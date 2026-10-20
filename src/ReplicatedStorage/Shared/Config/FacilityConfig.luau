--!strict
-- ReplicatedStorage/Shared/Config/FacilityConfig.luau
-- Waiting Room Tycoon Economy Tables

local FacilityConfig = {}

FacilityConfig.UpgradeTable = {
	ManaConduit = {
		[1] = { Gold = 0, MaxWorkers = 1, Cap = 150 },
		[2] = { Gold = 800, MaxWorkers = 1, Cap = 300 },
		[3] = { Gold = 2500, MaxWorkers = 2, Cap = 600 },
		[4] = { Gold = 7500, MaxWorkers = 2, Cap = 1200 },
		[5] = { Gold = 22000, MaxWorkers = 3, Cap = 2500 },
	},
	Infirmary = {
		[1] = { Gold = 0, MaxWorkers = 1, Beds = 2 },
		[2] = { Gold = 600, MaxWorkers = 1, Beds = 3 },
		[3] = { Gold = 2000, MaxWorkers = 2, Beds = 4 },
		[4] = { Gold = 6000, MaxWorkers = 2, Beds = 5 },
		[5] = { Gold = 18000, MaxWorkers = 3, Beds = 5 },
	},
}

return FacilityConfig
