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
	-- Consecutive ticks while ally target lives must NOT drop assist commitment for a closer mob in another camp
	assert(tick(h,{[1]=near,[2]=ally},ctx,.1,0,{2})==ally and h.TargetNetId==2)
	ally.IsAlive=false
	assert(tick(h,{[1]=near,[2]=ally},ctx,.2,0,{2})==near and h.TargetNetId==1)
end)
test("Nearest-mob ties break on the lower NetId",function()
	local h=hero(0,0);assert(tick(h,{[9]=mob(4,0),[5]=mob(-4,0)},free(),0)~=nil and h.TargetNetId==5)
end)
test("Unreachable targets are skipped until cooldown, generation or room changes",function()
	local h=hero(0,0);local blocked,other=mob(2,0),mob(8,0)
	blocked.EntityGeneration=4
	h.NavigationRejectedTargets={[1]={Until=15,Generation=4,FloorId=3,RoomGeneration=1}}
	local ctx={MasterPos=Vector3.new(0,0,0),Assigned=true,Leash=95,Now=10}
	h.TargetNetId=1;h.State="MOVE_TO_TARGET"
	assert(T.Select(h,{[1]=blocked,[2]=other},ctx,eligible,false,{1})==other,"cached target, assist and acquisition must all respect failure")
	h.TargetNetId=nil;ctx.Now=16
	assert(T.Select(h,{[1]=blocked},ctx,eligible,false)==blocked)
	h.TargetNetId=nil;ctx.Now=10;blocked.EntityGeneration=5
	assert(T.Select(h,{[1]=blocked},ctx,eligible,false)==blocked,"respawn under the same NetId is fresh")
end)
test("Assigned target acquisition prefers lower connector route cost over shorter straight-line distance across a chasm",function()
	local h=hero(0,0);local chasmMob,rampMob=mob(12,0),mob(22,0)
	local ctx={
		MasterPos=Vector3.new(0,0,0),
		Assigned=true,
		Leash=95,
		Now=0,
		RouteCost=function(_from,to)
			return if to.X==12 then 85 else 28
		end,
	}
	assert(T.Select(h,{[1]=chasmMob,[2]=rampMob},ctx,eligible,false)==rampMob and h.TargetNetId==2)
end)
test("Target lock hysteresis: competing mob < 12 studs closer does NOT switch, >= 12 studs closer DOES switch", function()
	local h = hero(0, 0)
	local target1 = mob(20, 0)
	local target2 = mob(14, 0)
	local target3 = mob(6, 0)
	local mobs = { [1] = target1, [2] = target2, [3] = target3 }

	h.TargetNetId = 1
	h.State = "MOVE_TO_TARGET"
	local ctx = free(0, 0)

	local res = T.Select(h, { [1] = target1, [2] = target2 }, ctx, eligible, false)
	assert(res == target1 and h.TargetNetId == 1, "target lock hysteresis prevents switching to mob only 6 studs closer")

	res = T.Select(h, mobs, ctx, eligible, false)
	assert(res == target3 and h.TargetNetId == 3, "competing mob >= 12 studs closer triggers target switch")
end)

test("Focus target instantly overrides hysteresis and maintains lock", function()
	local h = hero(0, 0)
	local m1 = mob(5, 0)
	local m2 = mob(25, 0)
	local mobs = { [1] = m1, [2] = m2 }
	local ctx = free(0, 0)
	ctx.FocusedTargetNetId = 2

	local res = T.Select(h, mobs, ctx, eligible, false)
	assert(res == m2 and h.TargetNetId == 2 and h.IsFocusTarget == true, "Focus target instantly locks onto clicked mob")

	ctx.FocusedTargetNetId = nil
	res = T.Select(h, mobs, ctx, eligible, false)
	assert(res == m2 and h.TargetNetId == 2, "Focus target remains locked against closer competing mob")
end)

test("Elevation-weighted distance applies 2.5x vertical penalty across diagonal ramp height gaps", function()
	local h = hero(0, 0)
	local mobFlat = mob(10, 0)
	local mobElevated = mob(8, 0); mobElevated.Position = Vector3.new(8, 6, 0)
	local mobs = { [1] = mobElevated, [2] = mobFlat }
	local ctx = free(0, 0)

	local res = T.Select(h, mobs, ctx, eligible, false)
	assert(res == mobFlat and h.TargetNetId == 2, "Elevation penalty prioritizes platform mob over ramp-elevated mob")
end)

test("Deterministic tie-breaker resolves nearly identical distances (< 4 studs) by lowest EntityId / SpawnOrder", function()
	local h = hero(0, 0)
	local mobA = mob(15, 0); mobA.EntityId = 50; mobA.SpawnOrder = 50
	local mobB = mob(16, 0); mobB.EntityId = 10; mobB.SpawnOrder = 10
	local mobs = { [1] = mobA, [2] = mobB }
	local ctx = free(0, 0)
	ctx.TieBreakerMargin = T.TIE_BREAKER_MARGIN

	local best = T.Acquire(h, mobs, ctx, eligible, nil)
	assert(best == 2, "Tie-breaker selects mobB due to lower EntityId/SpawnOrder (10 vs 50)")
end)

test("Assigned squad on diagonal ramp does not alternate or split when both end camps spawn", function()
	local campLower = mob(-110, 75); campLower.Position = Vector3.new(-110, 0, 75); campLower.CampId = "CAMP_BASIN_WEST"
	local campUpper = mob(-106, -25); campUpper.Position = Vector3.new(-106, 8, -25); campUpper.CampId = "CAMP_WEST_GALLERY"
	local mobs = { [10] = campLower, [20] = campUpper }

	-- Front hero near top of ramp, back hero near bottom of ramp; squad assist is committed to campUpper (20)
	local hFront = hero(-52, 26); hFront.Position = Vector3.new(-52, 7, 26)
	local hBack = hero(-35, 42); hBack.Position = Vector3.new(-35, 1, 42)
	local ctx = {
		MasterPos = campUpper.Position,
		Assigned = true,
		Leash = 1000,
		Now = 1.0,
		RouteCost = function(from, to)
			return (to - from).Magnitude
		end,
	}
	local assist = { 20 }

	for step = 1, 10 do
		ctx.Now = step * 0.1
		local resFront = T.Select(hFront, mobs, ctx, eligible, false, assist)
		local resBack = T.Select(hBack, mobs, ctx, eligible, false, assist)
		assert(resFront == campUpper and hFront.TargetNetId == 20, "Front hero lost lock on squad camp")
		assert(resBack == campUpper and hBack.TargetNetId == 20, "Back hero split to lower camp instead of staying with squad")
	end

	-- Even if hBack temporarily rejects mob 20 while teammates remain committed to CAMP_WEST_GALLERY,
	-- hBack must regroup (FOLLOW_MASTER) rather than peeling off to CAMP_BASIN_WEST (10).
	campUpper.EntityGeneration = 1
	hBack.NavigationRejectedTargets = { [20] = { Until = 6.0, Generation = 1, FloorId = 3, RoomGeneration = 1 } }
	ctx.Now = 2.0
	local resRejected = T.Select(hBack, mobs, ctx, eligible, false, assist)
	assert(resRejected == nil and hBack.State == "FOLLOW_MASTER", "Hero with rejected camp mob split to opposing camp")
end)
print(string.format("Hero targeting tests: %d passed, %d failed",passed,failed));assert(failed==0)
