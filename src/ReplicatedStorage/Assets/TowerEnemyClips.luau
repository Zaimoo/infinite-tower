--!strict
-- Authored pose keyframes in normalized clip time. Native source, no asset IDs.
-- One dedicated player owns these joints; the generic hero animator never touches them.
local C={}
local function rot(x,y,z) return CFrame.Angles(math.rad(x or 0),math.rad(y or 0),math.rad(z or 0)) end
local function pose(body,arms,head)
	return {Body=body or CFrame.identity,ArmL=rot(arms or 0,0,-5),ArmR=rot(arms or 0,0,5),Head=rot(head or 0)}
end
local idle={ {0,pose(rot(-1),-3,1)}, {.5,pose(rot(1),2,-1)}, {1,pose(rot(-1),-3,1)} }
local hit={ {0,{Body=rot(0)}}, {.18,{Body=rot(-9,0,3),Head=rot(-8)}}, {1,{Body=CFrame.identity,Head=CFrame.identity}} }
local death={ {0,pose()}, {.23,pose(CFrame.new(0,-.45,0)*rot(15),-20,-20)},
	{.7,pose(CFrame.new(0,-2,0)*rot(68),-65,15)}, {1,pose(CFrame.new(0,-2.4,0)*rot(78),-75,20)} }
local cleave={ {0,pose()}, {.55,pose(rot(-12,-24),-105,-8)}, {.76,pose(rot(-15,-32),-125,-10)},
	{.8,pose(rot(22,30),35,12)}, {1,pose()} }
local cast={ {0,pose()}, {.45,pose(rot(-6),-80,-10)}, {.76,pose(rot(-12),-130,-18)},
	{.8,pose(rot(13),-35,12)}, {1,pose()} }
local slam={ {0,pose()}, {.35,pose(rot(-10),-100,-12)}, {.72,pose(rot(-18),-160,-20)},
	{.8,pose(CFrame.new(0,-.4,0)*rot(28),30,18)}, {.9,pose(rot(20),20,8)}, {1,pose()} }
local sweep={ {0,pose()}, {.5,pose(rot(-8,-45),-75,-8)}, {.76,pose(rot(-10,-65),-95,-12)},
	{.8,pose(rot(12,65),-25,12)}, {1,pose()} }
local walk={}
for i=0,4 do
	local phase=i/4;local p=pose();local shift=({0,1,0,-1,0})[i+1]
	p.LegL=CFrame.new(0,shift>0 and .2 or 0,-shift*.32)*rot(shift*24)
	p.LegR=CFrame.new(0,shift<0 and .2 or 0,shift*.32)*rot(-shift*24)
	p.KneeL=rot(math.max(0,shift)*-25);p.KneeR=rot(math.max(0,-shift)*-25)
	p.ArmL=rot(-shift*12);p.ArmR=rot(shift*12)
	table.insert(walk,{phase,p})
end
local crawl={}
for i=0,4 do
	local phase=i/4;local shift=({0,1,0,-1,0})[i+1];local p={}
	for _,side in {-1,1} do for leg=1,3 do
		local value=shift*(leg%2==0 and -1 or 1)*side
		p["Leg"..side.."_"..leg]=CFrame.new(0,math.max(0,value)*.35,0)*rot(0,value*18,0)
		p["Knee"..side.."_"..leg]=rot(0,0,side*math.max(0,value)*-20)
	end end
	table.insert(crawl,{phase,p})
end
local bite={ {0,{Body=CFrame.identity,Head=rot(0),JawL=rot(0),JawR=rot(0)}},
	{.6,{Body=CFrame.new(0,-.15,.55)*rot(-8),Head=rot(-12),JawL=rot(0,-32),JawR=rot(0,32)}},
	{.8,{Body=CFrame.new(0,0,-.6)*rot(10),Head=rot(15),JawL=rot(0,18),JawR=rot(0,-18)}},
	{1,{Body=CFrame.identity,Head=CFrame.identity,JawL=CFrame.identity,JawR=CFrame.identity}} }
C.mob_moss_crawler={Idle=idle,Locomotion=crawl,BasicAttack=bite,HitReaction=hit,Death={
	{0,{Body=CFrame.identity}},{.4,{Body=CFrame.new(0,-.65,0)*rot(0,0,24)}},{1,{Body=CFrame.new(0,-.95,0)*rot(0,0,35)}}}}
C.elite_vinebound={Idle=idle,Locomotion=walk,BasicAttack=cleave,Special=cast,HitReaction=hit,Death=death}
C.boss_mossbound_guardian={Idle=idle,Locomotion=walk,BasicAttack=slam,Signature1=slam,Signature2=sweep,
	Awakening={{0,pose(CFrame.new(0,-1.2,0)*rot(22),20,28)},{.6,pose(rot(-8),-45,-15)},{1,pose()}},HitReaction=hit,Death=death}
function C.Sample(frames: any,t: number): any
	t=math.clamp(t,0,1);local a,b=frames[1],frames[#frames]
	for i=2,#frames do if t<=frames[i][1] then a=frames[i-1];b=frames[i];break end end
	local alpha=math.clamp((t-a[1])/math.max(.0001,b[1]-a[1]),0,1);alpha=alpha*alpha*(3-2*alpha)
	local result={};local keys={}
	for key in pairs(a[2]) do keys[key]=true end;for key in pairs(b[2]) do keys[key]=true end
	for key in pairs(keys) do result[key]=(a[2][key] or CFrame.identity):Lerp(b[2][key] or CFrame.identity,alpha) end
	return result
end
return C
