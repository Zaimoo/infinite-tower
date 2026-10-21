--!strict
local Service=require(script.Parent.TowerFloorService)
Service.Init()
local geometry = workspace:WaitForChild("BaseOverhaulGeometry")
local function apply(model: Instance)
	if model.Name == "CentralCrimsonTower" and model:IsA("Model") then
		local recovery=game.ServerStorage:FindFirstChild("TowerLegacyTraversal") or Instance.new("Folder")
		recovery.Name="TowerLegacyTraversal";recovery.Parent=game.ServerStorage
		local old=model:FindFirstChild("WalkableTower");if old then old.Parent=recovery end
		for _,p in model:WaitForChild("TowerRings"):GetChildren() do if p:IsA("BasePart") then p.Transparency=0;p.CanCollide=true;p.CanQuery=true end end
		model:SetAttribute("TraversalVersion",4);model:SetAttribute("WalkableFloors",0)
		for _,p in model:GetDescendants() do if p:IsA("BasePart") and p.Name:find("PortalTrigger") then
			p.CanCollide=true
			local a=Instance.new("Attachment");a.Position=Vector3.new(0,-p.Size.Y/2+5,0);a.Parent=p
			local prompt=Instance.new("ProximityPrompt");prompt.Name="TowerSelectorPrompt";prompt.ActionText="Choose floor";prompt.ObjectText="Infinite Tower"
			prompt.KeyboardKeyCode=Enum.KeyCode.F;prompt.MaxActivationDistance=20;prompt.RequiresLineOfSight=false;prompt.Parent=a
			prompt.Triggered:Connect(function(player) game.ReplicatedStorage.Remotes.TowerRemotes.OpenSelector:FireClient(player) end)
		end end
		if not geometry:FindFirstChild("TowerHubArrival") then
			local p=Instance.new("Part");p.Name="TowerHubArrival";p.Size=Vector3.new(34,2,26);p.Position=Vector3.new(0,15,-330);p.Anchored=true
			p.Material=Enum.Material.Slate;p.Color=Color3.fromRGB(71,37,48);p.Parent=geometry
		end
	end
end
geometry.ChildAdded:Connect(apply)
for _, model in geometry:GetChildren() do apply(model) end
