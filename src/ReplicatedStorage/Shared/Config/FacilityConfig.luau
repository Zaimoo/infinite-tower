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

export type InfirmaryLevelConfig = {
	Gold: number,
	MaxWorkers: number,
	Beds: number,
}

local FacilityConfig = {}

FacilityConfig.Constants = {
	GuardPostLaborMultiplier = 0.85,
	BiomeBossTierMultiplier = 0.15,
	MarketLaborMultiplier = 0.005,
	TrainingLaborMultiplier = 0.004,
	SynergyBonus = 0.25,
	InfirmaryBaseStaminaRegen = 3.0,
	InfirmaryHealerStaminaRegen = 4.5,
	InfirmaryBaseComaSec = 60,
	InfirmaryHealerComaSec = 40,
	PassiveGoldTickIntervalSeconds = 10,
	PassiveGoldCycleSeconds = 60,
}

FacilityConfig.FacilityArchetypeSynergies = {
	GuardPost = { "Vanguard", "Marksman" },
	Market = { "Miner" },
	TrainingGrounds = { "Striker", "Scholar" },
	Infirmary = { "Healer" },
}

FacilityConfig.AssignmentTags = {
	GuardPost = "FACILITY_GUARD_POST",
	Market = "FACILITY_MARKET",
	TrainingGrounds = "FACILITY_TRAINING",
	Infirmary = "FACILITY_INFIRMARY",
}

FacilityConfig.UpgradeTable = {
	Infirmary = {
		[1] = { Gold = 0, MaxWorkers = 5, Beds = 5 },
		[2] = { Gold = 600, MaxWorkers = 5, Beds = 5 },
		[3] = { Gold = 2000, MaxWorkers = 5, Beds = 5 },
		[4] = { Gold = 6000, MaxWorkers = 5, Beds = 5 },
		[5] = { Gold = 18000, MaxWorkers = 5, Beds = 5 },
	} :: { [number]: InfirmaryLevelConfig },

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
}

return FacilityConfig
