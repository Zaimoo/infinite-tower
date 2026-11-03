-- tests/hero-targeting.spec.luau
-- Hero auto-targeting (HeroTargeting.Select, run by CombatSimulation every 5 Hz tick).
-- Regressions: a mob that respawns beside an idle squad, and a recall into a camp.
local T=require(nodes["ServerScriptService.Combat.HeroTargeting"])
local passed,failed=0,0
local function test(name,fn)
	local ok,err=pcall(fn);if ok then passed+=1;print("PASS "..name) else failed+=1;print("FAIL "..name..": "..tostring(err)) end
end
local function hero(x,z,range) return {NetId=1,FloorId=3,RoomGeneration=1,Position=Vector3.new(x,0,z),AttackRange=range or 6,State="FOLLOW_MASTER"} end
local function mob(x,z) return {FloorId=3,RoomGeneration=1,IsAlive=true,Position=Vector3.new(x,0,z)} end
local function eligible(h,m) return m.IsAlive and m.FloorId==h.FloorId and m.RoomGeneration==h.RoomGeneration and not m.Safe end
local function free(mx,mz) return {MasterPos=Vector3.new(mx or 0,0,mz or 0),Assigned=false,Leash=65} end
-- One sim tick for a hero; pacifiedUntil mirrors the recall's 2 s aggro drop.
local function tick(h,mobs,ctx,now,pacifiedUntil,assist) return T.Select(h,mobs,ctx,eligible,now<(pacifiedUntil or 0),assist) end

test("Idle hero picks up a mob that respawns inside its attack range on the next tick",function()
	local h,m=hero(2,0),mob(5,0);local mobs={[40]=m}
	assert(tick(h,mobs,free(),0)==m and h.TargetNetId==40 and h.State=="MOVE_TO_TARGET")
	m.IsAlive=false
	assert(tick(h,mobs,free(),.2)==nil and h.TargetNetId==nil and h.State=="FOLLOW_MASTER","dead target is released")
	for t=.4,2,.2 do assert(tick(h,mobs,free(),t)==nil and h.State=="FOLLOW_MASTER") end
	m.IsAlive=true -- camp wave respawn: same slot, same NetId
	assert(tick(h,mobs,free(),2.2)==m and h.TargetNetId==40 and h.State=="MOVE_TO_TARGET")
end)
test("A cached NetId whose mob comes back alive never leaves the hero following",function()
	-- The old sim kept TargetNetId after a failed scan, so a respawn under the same NetId resolved
	-- as a live target while State stayed FOLLOW_MASTER, and the hero never attacked.
	local h,m=hero(0,0),mob(4,0);h.TargetNetId=40;h.State="FOLLOW_MASTER"
	assert(tick(h,{[40]=m},free(),0)==m and h.State=="MOVE_TO_TARGET")
end)
test("A mob inside a ranged hero's attack range counts even when it is far from the Master",function()
	local h=hero(20,0,28);local m=mob(44,0) -- 44 studs from the Master, 24 from the hero
	assert(tick(h,{[7]=m},free(),0)==m and h.TargetNetId==7)
	local melee=hero(20,0,6);assert(tick(melee,{[7]=m},free(),0)==nil and melee.State=="FOLLOW_MASTER")
end)
test("Recall into a camp: pacified for 2 s, then the nearest live mob is picked up",function()
	local mobs={[11]=mob(6,0),[12]=mob(3,1),[13]=mob(-9,4)}
	local h=hero(1,0);h.TargetNetId=11;h.State="ATTACKING"
	local recallAt=10;local pacifiedUntil=recallAt+2
	for t=recallAt,pacifiedUntil-.2,.2 do
		assert(tick(h,mobs,free(),t,pacifiedUntil)==nil and h.TargetNetId==nil and h.State=="FOLLOW_MASTER","no aggro while pacified")
	end
	assert(tick(h,mobs,free(),pacifiedUntil,pacifiedUntil)==mobs[12] and h.TargetNetId==12 and h.State=="MOVE_TO_TARGET")
end)
test("Recall into a camp that dies and respawns as a wave is fought again",function()
	local mobs={[11]=mob(6,0),[12]=mob(3,1)};local h=hero(0,0)
	assert(tick(h,mobs,free(),12)~=nil)
	mobs[11].IsAlive,mobs[12].IsAlive=false,false
	assert(tick(h,mobs,free(),12.2)==nil and h.TargetNetId==nil)
	mobs[11].IsAlive,mobs[12].IsAlive=true,true
	assert(tick(h,mobs,free(),22.4)==mobs[12] and h.State=="MOVE_TO_TARGET")
end)
test("Safe-zone, other-room, dead and out-of-range mobs are ignored",function()
	local safe=mob(2,0);safe.Safe=true
	local other=mob(3,0);other.RoomGeneration=2
	local dead=mob(1,0);dead.IsAlive=false
	local far=mob(40,0)
	local high=mob(4,0);high.Position=Vector3.new(4,31,0)
	local h=hero(0,0);assert(tick(h,{safe,other,dead,far,high},free(),0)==nil and h.State=="FOLLOW_MASTER")
end)
test("Free-following heroes disengage when the Master walks away",function()
	local m=mob(5,0);local h=hero(2,0)
	assert(tick(h,{[3]=m},free(),0)==m)
	assert(tick(h,{[3]=m},free(40,0),.2)==nil and h.TargetNetId==nil and h.State=="FOLLOW_MASTER","hero 38 studs from the Master")
end)
test("Assigned squads join a squadmate's target before scanning",function()
	local ctx={MasterPos=Vector3.new(0,0,0),Assigned=true,Leash=95}
	local near,ally=mob(3,0),mob(30,0);local h=hero(0,0)
	assert(tick(h,{[1]=near,[2]=ally},ctx,0,0,{2})==ally and h.TargetNetId==2)
	ally.IsAlive=false
	assert(tick(h,{[1]=near,[2]=ally},ctx,.2,0,{2})==near and h.TargetNetId==1)
end)
test("Nearest-mob ties break on the lower NetId",function()
	local h=hero(0,0);assert(tick(h,{[9]=mob(4,0),[5]=mob(-4,0)},free(),0)~=nil and h.TargetNetId==5)
end)
print(string.format("Hero targeting tests: %d passed, %d failed",passed,failed));assert(failed==0)
