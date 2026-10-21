--!strict
-- Session-only shared room/travel authority. All commits and adapter calls are non-yielding.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Protocol=require(RS.Shared.Util.TowerProtocol)
local Policy=require(RS.Shared.Util.TowerRequestPolicy)
local Builder=require(script.Parent.TowerRoomBuilder)
local Service={}
Service.SessionId=Http:GenerateGUID(false):gsub("-",""):lower()
Service.Encounters={} -- retained across geometry retirement; Part 3 owns combat/reward contents
local states: {[Player]:any}={}
local rooms: {[number]:any}={}
local generations: {[number]:number}={}
local adapters: {[string]:any}={}
local presenceRevision=0
local started=false
local remotes: any
local function remoteFolder(): any
	local root=RS:WaitForChild("Remotes")
	local f=root:FindFirstChild("TowerRemotes") or Instance.new("Folder");f.Name="TowerRemotes";f.Parent=root
	for _,name in {"Request","Response","Context","Ready","Presence","TowerEntityState","TowerAction","TowerSnapshot","OpenSelector"} do
		if not f:FindFirstChild(name) then local e=Instance.new(name=="TowerSnapshot" and "UnreliableRemoteEvent" or "RemoteEvent");e.Name=name;e.Parent=f end
	end
	return f
end
local function createState(player: Player): any
	local s=states[player]
	if not s then
		s={FloorId=0,RoomGeneration=1,LocationRevision=0,SquadRevision=0,CharacterGeneration=0,ViewEpoch=1,
			SquadFloorId=0,SquadRoomGeneration=1,SquadSize=0,Subscribed=false,Ledger={},Order={},Tokens=4,TokenAt=os.clock(),ControlTokens=4,ControlAt=os.clock(),BankArmed=false}
		states[player]=s
	end
	return s
end
function Service.GetState(player: Player): any return createState(player) end
function Service.GetRoom(id: number): any return rooms[id] end
function Service.IsTransitioning(player: Player): boolean local s=states[player];return s~=nil and s.Pending~=nil end
function Service.RegisterAdapter(name: string,adapter: any) adapters[name]=adapter end
function Service.EnsureRoom(id: number): any
	if rooms[id] and rooms[id].Status=="READY" then return rooms[id] end
	assert(Protocol.Integer(id,1,50),"Invalid room")
	local gen=(generations[id] or 0)+1;generations[id]=gen
	rooms[id]={FloorId=id,RoomGeneration=gen,Status="BUILDING",Reservations=0}
	local ok,room=pcall(Builder.Build,id,gen)
	if not ok then rooms[id].Status="FAILED";rooms[id].Error=tostring(room);error(room) end
	room.Status="READY";room.Reservations=0;room.EmptySince=os.clock();rooms[id]=room
	Service.Encounters[id]=Service.Encounters[id] or {Seed=id,BossGeneration=0,PayoutClaims={},EncountersEnabled=false}
	return room
end
function Service.Context(player: Player): any
	local s=createState(player);local r=rooms[s.FloorId]
	return {ContractVersion=1,ServerSessionId=Service.SessionId,FloorId=s.FloorId,RoomGeneration=s.RoomGeneration,ViewEpoch=s.ViewEpoch,
		CharacterGeneration=s.CharacterGeneration,LocationRevision=s.LocationRevision,Origin=r.Origin,Bounds=r.Bounds,Arrival=r.Arrival}
end
function Service.Same(a: any,b: any): boolean
	return a~=nil and b~=nil and a.FloorId~=nil and a.FloorId==b.FloorId and a.RoomGeneration==b.RoomGeneration
end
function Service.ContextAt(position: Vector3): any?
	for id,r in pairs(rooms) do
		if r.Status=="READY" and Protocol.InBounds(position,r.Origin,r.Bounds) then return {FloorId=id,RoomGeneration=r.RoomGeneration} end
	end
	return nil
end
function Service.GetSafety(context: any,position: Vector3): any
	local r=context and rooms[context.FloorId]
	if not r or r.RoomGeneration~=context.RoomGeneration then return {} end
	for _,z in r.Zones do if Protocol.InZone(position,r.Origin,z) then return z end end
	return {}
end
function Service.GroundDrop(context: any,position: Vector3,halfHeight: number): Vector3
	local r=assert(rooms[context.FloorId],"Drop room absent")
	local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances=r.Model and {r.Model} or {workspace.BaseOverhaulGeometry,workspace.WaitingRoomPlots}
	local hit=workspace:Raycast(position+Vector3.new(0,8,0),Vector3.new(0,-64,0),params)
	if hit and hit.Normal.Y>.65 and Protocol.InBounds(hit.Position,r.Origin,r.Bounds) then return hit.Position+Vector3.new(0,halfHeight+.2,0) end
	return r.Arrival.Position+Vector3.new(0,halfHeight-3,0)
end
function Service.BroadcastAt(remote: any,context: any,...: any)
	for player,s in pairs(states) do if player.Parent==Players and Service.Same(s,context) then remote:FireClient(player,Service.Context(player),...) end end
end
function Service.GetPresence(player: Player): any
	local floors={}
	for id=0,50 do floors[id+1]={FloorId=id,Visitors={},Squads={}} end
	for p,s in pairs(states) do
		if p.Parent==Players then
			local who={UserId=p.UserId,Username=p.Name,DisplayName=p.DisplayName}
			table.insert(floors[s.FloorId+1].Visitors,who)
			if s.SquadSize>0 then local q=table.clone(who);q.RosterSize=s.SquadSize;q.SquadRevision=s.SquadRevision;table.insert(floors[s.SquadFloorId+1].Squads,q) end
		end
	end
	local s=createState(player)
	return {ContractVersion=1,ServerSessionId=Service.SessionId,PresenceRevision=presenceRevision,Floors=floors,
		Self={PlayerLocation={FloorId=s.FloorId,RoomGeneration=s.RoomGeneration},SquadAssignment=s.SquadAssignment,
			SquadContext={FloorId=s.SquadFloorId,RoomGeneration=s.SquadRoomGeneration},CharacterGeneration=s.CharacterGeneration,
			LocationRevision=s.LocationRevision,SquadRevision=s.SquadRevision,PendingRequestId=s.Pending and s.Pending.RequestId}}
end
local function publish()
	presenceRevision+=1
	if not remotes then return end
	for p,s in pairs(states) do if p.Parent==Players and s.Subscribed then remotes.Presence:FireClient(p,Service.GetPresence(p)) end end
end
local function reply(player: Player,id: string,status: string,err: string?): any
	local s=createState(player)
	local r={ContractVersion=1,RequestId=id,Status=status,ErrorCode=err,LocationRevision=s.LocationRevision,SquadRevision=s.SquadRevision}
	if player.Parent==Players then remotes.Response:FireClient(player,r) end
	return r
end
local function saveResult(s: any,id: string,fp: string,result: any)
	s.Ledger[id]={Fingerprint=fp,Result=result,At=os.clock()};table.insert(s.Order,id)
	while #s.Order>64 do s.Ledger[table.remove(s.Order,1)]=nil end
end
local function finish(player: Player,status: string,err: string?)
	local s=states[player];local pending=s and s.Pending;if not pending then return end
	s.Pending=nil
	if pending.Room then pending.Room.Reservations=math.max(0,pending.Room.Reservations-1) end
	if status~="COMMITTED" and pending.View and player.Parent==Players then
		local c=Service.Context(player);c.Stage="ABORT";c.RequestId=pending.RequestId;remotes.Context:FireClient(player,c)
	end
	saveResult(s,pending.RequestId,pending.Fingerprint,reply(player,pending.RequestId,status,err));publish()
end
function Service.CancelPending(player: Player,err: string?) finish(player,"CANCELED",err or "CANCELED") end
local function alive(player: Player): (Model?,BasePart?)
	local c=player.Character;local h=c and c:FindFirstChildOfClass("Humanoid");local root=c and c:FindFirstChild("HumanoidRootPart")
	if not h or h.Health<=0 or not root or not root:IsA("BasePart") then return nil,nil end
	return c,root
end
local function commit(player: Player)
	local s=states[player];local p=s and s.Pending;if not p then return end
	local char,root=alive(player)
	if not char or not root or char~=p.Character or s.CharacterGeneration~=p.CharacterGeneration then finish(player,"REJECTED","CHARACTER_NOT_READY");return end
	if s.LocationRevision~=p.LocationRevision or s.SquadRevision~=p.SquadRevision then finish(player,"REJECTED","STALE_REVISION");return end
	local r=p.Room
	if os.clock()>p.Deadline or r.Status~="READY" or rooms[r.FloorId]~=r then finish(player,"REJECTED","ROOM_NOT_READY");return end
	local hitParams=RaycastParams.new();hitParams.FilterType=Enum.RaycastFilterType.Include
	hitParams.FilterDescendantsInstances=r.Model and {r.Model} or {workspace.BaseOverhaulGeometry}
	local hit=workspace:Raycast(r.Arrival.Position,Vector3.new(0,-12,0),hitParams)
	if not hit or hit.Normal.Y<.65 or not Protocol.InBounds(r.Arrival.Position,r.Origin,r.Bounds) then finish(player,"REJECTED","UNSAFE_ARRIVAL");return end
	local combat=adapters.Combat
	if not combat then finish(player,"REJECTED","PROFILE_NOT_READY");return end
	if not _G.DataManager or not _G.DataManager.GetProfile(player) then finish(player,"REJECTED","PROFILE_NOT_READY");return end
	local movingSquad=not p.View or s.SquadAssignment==nil
	if not combat.ValidateRoster(player) then finish(player,"REJECTED","ROSTER_CHANGED");return end
	if not p.View and combat.Count(player)==0 then finish(player,"REJECTED","NO_ELIGIBLE_SQUAD");return end
	if p.Action=="RECALL" and not combat.CanRecall(player) then finish(player,"REJECTED","RECALL_COOLDOWN");return end
	-- Capture live cargo now. Preparation never snapshots HP, cooldowns, or item state.
	local records={}
	if p.View then
		for _,a in pairs(adapters) do if a.CaptureCargo then
			local record=a.CaptureCargo(player)
			if record then
				if not record.Part or not record.Part.Parent or not record.Weld or not record.Weld.Parent or record.Weld.Part0~=root then finish(player,"REJECTED","CARGO_CHANGED");return end
				table.insert(records,{Ref=record,Position=record.Part.CFrame,FloorId=record.FloorId,RoomGeneration=record.RoomGeneration})
			end
		end end
		if #records>1 then finish(player,"REJECTED","CARGO_CHANGED");return end
	end
	local source=char:GetPivot()
	local squadSnapshot=movingSquad and combat.CaptureSquad(player) or nil
	local ok,transferError=pcall(function()
		if p.View then
			char:PivotTo(r.Arrival)
			root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
			for _,entry in records do
				local item=entry.Ref;item.Part.CFrame=r.Arrival*(source:ToObjectSpace(entry.Position))
				item.FloorId=r.FloorId;item.RoomGeneration=r.RoomGeneration
			end
		end
		if movingSquad then combat.Transfer(player,r,p.Action=="RECALL",(p.View or p.Action=="RECALL") and root.Position or nil) end
	end)
	if not ok then
		warn("Tower transfer rolled back: "..tostring(transferError))
		char:PivotTo(source);for _,entry in records do entry.Ref.Part.CFrame=entry.Position;entry.Ref.FloorId=entry.FloorId;entry.Ref.RoomGeneration=entry.RoomGeneration end
		if squadSnapshot then combat.RestoreSquad(squadSnapshot) end
		finish(player,"REJECTED","TRANSFER_FAILED");return
	end
	if p.View then
		s.FloorId=r.FloorId;s.RoomGeneration=r.RoomGeneration;s.LocationRevision+=1;s.ViewEpoch=p.ViewEpoch;s.BankArmed=false
		char:SetAttribute("TowerFloorId",s.FloorId)
	end
	if movingSquad then
		s.SquadFloorId=r.FloorId;s.SquadRoomGeneration=r.RoomGeneration;s.SquadRevision+=1
		if p.Action=="ASSIGN" then s.SquadAssignment=r.FloorId elseif p.Action=="RECALL" then s.SquadAssignment=nil end
	end
	if p.View then local c=Service.Context(player);c.Stage="COMMIT";c.RequestId=p.RequestId;remotes.Context:FireClient(player,c) end
	combat.BootstrapAll()
	finish(player,"COMMITTED")
end
local function take(s: any,control: boolean): boolean
	local tk,at=control and "ControlTokens" or "Tokens",control and "ControlAt" or "TokenAt"
	local now=os.clock();s[tk]=math.min(4,s[tk]+(now-s[at])*2);s[at]=now
	if s[tk]<1 then return false end;s[tk]-=1;return true
end
function Service.Request(player: Player,r: any)
	local s=createState(player)
	local ok,err=Policy.Validate(r)
	if not ok then if take(s,true) then reply(player,type(r)=="table" and type(r.RequestId)=="string" and r.RequestId:sub(1,64) or "INVALID","REJECTED",err) end;return end
	local fp=Policy.Fingerprint(r)
	for id,v in pairs(s.Ledger) do if os.clock()-v.At>60 then s.Ledger[id]=nil end end
	local stored=s.Ledger[r.RequestId]
	if stored then if stored.Fingerprint==fp then remotes.Response:FireClient(player,stored.Result) else reply(player,r.RequestId,"REJECTED","REQUEST_ID_CONFLICT") end;return end
	if s.Pending and s.Pending.RequestId==r.RequestId then reply(player,r.RequestId,s.Pending.Fingerprint==fp and "PENDING" or "REJECTED",s.Pending.Fingerprint~=fp and "REQUEST_ID_CONFLICT" or nil);return end
	if not take(s,r.Action=="CANCEL") then reply(player,r.RequestId,"REJECTED","RATE_LIMITED");return end
	local function reject(e: string) saveResult(s,r.RequestId,fp,reply(player,r.RequestId,"REJECTED",e)) end
	if r.Action=="CANCEL" then
		if s.Pending and s.Pending.RequestId==r.CancelRequestId then finish(player,"CANCELED","CANCELED") end
		saveResult(s,r.RequestId,fp,reply(player,r.RequestId,"COMMITTED"));return
	end
	if r.Action=="PRESENCE_SUBSCRIBE" or r.Action=="RESYNC" then
		if os.clock()-(s.LastSubscription or -99)<1 then reject("RATE_LIMITED");return end;s.LastSubscription=os.clock()
		if r.Action=="RESYNC" and not Protocol.Same(r,Service.Context(player)) then reject("STALE_REVISION");return end
		s.Subscribed=true
		if r.Action=="PRESENCE_SUBSCRIBE" then local c=Service.Context(player);c.Stage="COMMIT";c.RequestId=r.RequestId;remotes.Context:FireClient(player,c) end
		remotes.Presence:FireClient(player,Service.GetPresence(player));if adapters.Combat then adapters.Combat.Bootstrap(player) end
		saveResult(s,r.RequestId,fp,reply(player,r.RequestId,"COMMITTED"));return
	elseif r.Action=="PRESENCE_UNSUBSCRIBE" then s.Subscribed=false;saveResult(s,r.RequestId,fp,reply(player,r.RequestId,"COMMITTED"));return end
	if s.Pending then reject("BUSY");return end
	if r.CharacterGeneration~=s.CharacterGeneration or r.ExpectedLocationRevision~=s.LocationRevision or r.ExpectedSquadRevision~=s.SquadRevision then reject("STALE_REVISION");return end
	local char=alive(player)
	if not char then reject("CHARACTER_NOT_READY");return end
	if not _G.DataManager or not _G.DataManager.GetProfile(player) then reject("PROFILE_NOT_READY");return end
	local id=r.Action=="HUB" and 0 or r.Action=="RECALL" and s.FloorId or r.FloorId
	if r.Action=="ASSIGN" and s.SquadAssignment==id and s.SquadSize>0 then saveResult(s,r.RequestId,fp,reply(player,r.RequestId,"COMMITTED"));return end
	local p={RequestId=r.RequestId,Fingerprint=fp,Action=r.Action,View=r.Action=="VISIT" or r.Action=="HUB",Character=char,
		CharacterGeneration=s.CharacterGeneration,LocationRevision=s.LocationRevision,SquadRevision=s.SquadRevision,Deadline=os.clock()+8,ViewEpoch=s.ViewEpoch+1}
	s.Pending=p;reply(player,r.RequestId,"PENDING");publish()
	local success,room=pcall(function() return id==0 and rooms[0] or Service.EnsureRoom(id) end)
	if not success then warn("Tower room build: "..tostring(room));finish(player,"REJECTED","ROOM_NOT_READY");return end
	p.Room=room;room.Reservations+=1
	if not p.View then commit(player);return end
	p.Token=Http:GenerateGUID(false)
	local c={ContractVersion=1,RequestId=p.RequestId,Stage="PREPARE",ServerSessionId=Service.SessionId,FloorId=id,RoomGeneration=room.RoomGeneration,
		ViewEpoch=p.ViewEpoch,CharacterGeneration=s.CharacterGeneration,Origin=room.Origin,Bounds=room.Bounds,Arrival=room.Arrival,
		ReadyToken=p.Token,ReadyDeadline=workspace:GetServerTimeNow()+math.max(0,p.Deadline-os.clock()),LocationRevision=s.LocationRevision}
	remotes.Context:FireClient(player,c)
	task.delay(math.max(0,p.Deadline-os.clock()),function() if states[player] and states[player].Pending==p then finish(player,"REJECTED","READY_TIMEOUT") end end)
end
function Service.Ready(player: Player,r: any)
	local s=states[player];if not s or not take(s,true) or type(r)~="table" then return end
	for k in pairs(r) do if not ({ContractVersion=true,RequestId=true,ReadyToken=true,ViewEpoch=true,CharacterGeneration=true,Result=true})[k] then return end end
	local p=s.Pending
	if not p or not p.View or r.ContractVersion~=1 or r.RequestId~=p.RequestId or r.ReadyToken~=p.Token or r.ViewEpoch~=p.ViewEpoch or r.CharacterGeneration~=p.CharacterGeneration then return end
	if r.Result=="READY" then commit(player) elseif r.Result=="FAILED" then finish(player,"REJECTED","STREAMING_FAILED") end
end
function Service.VisitFloor(player: Player,id: number,request: any) request.Action="VISIT";request.FloorId=id;Service.Request(player,request) end
function Service.ReturnToHub(player: Player,request: any) request.Action="HUB";Service.Request(player,request) end
function Service.AssignSquad(player: Player,id: number,request: any) request.Action="ASSIGN";request.FloorId=id;Service.Request(player,request) end
function Service.Recall(player: Player,request: any?)
	local s=createState(player)
	Service.Request(player,request or {ContractVersion=1,RequestId=Http:GenerateGUID(false),Action="RECALL",CharacterGeneration=s.CharacterGeneration,
		ExpectedLocationRevision=s.LocationRevision,ExpectedSquadRevision=s.SquadRevision})
end
function Service.RosterChanged(player: Player,size: number)
	local s=createState(player);Service.CancelPending(player,"ROSTER_CHANGED");s.SquadSize=size;s.SquadRevision+=1
	if size==0 then s.SquadAssignment=nil;s.SquadFloorId=s.FloorId;s.SquadRoomGeneration=s.RoomGeneration end
	publish()
end
function Service.CommitRespawn(player: Player)
	local s=createState(player);Service.CancelPending(player,"CHARACTER_CHANGED")
	s.FloorId=0;s.RoomGeneration=1;s.LocationRevision+=1;s.ViewEpoch+=1;s.BankArmed=false
	if player.Character then player.Character:SetAttribute("TowerFloorId",0) end
	if not s.SquadAssignment and adapters.Combat then adapters.Combat.Transfer(player,rooms[0],false,player.Character and player.Character:GetPivot().Position);s.SquadFloorId=0;s.SquadRoomGeneration=1;s.SquadRevision+=1 end
	if remotes then local c=Service.Context(player);c.Stage="COMMIT";c.RequestId="RESPAWN";remotes.Context:FireClient(player,c) end
	if adapters.Combat then adapters.Combat.BootstrapAll() end;publish()
end
local function disconnectCargo(player: Player)
	for _,a in pairs(adapters) do if a.DropCargo then a.DropCargo(player) end end
end
function Service.Init()
	if started then return end;started=true;remotes=remoteFolder()
	local zones={}
	-- Authored polygon belt and bounded plot boxes. Distance from origin grants no privilege.
	for i=0,23 do
		local a,b=i*math.pi/12,(i+1)*math.pi/12
		table.insert(zones,{ZoneId="HUB_BANK_"..i,FloorId=0,RoomGeneration=1,LocalPolygonXZ={Vector2.new(math.cos(a)*460,math.sin(a)*460),Vector2.new(math.cos(b)*460,math.sin(b)*460),Vector2.new(math.cos(b)*760,math.sin(b)*760),Vector2.new(math.cos(a)*760,math.sin(a)*760)},MinY=-10,MaxY=100,CombatSafe=true,CanBankCargo=true,CanRecoverWipe=true})
	end
	rooms[0]={FloorId=0,RoomGeneration=1,Origin=Vector3.zero,Arrival=CFrame.new(0,19.5,-330),Bounds={Min=Vector3.new(-1500,-100,-1500),Max=Vector3.new(1500,2500,1500)},Zones=zones,Status="READY",Reservations=0}
	local plots=workspace:WaitForChild("WaitingRoomPlots")
	for _,plot in plots:GetChildren() do local spawn=plot:FindFirstChild("PlotSpawn");if spawn and spawn:IsA("BasePart") then
		local p=spawn.Position;table.insert(zones,{ZoneId=plot.Name,FloorId=0,RoomGeneration=1,LocalPolygonXZ={Vector2.new(p.X-60,p.Z-60),Vector2.new(p.X+60,p.Z-60),Vector2.new(p.X+60,p.Z+60),Vector2.new(p.X-60,p.Z+60)},MinY=p.Y-15,MaxY=p.Y+60,CombatSafe=true,CanBankCargo=true,CanRecoverWipe=true})
	end end
	remotes.Request.OnServerEvent:Connect(Service.Request);remotes.Ready.OnServerEvent:Connect(Service.Ready)
	local function playerAdded(player: Player)
		createState(player)
		local function added(char: Model)
			local s=createState(player);s.CharacterGeneration+=1;Service.CancelPending(player,"CHARACTER_CHANGED")
			local h=char:WaitForChild("Humanoid",10)
			if h then (h :: Humanoid).Died:Connect(function() Service.CancelPending(player,"CHARACTER_DIED");disconnectCargo(player) end) end
		end
		player.CharacterAdded:Connect(added)
		player.CharacterRemoving:Connect(function() Service.CancelPending(player,"CHARACTER_CHANGED");disconnectCargo(player) end)
		if player.Character then task.spawn(added,player.Character) end
	end
	Players.PlayerAdded:Connect(playerAdded);for _,p in Players:GetPlayers() do playerAdded(p) end
	Players.PlayerRemoving:Connect(function(player) Service.CancelPending(player,"DISCONNECTED");disconnectCargo(player);states[player]=nil;publish() end)
	local elapsed=0
	RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt;if elapsed<1 then return end;elapsed=0
		for player,s in pairs(states) do
			local char,root=alive(player);local r=rooms[s.FloorId]
			if char and root and r and s.FloorId~=0 and not Protocol.InBounds(root.Position,r.Origin,r.Bounds) then
				char:PivotTo(r.Arrival);root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero
			end
			if root and not Service.GetSafety(s,root.Position).CanBankCargo then s.BankArmed=true end
		end
		for id,r in pairs(rooms) do if id~=0 and r.Status=="READY" then
			local pinned=r.Reservations>0
			for _,s in pairs(states) do if s.FloorId==id or (s.SquadSize>0 and s.SquadFloorId==id) then pinned=true end end
			for _,a in pairs(adapters) do if a.Pins and a.Pins(id,r.RoomGeneration) then pinned=true end end
			if pinned then r.EmptySince=os.clock() elseif os.clock()-r.EmptySince>=60 then
				r.Status="RETIRING";r.Model:Destroy();rooms[id]=nil
			end
		end end
	end)
end
return Service
