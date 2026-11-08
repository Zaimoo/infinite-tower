--!strict
-- StarterPlayerScripts/UI/PromotionController.luau
-- Dedicated Hero Promotion Ritual UI (Promotion Stones + Gold only, 1★ -> 7★ Ascension):
--   Authoritative RemoteFunction: PitRequest (STATE -> PREVIEW -> COMMIT).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local ModalFit = require(script.Parent:WaitForChild("ModalFit"))
local UIAssets = require(script.Parent:WaitForChild("UIAssets"))
local UIFeel = require(script.Parent:WaitForChild("UIFeel"))
local StatFormulas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("StatFormulas"))
local PitBalanceConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PitBalanceConfig"))
local GothicBoxStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GothicBoxStyle"))
local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))

local Promo = {}
Promo.__index = Promo

local WIDE_SIZE = Vector2.new(744, 438)
local STACKED_SIZE = Vector2.new(400, 692)
local DETAILS_WIDTH = 352
local STONE_IMAGE = UIAssets.Images.PromotionStone
local ORBIT_PERIOD = 2.8
local HERO_CENTER = UDim2.fromScale(0.5, 0.5)
local FINAL_CHARGE_TIME = 0.16
local RANK_REVEAL_DELAY = 0.55

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
	if parent:FindFirstChildOfClass("UICorner") then
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, g)
	end
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
		Size = UDim2.fromOffset(WIDE_SIZE.X, WIDE_SIZE.Y),
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
	local title = label(root, "HERO PROMOTION", 30, C.Text, Enum.Font.GothamBlack)
	title.Name = "Title"
	title.Position = UDim2.fromOffset(48, 14)
	title.Size = UDim2.new(1, -96, 0, 40)
	title.ZIndex = 42
	goldText(title)
	self.Title = title

	--========================================================================
	-- RITUAL AREA (Circular Altar Layout — No Hero Sacrifices)
	--========================================================================
	local ritualArea = new("Frame", {
		Name = "RitualArea",
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(320, 280),
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

	-- Main hero model and rank
	local mainSlot = new("TextButton", {
		Name = "MainHeroSlot",
		Text = "",
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(164, 176),
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

	self.MainModelHost = new("Frame", {
		Name = "HeroModelHost",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -30),
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

	local mainRank = label(mainSlot, "", 21, C.StarGold, nil, "Number")
	mainRank.Name = "HeroStarRank"
	mainRank.Position = UDim2.new(0, -16, 0, -29)
	mainRank.Size = UDim2.new(1, 32, 0, 27)
	mainRank.ZIndex = 47
	self.MainRank = mainRank

	local heroName = label(ritualArea, "", 18, C.Text, nil, "Header")
	heroName.Name = "SelectedHeroName"
	heroName.Position = UDim2.new(0, 12, 1, -26)
	heroName.Size = UDim2.new(1, -24, 0, 24)
	heroName.RichText = false
	heroName.TextWrapped = false
	heroName.TextTruncate = Enum.TextTruncate.AtEnd
	heroName.ZIndex = 48
	self.HeroName = heroName

	mainSlot.Activated:Connect(function()
		self:OpenPicker()
	end)

	self.OrbitStones = table.create(5)
	for i = 1, 5 do
		self.OrbitStones[i] = new("ImageLabel", {
			Name = "OrbitStone" .. i,
			Image = STONE_IMAGE,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Visible = false,
		}, ritualArea)
	end

	--========================================================================
	-- STATS DISPLAY PANEL (Before & After Stats Panel)
	--========================================================================
	local statsPanel = new("Frame", {
		Name = "StatsDisplay",
		Size = UDim2.fromOffset(DETAILS_WIDTH, 136),
		BorderSizePixel = 0,
		ZIndex = 42,
	}, root)
	GildedGrimoire.Frame(statsPanel, { Class = "Panel", Tone = "Deep" })

	-- Left Stat Block (Current)
	local leftBlock = new("Frame", {
		Name = "StatBlockOld",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(136, 120),
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
		local nameLbl = label(row, name, 14, C.TextMuted, Enum.Font.GothamMedium, "Body")
		nameLbl.Size = UDim2.fromOffset(56, 24)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.ZIndex = 43
		local valLbl = label(row, "", 17, C.Text, Enum.Font.GothamBold, "Number")
		valLbl.Size = UDim2.new(1, -56, 1, 0)
		valLbl.Position = UDim2.fromOffset(56, 0)
		valLbl.TextWrapped = false
		valLbl.TextScaled = true
		new("UITextSizeConstraint", { MinTextSize = 10, MaxTextSize = 17 }, valLbl)
		valLbl.TextXAlignment = Enum.TextXAlignment.Right
		valLbl.ZIndex = 43
		return valLbl
	end

	local currentHeading = label(leftBlock, "CURRENT", 14, C.TextMuted, nil, "Header")
	currentHeading.Size = UDim2.new(1, 0, 0, 20)
	currentHeading.ZIndex = 43
	self.OldMaxLevel = makeStatRow(leftBlock, 22, "Level")
	self.OldHP = makeStatRow(leftBlock, 46, "HP")
	self.OldATK = makeStatRow(leftBlock, 70, "ATK")
	self.OldStars = label(leftBlock, "", 18, C.StarGold, Enum.Font.GothamBold)
	self.OldStars.Position = UDim2.fromOffset(0, 96)
	self.OldStars.Size = UDim2.new(1, 0, 0, 24)
	self.OldStars.TextXAlignment = Enum.TextXAlignment.Center
	self.OldStars.ZIndex = 43

	-- Center Arrow (Current Stats ➔ Upgraded Stats)
	self.Arrow = createRightArrow(statsPanel, UDim2.fromOffset(44, 32), UDim2.fromScale(0.5, 0.5), C.Border)

	-- Right Stat Block (Upgraded)
	local rightBlock = new("Frame", {
		Name = "StatBlockNew",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(136, 120),
		BackgroundTransparency = 1,
		ZIndex = 43,
	}, statsPanel)

	local previewHeading = label(rightBlock, "AFTER PROMOTION", 14, C.TextMuted, nil, "Header")
	previewHeading.Size = UDim2.new(1, 0, 0, 20)
	previewHeading.ZIndex = 43
	self.NewMaxLevel = makeStatRow(rightBlock, 22, "Level")
	self.NewMaxLevel.TextColor3 = C.SuccessGreen
	self.NewHP = makeStatRow(rightBlock, 46, "HP")
	self.NewHP.TextColor3 = C.SuccessGreen
	self.NewATK = makeStatRow(rightBlock, 70, "ATK")
	self.NewATK.TextColor3 = C.SuccessGreen
	self.NewStars = label(rightBlock, "", 18, C.StarGold, Enum.Font.GothamBold)
	self.NewStars.Position = UDim2.fromOffset(0, 96)
	self.NewStars.Size = UDim2.new(1, 0, 0, 24)
	self.NewStars.TextXAlignment = Enum.TextXAlignment.Center
	self.NewStars.ZIndex = 43

	--========================================================================
	-- ACTION AREA (Success rate, costs, button, feedback)
	--========================================================================
	local actionArea = new("Frame", {
		Name = "ActionSection",
		Size = UDim2.fromOffset(DETAILS_WIDTH, 188),
		BackgroundTransparency = 1,
		ZIndex = 42,
	}, root)
	self.ActionArea = actionArea

	local rateLbl = label(actionArea, "100% SUCCESS RATE", 16, C.SuccessGreen, Enum.Font.GothamBold)
	rateLbl.Position = UDim2.fromOffset(0, 0)
	rateLbl.Size = UDim2.new(1, 0, 0, 22)
	rateLbl.ZIndex = 43
	self.RateLabel = rateLbl

	local costLbl = label(actionArea, "", 15, C.TextMuted, Enum.Font.GothamBold, "Body")
	costLbl.Position = UDim2.fromOffset(0, 23)
	costLbl.Size = UDim2.new(1, 0, 0, 24)
	costLbl.ZIndex = 43
	self.CostLabel = costLbl

	local stoneCost = new("Frame", {
		Name = "PromotionStoneCost",
		Position = UDim2.fromOffset(0, 51),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = C.SlotBg,
		BorderSizePixel = 0,
		ZIndex = 43,
	}, actionArea)
	self.StoneCost = stoneCost
	new("UICorner", { CornerRadius = UDim.new(0, 7) }, stoneCost)
	self.StoneCostBorder = stroke(stoneCost, C.Border, 1.5, 0.25)
	new("ImageLabel", {
		Name = "StoneIcon",
		Image = STONE_IMAGE,
		ScaleType = Enum.ScaleType.Fit,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.fromOffset(38, 38),
		ZIndex = 44,
	}, stoneCost)
	local stoneCaption = label(stoneCost, "PROMOTION\nSTONES", 12, C.TextMuted, Enum.Font.GothamBold, "Body")
	self.StoneCaption = stoneCaption
	stoneCaption.Position = UDim2.fromOffset(52, 0)
	stoneCaption.Size = UDim2.fromOffset(102, 38)
	stoneCaption.TextXAlignment = Enum.TextXAlignment.Left
	stoneCaption.ZIndex = 44
	self.StoneCount = new("TextLabel", {
		Name = "StoneCount",
		Font = Enum.Font.GothamBlack,
		TextSize = 23,
		Text = "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(154, 0),
		Size = UDim2.new(1, -168, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 44,
	}, stoneCost)
	self.StoneCount:SetAttribute("Grimoire", true)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.fromRGB(9, 5, 14),
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = 3,
	}, self.StoneCount)

	local btn = new("TextButton", {
		Name = "InitiatePromotionButton",
		Text = "PROMOTE",
		TextSize = 22,
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Text,
		BackgroundColor3 = C.Bg,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 98),
		Size = UDim2.new(1, 0, 0, 46),
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

	self.Status = label(actionArea, "", 14, C.TextMuted, Enum.Font.GothamMedium, "Body")
	self.Status.Position = UDim2.fromOffset(6, 149)
	self.Status.Size = UDim2.new(1, -12, 0, 39)
	self.Status.ZIndex = 43

	self:BuildPicker()

	self.OuterAngle = 0
	self.InnerAngle = 0
	local ritualAnimation = RunService.RenderStepped:Connect(function(dt: number)
		if self.Root.Visible then
			self.OuterAngle = (self.OuterAngle + dt * 24) % 360
			self.InnerAngle = (self.InnerAngle - dt * 36) % 360
			self.OuterCircle.Rotation = self.OuterAngle
			self.InnerCircle.Rotation = self.InnerAngle
			if self.OrbitElapsed then
				self:UpdateStoneOrbit(dt)
			end
		end
	end)
	root.Destroying:Once(function()
		ritualAnimation:Disconnect()
	end)

	ModalFit.Bind(root, self.Scale, WIDE_SIZE.X, WIDE_SIZE.Y, {
		MaxScale = 1.25,
		DesignSize = function(available: Vector2): Vector2
			local wideScale = math.min(available.X / WIDE_SIZE.X, available.Y / WIDE_SIZE.Y)
			local stackedScale = math.min(available.X / STACKED_SIZE.X, available.Y / STACKED_SIZE.Y)
			if wideScale >= stackedScale then
				ritualArea.Position = UDim2.fromOffset(183, 85)
				statsPanel.Position = UDim2.fromOffset(366, 70)
				actionArea.Position = UDim2.fromOffset(366, 218)
				return WIDE_SIZE
			end
			ritualArea.Position = UDim2.fromOffset(STACKED_SIZE.X / 2, 62)
			statsPanel.Position = UDim2.fromOffset(24, 351)
			actionArea.Position = UDim2.fromOffset(24, 499)
			return STACKED_SIZE
		end,
	})

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
		if not self.Root.Visible or self.Busy then return end
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
		self.Message = "Choose a hero to promote."
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
	local recipientId = self.Recipient
	self:Render()
	task.spawn(function()
		-- Promotion consumes no donor heroes today, so the server never asks for rare confirmation here.
		-- Pass the preview's flag rather than a blanket true so the safeguard holds if that changes.
		local response = self:Request("COMMIT", { Token = preview.Token, ConfirmRare = preview.RequiresRareConfirmation == true })
		self.Preview = nil
		local revealRank = false
		if response.Success then
			local result = response.Result or {}
			local after = result.After
			local hero = self.State.Heroes[recipientId]
			local newStars = after and after.Stars or ((hero and hero.Stars or 1) + 1)
			local costs = result.Costs or preview.Costs
			local stoneCount = costs and costs.PromotionStone or 0
			if self.Root.Parent and self.Root.Visible and not UIFeel.ReducedMotion() then
				self:PlayAscension(stoneCount)
				revealRank = self.Root.Parent ~= nil and self.Root.Visible
			end
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
			if after and hero and not (delta and delta.Heroes and delta.Heroes[recipientId]) then
				local updated = table.clone(hero)
				updated.Stars, updated.Level, updated.XP, updated.Stats = newStars, after.Level, after.XP, after
				self.State.Heroes[recipientId] = updated
			end
		else
			self.Message = response.Message or "The promotion was rejected. Review requirements."
		end
		self.Busy = false
		if not self.Root.Parent then return end
		self:Render()
		if revealRank then UIFeel.Pop(self.MainRank, 0.3) end
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
	if self.Busy or not hero then return end
	self:StopStoneOrbit()
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

		local rarity = RARITY[math.clamp(StatFormulas.GetHeroRarity(hero), 1, #RARITY)]
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
	local selectedId = recipient and self.Recipient
	local templateId = recipient and recipient.TemplateId
	local portrait = recipient and recipient.Portrait
	if self.ModelRecipient ~= selectedId or self.ModelTemplate ~= templateId or self.ModelPortrait ~= portrait then
		self.ModelRecipient, self.ModelTemplate, self.ModelPortrait = selectedId, templateId, portrait
		self.MainModelHost:ClearAllChildren()
		if recipient then
			local view = HeroCard.Portrait(self.MainModelHost, recipient, true)
			view.ZIndex = 44
		end
	end
	self.MainRank.Visible = recipient ~= nil
	self.HeroName.Text = if recipient then recipient.DisplayName or "Hero" else "Select a hero"
	if recipient then
		self.MainQuestion.Visible = false
		local rarity = RARITY[math.clamp(StatFormulas.GetHeroRarity(recipient), 1, #RARITY)]
		self.MainStroke.Color = rarity
		self.MainRank.Text = stars(recipient.Stars)

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
		local curMaxLvl = recipient.Level or 1 -- promotion resets the hero to Lv 1 of the next star
		local nextMaxLvl = if curStars >= maxStars then curMaxLvl else 1

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
		self.OldMaxLevel.Text = "—"
		self.OldHP.Text = "—"
		self.OldATK.Text = "—"
		self.OldStars.Text = ""

		self.NewMaxLevel.Text = "—"
		self.NewHP.Text = "—"
		self.NewATK.Text = "—"
		self.NewStars.Text = ""
	end

	-- 3. Costs / Requirements Display
	local currencies = self.State.Currencies or {}
	local materials = self.State.Materials or self.State.PitMaterials or {}
	local goldOwned = currencies.Gold or 0
	local stonesOwned = materials.PromotionStone or 0

	local rule = recipient and PitBalanceConfig.Promotion[recipient.Stars]
	local atMaxRank = recipient ~= nil and (not rule or (recipient.Stars or 1) >= maxStars)
	if self.Root.Visible and rule and not atMaxRank and STONE_IMAGE ~= "" and not UIFeel.ReducedMotion() then
		if self.OrbitElapsed == nil then
			self.OrbitElapsed = 0
			self:UpdateStoneOrbit(0)
		end
	elseif self.OrbitElapsed then
		self:StopStoneOrbit()
	end
	self.StoneCost.Visible = not atMaxRank
	self.StoneCaption.Text = "PROMOTION\nSTONES"
	if atMaxRank then
		self.CostLabel.Text = '<font color="#39ff14">MAXIMUM CELESTIAL 7★ RANK ACHIEVED</font>'
	else
		local stoneColor = C.TextMuted
		if rule then
			local reqGold, reqStones = rule.Gold or 1500, rule.PromotionStone or 1
			self.CostLabel.Text = string.format(
				'<font color="%s">GOLD: %s / %s</font>',
				if goldOwned >= reqGold then "#39ff14" else "#ff5f55",
				formatNumber(goldOwned),
				formatNumber(reqGold)
			)
			self.StoneCount.Text = string.format("%s / %s", formatNumber(stonesOwned), formatNumber(reqStones))
			stoneColor = if stonesOwned >= reqStones then C.Good else C.Danger
		else
			self.CostLabel.Text = "GOLD OWNED: " .. formatNumber(goldOwned)
			self.StoneCount.Text = formatNumber(stonesOwned)
		end
		self.StoneCount.TextColor3 = stoneColor
		self.StoneCostBorder.Color = stoneColor
		self.StoneCost.BackgroundColor3 = C.SlotBg:Lerp(stoneColor, 0.12)
	end

	-- 4. Action Button & Feedback Status
	local canCommit = preview ~= nil and preview.CanCommit == true and not self.Loading and not self.Busy
	local button = self.ConfirmButton
	if self.Busy then
		button.Text = "PROMOTING…"
	else
		button.Text = "PROMOTE"
	end

	button.TextColor3 = (canCommit or self.Busy) and C.Text or Color3.fromRGB(206, 196, 226)
	button.TextTransparency = if canCommit or self.Busy then 0 else 0.15
	if self.ConfirmStroke then
		self.ConfirmStroke.Color = if canCommit then Color3.fromRGB(255, 226, 140) else Color3.fromRGB(150, 138, 176)
	end

	local status, color = self.Message, C.TextDim
	if self.Busy then
		status = "Channeling the promotion ritual…"
	elseif status == "" then
		if not recipient then
			status = "Choose a hero to promote."
		elseif self.Loading then
			status = "Evaluating ascension requirements…"
		elseif preview and not preview.CanCommit then
			status, color = preview.Reason or "Promotion requirements not met.", C.Danger
		elseif preview and preview.CanCommit then
			status, color = string.format("%s is ready to reach %d★.", recipient.DisplayName or "Hero", (recipient.Stars or 1) + 1), C.Good
		end
	elseif status:find("complete") or status:find("Ascension") then
		color = C.Good
	end
	self.Status.Text = status
	self.Status.TextColor3 = color
end

function Promo.StopStoneOrbit(self: any)
	self.OrbitElapsed = nil
	for _, stone in self.OrbitStones do
		stone.Visible = false
	end
end

function Promo.UpdateStoneOrbit(self: any, dt: number)
	local elapsed = (self.OrbitElapsed + dt) % ORBIT_PERIOD
	self.OrbitElapsed = elapsed
	for i, stone in self.OrbitStones do
		local angle = (elapsed / ORBIT_PERIOD + (i - 1) / #self.OrbitStones) * math.pi * 2
		local depth = math.sin(angle)
		local size = 35 + 10 * depth
		stone.Size = UDim2.fromOffset(size, size)
		stone.Position = UDim2.new(0.5, math.cos(angle) * 108, 0.5, depth * 58 + 18)
		stone.Rotation = math.cos(angle) * 16
		stone.ZIndex = if depth > 0 then 49 else 42
		stone.ImageTransparency = 0.15 - 0.15 * depth
		stone.Visible = true
	end
end

local function absorptionTime(index: number, count: number): number
	-- Let the first few stones read clearly, then pick up the pace for high-rank costs.
	return math.max(0.042, 0.38 / count ^ 0.65) + 0.23 * math.exp(-(index - 1) / 3.5)
end

function Promo.PlayAscension(self: any, count: number)
	local startAngle = (self.OrbitElapsed or 0) / ORBIT_PERIOD * math.pi * 2
	self:StopStoneOrbit()
	if count > 0 then
		local stone = new("ImageLabel", {
			Name = "AbsorbingStone",
			Image = STONE_IMAGE,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ZIndex = 50,
		}, self.RitualArea)
		self.StoneCaption.Text = "STONES\nABSORBED"
		self.StoneCount.Text = string.format("0 / %d", count)
		self.Status.Text = "The hero is absorbing Promotion Stones…"
		self.Status.TextColor3 = C.TextMuted

		local landed, elapsed, shakePhase = 0, 0, 0
		local duration = absorptionTime(1, count)
		while self.Root.Parent and self.Root.Visible do
			if landed == count and elapsed >= FINAL_CHARGE_TIME then break end

			local charge = landed / count
			local swing = 1.5 + 5 * charge
			self.MainSlot.Rotation = math.sin(shakePhase) * swing * charge
			self.MainSlot.Position = HERO_CENTER + UDim2.fromOffset(math.cos(shakePhase) * swing * charge, 0)
			stone.Visible = landed < count
			if stone.Visible then
				local angle = startAngle + landed * 2.4
				local progress = elapsed / duration
				local remaining = 1 - progress ^ 2
				local size = 16 + 26 * remaining
				stone.Position = HERO_CENTER + UDim2.fromOffset(math.cos(angle) * 108 * remaining, (math.sin(angle) * 58 + 18) * remaining)
				stone.Size = UDim2.fromOffset(size, size)
				stone.Rotation = math.cos(angle) * 16 + progress * 45
				stone.ImageTransparency = 0.55 * progress ^ 4
			end

			local dt = RunService.RenderStepped:Wait()
			elapsed += dt
			shakePhase += dt * (4 + 10 * charge) * math.pi * 2
			local previous = landed
			while landed < count and elapsed >= duration do
				elapsed -= duration
				landed += 1
				duration = absorptionTime(landed + 1, count)
			end
			if landed ~= previous then
				self.StoneCount.Text = string.format("%d / %d", landed, count)
			end
		end
		stone:Destroy()
		self.MainSlot.Position = HERO_CENTER
		self.MainSlot.Rotation = 0
	end

	if not self.Root.Parent or not self.Root.Visible then return end
	self:Celebrate()
	task.wait(RANK_REVEAL_DELAY)
end

function Promo.Celebrate(self: any)
	local burst = new("Frame", {
		Name = "AscensionFirework",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 51,
	}, self.RitualArea)
	local flash = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = HERO_CENTER,
		BackgroundColor3 = Color3.fromRGB(255, 241, 201),
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(68, 68),
		ZIndex = 52,
	}, burst)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, flash)
	UIFeel.Tween(flash, 0.32, { Size = UDim2.fromOffset(206, 206), BackgroundTransparency = 1 }, Enum.EasingStyle.Quart)
	task.wait(0.07)
	if not burst.Parent then return end
	UIFeel.Burst(burst, HERO_CENTER, C.StarGold, 12, 53, 125)
	for i = 1, 16 do
		local angle = i * math.pi / 8
		local radius = if i % 2 == 0 then 124 else 91
		local star = new("TextLabel", {
			Name = "FireworkStar",
			Text = "★",
			Font = Enum.Font.GothamBlack,
			TextSize = if i % 2 == 0 then 27 else 19,
			TextColor3 = if i % 2 == 0 then C.StarGold else Color3.fromRGB(238, 177, 255),
			TextStrokeColor3 = C.SlotBg,
			TextStrokeTransparency = 0.3,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = HERO_CENTER,
			Size = UDim2.fromOffset(36, 36),
			ZIndex = 54,
		}, burst)
		star:SetAttribute("Grimoire", true)
		local x, y = math.cos(angle) * radius, math.sin(angle) * radius
		UIFeel.Tween(star, 0.43, { Position = HERO_CENTER + UDim2.fromOffset(x, y), Rotation = x * 0.7 }, Enum.EasingStyle.Quart)
		UIFeel.Tween(star, 0.84, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	task.delay(0.9, function()
		burst:Destroy()
	end)
end

--============================================================================
-- LIFECYCLE
--============================================================================

function Promo.Open(self: any)
	if self.Busy then return end
	if _G.SetModalFocusMode then
		_G.SetModalFocusMode(true)
	end
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
	if _G.SetModalFocusMode then
		_G.SetModalFocusMode(false)
	end
	self:StopStoneOrbit()
	local firework = self.RitualArea:FindFirstChild("AscensionFirework")
	if firework then firework:Destroy() end
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
