local TweenService = game:GetService("TweenService")
local Workspace    = game:GetService("Workspace")

local Config = require(script.Parent:WaitForChild("PlaytimeConfig"))
local Utils  = require(script.Parent:WaitForChild("PlaytimeUtils"))

local StandBuilder = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local BG    = Color3.fromRGB(8, 8, 8)

local STAND_STYLES = {
	[1] = { borderColor = Color3.fromRGB(50, 180, 255),  borderThick = 5 },
	[2] = { borderColor = Color3.fromRGB(160, 160, 175), borderThick = 4 },
	[3] = { borderColor = Color3.fromRGB(160, 100, 50),  borderThick = 4 },
}
local NAME_GRADIENTS = {
	[1] = { top = Color3.fromRGB(100, 220, 255), bottom = Color3.fromRGB(20, 120, 200) },
	[2] = { top = Color3.fromRGB(230, 230, 240), bottom = Color3.fromRGB(140, 140, 155) },
	[3] = { top = Color3.fromRGB(220, 150, 80),  bottom = Color3.fromRGB(130, 75, 25)  },
}
local RANK_TEXT = { "1ST PLACE", "2ND PLACE", "3RD PLACE" }
local RANK_SIZE = { 216, 174, 174 }

local function clearStand(part: BasePart)
	local old = part:FindFirstChild("PlaytimeDisplay")
	if old then old:Destroy() end
end

local function buildEmptyStand(part: BasePart, rank: number)
	local st = STAND_STYLES[rank] or STAND_STYLES[3]
	clearStand(part)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "PlaytimeDisplay"
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 150
	gui.LightInfluence = 0
	gui.ZOffset = 1
	gui.Parent = part

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = BG
	root.BorderSizePixel = 0
	root.Parent = gui

	local border = Instance.new("UIStroke")
	border.Thickness = st.borderThick
	border.Color = st.borderColor
	border.Transparency = 0.5
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = ({ "1ST", "2ND", "3RD" })[rank] .. "\n\nNo data yet"
	lbl.TextSize = 20
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = WHITE
	lbl.TextTransparency = 0.5
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.Parent = root
end

local function buildStandDisplay(part: BasePart, rank: number, userId: number, username: string, seconds: number)
	local st = STAND_STYLES[rank] or STAND_STYLES[3]
	clearStand(part)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "PlaytimeDisplay"
	gui.Adornee = part
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 150
	gui.LightInfluence = 0
	gui.ZOffset = 1
	gui.Parent = part

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = BG
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = gui

	local border = Instance.new("UIStroke")
	border.Thickness = st.borderThick
	border.Color = st.borderColor
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = root

	local avatar = Instance.new("ImageLabel")
	avatar.AnchorPoint = Vector2.new(0.5, 0)
	avatar.Position = UDim2.new(0.5, 0, 0, 0)
	avatar.Size = UDim2.new(1, 0, 0.6, 0)
	avatar.BackgroundTransparency = 1
	avatar.Image = Utils.getAvatarThumb(userId, "Avatar", 420, 420)
	avatar.ScaleType = Enum.ScaleType.Fit
	avatar.Parent = root

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(1, 0, 0.4, 0)
	panel.Position = UDim2.new(0, 0, 0.6, 0)
	panel.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	panel.BorderSizePixel = 0
	panel.BackgroundTransparency = 1
	panel.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = panel

	local rankLbl = Instance.new("TextLabel")
	rankLbl.Size = UDim2.new(1, 0, 0, RANK_SIZE[rank] or 174)
	rankLbl.BackgroundTransparency = 1
	rankLbl.Text = RANK_TEXT[rank] or (rank .. "TH")
	rankLbl.TextSize = RANK_SIZE[rank] or 174
	rankLbl.Font = Enum.Font.GothamBlack
	rankLbl.TextColor3 = WHITE
	rankLbl.TextXAlignment = Enum.TextXAlignment.Center
	rankLbl.LayoutOrder = 1
	rankLbl.Parent = panel
	Instance.new("UIStroke", rankLbl).Color = Color3.new(0, 0, 0)

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0, rank == 1 and 144 or 114)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = "@" .. username
	nameLbl.TextSize = rank == 1 and 144 or 114
	nameLbl.Font = Enum.Font.GothamBlack
	nameLbl.TextColor3 = NAME_GRADIENTS[rank] and NAME_GRADIENTS[rank].top or WHITE
	nameLbl.TextXAlignment = Enum.TextXAlignment.Center
	nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	nameLbl.LayoutOrder = 2
	nameLbl.Parent = panel

	if NAME_GRADIENTS[rank] then
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, NAME_GRADIENTS[rank].top),
			ColorSequenceKeypoint.new(1, NAME_GRADIENTS[rank].bottom),
		})
		grad.Rotation = 90
		grad.Parent = nameLbl
	end

	local timeLbl = Instance.new("TextLabel")
	timeLbl.Size = UDim2.new(1, 0, 0, rank == 1 and 114 or 90)
	timeLbl.BackgroundTransparency = 1
	timeLbl.Text = Utils.formatHM(seconds)
	timeLbl.TextSize = rank == 1 and 114 or 90
	timeLbl.Font = Enum.Font.GothamBold
	timeLbl.TextColor3 = st.borderColor
	timeLbl.TextXAlignment = Enum.TextXAlignment.Center
	timeLbl.LayoutOrder = 3
	timeLbl.Parent = panel
	Instance.new("UIStroke", timeLbl).Color = Color3.new(0, 0, 0)

	-- Pulse border buat rank 1
	if rank == 1 then
		task.spawn(function()
			while border and border.Parent do
				local t1 = TweenService:Create(border, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.6 })
				t1:Play()
				task.wait(1.2)
				if not (border and border.Parent) then break end
				local t2 = TweenService:Create(border, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0 })
				t2:Play()
				task.wait(1.2)
			end
		end)
	end
end

local function getAllRigstandFolders(): { Folder }
	local folders = {}
	local plots = Workspace:FindFirstChild("WaitingRoomPlots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local pstand = plot:FindFirstChild("AvxsedPlaytimeWS")
			local rig = pstand and pstand:FindFirstChild("Rigstand")
			if rig and rig:IsA("Folder") then
				table.insert(folders, rig)
			end
		end
	end
	if #folders == 0 then
		local fallback = Utils.resolvePath(Config.Paths.RigstandFolder, Workspace, 2)
		if fallback and fallback:IsA("Folder") then
			table.insert(folders, fallback)
		end
	end
	return folders
end

function StandBuilder.Update(top: { { UserId: number, Seconds: number } })
	local folders = getAllRigstandFolders()
	for _, folder in ipairs(folders) do
		for rank = 1, Config.MAX_STAND_RANKS do
			local part = folder:FindFirstChild("Top " .. rank)
			if not part or not part:IsA("BasePart") then continue end

			local entry = top[rank]
			if entry then
				local uname = Utils.getUsernamePair(entry.UserId)
				buildStandDisplay(part, rank, entry.UserId, uname, entry.Seconds)
			else
				buildEmptyStand(part, rank)
			end
		end
	end
end

return StandBuilder
