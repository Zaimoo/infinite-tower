--!strict
-- Waiting Room facilities with F-key interactions at each entrance.
local Buildings = {}
local Architecture = require(script.Parent:WaitForChild("PlotFacilityArchitecture"))
local VERSION = 5
local definitions = {
	{Id = "Synthesis", Title = "SYNTHESIS", Subtitle = "THE ESSENCE FORGE", X = -46, Z = -24, Color = Color3.fromRGB(177, 110, 255)},
	-- The gate and PlotSpawn are on negative Z: keep that central approach clear.
	{Id = "Promotion", Title = "PROMOTION", Subtitle = "HALL OF ASCENSION", X = 0, Z = 44, Color = Color3.fromRGB(255, 202, 93)},
	{Id = "Infirmary", Title = "INFIRMARY", Subtitle = "REST & RECOVERY", X = 46, Z = -24, Color = Color3.fromRGB(100, 232, 175)},
	{Id = "Summoning", Title = "SUMMONING", Subtitle = "CALL OF THE RIFT", X = 46, Z = 24, Color = Color3.fromRGB(96, 191, 255)},
	{Id = "SquadManagement", Title = "SQUAD MANAGEMENT", Subtitle = "ASSEMBLE YOUR HEROES", X = -18, Z = 0, Color = Color3.fromRGB(245, 128, 99)},
}

function Buildings.Build(plot: Instance)
	local existing = plot:FindFirstChild("PlotBuildings")
	if existing and existing:GetAttribute("Version") == VERSION then return existing end
	local floor = plot:FindFirstChild("PlotFloor")
	local spawn = plot:FindFirstChild("PlotSpawn")
	if not floor or not floor:IsA("BasePart") or not spawn or not spawn:IsA("BasePart") then return nil end
	local surfaceY = spawn.Position.Y - spawn.Size.Y / 2
	local origin = CFrame.new(floor.Position.X, surfaceY, floor.Position.Z) * floor.CFrame.Rotation
	local folder = Instance.new("Folder")
	folder.Name = "PlotBuildings"
	folder:SetAttribute("Version", VERSION)
	folder.Name = "PlotBuildings_Updating"
	folder.Parent = plot
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
			elseif def.Id == "Summoning" then 4 else 0
		interaction.CFrame = frame * CFrame.new(0, 3.5, z)
		interaction.Anchored, interaction.Transparency = true, 1
		interaction.CanCollide, interaction.CanTouch, interaction.CanQuery = false, false, false
		interaction.Parent = model
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FacilityHUDPrompt"
		prompt:SetAttribute("FacilityHUD", def.Id)
		prompt.ObjectText = def.Title
		prompt.ActionText = "Open " .. (def.Id == "SquadManagement" and "Squad" or def.Id)
		prompt.KeyboardKeyCode, prompt.GamepadKeyCode = Enum.KeyCode.F, Enum.KeyCode.ButtonX
		prompt.MaxActivationDistance, prompt.HoldDuration = 10, 0
		prompt.RequiresLineOfSight, prompt.ClickablePrompt = false, true
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
