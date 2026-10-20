--!strict
-- ReplicatedStorage/Shared/Util/StatFormulas.luau
-- Pure Mathematical Formulas from Document 1 (Section 4) & Document 3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HeroCatalog"))

local StatFormulas = {}

-- Level Cap: MaxLevel(S) = S * 10
function StatFormulas.GetMaxLevel(stars: number): number
	return stars * 10
end

-- XP Required for Level L -> L + 1: round(50 * (L ^ 1.45))
function StatFormulas.GetXPRequiredForNextLevel(level: number): number
	return math.round(50 * (level ^ 1.45))
end

-- Synthesis ("The Pit") Fodder XP: (100 * 3^(FodderStars - 1)) + (25 * FodderLevel)
function StatFormulas.CalculateSynthesisXP(fodderStars: number, fodderLevel: number): number
	return (100 * (3 ^ (fodderStars - 1))) + (25 * fodderLevel)
end

-- Star Promotion Multipliers: 1.65^(S-1) Combat, 1.35^(S-1) Labor
function StatFormulas.GetPromotionCombatMult(stars: number): number
	return 1.65 ^ (stars - 1)
end

function StatFormulas.GetPromotionLaborMult(stars: number): number
	return 1.35 ^ (stars - 1)
end

-- Promotion Gold Cost
local PROMOTION_GOLD_COSTS = {
	[1] = 1500,
	[2] = 7500,
	[3] = 35000,
	[4] = 150000,
}

function StatFormulas.GetPromotionGoldCost(currentStars: number): number
	return PROMOTION_GOLD_COSTS[currentStars] or 9999999
end

-- Effective Combat Stats (ATK, HP, Single-Target DPS)
function StatFormulas.GetEffectiveCombatStats(hero: any, inBloodPact: boolean?, inOverdrive: boolean?): (number, number, number)
	local seed = HeroCatalog.Seeds[hero.TemplateId]
	local traitATK = seed and seed.TraitATKBonus or 0.0
	local traitHP = seed and seed.TraitHPBonus or 0.0
	local pactBonus = inBloodPact and 0.20 or 0.0
	local levelScalar = 1 + 0.08 * ((hero.Level or 1) - 1)
	local q = hero.QualityScalar or 1.0

	-- BaseATK and BaseHP on HeroInstance already include the 1.65^(S-1) promotion multiplier
	local effATK = math.round((hero.BaseATK or 35) * q * levelScalar * (1 + traitATK) * (1 + pactBonus))
	local effHP = math.round((hero.BaseHP or 280) * q * levelScalar * (1 + traitHP))

	local interval = hero.AttackInterval or 1.0
	local overdriveMult = inOverdrive and 1.40 or 1.00
	local exhaustionMult = ((hero.CurrentStamina or 100) <= 0) and 0.20 or 1.00
	if (hero.ComaUntilTimestamp or 0) > os.time() then
		exhaustionMult = 0.0
	end
	local dps = math.round((effATK / interval) * overdriveMult * exhaustionMult * 10) / 10
	return effATK, effHP, dps
end

-- Effective Labor Output (/min)
function StatFormulas.GetEffectiveLabor(hero: any, targetFacilityAssignment: string?): number
	local seed = HeroCatalog.Seeds[hero.TemplateId]
	local traitLabor = seed and seed.TraitLaborBonus or 0.0
	local prefFacility = seed and seed.PreferredFacility or ""
	local checkFacility = targetFacilityAssignment or hero.Assignment or ""

	local hasSynergy = (prefFacility == "ALL") or (prefFacility ~= "" and prefFacility == checkFacility)
	local synergyBonus = hasSynergy and 0.25 or 0.0
	local levelScalar = 1 + 0.05 * ((hero.Level or 1) - 1)
	local q = hero.QualityScalar or 1.0

	local effLabor = (hero.BaseLabor or 14) * q * levelScalar * (1 + synergyBonus) * (1 + traitLabor)
	return math.round(effLabor * 100) / 100
end

-- Waiting Room Facility Output Formulas
function StatFormulas.GetManaConduitGemsPerMin(facilityLevel: number, sumEffectiveLabor: number, blessOrLeechMult: number): number
	local base = (5 * facilityLevel) + (0.45 * sumEffectiveLabor)
	local levelMult = 1 + 0.12 * (facilityLevel - 1)
	return math.round(base * levelMult * blessOrLeechMult * 10) / 10
end

function StatFormulas.GetDimensionalLabRPPerMin(facilityLevel: number, sumEffectiveLabor: number, blessOrLeechMult: number): number
	local base = (3 * facilityLevel) + (0.35 * sumEffectiveLabor)
	local levelMult = 1 + 0.10 * (facilityLevel - 1)
	return math.round(base * levelMult * blessOrLeechMult * 10) / 10
end

function StatFormulas.GetInfirmaryRates(facilityLevel: number, sumEffectiveLabor: number): (number, number)
	local staminaRegenPerSec = 2.5 + (0.4 * facilityLevel) + (0.06 * sumEffectiveLabor)
	local effectiveComaSec = math.max(20, 60 / (1 + 0.05 * (facilityLevel - 1) + (0.008 * sumEffectiveLabor)))
	return math.round(staminaRegenPerSec * 100) / 100, math.round(effectiveComaSec * 10) / 10
end

return StatFormulas
