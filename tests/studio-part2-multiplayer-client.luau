-- Temporary multiplayer probe. Never installed in production source mappings.
local RS=game:GetService("ReplicatedStorage")
local p=game.Players.LocalPlayer
local control=RS:WaitForChild("TowerPart2TestControl",20)
if not control then return end
local R=RS.Remotes:WaitForChild("TowerRemotes")
local state=nil
local responses={}
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds;repeat if fn() then return end;task.wait(.05) until os.clock()>deadline;error("Timeout")
end
R.Presence.OnClientEvent:Connect(function(s) state=s end)
R.Response.OnClientEvent:Connect(function(r) responses[r.RequestId]=r end)
task.wait(1.2)
R.Request:FireServer({ContractVersion=1,RequestId=game.HttpService:GenerateGUID(false),Action="PRESENCE_SUBSCRIBE"})
control.OnClientEvent:Connect(function(sequence,action,floorId)
	local ok,result=pcall(function()
		if action=="MEASURE" then
			task.wait(.4)
			local ids,positions={},{}
			for id,m in _G.ClientCombatState.Metadata do table.insert(ids,id) end;table.sort(ids)
			for id,node in _G.ClientCombatState.VisualNodes do positions[tostring(id)]={X=node.CurrentPos.X,Y=node.CurrentPos.Y,Z=node.CurrentPos.Z} end
			return {FloorId=_G.TowerView.FloorId,ViewEpoch=_G.TowerView.ViewEpoch,Ids=ids,Positions=positions,Presence=state}
		elseif action=="LEAVE" then game:GetService("StudioTestService"):LeaveTest();return {Left=true}
		else
			waitFor(function() return state and _G.TowerView end,10)
			local own=state.Self
			local r={ContractVersion=1,RequestId=game.HttpService:GenerateGUID(false),Action=action,FloorId=floorId,CharacterGeneration=own.CharacterGeneration,ExpectedLocationRevision=own.LocationRevision,ExpectedSquadRevision=own.SquadRevision}
			R.Request:FireServer(r)
			waitFor(function() local response=responses[r.RequestId];return response and response.Status~="PENDING" end,10)
			return responses[r.RequestId]
		end
	end)
	control:FireServer(sequence,{Passed=ok,Result=ok and result or tostring(result)})
end)
control:FireServer("READY",{Passed=true})
