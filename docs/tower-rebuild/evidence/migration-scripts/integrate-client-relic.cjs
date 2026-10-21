const fs=require('fs'),root='C:/Projects/infinite-tower/';const read=p=>fs.readFileSync(root+p,'utf8').replace(/\r\n/g,'\n');const write=(p,s)=>fs.writeFileSync(root+p,s);
let s=read('src/StarterPlayerScripts/Rendering/EntityRenderer.client.luau');
s=s.replace('local VisualFolder =',`local Protocol=require(Shared.Util.TowerProtocol)
local TowerRemotes=ReplicatedStorage.Remotes:WaitForChild("TowerRemotes")
local View: any=nil
local LastBootstrap=0
local Assembly: any=nil
local Bootstrapped=false
local Buffered={}
local EntitySequences: {[number]:number}={}
local Generations: {[number]:number}={}
local VisualFolder =`);
let a=s.indexOf('EntityMetadataRemote.OnClientEvent:Connect');let b=s.indexOf('-- 60 FPS Smooth Interpolation Loop',a);
s=s.slice(0,a)+`local function clearView()
 for _,node in pairs(VisualNodesByNetId) do node.Model:Destroy() end
 table.clear(VisualNodesByNetId);table.clear(MetadataByNetId);table.clear(EntitySequences);table.clear(Generations)
 VisualFolder:ClearAllChildren();_G.ClientCombatState.Metadata=MetadataByNetId
 _G.ClientCombatState.FocusedNetId=nil;_G.ClientCombatState.WorldBossNetId=nil;_G.ClientCombatState.NovaCastDuration=0
 Assembly=nil;Bootstrapped=false;table.clear(Buffered);LastBootstrap=0
end
TowerRemotes.Context.OnClientEvent:Connect(function(c)
 if c.Stage~="COMMIT" then return end
 if not Protocol.Same(c,View) then clearView() end
 View=c;_G.TowerView=c
end)
local function consume(buf: buffer)
 local packet=Protocol.Decode(buf,View)
 if not packet then return end
 if not Bootstrapped then if #Buffered<2 then table.insert(Buffered,buf) else requestEntityMetadata() end;return end
 local now=os.clock()
 for _,e in packet.Entities do
  local id=e.NetId;local meta=MetadataByNetId[id]
  if not meta or meta.EntityGeneration~=e.EntityGeneration then requestEntityMetadata();continue end
  if EntitySequences[id]~=nil and not Protocol.Newer(packet.Sequence,EntitySequences[id]) then continue end
  EntitySequences[id]=packet.Sequence
  local node=VisualNodesByNetId[id]
  if not node then node=createEntityModel(id,meta,e.Position);VisualNodesByNetId[id]=node end
  node.GoalPos=e.Position;node.GoalYaw=e.Yaw;node.HpPermille=e.HpPermille;node.Stamina=e.Stamina
  node.StateEnum=e.StateEnum;node.Flags=e.Flags;node.LastSeenClock=now
  if node.HPBarFill then node.HPBarFill.Size=UDim2.fromScale(e.HpPermille/1000,1) end
  if node.StamBarFill then node.StamBarFill.Size=UDim2.fromScale(e.Stamina/100,1) end
  if node.Highlight then
   node.Highlight.OutlineColor=_G.ClientCombatState.FocusedNetId==id and Color3.fromRGB(0,255,235) or bit32.band(e.Flags,2)~=0 and Color3.fromRGB(255,195,40) or Color3.new(1,1,1)
  end
  if meta.MobType=="WORLD_BOSS" then
   _G.ClientCombatState.WorldBossNetId=id;_G.ClientCombatState.WorldBossHPPerMille=e.HpPermille
   _G.ClientCombatState.WorldBossPhase=math.max(1,e.StateEnum-10);_G.ClientCombatState.WorldBossCoreExposed=bit32.band(e.Flags,8)~=0
  end
  if e.ActionSequence~=0 then requestEntityMetadata() end -- Part 3 supplies authored action playback.
 end
end
TowerRemotes.TowerSnapshot.OnClientEvent:Connect(consume)
TowerRemotes.TowerEntityState.OnClientEvent:Connect(function(context,message)
 if not Protocol.Same(context,View) or type(message)~="table" then return end
 local revision=message.BootstrapRevision
 if type(revision)~="number" or revision<=LastBootstrap then return end
 if message.Kind=="BOOTSTRAP" then
  if not Protocol.Integer(message.BatchCount,1,512) or not Protocol.Integer(message.BatchIndex,1,message.BatchCount) or type(message.Entities)~="table" or #message.Entities>32 then return end
  if not Assembly or Assembly.Revision~=revision then Assembly={Revision=revision,Count=message.BatchCount,Chunks={},Started=os.clock()} end
  if Assembly.Count~=message.BatchCount then Assembly=nil;requestEntityMetadata();return end
  Assembly.Chunks[message.BatchIndex]=message.Entities
 elseif message.Kind=="COMPLETE" then
  if not Assembly or Assembly.Revision~=revision then requestEntityMetadata();return end
  local nextMetadata={}
  for i=1,Assembly.Count do
   local chunk=Assembly.Chunks[i];if not chunk then Assembly=nil;requestEntityMetadata();return end
   for _,entry in chunk do
    if not Protocol.Integer(entry.NetId,1,4294967295) or not Protocol.Integer(entry.EntityGeneration,1,4294967295) or nextMetadata[entry.NetId] then Assembly=nil;requestEntityMetadata();return end
    if entry.EntityGeneration<(Generations[entry.NetId] or 0) then continue end
    nextMetadata[entry.NetId]=entry
   end
  end
  for id,node in pairs(VisualNodesByNetId) do
   local new=nextMetadata[id];local old=MetadataByNetId[id]
   if not new or not old or new.EntityGeneration~=old.EntityGeneration then node.Model:Destroy();VisualNodesByNetId[id]=nil;EntitySequences[id]=nil end
  end
  for id,entry in pairs(nextMetadata) do Generations[id]=entry.EntityGeneration end
  MetadataByNetId=nextMetadata;_G.ClientCombatState.Metadata=MetadataByNetId
  LastBootstrap=revision;Assembly=nil;Bootstrapped=true
  local pending=Buffered;Buffered={};for _,buf in pending do consume(buf) end
 end
end)
-- Reliable full roster cuts define existence. Packet loss only freezes poses and requests resync.
RunService.Heartbeat:Connect(function()
 local now=os.clock()
 if Assembly and now-Assembly.Started>3 then Assembly=nil;requestEntityMetadata() end
 for _,node in pairs(VisualNodesByNetId) do if now-node.LastSeenClock>1 then requestEntityMetadata() end end
end)
requestEntityMetadata()

`+s.slice(b);
s=s.replace('function(telegraphType: number, originXZ:', 'function(context: any, telegraphType: number, originXZ:');
s=s.replace('\tlocal durationSec = durationMs / 1000.0','\tif not Protocol.Same(context,View) then return end\n\tlocal durationSec = durationMs / 1000.0');
s=s.replace('function(vfxType: string, pos:', 'function(context: any, vfxType: string, pos:');
s=s.replace('\tif vfxType == "WHISTLE_Q"', '\tif not Protocol.Same(context,View) then return end\n\tif vfxType == "WHISTLE_Q"');
write('src/StarterPlayerScripts/Rendering/EntityRenderer.client.luau',s);
s=read('src/ServerScriptService/ExtractionAndSocial/RelicService.server.luau');
s=s.replace('local RelicService = {}','local Tower=require(script.Parent.Parent.Core.TowerFloorService)\nTower.Init()\nlocal RelicService = {}');
s=s.replace('RelicId: number,','RelicId: number,\n\tFloorId: number,\n\tRoomGeneration: number,');
s=s.replace('\tlocal relic: ActiveRelic = {','\tlocal context=assert(Tower.ContextAt(worldPos),"Relic spawn outside room")\n\tlocal relic: ActiveRelic = {\n\t\tFloorId=context.FloorId,RoomGeneration=context.RoomGeneration,');
s=s.replace('local now = os.clock()\n\tif relic.Carrier', 'local now = os.clock()\n\tif Tower.IsTransitioning(player) or not Tower.Same(Tower.GetState(player),relic) or ActiveRelics[relic.RelicId]~=relic or now>=relic.DespawnAt then return false end\n\tif relic.Carrier');
s=s.replace('if not relic then return false end','if not relic then return false end\n\tTower.CancelPending(carrier,"CARGO_CHANGED")');
s=s.replace('relic.Part.Position = ground and (ground.Position + Vector3.new(0, relic.Part.Size.Y / 2 + 0.2, 0)) or position','relic.Part.Position = Tower.GroundDrop(relic,position,relic.Part.Size.Y/2)');
s=s.replace('relic.Part.Position = Vector3.new(dropPos.X, math.max(3.5, dropPos.Y), dropPos.Z)','relic.Part.Position = Tower.GroundDrop(relic,dropPos,relic.Part.Size.Y/2)');
s=s.replace('local now = os.clock()\n\tif relic.Weld', 'Tower.CancelPending(carrier,"CARGO_CHANGED")\n\tlocal now = os.clock()\n\tif relic.Weld');
s=s.replace('function RelicService.ExtractOnPrivatePad(carrier: Player)','function RelicService.ExtractOnPrivatePad(carrier: Player)\n\tlocal location=Tower.GetState(carrier)\n\tif location.FloorId~=0 or not location.BankArmed or Tower.IsTransitioning(carrier) then return end');
s=s.replace('\tlocal spec = RelicConfig[relic.TierId]\n\tawardRelicPayout',` local hum,root=getCharacterParts(carrier)
 if not hum or hum.Health<=0 or not root or relic.Carrier~=carrier or not Tower.Same(location,relic) or os.clock()>=relic.DespawnAt then return end
 local validPad=false
 for _,plot in PlotsFolder:GetChildren() do
  local pad=plot:FindFirstChild("PrivateExtractionPad")
  if plot:GetAttribute("OwnerUserId")==carrier.UserId and pad and pad:IsA("BasePart") then
   local at=pad.CFrame:PointToObjectSpace(root.Position)
   if math.abs(at.X)<=pad.Size.X/2+2 and math.abs(at.Z)<=pad.Size.Z/2+2 and at.Y>=-2 and at.Y<=12 then validPad=true;break end
  end
 end
 if not validPad then return end
 local spec = RelicConfig[relic.TierId]
 -- Remove authoritative identity before payout/replication to make reentry idempotent.
 CarrierToRelic[carrier]=nil;ActiveRelics[relic.RelicId]=nil
 awardRelicPayout`);
s=s.replace('ownerId == carrier.UserId or ownerId == 0','ownerId == carrier.UserId');
s=s.replace('if relic.Carrier == nil then','if now>=relic.DespawnAt then destroyRelicInstance(relic);continue end\n\t\tif relic.Carrier == nil then');
s=s.replace('RelicStateRemote:FireAllClients(relicId, tierId,','Tower.BroadcastAt(RelicStateRemote,relic,relicId, tierId,');
s=s.replaceAll('RelicStateRemote:FireAllClients(relic.RelicId, relic.TierId,','Tower.BroadcastAt(RelicStateRemote,relic,relic.RelicId, relic.TierId,');
s=s.replace('_G.RelicService = RelicService',`Tower.RegisterAdapter("Relic",{
 CaptureCargo=function(player) return CarrierToRelic[player] end,
 DropCargo=function(player)
  local relic=CarrierToRelic[player]
  if relic then RelicService.DropCarriedRelic(player);relic.LockedUserId=nil;relic.LockExpiresAt=0 end
 end,
 Pins=function(id,gen) for _,relic in pairs(ActiveRelics) do if relic.FloorId==id and relic.RoomGeneration==gen then return true end end;return false end,
})
if RunService:IsStudio() then RelicService.DebugRelics=function() return ActiveRelics,CarrierToRelic end end
_G.RelicService = RelicService`);
write('src/ServerScriptService/ExtractionAndSocial/RelicService.server.luau',s);
