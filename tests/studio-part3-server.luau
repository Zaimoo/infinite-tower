-- Inject as a temporary Script into a disposable Play session; never a production script.
local RS=game.ReplicatedStorage
local T=require(game.ServerScriptService.Core.TowerFloorService)
local A=require(RS.Shared.Util.AttackTimeline)
local results={}
local feedbackResult=nil
local feedbackReady=false
local control=nil
if game.StudioTestService:GetTestArgs()=="TOWER_PART3_COMBAT" then
	control=Instance.new("RemoteEvent");control.Name="Part3FeedbackControl";control.Parent=RS
	control.OnServerEvent:Connect(function(player,kind,result)
		if kind=="READY" then feedbackReady=true elseif kind=="RESULT" then feedbackResult=result end
	end)
end
local function save() RS:SetAttribute("Part3ServerTests",game.HttpService:JSONEncode(results)) end
local function record(name,fn)
	local ok,err=pcall(fn);table.insert(results,{Name=name,Passed=ok,Error=not ok and tostring(err) or nil});save();assert(ok,err)
end
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds;repeat if fn() then return end;task.wait(.04) until os.clock()>deadline;error("Timeout")
end
waitFor(function() return _G.CombatSimulation and _G.CombatSimulation.DebugEncounters and #game.Players:GetPlayers()>0 end,15)
local sim=_G.CombatSimulation;local runtime=sim.DebugEncounters
local p=game.Players:GetPlayers()[1]
waitFor(function() return p.Character and T.GetState(p).SquadSize==2 end,20)
local heroes,mobs=sim.DebugEntities()
local function request(action,floor)
	task.wait(.6);local s=T.GetState(p);local id=game.HttpService:GenerateGUID(false)
	T.Request(p,{ContractVersion=1,RequestId=id,Action=action,FloorId=floor,CharacterGeneration=s.CharacterGeneration,ExpectedLocationRevision=s.LocationRevision,ExpectedSquadRevision=s.SquadRevision})
	waitFor(function() return s.Ledger[id]~=nil end,10);assert(s.Ledger[id].Result.Status=="COMMITTED",s.Ledger[id].Result.ErrorCode)
end
record("Default combat creates exactly eight first-biome enemies on two floors without a preview flag",function()
	assert(workspace:GetAttribute("TowerCombatPreview")==nil)
	T.EnsureRoom(1);T.EnsureRoom(5)
	waitFor(function() local n=0;for _,m in mobs do if m.TowerEnemy then n+=1 end end;return n==8 end,3)
	local bosses=0;for _,m in mobs do if m.Role=="BOSS" then bosses+=1;assert(m.FloorId==5) end end;assert(bosses==1)
end)
record("Unattended assigned squad leaves arrival and exchanges actual attacks while owner stays hub",function()
	request("ASSIGN",1);local start=runtime.Metrics.Hits
	waitFor(function()
		local damaged=false;for _,m in mobs do if m.FloorId==1 and m.CurrentHP<m.MaxHP then damaged=true end end
		return damaged and runtime.Metrics.Hits>start
	end,18)
	assert(T.GetState(p).FloorId==0 and T.GetState(p).SquadAssignment==1)
	for _,h in heroes do assert(h.FloorId==1 and not T.GetSafety(h,h.Position).CombatSafe) end
end)
record("Roster rebuild retains hero identities HP stamina and attack cooldowns during assignment",function()
	local before={};for id,h in heroes do before[id]={Ref=h,HP=h.CurrentHP,Stamina=h.Stamina,Cooldown=h.AttackCooldown} end
	sim.RebuildPlayerSquad(p)
	for id,b in before do local h=heroes[id];assert(h==b.Ref and h.CurrentHP==b.HP and h.Stamina==b.Stamina and h.AttackCooldown==b.Cooldown) end
end)
record("Recall preserves health and assignment visits never reset boss HP or cooldowns",function()
	local before={};for id,h in heroes do before[id]=h.CurrentHP end
	request("RECALL");assert(T.GetState(p).SquadAssignment==nil)
	for id,h in heroes do assert(h.CurrentHP==before[id] and h.FloorId==0) end
	local boss;for _,m in mobs do if m.Role=="BOSS" then boss=m end end
	boss.CurrentHP-=100;boss.Cooldowns.guardian_crush=workspace:GetServerTimeNow()+45
	local hp,cd,gen=boss.CurrentHP,boss.Cooldowns.guardian_crush,boss.EntityGeneration
	request("VISIT",5);request("HUB");request("VISIT",5)
	assert(boss.CurrentHP==hp and boss.Cooldowns.guardian_crush==cd and boss.EntityGeneration==gen)
end)
record("Actual regular elite and boss render from complete reliable metadata",function()
	local count=0;for _,m in mobs do if m.FloorId==5 then count+=1 end end;assert(count==4)
	RS:SetAttribute("Part3PreviewFloor",5)
end)
-- Leave owner at floor 5 safe area for client art/timeline probes.
RS:SetAttribute("Part3ServerDone",true)
if control then
	local ok,err=pcall(function()
		waitFor(function() return feedbackReady or feedbackResult~=nil end,20)
		if not feedbackResult then
			control:FireClient(p,"MEASURE");request("ASSIGN",5)
			waitFor(function() return feedbackResult~=nil end,30)
		end
		assert(feedbackResult.Passed,feedbackResult.Error)
	end)
	local result={Passed=ok,Error=not ok and tostring(err) or nil,Server=results,Feedback=feedbackResult}
	print("[Part3CombatScopeResult] "..game.HttpService:JSONEncode(result))
	game.StudioTestService:EndTest(result)
end
