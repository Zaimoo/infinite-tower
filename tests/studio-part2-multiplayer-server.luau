-- Temporary server test, activated only by StudioTestService argument.
local STS=game:GetService("StudioTestService")
if STS:GetTestArgs()~="TOWER_PART2_MULTI" then return end
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local T=require(game.ServerScriptService.Core.TowerFloorService)
local P=require(RS.Shared.Util.TowerProtocol)
local control=Instance.new("RemoteEvent");control.Name="TowerPart2TestControl";control.Parent=RS
local reports={}
local ready={}
local results={}
control.OnServerEvent:Connect(function(p,sequence,result)
	if sequence=="READY" then ready[p]=true else reports[p]=reports[p] or {};reports[p][sequence]=result end
end)
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds;repeat if fn() then return end;task.wait(.05) until os.clock()>deadline;error("Timeout")
end
local seq=0
local function command(p,action,id)
	task.wait(.65);seq+=1;local key=tostring(seq)
	control:FireClient(p,key,action,id)
	waitFor(function() return reports[p] and reports[p][key] end,13)
	local report=reports[p][key];assert(report.Passed,report.Result)
	if action~="MEASURE" then assert(report.Result.Status=="COMMITTED",report.Result.ErrorCode) end
	return report.Result
end
local function record(name,fn)
	local ok,err=pcall(fn);table.insert(results,{Name=name,Passed=ok,Error=not ok and tostring(err) or nil})
	assert(ok,err)
end
local ok,err=pcall(function()
	waitFor(function() return #Players:GetPlayers()==2 end,30)
	local people=Players:GetPlayers();table.sort(people,function(a,b) return a.UserId<b.UserId end)
	local a,b=people[1],people[2]
	waitFor(function() return ready[a] and ready[b] and a.Character and b.Character and T.GetState(a).SquadSize==2 and T.GetState(b).SquadSize==2 end,30)
	record("Two real clients share floor 50 metadata positions and accurate visitor/squad presence",function()
		command(a,"VISIT",50);command(b,"VISIT",50)
		local first,second=command(a,"MEASURE"),command(b,"MEASURE")
		assert(first.FloorId==50 and second.FloorId==50 and #first.Ids==4 and #second.Ids==4)
		for i,id in first.Ids do assert(second.Ids[i]==id and first.Positions[tostring(id)].X>10000 and second.Positions[tostring(id)].X>10000) end
		for _,view in {first,second} do local floor=view.Presence.Floors[51];assert(#floor.Visitors==2 and #floor.Squads==2) end
	end)
	local oldContext=T.Context(a)
	record("Reassignment updates both viewers without duplicating heroes or switching owner view",function()
		local epoch=T.GetState(a).ViewEpoch
		command(a,"ASSIGN",5)
		assert(T.GetState(a).FloorId==50 and T.GetState(a).ViewEpoch==epoch and T.GetState(a).SquadFloorId==5)
		local first,second=command(a,"MEASURE"),command(b,"MEASURE")
		assert(#first.Ids==2 and #second.Ids==2)
		command(a,"VISIT",5)
		first=command(a,"MEASURE");assert(first.FloorId==5 and #first.Ids==2)
		local own=first.Presence.Floors[6];assert(#own.Visitors==1 and #own.Squads==1 and own.Squads[1].UserId==a.UserId)
	end)
	record("Cross-floor pickup and stale room snapshots/metadata fail on actual clients",function()
		local loot=_G.CombatSimulation.SpawnPhysicalLoot("GOLD",17,a.Character.HumanoidRootPart.Position,a)
		loot.Part.Position=b.Character.HumanoidRootPart.Position
		_G.CombatSimulation.CollectPhysicalLoot(b,loot.LootId)
		local _,_,held=_G.CombatSimulation.DebugEntities();assert(held[b]==nil);loot.Part:Destroy()
		local heroes=_G.CombatSimulation.DebugEntities();local fake={}
		for _,h in heroes do if h.Owner==a then local entry=table.clone(h);entry.Position=T.GetRoom(50).Origin+Vector3.new(110,0,110);entry.Flags=1;entry.StateEnum=1;table.insert(fake,entry) end end
		for _,packet in P.Encode(oldContext,fake,4000000000,workspace:GetServerTimeNow()) do RS.Remotes.TowerRemotes.TowerSnapshot:FireClient(a,packet) end
		RS.Remotes.TowerRemotes.TowerEntityState:FireClient(a,oldContext,{Kind="BOOTSTRAP",BootstrapRevision=4000000000,LifecycleRevision=4000000000,BatchIndex=1,BatchCount=1,Entities={}})
		RS.Remotes.TowerRemotes.TowerEntityState:FireClient(a,oldContext,{Kind="COMPLETE",BootstrapRevision=4000000000,LifecycleRevision=4000000000})
		local view=command(a,"MEASURE");assert(view.FloorId==5 and #view.Ids==2)
		for _,pos in view.Positions do assert(pos.X<20000) end
	end)
	record("Respawn returns player to hub while independently assigned heroes retain floor and health",function()
		command(a,"ASSIGN",50)
		local heroes=_G.CombatSimulation.DebugEntities();local owned={}
		for id,h in heroes do if h.Owner==a then h.CurrentHP=math.max(1,h.CurrentHP-15);owned[id]={HP=h.CurrentHP,Generation=h.EntityGeneration} end end
		local generation=T.GetState(a).CharacterGeneration
		a:LoadCharacterAsync()
		waitFor(function() return T.GetState(a).CharacterGeneration>generation and T.GetState(a).FloorId==0 end,20)
		assert(T.GetState(a).SquadAssignment==50 and T.GetState(a).SquadFloorId==50)
		for id,old in owned do assert(heroes[id] and heroes[id].FloorId==50 and heroes[id].CurrentHP==old.HP and heroes[id].EntityGeneration==old.Generation) end
	end)
	record("Leaving client clears visitor/squad presence and deployed entities for the remaining viewer",function()
		seq+=1;control:FireClient(a,tostring(seq),"LEAVE")
		waitFor(function() return a.Parent~=Players end,12)
		local view=command(b,"MEASURE")
		for _,floor in view.Presence.Floors do for _,list in {floor.Visitors,floor.Squads} do for _,who in list do assert(who.UserId~=a.UserId) end end end
		assert(#view.Ids==2)
	end)
	record("Room retirement increments geometry generation while retaining encounter payout claims",function()
		local room=T.EnsureRoom(4);local gen=room.RoomGeneration
		T.Encounters[4].PayoutClaims.Part2Test=true
		room.EmptySince=os.clock()-61
		waitFor(function() return T.GetRoom(4)==nil end,3)
		local rebuilt=T.EnsureRoom(4);assert(rebuilt.RoomGeneration>gen and T.Encounters[4].PayoutClaims.Part2Test==true)
	end)
end)
STS:EndTest({Passed=ok,Error=not ok and tostring(err) or nil,Results=results})
