--!strict
-- Require from a normal server Script in a disposable Studio playtest.
-- Calls the real combat movement state machine with session-only actors. Their
-- owner has no Player/profile; attacks are held on cooldown and cannot pay rewards.
return function()
	assert(game:GetService("RunService"):IsStudio())
	local combat=assert(_G.CombatSimulation)
	local tower=require(game.ServerScriptService.Core.TowerFloorService)
	local nav=require(game.ServerScriptService.Core.HeroNavigation)
	local layout=require(game.ReplicatedStorage.Shared.Config.TowerLayout).Get(3)
	local room=tower.EnsureRoom(43)
	local owner: any={Name="Phase0Isolated",UserId=-900001,Character=nil,Parent=nil,GetAttribute=function()return nil end}
	local state=tower.GetState(owner)
	state.SquadAssignment=43;state.SquadFloorId=43;state.SquadRoomGeneration=room.RoomGeneration
	local _,mobs=combat.DebugEntities()
	local heroes=combat.DebugEntities()
	for _,h in heroes do assert(h.FloorId~=43,"Floor 43 must have no real squad")end
	for _,p in game.Players:GetPlayers()do assert(tower.GetState(p).FloorId~=43,"Floor 43 must have no visitor")end
	-- EnsureRoom populates native camps. Temporarily hide their table entries from
	-- target selection; restore every entry during cleanup. No camp is killed.
	local savedMobs: any={}
	local function isolateMobs()
		for id,m in mobs do if id>0 and m.FloorId==43 then savedMobs[id]=m;mobs[id]=nil end end
	end
	isolateMobs()
	local actors={}
	local props=Instance.new("Folder");props.Name="Phase0Obstructions";props.Parent=room.Model
	local result: any={Kind="ISOLATED_NATIVE_ASSIGNED",Floor=43,RoomGeneration=room.RoomGeneration,Cases={}}
	local function point(x,y,z)return room.Origin+Vector3.new(x,y,z)end
	local link
	for _,v in layout.Links do if v.From=="Basin" and v.To=="EastGallery" then link=v end end
	local a,b=point(link.AX,link.AY,link.AZ),point(link.BX,link.BY,link.BZ)
	local dir=Vector3.new(b.X-a.X,0,b.Z-a.Z).Unit
	local side=Vector3.new(-dir.Z,0,dir.X)
	local function reset()
		for _,h in actors do nav.Clear(h)end;table.clear(actors)
		mobs[-900001]=nil;mobs[-900002]=nil
		props:ClearAllChildren()
	end
	local ok,failure=pcall(function()
		for _,kind in {"PURSUIT_RETARGET","BLOCKED_PURSUIT"}do
			reset()
			local target: any={NetId=-900001,FloorId=43,RoomGeneration=room.RoomGeneration,EntityGeneration=1,IsAlive=true,CurrentHP=100,MaxHP=100,Position=b,HomePosition=b,Yaw=0,Stamina=0,ActionSequence=0,Phase=1,DisplayName="Phase0Target",MobType="NORMAL"}
			mobs[target.NetId]=target
			local record: any={Kind=kind,Trace={},Heroes={},Before=nav.DebugSnapshot()}
			local count=if kind=="BLOCKED_PURSUIT" then 1 else 5
			for slot=1,count do
				local pos=a:Lerp(b,.4)+side*((slot-(count+1)/2)*2)
				local h: any={NetId=-910000-slot,Owner=owner,HeroUUID="phase0_"..slot,TemplateId="hero_han",Archetype="Vanguard",SlotIndex=slot,FloorId=43,RoomGeneration=room.RoomGeneration,EntityGeneration=1,Position=nav.Ground(pos,nil,4,8)or pos,State="FOLLOW_MASTER",CurrentHP=100,MaxHP=100,EffectiveATK=1,AttackRange=6,AttackInterval=1,AttackCooldown=math.huge,OverdriveUntil=0,PacifiedUntil=0,Stamina=0,StatsRefreshAt=math.huge}
				table.insert(actors,h)
				record.Heroes[tostring(h.NetId)]={Slot=slot,Backward=0,MaxStall=0,TargetChanges=0}
			end
			if kind=="BLOCKED_PURSUIT" then
				local p=actors[1].Position
				for _,spec in {{Vector3.new(0,3,4),Vector3.new(10,8,1)},{Vector3.new(0,3,-4),Vector3.new(10,8,1)},{Vector3.new(4,3,0),Vector3.new(1,8,10)},{Vector3.new(-4,3,0),Vector3.new(1,8,10)}}do
					local part=Instance.new("Part");part.Anchored=true;part.Size=spec[2];part.Position=p+spec[1];part.Parent=props
				end
			end
			local started=os.clock()
			local previous: any={}
			local swapped=false
			while os.clock()-started<10 do
				local dt=task.wait(.1)
				isolateMobs()
				local now=os.clock();local t=now-started
				if kind=="PURSUIT_RETARGET" then
					target.Position=b+dir*(15+math.sin(t)*10)
					if t>4 and not swapped then
						target.IsAlive=false
						target=table.clone(target);target.NetId=-900002;target.IsAlive=true
						mobs[target.NetId]=target;swapped=true
					end
				end
				for _,h in actors do
					local old=previous[h.NetId]
					local start=os.clock();combat.DebugStepHero(h,dt,now);local ms=(os.clock()-start)*1000
					local summary=record.Heroes[tostring(h.NetId)]
					local stall=0;local backward=false
					if old then
						local delta=h.Position-old.P
						local toward=target.Position-old.P
						if old.Target~=h.TargetNetId then summary.TargetChanges+=1 end
						if h.State=="MOVE_TO_TARGET" then
							if delta.Magnitude<.25 then stall=old.Stall+dt end
							backward=toward.Magnitude>1 and delta:Dot(toward.Unit)<-.5
							if backward then summary.Backward+=1 end
						end
					end
					summary.MaxStall=math.max(summary.MaxStall,stall)
					local p=h.Position-room.Origin
					table.insert(record.Trace,{T=t,Id=h.NetId,P={p.X,p.Y,p.Z},State=h.State,Target=h.TargetNetId,Backward=backward,Stall=stall,StepMs=ms,HasStuckTracker=combat.DebugStuckTracking(h.NetId)~=nil,Nav=nav.DebugSnapshot(h).Actor})
					previous[h.NetId]={P=h.Position,Target=h.TargetNetId,Stall=stall}
				end
			end
			record.After=nav.DebugSnapshot();table.insert(result.Cases,record)
		end
	end)
	reset();props:Destroy();state.SquadAssignment=nil;state.SquadFloorId=0
	for id,m in savedMobs do mobs[id]=m end
	assert(ok,tostring(failure))
	return result
end
