-- Run as a temporary LocalScript in PlayerGui in a disposable Studio Play session.
local RS=game:GetService("ReplicatedStorage")
local p=game.Players.LocalPlayer
local R=RS.Remotes.TowerRemotes
local results={}
local selfState=nil
local responses={}
local connection=R.Presence.OnClientEvent:Connect(function(s) selfState=s.Self end)
local responseConnection=R.Response.OnClientEvent:Connect(function(r) responses[r.RequestId]=r end)
local function check(name,fn)
	local ok,err=pcall(fn);table.insert(results,{Name=name,Passed=ok,Error=not ok and tostring(err) or nil})
	p.PlayerGui:SetAttribute("Part2ClientTests",game.HttpService:JSONEncode(results))
	assert(ok,err)
end
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds
	repeat if fn() then return end;task.wait(.05) until os.clock()>deadline
	error("Timed out")
end
local function request(action,id)
	task.wait(.6)
	assert(selfState,"Presence unavailable")
	local req={ContractVersion=1,RequestId=game.HttpService:GenerateGUID(false),Action=action,FloorId=id,
		CharacterGeneration=selfState.CharacterGeneration,ExpectedLocationRevision=selfState.LocationRevision,ExpectedSquadRevision=selfState.SquadRevision}
	R.Request:FireServer(req)
	waitFor(function() local r=responses[req.RequestId];return r and r.Status~="PENDING" end,10)
	return responses[req.RequestId],req
end
task.wait(1.1)
R.Request:FireServer({ContractVersion=1,RequestId=game.HttpService:GenerateGUID(false),Action="PRESENCE_SUBSCRIBE"})
waitFor(function() return selfState~=nil end,4)
check("Hub to 1 to 5 to 50 uses real Request Ready Context and snapshot remotes",function()
	for _,id in {1,5,50} do
		local result=request("VISIT",id);assert(result.Status=="COMMITTED",result.ErrorCode)
		waitFor(function() return _G.TowerView and _G.TowerView.FloorId==id end,2)
		assert(selfState.PlayerLocation.FloorId==id)
	end
	waitFor(function() local n=0;for _,m in _G.ClientCombatState.Metadata do if m.OwnerUserId==p.UserId then n+=1 end end;return n==2 end,3)
	waitFor(function() local n=0;for _ in _G.ClientCombatState.VisualNodes do n+=1 end;return n==2 end,3)
	local n=0;for _,node in _G.ClientCombatState.VisualNodes do n+=1;assert(node.CurrentPos.X>10000 and node.CurrentPos.Z>10000) end
	assert(n==2,"Expected both heroes rendered on floor 50")
end)
check("Adjacent fixture 49 then 50 and Return to Hub commit correct contexts",function()
	for _,id in {49,50} do assert(request("VISIT",id).Status=="COMMITTED");assert(_G.TowerView.FloorId==id) end
	assert(request("HUB").Status=="COMMITTED");assert(_G.TowerView.FloorId==0)
end)
check("Assignment does not switch owner view and owner travel leaves squad assigned",function()
	local epoch=_G.TowerView.ViewEpoch
	assert(request("ASSIGN",5).Status=="COMMITTED");assert(_G.TowerView.FloorId==0 and _G.TowerView.ViewEpoch==epoch)
	assert(selfState.SquadAssignment==5 and selfState.SquadContext.FloorId==5)
	assert(request("VISIT",50).Status=="COMMITTED");assert(selfState.SquadAssignment==5 and selfState.SquadContext.FloorId==5)
	task.wait(.3)
	for _,m in _G.ClientCombatState.Metadata do assert(m.OwnerUserId~=p.UserId,"Assigned heroes leaked into owner room") end
end)
check("Recall changes squad context once preserves owner view and shares cooldown",function()
	local epoch=_G.TowerView.ViewEpoch
	assert(request("RECALL").Status=="COMMITTED");assert(_G.TowerView.ViewEpoch==epoch and selfState.SquadAssignment==nil and selfState.SquadContext.FloorId==50)
	local result=request("RECALL");assert(result.Status=="REJECTED" and result.ErrorCode=="RECALL_COOLDOWN")
end)
check("Invalid floor and stale revisions reject without changing view",function()
	local epoch=_G.TowerView.ViewEpoch
	local result=request("VISIT",51);assert(result.ErrorCode=="INVALID_FLOOR")
	task.wait(.6)
	R.Request:FireServer({ContractVersion=1,RequestId="PART2_STALE",Action="VISIT",FloorId=1,CharacterGeneration=0,ExpectedLocationRevision=0,ExpectedSquadRevision=0})
	waitFor(function() return responses.PART2_STALE~=nil end,2);assert(responses.PART2_STALE.ErrorCode=="STALE_REVISION")
	assert(_G.TowerView.ViewEpoch==epoch)
end)
check("Hub return clears off-map view and has no stale hero rigs",function()
	assert(request("HUB").Status=="COMMITTED");task.wait(.5)
	for _,node in _G.ClientCombatState.VisualNodes do assert(math.abs(node.CurrentPos.X)<1500 and math.abs(node.CurrentPos.Z)<1500) end
end)
connection:Disconnect();responseConnection:Disconnect()
p.PlayerGui:SetAttribute("Part2ClientDone",true)
script:Destroy()
