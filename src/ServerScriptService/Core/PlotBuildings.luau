--!strict
-- ServerScriptService/Core/PlotBuildings.luau
-- Waiting Room facilities & Outskirts Guard Post with F-key interactions at each entrance.
-- Implements GDD Sections 2.4, 3.2, 3.4 & 4.3 (Citadel Courtyard 260x180 + Southern Outskirts Grounds 260x140).

local Buildings = {}
local Architecture = require(script.Parent:WaitForChild("PlotFacilityArchitecture"))
local OutskirtsBuilder = require(script.Parent:WaitForChild("OutskirtsEnvironmentBuilder"))
local FacilityPresence = require(script.Parent:WaitForChild("FacilityPresence"))
local VERSION = 17

local definitions = {
	-- Courtyard layout (Phase 4): a 3 x 2 grid either side of the spawn -> fountain -> rear gate
	-- walkway, which stays clear. Building entrances face the fountain.

	-- North row (spawn side): the two stations a Master visits most.
	{Id = "Summoning", Title = "SUMMONING", Subtitle = "CALL OF THE RIFT", X = -75, Z = -35, Color = Color3.fromRGB(96, 191, 255)},
	{Id = "Blacksmith", Title = "BLACKSMITH FORGE", Subtitle = "ARTIFACT ASCENSION & REFINING", X = 75, Z = -35, Color = Color3.fromRGB(255, 120, 40)},

	-- Middle row: the Command Post (War Banner + Architect's Table) mirrors The Pit.
	{Id = "SquadManagement", Title = "SQUAD DEPLOY", Subtitle = "WAR BANNER", X = -84, Z = 18, Color = Color3.fromRGB(245, 128, 99)},
	{Id = "ArchitectTable", Title = "ARCHITECT'S TABLE", Subtitle = "FORTRESS TREE", X = -63, Z = 24, Color = Color3.fromRGB(214, 180, 120)},
	{Id = "ThePit", Title = "THE PIT", Subtitle = "SYNTHESIS & PROMOTION", X = 75, Z = 18, Color = Color3.fromRGB(177, 110, 255)},

	-- South row: support facilities, hidden until built in the Fortress Tree.
	{Id = "TrainingGrounds", Title = "TRAINING GROUNDS", Subtitle = "MARTIAL COMBAT DRILLS", X = -75, Z = 68, Color = Color3.fromRGB(235, 80, 80)},
	{Id = "Market", Title = "THE MARKET", Subtitle = "TOWER LOOT & COMMERCE", X = 75, Z = 68, Color = Color3.fromRGB(245, 195, 75)},

	-- Southern Outskirts Grounds (Exterior Frontier Wilderness)
	{Id = "GuardPost", Title = "OUTSKIRTS GUARD POST", Subtitle = "FRONTIER PATROL & PASSIVE GOLD", X = 0, Z = 160, Color = Color3.fromRGB(130, 205, 95)},
}

-- A drafting desk with rolled blueprints and a candle. Built here rather than in
-- PlotFacilityArchitecture because it is a small prop, not a building.
local function buildArchitectTable(model: Model, frame: CFrame)
	local function prop(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanTouch = true, false
		p.CanCollide = name == "Tabletop" or name == "Leg"
		p.Size, p.CFrame, p.Color, p.Material = size, cf, color, material
		if shape then p.Shape = shape end
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local wood, dark = Color3.fromRGB(122, 84, 52), Color3.fromRGB(84, 58, 38)
	local ink = Color3.fromRGB(46, 84, 150)
	local top = frame * CFrame.new(0, 3.2, 0)
	local slant = top * CFrame.Angles(math.rad(-8), 0, 0)
	prop("Tabletop", Vector3.new(7, 0.4, 4), slant, wood, Enum.Material.Wood)
	for _, x in { -3.1, 3.1 } do
		for _, z in { -1.6, 1.6 } do
			prop("Leg", Vector3.new(0.4, 3.2, 0.4), frame * CFrame.new(x, 1.6, z), dark, Enum.Material.Wood)
		end
	end
	prop("Blueprint", Vector3.new(4.2, 0.05, 2.6), slant * CFrame.new(-0.6, 0.23, 0), Color3.fromRGB(196, 214, 236), Enum.Material.SmoothPlastic)
	prop("BlueprintInk", Vector3.new(3.4, 0.06, 0.08), slant * CFrame.new(-0.6, 0.26, -0.5), ink, Enum.Material.SmoothPlastic)
	prop("BlueprintInk", Vector3.new(0.08, 0.06, 1.8), slant * CFrame.new(-1.6, 0.26, 0.2), ink, Enum.Material.SmoothPlastic)
	for i = 0, 2 do
		prop("Scroll", Vector3.new(2.2, 0.4, 0.4), top * CFrame.new(2.3, 0.45, -1 + i * 0.6) * CFrame.Angles(0, math.rad(80), 0), Color3.fromRGB(232, 220, 190), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	prop("Candle", Vector3.new(0.3, 0.7, 0.3), top * CFrame.new(2.8, 0.6, 1.3), Color3.fromRGB(250, 244, 226), Enum.Material.SmoothPlastic)
	local flame = prop("CandleFlame", Vector3.new(0.25, 0.25, 0.25), top * CFrame.new(2.8, 1.05, 1.3), Color3.fromRGB(255, 196, 96), Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range = Color3.fromRGB(255, 190, 110), 0.8, 10
	light.Parent = flame
end

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
	local origin: CFrame
	if top and top:IsA("BasePart") then
		if top.Size.Z > 200 then
			-- Legacy 320-stud top slab centered at centerZ = 70
			origin = CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation * CFrame.new(0, 0, -70)
		else
			-- Clean 180-stud top slab centered at courtyard center Z = 0
			origin = CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation
		end
	else
		origin = CFrame.new(spawn.Position.X, surfaceY, spawn.Position.Z) * spawn.CFrame.Rotation * CFrame.new(0, 0, 80)
	end
	local folder = Instance.new("Folder")
	folder.Name = "PlotBuildings_Updating"
	folder:SetAttribute("Version", VERSION)
	folder.Parent = plot

	-- Build Southern Outskirts wilderness (Lush grass meadow, winding curved trail, asymmetrical pines/oaks, wild bushes, berry shrubs & boulders)
	OutskirtsBuilder.Build(folder, origin)

	for _, def in definitions do
		local model = Instance.new("Model")
		model.Name = "Building_" .. def.Id
		model:SetAttribute("Facility", def.Id)
		local position = origin:PointToWorldSpace(Vector3.new(def.X, 0, def.Z))
		local outward = position - origin.Position
		local frame: CFrame
		if def.Id == "SquadManagement" or outward.Magnitude < 0.1 then
			frame = origin * CFrame.new(def.X, 0, def.Z)
		else
			frame = CFrame.lookAt(position, position + outward)
		end
		if def.Id == "ArchitectTable" then
			buildArchitectTable(model, frame)
		else
			Architecture.Build(model, frame, def.Id, def.Color)
		end

		if def.Id == "ThePit" then
			-- Dual interactive stations for The Pit: Left is Synthesis Cauldron, Right is Promotion Altar
			local synthPart = Instance.new("Part")
			synthPart.Name = "FacilityInteraction_Synthesis"
			synthPart.Size = Vector3.new(2, 2, 2)
			synthPart.CFrame = frame * CFrame.new(-6.5, 3.5, 7)
			synthPart.Anchored, synthPart.Transparency = true, 1
			synthPart.CanCollide, synthPart.CanTouch, synthPart.CanQuery = false, false, true
			synthPart.Parent = model

			local synthPrompt = Instance.new("ProximityPrompt")
			synthPrompt.Name = "FacilityHUDPrompt"
			synthPrompt:SetAttribute("FacilityHUD", "Synthesis")
			synthPrompt.ObjectText = "Synthesis Cauldron"
			synthPrompt.ActionText = "Feed EXP & Imprints"
			synthPrompt.MaxActivationDistance = 14
			synthPrompt.HoldDuration = 0
			synthPrompt.RequiresLineOfSight = false
			synthPrompt.KeyboardKeyCode, synthPrompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
			synthPrompt.ClickablePrompt = true
			synthPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
			synthPrompt.Parent = synthPart

			local promoPart = Instance.new("Part")
			promoPart.Name = "FacilityInteraction_Promotion"
			promoPart.Size = Vector3.new(2, 2, 2)
			promoPart.CFrame = frame * CFrame.new(6.5, 3.5, 7)
			promoPart.Anchored, promoPart.Transparency = true, 1
			promoPart.CanCollide, promoPart.CanTouch, promoPart.CanQuery = false, false, true
			promoPart.Parent = model

			local promoPrompt = Instance.new("ProximityPrompt")
			promoPrompt.Name = "FacilityHUDPrompt"
			promoPrompt:SetAttribute("FacilityHUD", "Promotion")
			promoPrompt.ObjectText = "Promotion Altar"
			promoPrompt.ActionText = "Ascend Stars (1★-5★)"
			promoPrompt.MaxActivationDistance = 14
			promoPrompt.HoldDuration = 0
			promoPrompt.RequiresLineOfSight = false
			promoPrompt.KeyboardKeyCode, promoPrompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
			promoPrompt.ClickablePrompt = true
			promoPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
			promoPrompt.Parent = promoPart
		else
			local interaction = Instance.new("Part")
			interaction.Name = "FacilityInteraction"
			interaction.Size = Vector3.new(1, 1, 1)
			local z = if def.Id == "Summoning" then 4
				elseif def.Id == "Market" then 8
				elseif def.Id == "TrainingGrounds" then 10
				elseif def.Id == "GuardPost" then 9
				elseif def.Id == "Blacksmith" then 10
				elseif def.Id == "ArchitectTable" then 3
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
			prompt.ActionText = "Manage Merchants"
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
		elseif def.Id == "ArchitectTable" then
			prompt.ObjectText = "Architect's Table"
			prompt.ActionText = "Open Fortress Tree"
			prompt.MaxActivationDistance = 12
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
			prompt:SetAttribute("FacilityHUD", "FortressTree")
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
			prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
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
		end
		model.Parent = folder
	end

	-- Compatibility alias models for legacy external references
	for _, aliasName in { "Building_Synthesis", "Building_Promotion" } do
		local alias = Instance.new("Model")
		alias.Name = aliasName
		alias:SetAttribute("Facility", string.sub(aliasName, 10))
		alias.Parent = folder
	end

	if existing then existing:Destroy() end
	folder.Name = "PlotBuildings"
	-- Locked support facilities are hidden until the owner unlocks them (Phase 4 §5.6).
	FacilityPresence.Reapply(plot)
	return folder
end

return Buildings
