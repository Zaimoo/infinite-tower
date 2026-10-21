-- Temporary server suite, auto-ends and returns actual evidence to StudioTestService.
local STS=game:GetService("StudioTestService");if STS:GetTestArgs()~="TOWER_PART3_MULTI" then return end
local RS=game.ReplicatedStorage;local Players=game.Players
local T=require(game.ServerScriptService.Core.TowerFloorService)
local Config=require(RS.Shared.Config.FirstBiomeCombat)
local A=require(RS.Shared.Util.AttackTimeline)
local control=Instance.new("RemoteEvent");control.Name="TowerPart3TestControl";control.Parent=RS
local reports,ready,results={}, {}, {}
local detail={}
control.OnServerEvent:Connect(function(p,seq,result) if seq=="READY" then ready[p]=true else reports[p]=reports[p] or {};reports[p][seq]=result end end)
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds;repeat if fn() then return end;task.wait(.025) until os.clock()>deadline;error("Timeout")
end
local seq=0
local function command(p,action,id)
	seq+=1;local key=tostring(seq);control:FireClient(p,key,action,id)
	waitFor(function() return reports[p] and reports[p][key] end,15)
	local r=reports[p][key];assert(r.Passed,r.Result)
	if action~="MEASURE" and action~="CLEAR" and action~="LEAVE" then assert(r.Result.Status=="COMMITTED",r.Result.ErrorCode) end
	return r.Result
end
local function record(name,fn)
	local ok,err=pcall(fn);table.insert(results,{Name=name,Passed=ok,Error=not ok and tostring(err) or nil});assert(ok,err)
end
local ok,err=pcall(function()
	waitFor(function() return _G.CombatSimulation and #Players:GetPlayers()==2 end,35)
	local people=Players:GetPlayers();table.sort(people,function(a,b) return a.UserId<b.UserId end)
	local p,q=people[1],people[2]
	waitFor(function() return ready[p] and ready[q] and T.GetState(p).SquadSize==2 and T.GetState(q).SquadSize==2 end,35)
	local sim=_G.CombatSimulation;local rt=sim.DebugEncounters;local heroes,mobs=sim.DebugEntities()
	workspace:SetAttribute("TowerCombatPreview",true)
	command(p,"VISIT",5);command(q,"VISIT",5)
	waitFor(function() local n=0;for _,m in mobs do if m.FloorId==5 then n+=1 end end;return n==4 end,3)
	record("Two clients render the same regular elite and boss with articulated joints",function()
		local a,b=command(p,"MEASURE"),command(q,"MEASURE")
		assert(#a.Rigs==4 and #b.Rigs==4 and #a.Ids==8 and #b.Ids==8)
		for i,id in a.Ids do assert(b.Ids[i]==id) end
		detail.Inventory=a.Rigs
	end)
	local firstHero;for _,h in heroes do if h.Owner==p then firstHero=h;break end end
	local damageLog={};local originalDamage=rt.API.Damage
	rt.API.Damage=function(v,damage,m)
		table.insert(damageLog,{Id=m.NetId,Attack=m.Action.AttackId,Sequence=m.Action.ActionSequence,Target=v.NetId,Floor=v.FloorId,
			Start=m.Action.StartServerTime,Expected=m.Action.ImpactOffsetSeconds,Actual=workspace:GetServerTimeNow()})
		originalDamage(v,damage,m)
	end
	-- Keep natural damage readable without wiping the disposable measurement squad.
	for _,m in mobs do m.ATK=1 end
	for _,h in heroes do h.AttackCooldown=100;h.PacifiedUntil=math.huge;h.MoveSpeed=0 end
	command(p,"CLEAR");command(q,"CLEAR")
	record("Regular elite and boss execute telegraphed server impacts visible to both clients",function()
		for _,enemyId in {"mob_moss_crawler","elite_vinebound","boss_mossbound_guardian"} do
			local mob;for _,m in mobs do if m.EnemyId==enemyId then mob=m;break end end
			rt:Cancel(mob,"TEST_SETUP");mob.Cooldowns={}
			firstHero.Position=mob.Position+Vector3.new(0,0,-5)
			-- While pacified, the hero remains a live target; natural AI controls the enemy.
			local start=#damageLog
			waitFor(function() for i=start+1,#damageLog do if damageLog[i].Id==mob.NetId then return true end end;return false end,8)
			firstHero.Position=T.GetRoom(5).Arrival.Position-Vector3.new(0,3,0)
			task.wait(.3)
		end
		for _,hit in damageLog do assert(hit.Floor==5 and hit.Actual-hit.Start>=hit.Expected and hit.Actual-hit.Start-hit.Expected<.12) end
		local a,b=command(p,"MEASURE"),command(q,"MEASURE");local function keys(view)
			local out={};for _,e in view.Events do if e.Kind=="START" then out[e.Id..":"..e.Sequence]=e end end;return out
		end
		local x,y=keys(a),keys(b)
		for _,hit in damageLog do local key=hit.Id..":"..hit.Sequence;assert(x[key] and y[key],"Missing actual START on one client")
			assert(x[key].Received<hit.Actual and y[key].Received<hit.Actual,"Warning arrived after damage") end
		assert(next(a.MotionSamples) and next(b.MotionSamples),"No actual joint samples at contact")
		detail.CombatClients={a,b};detail.Damage=damageLog
	end)
	record("Death during windup cancels impact and duplicate final hits claim physical reward once",function()
		local mob;for _,m in mobs do if m.EnemyId=="mob_moss_crawler" then mob=m;break end end
		rt:Cancel(mob,"TEST_SETUP");mob.Cooldowns={};firstHero.Position=mob.Position+Vector3.new(0,0,-4)
		waitFor(function() return mob.Action and not mob.Action.Impacted end,5)
		local hits=#damageLog;local deaths=rt.Metrics.Deaths
		sim.DebugKillTowerMob(mob,p);sim.DebugKillTowerMob(mob,q)
		firstHero.Position=T.GetRoom(5).Arrival.Position-Vector3.new(0,3,0);task.wait(1.7)
		assert(rt.Metrics.Deaths==deaths+1 and not mob.IsAlive)
		for i=hits+1,#damageLog do assert(damageLog[i].Id~=mob.NetId,"Dead actor hit") end
		assert(T.Encounters[5].PayoutClaims[mob.Slot..":"..mob.LifeGeneration])
		local a,b=command(p,"MEASURE"),command(q,"MEASURE")
		for _,v in {a,b} do for _,rig in v.Rigs do assert(rig.Id~=mob.NetId,"Dead live rig remained") end end
	end)
	record("Target room departure and identical-coordinate foreign hero cannot receive ghost damage",function()
		local boss;for _,m in mobs do if m.Role=="BOSS" then boss=m end end
		rt:Cancel(boss,"TEST_SETUP");boss.Cooldowns={};firstHero.Position=boss.Position+Vector3.new(0,0,-5)
		waitFor(function() return boss.Action~=nil and not boss.Action.Impacted end,5)
		local action=boss.Action;local before=firstHero.CurrentHP
		-- A real travel commit changes entity generation before authoritative impact.
		command(p,"VISIT",50);task.wait(2.5);assert(firstHero.CurrentHP==before and action.Status=="CANCELED")
		local foreign=table.clone(firstHero);foreign.Position=boss.Position;foreign.NetId=3000000001;foreign.EntityGeneration=1
		local target;for _,h in heroes do if h.Owner==q then target=h;break end end
		target.Position=boss.Position+Vector3.new(0,0,-4)
		local d=Config.Get(boss.EnemyId).Attacks[2];local a=A.Start(boss,target,d,workspace:GetServerTimeNow()-d.ImpactOffsetSeconds)
		local hits=0;A.Step(a,boss,target,d,workspace:GetServerTimeNow(),function(e) return T.GetSafety(e,e.Position).CombatSafe end,{foreign},function() hits+=1 end)
		assert(hits==0 and foreign.FloorId==50);target.Position=T.GetRoom(5).Arrival.Position-Vector3.new(0,3,0)
	end)
	record("Late floor entry seeks bootstrap timeline and delayed duplicate START cannot undo cancellation",function()
		local boss;for _,m in mobs do if m.Role=="BOSS" then boss=m end end
		local target;for _,h in heroes do if h.Owner==q then target=h;break end end
		rt:Cancel(boss,"TEST_SETUP");boss.Cooldowns={};target.Position=boss.Position+Vector3.new(0,0,-5)
		waitFor(function() return boss.Action and boss.Action.AttackId=="sweeping_roots" end,6)
		local action=boss.Action;local message=rt:PublicAction(action,"START")
		command(p,"VISIT",5)
		local state=command(p,"MEASURE");local found=false
		for _,entry in state.Active do if entry.Key==A.Identity(boss).NetId..":"..boss.EntityGeneration and entry.Sequence==action.ActionSequence then assert(entry.Start==action.StartServerTime);found=true end end
		assert(found and state.Metrics.Seeks>0,"Late bootstrap did not seek original attack")
		local started=state.Metrics.Started
		rt:Cancel(boss,"LATE_PACKET_TEST")
		RS.Remotes.TowerRemotes.TowerAction:FireClient(p,T.Context(p),message)
		RS.Remotes.TowerRemotes.TowerAction:FireClient(p,T.Context(p),message)
		target.Position=T.GetRoom(5).Arrival.Position-Vector3.new(0,3,0)
		local after=command(p,"MEASURE");assert(after.Metrics.Started==started,"Duplicate START replayed")
		detail.LateActions={Before=state,After=after}
	end)
	record("Boss reward deadline and HP survive geometry retirement and regeneration",function()
		local boss;for _,m in mobs do if m.Role=="BOSS" then boss=m end end
		rt:Cancel(boss,"TEST_SETUP");boss.CurrentHP=boss.MaxHP-333
		local hp=boss.CurrentHP;local oldGeneration=boss.EntityGeneration;boss.Cooldowns.guardian_crush=workspace:GetServerTimeNow()+60
		command(q,"HUB");command(p,"HUB")
		for _,part in workspace.PhysicalLoot:GetChildren() do part:Destroy() end
		local room=T.GetRoom(5);room.EmptySince=os.clock()-62
		waitFor(function() return T.GetRoom(5)==nil end,3);task.wait(.3)
		T.EnsureRoom(5);task.wait(.4)
		assert(boss.CurrentHP==hp and boss.EntityGeneration>oldGeneration and boss.Cooldowns.guardian_crush>workspace:GetServerTimeNow())
	end)
	record("Boss death pays once and retains respawn deadline through another geometry rebuild",function()
		local boss;for _,m in mobs do if m.Role=="BOSS" then boss=m end end
		local count=rt.Metrics.Deaths;sim.DebugKillTowerMob(boss,p);sim.DebugKillTowerMob(boss,q)
		assert(rt.Metrics.Deaths==count+1 and not boss.IsAlive)
		local deadline=boss.RespawnAt;local generation=boss.LifeGeneration
		for _,part in workspace.PhysicalLoot:GetChildren() do part:Destroy() end
		T.GetRoom(5).EmptySince=os.clock()-62;waitFor(function() return T.GetRoom(5)==nil end,3);task.wait(.3)
		T.EnsureRoom(5);task.wait(.4)
		assert(not boss.IsAlive and boss.RespawnAt==deadline and boss.LifeGeneration==generation)
		assert(T.Encounters[5].PayoutClaims[boss.Slot..":"..generation])
	end)
	detail.Metrics=rt.Metrics;rt.API.Damage=originalDamage
end)
STS:EndTest({Passed=ok,Error=not ok and tostring(err) or nil,Tests=results,Detail=detail})
