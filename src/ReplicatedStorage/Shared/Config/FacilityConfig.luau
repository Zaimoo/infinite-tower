--!strict
-- ReplicatedStorage/Shared/Config/FacilityConfig.luau
-- Waiting Room Tycoon Economy Tables

local FacilityConfig = {}

FacilityConfig.UpgradeTable = {
	Infirmary = {
		[1] = { Gold = 0, MaxWorkers = 1, Beds = 2 },
		[2] = { Gold = 600, MaxWorkers = 1, Beds = 3 },
		[3] = { Gold = 2000, MaxWorkers = 2, Beds = 4 },
		[4] = { Gold = 6000, MaxWorkers = 2, Beds = 5 },
		[5] = { Gold = 18000, MaxWorkers = 3, Beds = 5 },
	},
}

return FacilityConfig
