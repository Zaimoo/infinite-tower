--!strict
-- Pure calculations shared by authoritative previews, progression, and tests.
local Config = require(script.Parent.Parent.Config.PitBalanceConfig)
local Stats = require(script.Parent.StatFormulas)
local Catalog = require(script.Parent.Parent.Config.HeroCatalog)
local PitMath = {}

function PitMath.Copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = PitMath.Copy(child) end
	return result
end

function PitMath.GetOverflowCapacity(hero: any): number
	if hero.Stars >= Config.MaxStars then return 0 end
	local cap = Stats.GetMaxLevel(hero.Stars)
	local total = 0
	for offset = 0, Config.Synthesis.OverflowNextLevels - 1 do
		total += Stats.GetXPRequiredForNextLevel(cap + offset)
	end
	return total
end

function PitMath.GetSynthesisXP(donor: any, recipient: any, research: any): any
	local balance = Config.Synthesis
	local base = balance.BaseXP * balance.StarMultiplier ^ (donor.Stars - 1) + balance.LevelXP * donor.Level
	local gap = math.max(0, recipient.Level - donor.Level - balance.EfficiencyGrace)
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
	while result.Level < cap and xp >= Stats.GetXPRequiredForNextLevel(result.Level) do
		xp -= Stats.GetXPRequiredForNextLevel(result.Level)
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
	local ranks = 0
	for id, rank in pairs(hero.InheritedImprints or {}) do
		if Config.Imprints.Definitions[id] and type(rank) == "number" then ranks += math.clamp(math.floor(rank), 0, Config.Imprints.MaxRank) end
	end
	return cfg.BaseEssence[hero.Stars] + math.floor((hero.Level - 1) / cfg.LevelsPerBonus) * cfg.EssencePerInvestmentLevel + ranks * cfg.EssencePerImprintRank
end

function PitMath.GetImprintCapacity(hero: any): number
	return Config.Imprints.SlotsByStar[hero.Stars] or 1
end

function PitMath.GetImprintOptions(donor: any, recipient: any, research: any): { any }
	local options = {}
	local used = 0
	for id, rank in pairs(recipient.InheritedImprints or {}) do
		if Config.Imprints.Definitions[id] and type(rank) == "number" and rank > 0 then used += 1 end
	end
	for id, definition in pairs(Config.Imprints.Definitions) do
		if definition.DonorRoles[donor.Archetype] then
			local rank = (recipient.InheritedImprints or {})[id] or 0
			local reason = ""
			if not definition.RecipientRoles[recipient.Archetype] then reason = "This memory is incompatible with the recipient's role."
			elseif recipient.Stars < (definition.MinimumStars or 1) then reason = "Promote the recipient before inheriting this memory."
			elseif definition.Research and not research[definition.Research] then reason = "Unlock Memory Studies in the Dimensional Lab."
			elseif rank >= Config.Imprints.MaxRank then reason = "This memory is already at maximum proficiency."
			elseif rank == 0 and used >= PitMath.GetImprintCapacity(recipient) then reason = "All inherited memory slots are filled. Promote for more capacity." end
			table.insert(options, { Id = id, Name = definition.Name, Description = definition.Description, Category = definition.Category,
				Compatible = reason == "", Reason = reason, CurrentRank = rank, MaxRank = Config.Imprints.MaxRank,
				SuccessChance = 1, Effect = PitMath.Copy(definition.Effect) })
		end
	end
	table.sort(options, function(a, b) return a.Id < b.Id end)
	return options
end

function PitMath.Promote(hero: any): (any, any)
	local result = PitMath.Copy(hero)
	result.Stars += 1
 local seed=Catalog.Seeds[result.TemplateId]
 if seed then
  result.BaseHP=math.round(seed.BaseHP_1Star*3^(result.Stars-1))
  result.BaseATK=math.round(seed.BaseATK_1Star*3^(result.Stars-1))
  result.BaseLabor=math.round(seed.BaseLabor_1Star*1.35^(result.Stars-1)*100)/100
 end
	return PitMath.AdvanceXP(result, 0)
end

function PitMath.Snapshot(hero: any, profile: any?): any
	local combat = Stats.GetCombatSnapshot(hero, Stats.GetEquippedArtifact(profile, hero))
	return { Level = hero.Level, XP = hero.XP, Stars = hero.Stars, HP = combat.Health, ATK = combat.AttackDamage, DPS = combat.DPS,
		AttackDamage = combat.AttackDamage, Health = combat.Health, AttackSpeed = combat.AttackSpeed, MovementSpeed = combat.MovementSpeed,
		Labor = Stats.GetEffectiveLabor(hero), MaxLevel = Stats.GetMaxLevel(hero.Stars),
		XPRequired = Stats.GetXPRequiredForNextLevel(hero.Level), OverflowXP = hero.OverflowXP or 0,
		ImprintCapacity = PitMath.GetImprintCapacity(hero), InheritedImprints = PitMath.Copy(hero.InheritedImprints or {}) }
end

return PitMath
