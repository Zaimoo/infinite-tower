--!strict
-- ServerScriptService/Core/PlotBuildings.luau
-- Waiting Room facilities & Outskirts Guard Post with F-key/E-key interactions at each entrance.
-- Implements GDD Sections 2.4, 3.2, 3.4 & 4.3 (Citadel Courtyard 260x180 + Southern Outskirts Grounds 260x140).

local Buildings = {}
local Architecture = require(script.Parent:WaitForChild("PlotFacilityArchitecture"))
local VERSION = 10

local definitions = {
	-- North Courtyard: Recovery & Summoning
	{Id = "Infirmary", Title = "INFIRMARY", Subtitle = "REST & RECOVERY", X = -75, Z = -35, Color = Color3.fromRGB(100, 232, 175)},
	{Id = "Summoning", Title = "SUMMONING", Subtitle = "CALL OF THE RIFT", X = 75, Z = -35, Color = Color3.fromRGB(96, 191, 255)},

	-- Center Courtyard: Heraldic Squad Command Standard
	{Id = "SquadManagement", Title = "SQUAD DEPLOY", Subtitle = "5 ACTIVE SLOTS", X = 0, Z = 0, Color = Color3.fromRGB(245, 128, 99)},

	-- Mid Courtyard: The Pit (Synthesis & Promotion) & The Blacksmith Forge
	{Id = "Synthesis", Title = "SYNTHESIS", Subtitle = "THE ESSENCE CAULDRON", X = -82, Z = 35, Color = Color3.fromRGB(177, 110, 255)},
	{Id = "Promotion", Title = "PROMOTION", Subtitle = "HALL OF ASCENSION", X = -45, Z = 35, Color = Color3.fromRGB(255, 202, 93)},
	{Id = "Blacksmith", Title = "BLACKSMITH FORGE", Subtitle = "ARTIFACT ASCENSION & REFINING", X = 75, Z = 35, Color = Color3.fromRGB(255, 120, 40)},

	-- South Inner Courtyard: Support Facilities
	{Id = "TrainingGrounds", Title = "TRAINING GROUNDS", Subtitle = "MARTIAL COMBAT DRILLS", X = -65, Z = 72, Color = Color3.fromRGB(235, 80, 80)},
	{Id = "Market", Title = "THE MARKET", Subtitle = "TOWER LOOT & COMMERCE", X = 65, Z = 72, Color = Color3.fromRGB(245, 195, 75)},

	-- Southern Outskirts Grounds (Exterior Frontier Wilderness)
	{Id = "GuardPost", Title = "OUTSKIRTS GUARD POST", Subtitle = "FRONTIER PATROL & PASSIVE GOLD", X = 0, Z = 160, Color = Color3.fromRGB(130, 205, 95)},
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
	local origin = if top and top:IsA("BasePart") then
		CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation * CFrame.new(0, 0, -70)
	else
		CFrame.new(spawn.Position.X, surfaceY, spawn.Position.Z) * spawn.CFrame.Rotation * CFrame.new(0, 0, 80)
	local folder = Instance.new("Folder")
	folder.Name = "PlotBuildings_Updating"
	folder:SetAttribute("Version", VERSION)
	folder.Parent = plot

	-- Ensure solid ground and patrol trail for the Southern Outskirts (GDD Section 3.4)
	-- Width of the Outskirts matches the Fortress Width exactly (260 studs)
	local outskirtsGround = Instance.new("Part")
	outskirtsGround.Name = "OutskirtsGrounds"
	outskirtsGround.Size = Vector3.new(260, 6, 140)
	outskirtsGround.CFrame = origin * CFrame.new(0, -3, 160)
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
	trail.Size = Vector3.new(230, 0.25, 20)
	trail.CFrame = origin * CFrame.new(0, 0.12, 160)
	trail.Anchored = true
	trail.CanCollide = false
	trail.Material = Enum.Material.Sand
	trail.Color = Color3.fromRGB(135, 115, 88)
	trail.Parent = folder

	-- Decorative Pine Trees along the southern wilderness border (Z = 218)
	for _, tx in {-110, -75, -40, 0, 40, 75, 110} do
		local trunk = Instance.new("Part")
		trunk.Name = "BorderPineTrunk"
		trunk.Size = Vector3.new(2.2, 14, 2.2)
		trunk.CFrame = origin * CFrame.new(tx, 7, 218)
		trunk.Anchored = true
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(72, 50, 32)
		trunk.Parent = folder

		local foliage = Instance.new("Part")
		foliage.Name = "BorderPineFoliage"
		foliage.Size = Vector3.new(12, 18, 12)
		foliage.CFrame = origin * CFrame.new(tx, 20, 218)
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
		local frame: CFrame
		if outward.Magnitude < 0.1 then
			frame = origin * CFrame.new(def.X, 0, def.Z)
		else
			frame = CFrame.lookAt(position, position + outward)
		end
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
			elseif def.Id == "Blacksmith" then 10
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
			prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
		elseif def.Id == "Market" then
			prompt.ObjectText = "The Market"
			prompt.ActionText = "Manage Merchants & Upgrades"
			prompt.MaxActivationDistance = 12
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
		elseif def.Id == "TrainingGrounds" then
			prompt.ObjectText = "Training Grounds"
			prompt.ActionText = "Manage Trainers & Drills"
			prompt.MaxActivationDistance = 12
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
		elseif def.Id == "GuardPost" then
			prompt.ObjectText = "Outskirts Guard Post"
			prompt.ActionText = "Manage Adventurers & Defense"
			prompt.MaxActivationDistance = 14
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
		elseif def.Id == "Blacksmith" then
			prompt.Name = "BlacksmithPrompt"
			prompt.ObjectText = "Blacksmith Forge"
			prompt.ActionText = "Upgrade & Refine Artifacts"
			prompt.MaxActivationDistance = 14
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.E, Enum.KeyCode.ButtonX
			prompt:SetAttribute("FacilityHUD", "Forge")
		else
			prompt.ObjectText = def.Title
			prompt.ActionText = "Open " .. def.Id
			prompt.MaxActivationDistance = 10
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
		end
		prompt.ClickablePrompt = true
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = interaction
		model.Parent = folder
	end

	if existing then existing:Destroy() end
	folder.Name = "PlotBuildings"
	return folder
end

return Buildings
