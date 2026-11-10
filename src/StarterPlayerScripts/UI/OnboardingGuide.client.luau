--!strict
-- Local cues are decorative and never consume input or change a gameplay action.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Store = require(script.Parent.Hud.Store)
local UIFeel = require(script.Parent.UIFeel)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local GOLD = Color3.fromRGB(255, 216, 119)
local INK = Color3.fromRGB(28, 20, 35)

local gui = Instance.new("ScreenGui")
gui.Name = "OnboardingGuide"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 150
-- Hidden until the join loading screen (ReplicatedFirst/LoadingScreen) fades and sets ClientLoaded.
gui.Enabled = player:GetAttribute("ClientLoaded") == true
if not gui.Enabled then
	local loadedConn: RBXScriptConnection
	loadedConn = player:GetAttributeChangedSignal("ClientLoaded"):Connect(function()
		if player:GetAttribute("ClientLoaded") == true then
			gui.Enabled = true
			loadedConn:Disconnect()
		end
	end)
	task.delay(30, function()
		gui.Enabled = true
	end)
end
gui.Parent = playerGui

local function label(name: string, size: Vector2): TextLabel
	local object = Instance.new("TextLabel")
	object.Name = name
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Size = UDim2.fromOffset(size.X, size.Y)
	object.BackgroundTransparency = 1
	object.TextColor3 = GOLD
	object.Font = Enum.Font.GothamBold
	object.TextSize = 16
	object.Visible = false
	object.Parent = gui
	return object
end

local arrow = label("Direction", Vector2.new(28, 28))
arrow.Text = "▲"
arrow.TextSize = 26
arrow.TextStrokeTransparency = 0.25

local caption = label("Instruction", Vector2.new(240, 44))
caption.TextWrapped = true
caption.BackgroundColor3 = INK
caption.BackgroundTransparency = 0.10
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = caption

local highlight = Instance.new("Highlight")
highlight.Name = "GuideOutline"
highlight.FillTransparency = 0.92
highlight.OutlineColor = GOLD
highlight.FillColor = GOLD
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Enabled = false
highlight.Parent = workspace

local ring = Instance.new("Frame")
ring.Name = "GuideRing"
ring.Visible = false
ring.Parent = gui
ring.BackgroundTransparency = 1
local ringCorner = corner:Clone()
ringCorner.Parent = ring
local outline = Instance.new("UIStroke")
outline.Color = GOLD
outline.Thickness = 3
outline.Parent = ring

local halo = Instance.new("Frame")
halo.Name = "Pulse"
halo.BackgroundTransparency = 1
halo.AnchorPoint = Vector2.new(0.5, 0.5)
halo.Position = UDim2.fromScale(0.5, 0.5)
halo.Parent = ring
local haloCorner = corner:Clone()
haloCorner.Parent = halo
local haloStroke = Instance.new("UIStroke")
haloStroke.Color = GOLD
haloStroke.Thickness = 2
haloStroke.Parent = halo

local function shown(object: Instance?): boolean
	local current = object
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("ScreenGui") and not current.Enabled then return false end
		current = current.Parent
	end
	return current == playerGui
end

local function control(root: Instance?, name: string): GuiButton?
	local button = root and root:FindFirstChild(name, true)
	if not button or not button:IsA("GuiButton") or not button.Interactable or not shown(button) then return nil end
	local center = button.AbsolutePosition + button.AbsoluteSize / 2
	local parent = button.Parent
	while parent and parent ~= playerGui do
		if parent:IsA("GuiObject") and parent.ClipsDescendants then
			local at = center - parent.AbsolutePosition
			if at.X < 0 or at.Y < 0 or at.X > parent.AbsoluteSize.X or at.Y > parent.AbsoluteSize.Y then return nil end
		end
		parent = parent.Parent
	end
	return button
end

local function modalControl(goal: any): (GuiButton?, boolean)
	local id = goal.Id
	local root: Instance?
	local button: GuiButton?
	if id == "Visit" or id == "step_floor1" then
		root = playerGui:FindFirstChild("FloorSelector", true)
		button = control(root, "GuideVisitFloor1") or control(root, "GuideFloor1")
	elseif id == "Ready" or id == "step_deploy" then
		root = playerGui:FindFirstChild("SquadDeployModal", true)
		button = control(root, "GuideSquadHero")
		for slot = 1, 5 do
			if button then break end
			button = control(root, `GuideSquadSlot{slot}`)
		end
	elseif id == "Summon" or id == "step_summon" then
		root = playerGui:FindFirstChild("PermanentSummonView", true)
		button = control(root, "PermSummon1XBtn")
	elseif id == "Upgrade" or id == "Equip" or id == "step_forge" then
		root = playerGui:FindFirstChild("ForgeWorkbench")
		if id == "Equip" then
			button = control(root, "EquipBestButton") or control(root, "ActionBarEquip")
		else
			button = control(root, "ConfirmUpgradeButton") or control(root, "ReviewUpgradeButton")
				or control(root, "AutoFillMaterialsButton") or control(root, "ActionBarUpgrade")
			if not button and root and goal.Control then
				button = control(root:FindFirstChild(`Tile_{goal.Control}`, true), "TileButton")
			end
		end
	elseif id == "Tree" or id == "step_tree" then
		root = playerGui:FindFirstChild("FortressTreeOverlay", true)
		local node = root and goal.Control and root:FindFirstChild(goal.Control, true)
		button = control(node, "Hit")
	elseif id == "Promotion" then
		root = playerGui:FindFirstChild("HeroPromotionModal", true)
		button = control(root, "InitiatePromotionButton") or control(root, "MainHeroSlot")
		if not shown(root) and shown(playerGui:FindFirstChild("SynthesisModal", true)) then
			return control(playerGui, "PromotionTab"), true
		end
	elseif id == "Synthesis" or id == "step_pit" then
		root = playerGui:FindFirstChild("SynthesisModal", true)
		local popup = playerGui:FindFirstChild("SynthesisPopup", true)
		button = control(popup, "Proceed") or control(root, "ConfirmButton") or control(root, "SelectRecipientButton")
	elseif goal.Target then
		root = playerGui:FindFirstChild(`GuideFacility_{goal.Target}`, true)
		button = control(root, "GuideAssignWorker")
	end
	return button, shown(root)
end

local BUILDINGS: { [string]: string } = {
	Summoning = "Building_Summoning", Blacksmith = "Building_Blacksmith", GuardPost = "Building_GuardPost",
	Market = "Building_Market", TrainingGrounds = "Building_TrainingGrounds", ThePit = "Building_ThePit",
}
local LEGACY_TARGETS: { [string]: string } = {
	step_summon = "Summoning", step_deploy = "Squad", step_floor1 = "Tower", step_forge = "Blacksmith",
	step_facilities = "GuardPost", step_pit = "ThePit", step_tree = "Upgrades",
}

local function ownPlot(): Instance?
	local folder = workspace:FindFirstChild("WaitingRoomPlots")
	if folder then
		for _, plot in folder:GetChildren() do
			if plot:GetAttribute("OwnerUserId") == player.UserId then return plot end
		end
	end
	return nil
end

local function promptPosition(prompt: Instance?): Vector3?
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then return nil end
	local anchor = prompt.Parent
	if anchor and anchor:IsA("Attachment") then return anchor.WorldPosition end
	if anchor and anchor:IsA("BasePart") then return anchor.Position end
	return nil
end

local function floorRoom(): Instance?
	local rooms = workspace:FindFirstChild("TowerRooms")
	if rooms then
		for _, room in rooms:GetChildren() do
			if room:GetAttribute("FloorId") == Store.PlayerFloorId then return room end
		end
	end
	return nil
end

local function worldTarget(target: string, root: BasePart): (Vector3?, Instance?)
	if target == "Tower" then
		local tower = workspace:FindFirstChild("CentralCrimsonTower", true)
		return promptPosition(tower and tower:FindFirstChild("TowerSelectorPrompt", true)), nil
	elseif target == "Raid" then
		local raid = workspace:FindFirstChild("RaidPortal")
		return promptPosition(raid and raid:FindFirstChild("EnterRaid", true)), raid
	elseif (target == "Hub" or target == "Bank") and Store.PlayerFloorId > 0 then
		local room = floorRoom()
		local portal = room and room:FindFirstChild("TravelPortal_HUB")
		return promptPosition(portal and portal:FindFirstChildWhichIsA("ProximityPrompt", true)), portal
	end

	local plot = ownPlot()
	if not plot then return nil, nil end
	if target == "Bank" then
		local pad = plot:FindFirstChild("PrivateExtractionPad")
		return if pad and pad:IsA("BasePart") then pad.Position else nil, pad
	end
	local buildings = plot:FindFirstChild("PlotBuildings")
	local buildingName = BUILDINGS[target]
	local building = if target == "GodsBlessing" then plot:FindFirstChild("Facility_GodsBlessing")
		else buildings and buildingName and buildings:FindFirstChild(buildingName)
	if not building then return nil, nil end
	local position = promptPosition(building:FindFirstChildWhichIsA("ProximityPrompt", true))
	if not position then return nil, nil end
	if target == "GuardPost" and buildings then
		local origin = buildings:GetAttribute("Origin")
		if typeof(origin) == "CFrame" and origin:PointToObjectSpace(root.Position).Z < 64 then
			return origin:PointToWorldSpace(Vector3.new(14, 2, 67)), nil
		end
	end
	return position, building
end

local renderConnection: RBXScriptConnection?
local point: Vector3?
local focusedButton: GuiButton?
local reducedMotion = false

local function stopWorld()
	point = nil
	arrow.Visible = false
	highlight.Enabled = false
	highlight.Adornee = nil
end

local function project(bounce: number)
	local camera = workspace.CurrentCamera
	local target = point
	if not camera or not target then arrow.Visible = false; caption.Visible = false; return end
	local size = gui.AbsoluteSize
	if size.X < 120 or size.Y < 120 then arrow.Visible = false; caption.Visible = false; return end
	local projected, inView = camera:WorldToScreenPoint(target)
	local center = size / 2
	local delta = Vector2.new(projected.X, projected.Y) - center
	local rotation = 180
	local pos = Vector2.new(projected.X, projected.Y - 34)
	if not inView or projected.Z <= 0 or pos.X < 36 or pos.X > size.X - 36 or pos.Y < 30 or pos.Y > size.Y - 56 then
		if projected.Z <= 0 then delta = -delta end
		if delta.Magnitude < 1 then delta = Vector2.new(0, 1) end
		local margin = Vector2.new(math.max(20, center.X - 40), math.max(20, center.Y - 58))
		local scale = math.max(math.abs(delta.X) / margin.X, math.abs(delta.Y) / margin.Y, 0.01)
		pos = center + delta / scale
		rotation = math.deg(math.atan2(delta.X, -delta.Y))
	end
	-- Keep the caption steady and bounce the arrow opposite the direction it points.
	local radians = math.rad(rotation)
	local arrowPos = pos + Vector2.new(-math.sin(radians), math.cos(radians)) * bounce
	arrow.Position = UDim2.fromOffset(arrowPos.X, arrowPos.Y)
	arrow.Rotation = rotation
	arrow.Visible = true
	caption.Position = UDim2.fromOffset(math.clamp(pos.X, 122, math.max(122, size.X - 122)), math.min(pos.Y + 42, size.Y - 23))
	caption.Visible = true
end

local function renderCue()
	local wave = if reducedMotion then 0 else 0.5 - 0.5 * math.cos(time() * 2 * math.pi / 1.35)
	if point then project(7 * wave) end
	if highlight.Enabled then
		highlight.OutlineTransparency = 0.12 + 0.3 * wave
		highlight.FillTransparency = 0.92 - 0.08 * wave
	end
	local button = focusedButton
	ring.Visible = button ~= nil and button.Parent ~= nil and button.Visible
	if button and ring.Visible then
		local offset = button.AbsolutePosition - gui.AbsolutePosition
		ring.Position = UDim2.fromOffset(offset.X, offset.Y)
		ring.Size = UDim2.fromOffset(button.AbsoluteSize.X, button.AbsoluteSize.Y)
		halo.Visible = not reducedMotion
		if halo.Visible then
			local spread = 4 + 10 * wave
			halo.Size = UDim2.new(1, spread, 1, spread)
			haloStroke.Transparency = 0.42 + 0.52 * wave
		end
	end
end

local function stopRendering()
	if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
end

local function refresh()
	local goal = Store.Goal
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local target = goal and (goal.Target or LEGACY_TARGETS[goal.Id])
	local button: GuiButton? = nil
	local showModal = false
	local position: Vector3? = nil
	local model: Instance? = nil
	local offline = playerGui:FindFirstChild("OfflineRewardScreenGui")
	if goal and Store.GuideVisible and workspace:GetAttribute("OnboardingMarkers") ~= false
		and not shown(offline and offline:FindFirstChild("ModalFrame")) and not shown(playerGui:FindFirstChild("SummonRevealScrim", true))
		and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0
		and not Store.ViewingSquad and not (_G.IsDuelActive and _G.IsDuelActive()) then
		if Store.ModalFocus then
			button, showModal = modalControl(goal)
		elseif goal.Id == "Clear" and Store.PlayerFloorId == 1 then
			local state = _G.ClientCombatState
			local boss = state and state.FloorBoss
			local visual = boss and boss.Enabled and state.VisualNodes and state.VisualNodes[boss.NetId]
			if visual and visual.RootPart and visual.RootPart.Parent and (visual.RootPart.Position - root.Position).Magnitude > 35 then
				position = visual.RootPart.Position + Vector3.new(0, 8, 0)
			end
		elseif target and (Store.PlayerFloorId == 0 or target == "Bank" or target == "Hub") then
			position, model = worldTarget(target, root)
			if target == "Tower" and position and (position - root.Position).Magnitude > 80 then position, model = nil, nil end
			if BUILDINGS[target] and position and (position - root.Position).Magnitude > 300 then
				button = control(playerGui, "IslandRailButton")
				if button then position, model = nil, nil end
			end
			if not position then
				local names = { Tower = "TowerRailButton", Squad = "GuideSquadHudSlot1", Upgrades = "FortressRailButton", Hub = "HubRailButton" }
				if names[target] then button = control(playerGui, names[target]) end
				if not button and target == "Squad" then button = control(playerGui, "SquadDrawerToggle") end
			end
		end
	end
	focusedButton = button
	reducedMotion = UIFeel.ReducedMotion()
	if position and root and root:IsA("BasePart") then
		point = position
		caption.Text = goal.Title
		local near = model ~= nil and (position - root.Position).Magnitude <= 50
		highlight.Adornee = if near then model else nil
		highlight.Enabled = near
	else
		stopWorld()
		caption.Visible = showModal
		if showModal then
			caption.Text = goal.Description
			caption.Position = UDim2.new(0.5, 0, 0, 24)
		end
	end
	renderCue()
	if point or focusedButton then
		if not renderConnection then renderConnection = RunService.RenderStepped:Connect(renderCue) end
	else
		stopRendering()
	end
end

local changed = Store.Changed:Connect(refresh)
local refreshLoop = task.spawn(function()
	while true do task.wait(0.2); refresh() end
end)
script.Destroying:Connect(function()
	changed:Disconnect()
	task.cancel(refreshLoop)
	stopRendering()
	stopWorld()
	ring:Destroy()
	highlight:Destroy()
	gui:Destroy()
end)
