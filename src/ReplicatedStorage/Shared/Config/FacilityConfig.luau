--!strict
-- ReplicatedStorage/Shared/Config/FacilityConfig.luau
-- Waiting Room Tycoon Economy & Tech Tree Tables from Document 3

local FacilityConfig = {}

FacilityConfig.UpgradeTable = {
	ManaConduit = {
		[1] = { Gold = 0, RP = 0, MaxWorkers = 1, Cap = 150 },
		[2] = { Gold = 800, RP = 25, MaxWorkers = 1, Cap = 300 },
		[3] = { Gold = 2500, RP = 75, MaxWorkers = 2, Cap = 600 },
		[4] = { Gold = 7500, RP = 200, MaxWorkers = 2, Cap = 1200 },
		[5] = { Gold = 22000, RP = 500, MaxWorkers = 3, Cap = 2500 },
	},
	Infirmary = {
		[1] = { Gold = 0, RP = 0, MaxWorkers = 1, Beds = 2 },
		[2] = { Gold = 600, RP = 20, MaxWorkers = 1, Beds = 3 },
		[3] = { Gold = 2000, RP = 60, MaxWorkers = 2, Beds = 4 },
		[4] = { Gold = 6000, RP = 160, MaxWorkers = 2, Beds = 5 },
		[5] = { Gold = 18000, RP = 400, MaxWorkers = 3, Beds = 5 },
	},
	DimensionalLab = {
		[1] = { Gold = 0, RP = 0, MaxWorkers = 1, Cap = 100 },
		[2] = { Gold = 1000, RP = 30, MaxWorkers = 1, Cap = 250 },
		[3] = { Gold = 3200, RP = 90, MaxWorkers = 2, Cap = 500 },
		[4] = { Gold = 9000, RP = 240, MaxWorkers = 2, Cap = 1000 },
		[5] = { Gold = 25000, RP = 600, MaxWorkers = 3, Cap = 2000 },
	},
}

FacilityConfig.TechNodes = {
	tech_essence_attunement = {
		Id = "tech_essence_attunement", Name = "Essence Attunement", ResearchKey = "EssenceAttunement",
		ReqLabLevel = 1, RPCost = 40, GoldCost = 750,
		Description = "Improves synthesis EXP by 10% before rounding.",
	},
	tech_memory_studies = {
		Id = "tech_memory_studies", Name = "Memory Studies", ResearchKey = "MemoryStudies",
		ReqLabLevel = 2, RPCost = 120, GoldCost = 2500,
		Description = "Unlocks advanced Runic Method imprints for compatible heroes.",
	},
	tech_advanced_stonecraft = {
		Id = "tech_advanced_stonecraft", Name = "Advanced Stonecraft", ResearchKey = "AdvancedStonecraft",
		ReqLabLevel = 2, RPCost = 150, GoldCost = 3000,
		Description = "Refines Promotion Stones into rituals for 3★ to 4★ promotion.",
	},
	tech_master_stonecraft = {
		Id = "tech_master_stonecraft", Name = "Master Stonecraft", ResearchKey = "MasterStonecraft",
		ReqLabLevel = 4, RPCost = 450, GoldCost = 15000,
		Description = "Unlocks the final 4★ to 5★ promotion ritual.",
	},
	tech_squad_slot_4 = {
		Id = "tech_squad_slot_4",
		Name = "4th Squad Deployment Slot",
		ReqLabLevel = 1,
		RPCost = 65,
		GoldCost = 1200,
		Description = "Increases active Master squad size from 3 to 4 Heroes (+33% Squad DPS).",
	},
	tech_ring2_barrier = {
		Id = "tech_ring2_barrier",
		Name = "Ring 2 Arcane Barrier Key",
		ReqLabLevel = 2,
		RPCost = 180,
		GoldCost = 3500,
		Description = "Permanently unlocks passage through the R=280 Barrier Gate into Ring 2.",
	},
	tech_squad_slot_5 = {
		Id = "tech_squad_slot_5",
		Name = "5th Squad Deployment Slot",
		ReqLabLevel = 3,
		RPCost = 420,
		GoldCost = 12000,
		Description = "Increases active Master squad size from 4 to the maximum 5 Heroes.",
	},
	craft_rift_lure = {
		Id = "craft_rift_lure",
		Name = "Craft Repeatable Rift Lure",
		ReqLabLevel = 3,
		RPCost = 300,
		GoldCost = 5000,
		Description = "Crafts 1x Rift Lure to summon The Rift Warden at Ring 3 (Guaranteed Abyssal Core).",
	},
}

return FacilityConfig
