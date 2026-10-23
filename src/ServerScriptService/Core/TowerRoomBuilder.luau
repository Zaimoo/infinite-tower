--!strict
-- Part 2 transport fixtures. These are explicitly unfinished environments.
local Config=require(game.ReplicatedStorage.Shared.Config.TowerFloorConfig)
local Builder={}
function Builder.Origin(id: number): Vector3
	if id==0 then return Vector3.zero end
	return Vector3.new(12000+((id-1)%10)*1800,1000,12000+math.floor((id-1)/10)*1800)
end
local function part(parent: Instance,name: string,size: Vector3,pos: Vector3,color: Color3): Part
	local p=Instance.new("Part");p.Name=name;p.Size=size;p.Position=pos;p.Anchored=true
	p.Material=Enum.Material.Slate;p.Color=color;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent
	return p
end
function Builder.Build(id: number,generation: number): any
	assert(Config.IsFloorId(id))
	local origin=Builder.Origin(id)
	local model=Instance.new("Model");model.Name=string.format("Floor_%02d",id)
	model.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
	model:SetAttribute("FloorId",id);model:SetAttribute("RoomGeneration",generation);model:SetAttribute("ContentStatus","DEVELOPMENT_FIXTURE")
	model:SetAttribute("EncountersEnabled",false)
	local tint=Color3.fromHSV((math.ceil(id/5)-1)/10,.22,.28)
	part(model,"Ground",Vector3.new(248,4,248),origin-Vector3.new(0,2,0),tint)
	for _,s in {-1,1} do
		part(model,"WallX",Vector3.new(6,84,248),origin+Vector3.new(s*124,40,0),tint)
		part(model,"WallZ",Vector3.new(248,84,6),origin+Vector3.new(0,40,s*124),tint)
	end
	part(model,"OpaqueCeiling",Vector3.new(254,6,254),origin+Vector3.new(0,84,0),tint)
	local landing=part(model,"SafeArrival",Vector3.new(70,.2,42),origin+Vector3.new(0,.1,90),Color3.fromRGB(45,100,115))
	local light=Instance.new("PointLight");light.Range=60;light.Brightness=3;light.Parent=landing
	for _,pos in {Vector3.new(-65,18,-45),Vector3.new(65,18,-45),Vector3.new(0,18,30)} do
		local lamp=part(model,"FixtureLamp",Vector3.new(2,2,2),origin+pos,Color3.fromRGB(210,190,150));lamp.CanCollide=false
		local l=Instance.new("PointLight");l.Range=100;l.Brightness=2;l.Parent=lamp
	end
	if id==1 then
		for _,x in {-65,65} do part(model,"RuinsFixture",Vector3.new(12,18,12),origin+Vector3.new(x,9,-20),tint) end
	elseif id==5 then
		part(model,"BossDaisFixture",Vector3.new(60,2,60),origin+Vector3.new(0,1,-55),tint)
	elseif id==50 then
		for _,x in {-60,60} do part(model,"ThroneProbeFixture",Vector3.new(16,30,16),origin+Vector3.new(x,15,-55),tint) end
	end
	for i,action in {"PREVIOUS","NEXT","SELECTOR","HUB"} do
		local p=part(model,action,Vector3.new(10,7,4),origin+Vector3.new((i-2.5)*17,3.5,111),Color3.fromRGB(105,34,51))
		local prompt=Instance.new("ProximityPrompt")
		local actionText = if action=="PREVIOUS" then "Previous Floor"
			elseif action=="NEXT" then "Next Floor"
			elseif action=="SELECTOR" then "Choose Floor"
			elseif action=="HUB" then "Return to Hub"
			else action
		local objectText = if action=="PREVIOUS" then string.format("Floor %d", id - 1)
			elseif action=="NEXT" then string.format("Floor %d", id + 1)
			elseif action=="SELECTOR" or action=="HUB" then "Infinite Tower"
			else "Tower travel"
		prompt.ActionText=actionText;prompt.ObjectText=objectText;prompt.MaxActivationDistance=14
		prompt.RequiresLineOfSight=false;prompt.KeyboardKeyCode=Enum.KeyCode.F;prompt:SetAttribute("TowerAction",action)
		prompt.Enabled=not ((action=="PREVIOUS" and id==1) or (action=="NEXT" and id==50));prompt.Parent=p
		local bg=Instance.new("BillboardGui");bg.Name="PedestalLabel";bg.Size=UDim2.fromOffset(130,28);bg.StudsOffset=Vector3.new(0,4.5,0);bg.AlwaysOnTop=false;bg.MaxDistance=50;bg.Parent=p
		local lbl=Instance.new("TextLabel");lbl.Size=UDim2.fromScale(1,1);lbl.BackgroundTransparency=0.3;lbl.BackgroundColor3=Color3.fromRGB(24,20,30);lbl.TextColor3=Color3.fromRGB(245,235,225);lbl.Font=Enum.Font.GothamBold;lbl.TextSize=13
		local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,4);corner.Parent=lbl
		if action=="PREVIOUS" and id==1 then lbl.Text="Floor 1 (Lowest)";lbl.TextColor3=Color3.fromRGB(140,130,130)
		elseif action=="NEXT" and id==50 then lbl.Text="Floor 50 (Apex)";lbl.TextColor3=Color3.fromRGB(140,130,130)
		elseif action=="PREVIOUS" then lbl.Text=string.format("◀ Floor %d", id - 1)
		elseif action=="NEXT" then lbl.Text=string.format("Floor %d ▶", id + 1)
		elseif action=="SELECTOR" then lbl.Text="Choose Floor"
		elseif action=="HUB" then lbl.Text="Return to Hub" end
		lbl.Parent=bg
	end
	local sign=Instance.new("SurfaceGui");sign.Face=Enum.NormalId.Back;sign.CanvasSize=Vector2.new(1000,220);sign.Parent=model:FindFirstChild("WallZ")
	local label=Instance.new("TextLabel");label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.TextColor3=Color3.new(1,1,1)
	label.TextScaled=true;label.Font=Enum.Font.GothamBold;label.Text=string.format("FLOOR %d · %s\nDEVELOPMENT FIXTURE · ENCOUNTERS DISABLED",id,Config.Get(id).DisplayName);label.Parent=sign
	local folder=workspace:FindFirstChild("TowerRooms") or Instance.new("Folder");folder.Name="TowerRooms";folder.Parent=workspace
	model.Parent=folder
	return {FloorId=id,RoomGeneration=generation,Origin=origin,Model=model,Arrival=CFrame.new(origin+Vector3.new(0,3.5,90)),
		Bounds={Min=Vector3.new(-120,-4,-120),Max=Vector3.new(120,78,120)},
		Zones={{ZoneId="ARRIVAL",FloorId=id,RoomGeneration=generation,LocalPolygonXZ={Vector2.new(-40,65),Vector2.new(40,65),Vector2.new(40,118),Vector2.new(-40,118)},
			MinY=-1,MaxY=15,CombatSafe=true,CanBankCargo=false,CanRecoverWipe=false}}}
end
return Builder
