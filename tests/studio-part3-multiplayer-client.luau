-- Temporary test fixture; install only for StudioTestService TOWER_PART3_MULTI.
local RS=game.ReplicatedStorage;local p=game.Players.LocalPlayer
local control=RS:WaitForChild("TowerPart3TestControl",30);if not control then return end
local R=RS.Remotes:WaitForChild("TowerRemotes");local presence;local responses={};local events={};local frames={}
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds;repeat if fn() then return end;task.wait(.04) until os.clock()>deadline;error("Timeout")
end
R.Presence.OnClientEvent:Connect(function(s) presence=s end)
R.Response.OnClientEvent:Connect(function(r) responses[r.RequestId]=r end)
R.TowerAction.OnClientEvent:Connect(function(context,m)
	if not _G.TowerView or context.ViewEpoch~=_G.TowerView.ViewEpoch or context.FloorId~=_G.TowerView.FloorId then return end
	if m.Kind=="START" or m.Kind=="IMPACT" or m.Kind=="CANCEL" or m.Kind=="DEATH" then
		table.insert(events,{Kind=m.Kind,Id=m.Actor.NetId,Generation=m.Actor.EntityGeneration,Sequence=m.ActionSequence,
			Start=m.StartServerTime,ImpactOffset=m.ImpactOffsetSeconds,Received=workspace:GetServerTimeNow(),Attack=m.AttackId,Floor=context.FloorId})
	end
end)
local dtSamples={};local animSamples={}
game:GetService("RunService").RenderStepped:Connect(function(dt)
	if #dtSamples<1200 then table.insert(dtSamples,dt*1000) end
	local state=_G.ClientCombatState
	if state then for id,node in state.VisualNodes do if node.EnemyRig and node.EnemyAction then
		local a=node.EnemyAction;local key=id..":"..a.ActionSequence
		local t=workspace:GetServerTimeNow()-a.StartServerTime
		if not animSamples[key] and math.abs(t-a.ImpactOffsetSeconds)<.05 then
			local body=node.EnemyRig.Joints.Body
			animSamples[key]={Id=id,Attack=a.AttackId,Offset=t,Expected=a.ImpactOffsetSeconds,Pose={body.Motor.C0:GetComponents()}}
		end
	end end end
end)
task.wait(1.2);R.Request:FireServer({ContractVersion=1,RequestId=game.HttpService:GenerateGUID(false),Action="PRESENCE_SUBSCRIBE"})
control.OnClientEvent:Connect(function(sequence,action,id)
	local ok,result=pcall(function()
		if action=="MEASURE" then
			task.wait(.3);local rigs={};local ids={};local dying=0
			for netId,node in _G.ClientCombatState.VisualNodes do
				table.insert(ids,netId)
				if node.EnemyRig then local joints=0;for _ in node.EnemyRig.Joints do joints+=1 end
					table.insert(rigs,{Id=netId,Enemy=node.EnemyRig.EnemyId,Parts=#node.EnemyRig.Parts,Joints=joints}) end
			end;table.sort(ids)
			local active={};for key,a in _G.ClientCombatState.EnemyActions.Actors do table.insert(active,{Key=key,Sequence=a.Sequence,Terminal=a.Terminal,Start=a.Action and a.Action.StartServerTime}) end
			local sorted=table.clone(dtSamples);table.sort(sorted)
			return {Floor=_G.TowerView.FloorId,Ids=ids,Rigs=rigs,Events=events,MotionSamples=animSamples,Metrics=_G.ClientCombatState.ActionMetrics,
				Active=active,
				Viewport=tostring(workspace.CurrentCamera.ViewportSize),Frames=#sorted,P50=sorted[math.max(1,math.ceil(#sorted*.5))],P95=sorted[math.max(1,math.ceil(#sorted*.95))]}
		elseif action=="CLEAR" then table.clear(events);table.clear(dtSamples);table.clear(animSamples);return true
		elseif action=="LEAVE" then game:GetService("StudioTestService"):LeaveTest();return true
		else
			task.wait(.6);waitFor(function() return presence~=nil end,4);local s=presence.Self;local requestId=game.HttpService:GenerateGUID(false)
			R.Request:FireServer({ContractVersion=1,RequestId=requestId,Action=action,FloorId=id,CharacterGeneration=s.CharacterGeneration,ExpectedLocationRevision=s.LocationRevision,ExpectedSquadRevision=s.SquadRevision})
			waitFor(function() return responses[requestId] and responses[requestId].Status~="PENDING" end,12)
			return responses[requestId]
		end
	end)
	control:FireServer(sequence,{Passed=ok,Result=ok and result or tostring(result)})
end)
waitFor(function() return presence~=nil end,10);control:FireServer("READY",true)
