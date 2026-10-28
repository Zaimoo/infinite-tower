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

-- Inherent rarity tier (Phase 4 §7). Saves without the field fall back to the template's rarity.
function StatFormulas.GetHeroRarity(hero: any): number
	local rarity = hero and hero.Rarity
	if B.Integer(rarity, 1, 16) then
		return rarity
	end
	return HeroCatalog.RarityOf(hero and hero.TemplateId)
end

-- Canonical four-stat snapshot. Legacy base fields are never multiplied again.
-- trainingMultiplier: from The Training Grounds (GDD Section 4.3.2.C)
function StatFormulas.GetCombatSnapshot(hero: any, artifact: any?, inOverdrive: boolean?, _inBloodPact: boolean?, trainingMultiplier: number?): any
 local seed=HeroCatalog.Seeds[hero.TemplateId]
 local stars=B.Integer(hero.Stars,1,math.max(PitBalanceConfig.MaxStars, seed and seed.BaseStar or 7)) and hero.Stars or 1
 local level=B.Integer(hero.Level,1,stars*10) and hero.Level or 1
 local quality=B.Finite(hero.QualityScalar) and math.clamp(hero.QualityScalar,.9,1.15) or 1
 local growth=B.HeroPromotionMultiplier^(stars-1)*B.LevelMultiplier^(level-1)*B.HeroRarityCombatMultiplier^(StatFormulas.GetHeroRarity(hero)-1)
 local power,speed=0,0
 if artifact then power,speed=ArtifactCatalog.CalculateEffectiveStats(artifact.Star,artifact.Rarity,nil,artifact.TemplateId) end
 local mult = trainingMultiplier or 1.0
 local damage=math.round((seed and seed.BaseATK_1Star or 35)*quality*growth*(1+power/B.WeaponPowerDivisor)*mult)
 local health=math.round((seed and seed.BaseHP_1Star or 280)*quality*growth*mult)
 local baseInterval=seed and seed.AttackInterval or hero.AttackInterval or 1
 local interval=math.max(.2,baseInterval/(1+speed))
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
 local synergy=pref=="ALL" or (pref~="" and pref==target) or (target=="FACILITY_GODS_BLESSING" and (hero.Archetype or seed and seed.Archetype)=="Healer")
 local rarity=B.HeroRarityLaborMultiplier^(StatFormulas.GetHeroRarity(hero)-1)
 local labor=(seed and seed.BaseLabor_1Star or 14)*q*rarity*1.35^(stars-1)*(1+.05*(level-1))*(synergy and 1.25 or 1)
 return math.round(labor*100)/100
end

-- Passive Gold Rate: (BaseRate + 0.85 * sum(EffectiveLabor)) * (1 + 0.15 * BiomeBossTier)
-- `perks` is FortressTree.PerkBonuses(profile.FortressTree); omitted means no perks.
function StatFormulas.GetPassiveGoldRate(guardPostLevel: number, sumEffectiveLabor: number, biomeBossTier: number?, perks: any?): number
	if guardPostLevel <= 0 then return 0 end
	local cfg = FacilityConfig.UpgradeTable.GuardPost[guardPostLevel]
	local baseRate = (cfg and cfg.BaseGoldPerMin or 30) * (1 + (perks and perks.GuardPostRate or 0))
	local bossTier = math.clamp(biomeBossTier or 0, 0, 10)
	local rate = (baseRate + FacilityConfig.Constants.GuardPostLaborMultiplier * sumEffectiveLabor) * (1 + FacilityConfig.Constants.BiomeBossTierMultiplier * bossTier)
	return math.round(rate * 100) / 100
end

-- Offline Gold Accumulation: min(ElapsedMinutes, MaxOfflineCapMinutes) * PassiveGoldPerMin * OfflineEfficiency
function StatFormulas.CalculateOfflineGold(guardPostLevel: number, passiveGoldPerMin: number, elapsedMinutes: number, perks: any?): (number, number)
	if guardPostLevel <= 0 or passiveGoldPerMin <= 0 or elapsedMinutes <= 0 then
		return 0, 0
	end
	local cfg = FacilityConfig.UpgradeTable.GuardPost[guardPostLevel]
	if not cfg then return 0, 0 end
	local cappedMinutes = math.min(elapsedMinutes, cfg.MaxOfflineMinutes + (perks and perks.OfflineMinutes or 0))
	local gold = math.floor(cappedMinutes * passiveGoldPerMin * cfg.OfflineEfficiency)
	return gold, cappedMinutes
end

-- Market Loot Multiplier: 1 + BaseBonus + (0.005 * sum(EffectiveLabor))
function StatFormulas.GetMarketLootMultiplier(marketLevel: number, sumEffectiveLabor: number, perks: any?): number
	if marketLevel <= 0 then return 1.0 end
	local cfg = FacilityConfig.UpgradeTable.Market[marketLevel]
	local baseBonus = (cfg and cfg.BaseBonus or 0) + (perks and perks.MarketBonus or 0)
	local mult = 1.0 + baseBonus + (FacilityConfig.Constants.MarketLaborMultiplier * sumEffectiveLabor)
	return math.round(mult * 1000) / 1000
end

-- Training Combat Multiplier: 1 + BaseBonus + (0.004 * sum(EffectiveLabor))
function StatFormulas.GetTrainingCombatMultiplier(trainingLevel: number, sumEffectiveLabor: number, perks: any?): number
	if trainingLevel <= 0 then return 1.0 end
	local cfg = FacilityConfig.UpgradeTable.TrainingGrounds[trainingLevel]
	local baseBonus = (cfg and cfg.BaseBonus or 0) + (perks and perks.TrainingBonus or 0)
	local mult = 1.0 + baseBonus + (FacilityConfig.Constants.TrainingLaborMultiplier * sumEffectiveLabor)
	return math.round(mult * 1000) / 1000
end

-- Squad Power (Phase 5 §2.3): HeroPower = round(10 x DPS + Health), summed over deployed heroes.
-- DPS ignores coma (a downed hero still counts toward the squad's strength).
function StatFormulas.GetHeroPower(hero: any, artifact: any?, trainingMultiplier: number?): number
	local v = StatFormulas.GetCombatSnapshot(hero, artifact, false, false, trainingMultiplier)
	return math.round(10 * (v.AttackDamage / v.TickInterval) + v.Health)
end

function StatFormulas.GetSquadPower(profile: any, trainingMultiplier: number?): (number, { [string]: number })
	local total, perHero = 0, {}
	for uuid, hero in pairs(profile and profile.Heroes or {}) do
		if string.find(hero.Assignment or "", "^SQUAD_SLOT_") then
			local power = StatFormulas.GetHeroPower(hero, StatFormulas.GetEquippedArtifact(profile, hero), trainingMultiplier)
			perHero[uuid] = power
			total += power
		end
	end
	return total, perHero
end

-- Worker slots for a support facility: level table plus Fortress Tree perk slots. 0 while locked.
local WORKER_PERKS = { Market = "MarketWorkers", TrainingGrounds = "TrainingWorkers", GodsBlessing = "BlessingWorkers" }
function StatFormulas.GetFacilityMaxWorkers(facility: string, level: number, perks: any?): number
	if level <= 0 then return 0 end
	local tableForFacility = (FacilityConfig.UpgradeTable :: any)[facility]
	local cfg = tableForFacility and tableForFacility[level]
	local perkKey = WORKER_PERKS[facility]
	return (cfg and cfg.MaxWorkers or 1) + (if perkKey and perks then perks[perkKey] or 0 else 0)
end

return StatFormulas
