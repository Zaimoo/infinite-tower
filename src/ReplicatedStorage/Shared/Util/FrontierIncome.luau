--!strict
-- A Master's typical tower Gold per minute on their frontier floor, built from the live reward tables.
-- Used to price things in "minutes of your income" (GDD §4.10), so a price keeps its weight as the
-- Master climbs. It is a model, not a measurement: per minute it counts KillsPerMinute kills and
-- RelicsPerMinute banked Regular relics (the floor's Geode/Urn mix), with no Market, streak, friend or
-- potion bonus.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TowerFloorConfig = require(ReplicatedStorage.Shared.Config.TowerFloorConfig)
local RelicConfig = require(ReplicatedStorage.Shared.Config.RelicConfig)

local FrontierIncome = {}

FrontierIncome.KillsPerMinute = table.freeze({ REGULAR = 30, ELITE = 3 })
FrontierIncome.RelicsPerMinute = 1

-- `floor` is the Master's highest cleared floor; 0, nil or anything invalid counts as Floor 1.
function FrontierIncome.GoldPerMinute(floor: any): number
	local f = if type(floor) == "number" and floor == floor then math.clamp(math.floor(floor), 1, TowerFloorConfig.FloorCount) else 1
	local gold = 0
	for role, kills in FrontierIncome.KillsPerMinute do
		gold += TowerFloorConfig.GetKillRewards(f, role).Gold * kills
	end
	local regular = TowerFloorConfig.GetKillRewards(f, "REGULAR")
	local biome = RelicConfig.GetBiomeForFloor(f)
	if biome then
		local geode = RelicConfig.Items[biome.DropTable[1]].Payout.Gold
		local urn = RelicConfig.Items[biome.DropTable[2]].Payout.Gold
		gold += (geode * (1 - regular.UrnChance) + urn * regular.UrnChance) * regular.RelicMultiplier * FrontierIncome.RelicsPerMinute
	end
	return gold
end

-- Rounds to three significant figures, so prices read cleanly ("16.2M", not "16,237,481").
function FrontierIncome.Round(value: number): number
	if value < 1000 then return math.round(value) end
	local step = 10 ^ (math.floor(math.log10(value)) - 2)
	return math.round(value / step) * step
end

return table.freeze(FrontierIncome)
