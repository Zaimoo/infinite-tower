--!strict
-- StarterPlayerScripts/UI/PromotionController.luau
-- Dedicated Hero Promotion Ritual UI (Promotion Stones + Gold only, 1★ -> 7★ Ascension):
--   Authoritative RemoteFunction: PitRequest (STATE -> PREVIEW -> COMMIT).

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local ModalFit = require(script.Parent:WaitForChild("ModalFit"))
local StatFormulas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("StatFormulas"))
local PitBalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PitBalanceConfig"))
local GothicBoxStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GothicBoxStyle"))
local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))

local Promo = {}
Promo.__index = Promo

local WIDTH, HEIGHT = 700, 610 -- same container as Synthesis (the Pit tabs swap between them)

local C = {
	Scrim = Color3.fromRGB(6, 6, 10),
	Bg = Color3.fromRGB(17, 14, 23),
	Border = Color3.fromRGB(200, 162, 200),
	BorderGlow = Color3.fromRGB(200, 162, 200),
	SlotBg = Color3.fromRGB(20, 20, 30),
	SlotBorder = Color3.fromRGB(200, 162, 200),
	SuccessGreen = Color3.fromRGB(57, 255, 20),
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(220, 220, 220),
	TextDim = Color3.fromRGB(160, 150, 180),
	StarGold = Color3.fromRGB(255, 215, 0),
	Danger = Color3.fromRGB(255, 95, 85),
	Good = Color3.fromRGB(57, 255, 20),
}

local RARITY = {
	Color3.fromRGB(160, 128, 100),
	Color3.fromRGB(181, 193, 201),
	Color3.fromRGB(115, 165, 218),
	Color3.fromRGB(180, 142, 218),
	Color3.fromRGB(228, 193, 111),
	Color3.fromRGB(240, 110, 95),
	Color3.fromRGB(130, 235, 255),
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in props do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, parent)
end

local function glow(parent: GuiObject, pad: number, color: Color3?, transparency: number?)
	local g = new("Frame", {
		Name = "Glow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, pad, 1, pad),
		ZIndex = parent.ZIndex,
	}, parent)
	stroke(g, color or C.BorderGlow, 3, transparency or 0.75)
end

local function applyGothicStyle(container: GuiObject, style: "Window" | "Card" | "Button" | "Compact")
	return GothicBoxStyle.Apply(container, { Style = style })
end

local function createRightArrow(parent: Instance, size: UDim2, position: UDim2, color: Color3): Frame
	local root = new("Frame", {
		Name = "VectorRightArrow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		ZIndex = 43,
	}, parent)

	local bright = Color3.fromRGB(
		math.clamp(math.floor(color.R * 255 * 1.25 + 20), 0, 255),
		math.clamp(math.floor(color.G * 255 * 1.25 + 20), 0, 255),
		math.clamp(math.floor(color.B * 255 * 1.25 + 20), 0, 255)
	)

	-- Outer Atmospheric Glow
	local g = new("Frame", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 0, 22),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 43,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 11) }, g)

	-- Central Horizontal Shaft
	local shaft = new("Frame", {
		Name = "Shaft",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.new(1, -18, 0, 3.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 44,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, shaft)

	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(
				math.floor(color.R * 255 * 0.75),
				math.floor(color.G * 255 * 0.75),
				math.floor(color.B * 255 * 0.75)
			)),
			ColorSequenceKeypoint.new(0.65, color),
			ColorSequenceKeypoint.new(1.0, bright),
		}),
	}, shaft)

	-- Arrowhead Wings (Chevron pointing right)
	local wingTop = new("Frame", {
		Name = "WingTop",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 3.5),
		Rotation = 38,
		BackgroundColor3 = bright,
		BorderSizePixel = 0,
		ZIndex = 45,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, wingTop)

	local wingBottom = new("Frame", {
		Name = "WingBottom",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 3.5),
		Rotation = -38,
		BackgroundColor3 = bright,
		BorderSizePixel = 0,
		ZIndex = 45,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, wingBottom)

	-- Seamless Vertex Tip
	new("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10.5, 0.5, 0),
		Size = UDim2.fromOffset(5, 5),
		Rotation = 45,
		BackgroundColor3 = bright,
		BorderSizePixel = 0,
		ZIndex = 46,
	}, root)

	return root
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?, role: string?): TextLabel
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or GothicBoxStyle.Font.LegacyFont or Enum.Font.GothamBold,
		TextWrapped = true,
		RichText = true,
	}, parent)
	GothicBoxStyle.Font.Apply(lbl, {
		Role = (role or if size >= 20 then "Title" else if size >= 15 then "Header" else "Body") :: any,
		Color = color,
		Size = size,
	})
	if role == "Number" then
		GildedGrimoire.StyleText(lbl, "Number")
	end
	return lbl
end

local function goldText(lbl: TextLabel)
	lbl.TextColor3 = Color3.new(1, 1, 1)
	new("UIGradient", {
		Name = "GrimoireGold",
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), GildedGrimoire.Text.Gold),
	}, lbl)
end

local function spaced(text: string): string
	return (text:gsub("(.)", "%1 "):sub(1, -2))
end

local function stars(n: number?): string
	local maxStars = PitBalanceConfig.MaxStars or 7
	return string.rep("★", math.clamp(n or 1, 1, maxStars))
end

local function formatNumber(n: number?): string
	local val = math.floor(n or 0)
	local str = tostring(val)
	return (str:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

--============================================================================
-- CONSTRUCTION
--============================================================================

function Promo.new(gui: ScreenGui, remote: RemoteFunction)
	local self: any = setmetatable({}, Promo)
	self.Remote = remote
	self.State = { Heroes = {}, Resources = {}, Currencies = {}, Materials = {} }
	self.Recipient = nil
	self.Preview = nil
	self.Busy = false
	self.Loading = false
	self.PreviewSerial = 0
	self.Message = ""

	-- 1. Scrim Backdrop
	self.Scrim = new("TextButton", {
		Name = "PromotionScrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 39,
	}, gui)
	self.Scrim.Activated:Connect(function()
		if not self.Busy then
			self:Close()
		end
	end)

	-- 2. Modal Root Frame (Ornate Gothic Box Container)
	local root = new("TextButton", {
		Name = "HeroPromotionModal",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		ZIndex = 40,
	}, gui)
	root.Activated:Connect(function() end)
	self.Root = root
	GildedGrimoire.Watch(root)

	applyGothicStyle(root, "Window")

	self.Scale = new("UIScale", {}, root)

	GothicBoxStyle.CreateCloseButton(root, function()
		if not self.Busy then
			self:Close()
		end
	end)

	-- Title: HERO PROMOTION
	local title = label(root, spaced("HERO PROMOTION"), 34, C.Text, Enum.Font.GothamBlack)
	title.Name = "Title"
	title.Position = UDim2.fromOffset(0, 18)
	title.Size = UDim2.new(1, 0, 0, 44)
	title.ZIndex = 42
	goldText(title)
	self.Title = title

	--========================================================================
	-- RITUAL AREA (Circular Altar Layout — No Hero Sacrifices)
	--========================================================================
	local ritualArea = new("Frame", {
		Name = "RitualArea",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(320, 320),
		BackgroundTransparency = 1,
		ZIndex = 42,
	}, root)
	self.RitualArea = ritualArea
	new("UIScale", { Scale = 0.8 }, ritualArea)

	-- Outer Magic Circle (280x280)
	local outerCircle = new("Frame", {
		Name = "MagicCircleOuter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(280, 280),
		BackgroundTransparency = 1,
		ZIndex = 42,
	}, ritualArea)
	new("UICorner", { CornerRadius = UDim.new(0, 140) }, outerCircle)
	stroke(outerCircle, C.Border, 2, 0.5)
	glow(outerCircle, 10, C.BorderGlow, 0.75)
	self.OuterCircle = outerCircle

	-- Inner Magic Circle (190x190)
	local innerCircle = new("Frame", {
		Name = "MagicCircleInner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(190, 190),
		BackgroundTransparency = 1,
		ZIndex = 42,
	}, ritualArea)
	new("UICorner", { CornerRadius = UDim.new(0, 95) }, innerCircle)
	stroke(innerCircle, C.Border, 1.5, 0.2)
	glow(innerCircle, 6, C.BorderGlow, 0.7)
	self.InnerCircle = innerCircle

	-- Main Hero Center Slot (136x136)
	local mainSlot = new("TextButton", {
		Name = "MainHeroSlot",
		Text = "",
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(136, 136),
		BackgroundColor3 = C.SlotBg,
		BorderSizePixel = 0,
		ZIndex = 43,
	}, ritualArea)
	self.MainSlot = mainSlot
	self.MainStroke = stroke(mainSlot, C.Border, 2, 0)
	glow(mainSlot, 12, C.BorderGlow, 0.5)

	local mainInset = new("Frame", {
		Name = "SlotInset",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		ZIndex = 44,
	}, mainSlot)
	stroke(mainInset, C.Border, 1, 0.8)

	self.MainPortraitHost = new("Frame", {
		Name = "PortraitHost",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		ZIndex = 44,
	}, mainSlot)

	self.MainQuestion = label(mainSlot, "?", 60, C.Text, Enum.Font.GothamBlack)
	self.MainQuestion.Size = UDim2.fromScale(1, 1)
	self.MainQuestion.ZIndex = 45
	self.MainQuestion.TextStrokeColor3 = C.Border
	self.MainQuestion.TextStrokeTransparency = 0.5

	-- Main Slot Level/Max Pill Badge
	local mainBadge = new("Frame", {
		Name = "HeroBadge",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(112, 24),
		BackgroundColor3 = Color3.fromRGB(15, 12, 22),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 46,
	}, mainSlot)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, mainBadge)
	stroke(mainBadge, C.Border, 1, 0.3)
	self.MainBadge = mainBadge

	local mainBadgeText = label(mainBadge, "MAX LVL", 14, C.Text, Enum.Font.GothamBold, "Number")
	mainBadgeText.Size = UDim2.fromScale(1, 1)
	mainBadgeText.ZIndex = 47
	self.MainBadgeText = mainBadgeText

	mainSlot.Activated:Connect(function()
		self:OpenPicker()
	end)

	--========================================================================
	-- STATS DISPLAY PANEL (Before & After Stats Panel)
	--========================================================================
	local statsPanel = new("Frame", {
		Name = "StatsDisplay",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 330),
		Size = UDim2.fromOffset(640, 116),
		BorderSizePixel = 0,
		ZIndex = 42,
	}, root)
	GildedGrimoire.Frame(statsPanel, { Class = "Panel", Tone = "Deep" })

	-- Left Stat Block (Current)
	local leftBlock = new("Frame", {
		Name = "StatBlockOld",
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.fromOffset(236, 100),
		BackgroundTransparency = 1,
		ZIndex = 43,
	}, statsPanel)

	local function makeStatRow(parent: Instance, y: number, name: string)
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.fromOffset(0, y),
			BackgroundTransparency = 1,
			ZIndex = 43,
		}, parent)
		local nameLbl = label(row, name, 17, C.TextMuted, Enum.Font.GothamMedium, "Body")
		nameLbl.Size = UDim2.new(0.55, 0, 1, 0)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.ZIndex = 43
		local valLbl = label(row, "", 19, C.Text, Enum.Font.GothamBold, "Number")
		valLbl.Size = UDim2.new(0.45, 0, 1, 0)
		valLbl.Position = UDim2.new(0.55, 0, 0, 0)
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.ZIndex = 43
		return valLbl
	end

	self.OldMaxLevel = makeStatRow(leftBlock, 0, "Max Level")
	self.OldHP = makeStatRow(leftBlock, 24, "HP")
	self.OldATK = makeStatRow(leftBlock, 48, "ATK")
	self.OldStars = label(leftBlock, "★★★", 22, C.StarGold, Enum.Font.GothamBold)
	self.OldStars.Position = UDim2.fromOffset(0, 74)
	self.OldStars.Size = UDim2.new(1, 0, 0, 24)
	self.OldStars.TextXAlignment = Enum.TextXAlignment.Center
	self.OldStars.ZIndex = 43

	-- Center Arrow (Current Stats ➔ Upgraded Stats)
	self.Arrow = createRightArrow(statsPanel, UDim2.fromOffset(60, 32), UDim2.fromScale(0.5, 0.5), C.Border)

	-- Right Stat Block (Upgraded)
	local rightBlock = new("Frame", {
		Name = "StatBlockNew",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 10),
		Size = UDim2.fromOffset(236, 100),
		BackgroundTransparency = 1,
		ZIndex = 43,
	}, statsPanel)

	self.NewMaxLevel = makeStatRow(rightBlock, 0, "Max Level")
	self.NewMaxLevel.TextColor3 = C.SuccessGreen
	self.NewHP = makeStatRow(rightBlock, 24, "HP")
	self.NewHP.TextColor3 = C.SuccessGreen
	self.NewATK = makeStatRow(rightBlock, 48, "ATK")
	self.NewATK.TextColor3 = C.SuccessGreen
	self.NewStars = label(rightBlock, '★★★<font color="#39ff14">★</font>', 22, C.StarGold, Enum.Font.GothamBold)
	self.NewStars.Position = UDim2.fromOffset(0, 74)
	self.NewStars.Size = UDim2.new(1, 0, 0, 24)
	self.NewStars.TextXAlignment = Enum.TextXAlignment.Center
	self.NewStars.ZIndex = 43

	--========================================================================
	-- ACTION AREA (Success rate, costs, button, feedback)
	--========================================================================
	local actionArea = new("Frame", {
		Name = "ActionSection",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 454),
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundTransparency = 1,
		ZIndex = 42,
	}, root)
	self.ActionArea = actionArea

	local rateLbl = label(actionArea, "100% SUCCESS RATE", 20, C.SuccessGreen, Enum.Font.GothamBlack)
	rateLbl.Position = UDim2.fromOffset(0, 0)
	rateLbl.Size = UDim2.new(1, 0, 0, 26)
	rateLbl.ZIndex = 43
	self.RateLabel = rateLbl

	local costLbl = label(actionArea, "", 15, C.TextMuted, Enum.Font.GothamBold, "Body")
	costLbl.Position = UDim2.fromOffset(0, 26)
	costLbl.Size = UDim2.new(1, 0, 0, 22)
	costLbl.ZIndex = 43
	self.CostLabel = costLbl

	local btnWidth, btnHeight = 480, 52
	local btn = new("TextButton", {
		Name = "InitiatePromotionButton",
		Text = spaced("INITIATE PROMOTION"),
		TextSize = 22,
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Text,
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(btnWidth, btnHeight),
		ZIndex = 43,
	}, actionArea)
	self.ConfirmButton = btn
	applyGothicStyle(btn, "Button")
	self.ConfirmStroke = GildedGrimoire.StateStroke(btn)
	btn.TextStrokeColor3 = Color3.fromRGB(10, 6, 14)
	btn.TextStrokeTransparency = 0.15

	btn.Activated:Connect(function()
		self:Confirm()
	end)

	self.Status = label(actionArea, "", 16, C.TextMuted, Enum.Font.GothamMedium, "Body")
	self.Status.Position = UDim2.fromOffset(30, 108)
	self.Status.Size = UDim2.new(1, -60, 0, 36)
	self.Status.ZIndex = 43

	self:BuildPicker()

	self.OuterAngle = 0
	self.InnerAngle = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if self.Root.Visible then
			self.OuterAngle = (self.OuterAngle + dt * 24) % 360
			self.InnerAngle = (self.InnerAngle - dt * 36) % 360
			self.OuterCircle.Rotation = self.OuterAngle
			self.InnerCircle.Rotation = self.InnerAngle
		end
	end)

	ModalFit.Bind(root, self.Scale, WIDTH, HEIGHT)

	self:Render()
	return self
end

--============================================================================
-- HERO PICKER OVERLAY
--============================================================================

function Promo.BuildPicker(self: any)
	local picker = new("TextButton", {
		Name = "HeroPickerOverlay",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		ZIndex = 60,
	}, self.Root)
	picker.Activated:Connect(function() end)
	applyGothicStyle(picker, "Window")
	self.Picker = picker

	self.PickerTitle = label(picker, "", 26, C.Text, Enum.Font.GothamBlack)
	self.PickerTitle.Position = UDim2.fromOffset(0, 12)
	self.PickerTitle.Size = UDim2.new(1, 0, 0, 34)
	goldText(self.PickerTitle)
	self.PickerTitle.ZIndex = 61

	local back = new("TextButton", {
		Text = "×",
		TextSize = 28,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextDim,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -48, 0, 10),
		Size = UDim2.fromOffset(38, 38),
		ZIndex = 61,
		Name = "PickerClose",
	}, picker)
	back.Activated:Connect(function()
		picker.Visible = false
	end)
	GrimoireIcons.CloseGlyph(back, 18)

	self.PickerStatus = label(picker, "", 16, C.TextMuted, Enum.Font.GothamMedium, "Body")
	self.PickerStatus.Position = UDim2.new(0, 20, 1, -44)
	self.PickerStatus.Size = UDim2.new(1, -40, 0, 34)
	self.PickerStatus.ZIndex = 61

	self.PickerList = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(20, 56),
		Size = UDim2.new(1, -40, 1, -108),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Border,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 61,
	}, picker)

	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(112, 140),
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.PickerList)

	new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
	}, self.PickerList)
end

--============================================================================
-- SERVER TRANSACTIONS
--============================================================================

function Promo.Request(self: any, command: string, payload: any?): any
	local ok, response = pcall(function()
		return self.Remote:InvokeServer(command, payload)
	end)
	if not ok or type(response) ~= "table" then
		return { Success = false, Message = "The Promotion chamber could not respond. Please try again." }
	end
	return response
end

function Promo.Refresh(self: any, attempt: number?)
	task.spawn(function()
		local response = self:Request("STATE")
		if not self.Root.Visible then return end
		if not response.Success then
			if (attempt or 0) < 3 then
				task.delay(0.5, function() self:Refresh((attempt or 0) + 1) end)
			end
			return
		end
		self.State = response.State or { Heroes = {}, Currencies = {}, Materials = {} }
		if self.Recipient and not self.State.Heroes[self.Recipient] then
			self.Recipient = nil
		end
		self:Render()
		if self.Picker.Visible then
			self:RenderPicker()
		end
		self:QueuePreview()
	end)
end

function Promo.QueuePreview(self: any)
	self.PreviewSerial += 1
	local serial = self.PreviewSerial
	self.Preview = nil
	if not self.Recipient then
		self:Render()
		return
	end

	self.Loading = true
	self:Render()
	task.delay(0.15, function()
		if serial ~= self.PreviewSerial or not self.Root.Visible then return end
		local response = self:Request("PREVIEW", {
			Action = "PROMOTION",
			Recipient = self.Recipient,
			Donors = {},
		})
		if serial ~= self.PreviewSerial then return end
		if not response.Success and tostring(response.Message):find("wait") then
			task.delay(0.3, function()
				if serial == self.PreviewSerial then self:QueuePreview() end
			end)
			return
		end
		self.Loading = false
		self.Preview = response.Preview
		if not response.Success then
			self.Message = response.Message or "Promotion requirements not met."
		end
		self:Render()
	end)
end

function Promo.Confirm(self: any)
	if self.Busy or self.Loading then return end
	if not self.Recipient then
		self.Message = "Tap the center slot to select a hero to promote."
		self:Render()
		return
	end

	local preview = self.Preview
	if not preview or not preview.CanCommit then
		self.Message = preview and preview.Reason or "Promotion requirements not met."
		self:Render()
		return
	end

	self.Busy = true
	self:Render()
	task.spawn(function()
		local response = self:Request("COMMIT", { Token = preview.Token, ConfirmRare = true })
		self.Busy = false
		self.Preview = nil
		if response.Success then
			local result = response.Result or {}
			local after = result.After
			local hero = self.State.Heroes[self.Recipient]
			local newStars = after and after.Stars or ((hero and hero.Stars or 1) + 1)
			self.Message = string.format("Ascension complete! %s has ascended to %s rank!", hero and hero.DisplayName or "Hero", stars(newStars))
			local delta = response.Delta
			if delta then
				for uuid, h in delta.Heroes or {} do
					self.State.Heroes[uuid] = h
				end
				for _, uuid in delta.Removed or {} do
					self.State.Heroes[uuid] = nil
				end
				if delta.Currencies then self.State.Currencies = delta.Currencies end
				if delta.Materials then self.State.Materials = delta.Materials end
			end
			self:Celebrate()
		else
			self.Message = response.Message or "The promotion was rejected. Review requirements."
		end
		self:Render()
		task.delay(0.5, function()
			if self.Root.Visible and not self.Busy then
				self:Refresh()
			end
		end)
	end)
end

--============================================================================
-- SELECTION & PICKER
--============================================================================

function Promo.OpenPicker(self: any)
	if self.Busy then return end
	self.PickerMessage = "Choose a hero at maximum level to promote with Promotion Stones & Gold."
	self.Picker.Visible = true
	self:RenderPicker()
end

function Promo.Pick(self: any, uuid: string)
	local hero = self.State.Heroes[uuid]
	if not hero then return end
	self.Recipient = uuid
	self.Message = ""
	self.Picker.Visible = false
	self:QueuePreview()
end

function Promo.RenderPicker(self: any)
	for _, child in self.PickerList:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local maxStars = PitBalanceConfig.MaxStars or 7
	self.PickerTitle.Text = spaced("SELECT HERO TO PROMOTE")
	self.PickerStatus.Text = self.PickerMessage or ""

	local heroes = {}
	for _, hero in self.State.Heroes do
		table.insert(heroes, hero)
	end

	table.sort(heroes, function(a, b)
		local aMax = (a.Stars or 1) >= maxStars
		local bMax = (b.Stars or 1) >= maxStars
		if aMax ~= bMax then return not aMax end
		local aCap = (a.Level or 1) >= (a.Stars or 1) * 10
		local bCap = (b.Level or 1) >= (b.Stars or 1) * 10
		if aCap ~= bCap then return aCap end
		if (a.Stars or 1) ~= (b.Stars or 1) then return (a.Stars or 1) > (b.Stars or 1) end
		if (a.Level or 1) ~= (b.Level or 1) then return (a.Level or 1) > (b.Level or 1) end
		return tostring(a.UUID) < tostring(b.UUID)
	end)

	if #heroes == 0 then
		local empty = label(self.PickerList, "No heroes in roster.", 17, C.TextMuted, Enum.Font.GothamMedium, "Body")
		empty.Size = UDim2.fromOffset(400, 40)
		empty.ZIndex = 62
	end

	for i, hero in heroes do
		local isMax = (hero.Stars or 1) >= maxStars
		local isCapped = (hero.Level or 1) >= (hero.Stars or 1) * 10
		local eligible = not isMax and isCapped
		local tagText: string? = nil
		if isMax then
			tagText = "MAX RANK"
		elseif not isCapped then
			tagText = "NEED LV." .. ((hero.Stars or 1) * 10)
		end

		local rarity = RARITY[math.clamp(hero.Stars or 1, 1, #RARITY)]
		local tile = new("TextButton", {
			Name = "Hero_" .. tostring(hero.UUID),
			Text = "",
			LayoutOrder = i,
			AutoButtonColor = false,
			BackgroundColor3 = C.SlotBg,
			BorderSizePixel = 0,
			ZIndex = 62,
		}, self.PickerList)
		GothicBoxStyle.Apply(tile, { Style = "Card" })

		local host = new("Frame", {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.fromOffset(96, 84),
			ZIndex = 63,
		}, tile)
		local portrait = HeroCard.Portrait(host, hero)
		portrait.ZIndex = 63

		local name = label(tile, hero.DisplayName or "Hero", 15, eligible and rarity or C.TextDim, nil, "Title")
		name.Position = UDim2.fromOffset(4, 94)
		name.Size = UDim2.new(1, -8, 0, 18)
		name.ZIndex = 63

		local info = label(tile, string.format("%s  Lv.%d", stars(hero.Stars), hero.Level or 1), 13, eligible and C.Text or C.TextDim, Enum.Font.GothamMedium, "Number")
		info.Position = UDim2.fromOffset(4, 114)
		info.Size = UDim2.new(1, -8, 0, 16)
		info.ZIndex = 63

		if tagText then
			local shade = new("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 64,
			}, tile)
			local tag = label(shade, tagText, 13, C.Danger, nil, "Title")
			tag.Size = UDim2.new(1, 0, 0, 16)
			tag.Position = UDim2.fromOffset(0, 36)
			tag.ZIndex = 65
		end

		local uuid = hero.UUID
		tile.Activated:Connect(function()
			self:Pick(uuid)
		end)
	end
end

--============================================================================
-- MAIN RENDERING
--============================================================================

function Promo.Render(self: any)
	local heroes = self.State.Heroes or {}
	local recipient = self.Recipient and heroes[self.Recipient]
	local maxStars = PitBalanceConfig.MaxStars or 7

	-- 1. Main Recipient Center Slot
	self.MainPortraitHost:ClearAllChildren()
	if recipient then
		self.MainQuestion.Visible = false
		local p = HeroCard.Portrait(self.MainPortraitHost, recipient)
		p.ZIndex = 44
		local rarity = RARITY[math.clamp(recipient.Stars or 1, 1, #RARITY)]
		self.MainStroke.Color = rarity

		local maxLevel = (recipient.Stars or 1) * 10
		local isCapped = (recipient.Level or 1) >= maxLevel
		self.MainBadge.Visible = true
		self.MainBadgeText.Text = isCapped and "MAX LVL" or string.format("LV. %d/%d", recipient.Level or 1, maxLevel)
	else
		self.MainQuestion.Visible = true
		self.MainStroke.Color = C.Border
		self.MainBadge.Visible = false
	end

	-- 2. Stats Display Panel (Before & After Stats)
	local preview = self.Preview
	if recipient then
		local curStars = math.clamp(recipient.Stars or 1, 1, maxStars)
		local nextStars = math.min(maxStars, curStars + 1)
		local curMaxLvl = curStars * 10
		local nextMaxLvl = nextStars * 10

		local beforeSnap = (preview and preview.Before) or recipient.Stats or StatFormulas.GetCombatSnapshot(recipient)
		local oldHP = math.floor(beforeSnap.HP or beforeSnap.Health or recipient.BaseHP or 1000)
		local oldATK = math.floor(beforeSnap.ATK or beforeSnap.AttackDamage or recipient.BaseATK or 100)

		local newHP = if curStars >= maxStars
			then oldHP
			else (preview and preview.After and preview.After.HP) or math.round(oldHP * PitBalanceConfig.Promotion.CombatMultiplier)
		local newATK = if curStars >= maxStars
			then oldATK
			else (preview and preview.After and preview.After.ATK) or math.round(oldATK * PitBalanceConfig.Promotion.CombatMultiplier)

		self.OldMaxLevel.Text = tostring(curMaxLvl)
		self.OldHP.Text = formatNumber(oldHP)
		self.OldATK.Text = formatNumber(oldATK)
		self.OldStars.Text = string.rep("★", curStars)

		self.NewMaxLevel.Text = tostring(nextMaxLvl)
		self.NewHP.Text = formatNumber(newHP)
		self.NewATK.Text = formatNumber(newATK)
		if curStars >= maxStars then
			self.NewStars.Text = string.rep("★", curStars)
		else
			self.NewStars.Text = string.format('%s<font color="#39ff14">★</font>', string.rep("★", curStars))
		end
	else
		self.OldMaxLevel.Text = "30"
		self.OldHP.Text = "1,250"
		self.OldATK.Text = "150"
		self.OldStars.Text = "★★★"

		self.NewMaxLevel.Text = "40"
		self.NewHP.Text = "3,750"
		self.NewATK.Text = "450"
		self.NewStars.Text = '★★★<font color="#39ff14">★</font>'
	end

	-- 3. Costs / Requirements Display
	local currencies = self.State.Currencies or {}
	local materials = self.State.Materials or self.State.PitMaterials or {}
	local goldOwned = currencies.Gold or 0
	local stonesOwned = materials.PromotionStone or 0

	if recipient then
		local rule = PitBalanceConfig.Promotion[recipient.Stars]
		if not rule or (recipient.Stars or 1) >= maxStars then
			self.CostLabel.Text = '<font color="#39ff14">MAXIMUM CELESTIAL 7★ RANK ACHIEVED</font>'
		else
			local reqGold = rule.Gold or 1500
			local reqStones = rule.PromotionStone or 1

			local goldOk = goldOwned >= reqGold
			local stonesOk = stonesOwned >= reqStones

			local goldStr = string.format("GOLD: %s / %s %s", formatNumber(goldOwned), formatNumber(reqGold), goldOk and "(OK)" or "(NEED MORE)")
			local stoneStr = string.format("STONES: %s / %s %s", formatNumber(stonesOwned), formatNumber(reqStones), stonesOk and "(OK)" or "(NEED MORE)")

			self.CostLabel.Text = string.format(
				'<font color="%s">%s</font>      <font color="%s">%s</font>',
				goldOk and "#39ff14" or "#ff5f55",
				goldStr,
				stonesOk and "#39ff14" or "#ff5f55",
				stoneStr
			)
		end
	else
		self.CostLabel.Text = string.format("GOLD OWNED: %s   ·   PROMOTION STONES: %s", formatNumber(goldOwned), formatNumber(stonesOwned))
	end

	-- 4. Action Button & Feedback Status
	local canCommit = preview ~= nil and preview.CanCommit == true and not self.Loading and not self.Busy
	local button = self.ConfirmButton
	if self.Busy then
		button.Text = spaced("PROMOTING…")
	else
		button.Text = spaced("INITIATE PROMOTION")
	end

	button.TextColor3 = (canCommit or self.Busy) and C.Text or Color3.fromRGB(206, 196, 226)
	button.TextTransparency = if canCommit or self.Busy then 0 else 0.15
	if self.ConfirmStroke then
		self.ConfirmStroke.Color = if canCommit then Color3.fromRGB(255, 226, 140) else Color3.fromRGB(150, 138, 176)
	end

	local status, color = self.Message, C.TextDim
	if status == "" then
		if not recipient then
			status = "Tap the center slot to select a hero for promotion."
		elseif self.Loading then
			status = "Evaluating ascension requirements…"
		elseif preview and not preview.CanCommit then
			status, color = preview.Reason or "Promotion requirements not met.", C.Danger
		elseif preview and preview.CanCommit then
			status, color = string.format("Ascension ready! Tap Initiate Promotion to ascend %s to %s rank.", recipient.DisplayName or "Hero", stars((recipient.Stars or 1) + 1)), C.Good
		end
	elseif status:find("complete") or status:find("Ascension") then
		color = C.Good
	end
	self.Status.Text = status
	self.Status.TextColor3 = color
end

function Promo.Celebrate(self: any)
	local flash = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 48,
	}, self.MainSlot)
	local tween = TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
end

--============================================================================
-- LIFECYCLE
--============================================================================

function Promo.Open(self: any)
	self.Root.Visible = true
	self.Scrim.Visible = true
	self.Picker.Visible = false
	self.Recipient = nil
	self.Preview = nil
	self.Message = ""
	self.Busy = false
	self.Loading = false
	self:Render()
	self:Refresh()
end

function Promo.Close(self: any)
	if self.Busy then return end
	self.Root.Visible = false
	self.Scrim.Visible = false
	self.Picker.Visible = false
	self.PreviewSerial += 1
	self.Loading = false
end

function Promo.IsOpen(self: any): boolean
	return self.Root.Visible
end

return Promo
