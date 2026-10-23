--!strict
-- ServerScriptService/Core/PlotBuildings.luau
-- Waiting Room facilities & Outskirts Guard Post with F-key interactions at each entrance.
-- Implements GDD Sections 2.4, 3.4 & 4.3 (Citadel Courtyard + Southern Outskirts Grounds).

local Buildings = {}
local Architecture = require(script.Parent:WaitForChild("PlotFacilityArchitecture"))
local VERSION = 9

local definitions = {
	{Id = "Synthesis", Title = "SYNTHESIS", Subtitle = "THE ESSENCE FORGE", X = -46, Z = -24, Color = Color3.fromRGB(177, 110, 255)},
	-- The gate and PlotSpawn are on negative Z: keep that central approach clear.
	{Id = "Promotion", Title = "PROMOTION", Subtitle = "HALL OF ASCENSION", X = 0, Z = 44, Color = Color3.fromRGB(255, 202, 93)},
	{Id = "Infirmary", Title = "INFIRMARY", Subtitle = "REST & RECOVERY", X = 46, Z = -24, Color = Color3.fromRGB(100, 232, 175)},
	{Id = "Summoning", Title = "SUMMONING", Subtitle = "CALL OF THE RIFT", X = 46, Z = 24, Color = Color3.fromRGB(96, 191, 255)},
	{Id = "SquadManagement", Title = "SQUAD DEPLOY", Subtitle = "5 ACTIVE SLOTS", X = -18, Z = 0, Color = Color3.fromRGB(245, 128, 99)},
	-- Support Facilities (Inner Fortress Wings - GDD Sections 2.4 & 3.4)
	{Id = "Market", Title = "THE MARKET", Subtitle = "TOWER LOOT & COMMERCE", X = 48, Z = 50, Color = Color3.fromRGB(245, 195, 75)},
	{Id = "TrainingGrounds", Title = "TRAINING GROUNDS", Subtitle = "MARTIAL COMBAT DRILLS", X = -48, Z = 50, Color = Color3.fromRGB(235, 80, 80)},
	-- Southern Outskirts Grounds (Exterior Frontier Wilderness - GDD Sections 2.4, 3.4 & 4.3)
	{Id = "GuardPost", Title = "OUTSKIRTS GUARD POST", Subtitle = "FRONTIER PATROL & PASSIVE GOLD", X = 0, Z = 86, Color = Color3.fromRGB(130, 205, 95)},
}

function Buildings.Build(plot: Instance)
	local existing = plot:FindFirstChild("PlotBuildings")
	if existing and existing:GetAttribute("Version") == VERSION then return existing end
	local spawn = plot:FindFirstChild("PlotSpawn")
	if not spawn or not spawn:IsA("BasePart") then return nil end
	local island = plot:FindFirstChild("FloatingFortressIsland")
	local top = island and island:FindFirstChild("IslandTopSurface")
	local anchorPart = if top and top:IsA("BasePart") then top
		elseif plot:FindFirstChild("PlotFloor") and plot.PlotFloor:IsA("BasePart") then plot.PlotFloor
		else spawn
	local surfaceY = if top and top:IsA("BasePart") then top.Position.Y + top.Size.Y / 2
		else spawn.Position.Y - spawn.Size.Y / 2
	local origin = CFrame.new(anchorPart.Position.X, surfaceY, anchorPart.Position.Z) * anchorPart.CFrame.Rotation
	local folder = Instance.new("Folder")
	folder.Name = "PlotBuildings_Updating"
	folder:SetAttribute("Version", VERSION)
	folder.Parent = plot

	-- Ensure solid ground and patrol trail for the Southern Outskirts (GDD Section 3.4)
	local outskirtsGround = Instance.new("Part")
	outskirtsGround.Name = "OutskirtsGrounds"
	outskirtsGround.Size = Vector3.new(220, 6, 95)
	outskirtsGround.CFrame = origin * CFrame.new(0, -3, 85)
	outskirtsGround.Anchored = true
	outskirtsGround.CanCollide = true
	outskirtsGround.CanTouch = true
	outskirtsGround.CanQuery = true
	outskirtsGround.Material = Enum.Material.Ground
	outskirtsGround.Color = Color3.fromRGB(88, 76, 62)
	outskirtsGround.Parent = folder

	-- Dirt wilderness patrol trail
	local trail = Instance.new("Part")
	trail.Name = "WildernessPatrolTrail"
	trail.Size = Vector3.new(180, 0.25, 16)
	trail.CFrame = origin * CFrame.new(0, 0.12, 85)
	trail.Anchored = true
	trail.CanCollide = false
	trail.Material = Enum.Material.Sand
	trail.Color = Color3.fromRGB(135, 115, 88)
	trail.Parent = folder

	-- Decorative Pine Trees along the southern wilderness border
	for _, tx in {-80, -45, 45, 80} do
		local trunk = Instance.new("Part")
		trunk.Name = "BorderPineTrunk"
		trunk.Size = Vector3.new(1.8, 12, 1.8)
		trunk.CFrame = origin * CFrame.new(tx, 6, 120)
		trunk.Anchored = true
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(72, 50, 32)
		trunk.Parent = folder

		local foliage = Instance.new("Part")
		foliage.Name = "BorderPineFoliage"
		foliage.Size = Vector3.new(10, 16, 10)
		foliage.CFrame = origin * CFrame.new(tx, 18, 120)
		foliage.Anchored = true
		foliage.Material = Enum.Material.Grass
		foliage.Color = Color3.fromRGB(42, 68, 45)
		foliage.Parent = folder
	end

	for _, def in definitions do
		local model = Instance.new("Model")
		model.Name = "Building_" .. def.Id
		model:SetAttribute("Facility", def.Id)
		local position = origin:PointToWorldSpace(Vector3.new(def.X, 0, def.Z))
		local outward = position - origin.Position
		local frame = CFrame.lookAt(position, position + outward)
		Architecture.Build(model, frame, def.Id, def.Color)
		local interaction = Instance.new("Part")
		interaction.Name = "FacilityInteraction"
		interaction.Size = Vector3.new(1, 1, 1)
		local z = if def.Id == "Synthesis" or def.Id == "Promotion" then 18
			elseif def.Id == "Infirmary" then 13
			elseif def.Id == "Summoning" then 4
			elseif def.Id == "Market" then 8
			elseif def.Id == "TrainingGrounds" then 10
			elseif def.Id == "GuardPost" then 9
			else 0
		interaction.CFrame = frame * CFrame.new(0, 3.5, z)
		interaction.Anchored, interaction.Transparency = true, 1
		interaction.CanCollide, interaction.CanTouch, interaction.CanQuery = false, false, true
		interaction.Parent = model
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FacilityHUDPrompt"
		prompt:SetAttribute("FacilityHUD", def.Id)
		if def.Id == "SquadManagement" then
			prompt.ObjectText = "War Banner"
			prompt.ActionText = "Deploy & Manage Squad"
			prompt.MaxActivationDistance = 14
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
		elseif def.Id == "Market" then
			prompt.ObjectText = "The Market"
			prompt.ActionText = "Manage Merchants & Upgrades"
			prompt.MaxActivationDistance = 12
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
		elseif def.Id == "TrainingGrounds" then
			prompt.ObjectText = "Training Grounds"
			prompt.ActionText = "Manage Trainers & Drills"
			prompt.MaxActivationDistance = 12
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
		elseif def.Id == "GuardPost" then
			prompt.ObjectText = "Outskirts Guard Post"
			prompt.ActionText = "Manage Adventurers & Defense"
			prompt.MaxActivationDistance = 14
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
		else
			prompt.ObjectText = def.Title
			prompt.ActionText = "Open " .. def.Id
			prompt.MaxActivationDistance = 10
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
		end
		prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
		prompt.ClickablePrompt = true
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = interaction
		model.Parent = folder
		task.wait()
	end
	if existing then existing:Destroy() end
	folder.Name = "PlotBuildings"
	return folder
end

return Buildings
