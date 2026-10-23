--!strict
-- StarterPlayerScripts/UI/FacilityController.luau
-- Authoritative Facility HUD featuring:
--   1. HERO BANNER & ARTIFACT BANNER SUMMONING (Call of the Rift & Echoes of the Rift)
--   2. Dynamic 50-pull pity tracking, 1X & 10X summons, rate-up hero highlights
--   3. Summon Celebration Reveal Modal
--   4. Full backward-compatibility for Infirmary & Squad Management
-- Matches the exact cosmic purple aesthetic with corner diamond accents, glowing borders, and responsive scaling.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local GothicBoxStyle = require(Shared:WaitForChild("Util"):WaitForChild("GothicBoxStyle"))

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
local ArtifactRemotes = RemotesFolder:FindFirstChild("ArtifactRemotes") :: Folder?

local Controller = {}
Controller.__index = Controller

local WIDTH, HEIGHT = 760, 520

local C = {
	Scrim = Color3.fromRGB(6, 5, 10),
	Panel = Color3.fromRGB(15, 13, 22),
	PanelInner = Color3.fromRGB(20, 17, 30),
	CardBg = Color3.fromRGB(24, 21, 40),
	SlotBg = Color3.fromRGB(18, 15, 26),
	StatBoxBg = Color3.fromRGB(12, 10, 18),
	Border = Color3.fromRGB(192, 132, 252),
	BorderGlow = Color3.fromRGB(175, 115, 215),
	BorderDim = Color3.fromRGB(58, 48, 75),
	BorderCard = Color3.fromRGB(59, 45, 84),
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(155, 145, 175),
	TextLavender = Color3.fromRGB(180, 175, 205),
	GoldYellow = Color3.fromRGB(250, 204, 21),
	Green = Color3.fromRGB(74, 222, 128),
	Red = Color3.fromRGB(239, 68, 68),
	Arrow = Color3.fromRGB(140, 130, 160),
	Underline = Color3.fromRGB(225, 150, 245),
}

local ARCHETYPE_ICONS: { [string]: string } = {
	Vanguard = "🛡️",
	Striker = "⚔️",
	Marksman = "🏹",
	Scholar = "🔮",
	Healer = "💚",
	Miner = "⛏️",
}

local ARTIFACT_ICONS: { [string]: string } = {
	BOW = "🏹",
	SWORD = "⚔️",
	DAGGERS = "🗡️",
	AXE = "🪓",
	TOME = "📖",
	STAFF = "🪄",
	RING = "💍",
	SHIELD = "🛡️",
}

local DETAILS = {
	Summoning = { Title = "SUMMONING", Description = "Call legendary heroes through the dimensional rift.", Color = Color3.fromRGB(192, 132, 252) },
	Infirmary = { Title = "INFIRMARY & BARRACKS", Description = "Rest wounded heroes, restore stamina, and clear coma. Resting Healers grant a +50% recovery aura.", Color = Color3.fromRGB(100, 232, 175) },
	SquadManagement = { Title = "SQUAD MANAGEMENT", Description = "Deploy rested heroes and bench your current squad.", Color = Color3.fromRGB(245, 128, 99) },
	GuardPost = { Title = "OUTSKIRTS GUARD POST", Description = "Station Adventurers along the southern trail to defend the outskirts and generate passive Gold online & offline.", Color = Color3.fromRGB(130, 205, 95) },
	Market = { Title = "THE MARKET", Description = "Station Merchants to multiply Infinite Tower mob/boss loot drops and cargo extraction banking.", Color = Color3.fromRGB(245, 195, 75) },
	TrainingGrounds = { Title = "TRAINING GROUNDS", Description = "Station Trainers to run martial combat drills, multiplying overall squad Final ATK and Final HP.", Color = Color3.fromRGB(235, 80, 80) },
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
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
	stroke(g, color or C.BorderGlow, 3, transparency or 0.8)
end

local function applyGothicStyle(container: GuiObject, style: "Window" | "Card" | "Button" | "Compact")
	return GothicBoxStyle.Apply(container, { Style = style })
end

local function cornerDiamonds(parent: GuiObject, size: number, color: Color3?)
	-- Styled automatically by GothicBoxStyle
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, size + 8),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
	}, parent)
end

--============================================================================
-- CONSTRUCTOR
--============================================================================

function Controller.new(gui: ScreenGui, getProfile: () -> any, remotes: Instance)
	local self: any = setmetatable({}, Controller)
	self.GetProfile = getProfile
	self.Busy = false
	self.LastSummoned = {}
	self.Current = "Summoning"
	self.ActiveSummonTab = "CALL_OF_THE_RIFT" -- "CALL_OF_THE_RIFT" | "A_STARS_ARRIVAL"

	-- Remotes
	self.Summon = remotes:WaitForChild("RequestSummon") :: RemoteFunction
	self.Assign = remotes:WaitForChild("AssignHeroRole") :: RemoteFunction
	self.Facility = remotes:WaitForChild("FacilityInteract") :: RemoteEvent

	if ArtifactRemotes then
		self.RequestSummonArtifact = ArtifactRemotes:FindFirstChild("RequestSummonArtifact") :: RemoteFunction?
	end

	-- 1. Scrim Background (dims world)
	self.Scrim = new("TextButton", {
		Name = "FacilityScrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 50,
	}, gui)
	self.Scrim.Activated:Connect(function()
		if not self.Busy then
			self:Close()
		end
	end)

	-- 2. Modal Frame (Ornate Gothic Box Container)
	local root = new("Frame", {
		Name = "FacilityModal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 51,
	}, gui)
	self.Root = root

	applyGothicStyle(root, "Window")
	self.Stroke = root:FindFirstChildOfClass("UIStroke")

	self.Scale = new("UIScale", {}, root)

	-- 3. Close Button (High contrast gothic rounded square with Latin 'X')
	local closeBtn = GothicBoxStyle.CreateCloseButton(root, function()
		if not self.Busy then
			self:Close()
		end
	end)

	-- 4. Currency / Gems Indicator in Top Bar
	local gemCurrency = label(root, "💎 0", 14, C.GoldYellow, Enum.Font.GothamBold)
	gemCurrency.Name = "GemCurrency"
	gemCurrency.AnchorPoint = Vector2.new(1, 0)
	gemCurrency.Position = UDim2.new(1, -56, 0, 20)
	gemCurrency.Size = UDim2.new(0, 180, 0, 22)
	gemCurrency.TextXAlignment = Enum.TextXAlignment.Right
	self.GemCurrency = gemCurrency

	-- 5. Top Tab Container (CALL OF THE RIFT | A STAR'S ARRIVAL)
	local tabContainer = new("Frame", {
		Name = "TabContainer",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -260, 0, 44),
		ZIndex = 52,
	}, root)
	self.TabContainer = tabContainer

	local callTabBtn = new("TextButton", {
		Name = "TabCallOfTheRift",
		Text = "CALL OF THE RIFT",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.Text,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(165, 36),
		Position = UDim2.fromOffset(10, 0),
		ZIndex = 53,
	}, tabContainer)

	local starTabBtn = new("TextButton", {
		Name = "TabAStarsArrival",
		Text = "A STAR'S ARRIVAL",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(165, 36),
		Position = UDim2.fromOffset(185, 0),
		ZIndex = 53,
	}, tabContainer)

	local activeIndicator = new("Frame", {
		Name = "ActiveTabIndicator",
		BackgroundColor3 = C.Underline,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 130, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(92, 36),
		ZIndex = 54,
	}, tabContainer)
	stroke(activeIndicator, C.BorderGlow, 1.5, 0.4)

	self.CallTabBtn = callTabBtn
	self.StarTabBtn = starTabBtn
	self.ActiveIndicator = activeIndicator

	callTabBtn.Activated:Connect(function()
		self:SetSummonTab("CALL_OF_THE_RIFT")
	end)
	starTabBtn.Activated:Connect(function()
		self:SetSummonTab("A_STARS_ARRIVAL")
	end)

	-- Header Title (Fallback for non-summon facilities like Infirmary / Squad)
	local headerTitle = label(root, "SUMMONING", 20, C.Text, Enum.Font.GothamBold)
	headerTitle.Name = "FacilityHeaderTitle"
	headerTitle.Position = UDim2.fromOffset(24, 18)
	headerTitle.Size = UDim2.new(1, -260, 0, 26)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Visible = false
	self.HeaderTitle = headerTitle

	-- Tab Divider line
	local tabDivider = new("Frame", {
		Name = "TabDivider",
		BackgroundColor3 = C.BorderDim,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 1),
		ZIndex = 52,
	}, root)
	self.TabDivider = tabDivider

	-- 6. Summon Views (Permanent 5-Star Banner & Limited 7-Star Banner)
	self:BuildPermanentSummonView(root)
	self:BuildLimitedSummonView(root)

	-- 7. Legacy / General Facility View (Infirmary, SquadManagement fallback)
	self:BuildGeneralFacilityView(root)

	-- 8. Summon Reveal Modal
	self:BuildSummonRevealModal(gui)

	-- Responsive scale tracking
	local function resize()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local v = cam.ViewportSize
		self.Scale.Scale = math.clamp(math.min((v.X - 20) / WIDTH, (v.Y - 40) / HEIGHT), 0.45, 1)
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

	return self
end

--============================================================================
-- SECTION 1: PERMANENT BANNER VIEW ("CALL OF THE RIFT" - 5 STARS)
--============================================================================

function Controller:BuildPermanentSummonView(root: Frame)
	local permView = new("Frame", {
		Name = "PermanentSummonView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 1, -82),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.PermanentSummonView = permView

	-- 1. Main Featured Banner Card
	local bannerCard = new("Frame", {
		Name = "PermanentBannerCard",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 246),
		BackgroundColor3 = Color3.fromRGB(19, 14, 34),
		BorderSizePixel = 0,
		ZIndex = 53,
	}, permView)

	applyGothicStyle(bannerCard, "Card")

	-- Cosmic Indigo Gradient
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(28, 19, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 14, 36)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(12, 9, 22)),
		}),
		Rotation = 35,
	}, bannerCard)

	-- Top Watermark
	local watermark = label(bannerCard, "★ 5-STAR PERMANENT HERO BANNER", 15, Color3.fromRGB(230, 220, 255), Enum.Font.GothamBold)
	watermark.TextTransparency = 0.55
	watermark.Position = UDim2.fromOffset(24, 18)
	watermark.Size = UDim2.new(1, -48, 0, 20)
	watermark.TextXAlignment = Enum.TextXAlignment.Left

	-- Big Glowing Banner Title
	local bannerTitle = label(bannerCard, "CALL OF THE RIFT", 36, C.GoldYellow, Enum.Font.GothamBlack)
	bannerTitle.AnchorPoint = Vector2.new(0, 0.5)
	bannerTitle.Position = UDim2.new(0, 24, 0.48, -4)
	bannerTitle.Size = UDim2.new(1, -48, 0, 44)
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Left
	bannerTitle.TextStrokeTransparency = 0.35
	bannerTitle.TextStrokeColor3 = Color3.fromRGB(120, 80, 0)

	-- Hero Pool Available Badge
	local poolLabel = label(bannerCard, "★ Available Roster: Ignis (5★) • Valeria (4★) • Catio (3★) • Aaron (2★) • Han (1★)", 13, Color3.fromRGB(215, 185, 255), Enum.Font.GothamBold)
	poolLabel.AnchorPoint = Vector2.new(0, 1)
	poolLabel.Position = UDim2.new(0, 24, 1, -22)
	poolLabel.Size = UDim2.new(1, -48, 0, 22)
	poolLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- 2. Info Row (Guaranteed 5★ Pity & Permanent Tag)
	local infoRow = new("Frame", {
		Name = "PermanentInfoRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 258),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 53,
	}, permView)

	local pityLabel = label(infoRow, "Guaranteed 5-Star in: <b>42</b> summons", 14, C.TextLavender, Enum.Font.GothamMedium)
	pityLabel.Position = UDim2.fromOffset(6, 4)
	pityLabel.Size = UDim2.new(0.5, 0, 0, 20)
	pityLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.PermanentPityLabel = pityLabel

	local timerLabel = label(infoRow, "Event: Permanent Banner", 14, C.TextLavender, Enum.Font.GothamMedium)
	timerLabel.AnchorPoint = Vector2.new(1, 0)
	timerLabel.Position = UDim2.new(1, -6, 0, 4)
	timerLabel.Size = UDim2.new(0.5, 0, 0, 20)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- 3. Summon Buttons Container (100 / 900 Gems)
	local btnRow = new("Frame", {
		Name = "PermanentButtonRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 296),
		Size = UDim2.new(1, 0, 0, 76),
		ZIndex = 53,
	}, permView)

	-- SUMMON 1X Button (100 Gems)
	local btn1X = new("TextButton", {
		Name = "PermSummon1XBtn",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(0.485, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(22, 18, 36),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 54,
	}, btnRow)
	applyGothicStyle(btn1X, "Button")

	local t1X = label(btn1X, "SUMMON 1X", 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	t1X.AnchorPoint = Vector2.new(0.5, 0.5)
	t1X.Position = UDim2.new(0.5, 0, 0.34, 0)
	t1X.Size = UDim2.new(1, 0, 0, 20)
	t1X.ZIndex = 56

	local c1X = label(btn1X, "💎 100", 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	c1X.AnchorPoint = Vector2.new(0.5, 0.5)
	c1X.Position = UDim2.new(0.5, 0, 0.72, 0)
	c1X.Size = UDim2.new(1, 0, 0, 20)
	c1X.ZIndex = 56

	btn1X.Activated:Connect(function()
		self:PerformSummon("CALL_OF_THE_RIFT", 1)
	end)

	-- SUMMON 10X Button (900 Gems)
	local btn10X = new("TextButton", {
		Name = "PermSummon10XBtn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.485, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(22, 18, 36),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 54,
	}, btnRow)
	applyGothicStyle(btn10X, "Button")

	local t10X = label(btn10X, "SUMMON 10X", 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	t10X.AnchorPoint = Vector2.new(0.5, 0.5)
	t10X.Position = UDim2.new(0.5, 0, 0.34, 0)
	t10X.Size = UDim2.new(1, 0, 0, 20)
	t10X.ZIndex = 56

	local c10X = label(btn10X, "💎 900", 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	c10X.AnchorPoint = Vector2.new(0.5, 0.5)
	c10X.Position = UDim2.new(0.5, 0, 0.72, 0)
	c10X.Size = UDim2.new(1, 0, 0, 20)
	c10X.ZIndex = 56

	btn10X.Activated:Connect(function()
		self:PerformSummon("CALL_OF_THE_RIFT", 10)
	end)
end

--============================================================================
-- SECTION 2: LIMITED BANNER VIEW ("A STAR'S ARRIVAL" - 1★ TO 7★)
--============================================================================

function Controller:BuildLimitedSummonView(root: Frame)
	local limView = new("Frame", {
		Name = "LimitedSummonView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 1, -82),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.LimitedSummonView = limView

	-- 1. Main Featured Banner Card
	local bannerCard = new("Frame", {
		Name = "LimitedBannerCard",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 246),
		BackgroundColor3 = Color3.fromRGB(24, 16, 38),
		BorderSizePixel = 0,
		ZIndex = 53,
	}, limView)

	applyGothicStyle(bannerCard, "Card")

	-- Celestial Gold / Amethyst Gradient
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(44, 25, 68)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(28, 16, 44)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(14, 10, 24)),
		}),
		Rotation = 35,
	}, bannerCard)

	-- Top Watermark
	local watermark = label(bannerCard, "★ 7-STAR LIMITED RATE-UP EVENT", 15, Color3.fromRGB(255, 235, 180), Enum.Font.GothamBold)
	watermark.TextTransparency = 0.50
	watermark.Position = UDim2.fromOffset(24, 18)
	watermark.Size = UDim2.new(1, -48, 0, 20)
	watermark.TextXAlignment = Enum.TextXAlignment.Left

	-- Big Glowing Banner Title
	local bannerTitle = label(bannerCard, "A STAR'S ARRIVAL", 36, Color3.fromRGB(255, 220, 100), Enum.Font.GothamBlack)
	bannerTitle.AnchorPoint = Vector2.new(0, 0.5)
	bannerTitle.Position = UDim2.new(0, 24, 0.48, -4)
	bannerTitle.Size = UDim2.new(1, -48, 0, 44)
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Left
	bannerTitle.TextStrokeTransparency = 0.35
	bannerTitle.TextStrokeColor3 = Color3.fromRGB(140, 85, 10)

	-- Featured Rate-Up Pill Label (1★ to 7★)
	local rateUpLabel = label(bannerCard, "★ Featured Roster: Astrea (7★) • Solaris (6★) • Archon (5★) • Morrigan (4★) • Eolka (3★) • Velkist (2★) • Jenna (1★)", 12, Color3.fromRGB(255, 215, 150), Enum.Font.GothamBold)
	rateUpLabel.AnchorPoint = Vector2.new(0, 1)
	rateUpLabel.Position = UDim2.new(0, 24, 1, -22)
	rateUpLabel.Size = UDim2.new(1, -48, 0, 22)
	rateUpLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- 2. Info Row (Guaranteed 7★ Pity & Timer)
	local infoRow = new("Frame", {
		Name = "LimitedInfoRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 258),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 53,
	}, limView)

	local pityLabel = label(infoRow, "Guaranteed 7-Star in: <b>42</b> summons", 14, Color3.fromRGB(255, 230, 180), Enum.Font.GothamMedium)
	pityLabel.Position = UDim2.fromOffset(6, 4)
	pityLabel.Size = UDim2.new(0.5, 0, 0, 20)
	pityLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.LimitedPityLabel = pityLabel

	local timerLabel = label(infoRow, "Event Ends: 14d 00h", 14, Color3.fromRGB(255, 205, 130), Enum.Font.GothamMedium)
	timerLabel.AnchorPoint = Vector2.new(1, 0)
	timerLabel.Position = UDim2.new(1, -6, 0, 4)
	timerLabel.Size = UDim2.new(0.5, 0, 0, 20)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- 3. Summon Buttons Container (100 / 900 Gems)
	local btnRow = new("Frame", {
		Name = "LimitedButtonRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 296),
		Size = UDim2.new(1, 0, 0, 76),
		ZIndex = 53,
	}, limView)

	-- SUMMON 1X Button (100 Gems)
	local btn1X = new("TextButton", {
		Name = "LimSummon1XBtn",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(0.485, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(22, 18, 36),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 54,
	}, btnRow)
	applyGothicStyle(btn1X, "Button")

	local t1X = label(btn1X, "SUMMON 1X", 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	t1X.AnchorPoint = Vector2.new(0.5, 0.5)
	t1X.Position = UDim2.new(0.5, 0, 0.34, 0)
	t1X.Size = UDim2.new(1, 0, 0, 20)
	t1X.ZIndex = 56

	local c1X = label(btn1X, "💎 100", 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	c1X.AnchorPoint = Vector2.new(0.5, 0.5)
	c1X.Position = UDim2.new(0.5, 0, 0.72, 0)
	c1X.Size = UDim2.new(1, 0, 0, 20)
	c1X.ZIndex = 56

	btn1X.Activated:Connect(function()
		self:PerformSummon("A_STARS_ARRIVAL", 1)
	end)

	-- SUMMON 10X Button (900 Gems)
	local btn10X = new("TextButton", {
		Name = "LimSummon10XBtn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.485, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(22, 18, 36),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 54,
	}, btnRow)
	applyGothicStyle(btn10X, "Button")

	local t10X = label(btn10X, "SUMMON 10X", 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	t10X.AnchorPoint = Vector2.new(0.5, 0.5)
	t10X.Position = UDim2.new(0.5, 0, 0.34, 0)
	t10X.Size = UDim2.new(1, 0, 0, 20)
	t10X.ZIndex = 56

	local c10X = label(btn10X, "💎 900", 15, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	c10X.AnchorPoint = Vector2.new(0.5, 0.5)
	c10X.Position = UDim2.new(0.5, 0, 0.72, 0)
	c10X.Size = UDim2.new(1, 0, 0, 20)
	c10X.ZIndex = 56

	btn10X.Activated:Connect(function()
		self:PerformSummon("A_STARS_ARRIVAL", 10)
	end)
end

--============================================================================
-- LEGACY / GENERAL FACILITY VIEW (Infirmary, SquadManagement fallback)
--============================================================================

function Controller:BuildGeneralFacilityView(root: Frame)
	local generalView = new("Frame", {
		Name = "GeneralFacilityView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 1, -82),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.GeneralFacilityView = generalView

	self.Title = label(generalView, "FacilityTitle", 18, C.Text, Enum.Font.GothamBold)
	self.Title.Position = UDim2.fromOffset(12, 0)
	self.Title.Size = UDim2.new(1, -24, 0, 24)
	self.Title.TextXAlignment = Enum.TextXAlignment.Left

	self.Description = label(generalView, "Description", 13, C.TextMuted, Enum.Font.GothamMedium)
	self.Description.Position = UDim2.fromOffset(12, 26)
	self.Description.Size = UDim2.new(1, -24, 0, 20)
	self.Description.TextXAlignment = Enum.TextXAlignment.Left

	self.Summary = label(generalView, "Summary", 14, C.TextLavender, Enum.Font.GothamMedium)
	self.Summary.Position = UDim2.fromOffset(12, 50)
	self.Summary.Size = UDim2.new(1, -24, 0, 22)
	self.Summary.TextXAlignment = Enum.TextXAlignment.Left

	self.Actions = new("Frame", {
		Name = "FacilityActions",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 80),
		Size = UDim2.new(1, -24, 0, 44),
		ZIndex = 53,
	}, generalView)

	self.List = new("ScrollingFrame", {
		Name = "HeroList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 136),
		Size = UDim2.new(1, -24, 1, -176),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 53,
	}, generalView)

	local layout = new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.List)

	self.Status = label(generalView, "", 13, C.TextMuted, Enum.Font.GothamMedium)
	self.Status.Position = UDim2.new(0, 12, 1, -30)
	self.Status.Size = UDim2.new(1, -24, 0, 24)
	self.Status.TextXAlignment = Enum.TextXAlignment.Left
end

--============================================================================
-- SUMMON REVEAL CELEBRATION MODAL
--============================================================================

function Controller:BuildSummonRevealModal(gui: ScreenGui)
	local revealScrim = new("TextButton", {
		Name = "SummonRevealScrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 80,
	}, gui)
	self.RevealScrim = revealScrim

	local modal = new("Frame", {
		Name = "SummonRevealModal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(680, 440),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 81,
	}, revealScrim)
	self.RevealModal = modal

	applyGothicStyle(modal, "Window")

	local revealTitle = label(modal, "✨ DIMENSIONAL HEROES SUMMONED", 20, C.GoldYellow, Enum.Font.GothamBlack)
	revealTitle.Position = UDim2.new(0, 0, 0, 20)
	revealTitle.Size = UDim2.new(1, 0, 0, 28)
	self.RevealTitle = revealTitle

	local cardScroll = new("ScrollingFrame", {
		Name = "RevealScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(24, 64),
		Size = UDim2.new(1, -48, 1, -140),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0, 0),
		ZIndex = 82,
	}, modal)
	self.RevealScroll = cardScroll

	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, cardScroll)

	local collectBtn = new("TextButton", {
		Name = "CollectBtn",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(220, 42),
		BackgroundColor3 = Color3.fromRGB(28, 22, 44),
		BorderSizePixel = 0,
		Text = "COLLECT & CONTINUE",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.GoldYellow,
		ZIndex = 82,
	}, modal)
	applyGothicStyle(collectBtn, "Button")

	collectBtn.Activated:Connect(function()
		self.RevealScrim.Visible = false
	end)
end

function Controller:ShowSummonResults(summonedList: { any }, isArtifact: boolean?)
	for _, child in self.RevealScroll:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	self.RevealTitle.Text = isArtifact and "✨ DIMENSIONAL ARTIFACTS SUMMONED" or "✨ DIMENSIONAL HEROES SUMMONED"

	for order, item in ipairs(summonedList) do
		local card = new("Frame", {
			Name = "ResultCard_" .. order,
			Size = UDim2.new(1, 0, 0, 72),
			BackgroundColor3 = C.CardBg,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 83,
		}, self.RevealScroll)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, card)
		stroke(card, C.BorderCard, 1)

		if isArtifact then
			local art = item
			local iconChar = ARTIFACT_ICONS[art.Type] or "⚔️"
			local iconTile = new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(48, 48),
				BackgroundColor3 = Color3.fromRGB(18, 15, 28),
				BorderSizePixel = 0,
				ZIndex = 84,
			}, card)
			new("UICorner", { CornerRadius = UDim.new(0, 6) }, iconTile)
			stroke(iconTile, C.BorderCard)

			local iconLbl = label(iconTile, iconChar, 22, C.Text)
			iconLbl.Position = UDim2.fromScale(0, 0)
			iconLbl.Size = UDim2.fromScale(1, 1)
			iconLbl.TextXAlignment = Enum.TextXAlignment.Center

			local stars = string.rep("★", art.Star or 1)
			local nameText = string.format("%s  <font color=\"#FACC15\">%s</font>", art.DisplayName or "Artifact", stars)
			local nameLbl = label(card, nameText, 15, C.Text, Enum.Font.GothamBold)
			nameLbl.Position = UDim2.fromOffset(72, 12)
			nameLbl.Size = UDim2.new(1, -90, 0, 22)
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left

			local subText = string.format("Level +%d  •  Tier %d  •  Equippable Weapon", art.Level or 0, art.Rarity or 1)
			local subLbl = label(card, subText, 13, C.TextLavender, Enum.Font.GothamMedium)
			subLbl.Position = UDim2.fromOffset(72, 36)
			subLbl.Size = UDim2.new(1, -90, 0, 18)
			subLbl.TextXAlignment = Enum.TextXAlignment.Left
		else
			local hero = item
			local archetype = hero.Archetype or "Striker"
			local iconChar = ARCHETYPE_ICONS[archetype] or "⚔️"

			local iconTile = new("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(48, 48),
				BackgroundColor3 = Color3.fromRGB(18, 15, 28),
				BorderSizePixel = 0,
				ZIndex = 84,
			}, card)
			new("UICorner", { CornerRadius = UDim.new(0, 6) }, iconTile)
			stroke(iconTile, C.BorderCard)

			local iconLbl = label(iconTile, iconChar, 22, C.Text)
			iconLbl.Position = UDim2.fromScale(0, 0)
			iconLbl.Size = UDim2.fromScale(1, 1)
			iconLbl.TextXAlignment = Enum.TextXAlignment.Center

			local stars = string.rep("★", hero.Stars or 1)
			local starColor = "#FACC15"
			if hero.Stars == 7 then
				starColor = "#E0B0FF"
			elseif hero.Stars == 6 then
				starColor = "#FFD700"
			elseif hero.Stars == 5 then
				starColor = "#C084FC"
			elseif hero.Stars == 4 then
				starColor = "#60A5FA"
			elseif hero.Stars == 3 then
				starColor = "#34D399"
			end
			local nameText = string.format("%s  <font color=\"%s\">%s</font>  <font color=\"#9CA3AF\" size=\"12\">[%s]</font>", hero.DisplayName or "Hero", starColor, stars, archetype)
			local nameLbl = label(card, nameText, 15, C.Text, Enum.Font.GothamBold)
			nameLbl.Position = UDim2.fromOffset(72, 12)
			nameLbl.Size = UDim2.new(1, -90, 0, 22)
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left

			local trait = hero.PassiveTrait or "Combat Ready"
			local subText = string.format("HP: %d  |  ATK: %d  •  %s", math.round(hero.BaseHP or 100), math.round(hero.BaseATK or 10), trait)
			local subLbl = label(card, subText, 12, C.TextLavender, Enum.Font.GothamMedium)
			subLbl.Position = UDim2.fromOffset(72, 36)
			subLbl.Size = UDim2.new(1, -90, 0, 18)
			subLbl.TextXAlignment = Enum.TextXAlignment.Left
		end
	end

	self.RevealScrim.Visible = true
end

--============================================================================
-- ACTIONS & METHODS
--============================================================================

function Controller:Button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, action: () -> ()): TextButton
	local b = new("TextButton", {
		Name = name,
		Text = text,
		Size = size,
		Position = position,
		ZIndex = 54,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextWrapped = true,
		BackgroundColor3 = Color3.fromRGB(34, 28, 52),
		TextColor3 = C.Text,
		BorderSizePixel = 0,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
	stroke(b, C.BorderDim, 1)
	b.Activated:Connect(action)
	return b
end

function Controller:SetSummonTab(tab: "CALL_OF_THE_RIFT" | "A_STARS_ARRIVAL")
	self.ActiveSummonTab = tab
	local isCall = (tab == "CALL_OF_THE_RIFT")
	self.CallTabBtn.TextColor3 = isCall and C.Text or C.TextMuted
	self.StarTabBtn.TextColor3 = not isCall and C.Text or C.TextMuted

	local targetX = isCall and 92 or 268
	TweenService:Create(self.ActiveIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(targetX, 36),
	}):Play()

	self.PermanentSummonView.Visible = isCall
	self.LimitedSummonView.Visible = not isCall
	self:Refresh()
end

function Controller:PerformSummon(bannerId: string, count: number)
	if self.Busy then return end
	local profile = self.GetProfile()
	local cost = (count == 10) and 900 or 100
	if not profile or not profile.Currencies or (profile.Currencies.Gems or 0) < cost then
		return
	end

	self.Busy = true
	task.spawn(function()
		local ok, result = pcall(function()
			return self.Summon:InvokeServer(count, nil, bannerId)
		end)
		self.Busy = false
		if ok and result and result.Success then
			self.LastSummoned = result.Summoned or {}
			if result.PermanentPityRemaining and self.PermanentPityLabel then
				self.PermanentPityLabel.Text = string.format("Guaranteed 5-Star in: <b>%d</b> summons", result.PermanentPityRemaining)
			end
			if result.LimitedPityRemaining and self.LimitedPityLabel then
				self.LimitedPityLabel.Text = string.format("Guaranteed 7-Star in: <b>%d</b> summons", result.LimitedPityRemaining)
			end
			self:ShowSummonResults(self.LastSummoned, false)
		end
		self:Refresh()
	end)
end

function Controller:Close()
	self.Root.Visible = false
	self.Scrim.Visible = false
	self.RevealScrim.Visible = false
end

function Controller:Open(facility: string)
	if not DETAILS[facility] then return end
	self.Current = facility
	self.Root.Visible = true
	self.Scrim.Visible = true
	self.Root:SetAttribute("Facility", facility)
	if self.Status then self.Status.Text = "" end

	local isSummon = (facility == "Summoning")
	self.TabContainer.Visible = isSummon
	self.TabDivider.Visible = isSummon
	self.HeaderTitle.Visible = not isSummon
	self.PermanentSummonView.Visible = isSummon and (self.ActiveSummonTab == "CALL_OF_THE_RIFT")
	self.LimitedSummonView.Visible = isSummon and (self.ActiveSummonTab == "A_STARS_ARRIVAL")
	self.GeneralFacilityView.Visible = not isSummon

	if not isSummon then
		local info = DETAILS[facility]
		self.HeaderTitle.Text = info.Title
		self.HeaderTitle.TextColor3 = info.Color
	end

	self:Refresh()
end

function Controller:Request(callback: () -> (boolean, string))
	if self.Busy then return end
	self.Busy = true
	if self.Status then self.Status.Text = "Working…" end
	task.spawn(function()
		local ok, success, message = pcall(callback)
		self.Busy = false
		if self.Status then
			self.Status.Text = if ok then message or (success and "Done." or "Unable to complete this action.") else "Connection failed. Please try again."
		end
		self:Refresh()
	end)
end

function Controller:Refresh()
	if not self.Root.Visible then return end
	local profile = self.GetProfile()
	local gems = profile and profile.Currencies and profile.Currencies.Gems or 0
	self.GemCurrency.Text = string.format("💎 %d Gems", math.floor(gems))

	if self.Current == "Summoning" then
		-- Update Permanent Banner Pity
		local permPity = profile and (profile.HeroPermanentPity or profile.HeroBannerPity) or 8
		local permRemaining = math.max(1, 50 - (permPity % 50))
		if self.PermanentPityLabel then
			self.PermanentPityLabel.Text = string.format("Guaranteed 5-Star in: <b>%d</b> summons", permRemaining)
		end

		-- Update Limited Banner Pity
		local limPity = profile and profile.HeroLimitedPity or 8
		local limRemaining = math.max(1, 50 - (limPity % 50))
		if self.LimitedPityLabel then
			self.LimitedPityLabel.Text = string.format("Guaranteed 7-Star in: <b>%d</b> summons", limRemaining)
		end
		return
	end

	-- Infirmary or SquadManagement fallback rendering
	local info = DETAILS[self.Current]
	if not info then return end

	self.Title.Text = info.Title
	self.Title.TextColor3 = info.Color
	self.Description.Text = info.Description
	if self.Stroke then
		self.Stroke.Color = info.Color
	end

	for _, c in self.Actions:GetChildren() do c:Destroy() end
	for _, c in self.List:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end

	if not profile then
		self.Summary.Text = "Loading your heroes…"
		return
	end

	local heroes = {}
	for _, h in profile.Heroes or {} do table.insert(heroes, h) end
	local currentTag = FacilityConfig.AssignmentTags[self.Current]

	table.sort(heroes, function(a, b)
		if currentTag then
			local aAssigned, bAssigned = a.Assignment == currentTag, b.Assignment == currentTag
			if aAssigned ~= bAssigned then return aAssigned end
		elseif self.Current == "SquadManagement" then
			local aSquad, bSquad = a.Assignment:match("^SQUAD_SLOT_") ~= nil, b.Assignment:match("^SQUAD_SLOT_") ~= nil
			if aSquad ~= bSquad then return aSquad end
		end
		if a.Stars ~= b.Stars then return a.Stars > b.Stars end
		return tostring(a.UUID) < tostring(b.UUID)
	end)

	if self.Current == "GuardPost" then
		local fac = profile.Facilities and profile.Facilities.GuardPost or { Level = 1, AssignedHeroUUIDs = {} }
		local sumLabor = 0
		for _, u in ipairs(fac.AssignedHeroUUIDs) do
			local h = profile.Heroes[u]
			if h and (h.ComaUntilTimestamp or 0) <= os.time() then
				sumLabor += StatFormulas.GetEffectiveLabor(h, "FACILITY_GUARD_POST")
			end
		end
		local bossTier = profile.HighestClearedBiomeBoss or 0
		local rate = StatFormulas.GetPassiveGoldRate(fac.Level, sumLabor, bossTier)
		local cfg = FacilityConfig.UpgradeTable.GuardPost[fac.Level]
		local nextCfg = FacilityConfig.UpgradeTable.GuardPost[fac.Level + 1]
		local hours = cfg and math.round(cfg.MaxOfflineMinutes / 60) or 4
		local eff = cfg and math.round(cfg.OfflineEfficiency * 100) or 75
		local bossText = bossTier > 0 and string.format(" (+%d%% Boss Tier %d)", bossTier * 15, bossTier) or ""

		self.Summary.Text = string.format("Guard Post Lv.%d (%s)  •  %d/%d Adventurers  •  💰 <b>%.1f Gold/min</b>%s  •  Offline Cap: %dh (%d%%)", fac.Level, cfg and cfg.VisualTitle or "Bastion", #fac.AssignedHeroUUIDs, cfg and cfg.MaxWorkers or 1, rate, bossText, hours, eff)
		local upgrade = nextCfg and string.format("UPGRADE TO LV.%d · %d GOLD (+%d Base Gold/min, +2h Cap)", fac.Level + 1, nextCfg.Gold, nextCfg.BaseGoldPerMin - (cfg and cfg.BaseGoldPerMin or 30)) or "MAXIMUM LEVEL (LV.5)"
		self:Button(self.Actions, "Upgrade", upgrade, UDim2.new(1, 0, 1, 0), UDim2.new(), function()
			if nextCfg then self.Facility:FireServer("UPGRADE_FACILITY", "GuardPost") end
		end)

	elseif self.Current == "Market" then
		local fac = profile.Facilities and profile.Facilities.Market or { Level = 1, AssignedHeroUUIDs = {} }
		local sumLabor = 0
		for _, u in ipairs(fac.AssignedHeroUUIDs) do
			local h = profile.Heroes[u]
			if h and (h.ComaUntilTimestamp or 0) <= os.time() then
				sumLabor += StatFormulas.GetEffectiveLabor(h, "FACILITY_MARKET")
			end
		end
		local mult = StatFormulas.GetMarketLootMultiplier(fac.Level, sumLabor)
		local bonusPct = math.round((mult - 1) * 1000) / 10
		local cfg = FacilityConfig.UpgradeTable.Market[fac.Level]
		local nextCfg = FacilityConfig.UpgradeTable.Market[fac.Level + 1]

		self.Summary.Text = string.format("Market Lv.%d (%s)  •  %d/%d Merchants  •  📦 <b>+%.1f%% Tower & Cargo Gold</b>", fac.Level, cfg and cfg.VisualTitle or "Bazaar", #fac.AssignedHeroUUIDs, cfg and cfg.MaxWorkers or 1, bonusPct)
		local upgrade = nextCfg and string.format("UPGRADE TO LV.%d · %d GOLD (+%.0f%% Base Loot Multiplier)", fac.Level + 1, nextCfg.Gold, (nextCfg.BaseBonus - (cfg and cfg.BaseBonus or 0)) * 100) or "MAXIMUM LEVEL (LV.5)"
		self:Button(self.Actions, "Upgrade", upgrade, UDim2.new(1, 0, 1, 0), UDim2.new(), function()
			if nextCfg then self.Facility:FireServer("UPGRADE_FACILITY", "Market") end
		end)

	elseif self.Current == "TrainingGrounds" then
		local fac = profile.Facilities and profile.Facilities.TrainingGrounds or { Level = 1, AssignedHeroUUIDs = {} }
		local sumLabor = 0
		for _, u in ipairs(fac.AssignedHeroUUIDs) do
			local h = profile.Heroes[u]
			if h and (h.ComaUntilTimestamp or 0) <= os.time() then
				sumLabor += StatFormulas.GetEffectiveLabor(h, "FACILITY_TRAINING")
			end
		end
		local mult = StatFormulas.GetTrainingCombatMultiplier(fac.Level, sumLabor)
		local bonusPct = math.round((mult - 1) * 1000) / 10
		local cfg = FacilityConfig.UpgradeTable.TrainingGrounds[fac.Level]
		local nextCfg = FacilityConfig.UpgradeTable.TrainingGrounds[fac.Level + 1]

		self.Summary.Text = string.format("Training Grounds Lv.%d (%s)  •  %d/%d Trainers  •  ⚔️ <b>+%.1f%% Squad Final ATK & HP</b>", fac.Level, cfg and cfg.VisualTitle or "Arena", #fac.AssignedHeroUUIDs, cfg and cfg.MaxWorkers or 1, bonusPct)
		local upgrade = nextCfg and string.format("UPGRADE TO LV.%d · %d GOLD (+%.0f%% Base Combat Multiplier)", fac.Level + 1, nextCfg.Gold, (nextCfg.BaseBonus - (cfg and cfg.BaseBonus or 0)) * 100) or "MAXIMUM LEVEL (LV.5)"
		self:Button(self.Actions, "Upgrade", upgrade, UDim2.new(1, 0, 1, 0), UDim2.new(), function()
			if nextCfg then self.Facility:FireServer("UPGRADE_FACILITY", "TrainingGrounds") end
		end)

	elseif self.Current == "Infirmary" then
		local facility = profile.Facilities and profile.Facilities.Infirmary or { Level = 1, AssignedHeroUUIDs = {} }
		local resting = 0
		local hasHealer = false
		for _, h in heroes do
			if h.Assignment == "FACILITY_INFIRMARY" then
				resting += 1
				if h.Archetype == "Healer" and (h.ComaUntilTimestamp or 0) <= os.time() then
					hasHealer = true
				end
			end
		end
		local regen, coma = StatFormulas.GetInfirmaryRates(facility.Level, 0, hasHealer)
		local auraText = hasHealer and "<font color=\"#4ADE80\">💚 HEALER AURA ACTIVE (+50% Regen, 40s Coma)</font>" or "<font color=\"#A0B0C4\">Standard Recovery (3.0/s, 60s Coma)</font>"
		self.Summary.Text = string.format("Infirmary (5 Beds)  •  %d heroes resting  •  %.1f Stamina/s  •  %s", resting, regen, auraText)
		self:Button(self.Actions, "Upgrade", "CORE CITADEL FACILITY · 5 PERMANENT RECUPERATION BEDS", UDim2.new(1, 0, 1, 0), UDim2.new(), function()
			-- Core Main Building: 5 permanent beds
		end)

	else
		local deployed = 0
		for _, h in heroes do if h.Assignment:match("^SQUAD_SLOT_") then deployed += 1 end end
		local slots = 5
		self.Summary.Text = string.format("%d / %d squad slots occupied  •  Deploy heroes or send them to the bench", deployed, slots)
		self:Button(self.Actions, "RotateSquad", "REST EXHAUSTED & DEPLOY FRESH HEROES", UDim2.new(1, 0, 1, 0), UDim2.new(), function()
			self:Request(function() return self.Assign:InvokeServer("AUTO_SWAP_EXHAUSTED", "") end)
		end)
	end

	if #heroes == 0 then
		local empty = label(self.List, "Your roster is empty. Visit Summoning to call a hero.", 14, C.TextMuted, Enum.Font.GothamMedium)
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.TextXAlignment = Enum.TextXAlignment.Center
	end

	for index, hero in ipairs(heroes) do
		local row = new("Frame", {
			Name = "Hero_" .. hero.UUID,
			LayoutOrder = index,
			Size = UDim2.new(1, -8, 0, 84),
			BackgroundColor3 = C.CardBg,
			BorderSizePixel = 0,
			ZIndex = 54,
		}, self.List)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
		stroke(row, C.BorderCard, 1)

		local desc = label(row, "", 13, C.Text, Enum.Font.GothamMedium)
		desc.Position = UDim2.fromOffset(12, 8)
		desc.Size = UDim2.new(0.6, -18, 1, -16)
		desc.TextXAlignment = Enum.TextXAlignment.Left

		local coma = math.max(0, (hero.ComaUntilTimestamp or 0) - os.time())
		local status = coma > 0 and string.format("<font color=\"#EF4444\">Coma (%ds)</font>", coma) or string.format("Stamina %d%%", math.round(hero.CurrentStamina or 100))
		local stars = string.rep("★", hero.Stars or 1)
		local archIcon = ARCHETYPE_ICONS[hero.Archetype] or "🛡️"

		local labor = StatFormulas.GetEffectiveLabor(hero, currentTag or hero.Assignment)
		local seed = HeroCatalog.Seeds[hero.TemplateId]
		local pref = seed and seed.PreferredFacility or ""
		local hasSynergy = currentTag and (pref == "ALL" or pref == currentTag)
		local synergyText = hasSynergy and " <font color=\"#4ADE80\">★ +25% Synergy</font>" or ""

		desc.Text = string.format("%s %s  <font color=\"#FACC15\">%s</font>  Lv.%d\n<font color=\"#A0B0C4\">%s  •  %s</font>\n<font color=\"#E2D5FC\">⛏️ Labor: <b>%.1f</b>%s</font>", archIcon, hero.DisplayName, stars, hero.Level or 1, hero.Assignment, status, labor, synergyText)

		local assignTitle = "DEPLOY"
		local targetAssignment = "SQUAD_AUTO"
		if self.Current == "GuardPost" then
			assignTitle = "PATROL"
			targetAssignment = "FACILITY_GUARD_POST"
		elseif self.Current == "Market" then
			assignTitle = "MERCHANT"
			targetAssignment = "FACILITY_MARKET"
		elseif self.Current == "TrainingGrounds" then
			assignTitle = "TRAIN"
			targetAssignment = "FACILITY_TRAINING"
		elseif self.Current == "Infirmary" then
			assignTitle = "REST"
			targetAssignment = "FACILITY_INFIRMARY"
		end

		local uuid = hero.UUID
		self:Button(row, "Assign", assignTitle, UDim2.new(0.18, -4, 0, 36), UDim2.new(0.62, 0, 0.5, -18), function()
			self:Request(function() return self.Assign:InvokeServer(uuid, targetAssignment) end)
		end)
		self:Button(row, "Bench", "BENCH", UDim2.new(0.18, -4, 0, 36), UDim2.new(0.81, 0, 0.5, -18), function()
			self:Request(function() return self.Assign:InvokeServer(uuid, "BENCHED") end)
		end)
	end
end

return Controller
