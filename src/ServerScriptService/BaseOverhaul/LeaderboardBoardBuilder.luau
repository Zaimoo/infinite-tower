--!strict
-- LeaderboardBoardBuilder.luau
-- ModuleScript: builds a world leaderboard (Top Playtime or Top Power) entirely in code, so the hub never
-- depends on a hand-placed model. The result matches what the board renderers and stand builders expect:
--   AvxsedPlaytimeWS / AvxsedPowerWS (Folder)
--     Build (Model)              frame posts, header beam, plinths and lanterns
--     ScreenPlaytime / ScreenPower (Part) .SurfaceGui.Holder
--       Header.LabelFrame.HeaderLabel
--       Body.ScrollingFrame.TemplateCardFrame (AvatarIconFrame.AvatarIcon, InfoLabel.DisplayNameLabel,
--         InfoLabel.UsernameLabel, TotalPlaytimeLabelFrame.TotalPlaytimeLabel or TotalPowerLabelFrame.TotalPowerLabel)
--       Footer.LabelFrame.UpdateLabel
--     Rigstand (Folder)           Top 1 / Top 2 / Top 3 panels the stand builders draw the top three onto
-- Built at its base size around the origin with the screen facing -Z; SharedLeaderboards seats and scales it.

local PartKit = require(script.Parent:WaitForChild("PartKit"))

local LeaderboardBoardBuilder = {}

local OBSIDIAN = Color3.fromRGB(26, 22, 26)
local STONE = Color3.fromRGB(58, 52, 56)
local GOLD = Color3.fromRGB(214, 176, 92)
local CREAM = Color3.fromRGB(240, 230, 210)
local LANTERN = Color3.fromRGB(255, 205, 140)
local PANEL = Color3.fromRGB(16, 14, 18)

local SCREEN_SIZE = Vector3.new(9.4, 12.4, 0.5)
local SCREEN_Y = 8
local TOP_SIZE = Vector3.new(6.6, 9.7, 0.2)
local PPS = 50 -- SurfaceGui pixels per stud at base size

type Kind = "Playtime" | "Power"

local function new(className: string, props: { [string]: any }): Instance
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function label(name: string, parent: Instance, text: string, size: UDim2, pos: UDim2, color: Color3, font: Enum.Font, align: Enum.TextXAlignment?): TextLabel
	return new("TextLabel", {
		Name = name,
		Size = size,
		Position = pos,
		BackgroundTransparency = 1,
		Text = text,
		TextScaled = true,
		Font = font,
		TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Center,
		Parent = parent,
	}) :: TextLabel
end

local function buildScreenGui(screen: BasePart, kind: Kind)
	local gui = new("SurfaceGui", { Name = "SurfaceGui", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = PPS, LightInfluence = 0, Parent = screen })
	local holder = new("Frame", { Name = "Holder", Size = UDim2.fromScale(1, 1), BackgroundColor3 = PANEL, BorderSizePixel = 0, Parent = gui })
	new("UIStroke", { Color = GOLD, Thickness = 6, Transparency = 0.15, Parent = holder })

	local header = new("Frame", { Name = "Header", Size = UDim2.fromScale(1, 0.12), BackgroundColor3 = Color3.fromRGB(60, 18, 24), BorderSizePixel = 0, Parent = holder })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(120, 30, 40), Color3.fromRGB(50, 12, 18)), Rotation = 90, Parent = header })
	local headerFrame = new("Frame", { Name = "LabelFrame", Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.05, 0.1), BackgroundTransparency = 1, Parent = header })
	label("HeaderLabel", headerFrame, if kind == "Power" then "TOP POWER" else "TOP PLAYTIME", UDim2.fromScale(1, 1), UDim2.new(), GOLD, Enum.Font.Fondamento)

	local body = new("Frame", { Name = "Body", Size = UDim2.fromScale(1, 0.78), Position = UDim2.fromScale(0, 0.12), BackgroundTransparency = 1, Parent = holder })
	local scroll = new("ScrollingFrame", {
		Name = "ScrollingFrame",
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.fromOffset(8, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = GOLD,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	})
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = scroll })

	-- One row per player; the renderer clones this, fills it and sets LayoutOrder
	local card = new("Frame", { Name = "TemplateCardFrame", Size = UDim2.new(1, -10, 0, 56), BackgroundColor3 = Color3.fromRGB(34, 28, 32), BorderSizePixel = 0, Visible = false, Parent = scroll })
	new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = card })
	new("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.6, Parent = card })
	local avatarFrame = new("Frame", { Name = "AvatarIconFrame", Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(6, 5), BackgroundColor3 = OBSIDIAN, BorderSizePixel = 0, Parent = card })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avatarFrame })
	local avatar = new("ImageLabel", { Name = "AvatarIcon", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = avatarFrame })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = avatar })
	local info = new("Frame", { Name = "InfoLabel", Size = UDim2.new(0.55, -60, 1, -10), Position = UDim2.fromOffset(60, 5), BackgroundTransparency = 1, Parent = card })
	label("DisplayNameLabel", info, "Player", UDim2.fromScale(1, 0.58), UDim2.new(), CREAM, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
	label("UsernameLabel", info, "@player", UDim2.fromScale(1, 0.38), UDim2.fromScale(0, 0.6), Color3.fromRGB(170, 160, 150), Enum.Font.Gotham, Enum.TextXAlignment.Left)
	local valueName = if kind == "Power" then "TotalPowerLabel" else "TotalPlaytimeLabel"
	local valueFrame = new("Frame", { Name = valueName .. "Frame", Size = UDim2.new(0.42, -8, 0.6, 0), Position = UDim2.fromScale(0.56, 0.2), BackgroundTransparency = 1, Parent = card })
	label(valueName, valueFrame, "0", UDim2.fromScale(1, 1), UDim2.new(), GOLD, Enum.Font.GothamBold, Enum.TextXAlignment.Right)

	local footer = new("Frame", { Name = "Footer", Size = UDim2.fromScale(1, 0.1), Position = UDim2.fromScale(0, 0.9), BackgroundColor3 = Color3.fromRGB(28, 22, 26), BorderSizePixel = 0, Parent = holder })
	local footerFrame = new("Frame", { Name = "LabelFrame", Size = UDim2.fromScale(0.92, 0.7), Position = UDim2.fromScale(0.04, 0.15), BackgroundTransparency = 1, Parent = footer })
	label("UpdateLabel", footerFrame, "Updating…", UDim2.fromScale(1, 1), UDim2.new(), Color3.fromRGB(180, 170, 160), Enum.Font.Gotham)
end

-- Frame posts, header beam and lantern pair around a panel of `size` centred at `cf`.
local function framePanel(parent: Instance, cf: CFrame, size: Vector3, crest: boolean)
	local w, h = size.X, size.Y
	for _, side in { -1, 1 } do
		PartKit.Part({ Name = "Post", Size = Vector3.new(0.7, h + 2, 0.9), CFrame = cf * CFrame.new(side * (w * 0.5 + 0.35), 0, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = parent })
	end
	PartKit.Part({ Name = "Beam", Size = Vector3.new(w + 2.2, 0.9, 1.1), CFrame = cf * CFrame.new(0, h * 0.5 + 0.65, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = parent })
	PartKit.Part({ Name = "BeamTrim", Size = Vector3.new(w + 2.4, 0.2, 1.2), CFrame = cf * CFrame.new(0, h * 0.5 + 0.15, 0), Color = GOLD, Material = Enum.Material.Metal, Decorative = true, Parent = parent })
	PartKit.Part({ Name = "Sill", Size = Vector3.new(w + 1.6, 0.5, 1), CFrame = cf * CFrame.new(0, -h * 0.5 - 0.27, 0), Color = STONE, Material = Enum.Material.Slate, Decorative = true, Parent = parent })
	if crest then
		local gem = PartKit.Part({ Name = "CrestGem", Size = Vector3.new(1.2, 1.2, 0.4), CFrame = cf * CFrame.new(0, h * 0.5 + 1.6, -0.1) * CFrame.Angles(0, 0, math.rad(45)), Color = GOLD, Material = Enum.Material.Neon, Decorative = true, Parent = parent })
		new("PointLight", { Color = LANTERN, Range = 12, Brightness = 1.2, Shadows = false, Parent = gem })
	end
end

function LeaderboardBoardBuilder.Build(kind: Kind): Folder
	local board = Instance.new("Folder")
	board.Name = if kind == "Power" then "AvxsedPowerWS" else "AvxsedPlaytimeWS"
	local build = Instance.new("Model")
	build.Name = "Build"
	build.Parent = board

	-- Main screen with its frame, on a stepped plinth
	local screenCF = CFrame.new(0, SCREEN_Y, 0)
	local screen = PartKit.Part({ Name = if kind == "Power" then "ScreenPower" else "ScreenPlaytime", Size = SCREEN_SIZE, CFrame = screenCF, Color = PANEL, Material = Enum.Material.Glass, Parent = board })
	screen.CanCollide = false
	buildScreenGui(screen, kind)
	framePanel(build, screenCF, SCREEN_SIZE, true)
	PartKit.Part({ Name = "Plinth", Size = Vector3.new(SCREEN_SIZE.X + 2.4, 1, 2.4), CFrame = CFrame.new(0, 0.5, 0), Color = STONE, Material = Enum.Material.Slate, Parent = build })
	PartKit.Part({ Name = "PlinthStep", Size = Vector3.new(SCREEN_SIZE.X + 1, 0.8, 1.6), CFrame = CFrame.new(0, 1.4, 0), Color = OBSIDIAN, Material = Enum.Material.Basalt, Decorative = true, Parent = build })

	-- Podium of the top three: 1st tallest, in the middle of the three
	local rig = Instance.new("Folder")
	rig.Name = "Rigstand"
	rig.Parent = board
	for rank, slot in { { X = 16.5, Lift = 1.2 }, { X = 9.0, Lift = 0 }, { X = 24.0, Lift = 0 } } do
		local y = SCREEN_Y - 0.6 + slot.Lift
		local cf = CFrame.new(slot.X, y, 0)
		local top = PartKit.Part({ Name = "Top " .. rank, Size = TOP_SIZE, CFrame = cf, Color = PANEL, Material = Enum.Material.SmoothPlastic, Parent = rig })
		top.CanCollide = false
		local rankFrame = Instance.new("Model")
		rankFrame.Name = "Build" .. rank
		rankFrame.Parent = rig
		framePanel(rankFrame, cf, TOP_SIZE, rank == 1)
		local base = y - TOP_SIZE.Y * 0.5 - 0.5
		PartKit.Part({ Name = "Pedestal", Size = Vector3.new(TOP_SIZE.X + 1.4, base, 2), CFrame = CFrame.new(slot.X, base * 0.5, 0), Color = STONE, Material = Enum.Material.Slate, Parent = rankFrame })
	end
	return board
end

return LeaderboardBoardBuilder
