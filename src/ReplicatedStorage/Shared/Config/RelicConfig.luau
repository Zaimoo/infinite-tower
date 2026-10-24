--!strict
-- ReplicatedStorage/Shared/Config/RelicConfig.luau
-- Physical Relic Extraction Table from Document 1 & Document 2

export type RelicTierId = "MANA_GEODE" | "CURSED_URN" | "ABYSSAL_CORE" | "CALAMITY_HEART"

export type RelicSpec = {
	TierId: RelicTierId,
	DisplayName: string,
	Rarity: string,
	WalkSpeedPenalty: number,
	DisableJump: boolean,
	TriggersSaboteurSnare: boolean,
	DespawnSeconds: number,
	InitialLockSeconds: number,
	Color: Color3,
	Payout: {
		Gems: number,
		Gold: number,
	},
}

local RelicConfig: { [RelicTierId]: RelicSpec } = {
	MANA_GEODE = {
		TierId = "MANA_GEODE",
		DisplayName = "Mana Geode",
		Rarity = "Common",
		WalkSpeedPenalty = 0.15,
		DisableJump = false,
		TriggersSaboteurSnare = false,
		DespawnSeconds = 90,
		InitialLockSeconds = 3.0,
		Color = Color3.fromRGB(65, 210, 255),
		Payout = { Gems = 100, Gold = 250 },
	},
	CURSED_URN = {
		TierId = "CURSED_URN",
		DisplayName = "Cursed Urn",
		Rarity = "Rare",
		WalkSpeedPenalty = 0.25,
		DisableJump = false,
		TriggersSaboteurSnare = true,
		DespawnSeconds = 120,
		InitialLockSeconds = 3.0,
		Color = Color3.fromRGB(255, 165, 45),
		Payout = { Gems = 300, Gold = 1200 },
	},
	ABYSSAL_CORE = {
		TierId = "ABYSSAL_CORE",
		DisplayName = "Abyssal Core",
		Rarity = "Mythic",
		WalkSpeedPenalty = 0.35,
		DisableJump = true,
		TriggersSaboteurSnare = true,
		DespawnSeconds = 150,
		InitialLockSeconds = 5.0,
		Color = Color3.fromRGB(190, 65, 255),
		Payout = { Gems = 1000, Gold = 4000 },
	},
	CALAMITY_HEART = {
		TierId = "CALAMITY_HEART",
		DisplayName = "The Calamity Heart",
		Rarity = "World Boss Exclusive",
		WalkSpeedPenalty = 0.45,
		DisableJump = true,
		TriggersSaboteurSnare = true,
		DespawnSeconds = 180,
		InitialLockSeconds = 15.0, -- 15s Rank #1 DPS Lock
		Color = Color3.fromRGB(255, 30, 65),
		Payout = { Gems = 1500, Gold = 15000 },
	},
}

return RelicConfig
