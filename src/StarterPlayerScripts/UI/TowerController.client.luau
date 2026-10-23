--!strict
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local PromptService=game:GetService("ProximityPromptService")
local Http=game:GetService("HttpService")
local player=Players.LocalPlayer
local floors=require(RS.Shared.Config.TowerFloorConfig)
local GothicBoxStyle=require(RS.Shared.Util.GothicBoxStyle)
local remotes=RS:WaitForChild("Remotes"):WaitForChild("TowerRemotes")
local selfState: any=nil
local context: any=nil
local pending: any=nil
local selected=1
local presence: any=nil
local gui=Instance.new("ScreenGui");gui.Name="TowerTravel";gui.ResetOnSpawn=false;gui.DisplayOrder=40;gui.Parent=player:WaitForChild("PlayerGui")
local function label(parent: Instance,text: string,pos: UDim2,size: UDim2): TextLabel
	local l=Instance.new("TextLabel");l.Position=pos;l.Size=size;l.BackgroundTransparency=1;l.Text=text;l.TextColor3=Color3.fromRGB(235,228,220)
	l.Font=Enum.Font.Gotham;l.TextSize=14;l.TextWrapped=true;l.Parent=parent;return l
end
local function button(parent: Instance,text: string,pos: UDim2,size: UDim2,callback: ()->()): TextButton
	local b=Instance.new("TextButton");b.Text=text;b.Position=pos;b.Size=size;b.BackgroundColor3=Color3.fromRGB(28,20,38)
	b.Name=text:gsub("[^%w]","");if b.Name=="" then b.Name="Close" end
	b.TextColor3=Color3.new(1,1,1);b.Font=Enum.Font.GothamBold;b.TextSize=14;b.Parent=parent
	GothicBoxStyle.Apply(b, { Style = "Button", OnClick = callback });return b
end
local panel=Instance.new("Frame");panel.Name="FloorSelector";panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.Size=UDim2.fromOffset(500,460)
panel.BackgroundColor3=Color3.fromRGB(15,12,22);panel.Visible=false;panel.Parent=gui
GothicBoxStyle.Apply(panel, { Style = "Window" })
local scale=Instance.new("UIScale");scale.Parent=panel
local reflow: any=nil
local function fit()
	local camera=workspace.CurrentCamera
	if camera then
		local width,height=math.min(500,camera.ViewportSize.X-24),math.min(460,camera.ViewportSize.Y-90)
		panel.Size=UDim2.fromOffset(width,height);scale.Scale=1
		if reflow then reflow(width,height) end
	end
end
fit();workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fit)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
local title=label(panel,"INFINITE TOWER",UDim2.fromOffset(20,12),UDim2.fromOffset(400,28));title.Font=Enum.Font.GothamBold
local subtitle=label(panel,"Development fixtures · encounters disabled",UDim2.fromOffset(20,42),UDim2.fromOffset(460,28))
local status=label(panel,"Connecting…",UDim2.fromOffset(20,390),UDim2.fromOffset(460,52))
local detail=label(panel,"",UDim2.fromOffset(20,255),UDim2.fromOffset(460,78))
local function request(action: string,id: number?)
	if not selfState or pending then return end
	local r={ContractVersion=1,RequestId=Http:GenerateGUID(false),Action=action,FloorId=id,CharacterGeneration=selfState.CharacterGeneration,
		ExpectedLocationRevision=selfState.LocationRevision,ExpectedSquadRevision=selfState.SquadRevision}
	pending=r.RequestId;status.Text="Preparing travel…";remotes.Request:FireServer(r)
end
_G.RequestTowerHub = function(): boolean
	if not selfState then
		warn("[TowerController] Cannot travel to Hub: selfState not ready yet")
		return false
	end
	if pending then
		warn("[TowerController] Travel already pending: " .. tostring(pending))
		return false
	end
	request("HUB")
	return true
end
local function render()
	local floor=floors.Get(selected)
	local info=presence and presence.Floors[selected+1]
	local names={};if info then for _,s in info.Squads do table.insert(names,s.DisplayName.." ("..s.RosterSize..")") end end
	detail.Text=string.format("Floor %d · %s\n%s%s\nVisitors: %d · Squads: %s",selected,floor.DisplayName,floor.BiomeId,floor.BossEnemyId and " · Boss floor" or "",info and #info.Visitors or 0,#names>0 and table.concat(names,", ") or "none")
	if selfState then status.Text=string.format("Visiting: %s · Squad: %s",selfState.PlayerLocation.FloorId==0 and "Hub" or tostring(selfState.PlayerLocation.FloorId),selfState.SquadAssignment and "assigned to "..selfState.SquadAssignment or "following") end
end
local scroll=Instance.new("ScrollingFrame");scroll.Name="Floors";scroll.Position=UDim2.fromOffset(20,82);scroll.Size=UDim2.fromOffset(460,164)
scroll.BackgroundColor3=Color3.fromRGB(33,30,40);scroll.CanvasSize=UDim2.fromOffset(0,10*39);scroll.ScrollBarThickness=5;scroll.Parent=panel
for id=1,50 do
	local b=button(scroll,tostring(id)..(id%5==0 and " ◆" or ""),UDim2.fromOffset(((id-1)%5)*90+4,math.floor((id-1)/5)*39+4),UDim2.fromOffset(84,33),function() selected=id;render() end)
	b.Name="Floor_"..id
end
button(panel,"Visit floor",UDim2.fromOffset(20,340),UDim2.fromOffset(145,38),function() request("VISIT",selected) end)
button(panel,"Assign squad",UDim2.fromOffset(177,340),UDim2.fromOffset(145,38),function() request("ASSIGN",selected) end)
button(panel,"Recall squad",UDim2.fromOffset(334,340),UDim2.fromOffset(145,38),function() request("RECALL") end)
button(panel,"×",UDim2.fromOffset(452,8),UDim2.fromOffset(36,28),function() panel.Visible=false end)
reflow=function(width: number,height: number)
	local compact=height<400
	local listY=compact and 52 or 82
	local listH=compact and math.max(44,height-224) or 164
	local detailY=listY+listH+4
	local actionY=compact and detailY+50 or 340
	title.Size=UDim2.fromOffset(width-76,26);title.Position=UDim2.fromOffset(20,compact and 2 or 12)
	subtitle.Size=UDim2.fromOffset(width-40,24);subtitle.Position=UDim2.fromOffset(20,compact and 27 or 42)
	scroll.Position=UDim2.fromOffset(20,listY);scroll.Size=UDim2.fromOffset(width-40,listH);scroll.CanvasSize=UDim2.fromOffset(0,440)
	local col=(width-40)/5
	for id=1,50 do local b=scroll:FindFirstChild("Floor_"..id);if b and b:IsA("TextButton") then b.Position=UDim2.fromOffset(((id-1)%5)*col+2,math.floor((id-1)/5)*44+2);b.Size=UDim2.fromOffset(col-5,40) end end
	detail.Position=UDim2.fromOffset(20,detailY);detail.Size=UDim2.fromOffset(width-40,compact and 48 or 78)
	local actionWidth=(width-64)/3
	for i,name in {"Visitfloor","Assignsquad","Recallsquad"} do local b=panel:FindFirstChild(name);if b and b:IsA("TextButton") then b.Position=UDim2.fromOffset(20+(i-1)*(actionWidth+12),actionY);b.Size=UDim2.fromOffset(actionWidth,44) end end
	status.Position=UDim2.fromOffset(20,actionY+48);status.Size=UDim2.fromOffset(width-40,math.max(24,height-actionY-52))
	local close=panel:FindFirstChild("Close");if close and close:IsA("TextButton") then close.Position=UDim2.fromOffset(width-48,2);close.Size=UDim2.fromOffset(44,44) end
end
fit()
remotes.OpenSelector.OnClientEvent:Connect(function() panel.Visible=true;render() end)
PromptService.PromptTriggered:Connect(function(prompt,who)
	if who and who~=player then return end
	local action=prompt:GetAttribute("TowerAction")
	local curFloor = if context and context.FloorId then context.FloorId elseif selfState and selfState.PlayerLocation then selfState.PlayerLocation.FloorId else 0
	if action=="SELECTOR" or prompt.Name=="TowerSelectorPrompt" then panel.Visible=true;render()
	elseif action=="HUB" then request("HUB")
	elseif action=="PREVIOUS" and curFloor>1 then request("VISIT",curFloor-1)
	elseif action=="NEXT" and curFloor>0 and curFloor<50 then request("VISIT",curFloor+1) end
end)
remotes.Presence.OnClientEvent:Connect(function(p)
	if presence and p.ServerSessionId==presence.ServerSessionId and p.PresenceRevision<presence.PresenceRevision then return end
	presence=p;selfState=p.Self;render()
end)
remotes.Response.OnClientEvent:Connect(function(r)
	if r.RequestId~=pending then return end
	if r.Status~="PENDING" then pending=nil;status.Text=r.ErrorCode or "Travel ready" end
end)
remotes.Context.OnClientEvent:Connect(function(c)
	if c.Stage=="PREPARE" then
		task.spawn(function()
			local ok=true
			if workspace.StreamingEnabled then ok=pcall(function() player:RequestStreamAroundAsync(c.Arrival.Position,math.max(.1,c.ReadyDeadline-workspace:GetServerTimeNow())) end) end
			remotes.Ready:FireServer({ContractVersion=1,RequestId=c.RequestId,ReadyToken=c.ReadyToken,ViewEpoch=c.ViewEpoch,CharacterGeneration=c.CharacterGeneration,Result=ok and workspace:GetServerTimeNow()<=c.ReadyDeadline and "READY" or "FAILED"})
		end)
	elseif c.Stage=="COMMIT" then
		context=c;_G.TowerView=c
		if c.FloorId>0 then selected=c.FloorId end
		local char=player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then root.AssemblyLinearVelocity=Vector3.zero;root.AssemblyAngularVelocity=Vector3.zero end
		render()
	end
end)
task.defer(function() remotes.Request:FireServer({ContractVersion=1,RequestId=Http:GenerateGUID(false),Action="PRESENCE_SUBSCRIBE"}) end)
