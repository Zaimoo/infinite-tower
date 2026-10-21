-- Run as a temporary Script in ServerScriptService after studio-part2-client completes.
local T=require(game.ServerScriptService.Core.TowerFloorService)
local P=require(game.ReplicatedStorage.Shared.Util.TowerProtocol)
local R=game.ReplicatedStorage.Remotes.TowerRemotes
local p=game.Players:GetPlayers()[1]
local results={}
local function record(name,fn)
	local ok,err=pcall(fn);table.insert(results,{Name=name,Passed=ok,Error=not ok and tostring(err) or nil})
	game.ReplicatedStorage:SetAttribute("Part2ServerTests",game.HttpService:JSONEncode(results));assert(ok,err)
end
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds
	repeat if fn() then return end;task.wait(.05) until os.clock()>deadline
	error("Timed out")
end
local function request(action,id)
	task.wait(.6)
	local s=T.GetState(p)
	local r={ContractVersion=1,RequestId=game.HttpService:GenerateGUID(false),Action=action,FloorId=id,CharacterGeneration=s.CharacterGeneration,ExpectedLocationRevision=s.LocationRevision,ExpectedSquadRevision=s.SquadRevision}
	T.Request(p,r)
	waitFor(function() return s.Pending==nil end,10)
	local terminal=s.Ledger[r.RequestId]
	assert(terminal,"No terminal result")
	return terminal.Result,r
end
local heroes,mobs,held=_G.CombatSimulation.DebugEntities()
local hero=next(heroes) and heroes[next(heroes)]
assert(hero,"Deployed hero missing")
local profile=_G.DataManager.GetProfile(p)
local before={HP=hero.CurrentHP,Stamina=hero.Stamina,ProfileStamina=profile.Heroes[hero.HeroUUID].CurrentStamina,AttackCooldown=hero.AttackCooldown}
local fixtureIds={}
record("Live HP stamina cooldown and physical cargo identity survive floor-50 travel without banking",function()
	assert(request("HUB").Status=="COMMITTED")
	hero.CurrentHP=hero.MaxHP-31;hero.Stamina=44;hero.AttackCooldown=.87;profile.Heroes[hero.HeroUUID].CurrentStamina=44
	local root=p.Character.HumanoidRootPart
	local loot=_G.CombatSimulation.SpawnPhysicalLoot("GOLD",125,root.Position,p)
	_G.CombatSimulation.CollectPhysicalLoot(p,loot.LootId)
	local cargo=assert(held[p],"Cargo not picked up")
	local identity,weld,expiry=cargo.Part,cargo.Weld,cargo.DespawnTime
	local currency=profile.Currencies.Gold
	assert(request("VISIT",50).Status=="COMMITTED")
	assert(hero.CurrentHP==hero.MaxHP-31 and hero.Stamina==44 and hero.AttackCooldown==.87)
	assert(held[p]==cargo and cargo.Part==identity and cargo.Weld==weld and cargo.DespawnTime==expiry and cargo.Amount==125)
	assert(cargo.FloorId==50 and cargo.RoomGeneration==T.GetState(p).RoomGeneration)
	task.wait(1.1);assert(profile.Currencies.Gold==currency and held[p]==cargo,"Off-map travel banked cargo")
	_G.CombatSimulation.DropCarriedLoot(p);assert(held[p]==nil and identity.Parent)
	identity:Destroy() -- test fixture only; no payout
end)
record("Cross-floor pickups fail even when the physical part is placed beside the carrier",function()
	local loot=_G.CombatSimulation.SpawnPhysicalLoot("GOLD",9,T.GetRoom(0).Arrival.Position,p)
	loot.Part.Position=p.Character.HumanoidRootPart.Position
	_G.CombatSimulation.CollectPhysicalLoot(p,loot.LootId);assert(held[p]==nil)
	loot.Part:Destroy()
end)
record("Relic cargo preserves identity locks expiry weld and private extraction rejects off-map",function()
	local root=p.Character.HumanoidRootPart
	local relic=_G.RelicService.SpawnRelic("MANA_GEODE",root.Position,p.UserId)
	assert(_G.RelicService.TryPickupRelic(p,relic))
	local part,weld,expiry,lock=relic.Part,relic.Weld,relic.DespawnAt,relic.LockExpiresAt
	local gold,gems=profile.Currencies.Gold,profile.Currencies.Gems
	_G.RelicService.ExtractOnPrivatePad(p);assert(relic.Part.Parent and profile.Currencies.Gold==gold and profile.Currencies.Gems==gems)
	assert(request("VISIT",1).Status=="COMMITTED")
	assert(relic.Part==part and relic.Weld==weld and relic.DespawnAt==expiry and relic.LockExpiresAt==lock and relic.FloorId==1 and relic.Carrier==p)
	assert(request("HUB").Status=="COMMITTED");_G.RelicService.ExtractOnPrivatePad(p)
	assert(relic.Carrier==p and profile.Currencies.Gold==gold and profile.Currencies.Gems==gems,"Arrival extracted relic")
	_G.RelicService.DropCarriedRelic(p);relic.DespawnAt=0;task.wait(.1)
end)
record("Duplicate terminal requests replay once while changed payloads do not mutate location",function()
	local response,req=request("VISIT",5);assert(response.Status=="COMMITTED")
	local s=T.GetState(p);local revision,epoch=s.LocationRevision,s.ViewEpoch
	T.Request(p,req);assert(s.LocationRevision==revision and s.ViewEpoch==epoch)
	local changed=table.clone(req);changed.FloorId=50;T.Request(p,changed)
	assert(s.FloorId==5 and s.LocationRevision==revision and s.ViewEpoch==epoch)
end)
record("Server safe arrival checks reject unsupported surfaces without moving the character",function()
	local room=T.EnsureRoom(6);local arrival=room.Arrival
	room.Arrival=CFrame.new(room.Origin+Vector3.new(0,50,0))
	local at=p.Character:GetPivot().Position;local response=request("VISIT",6)
	room.Arrival=arrival
	assert(response.Status=="REJECTED" and response.ErrorCode=="UNSAFE_ARRIVAL")
	assert(T.GetState(p).FloorId==5 and (p.Character:GetPivot().Position-at).Magnitude<2)
end)
record("Readiness timeout rejects stale Ready and preserves current source damage and membership",function()
	task.wait(.6)
	local s=T.GetState(p);local location,revision,epoch=s.FloorId,s.LocationRevision,s.ViewEpoch
	local id=game.HttpService:GenerateGUID(false)
	T.Request(p,{ContractVersion=1,RequestId=id,Action="VISIT",FloorId=4,CharacterGeneration=s.CharacterGeneration,ExpectedLocationRevision=s.LocationRevision,ExpectedSquadRevision=s.SquadRevision})
	local pending=assert(s.Pending)
	local token=pending.Token;pending.Token="INTENTIONALLY_UNMATCHED_TEST_TOKEN"
	T.Ready(p,{ContractVersion=1,RequestId=id,ReadyToken=token,ViewEpoch=pending.ViewEpoch,CharacterGeneration=s.CharacterGeneration,Result="READY"})
	assert(s.Pending==pending and s.FloorId==location)
	hero.CurrentHP-=7;local hp=hero.CurrentHP
	waitFor(function() return s.Pending==nil end,9)
	assert(s.Ledger[id].Result.ErrorCode=="READY_TIMEOUT")
	assert(s.FloorId==location and s.LocationRevision==revision and s.ViewEpoch==epoch and hero.CurrentHP==hp)
	assert(T.GetRoom(4).Reservations==0)
end)
record("Cancellation releases destination reservation and repeated pending IDs cannot duplicate travel",function()
	task.wait(.6)
	local s=T.GetState(p);local at=s.FloorId;local id=game.HttpService:GenerateGUID(false)
	local req={ContractVersion=1,RequestId=id,Action="VISIT",FloorId=2,CharacterGeneration=s.CharacterGeneration,ExpectedLocationRevision=s.LocationRevision,ExpectedSquadRevision=s.SquadRevision}
	T.Request(p,req);local pending=assert(s.Pending);T.Request(p,req);assert(s.Pending==pending)
	local conflicting=table.clone(req);conflicting.FloorId=1;T.Request(p,conflicting);assert(s.Pending==pending)
	T.CancelPending(p,"TEST_CANCEL");assert(s.Pending==nil and T.GetRoom(2).Reservations==0 and s.FloorId==at)
end)
record("Bounds recovery returns a falling character to its own validated landing",function()
	p.Character:PivotTo(CFrame.new(T.GetRoom(5).Origin+Vector3.new(0,-25,0)))
	task.wait(1.1)
	assert(P.InBounds(p.Character.HumanoidRootPart.Position,T.GetRoom(5).Origin,T.GetRoom(5).Bounds))
end)
record("Opaque room enclosures block hub and neighboring rooms",function()
	local a,b=T.EnsureRoom(1),T.EnsureRoom(5)
	local origin=a.Origin+Vector3.new(0,12,0)
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={a.Model}
	for _,target in {b.Origin+Vector3.new(0,12,0),T.GetRoom(0).Arrival.Position,a.Origin+Vector3.new(0,200,0)} do
		local hit=workspace:Raycast(origin,target-origin,params);assert(hit and hit.Instance:IsDescendantOf(a.Model))
	end
end)
record("300 relevant fixture entities retain IDs and metadata beyond the legacy 255 limit",function()
	assert(request("VISIT",50).Status=="COMMITTED")
	local r=T.GetRoom(50)
	for i=1,300 do
		local id=3000000000+i;table.insert(fixtureIds,id)
		local pos=r.Origin+Vector3.new(-95+((i-1)%20)*10,0,-95+math.floor((i-1)/20)*10)
		mobs[id]={NetId=id,EntityGeneration=1,FloorId=50,RoomGeneration=r.RoomGeneration,IsAlive=true,SpecId="mob_mana_node",DisplayName="NETWORK FIXTURE "..i,
			MobType="RING1_MOB",RingIndex=1,Position=pos,HomePosition=pos,Yaw=0,CurrentHP=10,MaxHP=10,ATK=0,AoERadius=0,NextAoECastTime=0,Phase=1,PunishWindowUntil=0}
	end
	_G.CombatSimulation.RebuildPlayerSquad(p)
	game.ReplicatedStorage:SetAttribute("Part2NetworkFixtureReady",true)
end)
-- Pause fixture cleanup until the client probe has measured actual rendered entities.
game.ReplicatedStorage:SetAttribute("Part2ServerDone",true)
hero.CurrentHP=math.min(before.HP,hero.MaxHP);hero.Stamina=before.Stamina;hero.AttackCooldown=before.AttackCooldown
profile.Heroes[hero.HeroUUID].CurrentStamina=before.ProfileStamina
script:Destroy()
