--!strict
-- ReplicatedStorage/Shared/Config/FacilityConfig.luau
-- Authoritative Fortress Outskirts & Facility Economy Tables (GDD Sections 2.4 & 4.3)

export type GuardPostLevelConfig = {
	Gold: number,
	MaxWorkers: number,
	BaseGoldPerMin: number,
	MaxOfflineMinutes: number,
	OfflineEfficiency: number,
	VisualTitle: string,
}

export type MarketLevelConfig = {
	Gold: number,
	MaxWorkers: number,
	BaseBonus: number,
	VisualTitle: string,
}

export type TrainingLevelConfig = {
	Gold: number,
	MaxWorkers: number,
	BaseBonus: number,
	VisualTitle: string,
}

export type BlessingLevelConfig = {
	Gold: number,
	MaxWorkers: number,
	BaseLuck: number,
	VisualTitle: string,
}

local FacilityConfig = {}

FacilityConfig.Constants = {
	GuardPostLaborMultiplier = 0.85,
	BiomeBossTierMultiplier = 0.15,
	MarketLaborMultiplier = 0.005,
	TrainingLaborMultiplier = 0.004,
	BlessingLaborMultiplier = 0.004,
	MaxSummonLuck = 0.50,
	SynergyBonus = 0.25,
	PassiveGoldTickIntervalSeconds = 10,
	PassiveGoldCycleSeconds = 60,
}

FacilityConfig.FacilityArchetypeSynergies = {
	GuardPost = { "Vanguard", "Marksman" },
	Market = { "Berserker" },
	TrainingGrounds = { "Striker", "Scholar" },
	GodsBlessing = { "Healer" },
}

FacilityConfig.AssignmentTags = {
	GuardPost = "FACILITY_GUARD_POST",
	Market = "FACILITY_MARKET",
	TrainingGrounds = "FACILITY_TRAINING",
	GodsBlessing = "FACILITY_GODS_BLESSING",
}

FacilityConfig.UpgradeTable = {
	GuardPost = {
		[1] = {
			Gold = 0,
			MaxWorkers = 1,
			BaseGoldPerMin = 30,
			MaxOfflineMinutes = 240, -- 4 Hours
			OfflineEfficiency = 0.75,
			VisualTitle = "Rugged Lean-To",
		},
		[2] = {
			Gold = 1500,
			MaxWorkers = 2,
			BaseGoldPerMin = 75,
			MaxOfflineMinutes = 360, -- 6 Hours
			OfflineEfficiency = 0.80,
			VisualTitle = "Timber Guard Shack",
		},
		[3] = {
			Gold = 6000,
			MaxWorkers = 3,
			BaseGoldPerMin = 160,
			MaxOfflineMinutes = 480, -- 8 Hours
			OfflineEfficiency = 0.85,
			VisualTitle = "Stone Bastion",
		},
		[4] = {
			Gold = 20000,
			MaxWorkers = 4,
			BaseGoldPerMin = 300,
			MaxOfflineMinutes = 600, -- 10 Hours
			OfflineEfficiency = 0.90,
			VisualTitle = "Fortified Outpost",
		},
		[5] = {
			Gold = 60000,
			MaxWorkers = 5,
			BaseGoldPerMin = 550,
			MaxOfflineMinutes = 720, -- 12 Hours
			OfflineEfficiency = 1.00,
			VisualTitle = "Frontier Barbican",
		},
	} :: { [number]: GuardPostLevelConfig },

	Market = {
		[1] = {
			Gold = 1000,
			MaxWorkers = 1,
			BaseBonus = 0.05,
			VisualTitle = "Bazaar Stall",
		},
		[2] = {
			Gold = 3500,
			MaxWorkers = 1,
			BaseBonus = 0.10,
			VisualTitle = "Twin Stalls & Wagon",
		},
		[3] = {
			Gold = 12000,
			MaxWorkers = 2,
			BaseBonus = 0.18,
			VisualTitle = "Covered Pavilion",
		},
		[4] = {
			Gold = 35000,
			MaxWorkers = 2,
			BaseBonus = 0.28,
			VisualTitle = "Exchange Depot",
		},
		[5] = {
			Gold = 90000,
			MaxWorkers = 3,
			BaseBonus = 0.40,
			VisualTitle = "Celestial Exchange",
		},
	} :: { [number]: MarketLevelConfig },

	TrainingGrounds = {
		[1] = {
			Gold = 1200,
			MaxWorkers = 1,
			BaseBonus = 0.04,
			VisualTitle = "Sparring Circle",
		},
		[2] = {
			Gold = 4000,
			MaxWorkers = 1,
			BaseBonus = 0.08,
			VisualTitle = "Training Yard",
		},
		[3] = {
			Gold = 14000,
			MaxWorkers = 2,
			BaseBonus = 0.14,
			VisualTitle = "Cobblestone Arena",
		},
		[4] = {
			Gold = 40000,
			MaxWorkers = 2,
			BaseBonus = 0.22,
			VisualTitle = "Tiered Training Ring",
		},
		[5] = {
			Gold = 100000,
			MaxWorkers = 3,
			BaseBonus = 0.32,
			VisualTitle = "Martial Amphitheater",
		},
	} :: { [number]: TrainingLevelConfig },

	-- The angel on the Plaza Fountain (Phase 4 §6). Gold is the cost of the matching tree node.
	GodsBlessing = {
		[1] = {
			Gold = 2500,
			MaxWorkers = 1,
			BaseLuck = 0.04,
			VisualTitle = "Consecrated Angel",
		},
		[2] = {
			Gold = 8000,
			MaxWorkers = 1,
			BaseLuck = 0.08,
			VisualTitle = "Gilded Wings",
		},
		[3] = {
			Gold = 25000,
			MaxWorkers = 2,
			BaseLuck = 0.14,
			VisualTitle = "Choir of Light",
		},
		[4] = {
			Gold = 70000,
			MaxWorkers = 2,
			BaseLuck = 0.22,
			VisualTitle = "Radiant Halo",
		},
		[5] = {
			Gold = 180000,
			MaxWorkers = 3,
			BaseLuck = 0.32,
			VisualTitle = "Seraph Ascendant",
		},
	} :: { [number]: BlessingLevelConfig },
}

-- Waiting Room Plot Island Layout (relative to Plot Courtyard Origin at Y = 12)
-- Note: In island local coordinates:
--   -Z (-60) = Bridge / Front Gate (Left in reference camera view)
--   +Z (+60) = Dividing Wall to Forest Outskirts (Right in reference camera view)
--   +X (+80) = North / Top Wall in reference camera view
--   -X (-80) = South / Bottom Wall in reference camera view
-- Align TrainingGrounds + its cobblestone approach path along the exact ray from Fountain (0, 0)
-- through the SE corner bastion inner tip (-66.8, 46.8) so Fountain -> Path -> Archway -> Tip -> Column align.
local TRAINING_CORNER_LEN = math.sqrt(66.8 * 66.8 + 46.8 * 46.8)
local TRAINING_AXIS_X = -66.8 / TRAINING_CORNER_LEN
local TRAINING_AXIS_Z = 46.8 / TRAINING_CORNER_LEN
local TRAINING_CENTER_DIST = 49.0

FacilityConfig.FacilityLayout = {
	Fountain = {
		Offset = Vector3.new(0, 0, 0),
		Radius = 16,
	},
	SummoningPortal = {
		Offset = Vector3.new(48, 0, -34),
		RotationY = math.rad(-55),
		Radius = 24,
		Dimensions = Vector3.new(24.0, 26.5, 17.55),
		DoorOpenAngleDeg = 80,
		ProximityOpenRadius = 24,
		PromptOffset = Vector3.new(0, 2.0, 6.0),
		PromptText = "Summon Heroes",
		Keybind = if Enum then Enum.KeyCode.F else ("F" :: any),
	},
	Leaderboard = {
		Offset = Vector3.new(52, 0, -12),
		RotationY = math.rad(-90),
	},
	Market = {
		Offset = Vector3.new(42, 0, 30),
		RotationY = math.rad(-145),
		Radius = 26,
		PromptText = "Open Market",
		Keybind = if Enum then Enum.KeyCode.F else ("F" :: any),
	},
	BlacksmithForge = {
		Offset = Vector3.new(54, 0, -2),
		RotationY = math.rad(-90),
		Radius = 22,
		PromptText = "Blacksmith Forge",
		Keybind = if Enum then Enum.KeyCode.F else ("F" :: any), -- F, so it never competes with the [E] Recall hotkey
	},
	SynthesisChamber = {
		Offset = Vector3.new(-44, 0, -28),
		RotationY = math.atan2(44, 28),
		Radius = 28,
		Dimensions = Vector3.new(40.0, 41.0, 45.0),
		DoorOpenAngleDeg = 95,
		ProximityOpenRadius = 1.5,
		ProximityCloseRadius = 3.0,
		InteriorHoldRadius = 16.5,
		PromptOffset = Vector3.new(0, 6.2, 0),
		PromptAttachmentName = "PromptAnchor",
		ActivationDistance = 12,
		-- One prompt for the whole Pit; Synthesis and Promotion are tabs inside its screen.
		PromptText = "Synthesis & Promotion",
		ActionText = "Open The Pit",
		Keybind = if Enum then Enum.KeyCode.F else ("F" :: any),
	},
	TrainingArea = {
		Offset = Vector3.new(TRAINING_AXIS_X * TRAINING_CENTER_DIST, 0, TRAINING_AXIS_Z * TRAINING_CENTER_DIST),
		RotationY = -math.atan2(66.8, 46.8),
		Radius = 26,
		PromptText = "Training Grounds",
		Keybind = if Enum then Enum.KeyCode.F else ("F" :: any),
	},
	Guardpost = {
		Offset = Vector3.new(12, 0, 115),
		RotationY = math.rad(0),
		Radius = 20,
		PromptText = "Guardpost",
		Keybind = if Enum then Enum.KeyCode.F else ("F" :: any),
	},
}

return FacilityConfig
