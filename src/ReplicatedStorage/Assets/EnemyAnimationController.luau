--!strict
local Rigs=require(script.Parent.TowerEnemyRigs)
local Clips=require(script.Parent.TowerEnemyClips)
local Config=require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat)
local Controller={}
local effects={}
local MAX_EFFECTS=12
local function clearEffect(key)
	local effect=effects[key];if effect then effect.Model:Destroy();effects[key]=nil end
end
local function groundPart(parent,size,cf,color,alpha)
	local p=Instance.new("Part");p.Size=size;p.CFrame=cf;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
	p.Material=Enum.Material.Neon;p.Color=color;p.Transparency=alpha;p.CastShadow=false;p.Parent=parent;return p
end
function Controller.Clear()
	for key in pairs(effects) do clearEffect(key) end
end
function Controller.Attach(model,root,enemyId)
	local clips=assert(Clips[enemyId],"Missing enemy clips: "..enemyId)
	for _,slot in Config.Get(enemyId).RequiredSlots do assert(clips[slot],"Missing enemy clip "..enemyId.."/"..slot) end
	return Rigs.Build(model,root,enemyId)
end
function Controller.Action(node,action,origin,now)
	if not node.EnemyRig or node.DeathAt then return end
	node.EnemyAction=action
	local due=action.StartServerTime+action.ImpactOffsetSeconds
	local key=tostring(node.NetId)..":"..action.ActionSequence
	node.EnemyEffectKey=key
	if now>=due then return end -- late observers seek pose without a fresh warning or impact burst
	local n=0;for _ in pairs(effects) do n+=1 end;if n>=MAX_EFFECTS then return end
	local model=Instance.new("Model");model.Name="EnemyWarning_"..key
	local point=origin+(action.Shape=="ARC" and action.Origin or action.Aim)+Vector3.new(0,.13,0)
	local color=Color3.fromRGB(240,136,56)
	if action.Shape=="ARC" then
		local cf=CFrame.new(point)*CFrame.Angles(0,action.Yaw,0)
		for i=0,10 do
			local a=-math.pi*.47+i*math.pi*.94/10
			local pos=Vector3.new(math.sin(a)*action.Range,0,-math.cos(a)*action.Range)
			groundPart(model,Vector3.new(action.Range*.27,.09,.24),cf*CFrame.new(pos)*CFrame.Angles(0,-a,0),color,.12)
		end
		for _,side in {-1,1} do
			groundPart(model,Vector3.new(.18,.09,action.Range),cf*CFrame.Angles(0,side*math.pi*.47,0)*CFrame.new(0,0,-action.Range/2),color,.3)
		end
	else
		local radius=action.Radius
		local disc=groundPart(model,Vector3.new(.07,radius*2,radius*2),CFrame.new(point)*CFrame.Angles(0,0,math.pi/2),color,.86)
		disc.Shape=Enum.PartType.Cylinder
		for i=0,11 do
			local a=i*math.pi/6
			groundPart(model,Vector3.new(radius*.51,.1,.22),CFrame.new(point+Vector3.new(math.sin(a)*radius,0,math.cos(a)*radius))*CFrame.Angles(0,a,0),color,.14)
		end
	end
	model.Parent=workspace.ClientVisualEntities
	effects[key]={Model=model,EndAt=due,Started=now,Due=due}
end
function Controller.Cancel(node)
	if node.EnemyEffectKey then clearEffect(node.EnemyEffectKey) end
	node.EnemyAction=nil
end
function Controller.Contact(node,action,origin,now)
	local key=tostring(node.NetId)..":"..action.ActionSequence
	clearEffect(key)
	if now-(action.StartServerTime+action.ImpactOffsetSeconds)>.4 then return end
	local p=groundPart(workspace.ClientVisualEntities,Vector3.new(.2,2,2),CFrame.new(origin+action.Aim+Vector3.new(0,.2,0))*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(174,239,109),.25)
	p.Shape=Enum.PartType.Cylinder
	game:GetService("TweenService"):Create(p,TweenInfo.new(.3),{Size=Vector3.new(.1,math.max(4,action.Radius*2),math.max(4,action.Radius*2)),Transparency=1}):Play()
	game:GetService("Debris"):AddItem(p,.35)
end
function Controller.Hit(node,now)
	if node and node.EnemyRig and not node.DeathAt then node.HitAt=now end
end
function Controller.Death(node,at)
	Controller.Cancel(node);node.DeathAt=at;node.DeathEnd=at+1.6
	if node.RootPart then local bb=node.RootPart:FindFirstChild("UnitBillboard");if bb then bb.Enabled=false end end
	for _,p in node.EnemyRig.Parts do p.CanQuery=false end
end
function Controller.Step(node,dt,now)
	local rig=node.EnemyRig;if not rig then return end
	local clips=Clips[rig.EnemyId];local frames=clips.Idle;local phase=(now%3)/3
	local moving=(node.GoalPos-node.CurrentPos).Magnitude>.15
	local distance=(node.CurrentPos-(rig.LastPos or node.CurrentPos)).Magnitude;rig.LastPos=node.CurrentPos
	rig.Distance+=math.min(distance,4)
	if node.DeathAt then frames=clips.Death;phase=(now-node.DeathAt)/1.6
	elseif node.EnemyAction then
		local a=node.EnemyAction;local elapsed=now-a.StartServerTime
		if elapsed<a.ImpactOffsetSeconds+a.RecoverySeconds then
			frames=clips[a.AnimationKey];phase=elapsed<a.ImpactOffsetSeconds and .8*elapsed/a.ImpactOffsetSeconds or .8+.2*(elapsed-a.ImpactOffsetSeconds)/a.RecoverySeconds
		else Controller.Cancel(node) end
	elseif node.BornAt and clips.Awakening and now-node.BornAt<2.2 then frames=clips.Awakening;phase=(now-node.BornAt)/2.2
	elseif moving then frames=clips.Locomotion;phase=(rig.Distance/(rig.Spec.Role=="BOSS" and 9.6 or rig.Spec.Role=="REGULAR" and 3.6 or 4.8))%1
	elseif node.HitAt and now-node.HitAt<.28 then frames=clips.HitReaction;phase=(now-node.HitAt)/.28 end
	local poses=Clips.Sample(frames,phase)
	for name,joint in pairs(rig.Joints) do joint.Motor.C0=joint.Bind*(poses[name] or CFrame.identity) end
	if node.HitAt and now-node.HitAt<.15 then
		if node.Highlight then node.Highlight.FillColor=Color3.fromRGB(235,255,190);node.Highlight.FillTransparency=.45 end
	elseif node.Highlight then node.Highlight.FillTransparency=1 end
	if node.DeathAt then
		local alpha=math.clamp((now-node.DeathAt-1.1)/.5,0,1)
		for _,p in rig.Parts do p.Transparency=alpha end
	end
end
function Controller.StepEffects(now)
	for key,effect in pairs(effects) do
		if now>=effect.EndAt then clearEffect(key) end
	end
end
return Controller
