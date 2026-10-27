--!strict
-- ReplicatedStorage/Shared/Util/SummonLuck.luau
-- God's Blessing summon luck (Phase 4 §6.3). Luck multiplies every tier above the lowest, and the
-- lowest tier gives up the difference, so the odds always add up to 1. Pity is never touched here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FacilityConfig = require(ReplicatedStorage.Shared.Config.FacilityConfig)

local SummonLuck = {}

-- Luck from the God's Blessing level, the Acolytes' summed EffectiveLabor and the Saint's Favor perk.
function SummonLuck.Luck(level: number, sumLabor: number, perkLuck: number?): number
	if level <= 0 then
		return 0
	end
	local cfg = FacilityConfig.UpgradeTable.GodsBlessing[level]
	local base = if cfg then cfg.BaseLuck else 0
	local luck = base + FacilityConfig.Constants.BlessingLaborMultiplier * math.max(0, sumLabor) + (perkLuck or 0)
	return math.clamp(luck, 0, FacilityConfig.Constants.MaxSummonLuck)
end

-- `rates[1]` is the lowest tier. Returns a new array; the input is never modified.
function SummonLuck.ApplyLuck(rates: { number }, luck: number): { number }
	local boosted = table.create(#rates, 0)
	local upper = 0
	for i = 2, #rates do
		boosted[i] = rates[i] * (1 + luck)
		upper += boosted[i]
	end
	boosted[1] = math.max(0, 1 - upper)
	return boosted
end

-- Picks a tier with `r` in [0, 1). Rare tiers are checked first, so a low roll is a rare pull.
function SummonLuck.Roll(rates: { number }, r: number): number
	local cumulative = 0
	for tier = #rates, 2, -1 do
		cumulative += rates[tier]
		if r < cumulative then
			return tier
		end
	end
	return 1
end

-- Same as Roll, limited to tiers >= minTier and renormalised (10-pull guarantee).
function SummonLuck.RollAtLeast(rates: { number }, minTier: number, r: number): number
	local total = 0
	for tier = minTier, #rates do
		total += rates[tier]
	end
	if total <= 0 then
		return math.min(minTier, #rates)
	end
	local cumulative = 0
	for tier = #rates, minTier + 1, -1 do
		cumulative += rates[tier] / total
		if r < cumulative then
			return tier
		end
	end
	return minTier
end

return table.freeze(SummonLuck)
