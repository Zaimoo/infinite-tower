// One-time exact migration; retained as implementation evidence.
const fs=require('fs');const root='C:/Projects/infinite-tower/';
const read=p=>fs.readFileSync(root+p,'utf8').replace(/\r\n/g,'\n');const write=(p,s)=>fs.writeFileSync(root+p,s);
let s=read('src/ServerScriptService/Combat/CombatSimulation.server.luau');
const rep=(a,b)=>{if(!s.includes(a))throw Error('Missing anchor '+a.slice(0,100));s=s.replace(a,b)};
rep('local CombatRemotes =',`local Tower=require(script.Parent.Parent.Core.TowerFloorService)
Tower.Init()
local Protocol=require(Shared.Util.TowerProtocol)
local TowerRemotes=ReplicatedStorage.Remotes.TowerRemotes
local CombatRemotes =`);
rep('NextNetId = (NextNetId % 60000) + 1','NextNetId += 1\n\tassert(NextNetId < 4294967295, "Entity ID space exhausted")');
s=s.replaceAll('NetId: number,','NetId: number,\n\tFloorId: number,\n\tRoomGeneration: number,\n\tEntityGeneration: number,');
s=s.replaceAll('NetId = netId,','NetId = netId,\n\t\t\tFloorId = 0, RoomGeneration = 1, EntityGeneration = 1,');
rep('local function broadcastMetadata(targetPlayer: Player?)',`local BootstrapRevision=0
local function sendBootstrap(player: Player)
 local context=Tower.Context(player)
 local metadata={}
 for _,entry in buildMetadataTable() do
  local e=ActiveHeroesByNetId[entry.NetId] or ActiveMobsByNetId[entry.NetId]
  if e and Tower.Same(e,context) then
   entry.FloorId=e.FloorId;entry.RoomGeneration=e.RoomGeneration;entry.EntityGeneration=e.EntityGeneration;table.insert(metadata,entry)
  end
 end
 BootstrapRevision+=1
 local count=math.max(1,math.ceil(#metadata/32))
 for i=1,count do
  local chunk={};for j=(i-1)*32+1,math.min(i*32,#metadata) do table.insert(chunk,metadata[j]) end
  TowerRemotes.TowerEntityState:FireClient(player,context,{Kind="BOOTSTRAP",BootstrapRevision=BootstrapRevision,LifecycleRevision=BootstrapRevision,BatchIndex=i,BatchCount=count,Entities=chunk,Actions={}})
 end
 TowerRemotes.TowerEntityState:FireClient(player,context,{Kind="COMPLETE",BootstrapRevision=BootstrapRevision,LifecycleRevision=BootstrapRevision})
end
local function bootstrapAll() for _,p in Players:GetPlayers() do sendBootstrap(p) end end
local function broadcastMetadata(targetPlayer: Player?)`);
let a=s.indexOf('\tlocal payload = buildMetadataTable()',s.indexOf('local function broadcastMetadata'));let b=s.indexOf('\nend',a);
s=s.slice(0,a)+'\tif targetPlayer then sendBootstrap(targetPlayer) else bootstrapAll() end'+s.slice(b);
rep('local masterPos = getMasterRootPosition(player) or Vector3.new(0, 14, -510)',`local towerState=Tower.GetState(player)
 local room=Tower.GetRoom(towerState.SquadFloorId) or Tower.GetRoom(0)
 local masterPos=towerState.SquadAssignment and room.Arrival.Position or getMasterRootPosition(player) or room.Arrival.Position`);
rep('\t\t\tmasterState.DeployedHeroes[uuid] = newSim','\t\t\tnewSim.FloorId=towerState.SquadFloorId;newSim.RoomGeneration=towerState.SquadRoomGeneration\n\t\t\tmasterState.DeployedHeroes[uuid] = newSim');
rep('\tbroadcastMetadata(nil)\nend\n\nlocal collectPhysicalLoot',` local size=0;for _ in pairs(masterState.DeployedHeroes) do size+=1 end
 Tower.RosterChanged(player,size)
 broadcastMetadata(nil)
end

local collectPhysicalLoot`);
rep('\tlocal held = CarrierToHeldLoot[player]\n\tif not held then return false end','\tif Tower.IsTransitioning(player) then Tower.CancelPending(player,"CARGO_CHANGED") end\n\tlocal held = CarrierToHeldLoot[player]\n\tif not held then return false end');
rep('part.Position = ground and (ground.Position + Vector3.new(0, part.Size.Y / 2 + 0.2, 0)) or position','part.Position = Tower.GroundDrop(held, position, part.Size.Y/2)');
rep('LootId = held.LootId, LootType = held.LootType, Amount = held.Amount,','LootId = held.LootId, LootType = held.LootType, Amount = held.Amount,\n\t\tFloorId=held.FloorId,RoomGeneration=held.RoomGeneration,');
rep('SpawnTime = now, DespawnTime = now + 90,','SpawnTime = held.SpawnTime, DespawnTime = held.DespawnTime,');
rep('task.delay(90, function()\n\t\tif ActiveLootDrops[held.LootId]','task.delay(math.max(0,held.DespawnTime-os.clock()), function()\n\t\tif ActiveLootDrops[held.LootId]');
rep('\tActiveHeroesByNetId[simHero.NetId] = nil\n\tlocal masterState','\tActiveHeroesByNetId[simHero.NetId] = nil\n\tTower.RosterChanged(simHero.Owner,math.max(0,Tower.GetState(simHero.Owner).SquadSize-1))\n\tlocal masterState');
rep('\tlocal loot = ActiveLootDrops[lootId]','\tif Tower.IsTransitioning(player) then return end\n\tlocal loot = ActiveLootDrops[lootId]');
rep('\tif loot.PickupBlockedUserId','\tif not Tower.Same(Tower.GetState(player),loot) or os.clock()>=loot.DespawnTime then return end\n\tif loot.PickupBlockedUserId');
rep('\t\tLootId = lootId,\n\t\tPart = part,','\t\tLootId = lootId,\n\t\tFloorId=loot.FloorId,RoomGeneration=loot.RoomGeneration,SpawnTime=loot.SpawnTime,DespawnTime=loot.DespawnTime,\n\t\tPart = part,');
rep('\tlocal lootData = {','\tlocal context=assert(Tower.ContextAt(worldPos),"Loot spawn outside room bounds")\n\tlocal lootData = {\n\t\tFloorId=context.FloorId,RoomGeneration=context.RoomGeneration,');
rep('function CombatSimulation.SpawnWorldBoss()','function CombatSimulation.SpawnWorldBoss()\n\tif true then return end -- Part 2: legacy/new encounters disabled.');
rep('function CombatSimulation.SpawnRiftWarden(summoner: Player)','function CombatSimulation.SpawnRiftWarden(summoner: Player)\n\tif true then return end -- Do not consume lures until Part 3.');
rep('populateArenaMobs()\n\nPlayers.PlayerAdded','-- Legacy tower population disabled for the isolated-room migration.\n\nPlayers.PlayerAdded');
rep('\tlocal atkR = math.sqrt(atkPos.X * atkPos.X + atkPos.Z * atkPos.Z)\n\tif atkR > 460 then',` local atkState,defState=Tower.GetState(attacker),Tower.GetState(defender)
 local defPos=getMasterRootPosition(defender)
 if not Tower.Same(atkState,defState) or not defPos or Tower.GetSafety(atkState,atkPos).CombatSafe or Tower.GetSafety(defState,defPos).CombatSafe then`);
rep('\tlocal masterState = ActiveMasters[player]\n\tlocal masterPos = getMasterRootPosition(player)\n\tif not masterState',` if Tower.IsTransitioning(player) then return end
 local towerState=Tower.GetState(player)
 if towerState.SquadAssignment and towerState.FloorId~=towerState.SquadFloorId then return end
 local masterState = ActiveMasters[player]
 local masterPos = getMasterRootPosition(player)
 if not masterState`);
rep('if targetMob and targetMob.IsAlive then','if targetMob and targetMob.IsAlive and Tower.Same(targetMob,towerState) and not Tower.GetSafety(targetMob,targetMob.Position).CombatSafe then');
a=s.indexOf('\t\t-- [E] EMERGENCY RECALL WHISTLE');b=s.indexOf('\n\tend\nend)',a);s=s.slice(0,a)+'\t\tTower.Recall(player)'+s.slice(b);
rep('if mob and mob.IsAlive then','if mob and mob.IsAlive and Tower.Same(simHero,mob) and not Tower.GetSafety(mob,mob.Position).CombatSafe then');
rep('if enemyHero and enemyHero.State ~= "COMA" and enemyHero.CurrentHP > 0 then','if enemyHero and enemyHero.State ~= "COMA" and enemyHero.CurrentHP > 0 and Tower.Same(simHero,enemyHero) and not Tower.GetSafety(enemyHero,enemyHero.Position).CombatSafe then');
rep('if h.State ~= "COMA" and h.CurrentHP > 0 then\n\t\t\t\t\tlocal d','if h.State ~= "COMA" and h.CurrentHP > 0 and Tower.Same(simHero,h) and not Tower.GetSafety(h,h.Position).CombatSafe then\n\t\t\t\t\tlocal d');
rep('\tlocal masterPos = getMasterRootPosition(simHero.Owner)',` local squadState=Tower.GetState(simHero.Owner)
 local assignedRoom=squadState.SquadAssignment and Tower.GetRoom(squadState.SquadFloorId)
 local masterPos=assignedRoom and assignedRoom.Arrival.Position or getMasterRootPosition(simHero.Owner)`);
rep('if mob.IsAlive and math.abs(mob.Position.Y - simHero.Position.Y)','if mob.IsAlive and Tower.Same(simHero,mob) and not Tower.GetSafety(mob,mob.Position).CombatSafe and math.abs(mob.Position.Y - simHero.Position.Y)');
rep('\tlocal isPacified = now < simHero.PacifiedUntil','\tlocal isPacified = now < simHero.PacifiedUntil or Tower.GetSafety(simHero,simHero.Position).CombatSafe==true');
rep('local drainRate = getZoneStaminaDrainPerSec(simHero.Position)','local drainRate = simHero.FloorId~=0 and 1.5 or getZoneStaminaDrainPerSec(simHero.Position)');
s=s.replaceAll('if mPos and getHorizontalDistance(mPos, mob.Position)','if mPos and Tower.Same(Tower.GetState(p),mob) and not Tower.GetSafety(Tower.GetState(p),mPos).CombatSafe and getHorizontalDistance(mPos, mob.Position)');
s=s.replaceAll('if mPos and getHorizontalDistance(mPos, WORLD_BOSS_ORIGIN)','if mPos and Tower.Same(Tower.GetState(p),boss) and not Tower.GetSafety(Tower.GetState(p),mPos).CombatSafe and getHorizontalDistance(mPos, WORLD_BOSS_ORIGIN)');
rep('if simHero.State ~= "COMA" then\n\t\t\t\tlocal distFromAltar','if simHero.State ~= "COMA" and Tower.Same(simHero,boss) and not Tower.GetSafety(simHero,simHero.Position).CombatSafe then\n\t\t\t\tlocal distFromAltar');
rep('if getHorizontalDistance(simHero.Position, mob.Position) <= mob.AoERadius then','if Tower.Same(simHero,mob) and not Tower.GetSafety(simHero,simHero.Position).CombatSafe and getHorizontalDistance(simHero.Position, mob.Position) <= mob.AoERadius then');
rep('{ Damage = (previous and previous.Damage or 0) + actualDamage, At = now }','{ Damage = (previous and previous.Damage or 0) + actualDamage, At = now, Owner=simHero.Owner, HeroUUID=simHero.HeroUUID, FloorId=simHero.FloorId, RoomGeneration=simHero.RoomGeneration, EntityGeneration=simHero.EntityGeneration }');
rep('if hero and owner and owner.Parent == Players and humanoid and humanoid.Health > 0','if hero and owner and owner.Parent == Players and contribution.Owner==owner and contribution.HeroUUID==hero.HeroUUID and Tower.Same(contribution,mob) and humanoid and humanoid.Health > 0');
a=s.indexOf('local function broadcastReplicationSnapshot');b=s.indexOf('\n-- Initialize Mobs & Loop',a);
s=s.slice(0,a)+`local SnapshotSequence=0
local function broadcastReplicationSnapshot(now: number)
 SnapshotSequence=(SnapshotSequence+1)%4294967296
 local byFloor={}
 for _,collection in {ActiveHeroesByNetId,ActiveMobsByNetId} do for _,e in pairs(collection) do
  if e.IsAlive==false then continue end
  local room=Tower.GetRoom(e.FloorId)
  if not room or room.RoomGeneration~=e.RoomGeneration then continue end
  if not Protocol.InBounds(e.Position,room.Origin,room.Bounds) then
   warn("Tower entity recovered outside bounds",e.NetId);e.Position=room.Arrival.Position-Vector3.new(0,3.5,0);HeroNavigation.Clear(e)
  end
  local hero=e.Owner~=nil;local entry=table.clone(e)
  entry.StateEnum=hero and (STATE_TO_ENUM[e.State] or 1) or (10+(e.Phase or 1))
  entry.Flags=hero and (1+(now<e.OverdriveUntil and 2 or 0)+(now<e.PacifiedUntil and 4 or 0)) or (e.MobType=="WORLD_BOSS" and now<e.PunishWindowUntil and 8 or 0)
  byFloor[e.FloorId]=byFloor[e.FloorId] or {};table.insert(byFloor[e.FloorId],entry)
 end end
 for _,p in Players:GetPlayers() do
  local c=Tower.Context(p)
  for _,packet in Protocol.Encode(c,byFloor[c.FloorId] or {},SnapshotSequence,Workspace:GetServerTimeNow()) do TowerRemotes.TowerSnapshot:FireClient(p,packet) end
 end
end
local function squadCount(player: Player): number
 local state=ActiveMasters[player];local n=0
 if state then for _,h in pairs(state.DeployedHeroes) do if h.CurrentHP>0 and h.State~="COMA" then n+=1 end end end
 return n
end
Tower.RegisterAdapter("Combat",{
 Count=squadCount,
 CanRecall=function(player) local m=ActiveMasters[player];return m~=nil and os.clock()-m.LastRecallClock>=RECALL_COOLDOWN end,
 Transfer=function(player,room,recall,anchor)
  local m=ActiveMasters[player];if not m then return end
  m.FocusedTargetNetId=nil;m.TargetEnemyUserId=nil
  if recall then m.LastRecallClock=os.clock();ProgressionActivity[player]=os.clock() end
  for _,h in pairs(m.DeployedHeroes) do
   h.FloorId=room.FloorId;h.RoomGeneration=room.RoomGeneration;h.EntityGeneration+=1
   h.Position=HeroNavigation.PlaceNear(anchor or room.Arrival.Position,getFormationOffset(h.SlotIndex))
   h.TargetNetId=nil;h.State="FOLLOW_MASTER";h.PacifiedUntil=os.clock()+2;h.ActionSequence=0;HeroNavigation.Clear(h)
  end
 end,
 CaptureCargo=function(player) return CarrierToHeldLoot[player] end,
 DropCargo=function(player) CombatSimulation.DropCarriedLoot(player,true) end,
 Pins=function(id,gen)
  for _,items in {ActiveLootDrops,CarrierToHeldLoot} do for _,item in pairs(items) do if item.FloorId==id and item.RoomGeneration==gen and item.Part and item.Part.Parent then return true end end end
  return false
 end,
 Bootstrap=sendBootstrap,BootstrapAll=bootstrapAll,
})
if RunService:IsStudio() then CombatSimulation.DebugEntities=function() return ActiveHeroesByNetId,ActiveMobsByNetId,CarrierToHeldLoot end end
`+s.slice(b);
rep('Players.PlayerRemoving:Connect(function(player: Player)','Players.PlayerRemoving:Connect(function(player: Player)\n\tCombatSimulation.DropCarriedLoot(player,true)');
rep('\t\t\tlocal r = math.sqrt(rootPos.X * rootPos.X + rootPos.Z * rootPos.Z)\n\t\t\tif r >= 460 then','\t\t\tlocal location=Tower.GetState(player)\n\t\t\tlocal safety=Tower.GetSafety(location,rootPos)\n\t\t\tif safety.CanBankCargo and location.BankArmed and not Tower.IsTransitioning(player) then');
rep('\tbroadcastReplicationSnapshot(now)',` for p,held in pairs(CarrierToHeldLoot) do if now>=held.DespawnTime then
  if held.Weld then held.Weld:Destroy() end;if held.Part then held.Part:Destroy() end;clearLootCarryState(p)
 end end
 broadcastReplicationSnapshot(now)`);
s=s.replaceAll('CombatVFXRemote:FireAllClients("HIT_SPARK", targetMob.Position','Tower.BroadcastAt(CombatVFXRemote,targetMob,"HIT_SPARK", targetMob.Position');
s=s.replaceAll('CombatVFXRemote:FireAllClients("HIT_SPARK", targetEnemyHero.Position','Tower.BroadcastAt(CombatVFXRemote,targetEnemyHero,"HIT_SPARK", targetEnemyHero.Position');
s=s.replaceAll('CombatVFXRemote:FireAllClients("WHISTLE_Q", masterPos)','Tower.BroadcastAt(CombatVFXRemote,Tower.GetState(player),"WHISTLE_Q",masterPos)');
s=s.replaceAll('CombatVFXRemote:FireAllClients("LOOT_PICKUP", hrp.Position)','Tower.BroadcastAt(CombatVFXRemote,Tower.GetState(player),"LOOT_PICKUP",hrp.Position)');
s=s.replaceAll('BossTelegraphRemote:FireAllClients(','Tower.BroadcastAt(BossTelegraphRemote,boss,');
a=s.indexOf('local function stepMobAndEliteAoEs');s=s.slice(0,a)+s.slice(a).replaceAll('Tower.BroadcastAt(BossTelegraphRemote,boss,','Tower.BroadcastAt(BossTelegraphRemote,mob,');
write('src/ServerScriptService/Combat/CombatSimulation.server.luau',s);
let nav=read('src/ServerScriptService/Core/HeroNavigation.luau').replace('if other ~= hero and other.State','if other ~= hero and other.FloorId==hero.FloorId and other.RoomGeneration==hero.RoomGeneration and other.State');
write('src/ServerScriptService/Core/HeroNavigation.luau',nav);
let plot=read('src/ServerScriptService/Core/PlotManager.server.luau').replace('hrp.CFrame = spawnLoc.CFrame * CFrame.new(0, 4, 0)','hrp.CFrame = spawnLoc.CFrame * CFrame.new(0, 4, 0)\n\t\trequire(script.Parent.TowerFloorService).CommitRespawn(player)');
write('src/ServerScriptService/Core/PlotManager.server.luau',plot);
