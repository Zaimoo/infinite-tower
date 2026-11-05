local Graph=require(nodes["ServerScriptService.Core.TowerNavigationGraph"])
local Recovery=require(nodes["ServerScriptService.Core.NavigationRecovery"])
local Queue=require(nodes["ServerScriptService.Core.NavigationQueue"])
local Layout=require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local passed=0
local function test(name,fn)fn();passed+=1;print("PASS "..name)end
local function p(x,y,z)return {X=x,Y=y,Z=z}end
local function lerp(a,b,t)return p(a.X+(b.X-a.X)*t,a.Y+(b.Y-a.Y)*t,a.Z+(b.Z-a.Z)*t)end
test("Moving goals on every connector retain forward progress, including reverse travel",function()
	for i=1,5 do
		local layout=Layout.Get(i);local graph=Graph.new(layout)
		for _,link in layout.Links do
			local a,b=p(link.AX,link.AY,link.AZ),p(link.BX,link.BY,link.BZ)
			for _,reverse in {false,true}do
				local from=lerp(a,b,if reverse then .6 else .4)
				local goal=lerp(a,b,if reverse then .15 else .85)
				local route=Graph.Route(graph,from,goal)
				assert(#route==1 and Graph.Distance(route[1],goal)<.001,"Ramp goal sent actor back to entrance: "..link.Id)
			end
		end
	end
end)
test("A mid-ramp actor leaves through the destination end, never the entrance behind it",function()
	local layout=Layout.Get(3);local graph=Graph.new(layout)
	for _,link in layout.Links do
		local a,b=p(link.AX,link.AY,link.AZ),p(link.BX,link.BY,link.BZ)
		local from=lerp(a,b,.4)
		local platform=layout.Platforms[link.To]
		local route=Graph.Route(graph,from,p(platform.X,platform.Y,platform.Z))
		assert(Graph.Distance(route[1],b)<.001,link.Id.." chose the wrong exit")
	end
end)
test("Identical horizontal coordinates on different elevations do not count as arrival",function()
	local route={p(0,10,0)}
	assert(Graph.Remaining(route,1,p(0,0,0))==10)
end)
test("A genuine U-turn on a connector targets the point behind, without replaying the far endpoint",function()
	local l=Layout.Get(3);local g=Graph.new(l);local link=l.Links[2]
	local a,b=p(link.AX,link.AY,link.AZ),p(link.BX,link.BY,link.BZ)
	local goal=lerp(a,b,.2);local route=Graph.Route(g,lerp(a,b,.8),goal)
	assert(#route==1 and Graph.Distance(route[1],goal)<.001)
end)
test("Request results are rejected after route, room, entity, or intent changes",function()
	local original={Revision=1,FloorId=18,RoomGeneration=2,EntityGeneration=3,Intent="TARGET:10"}
	assert(Graph.RequestMatches(original,table.clone(original)))
	for _,key in {"Revision","FloorId","RoomGeneration","EntityGeneration","Intent"}do
		local changed=table.clone(original);changed[key]=if key=="Intent"then "TARGET:11"else changed[key]+1
		assert(not Graph.RequestMatches(original,changed),key)
	end
end)
test("Shuffling reaches repath and unreachable rather than continually restarting the timer",function()
	local state={};local repathed=false;local status
	for i=0,35 do
		status=Recovery.Update(state,"CHASE",i*.1,if i%2==0 then .4 else -.4,20)
		if status=="REPATH"then repathed=true end
	end
	assert(repathed and status=="UNREACHABLE")
end)
test("Legitimate detour progress resets recovery, and attacking pauses its clock",function()
	local s={}
	for i=0,50 do assert(Recovery.Update(s,"CHASE",i*.1,.5,40-i*.5)~="UNREACHABLE")end
	Recovery.Pause(s)
	assert(Recovery.Update(s,"CHASE",100,0,20)=="BLOCKED")
	assert(Recovery.Update(s,"OTHER_TARGET",104,0,20)=="BLOCKED")
end)
test("FIFO work obeys concurrency, cancellation, deduplication and exactly-once completion",function()
	local started,finish={},{}
	local q=Queue.new(2,8,function(job,done)table.insert(started,job.Key);finish[job.Key]=done end)
	q:Push("a",{});q:Push("b",{});q:Push("c",{});q:Push("d",{})
	assert(q.Active==2 and q.Waiting==2 and #started==2)
	assert(q:Push("c",{})==nil)
	q:Cancel("c");q:Cancel("a")
	assert(q.Active==2 and q.Waiting==1)
	finish.a();finish.a()
	assert(started[3]=="d" and q.Active==2)
	finish.b();finish.d()
	assert(q.Active==0 and q.Waiting==0 and q.Count==0)
end)
test("Cancelled queue churn remains bounded and synchronous completions do not recurse",function()
	local done
	local q=Queue.new(1,4,function(_,complete)done=complete end)
	q:Push("active",{})
	for i=1,100 do q:Push(i,{});q:Cancel(i)end
	assert(q.Tail-q.Head<=q.Capacity*2+1)
	done();assert(q.Count==0)
	local completed=0
	local sync=Queue.new(1,4,function(_,complete)completed+=1;complete()end)
	for i=1,100 do sync:Push(i,{})end
	assert(completed==100 and sync.Active==0 and sync.Count==0)
end)
print(string.format("Tower navigation tests: %d passed",passed))
