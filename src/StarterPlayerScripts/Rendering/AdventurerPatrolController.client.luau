--!strict
-- StarterPlayerScripts/Rendering/AdventurerPatrolController.client.luau
-- Client-rendered lightweight patrol visual loop for stationed Outskirts Adventurers (GDD Sections 2.4 & 3.4)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))

local VisualContainer = Workspace:FindFirstChild("AdventurerVisualEntities")
if not VisualContainer then
	local f = Instance.new("Folder")
	f.Name = "AdventurerVisualEntities"
	f.Parent = Workspace
	VisualContainer = f
end

type PatrolNode = {
	UUID: string,
	TemplateId: string,
	Slot: number,
	Model: Model,
	RootPart: Part,
	StartPos: Vector3,
	EndPos: Vector3,
	CurrentPos: Vector3,
	T: number,
	Direction: number,
	CombatCooldown: number,
	CritterModel: Model?,
}

local ActivePatrols: { [string]: PatrolNode } = {}

local function getLocalProfile(): any
	return _G.DataManager and _G.DataManager.GetProfile and _G.DataManager.GetProfile(LocalPlayer)
end

local function getPlotOrigin(): CFrame?
	local plots = Workspace:FindFirstChild("WaitingRoomPlots")
	if not plots then return nil end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
			local spawn = plot:FindFirstChild("PlotSpawn")
			if spawn and spawn:IsA("BasePart") then
				local island = plot:FindFirstChild("FloatingFortressIsland")
				local top = island and island:FindFirstChild("IslandTopSurface")
				local surfaceY = if top and top:IsA("BasePart") then top.Position.Y + top.Size.Y / 2
					else spawn.Position.Y - spawn.Size.Y / 2
				return CFrame.new(spawn.Position.X, surfaceY, spawn.Position.Z) * spawn.CFrame.Rotation
			end
		end
	end
	return nil
end

local function createAdventurerRig(hero: any, slot: number, startPos: Vector3, endPos: Vector3): PatrolNode
	local seed = HeroCatalog.Seeds[hero.TemplateId] or HeroCatalog.Seeds.hero_han
	local model = Instance.new("Model")
	model.Name = "Adventurer_" .. hero.UUID

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 4.2, 1.2)
	root.Position = startPos + Vector3.new(0, 2.1, 0)
	root.Color = seed.Color or Color3.fromRGB(130, 205, 95)
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.Color = root.Color:Lerp(Color3.new(1, 1, 1), 0.3)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Position = root.Position + Vector3.new(0, 2.8, 0)
	head.Parent = model

	-- Billboard Tag
	local bb = Instance.new("BillboardGui")
	bb.Name = "AdventurerTag"
	bb.Adornee = root
	bb.Size = UDim2.fromOffset(180, 40)
	bb.StudsOffset = Vector3.new(0, 4.2, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 140
	bb.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 12
	lbl.TextColor3 = Color3.fromRGB(245, 225, 140)
	lbl.Text = string.format("⚔️ %s\n<font color=\"#82CD5F\">[OUTSKIRTS ADVENTURER]</font>", hero.DisplayName)
	lbl.RichText = true
	lbl.Parent = bb

	model.Parent = VisualContainer

	return {
		UUID = hero.UUID,
		TemplateId = hero.TemplateId,
		Slot = slot,
		Model = model,
		RootPart = root,
		StartPos = startPos,
		EndPos = endPos,
		CurrentPos = startPos,
		T = math.random() * 0.8,
		Direction = 1,
		CombatCooldown = os.clock() + math.random(5, 10),
		CritterModel = nil,
	}
end

local function spawnAmbientCritter(pos: Vector3): Model
	local critter = Instance.new("Model")
	critter.Name = "WildernessCritter"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(1.4, 1.4, 1.4)
	body.Position = pos + Vector3.new(0, 0.7, 0)
	body.Color = Color3.fromRGB(60, 95, 50)
	body.Material = Enum.Material.Grass
	body.Anchored = true
	body.CanCollide = false
	body.Parent = critter

	local eyes = Instance.new("Part")
	eyes.Name = "Eyes"
	eyes.Size = Vector3.new(0.8, 0.3, 0.4)
	eyes.Position = body.Position + Vector3.new(0, 0.2, 0.6)
	eyes.Color = Color3.fromRGB(255, 230, 80)
	eyes.Material = Enum.Material.Neon
	eyes.Anchored = true
	eyes.CanCollide = false
	eyes.Parent = critter

	critter.Parent = VisualContainer
	return critter
end

-- 30 Hz Visual Interpolation Loop
local lastUpdate = 0
RunService.RenderStepped:Connect(function(dt: number)
	lastUpdate += dt
	if lastUpdate < 0.03 then return end
	lastUpdate = 0

	local origin = getPlotOrigin()
	if not origin then
		for _, node in pairs(ActivePatrols) do
			if node.CritterModel then node.CritterModel:Destroy() end
			node.Model:Destroy()
		end
		table.clear(ActivePatrols)
		return
	end

	local profile = getLocalProfile()
	local guardPost = profile and profile.Facilities and profile.Facilities.GuardPost
	local assigned = guardPost and guardPost.AssignedHeroUUIDs or {}
	local activeUUIDMap: { [string]: boolean } = {}

	for slotIndex, uuid in ipairs(assigned) do
		activeUUIDMap[uuid] = true
		local hero = profile.Heroes and profile.Heroes[uuid]
		if hero and not ActivePatrols[uuid] then
			local laneOffset = (slotIndex - 3) * 28
			local p1 = origin:PointToWorldSpace(Vector3.new(laneOffset - 12, 1.2, 85))
			local p2 = origin:PointToWorldSpace(Vector3.new(laneOffset + 12, 1.2, 85))
			ActivePatrols[uuid] = createAdventurerRig(hero, slotIndex, p1, p2)
		end
	end

	-- Clean up unassigned
	for uuid, node in pairs(ActivePatrols) do
		if not activeUUIDMap[uuid] then
			if node.CritterModel then node.CritterModel:Destroy() end
			node.Model:Destroy()
			ActivePatrols[uuid] = nil
		end
	end

	local now = os.clock()
	for _, node in pairs(ActivePatrols) do
		-- Waypoint Patrol Motion
		node.T += dt * 0.25 * node.Direction
		if node.T >= 1.0 then
			node.T = 1.0
			node.Direction = -1
		elseif node.T <= 0.0 then
			node.T = 0.0
			node.Direction = 1
		end

		local goal = node.StartPos:Lerp(node.EndPos, node.T)
		local lookTarget = if node.Direction > 0 then node.EndPos else node.StartPos
		node.RootPart.CFrame = CFrame.lookAt(goal + Vector3.new(0, 2.1, 0), lookTarget + Vector3.new(0, 2.1, 0))
		local head = node.Model:FindFirstChild("Head") :: Part?
		if head then
			head.Position = node.RootPart.Position + Vector3.new(0, 2.8, 0)
		end

		-- Ambient Combat Loop: Spawn & Strike Critter
		if not node.CritterModel and now >= node.CombatCooldown then
			local spawnPoint = goal + (node.RootPart.CFrame.LookVector * 6)
			node.CritterModel = spawnAmbientCritter(spawnPoint)
			node.CombatCooldown = now + 4.0
		elseif node.CritterModel and now >= node.CombatCooldown then
			-- Strike Critter with Sparks
			local cBody = node.CritterModel:FindFirstChild("Body") :: Part?
			if cBody then
				local spark = Instance.new("Part")
				spark.Size = Vector3.new(1.8, 1.8, 1.8)
				spark.Position = cBody.Position
				spark.Color = Color3.fromRGB(255, 215, 60)
				spark.Material = Enum.Material.Neon
				spark.Anchored = true
				spark.CanCollide = false
				spark.Parent = VisualContainer
				task.delay(0.2, function() spark:Destroy() end)
			end
			node.CritterModel:Destroy()
			node.CritterModel = nil
			node.CombatCooldown = now + math.random(12, 20)
		end
	end
end)
