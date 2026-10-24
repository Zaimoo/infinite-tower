local A=require(nodes["ReplicatedStorage.Shared.Util.AttackTimeline"])
local S=require(nodes["ReplicatedStorage.Shared.Util.EnemyActionState"])
local C=require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local Clips=require(nodes["ReplicatedStorage.Assets.TowerEnemyClips"])
local Layout=require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local passed,failed=0,0
local function test(name,fn)
	local ok,err=pcall(fn);if ok then passed+=1;print("PASS "..name) else failed+=1;print("FAIL "..name..": "..tostring(err)) end
end
local function actor(id,x,z)
	return {NetId=id,EntityGeneration=1,FloorId=1,RoomGeneration=1,CurrentHP=100,IsAlive=true,Position=Vector3.new(x,0,z),Yaw=0,EnemyId="mob_moss_crawler"}
end
local function fixture()
	local m,h=actor(1,0,0),actor(2,0,-4)
	local d=C.Get(m.EnemyId).Attacks[1];local a=A.Start(m,h,d,10)
	return m,h,d,a
end
local function safe(e) return e.Safe==true end
test("Combat registry contains all 40 complete runtime enemies, clips, and all 50 floors",function()
	local n=0;for enemyId,e in pairs(C.Entries) do n+=1;assert(#e.RequiredSlots>=5);assert(e.ModelSource and e.ClipSource)
		local clipSet=assert(Clips[enemyId],"Missing clip set for "..enemyId)
		for _,slot in e.RequiredSlots do
			local frames=assert(clipSet[slot],"Missing slot "..slot.." for "..enemyId)
			assert(Clips.Sample(frames,0) and Clips.Sample(frames,.5) and Clips.Sample(frames,.8) and Clips.Sample(frames,1))
		end
		for _,a in e.Attacks do assert(a.ImpactOffsetSeconds>=.6 and a.RecoverySeconds>0 and a.Range>0 and a.DamageMultiplier>0) end
	end
	assert(n==40 and C.ReleaseEnabled)
	for floorId=1,50 do
		local placements=assert(C.Floors[floorId],"Missing placements on floor "..floorId)
		assert(#placements>=3)
		local bosses=0
		for _,p in placements do
			local spec=assert(C.Get(p.EnemyId))
			local safe=Layout.Get((floorId-1)%5+1).Sanctuary
			assert(math.abs(p.X)>safe.Width/2 or math.abs(p.Z-safe.Z)>safe.Depth/2,"Placement inside arrival safe zone on floor "..floorId)
			if spec.Role=="BOSS" then bosses+=1 end
		end
		assert(bosses==(floorId%5==0 and 1 or 0),"Invalid boss count on floor "..floorId)
	end
end)
test("Windup sends an identity-qualified future impact without applying damage",function()
	local m,h,d,a=fixture();local hits=0
	assert(A.Step(a,m,h,d,10.6,safe,{h},function() hits+=1 end)==nil)
	assert(hits==0 and a.Status=="WINDUP" and a.Target.EntityGeneration==1 and a.ActionSequence==1)
end)
test("Repeated ticks and duplicate victim entries apply exactly one impact",function()
	local m,h,d,a=fixture();local hits=0
	for i=1,10 do A.Step(a,m,h,d,10.7+i*.001,safe,{h,h},function() hits+=1 end) end
	assert(hits==1 and a.Impacted and a.Status=="RECOVERY")
	assert(A.Step(a,m,h,d,11.4,safe,{h},function() error("Repeated impact") end)=="COMPLETE")
end)
for _,case in {"actor dies","target dies","actor changes floor","target changes floor","actor generation changes","target generation changes","target enters safety","actor enters safety","target disappears"} do
	test("Windup cancels when "..case,function()
		local m,h,d,a=fixture()
		if case=="actor dies" then m.CurrentHP=0 elseif case=="target dies" then h.CurrentHP=0
		elseif case=="actor changes floor" then m.FloorId=5 elseif case=="target changes floor" then h.FloorId=5
		elseif case=="actor generation changes" then m.EntityGeneration=2 elseif case=="target generation changes" then h.EntityGeneration=2
		elseif case=="target enters safety" then h.Safe=true elseif case=="actor enters safety" then m.Safe=true else h=nil end
		assert(A.Step(a,m,h,d,10.7,safe,{},function() error("Ghost hit") end)=="CANCEL")
		assert(not A.Cancel(a,"REPEAT"))
	end)
end
test("Long server stall expires impact instead of applying a catch-up hit",function()
	local m,h,d,a=fixture();assert(A.Step(a,m,h,d,12,safe,{h},function() error("Late ghost hit") end)=="CANCEL")
end)
test("Arc excludes victims behind, out of range, above, safe, or in another room",function()
	local m,h,d,a=fixture();local victims={h,actor(3,0,4),actor(4,0,-8),actor(5,0,-4),actor(6,0,-4),actor(7,0,-4),actor(8,0,-4)}
	victims[4].Position=Vector3.new(0,20,-4);victims[5].Safe=true;victims[6].FloorId=5;victims[7].RoomGeneration=2
	local hits={};A.Step(a,m,h,d,10.7,safe,victims,function(v) table.insert(hits,v.NetId) end)
	assert(#hits==1 and hits[1]==h.NetId)
end)
test("Ground cast aim remains fixed and can be dodged during anticipation",function()
	local m,h=actor(1,0,0),actor(2,0,-20);m.EnemyId="elite_vinebound"
	local d=C.Get(m.EnemyId).Attacks[2];local a=A.Start(m,h,d,10)
	h.Position=Vector3.new(20,0,-20);local bystander=actor(3,0,-20);local hits={}
	A.Step(a,m,h,d,11.5,safe,{h,bystander},function(v) table.insert(hits,v.NetId) end)
	assert(#hits==1 and hits[1]==3 and a.Aim.X==0)
end)
test("Ranged projectile sweeps corridor at impact time and can be dodged laterally",function()
	local m,h=actor(1,0,0),actor(2,0,-24);m.EnemyId="mob_lantern_spore"
	local d=C.Get(m.EnemyId).Attacks[1]
	assert(d.Shape=="PROJECTILE" and d.TravelSeconds>0 and d.ImpactOffsetSeconds==d.WindupSeconds+d.TravelSeconds)
	local a=A.Start(m,h,d,10)
	h.Position=Vector3.new(10,0,-24) -- dodges laterally out of corridor
	local inCorridor=actor(3,0,-12)
	local hits={}
	A.Step(a,m,h,d,11.05,safe,{h,inCorridor},function(v) table.insert(hits,v.NetId) end)
	assert(#hits==1 and hits[1]==3)
end)
test("Each life action counter advances and cancellation is terminal",function()
	local m,h,d,a=fixture();assert(A.Cancel(a,"LEASH"));assert(A.Step(a,m,h,d,10.7,safe,{h},function() error("Canceled") end)==nil)
	assert(A.Start(m,h,d,11).ActionSequence==2)
end)
local function presentation()
	local m,h,d,a=fixture();a.Kind="START";local meta={[m.NetId]=A.Identity(m)}
	return S.New(),a,meta,m
end
test("Client accepts a late START with original time and deduplicates it",function()
	local s,a,meta= presentation();assert(S.Receive(s,a,meta,10.5));assert(not S.Receive(s,a,meta,10.6))
	assert(s.Actors[S.Key(a.Actor)].Action.StartServerTime==10)
end)
test("Completed late action records sequence without restarting effects",function()
	local s,a,meta= presentation();assert(not S.Receive(s,a,meta,12));assert(S.Expected(s,a.Actor,1));assert(not S.Receive(s,a,meta,10))
end)
test("Cancellation arriving before delayed START cannot resurrect the attack",function()
	local s,a,meta= presentation();local cancel=table.clone(a);cancel.Kind="CANCEL"
	assert(S.Receive(s,cancel,meta,10.2));assert(not S.Receive(s,a,meta,10.3))
end)
test("Death tombstone rejects delayed START and older generation cannot kill a new one",function()
	local s,a,meta,m= presentation();local death={Kind="DEATH",Actor=A.Identity(m)}
	assert(S.Receive(s,death,meta,10.2));assert(not S.Receive(s,a,meta,10.3))
	m.EntityGeneration=2;meta[1]=A.Identity(m);a.Actor=A.Identity(m)
	assert(S.Receive(s,a,meta,10.3))
end)
test("Missing reliable action is detectable from snapshot without inventing a hit",function()
	local s,a,meta= presentation();assert(not S.Expected(s,a.Actor,1));assert(S.Expected(s,a.Actor,0))
	S.Receive(s,a,meta,10.2);assert(S.Expected(s,a.Actor,1));assert(not S.Expected(s,a.Actor,2))
end)
test("Old sequences, wrong generation and unknown identities reject on client",function()
	local s,a,meta= presentation();a.ActionSequence=4;assert(S.Receive(s,a,meta,10.2))
	local old=table.clone(a);old.ActionSequence=3;assert(not S.Receive(s,old,meta,10.2))
	old.Actor=table.clone(a.Actor);old.Actor.EntityGeneration=2;assert(not S.Receive(s,old,meta,10.2));assert(not S.Receive(S.New(),a,{},10.2))
end)
print(string.format("Tower combat tests: %d passed, %d failed",passed,failed));assert(failed==0)
