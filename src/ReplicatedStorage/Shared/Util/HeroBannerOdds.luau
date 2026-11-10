--!strict
-- ReplicatedStorage/Shared/Util/HeroBannerOdds.luau
-- What a hero banner can drop and how likely each hero is, for the summon screen's
-- "View Heroes & Odds" window and the Hero Index. Mirrors DataManager's rollBannerHero: a tier is
-- rolled with the luck-boosted rates, then a hero is picked evenly from HeroesPoolByStar[tier]
-- (or HeroesByStar[tier] when the tier has no pool). Pity and the 10-pull floor are not modelled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SummonLuck = require(ReplicatedStorage.Shared.Util.SummonLuck)

local HeroBannerOdds = {}

export type HeroOdds = { HeroId: string, Chance: number }
export type TierOdds = { Tier: number, Rate: number, Heroes: { HeroOdds } }

-- The heroes a tier can award: its pool, else its single hero, else nothing.
function HeroBannerOdds.TierHeroes(banner: any, tier: number): { string }
	local pool = banner.HeroesPoolByStar and banner.HeroesPoolByStar[tier]
	if pool and #pool > 0 then
		return table.clone(pool)
	end
	local id = banner.HeroesByStar and banner.HeroesByStar[tier]
	return if id then { id } else {}
end

-- Every tier, rarest first, with its luck-boosted rate and each hero's chance per pull (0–1).
function HeroBannerOdds.Tiers(banner: any, luck: number?): { TierOdds }
	local rates = SummonLuck.ApplyLuck(banner.Rates :: { number }, luck or 0)
	local tiers: { TierOdds } = {}
	for tier = banner.MaxStar, 1, -1 do
		local rate = rates[tier] or 0
		local ids = HeroBannerOdds.TierHeroes(banner, tier)
		local heroes: { HeroOdds } = {}
		for _, id in ids do
			table.insert(heroes, { HeroId = id, Chance = rate / #ids })
		end
		table.insert(tiers, { Tier = tier, Rate = rate, Heroes = heroes })
	end
	return tiers
end

-- Every hero the banner can drop, rarest tier first, each listed once.
function HeroBannerOdds.Heroes(banner: any): { string }
	local list, seen = {}, {}
	for tier = banner.MaxStar, 1, -1 do
		for _, id in HeroBannerOdds.TierHeroes(banner, tier) do
			if not seen[id] then
				seen[id] = true
				table.insert(list, id)
			end
		end
	end
	return list
end

return table.freeze(HeroBannerOdds)
