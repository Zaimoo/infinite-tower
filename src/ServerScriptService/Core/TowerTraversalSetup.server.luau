--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Service = require(script.Parent.TowerFloorService)
Service.Init()

local geometry = workspace:WaitForChild("BaseOverhaulGeometry")

local function apply(model: Instance)
	if model.Name == "CentralCrimsonTower" and model:IsA("Model") then
		local recovery = game.ServerStorage:FindFirstChild("TowerLegacyTraversal") or Instance.new("Folder")
		recovery.Name = "TowerLegacyTraversal"
		recovery.Parent = game.ServerStorage
		local old = model:FindFirstChild("WalkableTower")
		if old then old.Parent = recovery end

		local rings = model:WaitForChild("TowerRings")
		for _, p in rings:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 0
				p.CanCollide = true
				p.CanQuery = true
			end
		end
		model:SetAttribute("TraversalVersion", 4)
		model:SetAttribute("WalkableFloors", 0)

		-- Solidify the base slab foundation
		local base = model:FindFirstChild("CrackedSmokyBase")
		local slab = base and base:FindFirstChild("CrackedGroundSlab")
		if slab and slab:IsA("BasePart") then
			slab.CanCollide = true
			slab.CanQuery = true
		end

		-- Setup portal trigger and proximity prompt
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Name:find("PortalTrigger") then
				p.CanCollide = false
				local a = p:FindFirstChild("PromptAttachment") or Instance.new("Attachment")
				a.Name = "PromptAttachment"
				a.Position = Vector3.new(0, -p.Size.Y / 2 + 5, 0)
				a.Parent = p

				local prompt = a:FindFirstChild("TowerSelectorPrompt") or Instance.new("ProximityPrompt")
				prompt.Name = "TowerSelectorPrompt"
				prompt.ActionText = "Choose floor"
				prompt.ObjectText = "Infinite Tower"
				prompt.KeyboardKeyCode = Enum.KeyCode.F
				prompt.MaxActivationDistance = 24
				prompt.RequiresLineOfSight = false
				prompt.Parent = a
				prompt.Triggered:Connect(function(player)
					local rem = ReplicatedStorage:FindFirstChild("Remotes")
					local tr = rem and rem:FindFirstChild("TowerRemotes")
					local sel = tr and tr:FindFirstChild("OpenSelector") :: RemoteEvent?
					if sel then sel:FireClient(player) end
				end)

				p.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if player then
						local rem = ReplicatedStorage:FindFirstChild("Remotes")
						local tr = rem and rem:FindFirstChild("TowerRemotes")
						local sel = tr and tr:FindFirstChild("OpenSelector") :: RemoteEvent?
						if sel then sel:FireClient(player) end
					end
				end)
			end
		end

		-- Ensure wide, solid arrival terrace is present
		if not geometry:FindFirstChild("TowerHubArrival") then
			local p = Instance.new("Part")
			p.Name = "TowerHubArrival"
			p.Size = Vector3.new(96, 2.4, 70)
			p.Position = Vector3.new(0, 15, -325)
			p.Anchored = true
			p.CanCollide = true
			p.Material = Enum.Material.Slate
			p.Color = Color3.fromRGB(55, 45, 52)
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Parent = geometry

			local runner = Instance.new("Part")
			runner.Name = "TowerHubArrival_Runner"
			runner.Size = Vector3.new(32, 0.2, 68)
			runner.Position = Vector3.new(0, 16.1, -325)
			runner.Anchored = true
			runner.CanCollide = false
			runner.Material = Enum.Material.Granite
			runner.Color = Color3.fromRGB(145, 28, 38)
			runner.TopSurface = Enum.SurfaceType.Smooth
			runner.BottomSurface = Enum.SurfaceType.Smooth
			runner.Parent = geometry

			for _, side in { -1, 1 } do
				local rail = Instance.new("Part")
				rail.Name = side < 0 and "TowerHubArrival_RailL" or "TowerHubArrival_RailR"
				rail.Size = Vector3.new(1.2, 4, 24)
				rail.Position = Vector3.new(side * 47.4, 18, -348)
				rail.Anchored = true
				rail.CanCollide = true
				rail.Material = Enum.Material.Granite
				rail.Color = Color3.fromRGB(112, 26, 37)
				rail.TopSurface = Enum.SurfaceType.Smooth
				rail.BottomSurface = Enum.SurfaceType.Smooth
				rail.Parent = geometry
			end
		end
	end
end

geometry.ChildAdded:Connect(apply)
for _, m in geometry:GetChildren() do apply(m) end
