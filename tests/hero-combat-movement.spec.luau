-- tests/hero-combat-movement.spec.luau
-- Fight positioning (HeroCombatMovement.Plan, run by CombatSimulation between a hero's attacks):
-- telegraph evasion, ranged kiting and spreading, melee ring slots.
local M=require(nodes["ServerScriptService.Combat.HeroCombatMovement"])
local passed,failed=0,0
local function test(name,fn)
	local ok,err=pcall(fn);if ok then passed+=1;print("PASS "..name) else failed+=1;print("FAIL "..name..": "..tostring(err)) end
end
local function v(x,z) return Vector3.new(x,0,z) end
local function flat(a,b) local dx,dz=a.X-b.X,a.Z-b.Z;return math.sqrt(dx*dx+dz*dz) end
-- Sim yaw convention: facing = (-sin yaw, 0, -cos yaw). Yaw 0 faces -Z, yaw pi faces +Z.
local function input(over)
	local i={NetId=2,Position=v(0,5),AttackRange=6,Archetype="Striker",BaseSpeed=20,TargetNetId=40,
		TargetPosition=v(0,0),TargetYaw=math.pi,TargetAimsAtHero=false,Allies={},Hostiles={},Threats={}}
	for k,value in over or {} do i[k]=value end
	return i
end
local function arc(over)
	local t={Shape="ARC",Origin=v(0,0),Aim=v(0,5),Yaw=math.pi,Range=12,Radius=0,HalfArcCos=math.cos(math.rad(50)),TimeToImpact=.7,Age=.3}
	for k,value in over or {} do t[k]=value end
	return t
end

test("InDanger matches the arc, disc and projectile shapes the hit uses",function()
	local a=arc()
	assert(M.InDanger(a,v(0,5)) and M.InDanger(a,v(3,5)),"inside the swing")
	assert(not M.InDanger(a,v(0,-5)),"behind the attacker")
	assert(not M.InDanger(a,v(0,13)),"past its reach")
	assert(not M.InDanger(a,Vector3.new(0,20,5)),"a terrace above is never hit")
	local disc={Shape="TARGET_DISC",Origin=v(30,0),Aim=v(0,0),Yaw=0,Range=60,Radius=7,TimeToImpact=1,Age=1}
	assert(M.InDanger(disc,v(6,0)) and not M.InDanger(disc,v(8,0)))
	local lane={Shape="PROJECTILE",Origin=v(0,0),Aim=v(0,40),Yaw=0,Range=40,Radius=2.6,TimeToImpact=1,Age=1}
	assert(M.InDanger(lane,v(2,20)) and not M.InDanger(lane,v(4,20)) and not M.InDanger(lane,v(0,44)))
end)
test("A Striker in a swing walks round to its edge and ends up outside it",function()
	local a=arc()
	local plan=M.Plan(input({Threats={a}}))
	assert(plan and plan.Kind=="EVADE","expected an evade")
	assert(not M.InDanger(a,plan.Goal),"escape point is still inside the swing")
	assert(flat(plan.Goal,v(0,5))<9,"flanking is shorter than backing out of a 12-stud reach")
	assert(plan.Deadline==.7 and plan.Speed==20)
end)
test("Every escape point is clear of its telegraph, including dead-centre stacks",function()
	local shapes={
		arc(),arc({HalfArcCos=math.cos(math.rad(135)),Range=20,TimeToImpact=5}),
		{Shape="SELF_DISC",Origin=v(0,0),Aim=v(0,0),Yaw=0,Range=16,Radius=16,TimeToImpact=5,Age=1},
		{Shape="TARGET_DISC",Origin=v(40,0),Aim=v(1,4),Yaw=0,Range=60,Radius=7,TimeToImpact=5,Age=1},
		{Shape="PROJECTILE",Origin=v(0,-20),Aim=v(0,20),Yaw=0,Range=40,Radius=2.6,TimeToImpact=5,Age=1},
	}
	for _,threat in shapes do
		for _,spot in {v(0,5),v(0,0),v(1,4),v(-2,3),v(.5,10)} do
			for netId=1,4 do
				local goal=M.EscapePoint(threat,spot,netId)
				if M.InDanger(threat,spot) then
					assert(goal and not M.InDanger(threat,goal),threat.Shape.." escape stays in danger")
				else
					assert(goal==nil,"no escape needed outside the shape")
				end
			end
		end
	end
	-- Two heroes on the projectile's centre line split to opposite sides.
	local lane=shapes[5]
	local a,b=M.EscapePoint(lane,v(0,5),1),M.EscapePoint(lane,v(0,5),2)
	assert(a.X*b.X<0,"stacked heroes dodge the same way")
end)
test("A telegraph that cannot be left in time is not dodged",function()
	local disc={Shape="SELF_DISC",Origin=v(0,0),Aim=v(0,0),Yaw=0,Range=26,Radius=26,TimeToImpact=.6,Age=1}
	local plan=M.Plan(input({Threats={disc},EvadeOnly=true}))
	assert(plan==nil,"21 studs in 0.6 s is out of reach at 20 studs/s")
	disc.TimeToImpact=2
	plan=M.Plan(input({Threats={disc},EvadeOnly=true}))
	assert(plan and plan.Kind=="EVADE")
end)
test("Telegraphs are noticed after the reaction delay, and never once they have landed",function()
	assert(M.Plan(input({Threats={arc({Age=.1})},EvadeOnly=true}))==nil,"dodged before the reaction delay")
	assert(M.Plan(input({Threats={arc({TimeToImpact=0})},EvadeOnly=true}))==nil,"dodged a landed hit")
end)
test("Vanguards and Berserkers hold their ground in a telegraph",function()
	for _,archetype in {"Vanguard","Berserker"} do
		local plan=M.Plan(input({Archetype=archetype,Threats={arc()},EvadeOnly=true}))
		assert(plan==nil,archetype.." should not evade")
	end
	for _,archetype in {"Striker","Marksman","Scholar","Healer"} do
		local plan=M.Plan(input({Archetype=archetype,Threats={arc()},EvadeOnly=true}))
		assert(plan and plan.Kind=="EVADE",archetype.." should evade")
	end
end)
test("A hero never dodges out of one telegraph into another",function()
	local a=arc()
	local goal=M.EscapePoint(a,v(0,5),2)
	local trap={Shape="TARGET_DISC",Origin=v(40,0),Aim=goal,Yaw=0,Range=60,Radius=3,TimeToImpact=1.5,Age=1}
	assert(M.Plan(input({Threats={a,trap},EvadeOnly=true}))==nil)
end)
test("A Striker circles toward the target's back in bounded steps, unless the target faces it",function()
	-- Target faces +Z (yaw pi); the Striker stands in front at (0,5), so the back is at -Z.
	local i=input()
	local position=i.Position
	local previous=math.huge
	for _=1,8 do
		i.Position=position
		local plan=M.Plan(i)
		if not plan then break end
		assert(plan.Kind=="FLANK")
		assert(math.abs(flat(plan.Goal,v(0,0))-4.8)<.01,"slot is on the ring at 80% of range")
		-- Chord of RING_STEP on the ring, plus the 0.2 studs the first step spends stepping onto it.
		assert(flat(plan.Goal,position)<=2*4.8*math.sin(M.RING_STEP/2)+.25,"one manoeuvre walks at most RING_STEP round the ring")
		position=plan.Goal
		local toBack=flat(position,v(0,-4.8))
		assert(toBack<previous,"each step gets closer to the back")
		previous=toBack
	end
	assert(flat(position,v(0,-4.8))<M.DEADBAND+.01,"ends behind the target")
	assert(M.Plan(input({TargetAimsAtHero=true}))==nil,"a target looking at the hero has no back to reach")
end)
test("Melee heroes on one target take separate ring slots; a hero still walking in takes none",function()
	local ally={NetId=1,Position=v(.4,4.8),AttackRange=6,TargetNetId=40}
	local plan=M.Plan(input({Archetype="Berserker",Position=v(0,4.8),Allies={ally}}))
	assert(plan and plan.Kind=="FLANK")
	assert(flat(plan.Goal,ally.Position)>=M.MELEE_SPACING-.3,"slots are spaced along the ring")
	assert(M.Plan(input({Archetype="Berserker",Position=v(0,4.8),Allies={{NetId=1,Position=v(0,14),AttackRange=6,TargetNetId=40}}}))==nil)
	assert(M.Plan(input({Archetype="Berserker",Position=v(0,4.8),Allies={{NetId=1,Position=v(.4,4.8),AttackRange=6,TargetNetId=41}}}))==nil,"allies on another target do not count")
	-- Two heroes on the exact same spot split in opposite directions.
	local a=M.Plan(input({Archetype="Berserker",NetId=3,Position=v(0,4.8),Allies={{NetId=4,Position=v(0,4.8),AttackRange=6,TargetNetId=40}}}))
	local b=M.Plan(input({Archetype="Berserker",NetId=4,Position=v(0,4.8),Allies={{NetId=3,Position=v(0,4.8),AttackRange=6,TargetNetId=40}}}))
	assert(a and b and a.Goal.X*b.Goal.X<0,"stacked heroes pick the same side")
end)
test("A Vanguard stands between the target and the squad's ranged heroes",function()
	local archer={NetId=5,Position=v(20,0),AttackRange=28,TargetNetId=40}
	local plan=M.Plan(input({Archetype="Vanguard",Position=v(0,4.8),Allies={archer}}))
	assert(plan and plan.Kind=="FLANK" and plan.Goal.X>0,"moves toward the backline's side")
	assert(M.Plan(input({Archetype="Vanguard",Position=v(4.8,0),Allies={archer}}))==nil,"already guarding")
end)
test("A ranged hero kites a mob that closed in, without leaving its own range or the Master's leash",function()
	local function ranged(over)
		local i=input({Archetype="Marksman",AttackRange=28,Position=v(0,20),Hostiles={{NetId=40,Position=v(0,0)}}})
		for k,value in over or {} do i[k]=value end
		return i
	end
	assert(M.Plan(ranged())==nil,"a mob 20 studs away is no reason to move")
	local chaser={NetId=41,Position=v(0,16)}
	local plan=M.Plan(ranged({Hostiles={{NetId=40,Position=v(0,0)},chaser}}))
	assert(plan and plan.Kind=="KITE")
	assert(flat(plan.Goal,chaser.Position)>4 and plan.Goal.Z>20,"backs away from the chaser")
	assert(flat(plan.Goal,v(0,0))<=28*M.RANGE_BAND+.01,"stays inside its own range")
	assert(plan.Speed==20*M.KITE_SPEED)
	-- Pinned at the edge of its range band: nowhere further to go.
	assert(M.Plan(ranged({Position=v(0,25.2),Hostiles={{NetId=41,Position=v(0,21)}}}))==nil)
	-- The Master's tether wins over kiting.
	assert(M.Plan(ranged({Hostiles={chaser},LeashCenter=v(0,0),LeashRadius=22}))==nil)
	assert(M.Plan(ranged({Hostiles={chaser},LeashCenter=v(0,0),LeashRadius=30}))~=nil)
	-- A mob on another terrace is not a threat.
	assert(M.Plan(ranged({Hostiles={{NetId=41,Position=Vector3.new(0,12,16)}}}))==nil)
	assert(M.Plan(ranged({Hostiles={chaser},EvadeOnly=true}))==nil,"no positioning while busy")
end)
test("Stacked ranged heroes spread sideways; only the higher NetId moves",function()
	local function ranged(netId,x,ally)
		return input({Archetype="Scholar",NetId=netId,AttackRange=24,Position=v(x,18),Allies={ally}})
	end
	local low,high={NetId=3,Position=v(0,18),AttackRange=24,TargetNetId=40},{NetId=6,Position=v(1,18),AttackRange=24,TargetNetId=40}
	assert(M.Plan(ranged(3,0,high))==nil,"the lower NetId holds its spot")
	local plan=M.Plan(ranged(6,1,low))
	assert(plan and plan.Kind=="SPREAD")
	assert(flat(plan.Goal,low.Position)>=M.RANGED_SPACING,"ends at least the spacing apart")
	local step,fire=plan.Goal-v(1,18),v(0,0)-v(1,18)
	assert(math.abs(step.X*fire.X+step.Z*fire.Z)<.01,"sidesteps across the line of fire, not along it")
	assert(M.Plan(ranged(6,6,low))==nil,"already spaced")
end)
assert(failed==0,failed.." hero combat movement test(s) failed")
print(passed.." hero combat movement tests passed")
