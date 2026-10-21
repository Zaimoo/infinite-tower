-- Temporary LocalScript for StudioTestService TOWER_PART3_COMBAT only.
if game.StudioTestService:GetTestArgs()~="TOWER_PART3_COMBAT" then return end
local RS=game.ReplicatedStorage;local p=game.Players.LocalPlayer
local control=RS:WaitForChild("Part3FeedbackControl",30);if not control then return end
local Feedback=require(RS.Assets.CombatFeedback)
local results={}
local function record(name,fn)
	local ok,err=pcall(fn);table.insert(results,{Name=name,Passed=ok,Error=not ok and tostring(err) or nil});assert(ok,err)
end
local function waitFor(fn,seconds)
	local deadline=os.clock()+seconds;repeat if fn() then return end;task.wait(.02) until os.clock()>deadline;error("Timeout")
end
local folder=Instance.new("Folder");folder.Name="Part3FeedbackFixture";folder.Parent=workspace
local feedback=Feedback.new(folder)
local ok,err=pcall(function()
	record("Feedback rejects zero negative malformed and nonfinite amounts",function()
		for _,value in {0,-1,0/0,math.huge,"25"} do assert(feedback:Hit(Vector3.zero,value)==nil) end
		assert(#folder:GetChildren()==0)
	end)
	record("Ordinary Overdrive and incoming labels display exact damage with distinct styles",function()
		local a=feedback:Hit(Vector3.zero,37,false,false).DamageLabel.TextLabel
		local b=feedback:Hit(Vector3.zero,74,true,false).DamageLabel.TextLabel
		local c=feedback:Hit(Vector3.zero,12,false,true).DamageLabel.TextLabel
		assert(a.Text=="-37" and b.Text=="-74" and c.Text=="-12")
		assert(a.TextColor3~=b.TextColor3 and b.TextColor3~=c.TextColor3 and b.TextSize>a.TextSize)
	end)
	record("Damage labels stay capped and expire without leaving hit parts",function()
		for i=1,Feedback.MaxNumbers+12 do feedback:Hit(Vector3.zero,i) end
		assert(#folder:GetChildren()==Feedback.MaxNumbers)
		-- Exercise the shipped cleanup with an explicit expired clock; avoid startup frame scheduling.
		feedback:Step(os.clock()+Feedback.Lifetime+.1)
		assert(#folder:GetChildren()==0 and #feedback.Active==0 and next(feedback.Expires)==nil)
	end)
	record("Context cleanup immediately clears live feedback and permits later hits",function()
		feedback:Hit(Vector3.zero,15);feedback:Clear();assert(#folder:GetChildren()==0)
		assert(feedback:Hit(Vector3.zero,16));feedback:Clear();assert(#folder:GetChildren()==0)
	end)
end)
feedback:Clear();folder:Destroy()
if not ok then control:FireServer("RESULT",{Passed=false,Error=tostring(err),Tests=results});return end
local actual={}
RS.Remotes.CombatRemotes.CombatVFX.OnClientEvent:Connect(function(context,kind,pos,amount,overdrive,incoming)
	if kind~="HIT_SPARK" or not _G.TowerView or context.FloorId~=_G.TowerView.FloorId or context.ViewEpoch~=_G.TowerView.ViewEpoch then return end
	for _,part in workspace.ClientVisualEntities:GetChildren() do
		if part.Name=="DamageNumber" and part:GetAttribute("Damage")==amount then
			local label=part:FindFirstChild("DamageLabel")
			if label and label.TextLabel.Text=="-"..tostring(math.max(1,math.round(amount))) then
				table.insert(actual,{Amount=amount,Overdrive=overdrive,Incoming=incoming,Floor=context.FloorId,Text=label.TextLabel.Text})
				break
			end
		end
	end
end)
control.OnClientEvent:Connect(function(command)
	if command~="MEASURE" then return end
	local passed,errorMessage=pcall(function()
		record("Actual same-floor attacks create matching server damage labels",function() waitFor(function() return #actual>0 end,18) end)
		RS.Remotes.CombatRemotes.WhistleCommand:FireServer(1)
		record("Actual Overdrive attacks produce gold damage labels",function()
			waitFor(function() for _,hit in actual do if hit.Overdrive then return true end end;return false end,7)
		end)
	end)
	control:FireServer("RESULT",{Passed=passed,Error=not passed and tostring(errorMessage) or nil,Tests=results,Actual=actual})
end)
control:FireServer("READY",true)
