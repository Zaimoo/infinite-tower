--!strict
-- Stat/progression data only. No banner, drop, reward or navigation settings.
local B = {}
B.Version = 2
B.TickSeconds = 0.20
B.HeroPromotionMultiplier = 3
B.LevelMultiplier = 1.08
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
-- Expected builds are stat fixtures, never grants or acquisition restrictions.
local builds={{1,1,1,1,1},{5,1,5,1,2},{10,1,10,2,2},{15,2,15,2,3},{20,2,20,3,3},
	{25,3,25,3,4},{30,3,30,4,5},{35,4,35,5,5},{40,4,40,6,6},{45,5,45,6,6},{50,5,50,7,7}}
local anchors={}
for _,v in builds do
	local g=B.HeroPromotionMultiplier^(v[2]-1)*B.LevelMultiplier^(v[3]-1)
	local power=B.RarityPower[v[4]]*B.WeaponStarMultipliers[v[5]]
	local damage=math.round(40*g*(1+power/40))
	local interval=B.ScheduledInterval(.85/(1+B.RaritySpeed[v[4]]))
	table.insert(anchors,{Floor=v[1],DPS=5*damage/interval,HP=math.round(300*g)})
end
function B.GetFloorStats(floor: number, role: string): any?
	if not B.Integer(floor,1,50) then return nil end
	local multipliers=({REGULAR={2,.015},ELITE={8,.03},BOSS={25,.04}})[role]
	if not multipliers then return nil end
	local a,b=anchors[1],anchors[#anchors]
	for _,v in anchors do if v.Floor<=floor then a=v end;if v.Floor>=floor then b=v;break end end
	local t=a.Floor==b.Floor and 0 or (floor-a.Floor)/(b.Floor-a.Floor)
	local dps=a.DPS*(b.DPS/a.DPS)^t
	local hp=a.HP*(b.HP/a.HP)^t
	return {MaxHP=math.round(dps*multipliers[1]),ATK=math.round(hp*multipliers[2])}
end
return table.freeze(B)
