--!strict
-- Stat/progression data only. No banner, drop, reward or navigation settings.
local B = {}
B.Version = 2
B.TickSeconds = 0.10 -- Phase 6 M6: 10 Hz simulation (was 5 Hz). Attack intervals round up to this tick.
-- Every hero is summoned at 1★; promotion at The Pit multiplies combat by 1.5 per star (was 3).
B.HeroSummonStar = 1
B.HeroPromotionMultiplier = 1.5
B.LevelMultiplier = 1.08
-- Inherent hero rarity (Phase 4 §7). Heroes used to be summoned at a star equal to their tier, so tier t carried
-- 3^(t-1) from stars on top of 1.35^(t-1) (labor: 1.35^(t-1) on top of 1.12^(t-1)). Now that every pull is 1★,
-- the rarity factor folds that old star bonus in, scaled by RarityStarCompensation: Common to Rare keep 100% of their
-- old summoned power (so the early floors stay easy), Superior and above get 50%.
B.HeroRarityCombatMultiplier = 1.35
B.HeroRarityLaborMultiplier = 1.12
B.LegacySummonCombatMultiplier = 3
B.LegacySummonLaborMultiplier = 1.35
B.RarityStarCompensationFullTier = 3 -- tiers up to and including this one keep 100%
B.RarityStarCompensation = 0.5 -- tiers above it
function B.RarityCompensation(tier: number): number
	return if tier <= B.RarityStarCompensationFullTier then 1 else B.RarityStarCompensation
end
function B.HeroRarityCombat(tier: number): number
	return B.RarityCompensation(tier) * (B.LegacySummonCombatMultiplier * B.HeroRarityCombatMultiplier) ^ (tier - 1)
end
function B.HeroRarityLabor(tier: number): number
	return B.RarityCompensation(tier) * (B.LegacySummonLaborMultiplier * B.HeroRarityLaborMultiplier) ^ (tier - 1)
end
B.MovementSpeed = 20
B.MaxAttackSpeed = 5
B.WeaponPowerDivisor = 40
B.WeaponStarMultipliers = table.freeze({1, 1.6, 2.5, 4, 6.5, 10, 16})
B.RarityPower = table.freeze({20, 60, 180, 540, 1400, 3500, 7000, 10000, 14000, 20000, 28000, 40000, 56000, 80000, 112000, 160000})
B.RaritySpeed = table.freeze({.05, .075, .10, .13, .165, .20, .30, .35, .40, .45, .50, .55, .60, .65, .70, .75})
B.WeaponPromotionCosts = table.freeze({
	[1] = table.freeze({Donors=1, Gold=500, Gems=0}),
	[2] = table.freeze({Donors=2, Gold=2000, Gems=0}),
	[3] = table.freeze({Donors=3, Gold=8000, Gems=0}),
	[4] = table.freeze({Donors=4, Gold=25000, Gems=50}),
	[5] = table.freeze({Donors=5, Gold=75000, Gems=150}),
	[6] = table.freeze({Donors=6, Gold=250000, Gems=500}),
})
function B.Finite(value: any): boolean
	return type(value)=="number" and value==value and math.abs(value)<math.huge
end
function B.Integer(value: any, low: number, high: number): boolean
	return B.Finite(value) and value%1==0 and value>=low and value<=high
end
function B.ScheduledInterval(interval: number): number
	return math.ceil(math.max(B.TickSeconds,interval)/B.TickSeconds-1e-10)*B.TickSeconds
end
function B.Format(value: any): string
	if not B.Finite(value) then return "0" end
	local magnitude=math.abs(value)
	for _,unit in {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}} do
		if magnitude>=unit[1] then return string.format("%.2f%s",value/unit[1],unit[2]) end
	end
	return value%1==0 and string.format("%.0f",value) or string.format("%.1f",value)
end
-- Expected builds are stat fixtures, never grants or acquisition restrictions (Phase 6 re-anchor).
-- Each row is {floor, squad size, hero stars, hero level, hero rarity tier, weapon rarity tier, weapon stars}.
-- Squad size follows the Fortress Tree slots a player is expected to have by then (2 at floor 1, 5 from floor 15).
-- The enemy curve is frozen at its pre-1★-summon values: these rows use the legacy rule (summoned at star = tier,
-- 3x per star), so the 1★ summon and 1.5x promotion change hero power without moving any floor's enemies.
local builds={{1,2,2,5,2,1,1},{5,3,2,10,2,2,1},{10,4,3,10,3,3,1},{15,5,3,25,3,3,2},{20,5,4,25,4,4,1},
	{25,5,4,35,4,4,3},{30,5,5,35,5,5,2},{35,5,5,45,5,5,4},{40,5,5,50,5,6,3},{45,5,5,50,5,6,6},{50,5,5,50,5,7,7}}
local anchors={}
for _,v in builds do
	local g=B.LegacySummonCombatMultiplier^(v[3]-1)*B.LevelMultiplier^(v[4]-1)*B.HeroRarityCombatMultiplier^(v[5]-1)
	local power=B.RarityPower[v[6]]*B.WeaponStarMultipliers[v[7]]
	local damage=math.round(40*g*(1+power/B.WeaponPowerDivisor))
	local interval=B.ScheduledInterval(.85/(1+B.RaritySpeed[v[6]]))
	table.insert(anchors,{Floor=v[1],DPS=v[2]*damage/interval,HP=math.round(300*g),Size=v[2]})
end
-- Sawtooth inside each 5-floor biome: floor 1 is a breather after the previous boss, floor 4 and the boss floor are walls.
B.BiomeStep=table.freeze({.85,.95,1.05,1.15,1.3})
-- Enemy HP = squad DPS x first number (seconds one enemy survives a full squad); ATK = one hero's HP x second number.
B.RoleMultipliers=table.freeze({REGULAR=table.freeze({2,.04}),ELITE=table.freeze({8,.08}),ALPHA=table.freeze({15,.10}),BOSS=table.freeze({25,.12})})
function B.ExpectedSquadSize(floor: number): number
	local a=anchors[1]
	for _,v in anchors do if v.Floor<=floor then a=v end end
	return a.Size
end
function B.GetFloorStats(floor: number, role: string): any?
	if not B.Integer(floor,1,50) then return nil end
	local multipliers=B.RoleMultipliers[role]
	if not multipliers then return nil end
	local a,b=anchors[1],anchors[#anchors]
	for _,v in anchors do if v.Floor<=floor then a=v end;if v.Floor>=floor then b=v;break end end
	local t=a.Floor==b.Floor and 0 or (floor-a.Floor)/(b.Floor-a.Floor)
	local dps=a.DPS*(b.DPS/a.DPS)^t
	local hp=a.HP*(b.HP/a.HP)^t
	local step=B.BiomeStep[(floor-1)%5+1]
	return {MaxHP=math.round(dps*multipliers[1]*step),ATK=math.round(hp*multipliers[2]*step)}
end
return table.freeze(B)
