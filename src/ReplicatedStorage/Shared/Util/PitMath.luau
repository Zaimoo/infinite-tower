--!strict
-- Pure calculations shared by authoritative previews, progression, and tests.
local Config = require(script.Parent.Parent.Config.PitBalanceConfig)
local Stats = require(script.Parent.StatFormulas)
local Catalog = require(script.Parent.Parent.Config.HeroCatalog)
local Balance = require(script.Parent.Parent.Config.StatBalance)
local PitMath = {}

function PitMath.Copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = PitMath.Copy(child) end
	return result
end

-- A hero's worth as fodder: its stars plus the stars its rarity used to be summoned at, so a 1★ Mythical still
-- feeds and converts like the 7★ it used to arrive as.
function PitMath.EffectiveStars(hero: any): number
	local stars = if type(hero.Stars) == "number" then hero.Stars else 1
	return math.clamp(stars + Stats.GetHeroRarity(hero) - 1, 1, Config.MaxStars)
end

function PitMath.GetOverflowCapacity(hero: any): number
	if hero.Stars >= Config.MaxStars then return 0 end
	local total = 0
	for offset = 0, Config.Synthesis.OverflowNextLevels - 1 do
		total += Stats.GetXPRequiredForNextLevel(offset + 1, hero.Stars + 1)
	end
	return total
end

-- Calculates total XP required from hero's current Level and XP to reach their current Star Level Cap (MaxLevel).
function PitMath.GetXPRequiredForMaxLevel(hero: any): number
	local cap = Stats.GetMaxLevel(hero.Stars)
	local currentLevel = hero.Level or 1
	if currentLevel >= cap then
		return 0
	end
	local currentXP = math.max(0, hero.XP or 0)
	local needed = 0
	for lvl = currentLevel, cap - 1 do
		local req = Stats.GetXPRequiredForNextLevel(lvl, hero.Stars)
		if lvl == currentLevel then
			needed += math.max(0, req - currentXP)
		else
			needed += req
		end
	end
	return math.max(0, needed)
end

-- Simulates projected level and XP after adding a given amount of donor XP.
-- Returns: projectedLevel, projectedXP, isAtOrAboveCap
function PitMath.GetProjectedLevel(hero: any, addedXP: number): (number, number, boolean)
	local cap = Stats.GetMaxLevel(hero.Stars)
	if (hero.Level or 1) >= cap then
		return cap, 0, true
	end
	local after, _ = PitMath.AdvanceXP(hero, addedXP)
	local isCap = (after.Level or 1) >= cap
	return after.Level or 1, after.XP or 0, isCap
end

function PitMath.GetSynthesisXP(donor: any, recipient: any, research: any): any
	local balance = Config.Synthesis
	local base = balance.BaseXP * balance.StarMultiplier ^ (PitMath.EffectiveStars(donor) - 1) + balance.LevelXP * Stats.GetEffectiveLevel(donor.Stars, donor.Level)
	local gap = math.max(0, Stats.GetEffectiveLevel(recipient.Stars, recipient.Level) - Stats.GetEffectiveLevel(donor.Stars, donor.Level) - balance.EfficiencyGrace)
	local efficiency = math.max(balance.MinimumEfficiency, 1 - gap * balance.EfficiencyLossPerLevel)
	local researchBonus = research and research.EssenceAttunement and balance.ResearchBonus or 0
	local affinity = donor.Archetype == recipient.Archetype and balance.AffinityBonus or 0
	return { Base = base, Efficiency = efficiency, ResearchBonus = researchBonus, AffinityBonus = affinity,
		Final = math.floor(base * efficiency * (1 + researchBonus + affinity) + 0.5 + 1e-7) }
end

function PitMath.AdvanceXP(hero: any, amount: number): (any, any)
	local result = PitMath.Copy(hero)
	local capacity = PitMath.GetOverflowCapacity(result)
	local reserve = math.max(0, result.OverflowXP or 0)
	local xp = math.max(0, result.XP or 0) + reserve + math.max(0, math.floor(amount))
	local cap = Stats.GetMaxLevel(result.Stars)
	result.OverflowXP = 0
	while result.Level < cap and xp >= Stats.GetXPRequiredForNextLevel(result.Level, result.Stars) do
		xp -= Stats.GetXPRequiredForNextLevel(result.Level, result.Stars)
		result.Level += 1
	end
	local rejected = 0
	if result.Level >= cap then
		result.XP = 0
		result.OverflowXP = math.min(capacity, xp)
		rejected = math.max(0, xp - capacity)
	else
		result.XP = xp
	end
	return result, { Stored = result.OverflowXP, Capacity = capacity, Rejected = rejected }
end

function PitMath.GetConversionYield(hero: any): number
	local cfg = Config.Conversion
	return (cfg.BaseEssence[PitMath.EffectiveStars(hero)] or cfg.BaseEssence[5] or 324) + math.floor((Stats.GetEffectiveLevel(hero.Stars, hero.Level) - 1) / cfg.LevelsPerBonus) * cfg.EssencePerInvestmentLevel
end

function PitMath.Promote(hero: any): (any, any)
	local result = PitMath.Copy(hero)
	result.Stars += 1
	-- Promotion resets to Lv 1 of the new star; reserved EXP is released below. Stats never drop (effective level rises by 1).
	result.Level, result.XP = 1, 0
	local seed = Catalog.Seeds[result.TemplateId]
	if seed then
		local rarity = Stats.GetHeroRarity(result)
		local rarityCombat = Balance.HeroRarityCombat(rarity)
		local rarityLabor = Balance.HeroRarityLabor(rarity)
		local starCombat = Config.Promotion.CombatMultiplier ^ (result.Stars - 1)
		result.BaseHP = math.round(seed.BaseHP_1Star * starCombat * rarityCombat)
		result.BaseATK = math.round(seed.BaseATK_1Star * starCombat * rarityCombat)
		result.BaseLabor = math.round(seed.BaseLabor_1Star * Config.Promotion.LaborMultiplier ^ (result.Stars - 1) * rarityLabor * 100) / 100
	end
	return PitMath.AdvanceXP(result, 0)
end

function PitMath.Snapshot(hero: any, profile: any?): any
	local combat = Stats.GetCombatSnapshot(hero, Stats.GetEquippedArtifact(profile, hero))
	return { Level = hero.Level, XP = hero.XP, Stars = hero.Stars, HP = combat.Health, ATK = combat.AttackDamage, DPS = combat.DPS,
		AttackDamage = combat.AttackDamage, Health = combat.Health, AttackSpeed = combat.AttackSpeed, MovementSpeed = combat.MovementSpeed,
		Labor = Stats.GetEffectiveLabor(hero), MaxLevel = Stats.GetMaxLevel(hero.Stars),
		XPRequired = Stats.GetXPRequiredForNextLevel(hero.Level, hero.Stars), OverflowXP = hero.OverflowXP or 0 }
end

return PitMath
