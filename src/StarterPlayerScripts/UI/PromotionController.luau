--!strict
-- StarterPlayerScripts/UI/PromotionController.luau
-- Dedicated Hero Promotion Ritual UI matching the Gothic Ascension Mockup and HTML specifications:
--   Palette: --ui-bg: rgba(17, 14, 23, 0.95), --ui-border: #c8a2c8, --ui-glow: rgba(200, 162, 200, 0.5),
--            --slot-bg: rgba(20, 20, 30, 0.6), --success-green: #39ff14
--   Layout:
--     1. Header: "HERO PROMOTION" (gothic title, wide letter-spacing, purple glow)
--     2. Ritual Area (320x320 circular layout):
--        - Outer dashed magic circle (280x280) with slow clockwise rotation
--        - Inner magic circle (190x190) with reverse counter-clockwise rotation
--        - Main Hero Center Slot (120x120) with "?" placeholder and intense glow
--        - 3 Orbiting Sacrifice Material Slots (75x75) at radius ~130px (Top, Bottom-Right, Bottom-Left)
--     3. Stats Display Panel:
--        - Left (Current): Max Level, HP, Base ATK, Gold Stars
--        - Center Arrow: "➔" with purple glow
--        - Right (Upgraded): Max Level, HP, Base ATK, Green Star in neon #39ff14
--     4. Action Area:
--        - "100% SUCCESS RATE" in neon green (#39ff14)
--        - Requirements / Costs indicator (Gold & Promotion Stones)
--        - "INITIATE PROMOTION" button with corner diamonds and gothic styling
--   Authoritative RemoteFunction: PitRequest (STATE -> PREVIEW -> COMMIT).

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local StatFormulas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("StatFormulas"))
local PitBalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PitBalanceConfig"))
local GothicBoxStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GothicBoxStyle"))

local Promo = {}
Promo.__index = Promo

local WIDTH, HEIGHT = 700, 740

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

local function cornerDiamonds(parent: GuiObject, size: number)
	-- Handled automatically by GothicBoxStyle
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or Enum.Font.GothamBold,
		TextWrapped = true,
		RichText = true,
	}, parent)
end

local function spaced(text: string): string
	return (text:gsub("(.)", "%1 "):sub(1, -2))
end

local function stars(n: number?): string
	return string.rep("★", math.clamp(n or 1, 1, 5))
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
	self.Donors = {}
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
		BackgroundTransparency = 0.35,
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
	local root = new("Frame", {
		Name = "HeroPromotionModal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		ZIndex = 40,
	}, gui)
	self.Root = root

	applyGothicStyle(root, "Window")

	self.Scale = new("UIScale", {}, root)

	-- Close Button (High contrast gothic rounded square with Latin 'X')
	local close = GothicBoxStyle.CreateCloseButton(root, function()
		if not self.Busy then
			self:Close()
		end
	end)

	-- Title: HERO PROMOTION
	local title = label(root, spaced("HERO PROMOTION"), 24, C.Text, Enum.Font.GothamBlack)
	title.Name = "Title"
	title.Position = UDim2.fromOffset(0, 24)
	title.Size = UDim2.new(1, 0, 0, 36)
	title.ZIndex = 42
	title.TextStrokeColor3 = C.Border
	title.TextStrokeTransparency = 0.45
	self.Title = title

	--========================================================================
	-- RITUAL AREA (Circular Layout 320x320)
	--========================================================================
	local ritualArea = new("Frame", {
		Name = "RitualArea",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.fromOffset(320, 320),
		BackgroundTransparency = 1,
		ZIndex = 42,
	}, root)
	self.RitualArea = ritualArea

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

	-- Main Hero Center Slot (120x120)
	local mainSlot = new("TextButton", {
		Name = "MainHeroSlot",
		Text = "",
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(120, 120),
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

	self.MainQuestion = label(mainSlot, "?", 54, C.Text, Enum.Font.GothamBlack)
	self.MainQuestion.Size = UDim2.fromScale(1, 1)
	self.MainQuestion.ZIndex = 45
	self.MainQuestion.TextStrokeColor3 = C.Border
	self.MainQuestion.TextStrokeTransparency = 0.5

	-- Main Slot Level/Max Pill Badge
	local mainBadge = new("Frame", {
		Name = "HeroBadge",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(90, 20),
		BackgroundColor3 = Color3.fromRGB(15, 12, 22),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 46,
	}, mainSlot)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, mainBadge)
	stroke(mainBadge, C.Border, 1, 0.3)
	self.MainBadge = mainBadge

	local mainBadgeText = label(mainBadge, "MAX LVL", 10, C.Text, Enum.Font.GothamBold)
	mainBadgeText.Size = UDim2.fromScale(1, 1)
	mainBadgeText.ZIndex = 47
	self.MainBadgeText = mainBadgeText

	mainSlot.Activated:Connect(function()
		self:OpenPicker("RECIPIENT")
	end)

	-- Orbiting Sacrifice Slots (Radius = 130px)
	-- Slot 1: Top (0°)
	-- Slot 2: Bottom Right (120°)
	-- Slot 3: Bottom Left (240°)
	self.SacrificeSlots = {}
	local slotPositions = {
		UDim2.new(0.5, 0, 0.5, -130),
		UDim2.new(0.5, 112, 0.5, 65),
		UDim2.new(0.5, -112, 0.5, 65),
	}

	for i = 1, 3 do
		local sacBtn = new("TextButton", {
			Name = "SacrificeSlot_" .. i,
			Text = "",
			AutoButtonColor = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = slotPositions[i],
			Size = UDim2.fromOffset(75, 75),
			BackgroundColor3 = C.SlotBg,
			BorderSizePixel = 0,
			ZIndex = 43,
		}, ritualArea)

		local sacStroke = stroke(sacBtn, C.SlotBorder, 1.5, 0.6)
		local sacInset = new("Frame", {
			Name = "Inset",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			ZIndex = 44,
		}, sacBtn)
		stroke(sacInset, C.Border, 1, 0.85)

		local sacHost = new("Frame", {
			Name = "PortraitHost",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			ZIndex = 44,
		}, sacBtn)

		local sacPlus = label(sacBtn, "+", 32, C.TextDim, Enum.Font.GothamMedium)
		sacPlus.Size = UDim2.fromScale(1, 1)
		sacPlus.ZIndex = 45

		local sacLevel = label(sacBtn, "", 10, C.Text, Enum.Font.GothamBold)
		sacLevel.AnchorPoint = Vector2.new(0.5, 1)
		sacLevel.Position = UDim2.new(0.5, 0, 1, -3)
		sacLevel.Size = UDim2.new(1, -4, 0, 14)
		sacLevel.ZIndex = 46
		sacLevel.Visible = false

		local slotIdx = i
		sacBtn.Activated:Connect(function()
			local donorUUID = self.Donors[slotIdx]
			if donorUUID then
				self:RemoveDonor(donorUUID)
			else
				if not self.Recipient then
					self.Message = "Select a main hero first."
					self:Render()
				else
					self:OpenPicker("DONOR")
				end
			end
		end)

		table.insert(self.SacrificeSlots, {
			Button = sacBtn,
			Stroke = sacStroke,
			Host = sacHost,
			Plus = sacPlus,
			Level = sacLevel,
		})
	end

	--========================================================================
	-- STATS DISPLAY PANEL (Before & After Stats Panel)
	--========================================================================
	local statsPanel = new("Frame", {
		Name = "StatsDisplay",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 404),
		Size = UDim2.fromOffset(620, 108),
		BackgroundColor3 = Color3.fromRGB(12, 10, 16),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 42,
	}, root)
	stroke(statsPanel, C.Border, 1, 0.7)

	-- Left Stat Block (Current)
	local leftBlock = new("Frame", {
		Name = "StatBlockOld",
		Position = UDim2.fromOffset(24, 10),
		Size = UDim2.fromOffset(220, 88),
		BackgroundTransparency = 1,
		ZIndex = 43,
	}, statsPanel)

	local function makeStatRow(parent: Instance, y: number, name: string)
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, y),
			BackgroundTransparency = 1,
			ZIndex = 43,
		}, parent)
		local nameLbl = label(row, name, 13, C.TextMuted, Enum.Font.GothamMedium)
		nameLbl.Size = UDim2.new(0.55, 0, 1, 0)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.ZIndex = 43
		local valLbl = label(row, "", 13, C.Text, Enum.Font.GothamBold)
		valLbl.Size = UDim2.new(0.45, 0, 1, 0)
		valLbl.Position = UDim2.new(0.55, 0, 0, 0)
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.ZIndex = 43
		return valLbl
	end

	self.OldMaxLevel = makeStatRow(leftBlock, 2, "Max Level")
	self.OldHP = makeStatRow(leftBlock, 22, "HP")
	self.OldATK = makeStatRow(leftBlock, 42, "Base ATK")
	self.OldStars = label(leftBlock, "★★★", 16, C.StarGold, Enum.Font.GothamBold)
	self.OldStars.Position = UDim2.fromOffset(0, 64)
	self.OldStars.Size = UDim2.new(1, 0, 0, 20)
	self.OldStars.TextXAlignment = Enum.TextXAlignment.Center
	self.OldStars.ZIndex = 43

	-- Center Arrow
	local arrow = label(statsPanel, "➔", 32, C.Border, Enum.Font.GothamBlack)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromScale(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(60, 40)
	arrow.ZIndex = 43
	arrow.TextStrokeColor3 = C.Border
	arrow.TextStrokeTransparency = 0.5
	self.Arrow = arrow

	-- Right Stat Block (Upgraded)
	local rightBlock = new("Frame", {
		Name = "StatBlockNew",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 10),
		Size = UDim2.fromOffset(220, 88),
		BackgroundTransparency = 1,
		ZIndex = 43,
	}, statsPanel)

	self.NewMaxLevel = makeStatRow(rightBlock, 2, "Max Level")
	self.NewMaxLevel.TextColor3 = C.SuccessGreen
	self.NewHP = makeStatRow(rightBlock, 22, "HP")
	self.NewHP.TextColor3 = C.SuccessGreen
	self.NewATK = makeStatRow(rightBlock, 42, "Base ATK")
	self.NewATK.TextColor3 = C.SuccessGreen
	self.NewStars = label(rightBlock, '★★★<font color="#39ff14">★</font>', 16, C.StarGold, Enum.Font.GothamBold)
	self.NewStars.Position = UDim2.fromOffset(0, 64)
	self.NewStars.Size = UDim2.new(1, 0, 0, 20)
	self.NewStars.TextXAlignment = Enum.TextXAlignment.Center
	self.NewStars.ZIndex = 43

	--========================================================================
	-- ACTION AREA (Success rate, costs, button, feedback)
	--========================================================================
	local actionArea = new("Frame", {
		Name = "ActionSection",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 528),
		Size = UDim2.new(1, 0, 0, 195),
		BackgroundTransparency = 1,
		ZIndex = 42,
	}, root)
	self.ActionArea = actionArea

	-- 100% SUCCESS RATE
	local rateLbl = label(actionArea, "100% SUCCESS RATE", 14, C.SuccessGreen, Enum.Font.GothamBlack)
	rateLbl.Position = UDim2.fromOffset(0, 0)
	rateLbl.Size = UDim2.new(1, 0, 0, 20)
	rateLbl.ZIndex = 43
	rateLbl.TextStrokeColor3 = C.SuccessGreen
	rateLbl.TextStrokeTransparency = 0.6
	self.RateLabel = rateLbl

	-- Requirements / Costs Label
	local costLbl = label(actionArea, "", 12, C.TextDim, Enum.Font.GothamBold)
	costLbl.Position = UDim2.fromOffset(0, 22)
	costLbl.Size = UDim2.new(1, 0, 0, 20)
	costLbl.ZIndex = 43
	self.CostLabel = costLbl

	-- Initiate Promotion Button (btn-action)
	local btnWidth, btnHeight = 480, 52
	local btn = new("TextButton", {
		Name = "InitiatePromotionButton",
		Text = spaced("INITIATE PROMOTION"),
		TextSize = 16,
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Text,
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 48),
		Size = UDim2.fromOffset(btnWidth, btnHeight),
		ZIndex = 43,
	}, actionArea)
	self.ConfirmButton = btn
	applyGothicStyle(btn, "Button")
	self.ConfirmStroke = btn:FindFirstChildOfClass("UIStroke")

	btn.Activated:Connect(function()
		self:Confirm()
	end)

	-- Status Feedback
	self.Status = label(actionArea, "", 13, C.TextDim, Enum.Font.GothamMedium)
	self.Status.Position = UDim2.fromOffset(30, 108)
	self.Status.Size = UDim2.new(1, -60, 0, 36)
	self.Status.ZIndex = 43

	-- Build Picker Overlay
	self:BuildPicker()

	-- Animated Magic Circles via RenderStepped
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

	-- Responsive Viewport Sizing
	local function resize()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local v = cam.ViewportSize
		self.Scale.Scale = math.clamp(math.min((v.X - 24) / WIDTH, (v.Y - 32) / HEIGHT), 0.45, 1)
	end
	local camConn: RBXScriptConnection? = nil
	local function track()
		if camConn then camConn:Disconnect() end
		if Workspace.CurrentCamera then
			camConn = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
		end
		resize()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(track)
	track()

	self:Render()
	return self
end

--============================================================================
-- HERO PICKER OVERLAY
--============================================================================

function Promo.BuildPicker(self: any)
	local picker = new("Frame", {
		Name = "HeroPickerOverlay",
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 1, -24),
		ZIndex = 60,
	}, self.Root)
	applyGothicStyle(picker, "Window")
	self.Picker = picker

	self.PickerTitle = label(picker, "", 18, C.Text, Enum.Font.GothamBlack)
	self.PickerTitle.Position = UDim2.fromOffset(0, 16)
	self.PickerTitle.Size = UDim2.new(1, 0, 0, 28)
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
	}, picker)
	back.Activated:Connect(function()
		picker.Visible = false
	end)

	self.PickerStatus = label(picker, "", 13, C.TextDim, Enum.Font.GothamMedium)
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
		for i = #self.Donors, 1, -1 do
			if not self.State.Heroes[self.Donors[i]] then
				table.remove(self.Donors, i)
			end
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
			Donors = table.clone(self.Donors),
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
			end
			self.Donors = {}
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

function Promo.RemoveDonor(self: any, uuid: string)
	local idx = table.find(self.Donors, uuid)
	if idx then
		table.remove(self.Donors, idx)
	end
	self.Message = ""
	self:QueuePreview()
end

function Promo.OpenPicker(self: any, mode: string)
	if self.Busy then return end
	self.PickerMode = mode
	if mode == "RECIPIENT" then
		self.PickerMessage = "Choose a hero at maximum level to promote."
	else
		local recipient = self.Recipient and self.State.Heroes[self.Recipient]
		local rank = recipient and recipient.Stars or 1
		self.PickerMessage = string.format("Sacrifice materials must be %s rank and will be consumed.", stars(rank))
	end
	self.Picker.Visible = true
	self:RenderPicker()
end

function Promo.Pick(self: any, uuid: string)
	local hero = self.State.Heroes[uuid]
	if not hero then return end
	if self.PickerMode == "RECIPIENT" then
		self.Recipient = uuid
		self.Donors = {}
	else
		if table.find(self.Donors, uuid) then return end
		if #self.Donors < 3 then
			table.insert(self.Donors, uuid)
		end
	end
	self.Message = ""
	self.Picker.Visible = false
	self:QueuePreview()
end

function Promo.RenderPicker(self: any)
	for _, child in self.PickerList:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local isDonorMode = self.PickerMode == "DONOR"
	local recipient = self.Recipient and self.State.Heroes[self.Recipient]

	if isDonorMode then
		self.PickerTitle.Text = spaced("SELECT SACRIFICE MATERIAL")
	else
		self.PickerTitle.Text = spaced("SELECT HERO TO PROMOTE")
	end
	self.PickerStatus.Text = self.PickerMessage or ""

	local heroes = {}
	for uuid, hero in self.State.Heroes do
		if isDonorMode then
			if uuid ~= self.Recipient and not table.find(self.Donors, uuid) then
				table.insert(heroes, hero)
			end
		else
			table.insert(heroes, hero)
		end
	end

	if isDonorMode then
		local targetRank = recipient and (recipient.Stars or 1) or 1
		table.sort(heroes, function(a, b)
			local aMatch = (a.Stars or 1) == targetRank
			local bMatch = (b.Stars or 1) == targetRank
			if aMatch ~= bMatch then return aMatch end
			local aOk = not a.PitStatus or a.PitStatus.EligibleDonor ~= false
			local bOk = not b.PitStatus or b.PitStatus.EligibleDonor ~= false
			if aOk ~= bOk then return aOk end
			return tostring(a.UUID) < tostring(b.UUID)
		end)
	else
		table.sort(heroes, function(a, b)
			local aMax = (a.Stars or 1) >= 5
			local bMax = (b.Stars or 1) >= 5
			if aMax ~= bMax then return not aMax end
			local aCap = (a.Level or 1) >= (a.Stars or 1) * 10
			local bCap = (b.Level or 1) >= (b.Stars or 1) * 10
			if aCap ~= bCap then return aCap end
			if (a.Stars or 1) ~= (b.Stars or 1) then return (a.Stars or 1) > (b.Stars or 1) end
			if (a.Level or 1) ~= (b.Level or 1) then return (a.Level or 1) > (b.Level or 1) end
			return tostring(a.UUID) < tostring(b.UUID)
		end)
	end

	if #heroes == 0 then
		local empty = label(self.PickerList, isDonorMode and "No matching sacrifice materials available." or "No heroes in roster.", 14, C.TextDim, Enum.Font.GothamMedium)
		empty.Size = UDim2.fromOffset(400, 40)
		empty.ZIndex = 62
	end

	for i, hero in heroes do
		local eligible = true
		local tagText: string? = nil
		if isDonorMode then
			local targetRank = recipient and (recipient.Stars or 1) or 1
			if (hero.Stars or 1) ~= targetRank then
				eligible = false
				tagText = "WRONG RANK"
			elseif hero.PitStatus and hero.PitStatus.EligibleDonor == false then
				eligible = false
				tagText = (hero.PitStatus.Status or "UNAVAILABLE"):upper()
			end
		else
			local isMax = (hero.Stars or 1) >= 5
			local isCapped = (hero.Level or 1) >= (hero.Stars or 1) * 10
			if isMax then
				eligible = false
				tagText = "MAX RANK"
			elseif not isCapped then
				eligible = false
				tagText = "NEED LV." .. ((hero.Stars or 1) * 10)
			end
		end

		local rarity = RARITY[math.clamp(hero.Stars or 1, 1, 5)]
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

		local name = label(tile, hero.DisplayName or "Hero", 13, eligible and rarity or C.TextDim)
		name.Position = UDim2.fromOffset(4, 94)
		name.Size = UDim2.new(1, -8, 0, 18)
		name.ZIndex = 63

		local info = label(tile, string.format("%s  Lv.%d", stars(hero.Stars), hero.Level or 1), 11, eligible and C.Text or C.TextDim, Enum.Font.GothamMedium)
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
			local tag = label(shade, tagText, 10, C.Danger)
			tag.Size = UDim2.new(1, 0, 0, 16)
			tag.Position = UDim2.fromOffset(0, 36)
			tag.ZIndex = 65
		end

		local uuid = hero.UUID
		tile.Activated:Connect(function()
			if isDonorMode and not eligible then return end
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

	-- 1. Main Recipient Center Slot
	self.MainPortraitHost:ClearAllChildren()
	if recipient then
		self.MainQuestion.Visible = false
		local p = HeroCard.Portrait(self.MainPortraitHost, recipient)
		p.ZIndex = 44
		local rarity = RARITY[math.clamp(recipient.Stars or 1, 1, 5)]
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

	-- 2. 3 Orbiting Sacrifice Slots
	for i = 1, 3 do
		local slotData = self.SacrificeSlots[i]
		local donorUUID = self.Donors[i]
		local donorHero = donorUUID and heroes[donorUUID]

		slotData.Host:ClearAllChildren()
		if donorHero then
			slotData.Plus.Visible = false
			local dp = HeroCard.Portrait(slotData.Host, donorHero)
			dp.ZIndex = 44
			local rarity = RARITY[math.clamp(donorHero.Stars or 1, 1, 5)]
			slotData.Stroke.Color = rarity
			slotData.Stroke.Transparency = 0.2
			slotData.Level.Visible = true
			slotData.Level.Text = string.format("Lv.%d", donorHero.Level or 1)
		else
			slotData.Plus.Visible = true
			slotData.Stroke.Color = C.SlotBorder
			slotData.Stroke.Transparency = 0.6
			slotData.Level.Visible = false
		end
	end

	-- 3. Stats Display Panel (Before & After Stats)
	local preview = self.Preview
	if recipient then
		local curStars = math.clamp(recipient.Stars or 1, 1, 4)
		local curMaxLvl = curStars * 10
		local nextMaxLvl = (curStars + 1) * 10

		local oldHP = math.floor(recipient.BaseHP or 1000)
		local oldATK = math.floor(recipient.BaseATK or 100)

		local newHP = preview and preview.After and preview.After.HP or math.round(oldHP * PitBalanceConfig.Promotion.CombatMultiplier)
		local newATK = preview and preview.After and preview.After.ATK or math.round(oldATK * PitBalanceConfig.Promotion.CombatMultiplier)

		self.OldMaxLevel.Text = tostring(curMaxLvl)
		self.OldHP.Text = formatNumber(oldHP)
		self.OldATK.Text = formatNumber(oldATK)
		self.OldStars.Text = string.rep("★", curStars)

		self.NewMaxLevel.Text = tostring(nextMaxLvl)
		self.NewHP.Text = formatNumber(newHP)
		self.NewATK.Text = formatNumber(newATK)
		self.NewStars.Text = string.format('%s<font color="#39ff14">★</font>', string.rep("★", curStars))
	else
		-- Example mockup display values when no hero is slotted
		self.OldMaxLevel.Text = "30"
		self.OldHP.Text = "1,250"
		self.OldATK.Text = "150"
		self.OldStars.Text = "★★★"

		self.NewMaxLevel.Text = "40"
		self.NewHP.Text = "1,850"
		self.NewATK.Text = "280"
		self.NewStars.Text = '★★★<font color="#39ff14">★</font>'
	end

	-- 4. Costs / Requirements Display
	local currencies = self.State.Currencies or {}
	local materials = self.State.Materials or self.State.PitMaterials or {}
	local goldOwned = currencies.Gold or 0
	local stonesOwned = materials.PromotionStone or 0

	if recipient then
		local rule = PitBalanceConfig.Promotion[recipient.Stars]
		local reqGold = rule and rule.Gold or 1500
		local reqStones = rule and rule.PromotionStone or 1

		local goldOk = goldOwned >= reqGold
		local stonesOk = stonesOwned >= reqStones

		local goldStr = string.format("GOLD: %s / %s %s", formatNumber(goldOwned), formatNumber(reqGold), goldOk and "✓" or "✗")
		local stoneStr = string.format("STONES: %s / %s %s", formatNumber(stonesOwned), formatNumber(reqStones), stonesOk and "✓" or "✗")

		self.CostLabel.Text = string.format(
			'<font color="%s">%s</font>      <font color="%s">%s</font>',
			goldOk and "#39ff14" or "#ff5f55",
			goldStr,
			stonesOk and "#39ff14" or "#ff5f55",
			stoneStr
		)
	else
		self.CostLabel.Text = string.format("GOLD OWNED: %s   ·   PROMOTION STONES: %s", formatNumber(goldOwned), formatNumber(stonesOwned))
	end

	-- 5. Action Button & Feedback Status
	local canCommit = preview ~= nil and preview.CanCommit == true and not self.Loading and not self.Busy
	local button = self.ConfirmButton
	if self.Busy then
		button.Text = spaced("PROMOTING…")
	else
		button.Text = spaced("INITIATE PROMOTION")
	end

	button.TextColor3 = (canCommit or self.Busy) and C.Text or Color3.fromRGB(120, 115, 135)
	if self.ConfirmStroke then
		self.ConfirmStroke.Color = canCommit and C.Border or Color3.fromRGB(80, 70, 95)
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
	self.Donors = {}
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
