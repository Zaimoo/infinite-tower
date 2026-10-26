local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotesFolder = ReplicatedStorage:WaitForChild("PlaytimeRemotes", 10)
if not remotesFolder then
	return
end

local RF_GetOnlinePlayers = remotesFolder:WaitForChild("RF_GetOnlinePlayers") :: RemoteFunction
local RE_AddPlaytime      = remotesFolder:WaitForChild("RE_AddPlaytime") :: RemoteEvent
local RE_RequestRefresh   = remotesFolder:WaitForChild("RE_RequestRefresh") :: RemoteEvent
local RE_Notify           = remotesFolder:WaitForChild("RE_Notify") :: RemoteEvent

local gui = playerGui:WaitForChild("PanelPlaytimeLeaderBoardGui", 5)
if not gui then
	local starterPanel = StarterGui:FindFirstChild("PanelPlaytimeLeaderBoardGui")
	if starterPanel then
		gui = starterPanel:Clone()
		gui.Parent = playerGui
	else
		local repPanel = ReplicatedStorage:FindFirstChild("PanelPlaytimeLeaderBoardGui", true)
		if repPanel then
			gui = repPanel:Clone()
			gui.Parent = playerGui
		else
			return
		end
	end
end

local holderCanvas = gui:WaitForChild("HolderCanvas")
local holderFrame  = holderCanvas:WaitForChild("HolderFrame")

local header       = holderFrame:WaitForChild("Header")
local closeButton  = header:WaitForChild("CloseButtonFrame"):WaitForChild("CloseButton") :: GuiButton

local body = holderFrame:WaitForChild("Body")

local refreshFrame  = body:WaitForChild("RefreshLeaderboardFrame")
local refreshBtnPart = refreshFrame:FindFirstChild("Button")
local refreshButton: GuiButton? = nil
if refreshBtnPart then
	local framePart = refreshBtnPart:FindFirstChild("Frame")
	refreshButton = (framePart and framePart:FindFirstChild("RefreshLeaderboardButton") :: GuiButton?)
		or (refreshBtnPart:FindFirstChildWhichIsA("GuiButton", true))
		or (refreshFrame:FindFirstChildWhichIsA("GuiButton", true))
end

local playerlistFrame  = body:WaitForChild("PlayerlistFrame")
local playerListScroll = playerlistFrame:WaitForChild("PlayerListScrollingFrame") :: ScrollingFrame
local playerTemplate    = playerListScroll:WaitForChild("Template") :: Frame
playerTemplate.Visible = false

local addFrame = body:WaitForChild("AddPlaytimeFrame")
local inputJam   = addFrame:WaitForChild("Jam"):WaitForChild("Frame"):WaitForChild("InputAmountBoxJam") :: TextBox
local inputMenit = addFrame:WaitForChild("Menit"):WaitForChild("Frame"):WaitForChild("InputAmountBoxMenit") :: TextBox
local addButton  = addFrame:WaitForChild("Button"):WaitForChild("Frame"):WaitForChild("AddPlaytimeButton") :: GuiButton

local SELECTED_COLOR   = Color3.fromRGB(0, 170, 127)
local DESELECTED_COLOR = Color3.fromRGB(35, 35, 45)

local selectedUserId: number? = nil
local rowInstances: { [number]: Frame } = {}
local loadPlayerList: () -> ()

gui.Enabled = false

local function closePanel()
	gui.Enabled = false
end

local function openPanel()
	gui.Enabled = true
	loadPlayerList()
end

-- Check if TopbarPlus Icon module is available
local hasIconModule = ReplicatedStorage:FindFirstChild("Icon")
if hasIconModule then
	local ok, Icon = pcall(function()
		return require(hasIconModule)
	end)
	if ok and Icon and typeof(Icon) == "table" and Icon.new then
		local topbarIcon = Icon.new()
		topbarIcon:setImage("rbxassetid://96714408085433")
		topbarIcon.selected:Connect(openPanel)
		topbarIcon.deselected:Connect(closePanel)
	end
end

-- Keybind fallback: F8 toggles admin panel
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F8 then
		if gui.Enabled then
			closePanel()
		else
			openPanel()
		end
	end
end)

closeButton.MouseButton1Click:Connect(function()
	closePanel()
end)

local function clearSelection()
	selectedUserId = nil
	for _, row in pairs(rowInstances) do
		local canvas = row:FindFirstChild("Canvas")
		local selectBtn = canvas and canvas:FindFirstChild("SelectButton") :: GuiButton?
		if selectBtn then
			selectBtn.BackgroundColor3 = DESELECTED_COLOR
		end
	end
end

local function selectRow(userId: number)
	clearSelection()
	selectedUserId = userId
	local row = rowInstances[userId]
	if row then
		local canvas = row:FindFirstChild("Canvas")
		local selectBtn = canvas and canvas:FindFirstChild("SelectButton") :: GuiButton?
		if selectBtn then
			selectBtn.BackgroundColor3 = SELECTED_COLOR
		end
	end
end

loadPlayerList = function()
	for _, row in pairs(rowInstances) do
		row:Destroy()
	end
	table.clear(rowInstances)
	clearSelection()

	local list = RF_GetOnlinePlayers:InvokeServer()
	if typeof(list) ~= "table" then return end

	for _, info in ipairs(list) do
		local row = playerTemplate:Clone()
		row.Name    = "Row_" .. info.UserId
		row.Visible = true
		row.Parent  = playerListScroll

		local canvas    = row:FindFirstChild("Canvas")
		local selectBtn = canvas and canvas:FindFirstChild("SelectButton") :: GuiButton?
		if selectBtn then
			selectBtn.BackgroundColor3 = DESELECTED_COLOR
			local frame   = selectBtn:FindFirstChild("Frame")
			local nameLbl = frame and frame:FindFirstChild("DisplayNameLabel") :: TextLabel?
			local userLbl = frame and frame:FindFirstChild("UsernameLabel") :: TextLabel?
			if nameLbl then nameLbl.Text = info.DisplayName end
			if userLbl then userLbl.Text = "@" .. info.Name end

			selectBtn.MouseButton1Click:Connect(function()
				selectRow(info.UserId)
			end)
		end

		rowInstances[info.UserId] = row
	end
end

addButton.MouseButton1Click:Connect(function()
	if not selectedUserId then
		StarterGui:SetCore("SendNotification", {
			Title = "Pilih Player",
			Text = "Pilih salah satu player dari list dulu",
			Duration = 3,
		})
		return
	end

	local hours   = tonumber(inputJam.Text) or 0
	local minutes = tonumber(inputMenit.Text) or 0
	if hours <= 0 and minutes <= 0 then
		StarterGui:SetCore("SendNotification", {
			Title = "Input Kosong",
			Text = "Isi jumlah jam atau menit dulu",
			Duration = 3,
		})
		return
	end

	RE_AddPlaytime:FireServer(selectedUserId, hours, minutes)
	inputJam.Text   = ""
	inputMenit.Text = ""
end)

if refreshButton then
	refreshButton.MouseButton1Click:Connect(function()
		RE_RequestRefresh:FireServer()
	end)
end

RE_Notify.OnClientEvent:Connect(function(title: string, text: string, _success: boolean)
	StarterGui:SetCore("SendNotification", {
		Title = title,
		Text = text,
		Duration = 4,
	})
end)
