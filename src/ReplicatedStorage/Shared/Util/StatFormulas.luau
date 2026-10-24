--!strict
-- ReplicatedStorage/Shared/Util/StatFormulas.luau
-- Pure Mathematical Formulas from Document 1 (Section 4) & Document 3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HeroCatalog"))
local ArtifactCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local PitBalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PitBalanceConfig"))

local B = require(ReplicatedStorage.Shared.Config.StatBalance)
local FacilityConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("FacilityConfig"))
local StatFormulas = {}

-- Level Cap: MaxLevel(S) = S * 10
function StatFormulas.GetMaxLevel(stars: number): number
	return math.clamp(math.floor(stars), 1, PitBalanceConfig.MaxStars) * 10
end

-- Legacy compatibility: retired effects cannot affect stats.
function StatFormulas.GetImprintBonuses(_hero: any): (number,number,number)
 return 0,0,0
end
function StatFormulas.GetEquippedArtifact(profile: any, hero: any): any?
 return profile and profile.Artifacts and hero and hero.EquippedArtifactUUID and profile.Artifacts[hero.EquippedArtifactUUID] or nil
end

-- XP Required for Level L -> L + 1: round(50 * (L ^ 1.45))
function StatFormulas.GetXPRequiredForNextLevel(level: number): number
	return math.round(50 * (level ^ 1.45))
end

-- Synthesis ("The Pit") Fodder XP: (100 * 3^(FodderStars - 1)) + (25 * FodderLevel)
function StatFormulas.CalculateSynthesisXP(fodderStars: number, fodderLevel: number): number
	local config = PitBalanceConfig.Synthesis
	return (config.BaseXP * (config.StarMultiplier ^ (fodderStars - 1))) + (config.LevelXP * fodderLevel)
end

-- Star Promotion Multipliers: 3^(S-1) Combat, 1.35^(S-1) Labor
function StatFormulas.GetPromotionCombatMult(stars: number): number
	return PitBalanceConfig.Promotion.CombatMultiplier ^ (stars - 1)
end

function StatFormulas.GetPromotionLaborMult(stars: number): number
	return PitBalanceConfig.Promotion.LaborMultiplier ^ (stars - 1)
end

-- Promotion Gold Cost
function StatFormulas.GetPromotionGoldCost(currentStars: number): number
	local cost = PitBalanceConfig.Promotion[currentStars]
	return cost and cost.Gold or 9999999
end

-- Canonical four-stat snapshot. Legacy base fields are never multiplied again.
-- trainingMultiplier: from The Training Grounds (GDD Section 4.3.2.C)
function StatFormulas.GetCombatSnapshot(hero: any, artifact: any?, inOverdrive: boolean?, _inBloodPact: boolean?, trainingMultiplier: number?): any
 local seed=HeroCatalog.Seeds[hero.TemplateId]
 local stars=B.Integer(hero.Stars,1,math.max(PitBalanceConfig.MaxStars, seed and seed.BaseStar or 7)) and hero.Stars or 1
 local level=B.Integer(hero.Level,1,stars*10) and hero.Level or 1
 local quality=B.Finite(hero.QualityScalar) and math.clamp(hero.QualityScalar,.9,1.15) or 1
 local growth=B.HeroPromotionMultiplier^(stars-1)*B.LevelMultiplier^(level-1)
 local power,speed=0,0
 if artifact then power,speed=ArtifactCatalog.CalculateEffectiveStats(artifact.Star,artifact.Rarity,nil,artifact.TemplateId) end
 local mult = trainingMultiplier or 1.0
 local damage=math.round((seed and seed.BaseATK_1Star or 35)*quality*growth*(1+power/B.WeaponPowerDivisor)*mult)
 local health=math.round((seed and seed.BaseHP_1Star or 280)*quality*growth*mult)
 local baseInterval=seed and seed.AttackInterval or hero.AttackInterval or 1
 local interval=math.max(.2,baseInterval/((1+speed)*(inOverdrive and 1.4 or 1)))
 local tickInterval=B.ScheduledInterval(interval)
 local exhaustion=if (hero.ComaUntilTimestamp or 0)>os.time() then 0 else 1
 return {AttackDamage=damage,Health=health,AttackSpeed=1/interval,MovementSpeed=seed and seed.MovementSpeed or 20,
  AttackInterval=interval,TickInterval=tickInterval,DPS=math.round(damage/tickInterval*exhaustion*10)/10,
  ATK=damage,HP=health,WeaponPower=power}
end
function StatFormulas.GetEffectiveCombatStats(hero: any, inBloodPact: boolean?, inOverdrive: boolean?, artifact: any?, trainingMultiplier: number?): (number,number,number,number)
 local v=StatFormulas.GetCombatSnapshot(hero,artifact,inOverdrive,inBloodPact,trainingMultiplier)
 return v.AttackDamage,v.Health,v.DPS,v.AttackInterval
end
function StatFormulas.GetEffectiveLabor(hero: any, targetFacilityAssignment: string?): number
 local seed=HeroCatalog.Seeds[hero.TemplateId]
 local stars=B.Integer(hero.Stars,1,math.max(PitBalanceConfig.MaxStars, seed and seed.BaseStar or 7)) and hero.Stars or 1
 local level=B.Integer(hero.Level,1,stars*10) and hero.Level or 1
 local q=B.Finite(hero.QualityScalar) and math.clamp(hero.QualityScalar,.9,1.15) or 1
 local pref=seed and seed.PreferredFacility or ""
 local target=targetFacilityAssignment or hero.Assignment or ""
 local synergy=pref=="ALL" or (pref~="" and pref==target)
 local labor=(seed and seed.BaseLabor_1Star or 14)*q*1.35^(stars-1)*(1+.05*(level-1))*(synergy and 1.25 or 1)
 return math.round(labor*100)/100
end

-- Waiting Room Facility Output Formulas (GDD Sections 2.4 & 4.3)
-- The Infirmary: 3.0 stamina/sec base, 4.5 stamina/sec if Healer present. Coma: 60s base, 40s if Healer present.
function StatFormulas.GetInfirmaryRates(facilityLevel: number?, sumEffectiveLabor: number?, hasHealer: boolean?): (number, number)
	if hasHealer == true then
		return FacilityConfig.Constants.InfirmaryHealerStaminaRegen, FacilityConfig.Constants.InfirmaryHealerComaSec
	end
	return FacilityConfig.Constants.InfirmaryBaseStaminaRegen, FacilityConfig.Constants.InfirmaryBaseComaSec
end

-- Passive Gold Rate: (BaseRate + 0.85 * sum(EffectiveLabor)) * (1 + 0.15 * BiomeBossTier)
function StatFormulas.GetPassiveGoldRate(guardPostLevel: number, sumEffectiveLabor: number, biomeBossTier: number?): number
	if guardPostLevel <= 0 then return 0 end
	local cfg = FacilityConfig.UpgradeTable.GuardPost[guardPostLevel]
	local baseRate = cfg and cfg.BaseGoldPerMin or 30
	local bossTier = math.clamp(biomeBossTier or 0, 0, 10)
	local rate = (baseRate + FacilityConfig.Constants.GuardPostLaborMultiplier * sumEffectiveLabor) * (1 + FacilityConfig.Constants.BiomeBossTierMultiplier * bossTier)
	return math.round(rate * 100) / 100
end

-- Offline Gold Accumulation: min(ElapsedMinutes, MaxOfflineCapMinutes) * PassiveGoldPerMin * OfflineEfficiency
function StatFormulas.CalculateOfflineGold(guardPostLevel: number, passiveGoldPerMin: number, elapsedMinutes: number): (number, number)
	if guardPostLevel <= 0 or passiveGoldPerMin <= 0 or elapsedMinutes <= 0 then
		return 0, 0
	end
	local cfg = FacilityConfig.UpgradeTable.GuardPost[guardPostLevel]
	if not cfg then return 0, 0 end
	local cappedMinutes = math.min(elapsedMinutes, cfg.MaxOfflineMinutes)
	local gold = math.floor(cappedMinutes * passiveGoldPerMin * cfg.OfflineEfficiency)
	return gold, cappedMinutes
end

-- Market Loot Multiplier: 1 + BaseBonus + (0.005 * sum(EffectiveLabor))
function StatFormulas.GetMarketLootMultiplier(marketLevel: number, sumEffectiveLabor: number): number
	if marketLevel <= 0 then return 1.0 end
	local cfg = FacilityConfig.UpgradeTable.Market[marketLevel]
	local baseBonus = cfg and cfg.BaseBonus or 0
	local mult = 1.0 + baseBonus + (FacilityConfig.Constants.MarketLaborMultiplier * sumEffectiveLabor)
	return math.round(mult * 1000) / 1000
end

-- Training Combat Multiplier: 1 + BaseBonus + (0.004 * sum(EffectiveLabor))
function StatFormulas.GetTrainingCombatMultiplier(trainingLevel: number, sumEffectiveLabor: number): number
	if trainingLevel <= 0 then return 1.0 end
	local cfg = FacilityConfig.UpgradeTable.TrainingGrounds[trainingLevel]
	local baseBonus = cfg and cfg.BaseBonus or 0
	local mult = 1.0 + baseBonus + (FacilityConfig.Constants.TrainingLaborMultiplier * sumEffectiveLabor)
	return math.round(mult * 1000) / 1000
end

return StatFormulas
