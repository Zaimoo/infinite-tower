--!strict
-- StarterPlayerScripts/UI/LeaderboardController.client.luau
-- 1:1 replica of the Roblox CoreGui PlayerList / "People" modal:
-- - Exact Roblox pixel measurements: 18px dismiss bar (9x9 X at 7,7), 20px TitleBar (no header divider), 40px rows
-- - Regular weight BuilderSans font throughout (no bold, exact TextSize 11 headers / 14 rows)
-- - Circular avatar headshot thumbnail next to each player name
-- - 1px subtle divider between player rows
-- - Smooth slide animation from the right

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 1. Disable default Roblox CoreGui player list with retries
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then break end
		task.wait(0.5)
	end
end)

-- 2. Number formatting helper
local function formatPower(val: number?): string
	local n = tonumber(val) or 0
	if n <= 0 then return "0" end
	if n >= 1e12 then
		local s = string.format("%.1fT", n / 1e12)
		return s:gsub("%.0T", "T")
	elseif n >= 1e9 then
		local s = string.format("%.1fB", n / 1e9)
		return s:gsub("%.0B", "B")
	elseif n >= 1e6 then
		local s = string.format("%.1fM", n / 1e6)
		return s:gsub("%.0M", "M")
	elseif n >= 1e3 then
		local s = string.format("%.1fK", n / 1e3)
		return s:gsub("%.0K", "K")
	else
		return tostring(math.floor(n))
	end
end

-- Regular weight font (never bold, matching Roblox default PlayerList)
local REGULAR_FONT: Enum.Font = (function(): Enum.Font
	local ok, f = pcall(function() return Enum.Font.BuilderSans end)
	return if ok then f else Enum.Font.Gotham
end)()

-- 3. ScreenGui Container
local oldGui = PlayerGui:FindFirstChild("CustomLeaderboardGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomLeaderboardGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

-- 4. Main Leaderboard Card (Exact Roblox PlayerList dimensions)
local CARD_WIDTH = 318
local DISMISS_BAR_HEIGHT = 18
local TITLE_BAR_HEIGHT = 20
local HEADER_TOTAL_HEIGHT = DISMISS_BAR_HEIGHT + TITLE_BAR_HEIGHT -- 38px
local ROW_HEIGHT = 41 -- 40px content + 1px bottom divider
local NAME_COL_WIDTH = 172
local STAT_COL_WIDTH = 66

local modal = Instance.new("Frame")
modal.Name = "LeaderboardModal"
modal.AnchorPoint = Vector2.new(1, 0)
modal.Size = UDim2.fromOffset(CARD_WIDTH, HEADER_TOTAL_HEIGHT + ROW_HEIGHT + 6)
modal.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
modal.BackgroundTransparency = 0.16
modal.BorderSizePixel = 0
modal.ClipsDescendants = true
modal.Parent = screenGui

local modalCorner = Instance.new("UICorner")
modalCorner.CornerRadius = UDim.new(0, 7)
modalCorner.Parent = modal

-- Dismiss Button (Small 9x9 X at offset 7,7 inside a 24x22 hit area)
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.fromOffset(24, 22)
closeBtn.Position = UDim2.fromOffset(0, 0)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = ""
closeBtn.AutoButtonColor = false
closeBtn.Parent = modal

local closeIcon = Instance.new("ImageLabel")
closeIcon.Name = "CloseIcon"
closeIcon.Size = UDim2.fromOffset(9, 9)
closeIcon.Position = UDim2.fromOffset(7, 7)
closeIcon.BackgroundTransparency = 1
closeIcon.Image = "rbxasset://textures/ui/InspectMenu/x.png"
closeIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
closeIcon.ImageTransparency = 0.08
closeIcon.Parent = closeBtn

closeBtn.MouseEnter:Connect(function()
	closeIcon.ImageTransparency = 0
end)
closeBtn.MouseLeave:Connect(function()
	closeIcon.ImageTransparency = 0.08
end)

-- TitleBar Row (People | Floor | Power directly below X at Y = 18, NO divider line below)
local header = Instance.new("Frame")
header.Name = "Header"
header.Position = UDim2.fromOffset(0, DISMISS_BAR_HEIGHT)
header.Size = UDim2.new(1, 0, 0, TITLE_BAR_HEIGHT)
header.BackgroundTransparency = 1
header.Parent = modal

-- Column: People
local peopleHeader = Instance.new("TextLabel")
peopleHeader.Name = "PeopleHeader"
peopleHeader.Position = UDim2.fromOffset(16, 0)
peopleHeader.Size = UDim2.new(0, NAME_COL_WIDTH - 16, 1, 0)
peopleHeader.BackgroundTransparency = 1
peopleHeader.Text = "People"
peopleHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
peopleHeader.TextTransparency = 0.3
peopleHeader.TextSize = 11
peopleHeader.Font = REGULAR_FONT
peopleHeader.TextXAlignment = Enum.TextXAlignment.Left
peopleHeader.TextYAlignment = Enum.TextYAlignment.Center
peopleHeader.Parent = header

-- Column: Floor
local floorHeader = Instance.new("TextLabel")
floorHeader.Name = "FloorHeader"
floorHeader.Position = UDim2.fromOffset(NAME_COL_WIDTH, 0)
floorHeader.Size = UDim2.new(0, STAT_COL_WIDTH, 1, 0)
floorHeader.BackgroundTransparency = 1
floorHeader.Text = "Floor"
floorHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
floorHeader.TextTransparency = 0.3
floorHeader.TextSize = 11
floorHeader.Font = REGULAR_FONT
floorHeader.TextXAlignment = Enum.TextXAlignment.Center
floorHeader.TextYAlignment = Enum.TextYAlignment.Center
floorHeader.Parent = header

-- Column: Power
local powerHeader = Instance.new("TextLabel")
powerHeader.Name = "PowerHeader"
powerHeader.Position = UDim2.fromOffset(NAME_COL_WIDTH + STAT_COL_WIDTH, 0)
powerHeader.Size = UDim2.new(0, STAT_COL_WIDTH, 1, 0)
powerHeader.BackgroundTransparency = 1
powerHeader.Text = "Power"
powerHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
powerHeader.TextTransparency = 0.3
powerHeader.TextSize = 11
powerHeader.Font = REGULAR_FONT
powerHeader.TextXAlignment = Enum.TextXAlignment.Center
powerHeader.TextYAlignment = Enum.TextYAlignment.Center
powerHeader.Parent = header

-- 5. Scrolling Player List (Starts at Y = 38, no line above first row)
local scrollList = Instance.new("ScrollingFrame")
scrollList.Name = "PlayerScrollList"
scrollList.Position = UDim2.fromOffset(0, HEADER_TOTAL_HEIGHT)
scrollList.Size = UDim2.new(1, -4, 1, -HEADER_TOTAL_HEIGHT - 4)
scrollList.BackgroundTransparency = 1
scrollList.BorderSizePixel = 0
scrollList.ScrollBarThickness = 6
scrollList.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
scrollList.ScrollBarImageTransparency = 0.65
scrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollList.Parent = modal

local listLayout = Instance.new("UIListLayout")
listLayout.Name = "ListLayout"
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 0)
listLayout.Parent = scrollList

-- Dynamic Height adjustment matching player count
local function updateModalHeight(playerCount: number)
	local count = math.max(1, playerCount)
	local targetH = math.clamp(HEADER_TOTAL_HEIGHT + count * ROW_HEIGHT + 6, 85, 360)
	modal.Size = UDim2.fromOffset(CARD_WIDTH, targetH)
end

-- 6. Player Tracking & Row Building
type PlayerRowData = {
	Frame: Frame,
	Player: Player,
	FloorLabel: TextLabel,
	PowerLabel: TextLabel,
	FloorValue: number,
	PowerValue: number,
	Connections: { [string]: RBXScriptConnection },
}

local playerRows: { [Player]: PlayerRowData } = {}

local function refreshSorting()
	local entries: { PlayerRowData } = {}
	for _, row in pairs(playerRows) do
		table.insert(entries, row)
	end

	table.sort(entries, function(a, b)
		if a.FloorValue ~= b.FloorValue then
			return a.FloorValue > b.FloorValue
		end
		if a.PowerValue ~= b.PowerValue then
			return a.PowerValue > b.PowerValue
		end
		return a.Player.Name < b.Player.Name
	end)

	for order, row in ipairs(entries) do
		row.Frame.LayoutOrder = order
	end

	updateModalHeight(#entries)
end

local function createPlayerRow(player: Player): PlayerRowData
	local row = Instance.new("Frame")
	row.Name = `Row_{player.UserId}`
	row.Size = UDim2.new(1, 4, 0, ROW_HEIGHT)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Parent = scrollList

	row.MouseEnter:Connect(function()
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.BackgroundTransparency = 0.94
	end)
	row.MouseLeave:Connect(function()
		row.BackgroundTransparency = 1
	end)

	-- Avatar Headshot Icon (22x22 circle aligned with the icon slot before the player name)
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.Size = UDim2.fromOffset(22, 22)
	avatar.Position = UDim2.new(0, 12, 0.5, -11)
	avatar.BackgroundTransparency = 1
	avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId)
	avatar.Parent = row

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatar

	-- Player Display Name Label (Regular weight, TextSize 14, starts at X = 41)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Position = UDim2.fromOffset(41, 0)
	nameLabel.Size = UDim2.new(0, NAME_COL_WIDTH - 45, 1, -1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextTransparency = 0.04
	nameLabel.TextSize = 14
	nameLabel.Font = REGULAR_FONT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = row

	-- Floor Stat Label (Regular weight, TextSize 14, Center-aligned in stat column 1)
	local floorLabel = Instance.new("TextLabel")
	floorLabel.Name = "FloorLabel"
	floorLabel.Position = UDim2.fromOffset(NAME_COL_WIDTH, 0)
	floorLabel.Size = UDim2.new(0, STAT_COL_WIDTH, 1, -1)
	floorLabel.BackgroundTransparency = 1
	floorLabel.Text = "0"
	floorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	floorLabel.TextTransparency = 0.04
	floorLabel.TextSize = 14
	floorLabel.Font = REGULAR_FONT
	floorLabel.TextXAlignment = Enum.TextXAlignment.Center
	floorLabel.TextYAlignment = Enum.TextYAlignment.Center
	floorLabel.Parent = row

	-- Power Stat Label (Regular weight, TextSize 14, Center-aligned in stat column 2)
	local powerLabel = Instance.new("TextLabel")
	powerLabel.Name = "PowerLabel"
	powerLabel.Position = UDim2.fromOffset(NAME_COL_WIDTH + STAT_COL_WIDTH, 0)
	powerLabel.Size = UDim2.new(0, STAT_COL_WIDTH, 1, -1)
	powerLabel.BackgroundTransparency = 1
	powerLabel.Text = "0"
	powerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	powerLabel.TextTransparency = 0.04
	powerLabel.TextSize = 14
	powerLabel.Font = REGULAR_FONT
	powerLabel.TextXAlignment = Enum.TextXAlignment.Center
	powerLabel.TextYAlignment = Enum.TextYAlignment.Center
	powerLabel.Parent = row

	-- 1px Horizontal Divider at the bottom of the row
	local rowDivider = Instance.new("Frame")
	rowDivider.Name = "RowDivider"
	rowDivider.Position = UDim2.new(0, 0, 1, -1)
	rowDivider.Size = UDim2.new(1, 0, 0, 1)
	rowDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	rowDivider.BackgroundTransparency = 0.88
	rowDivider.BorderSizePixel = 0
	rowDivider.Parent = row

	local rowData: PlayerRowData = {
		Frame = row,
		Player = player,
		FloorLabel = floorLabel,
		PowerLabel = powerLabel,
		FloorValue = 0,
		PowerValue = 0,
		Connections = {},
	}

	-- Listen for leaderstats changes
	local function bindLeaderstats(leaderstats: Folder)
		local floorVal = leaderstats:FindFirstChild("Floor") :: IntValue?
		local powerVal = leaderstats:FindFirstChild("Power") :: NumberValue?

		local function onFloorChanged()
			local f = floorVal and floorVal.Value or 0
			rowData.FloorValue = f
			rowData.FloorLabel.Text = tostring(f)
			refreshSorting()
		end

		local function onPowerChanged()
			local p = powerVal and powerVal.Value or 0
			rowData.PowerValue = p
			rowData.PowerLabel.Text = formatPower(p)
			refreshSorting()
		end

		if floorVal then
			onFloorChanged()
			rowData.Connections["FloorChanged"] = floorVal.Changed:Connect(onFloorChanged)
		else
			rowData.Connections["FloorAdded"] = leaderstats.ChildAdded:Connect(function(child)
				if child.Name == "Floor" and child:IsA("IntValue") then
					floorVal = child :: IntValue
					onFloorChanged()
					rowData.Connections["FloorChanged"] = floorVal.Changed:Connect(onFloorChanged)
				end
			end)
		end

		if powerVal then
			onPowerChanged()
			rowData.Connections["PowerChanged"] = powerVal.Changed:Connect(onPowerChanged)
		else
			rowData.Connections["PowerAdded"] = leaderstats.ChildAdded:Connect(function(child)
				if child.Name == "Power" and child:IsA("NumberValue") then
					powerVal = child :: NumberValue
					onPowerChanged()
					rowData.Connections["PowerChanged"] = powerVal.Changed:Connect(onPowerChanged)
				end
			end)
		end
	end

	local leaderstats = player:FindFirstChild("leaderstats") :: Folder?
	if leaderstats then
		bindLeaderstats(leaderstats)
	else
		rowData.Connections["LeaderstatsAdded"] = player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" and child:IsA("Folder") then
				bindLeaderstats(child :: Folder)
			end
		end)
	end

	return rowData
end

local function addPlayer(player: Player)
	if playerRows[player] then return end
	local rowData = createPlayerRow(player)
	playerRows[player] = rowData
	refreshSorting()
end

local function removePlayer(player: Player)
	local rowData = playerRows[player]
	if not rowData then return end
	for _, conn in pairs(rowData.Connections) do
		conn:Disconnect()
	end
	rowData.Frame:Destroy()
	playerRows[player] = nil
	refreshSorting()
end

for _, p in ipairs(Players:GetPlayers()) do
	addPlayer(p)
end

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)

-- 7. Smooth Slide Animation from the right (matching Roblox PlayerListApp motor)
local isOpen = true
local currentTween: Tween? = nil

local function getTargetPositions(): (UDim2, UDim2)
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
	if vp.X < 500 then
		local openPos = UDim2.new(0.5, 0, 0, 10)
		local closedPos = UDim2.new(1, CARD_WIDTH + 40, 0, 10)
		return openPos, closedPos
	else
		local openPos = UDim2.new(1, -74, 0, 10)
		local closedPos = UDim2.new(1, CARD_WIDTH + 40, 0, 10)
		return openPos, closedPos
	end
end

local openPos, closedPos = getTargetPositions()
modal.Position = openPos
modal.Visible = true

local function setVisibility(visible: boolean)
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end

	isOpen = visible
	local currentOpenPos, currentClosedPos = getTargetPositions()

	if visible then
		modal.Visible = true
		currentTween = TweenService:Create(
			modal,
			TweenInfo.new(0.26, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
			{ Position = currentOpenPos }
		)
		currentTween:Play()
	else
		currentTween = TweenService:Create(
			modal,
			TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = currentClosedPos }
		)
		currentTween.Completed:Connect(function(playbackState)
			if playbackState == Enum.PlaybackState.Completed and not isOpen then
				modal.Visible = false
			end
		end)
		currentTween:Play()
	end
end

closeBtn.Activated:Connect(function()
	setVisibility(false)
end)

-- Keyboard Tab keybind (standard Roblox PC playerlist toggle)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Tab and not gameProcessed then
		setVisibility(not isOpen)
	end
end)

-- Responsive positioning adjustments
local function updateLayoutForScreen()
	local currentOpenPos, currentClosedPos = getTargetPositions()
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
	if vp.X < 500 then
		modal.AnchorPoint = Vector2.new(0.5, 0)
	else
		modal.AnchorPoint = Vector2.new(1, 0)
	end

	if isOpen then
		modal.Position = currentOpenPos
	else
		modal.Position = currentClosedPos
	end
end

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayoutForScreen)
end

-- On small mobile screens, start closed
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	if vp and vp.X < 700 then
		modal.Position = closedPos
		modal.Visible = false
		isOpen = false
	end
end

-- Mount Gui
screenGui.Parent = PlayerGui

-- Clean up when script is destroyed
script.Destroying:Connect(function()
	if currentTween then currentTween:Cancel() end
	for _, row in pairs(playerRows) do
		for _, conn in pairs(row.Connections) do
			conn:Disconnect()
		end
	end
	if screenGui then screenGui:Destroy() end
end)
