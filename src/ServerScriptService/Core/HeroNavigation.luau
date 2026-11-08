--!strict
-- Shared server feet-position movement for heroes and enemies.
local Workspace=game:GetService("Workspace")
local Players=game:GetService("Players")
local PathfindingService=game:GetService("PathfindingService")
local Layout=require(game.ReplicatedStorage.Shared.Config.TowerLayout)
local Graph=require(script.Parent.TowerNavigationGraph)
local Recovery=require(script.Parent.NavigationRecovery)
local Queue=require(script.Parent.NavigationQueue)
local TowerTraversal=require(script.Parent.TowerTraversal)
local Navigation={}
local states: {[any]:any}=setmetatable({},{__mode="k"}) :: any
local graphs: {[number]:any}={}
local RADIUS,HEIGHT,STEP_UP,MAX_DROP=1.2,4.8,2.2,3.5
local diagnostics: any=if game:GetService("RunService"):IsStudio()then {
	Steps=0,GroundQueries=0,BodyQueries=0,PathRequests=0,PathSuccess=0,PathFailure=0,PeakComputing=0,StalePaths=0,
}else nil
local exclusions: {Instance}={}
local function refreshExclusions()
	local list: {Instance}={}
	for _,name in {"ClientVisualEntities","PhysicalRelics","ModelViewer"}do
		local f=Workspace:FindFirstChild(name);if f then table.insert(list,f)end
	end
	for _,p in Players:GetPlayers()do if p.Character then table.insert(list,p.Character)end end
	exclusions=list
end
local function trackPlayer(p: Player)
	p.CharacterAdded:Connect(function()task.defer(refreshExclusions)end)
	p.CharacterRemoving:Connect(function()task.defer(refreshExclusions)end)
end
refreshExclusions()
for _,p in Players:GetPlayers()do trackPlayer(p)end
Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function()task.defer(refreshExclusions)end)
Workspace.ChildAdded:Connect(refreshExclusions)
local function parameters(group: string?): RaycastParams
	local p=RaycastParams.new()
	p.FilterType=Enum.RaycastFilterType.Exclude;p.FilterDescendantsInstances=exclusions
	p.RespectCanCollide=true;p.IgnoreWater=true;p.CollisionGroup=group or "Default"
	return p
end
function Navigation.Ground(position: Vector3,group: string?,up: number?,down: number?): Vector3?
	if diagnostics then diagnostics.GroundQueries+=1 end
	local rise,drop=up or STEP_UP,down or MAX_DROP
	local hit=Workspace:Raycast(position+Vector3.new(0,rise,0),Vector3.new(0,-rise-drop,0),parameters(group))
	return if hit and hit.Normal.Y>=.65 then hit.Position else nil
end
local function groupFor(hero: any): string
	local char=hero.Owner and hero.Owner.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	return if root then root.CollisionGroup else "Default"
end
local function flatDistance(a: Vector3,b: Vector3): number
	return Vector3.new(a.X-b.X,0,a.Z-b.Z).Magnitude
end
local function allowed(position: Vector3,origin: Vector3?,corridor: any,previous: Vector3): boolean
	if not corridor or not origin then return true end
	local p=position-origin
	local dx,dz=corridor.BX-corridor.AX,corridor.BZ-corridor.AZ
	local length2=dx*dx+dz*dz
	local t=((p.X-corridor.AX)*dx+(p.Z-corridor.AZ)*dz)/length2
	if t<0 or t>1 then return true end
	local lateral=math.abs((p.X-corridor.AX)*dz-(p.Z-corridor.AZ)*dx)/math.sqrt(length2)
	local before=previous-origin
	local previousLateral=math.abs((before.X-corridor.AX)*dz-(before.Z-corridor.AZ)*dx)/math.sqrt(length2)
	return lateral<=corridor.UsableWidth/2 or lateral<previousLateral-.01
end
local function walkSegment(from: Vector3,toward: Vector3,distance: number,group: string,origin: Vector3?,corridor: any): (Vector3,boolean,string?)
	local flat=Vector3.new(toward.X-from.X,0,toward.Z-from.Z)
	if flat.Magnitude<.01 then return from,math.abs(toward.Y-from.Y)<STEP_UP,"HEIGHT" end
	local travel=math.min(distance,flat.Magnitude)
	local direction=flat.Unit
	local count=math.max(1,math.ceil(travel/1.5))
	local at=from
	local params=parameters(group)
	for _=1,count do
		local ground=Navigation.Ground(at+direction*(travel/count),group)
		if not ground then return at,false,"NO_SUPPORT" end
		if not allowed(ground,origin,corridor,at)then return at,false,"CORRIDOR_EDGE" end
		local across=Vector3.new(-direction.Z,0,direction.X)*RADIUS
		for _,offset in {across+direction*RADIUS,across-direction*RADIUS,-across+direction*RADIUS,-across-direction*RADIUS}do
			local support=Navigation.Ground(ground+offset,group)
			if not support or math.abs(support.Y-ground.Y)>MAX_DROP then return at,false,"UNSUPPORTED_SHOULDER" end
		end
		if diagnostics then diagnostics.BodyQueries+=1 end
		local delta=ground-at
		if delta.Magnitude>.001 then
			local hit=Workspace:Blockcast(CFrame.new(at+Vector3.new(0,3.5,0)),Vector3.new(RADIUS*2,2.5,RADIUS*2),delta,params)
			if hit then return at,false,"BODY" end
		end
		at=ground
	end
	return at,true,nil
end
local function clearRoute(from: Vector3,goal: Vector3,group: string): boolean
	local distance=flatDistance(from,goal)
	if distance>180 or math.abs(from.Y-goal.Y)>45 then return false end
	local at,clear=walkSegment(from,goal,distance,group,nil,nil)
	return clear and (at-goal).Magnitude<.5
end
function Navigation.CanShortcut(from: Vector3,goal: Vector3,group: string?): boolean
	if math.abs(from.Y-goal.Y)>4.5 or flatDistance(from,goal)>42 then return false end
	return clearRoute(from,goal,group or "Default")
end
function Navigation.PlaceOnGround(feet: Vector3,offset: Vector3,group: string?): Vector3
	local base=Navigation.Ground(feet,group,2.2,3.5)or feet
	local desired=Navigation.Ground(base+offset,group)
	return if desired and clearRoute(base,desired,group or "Default")then desired else base
end
-- Root-position compatibility wrapper for existing recalls and spawns.
function Navigation.PlaceNear(root: Vector3,offset: Vector3,group: string?): Vector3
	local feet=root-Vector3.new(0,3,0)
	feet=Navigation.Ground(feet,group,4,50)or feet
	return Navigation.PlaceOnGround(feet,offset,group)
end
local function intent(hero: any): string
	return if hero.State=="FOLLOW_MASTER"then "FOLLOW"else tostring(hero.TargetNetId or hero.State or "MOVE")
end
local function identity(hero: any,s: any): any
	return {Revision=s.Revision,FloorId=hero.FloorId,RoomGeneration=hero.RoomGeneration,
		EntityGeneration=hero.EntityGeneration,Intent=intent(hero)}
end
local jobs: any
jobs=Queue.new(12,512,function(job: any,done: ()->())
	local request=job.Payload
	task.spawn(function()
		local path
		local started=os.clock()
		if diagnostics then diagnostics.PathRequests+=1;diagnostics.PeakComputing=math.max(diagnostics.PeakComputing,jobs.Active)end
		local ok,points=pcall(function()
			path=PathfindingService:CreatePath({AgentRadius=2,AgentHeight=HEIGHT,AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=4,Costs={BridgeRail=math.huge}})
			path:ComputeAsync(request.Start,request.Goal)
			return if path.Status==Enum.PathStatus.Success then path:GetWaypoints()else nil
		end)
		local hero,s=request.Hero,request.State
		local valid=not job.Cancelled and states[hero]==s and Graph.RequestMatches(request,identity(hero,s))
			and hero.State~="COMA" and s.SubGoal and (s.PathRouteIndex==s.TowerIndex and (s.SubGoal-request.Goal).Magnitude<=40)
		if valid then
			s.Pending=false;s.PathMilliseconds=(os.clock()-started)*1000
			s.PathStatus=if ok and points then "Success"else "NoPath"
			if ok and points then
				s.Points={}
				local nearest,best=1,math.huge
				for i,wp in points do
					local feet=Navigation.Ground(wp.Position,groupFor(hero),STEP_UP,8)or wp.Position
					table.insert(s.Points,feet)
					local d=(feet-hero.Position).Magnitude
					if d<best then nearest,best=i,d end
				end
				s.Index=nearest;s.Failures=0;s.EscapeRemaining=nil
				if best<2.5 and s.Points[nearest+1]and clearRoute(hero.Position,s.Points[nearest+1],groupFor(hero))then s.Index+=1 end
				if diagnostics then diagnostics.PathSuccess+=1 end
			else
				s.Failures=(s.Failures or 0)+1
				s.NextRequest=os.clock()+math.min(2,.35*2^math.min(s.Failures,3))
				if diagnostics then diagnostics.PathFailure+=1 end
			end
		else
			if states[hero]==s and s.Revision==request.Revision then s.Pending=false end
			if diagnostics then diagnostics.StalePaths+=1 end
		end
		if path then path:Destroy()end
		done()
	end)
end)
local function resetPath(hero: any,s: any)
	jobs:Cancel(hero);s.Pending=false;s.Points=nil;s.PathGoal=nil;s.EscapeRemaining=nil;s.Revision+=1
end
function Navigation.Clear(hero: any)
	jobs:Cancel(hero);states[hero]=nil;hero.NavigationRejectedTargets=nil
end
function Navigation.Pause(hero: any)
	local s=states[hero]
	if s then
		resetPath(hero,s);Recovery.Pause(s.Monitor);s.LastStep=nil
		s.RampLinkId=nil;s.RampDirection=nil;s.RampDirChangeTime=nil
	end
end
function Navigation.Displace(hero: any,destination: Vector3)
	hero.Position=walkSegment(hero.Position,destination,flatDistance(hero.Position,destination),groupFor(hero),nil,nil)
	Navigation.Clear(hero)
end
local function requestPath(hero: any,s: any,goal: Vector3,now: number)
	if s.Pending or now<s.NextRequest then return end
	local request=identity(hero,s)
	request.Hero=hero;request.State=s;request.Start=hero.Position;request.Goal=goal
	s.Pending=true;s.PathGoal=goal;s.PathRouteIndex=s.TowerIndex;s.RequestedAt=now;s.NextRequest=now+.35
	if not jobs:Push(hero,request)then s.Pending=false;s.PathGoal=nil;s.NextRequest=now+.2 end
end
local function graphFor(floor: number): (any,Vector3)
	local index=(floor-1)%5+1
	if not graphs[index]then graphs[index]=Graph.new(Layout.Get(index))end
	return graphs[index],Vector3.new(12000+((floor-1)%10)*2400,1000,12000+math.floor((floor-1)/10)*2400)
end
local function localPoint(p: Vector3,origin: Vector3): any
	local v=p-origin;return {X=v.X,Y=v.Y,Z=v.Z}
end
local function remaining(s: any,position: Vector3): number
	local route,index=s.TowerRoute,s.TowerIndex
	local distance=0
	if s.Points and s.Points[s.Index]then
		for i=s.Index,#s.Points do distance+=(position-s.Points[i]).Magnitude;position=s.Points[i]end
		index+=1
	end
	for i=index,#route do distance+=(position-route[i]).Magnitude;position=route[i]end
	return distance
end
local function advance(points: {Vector3},index: number,position: Vector3,group: string?,origin: Vector3?,corridor: any,startPoint: Vector3?): number
	while points[index] do
		local wp=points[index]
		local nxt=points[index+1]
		if (wp-position).Magnitude<.35 or (flatDistance(wp,position)<.45 and math.abs(wp.Y-position.Y)<=STEP_UP) then
			index+=1
		elseif nxt and math.abs(wp.Y-position.Y)<=1.8 and flatDistance(wp,position)<=4.5 then
			local prev=points[index-1] or startPoint
			local inOk=true
			if prev then
				local inSeg=Vector3.new(wp.X-prev.X,0,wp.Z-prev.Z)
				local relIn=Vector3.new(position.X-wp.X,0,position.Z-wp.Z)
				inOk=inSeg.Magnitude<=.05 or inSeg:Dot(relIn)>=0
			end
			local seg=Vector3.new(nxt.X-wp.X,0,nxt.Z-wp.Z)
			local rel=Vector3.new(position.X-wp.X,0,position.Z-wp.Z)
			local step=math.min(4.5,flatDistance(position,nxt))
			local _,ok=walkSegment(position,nxt,step,group or "Default",origin,corridor)
			if inOk and seg.Magnitude>.01 and rel:Dot(seg.Unit)>=0 and ok then
				index+=1
			else
				break
			end
		else
			break
		end
	end
	return index
end
local function avoid(hero: any,s: any,old: Vector3,nextPosition: Vector3,group: string): Vector3
	local movement=nextPosition-old
	if movement.Magnitude<.01 then return nextPosition end
	for other,otherState in states do
		if other==hero or other.FloorId~=hero.FloorId or other.RoomGeneration~=hero.RoomGeneration
			or other.State=="COMA" or not other.Position or math.abs(other.Position.Y-old.Y)>3 then continue end
		local offset=Vector3.new(other.Position.X-old.X,0,other.Position.Z-old.Z)
		local flat=Vector3.new(movement.X,0,movement.Z)
		if flat.Magnitude<.01 or offset:Dot(flat)<=0 or offset.Magnitude>flat.Magnitude+1.8 then continue end
		local t=math.clamp(offset:Dot(flat)/flat:Dot(flat),0,1)
		if (offset-flat*t).Magnitude>=1.8 then continue end
		local right=Vector3.new(-flat.Unit.Z,0,flat.Unit.X)
		local minSep=if s.BlockReason or (otherState and (otherState.ConsumedDistance or 1)<.05) then 1.35 else 1.65
		for _,ang in {{.6,.8},{.25,.97},{0,1},{-.35,.94}}do
			for _,side in {s.SteerSide or 1,-(s.SteerSide or 1)}do
				local dir=(flat.Unit*ang[1]+right*(side*ang[2])).Unit
				local trial,safe=walkSegment(old,old+dir*flat.Magnitude,flat.Magnitude,group,s.Origin,s.Corridor)
				if safe and flatDistance(trial,old)>.01 and (flatDistance(trial,other.Position)>=minSep or flatDistance(trial,other.Position)>offset.Magnitude+.02)then
					return trial
				end
			end
		end
		if (hero.NetId or 0)<(other.NetId or 0) or (otherState and (otherState.ConsumedDistance or 1)<.05) then
			local room=math.max(0,offset.Magnitude-1.2)
			if room>.05 then
				return walkSegment(old,old+flat.Unit*math.min(room,flat.Magnitude),math.min(room,flat.Magnitude),group,s.Origin,s.Corridor)
			end
			return nextPosition
		end
		s.BlockReason="YIELD";return old
	end
	return nextPosition
end
function Navigation.Step(hero: any,goal: Vector3,distance: number,now: number,deltaTime: number?): any
	local s=states[hero]
	if not s then s={Revision=0,NextRequest=0,TowerIndex=1,Index=1,Monitor={}};states[hero]=s end
	local group=groupFor(hero)
	local dt=math.clamp(deltaTime or (s.LastStep and now-s.LastStep)or .1,.001,.3)
	s.LastStep=now
	if hero.JumpStart and hero.GroundBaseY then hero.Position=Vector3.new(hero.Position.X,hero.GroundBaseY,hero.Position.Z)end
	local from=hero.Position
	local scope=tostring(hero.FloorId)..":"..tostring(hero.RoomGeneration)..":"..tostring(hero.EntityGeneration)..":"..intent(hero)
	local g,origin,location,goalLocation
	if hero.FloorId and hero.FloorId>0 and hero.FloorId<=50 then -- tower floors only; the raid arena is open ground
		g,origin=graphFor(hero.FloorId)
		location=Graph.Locate(g,localPoint(from,origin));goalLocation=Graph.Locate(g,localPoint(goal,origin))
	end
	local key=scope..":"..(location and location.Key or "WORLD")..">"..(goalLocation and goalLocation.Key or "WORLD")
	local currentLink = nil
	if location and location.Link and g then
		for _, link in g.Links do
			if link.Id == location.Link then
				currentLink = link
				break
			end
		end
	end

	local isMidRamp = currentLink ~= nil and TowerTraversal.IsDiagonalRamp(currentLink) and TowerTraversal.IsMidRamp(location and location.T)
	local isOverride = hero.FocusOverride == true or hero.RecallOverride == true or hero.IsFocusTarget == true
	local shouldCommit = false

	if isOverride or not isMidRamp then
		s.RampLinkId = nil
		s.RampDirection = nil
		s.RampDirChangeTime = nil
		hero.FocusOverride = nil
		hero.RecallOverride = nil
	else
		local fromLocal = localPoint(from, origin)
		local candRoute = if g then Graph.Route(g, fromLocal, localPoint(goal, origin)) else {{X=goal.X, Y=goal.Y, Z=goal.Z}}
		local lx, ly, lz = currentLink.BX - currentLink.AX, currentLink.BY - currentLink.AY, currentLink.BZ - currentLink.AZ
		local reqDir = 0
		for _, p in candRoute do
			local dot = (p.X - fromLocal.X) * lx + (p.Y - fromLocal.Y) * ly + (p.Z - fromLocal.Z) * lz
			if math.abs(dot) > 0.05 then
				reqDir = if dot > 0 then 1 else -1
				break
			end
		end
		if reqDir == 0 then
			reqDir = s.RampDirection or 1
		end

		local isReversal = (s.RampLinkId == currentLink.Id) and (s.RampDirection ~= nil) and (reqDir == -s.RampDirection)
		if isReversal and TowerTraversal.ShouldCommitDirection(s.RampDirChangeTime, now) then
			shouldCommit = true
		else
			if s.RampLinkId ~= currentLink.Id or s.RampDirection ~= reqDir then
				s.RampLinkId = currentLink.Id
				s.RampDirection = reqDir
				s.RampDirChangeTime = now
			end
		end
	end

	if not shouldCommit and s.RouteKey ~= key then
		resetPath(hero, s); s.RouteKey = key; s.TowerRoute = {}; s.TowerIndex = 1; s.TowerStart = from
		local route = if g then Graph.Route(g, localPoint(from, origin), localPoint(goal, origin)) else {{X=goal.X, Y=goal.Y, Z=goal.Z}}
		for _, p in route do
			local v = Vector3.new(p.X, p.Y, p.Z) + (origin or Vector3.zero)
			v = Navigation.Ground(v, group, STEP_UP, MAX_DROP) or v
			if #s.TowerRoute == 0 or (s.TowerRoute[#s.TowerRoute] - v).Magnitude > 0.01 then table.insert(s.TowerRoute, v) end
		end
		if #s.TowerRoute == 0 then s.TowerRoute = {goal} end
	elseif shouldCommit and currentLink then
		local endLocal = if s.RampDirection == 1
			then {X=currentLink.BX, Y=currentLink.BY, Z=currentLink.BZ}
			else {X=currentLink.AX, Y=currentLink.AY, Z=currentLink.AZ}
		local endWorld = Vector3.new(endLocal.X, endLocal.Y, endLocal.Z) + (origin or Vector3.zero)
		endWorld = Navigation.Ground(endWorld, group, STEP_UP, MAX_DROP) or endWorld
		s.TowerRoute = { endWorld }
		local tailRoute = if g then Graph.Route(g, endLocal, localPoint(goal, origin)) else {{X=goal.X, Y=goal.Y, Z=goal.Z}}
		for _, p in tailRoute do
			local v = Vector3.new(p.X, p.Y, p.Z) + (origin or Vector3.zero)
			v = Navigation.Ground(v, group, STEP_UP, MAX_DROP) or v
			if (s.TowerRoute[#s.TowerRoute] - v).Magnitude > 0.01 then table.insert(s.TowerRoute, v) end
		end
		s.TowerIndex = 1
		s.TowerStart = from
	end
	s.TowerRoute[#s.TowerRoute]=goal;s.TowerGoal=goal;s.Origin=origin
	s.TowerIndex=math.min(s.TowerIndex,#s.TowerRoute)
	s.Corridor=nil
	if location and location.Link then for _,link in g.Links do if link.Id==location.Link then s.Corridor=link;break end end end
	s.Destination=goal;s.RequestedDistance=distance;s.BlockReason=nil
	if diagnostics then diagnostics.Steps+=1 end
	-- Deep descent is for externally airborne actors, never a walking shortcut.
	if not Navigation.Ground(from,group,.2,MAX_DROP)then
		local below=Navigation.Ground(from,group,.2,50)
		if below then
			hero.Position=Vector3.new(from.X,math.max(below.Y,from.Y-45*dt),from.Z)
			hero.GroundBaseY=hero.Position.Y;s.Status="FALLING"
			return {Status="FALLING",Remaining=(goal-hero.Position).Magnitude}
		end
	end
	s.TowerIndex=advance(s.TowerRoute,s.TowerIndex,hero.Position,group,origin,s.Corridor,s.TowerStart)
	s.SubGoal=s.TowerRoute[s.TowerIndex]or goal
	if s.PathGoal and (s.PathRouteIndex~=s.TowerIndex or (s.PathGoal-s.SubGoal).Magnitude>(if s.Pending then 36 else 16))then resetPath(hero,s)end
	local before=remaining(s,hero.Position)
	local budget=math.max(0,distance)
	for _=1,64 do
		if budget<.01 then break end
		s.TowerIndex=advance(s.TowerRoute,s.TowerIndex,hero.Position,group,origin,s.Corridor,s.TowerStart)
		local subGoal=s.TowerRoute[s.TowerIndex]
		if not subGoal then break end
		s.SubGoal=subGoal
		if s.PathGoal and (s.PathRouteIndex~=s.TowerIndex or (s.PathGoal-subGoal).Magnitude>(if s.Pending then 36 else 16))then resetPath(hero,s)end
		local destination=subGoal
		if s.Points then
			s.Index=advance(s.Points,s.Index,hero.Position,group,origin,s.Corridor,s.TowerStart)
			destination=s.Points[s.Index]or subGoal
			if not s.Points[s.Index]then s.Points=nil end
		end
		local old=hero.Position
		if s.EscapeRemaining and s.EscapeRemaining>.05 then destination=old+s.EscapeDirection*math.min(1.5,s.EscapeRemaining) else s.EscapeRemaining=nil end
		if s.Points and s.Points[s.Index] and flatDistance(old,destination)<.45 then s.Index+=1;continue end
		local step=math.min(1.5,budget,flatDistance(old,destination))
		if step<.01 then s.BlockReason="HEIGHT";break end
		local nextPosition,clear,reason=walkSegment(old,destination,step,group,origin,s.Corridor)
		if not clear then
			s.BlockReason=reason;requestPath(hero,s,subGoal,now)
			local dir=Vector3.new(destination.X-nextPosition.X,0,destination.Z-nextPosition.Z)
			if dir.Magnitude>.01 then
				local right=Vector3.new(-dir.Unit.Z,0,dir.Unit.X)
				local left=math.max(0,step-flatDistance(old,nextPosition))
				-- Keep a side around convex scenery instead of alternating at its tip.
				-- Lateral escape also lets an actor descend a low mound beside a spike.
				local escaped=false
				for _,angle in {{.707,.707},{.5,.866},{0,1},{-.5,.866},{-.866,.5}}do
					for _,side in {s.SteerSide or 1,-(s.SteerSide or 1)}do
						local steer=dir.Unit*angle[1]+right*(side*angle[2])
						local trial,safe=walkSegment(nextPosition,nextPosition+steer*left,left,group,origin,s.Corridor)
						if safe and flatDistance(trial,nextPosition)>.01 then
							nextPosition=trial;s.SteerSide=side;escaped=true
							-- Finish a short retreat before facing the obstacle again.
							if angle[1]<0 then s.EscapeDirection=steer;s.EscapeRemaining=4.5 end
							break
						end
					end
					if escaped then break end
				end
			end
		end
		nextPosition=avoid(hero,s,old,nextPosition,group)
		local spent=flatDistance(old,nextPosition)
		if s.EscapeRemaining then s.EscapeRemaining=if clear and spent>=.05 then math.max(0,s.EscapeRemaining-spent) else nil end
		hero.Position=nextPosition;budget-=spent
		if spent<.01 then break end
	end
	hero.GroundBaseY=hero.Position.Y
	local moved=hero.Position-from
	s.ConsumedDistance=moved.Magnitude
	if moved.Magnitude>.02 then hero.Yaw=math.atan2(-moved.X,-moved.Z)end
	local after=remaining(s,hero.Position)
	s.Status=Recovery.Update(s.Monitor,scope,now,before-after,after)
	s.NoProgressSeconds=now-(s.Monitor.ProgressAt or now)
	if s.Status=="REPATH"then resetPath(hero,s);s.RouteKey=nil;s.NextRequest=now end
	return {Status=s.Status,Remaining=after,NoProgressSeconds=s.NoProgressSeconds,Reason=s.BlockReason}
end
if diagnostics then
	function Navigation.DebugSnapshot(hero: any?): any
		local result=table.clone(diagnostics);result.Computing=jobs.Active;result.Queued=jobs.Waiting
		local s=hero and states[hero]
		if s then
			local actor={}
			for _,key in {"TowerIndex","Index","Pending","NextRequest","RequestedAt","PathMilliseconds","PathStatus","RequestedDistance","ConsumedDistance","Destination","SubGoal","TowerGoal","Revision","RouteKey","Status","NoProgressSeconds","BlockReason"}do
				local value=s[key]
				actor[key]=if typeof(value)=="Vector3"then {X=value.X,Y=value.Y,Z=value.Z}else value
			end
			actor.TowerPoints=#s.TowerRoute;actor.PathPoints=s.Points and #s.Points or 0
			result.Actor=actor
		end
		return result
	end
	function Navigation.DebugTracking(netId: number): any
		for hero,s in states do
			if hero.NetId==netId then return {LastClock=s.Monitor.ProgressAt,Status=s.Status,NoProgressSeconds=s.NoProgressSeconds}end
		end
		return nil
	end
end
function Navigation.CanAttack(from: Vector3,target: Vector3,group: string?): boolean
	if math.abs(from.Y-target.Y)>11 then return false end
	local a,b=from+Vector3.new(0,2.5,0),target+Vector3.new(0,2.5,0)
	return Workspace:Raycast(a,b-a,parameters(group))==nil
end
return Navigation
