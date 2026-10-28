--!strict
-- StarterPlayerScripts/UI/TowerController.client.luau
-- Authoritative Infinite Tower Travel & Hub Floor Selector Modal.
-- Designed to match the 50-Floor 10-Biome Gothic Modal specification.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Http = game:GetService("HttpService")

local player = Players.LocalPlayer
local floors = require(RS.Shared.Config.TowerFloorConfig)
local mobs = require(RS.Shared.Config.MobCatalog)
local GothicBoxStyle = require(RS.Shared.Util.GothicBoxStyle)
local GildedGrimoire = require(RS.Shared.Util.GildedGrimoire)
local GrimoireIcons = require(RS.Shared.Util.GrimoireIcons)
local remotes = RS:WaitForChild("Remotes"):WaitForChild("TowerRemotes")

local selfState: any = nil
local context: any = nil
local pending: any = nil
local pendingActionName: string? = nil
local lastFeedback: string? = nil
local selected = 1
local activeBiomeIndex = 1
local presence: any = nil
local lastSelectorOpenTime = 0
local render: () -> ()

-- Visual Palette
local C = {
	ObsidianDark = Color3.fromRGB(15, 12, 24),
	ObsidianMid = Color3.fromRGB(22, 18, 34),
	ObsidianSheen = Color3.fromRGB(36, 28, 52),
	BorderNormal = Color3.fromRGB(65, 54, 82),
	BorderSelected = Color3.fromRGB(255, 214, 110),
	BorderVisiting = Color3.fromRGB(74, 222, 128),
	BorderSquad = Color3.fromRGB(56, 189, 248),
	TextWhite = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(165, 155, 185),
	TextDim = Color3.fromRGB(115, 105, 135),
	GreenAccent = Color3.fromRGB(74, 222, 128),
	GoldAccent = Color3.fromRGB(250, 204, 21),
}

-- Biome Environmental Atmospheric Color Themes
local BIOME_PALETTES = {
	[1] = { Top = Color3.fromRGB(38, 70, 50), Bot = Color3.fromRGB(16, 28, 22), Accent = Color3.fromRGB(60, 115, 82) },    -- Verdant Ruins
	[2] = { Top = Color3.fromRGB(58, 36, 78), Bot = Color3.fromRGB(22, 16, 36), Accent = Color3.fromRGB(85, 55, 120) },   -- Fungal Hollow
	[3] = { Top = Color3.fromRGB(78, 54, 34), Bot = Color3.fromRGB(30, 20, 14), Accent = Color3.fromRGB(120, 85, 52) },  -- Ashen Dunes
	[4] = { Top = Color3.fromRGB(32, 64, 92), Bot = Color3.fromRGB(16, 30, 44), Accent = Color3.fromRGB(56, 110, 155) },  -- Frozen Citadel
	[5] = { Top = Color3.fromRGB(84, 32, 32), Bot = Color3.fromRGB(32, 14, 14), Accent = Color3.fromRGB(135, 48, 48) },   -- Infernal Foundry
	[6] = { Top = Color3.fromRGB(52, 32, 88), Bot = Color3.fromRGB(22, 14, 40), Accent = Color3.fromRGB(92, 54, 142) },   -- Thunder Highlands
	[7] = { Top = Color3.fromRGB(68, 28, 74), Bot = Color3.fromRGB(28, 12, 32), Accent = Color3.fromRGB(110, 42, 120) },  -- Corrupted Grove
	[8] = { Top = Color3.fromRGB(24, 62, 82), Bot = Color3.fromRGB(12, 26, 36), Accent = Color3.fromRGB(42, 98, 128) },   -- Sunken Sanctuary
	[9] = { Top = Color3.fromRGB(58, 40, 94), Bot = Color3.fromRGB(24, 16, 42), Accent = Color3.fromRGB(105, 68, 160) },  -- Astral Archives
	[10] = { Top = Color3.fromRGB(78, 22, 38), Bot = Color3.fromRGB(30, 10, 16), Accent = Color3.fromRGB(130, 35, 62) },   -- Abyssal Throne
}

local function new<T>(className: string, props: { [string]: any }, parent: Instance?): T
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst :: any
end

-- ScreenGui Setup
local gui = new("ScreenGui", {
	Name = "TowerTravel",
	ResetOnSpawn = false,
	DisplayOrder = 40,
}, player:WaitForChild("PlayerGui"))

-- Dim Scrim Backdrop
local scrim = new("TextButton", {
	Name = "TowerScrim",
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.fromRGB(6, 4, 10),
	BackgroundTransparency = 0.45,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 38,
}, gui)

-- Main Modal Window Container
local panel = new("Frame", {
	Name = "FloorSelector",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(830, 560),
	BackgroundColor3 = C.ObsidianDark,
	Active = true,
	Visible = false,
	ZIndex = 40,
}, gui)
GothicBoxStyle.Apply(panel, { Style = "Window" })

-- Gilded Grimoire: every label in the selector uses the theme fonts.
GildedGrimoire.Watch(panel)

local scale = new("UIScale", { Scale = 1.0 }, panel)

local function fit()
	local camera = workspace.CurrentCamera
	if camera then
		local vp = camera.ViewportSize
		local targetW, targetH = 830, 560
		local scaleX = (vp.X - 24) / targetW
		local scaleY = (vp.Y - 24) / targetH
		local finalScale = math.clamp(math.min(scaleX, scaleY), 0.48, 1.0)
		scale.Scale = finalScale
	end
end
fit()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fit)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

local function closeSelector()
	panel.Visible = false
	scrim.Visible = false
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end
end
GothicBoxStyle.CreateCloseButton(panel, closeSelector)

scrim.Activated:Connect(function()
	if os.clock() - lastSelectorOpenTime < 0.25 then return end
	panel.Visible = false
	scrim.Visible = false
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end
end)

-- Title & Subtitle Header
local titleIcon = GrimoireIcons.Create("Tower", 46, panel, 42)
titleIcon.Position = UDim2.fromOffset(20, 12)
local titleLabel = new("TextLabel", {
	Name = "Title",
	Position = UDim2.fromOffset(74, 14),
	Size = UDim2.fromOffset(560, 30),
	BackgroundTransparency = 1,
	Text = "INFINITE TOWER · 50 FLOORS",
	TextColor3 = C.TextWhite,
	Font = Enum.Font.GothamBlack,
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 42,
}, panel)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), GildedGrimoire.Text.Gold) }, titleLabel)

local subtitleLabel = new("TextLabel", {
	Name = "Subtitle",
	Position = UDim2.fromOffset(74, 44),
	Size = UDim2.fromOffset(500, 18),
	BackgroundTransparency = 1,
	Text = "10 Biomes · Select any floor to visit or station your squad",
	TextColor3 = C.TextMuted,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 42,
}, panel)

-- Body Layout Area (Left Column = Biome List, Right Column = Floors & Telemetry)
local body = new("Frame", {
	Name = "Body",
	Position = UDim2.fromOffset(26, 72),
	Size = UDim2.new(1, -52, 1, -90),
	BackgroundTransparency = 1,
	ZIndex = 41,
}, panel)

-- ============================================================================
-- LEFT COLUMN: 10 BIOME CARDS SCROLLING FRAME
-- ============================================================================
local biomeScroll = new("ScrollingFrame", {
	Name = "BiomeScroll",
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.new(0.36, -14, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
	CanvasSize = UDim2.new(0, 0, 0, 10 * 100 + 8),
	ZIndex = 42,
}, body)

-- Subtle Vertical Divider between Left & Right Columns
local columnDivider = new("Frame", {
	Name = "ColumnDivider",
	Position = UDim2.new(0.36, 0, 0, 6),
	Size = UDim2.new(0, 2, 1, -12),
	BackgroundColor3 = Color3.fromRGB(55, 45, 72),
	BorderSizePixel = 0,
	ZIndex = 42,
}, body)
new("UICorner", { CornerRadius = UDim.new(0, 1) }, columnDivider)

local biomeListLayout = new("UIListLayout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, biomeScroll)

local biomeCards: { [number]: { Root: Frame, Stroke: UIStroke, Label: TextLabel, PillStroke: UIStroke } } = {}

-- ============================================================================
-- RIGHT COLUMN: ACTIVE BIOME FLOOR SELECTION & TELEMETRY
-- ============================================================================
local rightPane = new("Frame", {
	Name = "RightPane",
	Position = UDim2.new(0.36, 14, 0, 0),
	Size = UDim2.new(0.64, -14, 1, 0),
	BackgroundTransparency = 1,
	ZIndex = 42,
}, body)

-- 1. Floor Button Row (Top)
local floorRow = new("Frame", {
	Name = "FloorRow",
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.new(1, 0, 0, 68),
	BackgroundTransparency = 1,
	ZIndex = 43,
}, rightPane)

local floorRowLayout = new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, floorRow)

local activeFloorButtons: { [number]: { Root: TextButton, Stroke: UIStroke, Corners: { Frame }, Number: TextLabel, Tag: TextLabel, Lock: Frame, FloorId: number } } = {}

-- 2. Floor Details Card (Middle)
local detailsCard = new("Frame", {
	Name = "FloorDetailsCard",
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.new(1, 0, 0, 176),
	BorderSizePixel = 0,
	ZIndex = 43,
}, rightPane)
GildedGrimoire.Frame(detailsCard, { Class = "Panel", Tone = "Deep", ZIndex = 44 })

-- Details Content Labels
local detailHeader = new("TextLabel", {
	Name = "DetailHeader",
	Position = UDim2.fromOffset(18, 16),
	Size = UDim2.new(1, -36, 0, 22),
	BackgroundTransparency = 1,
	Text = "Floor 1 · Overgrown Threshold (Verdant Ruins)",
	TextColor3 = GildedGrimoire.Text.Gold,
	Font = Enum.Font.GothamBlack,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	ZIndex = 45,
}, detailsCard)

local detailScaling = new("TextLabel", {
	Name = "DetailScaling",
	Position = UDim2.fromOffset(18, 48),
	Size = UDim2.new(1, -36, 0, 20),
	BackgroundTransparency = 1,
	RichText = true,
	Text = "Recommended Power: 700",
	TextColor3 = Color3.fromRGB(240, 235, 248),
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 45,
}, detailsCard)

local detailRoster = new("TextLabel", {
	Name = "DetailRoster",
	Position = UDim2.fromOffset(18, 80),
	Size = UDim2.new(1, -36, 0, 40),
	BackgroundTransparency = 1,
	RichText = true,
	Text = "Roster: Moss Crawler ×5, Ruin Guardian ×5, Vinebound Elite ×1",
	TextColor3 = Color3.fromRGB(220, 212, 235),
	Font = Enum.Font.Gotham,
	TextSize = 14,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 45,
}, detailsCard)

local detailVisitors = new("TextLabel", {
	Name = "DetailVisitors",
	Position = UDim2.fromOffset(18, 130),
	Size = UDim2.new(1, -36, 0, 20),
	BackgroundTransparency = 1,
	Text = "Visitors: 0 · Stationed Squads: none",
	TextColor3 = Color3.fromRGB(150, 140, 168),
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 45,
}, detailsCard)

-- 3. Action Buttons Row (Bottom)
local actionRow = new("Frame", {
	Name = "ActionRow",
	Position = UDim2.fromOffset(0, 274),
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundTransparency = 1,
	ZIndex = 43,
}, rightPane)

local actionLayout = new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, actionRow)

-- 4. Status Footer
local statusFooter = new("TextLabel", {
	Name = "StatusFooter",
	Position = UDim2.fromOffset(2, 332),
	Size = UDim2.new(1, -4, 0, 40),
	BackgroundTransparency = 1,
	Text = "You: Hub · Squad: Following Master\nHub travel complete",
	TextColor3 = Color3.fromRGB(160, 150, 180),
	Font = Enum.Font.Gotham,
	TextSize = 12,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 43,
}, rightPane)

-- ============================================================================
-- HELPER: CREATE ORNATE ACTION BUTTON WITH CORNER & SIDE DIAMONDS
-- ============================================================================
local function createOrnateButton(parent: Instance, text: string, order: number, isPrimary: boolean?, onClick: () -> ()): TextButton
	local btn = new("TextButton", {
		Name = text:gsub("[^%w]", "") .. "Btn",
		LayoutOrder = order,
		Size = UDim2.new(0.333, -7, 1, 0),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		ZIndex = 44,
	}, parent)
	GothicBoxStyle.Apply(btn, { Style = if isPrimary then "Button" else "ButtonSecondary" })
	btn.TextStrokeColor3 = GildedGrimoire.Ink
	btn.TextStrokeTransparency = 0.15
	btn.Activated:Connect(onClick)
	return btn
end

-- ============================================================================
-- HELPER: CREATE ORNATE SQUARE FLOOR BUTTON (1, 2, 3, 4, 5◆)
-- ============================================================================
local function createFloorTile(indexInRow: number): any
	local btn = new("TextButton", {
		Name = "FloorSlot_" .. indexInRow,
		LayoutOrder = indexInRow,
		Size = UDim2.fromOffset(78, 68),
		BackgroundColor3 = Color3.fromRGB(18, 14, 28),
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		ZIndex = 44,
	}, floorRow)

	GildedGrimoire.Frame(btn, { Class = "Slot", Tone = "Deep", Rail = C.BorderNormal, ZIndex = 45 })
	-- The inner rail shows the tile state (selected, here, squad, boss); the ink outline stays black.
	local stroke = GildedGrimoire.StateStroke(btn) :: UIStroke
	stroke.Transparency = 0

	-- 4 Corner Diamonds
	local cornerCoords = {
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 0),
		UDim2.fromScale(0, 1),
		UDim2.fromScale(1, 1),
	}
	local cornerDiamonds: { Frame } = {}
	for _, pos in ipairs(cornerCoords) do
		local d = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = pos,
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = C.BorderNormal,
			BorderSizePixel = 0,
			Rotation = 45,
			Active = false,
			ZIndex = 47,
		}, btn)
		new("UIStroke", { Color = GildedGrimoire.Ink, Thickness = 1.5 }, d)
		table.insert(cornerDiamonds, d)
	end

	local numLabel = new("TextLabel", {
		Name = "Num",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = tostring(indexInRow),
		TextColor3 = C.TextMuted,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Active = false,
		ZIndex = 46,
	}, btn)
	numLabel:SetAttribute("Grimoire", true)
	GildedGrimoire.StyleText(numLabel, "Number")
	local tagLabel = new("TextLabel", {
		Name = "Tag",
		Position = UDim2.new(0, 4, 1, -24),
		Size = UDim2.new(1, -8, 0, 16),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = C.TextMuted,
		TextScaled = true,
		Active = false,
		ZIndex = 46,
	}, btn)
	tagLabel:SetAttribute("Grimoire", true)
	GildedGrimoire.StyleText(tagLabel, "Title")
	local lockIcon = GrimoireIcons.Create("Lock", 22, btn, 47)
	lockIcon.AnchorPoint = Vector2.new(1, 0)
	lockIcon.Position = UDim2.new(1, 4, 0, -6)
	lockIcon.Visible = false

	local slotData: any
	slotData = {
		Root = btn,
		Stroke = stroke,
		Corners = cornerDiamonds,
		Number = numLabel,
		Tag = tagLabel,
		Lock = lockIcon,
		FloorId = indexInRow,
	}

	btn.Activated:Connect(function()
		if slotData.FloorId and slotData.FloorId > 0 then
			selected = slotData.FloorId
			render()
		end
	end)

	btn.MouseEnter:Connect(function()
		if selected ~= slotData.FloorId then
			stroke.Thickness += 0.8
		end
	end)
	btn.MouseLeave:Connect(function()
		if selected ~= slotData.FloorId then
			render()
		end
	end)

	return slotData
end

-- Create the 5 permanent floor slots
for i = 1, 5 do
	activeFloorButtons[i] = createFloorTile(i)
end

-- ============================================================================
-- HELPER: BUILD 10 BIOME CARDS
-- ============================================================================
for biomeIdx, biome in ipairs(mobs.Biomes) do
	local firstF = (biomeIdx - 1) * 5 + 1
	local lastF = biomeIdx * 5
	local pal = BIOME_PALETTES[biomeIdx] or BIOME_PALETTES[1]

	local card = new("TextButton", {
		Name = "BiomeCard_" .. biomeIdx,
		LayoutOrder = biomeIdx,
		Size = UDim2.new(1, -6, 0, 92),
		BackgroundColor3 = pal.Bot,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Text = "",
		ClipsDescendants = true,
		ZIndex = 43,
	}, biomeScroll)

	new("UICorner", { CornerRadius = UDim.new(0, 10) }, card)

	-- Atmospheric Environmental Landscape Gradient
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, pal.Top),
			ColorSequenceKeypoint.new(0.45, pal.Accent),
			ColorSequenceKeypoint.new(1.0, pal.Bot),
		}),
		Rotation = 75,
	}, card)

	-- Atmospheric horizon silhouette layer
	local horizon = new("Frame", {
		Name = "HorizonArt",
		Position = UDim2.new(0, 0, 0.12, 0),
		Size = UDim2.new(1, 0, 0.68, 0),
		BackgroundTransparency = 0.55,
		BackgroundColor3 = Color3.fromRGB(8, 6, 12),
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 44,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, horizon)

	-- Vignette overlay
	local vignette = new("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 8, 16),
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 45,
	}, card)

	-- Gilded Grimoire: ink outline; the inset rail is the selection stroke.
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = GildedGrimoire.Ink,
		Thickness = 2.5,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, card)
	local cardRail = GildedGrimoire.Rail(card, C.BorderNormal, 10, 46)
	local cardStroke = cardRail:FindFirstChildOfClass("UIStroke") :: UIStroke
	cardStroke.Transparency = 0

	-- Inner Artwork Border Frame
	local innerArtFrame = new("Frame", {
		Name = "ArtFrame",
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 45,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, innerArtFrame)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(60, 50, 75),
		Thickness = 1,
		Transparency = 0.4,
	}, innerArtFrame)

	-- Bottom Label Pill (e.g. BIOME 1 · VERDANT RUINS (FLOORS 1–5))
	local pill = new("Frame", {
		Name = "TitlePill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(1, -14, 0, 24),
		BackgroundColor3 = Color3.fromRGB(12, 10, 18),
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 46,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, pill)

	local pillStroke = new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromRGB(75, 62, 95),
		Thickness = 1,
	}, pill)

	local pillText = new("TextLabel", {
		Name = "PillText",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = string.format("BIOME %d · %s (FLOORS %d–%d)", biomeIdx, string.upper(biome.DisplayName), firstF, lastF),
		TextColor3 = C.TextMuted,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Active = false,
		ZIndex = 47,
	}, pill)

	card.Activated:Connect(function()
		activeBiomeIndex = biomeIdx
		selected = (biomeIdx - 1) * 5 + 1
		render()
	end)

	biomeCards[biomeIdx] = {
		Root = card,
		Stroke = cardStroke,
		Label = pillText,
		PillStroke = pillStroke,
	}
end

-- ============================================================================
-- ACTION BUTTON HANDLERS
-- ============================================================================
-- 1234 -> "1.2K", 3400000 -> "3.4M" (power numbers grow very large on high floors).
local function abbreviate(n: number): string
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= unit[1] then
			return (string.gsub(string.format("%.1f%s", n / unit[1], unit[2]), "%.0(%a)$", "%1"))
		end
	end
	return tostring(math.round(n))
end

local function request(action: string, id: number?)
	if not selfState or pending then return end
	local r = {
		ContractVersion = 1,
		RequestId = Http:GenerateGUID(false),
		Action = action,
		FloorId = id,
		CharacterGeneration = selfState.CharacterGeneration,
		ExpectedLocationRevision = selfState.LocationRevision,
		ExpectedSquadRevision = selfState.SquadRevision,
	}
	pending = r.RequestId
	pendingActionName = if id then string.format("%s Floor %d", action, id) else action
	lastFeedback = nil
	render()
	remotes.Request:FireServer(r)
end

local visitBtn = createOrnateButton(actionRow, "VISIT FLOOR", 1, true, function()
	local visitingFloor = if selfState and selfState.PlayerLocation then selfState.PlayerLocation.FloorId else 0
	if visitingFloor == selected then
		request("HUB")
		return
	end
	local profile = _G.CurrentProfile
	local maxAllowed = math.max(1, if profile then (profile.MaxFloorReached or ((profile.HighestClearedFloor or 0) + 1)) else 1)
	if selected > maxAllowed then
		lastFeedback = string.format("Floor %d is locked! Slay Floor %d Boss first.", selected, selected - 1)
		render()
		return
	end
	request("VISIT", selected)
end)

local assignBtn = createOrnateButton(actionRow, "ASSIGN SQUAD", 2, false, function()
	local profile = _G.CurrentProfile
	local maxAllowed = math.max(1, if profile then (profile.MaxFloorReached or ((profile.HighestClearedFloor or 0) + 1)) else 1)
	if selected > maxAllowed then
		lastFeedback = string.format("Cannot assign squad to locked Floor %d!", selected)
		render()
		return
	end
	request("ASSIGN", selected)
end)
local recallBtn = createOrnateButton(actionRow, "RECALL SQUAD", 3, false, function()
	request("RECALL")
end)

-- ============================================================================
-- RENDER & REFRESH LOGIC
-- ============================================================================
render = function()
	local floor = floors.Get(selected)
	if not floor then return end

	activeBiomeIndex = math.clamp(math.floor((selected - 1) / 5) + 1, 1, 10)
	local biome = mobs.Biomes[floor.BiomeIndex]
	local info = presence and presence.Floors[selected + 1]

	local squadSummaries = {}
	if info and info.Squads then
		for _, s in info.Squads do
			table.insert(squadSummaries, string.format("%s (%d)", s.DisplayName, s.RosterSize))
		end
	end

	local encounterNames = {}
	for _, enc in ipairs(floor.Encounters) do
		local m = mobs.Get(enc.EnemyId)
		if m then
			table.insert(encounterNames, string.format("%s x%d", m.DisplayName, enc.Count))
		end
	end
	local bossEntry = floor.BossEnemyId and mobs.Get(floor.BossEnemyId) or nil
	local bossText = if bossEntry then string.format(" · BOSS: %s", bossEntry.DisplayName) else ""

	local profile = _G.CurrentProfile
	local maxAllowed = math.max(1, if profile then (profile.MaxFloorReached or ((profile.HighestClearedFloor or 0) + 1)) else 1)
	local isSelectedLocked = selected > maxAllowed

	-- 1. Update Floor Details Card
	if isSelectedLocked then
		detailHeader.Text = string.format("Floor %d · %s (LOCKED)", selected, floor.DisplayName)
		detailScaling.Text = string.format(
			"LOCKED · Slay Floor %d Boss to unlock!",
			selected - 1
		)
	else
		detailHeader.Text = string.format("Floor %d · %s (%s%s)", selected, floor.DisplayName, floor.BiomeDisplayName or (biome and biome.DisplayName) or floor.BiomeId, bossText)
		-- Phase 5: the floor's Recommended Squad Power against yours (green when you meet it).
		local recommended = floors.RecommendedPower(selected)
		local mine = if profile then profile.SquadPower or 0 else 0
		local ready = mine >= recommended
		detailScaling.Text = string.format(
			"Recommended Power: <font color=\"#FFD66E\"><b>%s</b></font>  ·  Your Squad: <font color=\"%s\"><b>%s</b></font>%s",
			abbreviate(recommended),
			if ready then "#4ADE80" else "#FF6B6B",
			abbreviate(mine),
			if ready then "" else "  (under-powered)"
		)
	end
	detailRoster.Text = string.format("Roster: %s", #encounterNames > 0 and table.concat(encounterNames, ", ") or "None")

	detailVisitors.Text = string.format(
		"Visitors: %d · Stationed Squads: %s",
		info and #info.Visitors or 0,
		#squadSummaries > 0 and table.concat(squadSummaries, ", ") or "none"
	)

	local visitingFloor = if selfState and selfState.PlayerLocation then selfState.PlayerLocation.FloorId else 0
	local assignedFloor = if selfState then selfState.SquadAssignment else nil

	-- 2. Update 10 Biome Cards Highlight State
	for bIdx = 1, 10 do
		local cardData = biomeCards[bIdx]
		if cardData then
			local firstF = (bIdx - 1) * 5 + 1
			local isBiomeLocked = firstF > maxAllowed
			local isCurrentBiome = (bIdx == activeBiomeIndex)
			if isCurrentBiome then
				cardData.Stroke.Color = C.BorderSelected
				cardData.Stroke.Thickness = 1.8
				cardData.PillStroke.Color = C.BorderSelected
				cardData.Label.TextColor3 = C.TextWhite
			elseif isBiomeLocked then
				cardData.Stroke.Color = Color3.fromRGB(35, 28, 48)
				cardData.Stroke.Thickness = 1.0
				cardData.PillStroke.Color = Color3.fromRGB(40, 32, 52)
				cardData.Label.TextColor3 = Color3.fromRGB(110, 95, 130)
			else
				cardData.Stroke.Color = C.BorderNormal
				cardData.Stroke.Thickness = 1.0
				cardData.PillStroke.Color = Color3.fromRGB(75, 62, 95)
				cardData.Label.TextColor3 = C.TextMuted
			end
		end
	end
	-- 3. Update 5 Floor Buttons of the Active Biome
	local firstFloorOfBiome = (activeBiomeIndex - 1) * 5 + 1
	for slotIdx = 1, 5 do
		local fId = firstFloorOfBiome + slotIdx - 1
		local slotData = activeFloorButtons[slotIdx]
		if slotData then
			local isSelectedFloor = (fId == selected)
			local isVisiting = (visitingFloor == fId)
			local isAssigned = (assignedFloor == fId)
			local isBoss = (fId % 5 == 0)
			local isFloorLocked = (fId > maxAllowed)

			slotData.Number.Text = tostring(fId)
			slotData.Tag.Text = if isFloorLocked then "LOCKED"
				elseif isVisiting and isAssigned then "YOU + SQUAD"
				elseif isVisiting then "YOU ARE HERE"
				elseif isAssigned then "SQUAD"
				elseif isBoss then "BOSS"
				else ""
			slotData.Lock.Visible = isFloorLocked

			-- State Colors
			if isSelectedFloor then
				slotData.Stroke.Color = C.BorderSelected
				slotData.Stroke.Thickness = 1.8
				slotData.Number.TextColor3 = C.TextWhite
				for _, d in ipairs(slotData.Corners) do
					d.BackgroundColor3 = C.BorderSelected
				end
			elseif isFloorLocked then
				slotData.Stroke.Color = Color3.fromRGB(38, 30, 50)
				slotData.Stroke.Thickness = 1.0
				slotData.Number.TextColor3 = Color3.fromRGB(90, 75, 110)
				for _, d in ipairs(slotData.Corners) do
					d.BackgroundColor3 = Color3.fromRGB(38, 30, 50)
				end
			elseif isVisiting then
				slotData.Stroke.Color = C.BorderVisiting
				slotData.Stroke.Thickness = 1.5
				slotData.Number.TextColor3 = C.GreenAccent
				for _, d in ipairs(slotData.Corners) do
					d.BackgroundColor3 = C.BorderVisiting
				end
			elseif isAssigned then
				slotData.Stroke.Color = C.BorderSquad
				slotData.Stroke.Thickness = 1.5
				slotData.Number.TextColor3 = Color3.fromRGB(135, 215, 255)
				for _, d in ipairs(slotData.Corners) do
					d.BackgroundColor3 = C.BorderSquad
				end
			elseif isBoss then
				slotData.Stroke.Color = Color3.fromRGB(150, 110, 180)
				slotData.Stroke.Thickness = 1.2
				slotData.Number.TextColor3 = Color3.fromRGB(240, 185, 255)
				for _, d in ipairs(slotData.Corners) do
					d.BackgroundColor3 = Color3.fromRGB(150, 110, 180)
				end
			else
				slotData.Stroke.Color = C.BorderNormal
				slotData.Stroke.Thickness = 1.2
				slotData.Number.TextColor3 = C.TextMuted
				for _, d in ipairs(slotData.Corners) do
					d.BackgroundColor3 = C.BorderNormal
				end
			end

			slotData.Tag.TextColor3 = if isBoss and not isFloorLocked and not isSelectedFloor and not isVisiting and not isAssigned then Color3.fromRGB(255, 120, 140) else slotData.Number.TextColor3
			slotData.FloorId = fId
		end
	end
	-- 4. Dynamic Action Button Text
	if isSelectedLocked then
		visitBtn.Text = "LOCKED"
		assignBtn.Text = "LOCKED"
	elseif visitingFloor == selected and visitingFloor > 0 then
		visitBtn.Text = "RETURN TO HUB"
		assignBtn.Text = "ASSIGN SQUAD"
	else
		visitBtn.Text = "VISIT FLOOR"
		assignBtn.Text = "ASSIGN SQUAD"
	end
	-- 5. Status Footer Readout
	if selfState then
		local locStr = if visitingFloor == 0 then "Hub" else string.format("Floor %d (%s)", visitingFloor, floors.Get(visitingFloor).DisplayName)
		local sqStr = if assignedFloor then string.format("Stationed on Floor %d", assignedFloor) else "Following Master"
		local feedbackStr = if pending then string.format("Pending: %s…", pendingActionName or "request")
			elseif lastFeedback then lastFeedback
			else "Hub travel complete"
		statusFooter.Text = string.format("You: %s · Squad: %s\n%s", locStr, sqStr, feedbackStr)
	end
end

-- Global Control APIs
_G.RequestTowerHub = function(): boolean
	if not selfState then
		warn("[TowerController] Cannot travel to Hub: selfState not ready yet")
		return false
	end
	if pending then
		warn("[TowerController] Travel already pending: " .. tostring(pending))
		return false
	end
	request("HUB")
	return true
end

_G.OpenTowerSelector = function()
	lastSelectorOpenTime = os.clock()
	if _G.OpenMasterModal then _G.OpenMasterModal("NONE") end
	panel.Visible = true
	scrim.Visible = true
	render()
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end
end

_G.IsTowerSelectorOpen = function(): boolean
	return panel.Visible
end

_G.CloseTowerSelector = function()
	panel.Visible = false
	scrim.Visible = false
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end
end

-- Keyboard / Gamepad Navigation
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if not panel.Visible then return end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		panel.Visible = false
		scrim.Visible = false
		if _G.UpdateBottomTabHighlights then
			_G.UpdateBottomTabHighlights()
		end
		return
	end
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.PageUp then
		selected = math.clamp(selected - 1, 1, 50)
		render()
	elseif input.KeyCode == Enum.KeyCode.DPadRight or input.KeyCode == Enum.KeyCode.PageDown then
		selected = math.clamp(selected + 1, 1, 50)
		render()
	end
end)

-- Remote Event Listeners

local SyndicateRemotes = RS:WaitForChild("Remotes"):WaitForChild("SyndicateRemotes")
local ProfileDeltaSyncEvent = SyndicateRemotes:WaitForChild("ProfileDeltaSync") :: RemoteEvent
ProfileDeltaSyncEvent.OnClientEvent:Connect(function(profile: any)
	if profile and not profile._PitDelta then
		_G.CurrentProfile = profile
		if panel.Visible then
			render()
		end
	end
end)
remotes.OpenSelector.OnClientEvent:Connect(function()
	if _G.OpenMasterModal then _G.OpenMasterModal("NONE") end
	panel.Visible = true
	scrim.Visible = true
	render()
end)

PromptService.PromptTriggered:Connect(function(prompt, who)
	if who and who ~= player then return end
	local action = prompt:GetAttribute("TowerAction")
	local curFloor = if context and context.FloorId then context.FloorId elseif selfState and selfState.PlayerLocation then selfState.PlayerLocation.FloorId else 0
	if action == "SELECTOR" or prompt.Name == "TowerSelectorPrompt" then
		if _G.OpenMasterModal then _G.OpenMasterModal("NONE") end
		panel.Visible = true
		scrim.Visible = true
		render()
	elseif action == "HUB" then
		request("HUB")
	elseif action == "PREVIOUS" and curFloor > 1 then
		request("VISIT", curFloor - 1)
	elseif action == "NEXT" and curFloor > 0 and curFloor < 50 then
		local nextFloor = curFloor + 1
		local profile = _G.CurrentProfile
		local maxAllowed = math.max(1, if profile then (profile.MaxFloorReached or ((profile.HighestClearedFloor or 0) + 1)) else 1)
		if nextFloor <= maxAllowed then
			request("VISIT", nextFloor)
		else
			lastFeedback = string.format("Floor %d is locked! Slay Floor %d Boss first.", nextFloor, curFloor)
			panel.Visible = true
			scrim.Visible = true
			render()
		end
	end
end)

remotes.Presence.OnClientEvent:Connect(function(p)
	if presence and p.ServerSessionId == presence.ServerSessionId and p.PresenceRevision < presence.PresenceRevision then return end
	presence = p
	selfState = p.Self
	render()
end)

remotes.Response.OnClientEvent:Connect(function(r)
	if r.RequestId ~= pending then return end
	if r.Status ~= "PENDING" then
		local act = pendingActionName or "Action"
		pending = nil
		pendingActionName = nil
		if r.Status == "OK" or not r.ErrorCode then
			lastFeedback = string.format("%s complete", act)
		else
			lastFeedback = string.format("%s failed: %s", act, tostring(r.ErrorCode))
		end
		render()
	end
end)

remotes.Context.OnClientEvent:Connect(function(c)
	if c.Stage == "PREPARE" then
		task.spawn(function()
			local ok = true
			if workspace.StreamingEnabled then
				ok = pcall(function()
					player:RequestStreamAroundAsync(c.Arrival.Position, math.max(.1, c.ReadyDeadline - workspace:GetServerTimeNow()))
				end)
			end
			remotes.Ready:FireServer({
				ContractVersion = 1,
				RequestId = c.RequestId,
				ReadyToken = c.ReadyToken,
				ViewEpoch = c.ViewEpoch,
				CharacterGeneration = c.CharacterGeneration,
				Result = ok and workspace:GetServerTimeNow() <= c.ReadyDeadline and "READY" or "FAILED",
			})
		end)
	elseif c.Stage == "COMMIT" then
		context = c
		_G.TowerView = c
		if c.FloorId > 0 then selected = c.FloorId end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		render()
	end
end)

task.defer(function()
	remotes.Request:FireServer({ ContractVersion = 1, RequestId = Http:GenerateGUID(false), Action = "PRESENCE_SUBSCRIBE" })
end)
