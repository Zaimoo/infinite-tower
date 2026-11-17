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
-- Mirror heroes (The Gilded Mirror, docs/gilded-mirror-plan.md) have no stats of their own: their base power is a
-- share of the Master's best normal hero. The share is set by rarity and rises by MirrorPerStar for every star above 1★.
B.MirrorBase = table.freeze({ [7] = 1.10, [8] = 1.20, [9] = 1.30, [10] = 1.40, [11] = 1.50 } :: { [number]: number })
B.MirrorPerStar = 0.02
B.MovementSpeed = 20
B.MaxAttackSpeed = 5
B.MaxHeroInventory = 50
B.MaxArtifactInventory = 50
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
-- Expected builds are stat fixtures, never grants or acquisition restrictions.
-- Floors 1-9 keep the Phase 6 legacy rows (summoned at star = tier, 3x per star) and their playtested
-- towerCombatScale below. Each legacy row is {floor, squad size, hero stars, hero level, hero rarity tier,
-- weapon rarity tier, weapon stars}; the Floor 10 row only shapes floors 6-9 and never sets Floor 10 itself.
local legacyBuilds={{1,2,2,5,2,1,1},{5,3,2,10,2,2,1},{10,4,3,10,3,3,1}}
local legacyAnchors={}
for _,v in legacyBuilds do
	local g=B.LegacySummonCombatMultiplier^(v[3]-1)*B.LevelMultiplier^(v[4]-1)*B.HeroRarityCombatMultiplier^(v[5]-1)
	local power=B.RarityPower[v[6]]*B.WeaponStarMultipliers[v[7]]
	local damage=math.round(40*g*(1+power/B.WeaponPowerDivisor))
	local interval=B.ScheduledInterval(.85/(1+B.RaritySpeed[v[6]]))
	table.insert(legacyAnchors,{Floor=v[1],DPS=v[2]*damage/interval,HP=math.round(300*g),Size=v[2]})
end
-- From Floor 10 the curve follows the squad a Master is expected to field under today's rules: every hero is
-- summoned at 1★, promotes x1.5 per star, levels 1-10 per star, and its rarity factor is HeroRarityCombat.
-- Each hero is {rarity tier, stars, level within the star}; Weapon is {rarity tier, stars}.
-- Floor 10 needs a promoted Rare, Floor 30 a squad of 3★ Exalteds, and Floor 50 a full squad of 7★ Lv 10
-- Legendary/Mythical heroes (two Mythicals, three Legendaries) with Legendary 5★ weapons.
-- Squad DPS is the sum of the heroes; enemy ATK keys off the geometric mean of their HP, so the squad's
-- weaker heroes still have to be built up.
B.ExpectedSquads=table.freeze({
	{Floor=10,Heroes={{3,2,5},{3,2,1},{3,1,10},{2,1,10}},Weapon={3,1}},
	{Floor=15,Heroes={{4,2,5},{3,2,10},{3,2,5},{3,2,5},{3,1,10}},Weapon={4,1}},
	{Floor=20,Heroes={{4,3,1},{4,2,10},{3,3,1},{3,2,10},{3,2,10}},Weapon={4,2}},
	{Floor=25,Heroes={{5,2,5},{4,3,5},{4,3,1},{4,2,10},{3,3,5}},Weapon={5,1}},
	{Floor=30,Heroes={{5,3,10},{5,3,5},{5,3,5},{4,3,10},{4,4,1}},Weapon={5,2}},
	{Floor=35,Heroes={{6,3,10},{5,4,5},{5,4,5},{5,4,1},{5,3,10}},Weapon={5,3}},
	{Floor=40,Heroes={{6,4,10},{6,4,5},{5,5,5},{5,5,1},{5,4,10}},Weapon={6,2}},
	{Floor=45,Heroes={{7,6,1},{6,6,1},{6,5,10},{6,5,10},{6,5,10}},Weapon={6,4}},
	{Floor=50,Heroes={{7,7,10},{7,7,10},{6,7,10},{6,7,10},{6,7,10}},Weapon={6,5}},
})
B.CurveStartFloor=10 -- the first floor set by ExpectedSquads
local anchors={}
for _,row in B.ExpectedSquads do
	local w=row.Weapon
	local power=B.RarityPower[w[1]]*B.WeaponStarMultipliers[w[2]]
	local interval=B.ScheduledInterval(.85/(1+B.RaritySpeed[w[1]]))
	local dps,logHP=0,0
	for _,h in row.Heroes do
		local g=B.HeroRarityCombat(h[1])*B.HeroPromotionMultiplier^(h[2]-1)*B.LevelMultiplier^((h[2]-1)*10+h[3]-1)
		dps+=math.round(40*g*(1+power/B.WeaponPowerDivisor))/interval
		logHP+=math.log(300*g)
	end
	table.insert(anchors,{Floor=row.Floor,DPS=dps,HP=math.exp(logHP/#row.Heroes),Size=#row.Heroes})
end
-- Sawtooth inside each 5-floor biome: floor 1 is a breather after the previous boss, floor 4 and the boss floor are walls.
B.BiomeStep=table.freeze({.85,.95,1.05,1.15,1.3})
-- Enemy HP = squad DPS x first number (seconds one enemy survives a full squad); ATK = one hero's HP x second number.
B.RoleMultipliers=table.freeze({REGULAR=table.freeze({2,.04}),ELITE=table.freeze({8,.08}),ALPHA=table.freeze({15,.10}),BOSS=table.freeze({25,.12})})
local function anchorsFor(floor: number): { any }
	return if floor<B.CurveStartFloor then legacyAnchors else anchors
end
function B.ExpectedSquadSize(floor: number): number
	local list=anchorsFor(floor)
	local a=list[1]
	for _,v in list do if v.Floor<=floor then a=v end end
	return a.Size
end
function B.GetFloorStats(floor: number, role: string): any?
	if not B.Integer(floor,1,50) then return nil end
	local multipliers=B.RoleMultipliers[role]
	if not multipliers then return nil end
	local list=anchorsFor(floor)
	local a,b=list[1],list[#list]
	for _,v in list do if v.Floor<=floor then a=v end;if v.Floor>=floor then b=v;break end end
	local t=a.Floor==b.Floor and 0 or (floor-a.Floor)/(b.Floor-a.Floor)
	local dps=a.DPS*(b.DPS/a.DPS)^t
	local hp=a.HP*(b.HP/a.HP)^t
	local step=B.BiomeStep[(floor-1)%5+1]
	return {MaxHP=math.round(dps*multipliers[1]*step),ATK=math.round(hp*multipliers[2]*step)}
end

-- Floors 1-9 scale tower fights below the legacy reference: Floor 1 fits the starter pair, Floors 5-9 a
-- developing squad with a Rare. From Floor 10 tower fights use the reference curve unchanged. The Floor 10
-- entry only shapes the interpolation for floors 6-9.
local towerCombatScale = {
	{ Floor = 1, HP = 0.15, ATK = 0.14 },
	{ Floor = 2, HP = 0.16, ATK = 0.21 },
	{ Floor = 3, HP = 0.18, ATK = 0.33 },
	{ Floor = 4, HP = 0.20, ATK = 0.42 },
	{ Floor = 5, HP = 0.21, ATK = 0.53 },
	{ Floor = 10, HP = 0.085, ATK = 0.37 },
}

function B.GetTowerFloorStats(floor: number, role: string): any?
	local stats = B.GetFloorStats(floor, role)
	if not stats or floor >= B.CurveStartFloor then return stats end
	for i = 2, #towerCombatScale do
		local upper = towerCombatScale[i]
		if floor <= upper.Floor then
			local lower = towerCombatScale[i - 1]
			local t = (floor - lower.Floor) / (upper.Floor - lower.Floor)
			stats.MaxHP = math.round(stats.MaxHP * lower.HP * (upper.HP / lower.HP) ^ t)
			stats.ATK = math.max(1, math.round(stats.ATK * lower.ATK * (upper.ATK / lower.ATK) ^ t))
			break
		end
	end
	return stats
end
return table.freeze(B)
