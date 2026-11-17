--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Service = require(script.Parent.TowerFloorService)
local StaticGeometry = require(script.Parent.StaticGeometry)
local Traversal = require(script.Parent.TowerTraversal)
Service.Init()

local geometry = workspace:WaitForChild("BaseOverhaulGeometry")

-- Every body part touching the portal pad fires Touched; open the floor selector once per visit.
local PAD_OPEN_COOLDOWN = 3
local lastPadOpen: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	lastPadOpen[player] = nil
end)

local function apply(model: Instance)
	if model.Name == "CentralCrimsonTower" and model:IsA("Model") then
		local recovery = game.ServerStorage:FindFirstChild("TowerLegacyTraversal") or Instance.new("Folder")
		recovery.Name = "TowerLegacyTraversal"
		recovery.Parent = game.ServerStorage
		local old = model:FindFirstChild("WalkableTower")
		if old then old.Parent = recovery end

		local rings = model:WaitForChild("TowerRings")
		-- Under the Blender remodel (GothicTowerShell) the rings are collision only, hidden inside the mesh
		local meshed = model:GetAttribute("ShellMeshed") == true
		for _, p in rings:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = if meshed then 1 else 0
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

				StaticGeometry.MarkNeedsTouch(p)
				p.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					local now = os.clock()
					if player and now - (lastPadOpen[player] or 0) >= PAD_OPEN_COOLDOWN then
						lastPadOpen[player] = now
						local rem = ReplicatedStorage:FindFirstChild("Remotes")
						local tr = rem and rem:FindFirstChild("TowerRemotes")
						local sel = tr and tr:FindFirstChild("OpenSelector") :: RemoteEvent?
						if sel then sel:FireClient(player) end
					end
				end)
			end
		end

		-- Wide, solid arrival terrace in front of the gate (also baked into the place by tests/studio-rebake-hub.luau)
		Traversal.EnsureHubArrival(geometry)
	end
end

geometry.ChildAdded:Connect(apply)
for _, m in geometry:GetChildren() do apply(m) end
