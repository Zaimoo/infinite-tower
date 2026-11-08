local Graph=require(nodes["ServerScriptService.Core.TowerNavigationGraph"])
local Recovery=require(nodes["ServerScriptService.Core.NavigationRecovery"])
local Queue=require(nodes["ServerScriptService.Core.NavigationQueue"])
local Layout=require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local Traversal=require(nodes["ServerScriptService.Core.TowerTraversal"])
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
test("TowerTraversal diagonal ramp commitment and bounds detection", function()
	assert(Traversal.RAMP_COMMITMENT_WINDOW == 0.8)
	local rampLink = { Kind = "RAMP", AY = 0, BY = 8 }
	local flatLink = { Kind = "BRIDGE", AY = 0, BY = 0 }
	assert(Traversal.IsDiagonalRamp(rampLink) == true)
	assert(Traversal.IsDiagonalRamp(flatLink) == false)

	assert(Traversal.IsMidRamp(0.5) == true)
	assert(Traversal.IsMidRamp(0.02) == false)
	assert(Traversal.IsMidRamp(0.98) == false)

	assert(Traversal.ShouldCommitDirection(10.0, 10.5) == true, "0.5s < 0.8s commits direction")
	assert(Traversal.ShouldCommitDirection(10.0, 10.85) == false, "0.85s >= 0.8s releases commitment")
end)
test("Recessed diagonal ramps route around curb walls via landing porch in both directions and classify lower deck as connector", function()
	local layout = Layout.Get(1)
	local g = Graph.new(layout)
	local link
	for _, l in layout.Links do
		if l.Id == "Basin_WestGallery" then link = l; break end
	end
	assert(link ~= nil)
	local a, b = p(link.AX, link.AY, link.AZ), p(link.BX, link.BY, link.BZ)
	local lowDeck = lerp(a, b, 0.02) -- Y = 0.16 < 0.25 inside Basin bounds
	local loc = Graph.Locate(g, lowDeck)
	assert(loc.Key == "C:Basin_WestGallery", "Lower ramp deck misclassified as platform: " .. tostring(loc.Key))

	local campBasinWest = p(-102.3, 0, 59.7)
	local campWestGallery = p(-106.4, 8, -25.2)

	-- Going UP from behind the ramp curb (CAMP_BASIN_WEST -> CAMP_WEST_GALLERY) inserts porch before A
	local upRoute = Graph.Route(g, campBasinWest, campWestGallery)
	local aIndex = nil
	for i, pt in ipairs(upRoute) do
		if Graph.Distance(pt, a) < 0.01 then aIndex = i; break end
	end
	assert(aIndex and aIndex >= 3, "Missing porch waypoint before ramp entrance A")
	local porchUp = upRoute[aIndex - 1]
	local alongUp = (porchUp.X - a.X) * link.UX + (porchUp.Z - a.Z) * link.UZ
	assert(alongUp <= -10, "Approach porch is not in front of ramp mouth A")

	-- Going DOWN (CAMP_WEST_GALLERY -> CAMP_BASIN_WEST) inserts porch after A before turning behind curb
	local downRoute = Graph.Route(g, campWestGallery, campBasinWest)
	local downAIndex = nil
	for i, pt in ipairs(downRoute) do
		if Graph.Distance(pt, a) < 0.01 then downAIndex = i; break end
	end
	assert(downAIndex and downRoute[downAIndex + 1], "Missing waypoint after ramp exit A")
	local porchDown = downRoute[downAIndex + 1]
	local alongDown = (porchDown.X - a.X) * link.UX + (porchDown.Z - a.Z) * link.UZ
	assert(alongDown <= -10, "Exit porch is not in front of ramp mouth A")

	-- Same-platform segment starting just outside A toward CAMP_BASIN_WEST detours via porch
	local justOutsideA = p(a.X - link.UX * 1.5, a.Y, a.Z - link.UZ * 1.5)
	local samePlatRoute = Graph.Route(g, justOutsideA, campBasinWest)
	assert(#samePlatRoute == 2 and ((samePlatRoute[1].X - a.X) * link.UX + (samePlatRoute[1].Z - a.Z) * link.UZ) <= -10,
		"Same-platform route cut through recessed ramp curb")
end)
print(string.format("Tower navigation tests: %d passed",passed))
