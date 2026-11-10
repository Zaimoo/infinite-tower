--!strict
-- StarterPlayerScripts/UI/OnboardingGuide.client.luau
-- Shows the player how to do the current guide lesson (GDD §4.7). Two kinds of cue:
--
--   * Press something: a SPOTLIGHT. The screen dims to black except for the one control to press,
--     with a gold ring round it and two or three words beside it. For a lesson of the core chain the
--     dim area also swallows input, which holds the player to the task.
--   * Walk somewhere: a TRAIL of gold chevrons on the ground from the player to the place, a beacon
--     on the place, and an arrow at the screen edge when it is out of view.
--
-- Everything here is local decoration: the server decides which lesson is current and whether an
-- action counts. The lock is a convenience, not a gate, and it always lets go when it cannot help
-- (the control is covered, pressing it changed nothing, or the player asks to skip).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Store = require(script.Parent.Hud.Store)
local UIFeel = require(script.Parent.UIFeel)
local HeroCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HeroCatalog"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local GOLD = Color3.fromRGB(255, 216, 119)
local INK = Color3.fromRGB(28, 20, 35)
local DIM = 0.38 -- transparency of the black overlay
local HOLE_PAD = 6

--============================================================================
-- SCREEN LAYERS
--============================================================================

local function screen(name: string, order: number, fullBleed: boolean): ScreenGui
	local layer = Instance.new("ScreenGui")
	layer.Name = name
	layer.ResetOnSpawn = false
	layer.DisplayOrder = order
	layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if fullBleed then
		layer.IgnoreGuiInset = true
		layer.ScreenInsets = Enum.ScreenInsets.None
	else
		layer.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	end
	return layer
end

-- Above every window (80s) and below toasts (290) and confirm dialogs (300).
local dimGui = screen("OnboardingSpotlight", 149, true)
local gui = screen("OnboardingGuide", 150, false)

-- Hidden until the join loading screen (ReplicatedFirst/LoadingScreen) fades and sets ClientLoaded.
local loaded = player:GetAttribute("ClientLoaded") == true
local function setLoaded()
	loaded = true
	gui.Enabled, dimGui.Enabled = true, true
end
gui.Enabled, dimGui.Enabled = loaded, loaded
if not loaded then
	local loadedConn: RBXScriptConnection
	loadedConn = player:GetAttributeChangedSignal("ClientLoaded"):Connect(function()
		if player:GetAttribute("ClientLoaded") == true then
			setLoaded()
			loadedConn:Disconnect()
		end
	end)
	task.delay(30, setLoaded)
end
dimGui.Parent = playerGui
gui.Parent = playerGui

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- Spotlight: four black panels around the hole. They are buttons so they can swallow input.
local panels: { TextButton } = {}
for _, name in { "Top", "Bottom", "Left", "Right" } do
	local panel = Instance.new("TextButton")
	panel.Name = "Dim" .. name
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.Selectable = false
	panel.BorderSizePixel = 0
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = 1
	panel.Visible = false
	panel.Parent = dimGui
	table.insert(panels, panel)
end

local skip = Instance.new("TextButton")
skip.Name = "SkipTutorial"
skip.AnchorPoint = Vector2.new(1, 1)
skip.Position = UDim2.new(1, -16, 1, -16)
skip.Size = UDim2.fromOffset(132, 36)
skip.BackgroundColor3 = INK
skip.BackgroundTransparency = 0.2
skip.Font = Enum.Font.GothamBold
skip.TextSize = 14
skip.TextColor3 = Color3.fromRGB(214, 204, 232)
skip.Text = "Skip tutorial"
skip.ZIndex = 5
skip.Visible = false
skip.Parent = dimGui
corner(skip, 8)

local ring = Instance.new("Frame")
ring.Name = "GuideRing"
ring.BackgroundTransparency = 1
ring.Visible = false
ring.Parent = gui
corner(ring, 10)
local ringStroke = Instance.new("UIStroke")
ringStroke.Color = GOLD
ringStroke.Thickness = 3
ringStroke.Parent = ring

local halo = Instance.new("Frame")
halo.Name = "Pulse"
halo.BackgroundTransparency = 1
halo.AnchorPoint = Vector2.new(0.5, 0.5)
halo.Position = UDim2.fromScale(0.5, 0.5)
halo.Parent = ring
corner(halo, 12)
local haloStroke = Instance.new("UIStroke")
haloStroke.Color = GOLD
haloStroke.Thickness = 2
haloStroke.Parent = halo

-- The words beside the highlighted control (or above the world target).
local caption = Instance.new("TextLabel")
caption.Name = "Instruction"
caption.AnchorPoint = Vector2.new(0.5, 0.5)
caption.AutomaticSize = Enum.AutomaticSize.XY
caption.BackgroundColor3 = INK
caption.BackgroundTransparency = 0.05
caption.Font = Enum.Font.GothamBold
caption.TextSize = 17
caption.TextColor3 = GOLD
caption.Text = ""
caption.Visible = false
caption.ZIndex = 4
caption.Parent = gui
corner(caption, 8)
do
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 7), UDim.new(0, 7)
	pad.Parent = caption
	local edge = Instance.new("UIStroke")
	edge.Color = GOLD
	edge.Thickness = 1.5
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = caption
end

-- Points from the caption at the control, or at the screen edge toward a place out of view.
local pointer = Instance.new("TextLabel")
pointer.Name = "Pointer"
pointer.AnchorPoint = Vector2.new(0.5, 0.5)
pointer.Size = UDim2.fromOffset(28, 28)
pointer.BackgroundTransparency = 1
pointer.Font = Enum.Font.GothamBold
pointer.Text = "▲"
pointer.TextSize = 26
pointer.TextColor3 = GOLD
pointer.TextStrokeTransparency = 0.25
pointer.Visible = false
pointer.ZIndex = 4
pointer.Parent = gui

--============================================================================
-- WORLD CUES: ground trail, beacon, outline
--============================================================================

local highlight = Instance.new("Highlight")
highlight.Name = "GuideOutline"
highlight.FillTransparency = 0.92
highlight.OutlineColor = GOLD
highlight.FillColor = GOLD
highlight.DepthMode = Enum.HighlightDepthMode.Occluded
highlight.Enabled = false
highlight.Parent = workspace

local trailFolder = Instance.new("Folder")
trailFolder.Name = "GuideTrail"
trailFolder.Parent = workspace

local function neon(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = GOLD
	part.Transparency = 1
	part.Parent = trailFolder
	return part
end

-- Each chevron is two slim bars meeting at a point that faces the way to walk.
local CHEVRONS = 8
local SPACING = 6 -- studs between chevrons
local TRAIL_SPEED = 9 -- studs per second
local ARM = Vector3.new(0.22, 0.12, 1.5)
local chevrons: { { Left: Part, Right: Part } } = {}
for i = 1, CHEVRONS do
	chevrons[i] = { Left = neon("ChevronL" .. i, ARM), Right = neon("ChevronR" .. i, ARM) }
end
local beacon = neon("Beacon", Vector3.new(0.3, 5, 5))
beacon.Shape = Enum.PartType.Cylinder

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hideTrail()
	for _, chevron in chevrons do
		chevron.Left.Transparency, chevron.Right.Transparency = 1, 1
	end
	beacon.Transparency = 1
end

local function ground(at: Vector3, fallbackY: number): number
	local hit = workspace:Raycast(at + Vector3.new(0, 8, 0), Vector3.new(0, -24, 0), rayParams)
	return if hit then hit.Position.Y else fallbackY
end

-- Lays the chevrons along the straight line from the player's feet to `target`, flowing forward.
local function drawTrail(root: BasePart, target: Vector3, reduced: boolean)
	local character = root.Parent
	rayParams.FilterDescendantsInstances = { trailFolder, character :: Instance }
	local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + 2, 0)
	local flat = Vector3.new(target.X - feet.X, 0, target.Z - feet.Z)
	local distance = flat.Magnitude
	if distance < 5 then
		hideTrail()
		return
	end
	local dir = flat / distance
	local length = math.min(distance - 2, CHEVRONS * SPACING)
	local flow = if reduced then 0 else (time() * TRAIL_SPEED) % SPACING
	local yaw = math.atan2(-dir.X, -dir.Z)
	for i, chevron in chevrons do
		local along = 3 + (i - 1) * SPACING + flow
		if along > length then
			chevron.Left.Transparency, chevron.Right.Transparency = 1, 1
			continue
		end
		local at = feet + dir * along
		local y = ground(at, feet.Y + (target.Y - feet.Y) * (along / distance)) + 0.15
		local base = CFrame.new(at.X, y, at.Z) * CFrame.Angles(0, yaw, 0)
		-- Fade in near the player and out at the far end.
		local fade = math.clamp(math.min(along / 6, (length - along) / 6), 0, 1)
		local transparency = 1 - 0.85 * fade
		chevron.Left.CFrame = base * CFrame.new(-0.5, 0, 0) * CFrame.Angles(0, math.rad(-38), 0)
		chevron.Right.CFrame = base * CFrame.new(0.5, 0, 0) * CFrame.Angles(0, math.rad(38), 0)
		chevron.Left.Transparency, chevron.Right.Transparency = transparency, transparency
	end
	-- A flat gold disc under the destination.
	local pulse = if reduced then 0 else 0.5 - 0.5 * math.cos(time() * 2 * math.pi / 1.35)
	beacon.Size = Vector3.new(0.3, 5 + pulse * 1.5, 5 + pulse * 1.5)
	beacon.CFrame = CFrame.new(target.X, ground(target, target.Y - 3) + 0.2, target.Z) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Transparency = 0.35 + 0.3 * pulse
end

--============================================================================
-- FINDING THE CONTROL OR THE PLACE
--============================================================================

local function shown(object: Instance?): boolean
	local current = object
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("ScreenGui") and not current.Enabled then return false end
		current = current.Parent
	end
	return current == playerGui
end

-- A named control under `root` that is on screen and can be pressed. The name may sit on a button
-- or on a frame that wraps one.
local function control(root: Instance?, name: string): GuiObject?
	local found = root and root:FindFirstChild(name, true)
	if not found or not found:IsA("GuiObject") or not shown(found) then return nil end
	local button: GuiButton? = if found:IsA("GuiButton") then found else found:FindFirstChildWhichIsA("GuiButton", true)
	if button and not button.Interactable then return nil end
	local center = found.AbsolutePosition + found.AbsoluteSize / 2
	local parent = found.Parent
	while parent and parent ~= playerGui do
		if parent:IsA("GuiObject") and parent.ClipsDescendants then
			local at = center - parent.AbsolutePosition
			if at.X < 0 or at.Y < 0 or at.X > parent.AbsoluteSize.X or at.Y > parent.AbsoluteSize.Y then return nil end
		end
		parent = parent.Parent
	end
	return found
end

-- The control to press inside the open window, and whether that lesson's window is the open one.
local function modalControl(goal: any): (GuiObject?, boolean)
	local id = goal.Id
	local root: Instance?
	local button: GuiObject?
	if id == "Visit" then
		root = playerGui:FindFirstChild("FloorSelector", true)
		button = control(root, "GuideVisitFloor1") or control(root, "GuideFloor1")
	elseif id == "Ready" or id == "Squad" then
		root = playerGui:FindFirstChild("SquadDeployModal", true)
		button = control(root, "GuideSquadHero")
		for slot = 1, 5 do
			if button then break end
			button = control(root, `GuideSquadSlot{slot}`)
		end
	elseif id == "Summon" or id == "Recruit" then
		root = playerGui:FindFirstChild("PermanentSummonView", true)
		-- The starter Gems are one ten-pull with a guaranteed Rare: point at that while it is affordable.
		local gems = Store.Profile and Store.Profile.Currencies and Store.Profile.Currencies.Gems or 0
		if id == "Summon" and gems >= HeroCatalog.PermanentBanner.Cost10X then button = control(root, "PermSummon10XBtn") end
		button = button or control(root, "PermSummon1XBtn")
	elseif id == "Roll" then
		root = playerGui:FindFirstChild("ForgeWorkbench")
		button = control(root, "Summon1XBtn") or control(playerGui, "Summon1XBtn") or control(root, "SummonTab")
	elseif id == "Equip" then
		root = playerGui:FindFirstChild("ForgeWorkbench")
		button = control(root, "EquipBestButton") or control(root, "ActionBarEquip") or control(root, "ArtifactsTab")
	elseif id == "Upgrade" then
		root = playerGui:FindFirstChild("ForgeWorkbench")
		button = control(root, "ConfirmUpgradeButton") or control(root, "ReviewUpgradeButton")
			or control(root, "AutoFillMaterialsButton") or control(root, "ActionBarUpgrade")
		if not button and root and goal.Control then
			button = control(root:FindFirstChild(`Tile_{goal.Control}`, true), "TileButton")
		end
	elseif id == "Tree" then
		root = playerGui:FindFirstChild("FortressTreeOverlay", true)
		local node = root and goal.Control and root:FindFirstChild(goal.Control, true)
		button = control(node, "Hit")
	elseif id == "Promotion" then
		root = playerGui:FindFirstChild("HeroPromotionModal", true)
		button = control(root, "InitiatePromotionButton") or control(root, "MainHeroSlot")
		local synthesis = playerGui:FindFirstChild("SynthesisModal", true)
		if not shown(root) and shown(synthesis) then return control(synthesis, "PromotionTab"), true end
	elseif id == "Synthesis" then
		root = playerGui:FindFirstChild("SynthesisModal", true)
		local promotion = playerGui:FindFirstChild("HeroPromotionModal", true)
		if not shown(root) and shown(promotion) then return control(promotion, "SynthesisTab"), true end
		-- Pick the hero first; then the materials are the player's choice, so only Confirm is lit.
		button = control(root, "EmptySelectHeroButton") or control(root, "ConfirmButton")
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
-- HUD buttons that stand in for a place that is far away or has no spot in the world.
local HUD_BUTTONS: { [string]: { string } } = {
	Tower = { "TowerRailButton" },
	Squad = { "SquadRailButton", "GuideSquadHudSlot1", "SquadDrawerToggle" },
	Upgrades = { "FortressRailButton" },
	Hub = { "HubRailButton" },
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

-- True when no higher layer that takes input sits on top of `object` (a confirm dialog, the summon
-- reveal). Layers are compared by DisplayOrder, so the answer does not depend on hit-list order.
local function uncovered(object: GuiObject): boolean
	local layer = object:FindFirstAncestorOfClass("ScreenGui")
	if not layer then return false end
	local center = object.AbsolutePosition + object.AbsoluteSize / 2
	for _, hit in playerGui:GetGuiObjectsAtPosition(center.X, center.Y) do
		if hit:IsDescendantOf(gui) or hit:IsDescendantOf(dimGui) then continue end
		local other = hit:FindFirstAncestorOfClass("ScreenGui")
		if other and other ~= layer and other.DisplayOrder > layer.DisplayOrder and (hit:IsA("GuiButton") or hit.Active) then
			return false
		end
	end
	return true
end

--============================================================================
-- STATE
--============================================================================

local renderConnection: RBXScriptConnection?
local point: Vector3? -- world target
local pointRoot: BasePart?
local focused: GuiObject? -- control under the spotlight
local locked = false -- the dim area swallows input
local reducedMotion = false
local dimShown = false

-- The lock lets go of a lesson when pressing its control changes nothing (not enough Gems, a server
-- refusal): the player must never be stuck in front of a button that does not work.
local released: { [string]: boolean } = {}
local presses = 0
local pressConnection: RBXScriptConnection?
local pressedObject: GuiObject?
local lastGoalKey = ""

local function watchPresses(object: GuiObject?, goalId: string)
	if object == pressedObject then return end
	if pressConnection then pressConnection:Disconnect(); pressConnection = nil end
	pressedObject = object
	presses = 0
	local button: GuiButton? = if object and object:IsA("GuiButton") then object elseif object then object:FindFirstChildWhichIsA("GuiButton", true) else nil
	if not button then return end
	pressConnection = button.Activated:Connect(function()
		presses += 1
		local seen, target = presses, object
		task.delay(3, function()
			-- Still the same control three seconds after the second press: stop holding the player.
			if seen >= 2 and presses == seen and pressedObject == target then
				released[goalId] = true
			end
		end)
	end)
end

local function setDim(visible: boolean, lock: boolean)
	locked = visible and lock
	for _, panel in panels do
		panel.Active = locked
		panel.Interactable = locked
	end
	skip.Visible = visible and lock
	if visible == dimShown then return end
	dimShown = visible
	local goalTransparency = if visible then DIM else 1
	for _, panel in panels do
		if visible then panel.Visible = true end
		if reducedMotion then
			panel.BackgroundTransparency = goalTransparency
			panel.Visible = visible
		else
			local tween = TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = goalTransparency })
			if not visible then
				tween.Completed:Once(function() if not dimShown then panel.Visible = false end end)
			end
			tween:Play()
		end
	end
end

-- A tap on the dim area: nudge the eye back to the lit control.
for _, panel in panels do
	panel.Activated:Connect(function()
		if not locked then return end
		UIFeel.Sfx("Error", 1, 0.4)
		UIFeel.Shake(caption, 3, 0.25)
	end)
end

skip.Activated:Connect(function()
	local ok, Kit = pcall(require, script.Parent:WaitForChild("Kit"))
	local function confirmed()
		Store.GuideAction("Skip")
	end
	if ok and Kit and Kit.Confirm then
		Kit.Confirm.Ask({ Tier = "Soft", Title = "Skip the tutorial?", Body = "Step rewards you haven't earned are forfeited.",
			ConfirmText = "Skip", OnConfirm = confirmed })
	else
		confirmed()
	end
end)

local function stopWorld()
	point, pointRoot = nil, nil
	highlight.Enabled = false
	highlight.Adornee = nil
	hideTrail()
end

-- Places the four dim panels round `object`, the ring on it and the caption beside it.
local function spotlight(object: GuiObject, wave: number)
	local origin = dimGui.AbsolutePosition
	local full = dimGui.AbsoluteSize
	local pos = object.AbsolutePosition - origin - Vector2.new(HOLE_PAD, HOLE_PAD)
	local size = object.AbsoluteSize + Vector2.new(HOLE_PAD * 2, HOLE_PAD * 2)
	local x0, y0 = math.clamp(pos.X, 0, full.X), math.clamp(pos.Y, 0, full.Y)
	local x1, y1 = math.clamp(pos.X + size.X, 0, full.X), math.clamp(pos.Y + size.Y, 0, full.Y)
	panels[1].Position, panels[1].Size = UDim2.fromOffset(0, 0), UDim2.fromOffset(full.X, y0)
	panels[2].Position, panels[2].Size = UDim2.fromOffset(0, y1), UDim2.fromOffset(full.X, full.Y - y1)
	panels[3].Position, panels[3].Size = UDim2.fromOffset(0, y0), UDim2.fromOffset(x0, y1 - y0)
	panels[4].Position, panels[4].Size = UDim2.fromOffset(x1, y0), UDim2.fromOffset(full.X - x1, y1 - y0)

	local local0 = object.AbsolutePosition - gui.AbsolutePosition - Vector2.new(HOLE_PAD, HOLE_PAD)
	ring.Position = UDim2.fromOffset(local0.X, local0.Y)
	ring.Size = UDim2.fromOffset(size.X, size.Y)
	ring.Visible = true
	halo.Visible = not reducedMotion
	if halo.Visible then
		local spread = 4 + 10 * wave
		halo.Size = UDim2.new(1, spread, 1, spread)
		haloStroke.Transparency = 0.42 + 0.52 * wave
	end

	-- Caption under the control when there is room, otherwise above it; the pointer joins the two.
	local area = gui.AbsoluteSize
	local centerX = local0.X + size.X / 2
	local below = local0.Y + size.Y + 44 < area.Y - 8
	local half = caption.AbsoluteSize.X / 2
	local captionY = if below then local0.Y + size.Y + 40 else local0.Y - 40
	caption.Position = UDim2.fromOffset(math.clamp(centerX, half + 8, math.max(half + 8, area.X - half - 8)), captionY)
	pointer.Rotation = if below then 0 else 180
	pointer.Position = UDim2.fromOffset(centerX, (if below then local0.Y + size.Y + 14 else local0.Y - 14) + (if below then 4 else -4) * wave)
	pointer.Visible = true
	caption.Visible = caption.Text ~= ""
end

-- The caption over a world target, or an arrow on the screen edge toward one that is out of view.
local function project(target: Vector3, root: BasePart, bounce: number)
	local camera = workspace.CurrentCamera
	local size = gui.AbsoluteSize
	if not camera or size.X < 120 or size.Y < 120 then
		pointer.Visible, caption.Visible = false, false
		return
	end
	local projected, inView = camera:WorldToScreenPoint(target)
	local center = size / 2
	local delta = Vector2.new(projected.X, projected.Y) - center
	local pos = Vector2.new(projected.X, projected.Y - 34)
	local offscreen = not inView or projected.Z <= 0 or pos.X < 36 or pos.X > size.X - 36 or pos.Y < 30 or pos.Y > size.Y - 56
	if offscreen then
		if projected.Z <= 0 then delta = -delta end
		if delta.Magnitude < 1 then delta = Vector2.new(0, 1) end
		local margin = Vector2.new(math.max(20, center.X - 40), math.max(20, center.Y - 58))
		local scale = math.max(math.abs(delta.X) / margin.X, math.abs(delta.Y) / margin.Y, 0.01)
		pos = center + delta / scale
		local rotation = math.deg(math.atan2(delta.X, -delta.Y))
		local radians = math.rad(rotation)
		local arrowPos = pos + Vector2.new(math.sin(radians), -math.cos(radians)) * bounce
		pointer.Position = UDim2.fromOffset(arrowPos.X, arrowPos.Y)
		pointer.Rotation = rotation
		pointer.Visible = true
	else
		pointer.Visible = false -- the trail on the ground shows the way
	end
	local half = caption.AbsoluteSize.X / 2
	caption.Position = UDim2.fromOffset(math.clamp(pos.X, half + 8, math.max(half + 8, size.X - half - 8)),
		math.clamp(pos.Y + (if offscreen then 34 else -4), 24, size.Y - 24))
	caption.Visible = caption.Text ~= ""
	local metres = math.floor((target - root.Position).Magnitude / 3.5 + 0.5)
	local title = caption:GetAttribute("Title")
	if type(title) == "string" then caption.Text = if metres > 3 then `{title}  ·  {metres}m` else title end
end

local function renderCue()
	local wave = if reducedMotion then 0 else 0.5 - 0.5 * math.cos(time() * 2 * math.pi / 1.35)
	local object = focused
	if object and object.Parent and shown(object) then
		spotlight(object, wave)
	else
		ring.Visible = false
		if not point then pointer.Visible = false end
	end
	local target, root = point, pointRoot
	if target and root and root.Parent then
		drawTrail(root, target, reducedMotion)
		project(target, root, 7 * wave)
		if highlight.Enabled then
			highlight.OutlineTransparency = 0.12 + 0.3 * wave
			highlight.FillTransparency = 0.92 - 0.08 * wave
		end
	end
end

local function stopRendering()
	if renderConnection then renderConnection:Disconnect(); renderConnection = nil end
end

--============================================================================
-- CHOOSING THE CUE (5 Hz)
--============================================================================

local function refresh()
	local goal = Store.Goal
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local target: string? = goal and goal.Target
	local object: GuiObject? = nil
	local inWindow = false
	local position: Vector3? = nil
	local model: Instance? = nil
	local offline = playerGui:FindFirstChild("OfflineRewardScreenGui")
	local core = goal ~= nil and goal.Core == true

	local goalKey = if goal then tostring(goal.Id) .. ":" .. tostring(goal.Control) else ""
	if goalKey ~= lastGoalKey then
		lastGoalKey = goalKey
		table.clear(released)
	end

	if goal and loaded and (core or Store.GuideVisible) and workspace:GetAttribute("OnboardingMarkers") ~= false
		and not shown(offline and offline:FindFirstChild("ModalFrame")) and not shown(playerGui:FindFirstChild("SummonRevealScrim", true))
		and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0
		and not Store.ViewingSquad and not (_G.IsDuelActive and _G.IsDuelActive()) then
		if Store.ModalFocus then
			object, inWindow = modalControl(goal)
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
				object = control(playerGui, "IslandRailButton")
				if object then position, model = nil, nil end
			end
			if not position and not object then
				for _, name in HUD_BUTTONS[target] or {} do
					object = control(playerGui, name)
					if object then break end
				end
			end
		end
	end
	if object and not uncovered(object) then object = nil end

	reducedMotion = UIFeel.ReducedMotion()
	focused = object
	local goalId = if goal then tostring(goal.Id) else ""
	watchPresses(object, goalId)

	if object then
		stopWorld()
		caption.Text = tostring(goal.Action or goal.Title)
		caption:SetAttribute("Title", nil)
		setDim(true, core and not released[goalId])
		if locked and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			local button: GuiButton? = if object:IsA("GuiButton") then object else object:FindFirstChildWhichIsA("GuiButton", true)
			if button and GuiService.SelectedObject ~= button then GuiService.SelectedObject = button end
		end
	elseif position and root and root:IsA("BasePart") then
		setDim(false, false)
		point, pointRoot = position, root
		caption.Text = tostring(goal.Title)
		caption:SetAttribute("Title", tostring(goal.Title))
		local near = model ~= nil and (position - root.Position).Magnitude <= 50
		highlight.Adornee = if near then model else nil
		highlight.Enabled = near
	else
		setDim(false, false)
		stopWorld()
		pointer.Visible = false
		-- The lesson's window is open but the next press is the player's choice: say what to do.
		caption.Visible = inWindow
		if inWindow then
			caption.Text = tostring(goal.Action or goal.Description)
			caption:SetAttribute("Title", nil)
			caption.Position = UDim2.new(0.5, 0, 0, 28)
		end
	end
	renderCue()
	if point or focused then
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
	if pressConnection then pressConnection:Disconnect() end
	highlight:Destroy()
	trailFolder:Destroy()
	dimGui:Destroy()
	gui:Destroy()
end)
