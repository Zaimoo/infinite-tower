--!strict
-- Pure authority: no timers, remotes, markers, or client-owned damage.
local A={}
function A.Same(a: any,b: any): boolean
	return a~=nil and b~=nil and a.FloorId==b.FloorId and a.RoomGeneration==b.RoomGeneration
end
function A.Identity(e: any): any
	return {NetId=e.NetId,EntityGeneration=e.EntityGeneration,FloorId=e.FloorId,RoomGeneration=e.RoomGeneration}
end
function A.Matches(e: any,id: any): boolean
	return A.Same(e,id) and e.NetId==id.NetId and e.EntityGeneration==id.EntityGeneration
end
function A.Alive(e: any): boolean
	return e~=nil and e.CurrentHP>0 and e.IsAlive~=false and e.State~="COMA"
end
local function distance(a,b)
	local x,z=a.X-b.X,a.Z-b.Z;return math.sqrt(x*x+z*z)
end
local function segmentDistance(p,a,b)
	local vx,vz=b.X-a.X,b.Z-a.Z
	local wx,wz=p.X-a.X,p.Z-a.Z
	local len2=vx*vx+vz*vz
	if len2<.0001 then return distance(p,a) end
	local t=math.clamp((wx*vx+wz*vz)/len2,0,1)
	local dx,dz=p.X-(a.X+t*vx),p.Z-(a.Z+t*vz)
	return math.sqrt(dx*dx+dz*dz)
end
function A.Start(actor: any,target: any,definition: any,now: number): any
	assert(A.Alive(actor) and A.Alive(target) and A.Same(actor,target))
	actor.ActionCounter=(actor.ActionCounter or 0)+1
	assert(actor.ActionCounter<4294967296,"Action identity exhausted")
	local aim=definition.Shape=="SELF_DISC" and actor.Position or target.Position
	return {Actor=A.Identity(actor),Target=A.Identity(target),ActionSequence=actor.ActionCounter,
		EnemyId=actor.EnemyId,AttackId=definition.Id,AnimationKey=definition.AnimationKey,
		StartServerTime=now,WindupSeconds=definition.WindupSeconds,TravelSeconds=definition.TravelSeconds or 0,
		ImpactOffsetSeconds=definition.ImpactOffsetSeconds,RecoverySeconds=definition.RecoverySeconds,
		Origin=actor.Position,Aim=aim,Yaw=actor.Yaw,Shape=definition.Shape,Range=definition.Range,
		Radius=definition.Radius,Status="WINDUP",Impacted=false,Hits={}}
end
function A.Cancel(action: any,reason: string): boolean
	if action.Status=="CANCELED" or action.Status=="COMPLETE" then return false end
	action.Status="CANCELED";action.CancelReason=reason;return true
end
function A.Contains(action: any,actor: any,target: any,definition: any): boolean
	if not A.Alive(target) or not A.Same(actor,target) or not A.Matches(actor,action.Actor) then return false end
	if math.abs(actor.Position.Y-target.Position.Y)>8 then return false end
	if definition.Shape=="ARC" then
		local d=distance(action.Origin,target.Position)
		if d>definition.Range then return false end
		if d<.01 then return true end
		local dot=((target.Position.X-action.Origin.X)*-math.sin(action.Yaw)+(target.Position.Z-action.Origin.Z)*-math.cos(action.Yaw))/d
		return dot>=definition.HalfArcCos
	elseif definition.Shape=="PROJECTILE" then
		return segmentDistance(target.Position,action.Origin,action.Aim)<=definition.Radius
	end
	return distance(action.Aim,target.Position)<=definition.Radius
end
-- Calls can be repeated or skipped. An action never applies an impact twice.
-- Long stalls cancel rather than delivering an untelegraphed catch-up hit.
function A.Step(action: any,actor: any,target: any,definition: any,now: number,safe: any,candidates: any,hit: any): string?
	if action.Status=="CANCELED" or action.Status=="COMPLETE" then return nil end
	if not A.Alive(actor) or not A.Matches(actor,action.Actor) or not A.Alive(target)
		or not A.Matches(target,action.Target) or not A.Same(actor,target) or safe(actor) or safe(target) then
		A.Cancel(action,"INVALID_IDENTITY_OR_SAFETY");return "CANCEL"
	end
	local elapsed=now-action.StartServerTime
	if not action.Impacted and elapsed>=definition.ImpactOffsetSeconds then
		if elapsed-definition.ImpactOffsetSeconds>definition.MaxLatenessSeconds then A.Cancel(action,"MISSED_IMPACT_DEADLINE");return "CANCEL" end
		action.Impacted=true;action.Status="RECOVERY"
		for _,victim in candidates do
			local key=tostring(victim.NetId)..":"..tostring(victim.EntityGeneration)
			if not action.Hits[key] and not safe(victim) and A.Contains(action,actor,victim,definition) then
				action.Hits[key]=true;hit(victim,definition.DamageMultiplier,action)
			end
		end
		return "IMPACT"
	end
	if elapsed>=definition.ImpactOffsetSeconds+definition.RecoverySeconds then action.Status="COMPLETE";return "COMPLETE" end
	return nil
end
return table.freeze(A)
