--!strict
-- ReplicatedStorage/Shared/Util/RollLuck.luau
-- Open Forge Roll Luck: separate from God's Blessing summon luck, with no maximum cap.
-- Uses an odds-ratio tail transform C_t(L) = C_t(0)*(1 + L) / (1 + C_t(0)*L) so that for any
-- uncapped luck bonus L >= 0, every rarity tier stays strictly positive and probabilities sum to 1.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RollLuck = {}

-- `rates[1]` is the lowest tier (Common). Returns a new array summing to 1.0; input is never mutated.
function RollLuck.ApplyLuck(rates: { number }, luck: number): { number }
	local n = #rates
	if n == 0 then
		return {}
	end
	if type(luck) ~= "number" or luck ~= luck or luck <= 0 then
		return table.clone(rates)
	end
	if luck == math.huge then
		local maxed = table.create(n, 0)
		maxed[n] = 1
		return maxed
	end

	local baseTail = table.create(n + 1, 0)
	for t = n, 1, -1 do
		baseTail[t] = baseTail[t + 1] + math.max(0, rates[t])
	end
	local total = baseTail[1]
	if total <= 0 then
		local fallback = table.create(n, 0)
		fallback[1] = 1
		return fallback
	end

	local boostedTail = table.create(n + 1, 0)
	boostedTail[1] = 1
	for t = 2, n do
		local c0 = math.clamp(baseTail[t] / total, 0, 1)
		boostedTail[t] = (c0 * (1 + luck)) / (1 + c0 * luck)
	end

	local boosted = table.create(n, 0)
	local sum = 0
	for t = n, 2, -1 do
		local p = math.max(0, boostedTail[t] - boostedTail[t + 1])
		boosted[t] = p
		sum += p
	end
	boosted[1] = math.max(0, 1 - sum)
	return boosted
end

-- Picks a tier with `r` in [0, 1). Rare tiers are checked first, so a low roll is a rare weapon.
function RollLuck.Roll(rates: { number }, r: number): number
	local cumulative = 0
	for tier = #rates, 2, -1 do
		cumulative += rates[tier]
		if r < cumulative then
			return tier
		end
	end
	return 1
end

-- Live Forge Roll Luck for `profile`, derived solely from the uncapped ForgeLuck branch in FortressTree.
function RollLuck.ForProfile(profile: any): number
	if not profile then
		return 0
	end
	local FortressTree = require(ReplicatedStorage.Shared.Util.FortressTree)
	return FortressTree.RollLuck(profile.FortressTree)
end

return table.freeze(RollLuck)
