--!strict
-- StarterPlayerScripts/UI/ForgeController.luau
-- Authoritative Blacksmith Forge HUD featuring 3 Sections:
--   1. ASSIGN (Inventory list of all owned artifacts with stats & 1-click hero assignment)
--   2. SUMMON (Dimensional banner gacha for artifacts: 1X & 10X pulls, 50-pull pity counter, rate-up featured items)
--   3. UPGRADE ARTIFACT (Promote weapon stars with up to 6 duplicate copies)
-- Matches exact cosmic purple aesthetic with corner diamond accents, glowing borders, and responsive scaling.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local StatFormulas = require(Shared.Util.StatFormulas)
local StatBalance = require(Shared.Config.StatBalance)
local GothicBoxStyle = require(Shared.Util.GothicBoxStyle)

local LocalPlayer = Players.LocalPlayer

local Forge = {}
Forge.__index = Forge

local WIDTH, HEIGHT = 760, 530

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

local ICON_MAP: { [string]: string } = {
	BOW = "🏹",
	SWORD = "⚔️",
	DAGGERS = "🗡️",
	AXE = "🪓",
	TOME = "📖",
	STAFF = "🪄",
	RING = "💍",
	SHIELD = "🛡️",
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

-- Formats artifact stat string e.g. "ATK +150 | Crit Rate +5%" matching mockup
local function formatStatSummary(art: any): string
 local stats=ArtifactCatalog.GetStatBreakdown(art.TemplateId,art.Star or 1,art.Rarity or 1)
 return string.format("Power %.0f | Damage x%.2f | AtkSpd +%.1f%%",stats.Power,stats.DamageMultiplier,stats["Attack Speed"])
end

--============================================================================
-- CONSTRUCTOR
--============================================================================

function Forge.new(gui: ScreenGui, artifactRemotes: Folder, getProfile: (() -> any)?, onClose: (() -> ())?)
	local self: any = setmetatable({}, Forge)
	self.Remotes = artifactRemotes
	self.GetProfile = getProfile
	self.OnClose = onClose
	self.RequestSummon = artifactRemotes:WaitForChild("RequestSummonArtifact") :: RemoteFunction
	self.RequestUpgrade = artifactRemotes:WaitForChild("RequestUpgradeArtifact") :: RemoteFunction
	self.RequestEquip = artifactRemotes:WaitForChild("RequestEquipArtifact") :: RemoteFunction
	self.RequestUnequip = artifactRemotes:WaitForChild("RequestUnequipArtifact") :: RemoteFunction
	self.RequestCraft = artifactRemotes:FindFirstChild("RequestCraftArtifact") :: RemoteFunction?

	self.ActiveTab = "ASSIGN" :: "ASSIGN" | "SUMMON" | "UPGRADE"
	self.SelectedAssignArtifactUUID = nil :: string?
	self.SelectedTargetUUID = nil :: string?
	self.FodderUUIDs = {} :: { string } -- Up to six same-template donor UUIDs.
	self.PickerMode = "NONE" :: "NONE" | "TARGET" | "FODDER" | "EQUIP_LOADOUT"
	self.Busy = false

	-- 1. Scrim Background (dims world)
	self.Scrim = new("TextButton", {
		Name = "ForgeScrim",
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
		Name = "BlacksmithForgeModal",
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

	self.Scale = new("UIScale", {}, root)

	-- 3. Close Button (High contrast gothic rounded square with Latin 'X')
	local closeBtn = GothicBoxStyle.CreateCloseButton(root, function()
		if not self.Busy then
			self:Close()
		end
	end)
	closeBtn.Position = UDim2.fromOffset(658, 68)
	closeBtn.Size = UDim2.fromOffset(26, 26)

	-- 4. Top Header & 3 Tabs (ASSIGN | SUMMON | UPGRADE ARTIFACT)
	local tabContainer = new("Frame", {
		Name = "TabContainer",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(72, 68),
		Size = UDim2.new(0, 540, 0, 30),
		ZIndex = 52,
	}, root)

	local assignTabBtn = new("TextButton", {
		Name = "TabAssign",
		Text = "ASSIGN",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.Text,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(105, 26),
		Position = UDim2.fromOffset(0, 0),
		ZIndex = 53,
	}, tabContainer)

	local summonTabBtn = new("TextButton", {
		Name = "TabSummon",
		Text = "SUMMON",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(105, 26),
		Position = UDim2.fromOffset(105, 0),
		ZIndex = 53,
	}, tabContainer)

	local upgradeTabBtn = new("TextButton", {
		Name = "TabUpgrade",
		Text = "UPGRADE ARTIFACT",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(170, 26),
		Position = UDim2.fromOffset(210, 0),
		ZIndex = 53,
	}, tabContainer)

	-- Active Underline indicator (Stark white rounded pill matching gothic mockup)
	local activeIndicator = new("Frame", {
		Name = "ActiveTabIndicator",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 55, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(52, 26),
		ZIndex = 54,
	}, tabContainer)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, activeIndicator)

	self.AssignTabBtn = assignTabBtn
	self.SummonTabBtn = summonTabBtn
	self.UpgradeTabBtn = upgradeTabBtn
	self.ActiveIndicator = activeIndicator

	assignTabBtn.Activated:Connect(function()
		self:SetTab("ASSIGN")
	end)
	summonTabBtn.Activated:Connect(function()
		self:SetTab("SUMMON")
	end)
	upgradeTabBtn.Activated:Connect(function()
		self:SetTab("UPGRADE")
	end)

	-- Divider Line beneath tabs
	local tabDivider = new("Frame", {
		Name = "TabDivider",
		BackgroundColor3 = Color3.fromRGB(55, 45, 70),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(72, 102),
		Size = UDim2.new(0, 616, 0, 1),
		ZIndex = 52,
	}, root)

	-- 5. SECTION 1: ASSIGN ARTIFACT VIEW (Image 2)
	self:BuildAssignView(root)

	-- 6. SECTION 2: SUMMON ARTIFACT BANNER VIEW (Image 1)
	self:BuildSummonView(root)

	-- 7. SECTION 3: UPGRADE ARTIFACT VIEW
	self:BuildUpgradeView(root)

	-- 8. SELECTION DRAWER (Bottom overlay for picking target / fodder / hero assignment)
	self:BuildPickerDrawer(root)

	-- 9. SUMMON RESULTS CELEBRATION MODAL
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

function Forge:ResolveProfile(): any
	if self.GetProfile then
		local p = self.GetProfile()
		if p then return p end
	end
	if _G.CurrentProfile then return _G.CurrentProfile end
	if _G.DataManager and _G.DataManager.GetProfile then
		return _G.DataManager.GetProfile(LocalPlayer)
	end
	return nil
end

--============================================================================
-- TAB SWITCHING
--============================================================================

function Forge:SetTab(tab: "ASSIGN" | "SUMMON" | "UPGRADE")
	self.ActiveTab = tab
	self:ClosePicker()

	if tab == "ASSIGN" then
		self.AssignTabBtn.TextColor3 = C.Text
		self.SummonTabBtn.TextColor3 = C.TextMuted
		self.UpgradeTabBtn.TextColor3 = C.TextMuted

		self.AssignView.Visible = true
		self.SummonView.Visible = false
		self.UpgradeView.Visible = false

		local targetX = self.AssignTabBtn.Position.X.Offset + self.AssignTabBtn.Size.X.Offset / 2
		TweenService:Create(self.ActiveIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(targetX, 26),
			Size = UDim2.fromOffset(55, 3),
		}):Play()
		self:RenderAssignView()
	elseif tab == "SUMMON" then
		self.AssignTabBtn.TextColor3 = C.TextMuted
		self.SummonTabBtn.TextColor3 = C.Text
		self.UpgradeTabBtn.TextColor3 = C.TextMuted

		self.AssignView.Visible = false
		self.SummonView.Visible = true
		self.UpgradeView.Visible = false

		local targetX = self.SummonTabBtn.Position.X.Offset + self.SummonTabBtn.Size.X.Offset / 2
		TweenService:Create(self.ActiveIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(targetX, 26),
			Size = UDim2.fromOffset(60, 3),
		}):Play()
		self:RenderSummonView()
	else
		self.AssignTabBtn.TextColor3 = C.TextMuted
		self.SummonTabBtn.TextColor3 = C.TextMuted
		self.UpgradeTabBtn.TextColor3 = C.Text

		self.AssignView.Visible = false
		self.SummonView.Visible = false
		self.UpgradeView.Visible = true

		local targetX = self.UpgradeTabBtn.Position.X.Offset + self.UpgradeTabBtn.Size.X.Offset / 2
		TweenService:Create(self.ActiveIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(targetX, 26),
			Size = UDim2.fromOffset(110, 3),
		}):Play()
		self:RenderUpgradeView()
	end
end

--============================================================================
-- SECTION 1: ASSIGN ARTIFACT VIEW (Image 2)
--============================================================================

function Forge:BuildAssignView(root: Frame)
	local assignView = new("Frame", {
		Name = "AssignView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(72, 108),
		Size = UDim2.new(0, 616, 0, 380),
		Visible = true,
		ZIndex = 52,
	}, root)
	self.AssignView = assignView

	local scroll = new("ScrollingFrame", {
		Name = "AssignScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Border,
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 53,
	}, assignView)
	self.AssignScroll = scroll

	local layout = new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, scroll)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 8),
	}, scroll)
end

function Forge:RenderAssignView()
	local scroll = self.AssignScroll
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local profile = self:ResolveProfile()
	local artifacts = profile and profile.Artifacts or {}
	local heroMap = profile and profile.Heroes or {}

	-- Collect and sort artifacts
	local artList = {}
	for uuid, art in pairs(artifacts) do
		table.insert(artList, { UUID = uuid, Art = art })
	end

	if #artList == 0 then
		local emptyCard = new("Frame", {
			Name = "EmptyCard",
			Size = UDim2.new(1, 0, 0, 180),
			BackgroundColor3 = C.CardBg,
			BorderSizePixel = 0,
			ZIndex = 53,
		}, scroll)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, emptyCard)
		stroke(emptyCard, C.BorderDim)

		local emptyTitle = label(emptyCard, "📦 NO ARTIFACTS IN INVENTORY", 18, C.Text, Enum.Font.GothamBold)
		emptyTitle.Position = UDim2.new(0, 0, 0.25, 0)
		emptyTitle.Size = UDim2.new(1, 0, 0, 26)
		local sub = label(emptyCard, "Visit the <b>SUMMON</b> tab to draw weapons from the dimensional banner!", 14, C.TextLavender, Enum.Font.Gotham)
		sub.Position = UDim2.new(0, 0, 0.5, 0)
		sub.Size = UDim2.new(1, 0, 0, 24)

		local goBtn = new("TextButton", {
			Text = "GO TO SUMMON ➔",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = C.Text,
			BackgroundColor3 = C.Panel,
			Size = UDim2.fromOffset(170, 36),
			Position = UDim2.new(0.5, -85, 0.72, 0),
			ZIndex = 54,
		}, emptyCard)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, goBtn)
		stroke(goBtn, C.Border)
		goBtn.Activated:Connect(function()
			self:SetTab("SUMMON")
		end)
		return
	end

	-- Sort: Star desc, Level desc, Alphabetical
	table.sort(artList, function(a, b)
		local aStar = a.Art.Star or 1
		local bStar = b.Art.Star or 1
		if aStar ~= bStar then return aStar > bStar end
		local aLvl = a.Art.Rarity or 1
		local bLvl = b.Art.Rarity or 1
		if aLvl ~= bLvl then return aLvl > bLvl end
		return (a.Art.DisplayName or "") < (b.Art.DisplayName or "")
	end)

	for order, item in ipairs(artList) do
		local uuid = item.UUID
		local art = item.Art
		local equippedHero = art.EquippedHeroUUID and heroMap[art.EquippedHeroUUID]

		local card = new("Frame", {
			Name = "ArtCard_" .. uuid,
			Size = UDim2.new(1, 0, 0, 80),
			BackgroundColor3 = C.CardBg,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 53,
		}, scroll)
		applyGothicStyle(card, "Card")

		-- Left Weapon Icon Box
		local iconBox = new("Frame", {
			Name = "IconBox",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = Color3.fromRGB(18, 15, 28),
			BorderSizePixel = 0,
			ZIndex = 54,
		}, card)
		applyGothicStyle(iconBox, "Compact")

		local iconChar = ICON_MAP[art.Type] or "⚔️"
		local iconLabel = label(iconBox, iconChar, 24, C.Text)
		iconLabel.Position = UDim2.fromScale(0, 0)
		iconLabel.Size = UDim2.fromScale(1, 1)

		-- Center Text Info
		local infoContainer = new("Frame", {
			Name = "Info",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 80, 0.5, 0),
			Size = UDim2.new(1, -260, 0, 48),
			ZIndex = 54,
		}, card)

		local displayName = art.DisplayName or "Artifact"
		displayName = string.format("%s (%d stars)", displayName, art.Star or 1)

		local nameLabel = label(infoContainer, displayName, 16, C.Text, Enum.Font.GothamBold)
		nameLabel.Position = UDim2.fromOffset(0, 2)
		nameLabel.Size = UDim2.new(1, 0, 0, 22)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left

		if equippedHero then
			nameLabel.Text = string.format("%s  <font color=\"#60A5FA\" size=\"12\">[Equipped: %s]</font>", displayName, equippedHero.DisplayName)
		end

		local statSummary = formatStatSummary(art)
		local statLabel = label(infoContainer, statSummary, 13, C.TextLavender, Enum.Font.GothamMedium)
		statLabel.Position = UDim2.fromOffset(0, 26)
		statLabel.Size = UDim2.new(1, 0, 0, 18)
		statLabel.TextXAlignment = Enum.TextXAlignment.Left

		-- Right Button: ASSIGN ARTIFACT
		local assignBtn = new("TextButton", {
			Name = "AssignBtn",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -16, 0.5, 0),
			Size = UDim2.fromOffset(150, 42),
			BackgroundColor3 = Color3.fromRGB(22, 18, 34),
			BorderSizePixel = 0,
			Text = equippedHero and "CHANGE HERO" or "ASSIGN ARTIFACT",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = C.Text,
			ZIndex = 54,
		}, card)
		applyGothicStyle(assignBtn, "Button")

		assignBtn.Activated:Connect(function()
			if self.Busy then return end
			self.SelectedAssignArtifactUUID = uuid
			self:OpenDrawer("EQUIP_LOADOUT", uuid)
		end)
	end
end

--============================================================================
-- SECTION 2: SUMMON ARTIFACT BANNER VIEW (Image 1)
--============================================================================

function Forge:BuildSummonView(root: Frame)
	local summonView = new("Frame", {
		Name = "SummonView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(72, 108),
		Size = UDim2.new(0, 616, 0, 380),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.SummonView = summonView

	-- 1. Main Featured Banner Card (Image 1 - Ornate Gothic Card Container)
	local bannerCard = new("Frame", {
		Name = "BannerCard",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 230),
		BackgroundColor3 = Color3.fromRGB(18, 14, 28),
		BorderSizePixel = 0,
		ZIndex = 53,
	}, summonView)
	self.BannerCard = bannerCard

	applyGothicStyle(bannerCard, "Card")

	-- Cosmic Gradient
	local grad = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(28, 20, 42)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(18, 13, 28)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(12, 9, 20)),
		}),
		Rotation = 35,
	}, bannerCard)

	-- Top Watermark
	local watermark = label(bannerCard, "★ 5-STAR FEATURED HERO & ARTIFACTS", 11, Color3.fromRGB(225, 220, 235), Enum.Font.GothamBold)
	watermark.TextTransparency = 0.4
	watermark.Position = UDim2.fromOffset(26, 22)
	watermark.Size = UDim2.new(1, -52, 0, 18)
	watermark.TextXAlignment = Enum.TextXAlignment.Left
	watermark.ZIndex = 56

	-- Big Glowing Banner Title
	local bannerTitle = label(bannerCard, "ECHOES OF THE RIFT", 25, C.GoldYellow, Enum.Font.GothamBlack)
	bannerTitle.AnchorPoint = Vector2.new(0, 0)
	bannerTitle.Position = UDim2.new(0, 28, 0, 152)
	bannerTitle.Size = UDim2.new(0, 340, 0, 30)
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Left
	bannerTitle.TextStrokeTransparency = 0.3
	bannerTitle.TextStrokeColor3 = Color3.fromRGB(110, 75, 0)
	bannerTitle.ZIndex = 56

	-- Featured Rate-Up Pill Label
	local rateUpLabel = label(bannerCard, "✧ Rate Up: Blade of the Rift (5★)  |  Aegis Core (5★)", 11, Color3.fromRGB(216, 140, 230), Enum.Font.GothamBold)
	rateUpLabel.AnchorPoint = Vector2.new(1, 0)
	rateUpLabel.Position = UDim2.new(1, -28, 0, 158)
	rateUpLabel.Size = UDim2.new(0, 320, 0, 20)
	rateUpLabel.TextXAlignment = Enum.TextXAlignment.Right
	rateUpLabel.ZIndex = 56

	-- 2. Info Row (Guaranteed Pity & Timer)
	local infoRow = new("Frame", {
		Name = "InfoRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 236),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 53,
	}, summonView)

	local pityLabel = label(infoRow, "Guaranteed 5-Star in: <b>42</b> summons", 12, Color3.fromRGB(230, 225, 240), Enum.Font.GothamMedium)
	pityLabel.Position = UDim2.fromOffset(4, 0)
	pityLabel.Size = UDim2.new(0.5, 0, 1, 0)
	pityLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.PityLabel = pityLabel

	local timerLabel = label(infoRow, "Event Ends: 2d 14h", 12, Color3.fromRGB(180, 170, 200), Enum.Font.GothamMedium)
	timerLabel.AnchorPoint = Vector2.new(1, 0)
	timerLabel.Position = UDim2.new(1, -4, 0, 0)
	timerLabel.Size = UDim2.new(0.5, 0, 1, 0)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- 3. Summon Buttons Container (Image 1 - Ornate Gothic Button Containers)
	local btnRow = new("Frame", {
		Name = "ButtonRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 264),
		Size = UDim2.new(1, 0, 0, 76),
		ZIndex = 53,
	}, summonView)

	-- SUMMON 1X Button
	local btn1X = new("TextButton", {
		Name = "Summon1XBtn",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(0.485, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(22, 18, 36),
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 54,
	}, btnRow)
	applyGothicStyle(btn1X, "Button")

	local t1X = label(btn1X, "SUMMON 1X", 14, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	t1X.AnchorPoint = Vector2.new(0.5, 0)
	t1X.Position = UDim2.new(0.5, 0, 0, 22)
	t1X.Size = UDim2.new(1, 0, 0, 16)
	t1X.ZIndex = 56

	local c1X = label(btn1X, "💎 160", 13, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	c1X.AnchorPoint = Vector2.new(0.5, 0)
	c1X.Position = UDim2.new(0.5, 0, 0, 42)
	c1X.Size = UDim2.new(1, 0, 0, 16)
	c1X.ZIndex = 56

	btn1X.Activated:Connect(function()
		self:PerformSummon(1)
	end)

	-- SUMMON 10X Button
	local btn10X = new("TextButton", {
		Name = "Summon10XBtn",
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

	local t10X = label(btn10X, "SUMMON 10X", 14, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	t10X.AnchorPoint = Vector2.new(0.5, 0)
	t10X.Position = UDim2.new(0.5, 0, 0, 22)
	t10X.Size = UDim2.new(1, 0, 0, 16)
	t10X.ZIndex = 56

	local c10X = label(btn10X, "💎 1600", 13, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
	c10X.AnchorPoint = Vector2.new(0.5, 0)
	c10X.Position = UDim2.new(0.5, 0, 0, 42)
	c10X.Size = UDim2.new(1, 0, 0, 16)
	c10X.ZIndex = 56

	btn10X.Activated:Connect(function()
		self:PerformSummon(10)
	end)
end

function Forge:RenderSummonView()
	local profile = self:ResolveProfile()
	local pity = profile and profile.ArtifactBannerPity or 8
	local remaining = math.max(1, 50 - (pity % 50))
	if self.PityLabel then
		self.PityLabel.Text = string.format("Guaranteed 5-Star in: <b>%d</b> summons", remaining)
	end
end

function Forge:PerformSummon(count: number)
	if self.Busy then return end
	local profile = self:ResolveProfile()
	local cost = (count == 10) and 1600 or 160

	if not profile or not profile.Currencies or (profile.Currencies.Gems or 0) < cost then
		-- Flash error feedback
		return
	end

	self.Busy = true
	task.spawn(function()
		local success, msg, summonedList, pityRemaining = self.RequestSummon:InvokeServer(count)
		self.Busy = false
		if success and summonedList and #summonedList > 0 then
			if pityRemaining and self.PityLabel then
				self.PityLabel.Text = string.format("Guaranteed 5-Star in: <b>%d</b> summons", pityRemaining)
			end
			self:ShowSummonResults(summonedList)
		end
		self:Refresh()
	end)
end

--============================================================================
-- SUMMON CELEBRATION / REVEAL MODAL
--============================================================================

function Forge:BuildSummonRevealModal(gui: ScreenGui)
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

	local revealTitle = label(modal, "✨ DIMENSIONAL ARTIFACTS SUMMONED", 20, C.GoldYellow, Enum.Font.GothamBlack)
	revealTitle.Position = UDim2.new(0, 0, 0, 20)
	revealTitle.Size = UDim2.new(1, 0, 0, 28)

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
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(200, 44),
		BackgroundColor3 = Color3.fromRGB(22, 18, 36),
		BorderSizePixel = 0,
		Text = "COLLECT ARTIFACTS",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.Text,
		ZIndex = 82,
	}, modal)
	applyGothicStyle(collectBtn, "Button")

	collectBtn.Activated:Connect(function()
		self.RevealScrim.Visible = false
		self:SetTab("ASSIGN") -- Take player to ASSIGN tab so they can see new artifacts!
	end)
end

function Forge:ShowSummonResults(summonedList: { any })
	local scroll = self.RevealScroll
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	for order, art in ipairs(summonedList) do
		local row = new("Frame", {
			Name = "ResultRow_" .. order,
			Size = UDim2.new(1, -4, 0, 64),
			BackgroundColor3 = C.CardBg,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 83,
		}, scroll)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, row)
		stroke(row, C.BorderCard, 1)

		-- Star Rating string
		local starCount = art.Star or 1
		local starStr = string.rep("★", starCount)
		local starColor = (starCount >= 5) and C.GoldYellow or ((starCount >= 4) and Color3.fromRGB(192, 132, 252) or C.TextLavender)

		-- Left Icon Box
		local iconBox = new("Frame", {
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = Color3.fromRGB(18, 14, 28),
			BorderSizePixel = 0,
			ZIndex = 84,
		}, row)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, iconBox)
		stroke(iconBox, starColor, 1)

		local iconChar = ICON_MAP[art.Type] or "⚔️"
		local iconLabel = label(iconBox, iconChar, 22, starColor)
		iconLabel.Position = UDim2.fromScale(0, 0)
		iconLabel.Size = UDim2.fromScale(1, 1)

		-- Text Info
		local info = new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(68, 8),
			Size = UDim2.new(1, -80, 0, 48),
			ZIndex = 84,
		}, row)

		local nameLabel = label(info, string.format("%s  <font color=\"#FACC15\">%s</font>", art.DisplayName, starStr), 15, C.Text, Enum.Font.GothamBold)
		nameLabel.Position = UDim2.fromOffset(0, 2)
		nameLabel.Size = UDim2.new(1, 0, 0, 20)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left

		local statsSummary = formatStatSummary(art)
		local statLabel = label(info, statsSummary, 12, C.TextLavender, Enum.Font.GothamMedium)
		statLabel.Position = UDim2.fromOffset(0, 24)
		statLabel.Size = UDim2.new(1, 0, 0, 18)
		statLabel.TextXAlignment = Enum.TextXAlignment.Left
	end

	self.RevealScrim.Visible = true
end

--============================================================================
-- SECTION 3: WEAPON STAR PROMOTION VIEW (up to 6 donor slots)
--============================================================================

function Forge:BuildUpgradeView(root: Frame)
	local upgradeView = new("Frame", {
		Name = "UpgradeView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(72, 108),
		Size = UDim2.new(0, 616, 0, 380),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.UpgradeView = upgradeView

	-- Target Slot (Selected Artifact to Enhance)
	local targetSlot = new("Frame", {
		Name = "TargetSlot",
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.fromOffset(160, 180),
		BackgroundColor3 = C.SlotBg,
		BorderSizePixel = 0,
		ZIndex = 53,
	}, upgradeView)
	applyGothicStyle(targetSlot, "Card")

	local targetIcon = label(targetSlot, "⚔️", 46, C.Text)
	targetIcon.Name = "TargetIcon"
	targetIcon.Position = UDim2.fromScale(0, 0.15)
	targetIcon.Size = UDim2.fromScale(1, 0.45)
	self.TargetIcon = targetIcon

	local targetName = label(targetSlot, "SELECT ARTIFACT", 14, C.Text, Enum.Font.GothamBold)
	targetName.Name = "TargetName"
	targetName.Position = UDim2.fromScale(0, 0.62)
	targetName.Size = UDim2.fromScale(1, 0.18)
	self.TargetName = targetName

	local targetLevel = label(targetSlot, "Click to choose", 12, C.TextLavender, Enum.Font.Gotham)
	targetLevel.Name = "TargetLevel"
	targetLevel.Position = UDim2.fromScale(0, 0.78)
	targetLevel.Size = UDim2.fromScale(1, 0.18)
	self.TargetLevel = targetLevel

	local targetBtn = new("TextButton", {
		Name = "TargetSlotBtn",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 54,
	}, targetSlot)
	targetBtn.Activated:Connect(function()
		self:OpenDrawer("TARGET")
	end)

	-- Center Arrow & Stat Preview Box
	local statBox = new("Frame", {
		Name = "StatComparisonBox",
		Position = UDim2.fromOffset(210, 14),
		Size = UDim2.new(1, -234, 0, 180),
		BackgroundColor3 = C.CardBg,
		BorderSizePixel = 0,
		ZIndex = 53,
	}, upgradeView)
	applyGothicStyle(statBox, "Card")

	local previewHeader = label(statBox, "STAR PROMOTION PREVIEW", 15, C.Text, Enum.Font.GothamBold)
	previewHeader.Position = UDim2.new(0, 18, 0, 14)
	previewHeader.Size = UDim2.new(1, -36, 0, 22)
	previewHeader.TextXAlignment = Enum.TextXAlignment.Left

	local currentStatsLabel = label(statBox, "Current Stats: Select an artifact", 13, C.TextLavender, Enum.Font.GothamMedium)
	currentStatsLabel.Position = UDim2.new(0, 18, 0, 48)
	currentStatsLabel.Size = UDim2.new(1, -36, 0, 24)
	currentStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.CurrentStatsLabel = currentStatsLabel

	local arrowLabel = label(statBox, "▼  UPGRADE BOOST  ▼", 12, C.Arrow, Enum.Font.GothamBold)
	arrowLabel.Position = UDim2.new(0, 18, 0, 84)
	arrowLabel.Size = UDim2.new(1, -36, 0, 20)
	arrowLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.HeroStatPreview = arrowLabel

	local nextStatsLabel = label(statBox, "Next Star: —", 14, C.Green, Enum.Font.GothamBold)
	nextStatsLabel.Position = UDim2.new(0, 18, 0, 114)
	nextStatsLabel.Size = UDim2.new(1, -36, 0, 24)
	nextStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.NextStatsLabel = nextStatsLabel

	local fodderReqLabel = label(statBox, "Fodder Required: 0 / 0", 12, C.TextMuted, Enum.Font.Gotham)
	fodderReqLabel.Position = UDim2.new(0, 18, 0, 146)
	fodderReqLabel.Size = UDim2.new(1, -36, 0, 20)
	fodderReqLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.FodderReqLabel = fodderReqLabel

	-- Six duplicate slots support the final star promotion.
	local fodderContainer = new("Frame", {
		Name = "FodderSlotsContainer",
		Position = UDim2.fromOffset(24, 214),
		Size = UDim2.new(1, -48, 0, 100),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, upgradeView)

	self.FodderSlotFrames = {}
	local slotW = 88
	local spacing = 12

	for i = 1, 6 do
		local slot = new("Frame", {
			Name = "FodderSlot_" .. i,
			Position = UDim2.fromOffset((i - 1) * (slotW + spacing), 0),
			Size = UDim2.fromOffset(slotW, 90),
			BackgroundColor3 = C.SlotBg,
			BorderSizePixel = 0,
			ZIndex = 53,
		}, fodderContainer)
		applyGothicStyle(slot, "Compact")

		local plus = label(slot, "+", 28, C.TextMuted, Enum.Font.GothamBold)
		plus.Name = "PlusLabel"
		plus.Position = UDim2.fromScale(0, 0.15)
		plus.Size = UDim2.fromScale(1, 0.45)

		local name = label(slot, "Fodder", 11, C.TextMuted, Enum.Font.Gotham)
		name.Name = "NameLabel"
		name.Position = UDim2.fromScale(0, 0.6)
		name.Size = UDim2.fromScale(1, 0.3)

		local slotBtn = new("TextButton", {
			Name = "SlotBtn",
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 54,
		}, slot)
		slotBtn.Activated:Connect(function()
			self:OpenDrawer("FODDER")
		end)

		table.insert(self.FodderSlotFrames, slot)
	end

	-- Bottom Action Row (Auto-Fill & Enhance Button)
	local bottomRow = new("Frame", {
		Name = "BottomActionRow",
		Position = UDim2.fromOffset(24, 326),
		Size = UDim2.new(1, -48, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, upgradeView)

	local autoFillBtn = new("TextButton", {
		Name = "AutoFillBtn",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(180, 46),
		BackgroundColor3 = Color3.fromRGB(26, 20, 38),
		BorderSizePixel = 0,
		Text = "⚡ AUTO-FILL FODDER",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = C.Text,
		ZIndex = 54,
	}, bottomRow)
	applyGothicStyle(autoFillBtn, "Button")
	autoFillBtn.Activated:Connect(function()
		self:AutoFillFodder()
	end)

	local enhanceBtn = new("TextButton", {
		Name = "EnhanceBtn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(260, 46),
		BackgroundColor3 = Color3.fromRGB(30, 22, 46),
		BorderSizePixel = 0,
		Text = "⚒️ PROMOTE WEAPON",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C.Text,
		ZIndex = 54,
	}, bottomRow)
	applyGothicStyle(enhanceBtn, "Button")
	self.EnhanceBtn = enhanceBtn

	enhanceBtn.Activated:Connect(function()
		self:PerformUpgrade()
	end)
end

function Forge:RenderUpgradeView()
	local profile = self:ResolveProfile()
	local artifacts = profile and profile.Artifacts or {}

	-- If no target selected, try to pick first owned artifact
	if not self.SelectedTargetUUID or not artifacts[self.SelectedTargetUUID] then
		for uuid, _ in pairs(artifacts) do
			self.SelectedTargetUUID = uuid
			break
		end
	end

	local target = self.SelectedTargetUUID and artifacts[self.SelectedTargetUUID]
	if not target then
		self.TargetIcon.Text = "⚔️"
		self.TargetName.Text = "NO ARTIFACT"
		self.TargetLevel.Text = "Click to pick"
		self.CurrentStatsLabel.Text = "Current Stats: No artifact selected"
		self.NextStatsLabel.Text = "Next Star: —"
		self.FodderReqLabel.Text = "Fodder Required: 0 / 0"
		self.HeroStatPreview.Text = "Equip a weapon to preview hero damage and DPS"
		return
	end

	-- Update Target Slot
	local iconChar = ICON_MAP[target.Type] or "⚔️"
	self.TargetIcon.Text = iconChar
	self.TargetName.Text = target.DisplayName or "Artifact"
	self.TargetLevel.Text = string.format("%s · %d stars", ArtifactCatalog.GetRarityInfo(target.Rarity or 1).Name, target.Star or 1)

	local currentStar = target.Star or 1
	local maxStars = ArtifactCatalog.MaxStars or 7
	local reqFodder = ArtifactCatalog.GetFodderRequirement(currentStar)

	-- Update Stats
	local currentStats = formatStatSummary(target)
	self.CurrentStatsLabel.Text = string.format("Current Stats: %s", currentStats)
	local equippedHero = target.EquippedHeroUUID and profile.Heroes and profile.Heroes[target.EquippedHeroUUID]
	if equippedHero then
		local before = StatFormulas.GetCombatSnapshot(equippedHero, target)
		local nextWeapon = table.clone(target)
		nextWeapon.Star = math.min(maxStars, currentStar + 1)
		local after = StatFormulas.GetCombatSnapshot(equippedHero, nextWeapon)
		self.HeroStatPreview.Text = string.format("Hit %s → %s | DPS %s → %s", StatBalance.Format(before.AttackDamage), StatBalance.Format(after.AttackDamage), StatBalance.Format(before.DPS), StatBalance.Format(after.DPS))
	else
		self.HeroStatPreview.Text = "Equip to a hero to preview damage and DPS"
	end

	if currentStar >= maxStars then
		self.NextStatsLabel.Text = "★ MAXIMUM 7-STAR RANK REACHED"
		self.FodderReqLabel.Text = "Maximum 7-star rank"
		self.EnhanceBtn.Text = "MAX STARS REACHED"
	else
		-- Preview the next star with unchanged rarity and speed.
		local simNext = {
			TemplateId = target.TemplateId,
			Star = currentStar + 1,
			Rarity = target.Rarity,
			Type = target.Type,
		}
		local nextStats = formatStatSummary(simNext)
		self.NextStatsLabel.Text = string.format("Next Star (%d): %s", currentStar + 1, nextStats)
		local cost=ArtifactCatalog.GetStarPromotionCost(currentStar)
		self.FodderReqLabel.Text = string.format("Copies: %d/%d | Gold %d | Gems %d", #self.FodderUUIDs, reqFodder, cost.Gold, cost.Gems)
		self.EnhanceBtn.Text = string.format("⚒️ PROMOTE TO %d STARS (%d/%d)", currentStar + 1, #self.FodderUUIDs, reqFodder)
	end

	-- Update Fodder Slots
	for i = 1, 6 do
		local slotFrame = self.FodderSlotFrames[i]
		if slotFrame then
			local plusLabel = slotFrame:FindFirstChild("PlusLabel") :: TextLabel?
			local nameLabel = slotFrame:FindFirstChild("NameLabel") :: TextLabel?
			local fUUID = self.FodderUUIDs[i]
			local fArt = fUUID and artifacts[fUUID]

			if fArt then
				if plusLabel then plusLabel.Text = ICON_MAP[fArt.Type] or "⚔️" end
				if nameLabel then nameLabel.Text = fArt.DisplayName or "Fodder" end
				slotFrame.BackgroundColor3 = Color3.fromRGB(26, 20, 36)
				stroke(slotFrame, C.Border, 1)
			else
				if plusLabel then plusLabel.Text = (i <= reqFodder) and "+" or "🔒" end
				if nameLabel then nameLabel.Text = (i <= reqFodder) and "Slot " .. i or "Locked" end
				slotFrame.BackgroundColor3 = C.SlotBg
				stroke(slotFrame, C.BorderDim, 1)
			end
		end
	end
end

function Forge:AutoFillFodder()
	local profile = self:ResolveProfile()
	local artifacts = profile and profile.Artifacts or {}
	local target = self.SelectedTargetUUID and artifacts[self.SelectedTargetUUID]
	if not target then return end

	local currentStar = target.Star or 1
	local reqFodder = ArtifactCatalog.GetFodderRequirement(currentStar)

	table.clear(self.FodderUUIDs)

	-- Prefer lower rarity/star copies of the same weapon.
	local candidates = {}
	for uuid, art in pairs(artifacts) do
		if uuid ~= self.SelectedTargetUUID and not art.EquippedHeroUUID and not art.Locked and target and art.TemplateId == target.TemplateId then
			table.insert(candidates, { UUID = uuid, Art = art })
		end
	end

	table.sort(candidates, function(a, b)
		local aRarity = a.Art.Rarity or 1
		local bRarity = b.Art.Rarity or 1
		if aRarity ~= bRarity then return aRarity < bRarity end
		return (a.Art.Star or 1) < (b.Art.Star or 1)
	end)

	for i = 1, math.min(reqFodder, #candidates) do
		table.insert(self.FodderUUIDs, candidates[i].UUID)
	end

	self:RenderUpgradeView()
end

function Forge:PerformUpgrade()
	if self.Busy then return end
	local profile = self:ResolveProfile()
	local artifacts = profile and profile.Artifacts or {}
	local target = self.SelectedTargetUUID and artifacts[self.SelectedTargetUUID]
	if not target then return end

	local currentStar = target.Star or 1
	local reqFodder = ArtifactCatalog.GetFodderRequirement(currentStar)

	if reqFodder == 0 or #self.FodderUUIDs ~= reqFodder then
		return
	end

	self.Busy = true
	task.spawn(function()
		local success, msg, newStar = self.RequestUpgrade:InvokeServer(self.SelectedTargetUUID, self.FodderUUIDs)
		self.Busy = false
		if success then
			table.clear(self.FodderUUIDs)
		end
		self:Refresh()
	end)
end

--============================================================================
-- SELECTION DRAWER (TARGET / FODDER / HERO LOADOUT ASSIGNMENT)
--============================================================================

function Forge:BuildPickerDrawer(root: Frame)
	local drawer = new("Frame", {
		Name = "SelectionDrawer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1.5),
		Size = UDim2.new(1, 0, 0, 240),
		BackgroundColor3 = Color3.fromRGB(16, 13, 24),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 70,
	}, root)
	self.Drawer = drawer

	applyGothicStyle(drawer, "Card")

	local header = new("Frame", {
		Name = "DrawerHeader",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 32),
		ZIndex = 71,
	}, drawer)

	local title = label(header, "SELECT ARTIFACT", 15, C.Text, Enum.Font.GothamBold)
	title.Name = "DrawerTitle"
	title.Position = UDim2.fromOffset(4, 0)
	title.Size = UDim2.new(1, -60, 1, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	self.DrawerTitle = title

	local closeDrawerBtn = new("TextButton", {
		Name = "CloseDrawerBtn",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(28, 22, 42),
		Text = "X",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(225, 210, 250),
		AutoButtonColor = false,
		ZIndex = 72,
	}, header)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, closeDrawerBtn)
	local drawerCloseStroke = stroke(closeDrawerBtn, Color3.fromRGB(80, 60, 110), 1)

	closeDrawerBtn.MouseEnter:Connect(function()
		TweenService:Create(closeDrawerBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(180, 45, 60),
			TextColor3 = Color3.fromRGB(255, 255, 255),
		}):Play()
		TweenService:Create(drawerCloseStroke, TweenInfo.new(0.15), {
			Color = Color3.fromRGB(255, 100, 120),
		}):Play()
	end)
	closeDrawerBtn.MouseLeave:Connect(function()
		TweenService:Create(closeDrawerBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(28, 22, 42),
			TextColor3 = Color3.fromRGB(225, 210, 250),
		}):Play()
		TweenService:Create(drawerCloseStroke, TweenInfo.new(0.15), {
			Color = Color3.fromRGB(80, 60, 110),
		}):Play()
	end)
	closeDrawerBtn.Activated:Connect(function()
		self:ClosePicker()
	end)

	local scroll = new("ScrollingFrame", {
		Name = "DrawerScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 46),
		Size = UDim2.new(1, -32, 1, -56),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.fromScale(0, 0),
		ZIndex = 71,
	}, drawer)
	self.DrawerScroll = scroll

	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, scroll)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	}, scroll)
end

function Forge:OpenDrawer(mode: "TARGET" | "FODDER" | "EQUIP_LOADOUT", contextUUID: string?)
	self.PickerMode = mode
	self.Drawer.Visible = true

	TweenService:Create(self.Drawer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0, 1),
	}):Play()

	local scroll = self.DrawerScroll
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	local profile = self:ResolveProfile()
	local artifacts = profile and profile.Artifacts or {}
	local heroMap = profile and profile.Heroes or {}

	if mode == "TARGET" then
		self.DrawerTitle.Text = "SELECT TARGET ARTIFACT TO ENHANCE"
		for uuid, art in pairs(artifacts) do
			local isSelected = (uuid == self.SelectedTargetUUID)
			local card = new("Frame", {
				Name = "TargetCard_" .. uuid,
				Size = UDim2.fromOffset(124, 160),
				BackgroundColor3 = isSelected and Color3.fromRGB(34, 25, 48) or C.CardBg,
				BorderSizePixel = 0,
				ZIndex = 72,
			}, scroll)
			applyGothicStyle(card, "Card")

			local iconTile = new("Frame", {
				Name = "IconTile",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				Size = UDim2.fromOffset(42, 42),
				BackgroundColor3 = Color3.fromRGB(18, 14, 28),
				BorderSizePixel = 0,
				ZIndex = 73,
			}, card)
			new("UICorner", { CornerRadius = UDim.new(0, 6) }, iconTile)
			stroke(iconTile, C.BorderDim, 1)

			local iconChar = ICON_MAP[art.Type] or "⚔️"
			local iconLbl = label(iconTile, iconChar, 24, C.Text)
			iconLbl.Position = UDim2.fromScale(0, 0)
			iconLbl.Size = UDim2.fromScale(1, 1)
			iconLbl.TextXAlignment = Enum.TextXAlignment.Center

			local nameLbl = label(card, art.DisplayName or "Artifact", 11, C.Text, Enum.Font.GothamBold)
			nameLbl.Position = UDim2.new(0, 6, 0, 56)
			nameLbl.Size = UDim2.new(1, -12, 0, 32)
			nameLbl.TextWrapped = true
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.TextXAlignment = Enum.TextXAlignment.Center

			local lvlBadge = new("Frame", {
				Name = "LvlBadge",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 92),
				Size = UDim2.new(1, -20, 0, 22),
				BackgroundColor3 = Color3.fromRGB(18, 14, 28),
				BorderSizePixel = 0,
				ZIndex = 73,
			}, card)
			new("UICorner", { CornerRadius = UDim.new(0, 4) }, lvlBadge)
			local lvlLbl = label(lvlBadge, string.format("%d stars", art.Star or 1), 11, C.GoldYellow, Enum.Font.GothamBold)
			lvlLbl.Position = UDim2.fromScale(0, 0)
			lvlLbl.Size = UDim2.fromScale(1, 1)
			lvlLbl.TextXAlignment = Enum.TextXAlignment.Center

			local actionPill = new("Frame", {
				Name = "ActionPill",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 120),
				Size = UDim2.new(1, -20, 0, 26),
				BackgroundColor3 = isSelected and Color3.fromRGB(48, 28, 72) or Color3.fromRGB(22, 18, 32),
				BorderSizePixel = 0,
				ZIndex = 73,
			}, card)
			new("UICorner", { CornerRadius = UDim.new(0, 4) }, actionPill)
			stroke(actionPill, isSelected and C.Border or C.BorderDim, 1)

			local actionLbl = label(actionPill, isSelected and "SELECTED" or "SELECT", 11, isSelected and C.Text or C.TextMuted, Enum.Font.GothamBold)
			actionLbl.Position = UDim2.fromScale(0, 0)
			actionLbl.Size = UDim2.fromScale(1, 1)
			actionLbl.TextXAlignment = Enum.TextXAlignment.Center

			local btn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 74 }, card)
			btn.Activated:Connect(function()
				self.SelectedTargetUUID = uuid
				table.clear(self.FodderUUIDs)
				self:ClosePicker()
				self:RenderUpgradeView()
			end)
		end
	elseif mode == "FODDER" then
		self.DrawerTitle.Text = "SELECT SAME-WEAPON COPIES (RARITY STAYS FIXED)"
		local target = self.SelectedTargetUUID and artifacts[self.SelectedTargetUUID]
		local req = target and ArtifactCatalog.GetFodderRequirement(target.Star or 1) or 0

		for uuid, art in pairs(artifacts) do
			if uuid ~= self.SelectedTargetUUID and not art.EquippedHeroUUID and not art.Locked and target and art.TemplateId == target.TemplateId then
				local isSlotted = table.find(self.FodderUUIDs, uuid) ~= nil
				local card = new("Frame", {
					Name = "FodderCard_" .. uuid,
					Size = UDim2.fromOffset(124, 160),
					BackgroundColor3 = isSlotted and Color3.fromRGB(34, 25, 48) or C.CardBg,
					BorderSizePixel = 0,
					ZIndex = 72,
				}, scroll)
				applyGothicStyle(card, "Card")

				local iconTile = new("Frame", {
					Name = "IconTile",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 10),
					Size = UDim2.fromOffset(42, 42),
					BackgroundColor3 = Color3.fromRGB(18, 14, 28),
					BorderSizePixel = 0,
					ZIndex = 73,
				}, card)
				new("UICorner", { CornerRadius = UDim.new(0, 6) }, iconTile)
				stroke(iconTile, C.BorderDim, 1)

				local iconChar = ICON_MAP[art.Type] or "⚔️"
				local iconLbl = label(iconTile, iconChar, 24, C.Text)
				iconLbl.Position = UDim2.fromScale(0, 0)
				iconLbl.Size = UDim2.fromScale(1, 1)
				iconLbl.TextXAlignment = Enum.TextXAlignment.Center

				local nameLbl = label(card, art.DisplayName or "Artifact", 11, C.Text, Enum.Font.GothamBold)
				nameLbl.Position = UDim2.new(0, 6, 0, 56)
				nameLbl.Size = UDim2.new(1, -12, 0, 32)
				nameLbl.TextWrapped = true
				nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nameLbl.TextXAlignment = Enum.TextXAlignment.Center

				local lvlBadge = new("Frame", {
					Name = "LvlBadge",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 92),
					Size = UDim2.new(1, -20, 0, 22),
					BackgroundColor3 = isSlotted and Color3.fromRGB(24, 60, 36) or Color3.fromRGB(18, 14, 28),
					BorderSizePixel = 0,
					ZIndex = 73,
				}, card)
				new("UICorner", { CornerRadius = UDim.new(0, 4) }, lvlBadge)
				stroke(lvlBadge, isSlotted and C.Green or C.BorderDim, 1)

				local lvlText = isSlotted and "✓ SLOTTED" or string.format("%d stars", art.Star or 1)
				local lvlColor = isSlotted and C.Green or C.TextMuted
				local lvlLbl = label(lvlBadge, lvlText, 11, lvlColor, Enum.Font.GothamBold)
				lvlLbl.Position = UDim2.fromScale(0, 0)
				lvlLbl.Size = UDim2.fromScale(1, 1)
				lvlLbl.TextXAlignment = Enum.TextXAlignment.Center

				local actionPill = new("Frame", {
					Name = "ActionPill",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 120),
					Size = UDim2.new(1, -20, 0, 26),
					BackgroundColor3 = isSlotted and Color3.fromRGB(48, 20, 28) or Color3.fromRGB(28, 22, 42),
					BorderSizePixel = 0,
					ZIndex = 73,
				}, card)
				new("UICorner", { CornerRadius = UDim.new(0, 4) }, actionPill)
				stroke(actionPill, isSlotted and C.Red or C.BorderCard, 1)

				local actionText = isSlotted and "REMOVE" or "+ ADD"
				local actionColor = isSlotted and C.Red or C.Text
				local actionLbl = label(actionPill, actionText, 11, actionColor, Enum.Font.GothamBold)
				actionLbl.Position = UDim2.fromScale(0, 0)
				actionLbl.Size = UDim2.fromScale(1, 1)
				actionLbl.TextXAlignment = Enum.TextXAlignment.Center

				local btn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 74 }, card)
				btn.Activated:Connect(function()
					if isSlotted then
						local idx = table.find(self.FodderUUIDs, uuid)
						if idx then table.remove(self.FodderUUIDs, idx) end
					else
						if #self.FodderUUIDs < req then
							table.insert(self.FodderUUIDs, uuid)
						end
					end
					self:RenderUpgradeView()
					self:OpenDrawer("FODDER")
				end)
			end
		end
	elseif mode == "EQUIP_LOADOUT" then
		local artUUID = contextUUID or self.SelectedAssignArtifactUUID
		local art = artUUID and artifacts[artUUID]
		if not art then return end

		self.DrawerTitle.Text = string.format("ASSIGN %s TO HERO", string.upper(art.DisplayName or "ARTIFACT"))

		for heroUUID, hero in pairs(heroMap) do
			local canEquip = ArtifactCatalog.CanHeroEquip(hero.Archetype, art.Type)
			local isCurrentEquipped = (hero.EquippedArtifactUUID == artUUID)

			local card = new("Frame", {
				Name = "HeroCard_" .. heroUUID,
				Size = UDim2.fromOffset(150, 160),
				BackgroundColor3 = isCurrentEquipped and Color3.fromRGB(30, 24, 46) or C.CardBg,
				BorderSizePixel = 0,
				ZIndex = 72,
			}, scroll)
			applyGothicStyle(card, "Card")

			local starsLbl = label(card, string.rep("★", hero.Stars or 1), 12, C.GoldYellow)
			starsLbl.Position = UDim2.new(0, 0, 0, 8)
			starsLbl.Size = UDim2.new(1, 0, 0, 18)
			starsLbl.TextXAlignment = Enum.TextXAlignment.Center

			local heroNameLbl = label(card, hero.DisplayName or "Hero", 14, C.Text, Enum.Font.GothamBold)
			heroNameLbl.Position = UDim2.new(0, 6, 0, 28)
			heroNameLbl.Size = UDim2.new(1, -12, 0, 20)
			heroNameLbl.TextXAlignment = Enum.TextXAlignment.Center

			local classLbl = label(card, hero.Archetype or "Class", 11, C.TextLavender)
			classLbl.Position = UDim2.new(0, 0, 0, 50)
			classLbl.Size = UDim2.new(1, 0, 0, 16)
			classLbl.TextXAlignment = Enum.TextXAlignment.Center

			local eqArt = hero.EquippedArtifactUUID and artifacts[hero.EquippedArtifactUUID]
			local eqStatusText = isCurrentEquipped and "Equipped: This Artifact" or (eqArt and ("Equipped: " .. (eqArt.DisplayName or "Artifact")) or "No Artifact")
			local eqStatusLbl = label(card, eqStatusText, 10, isCurrentEquipped and C.Green or C.TextMuted, Enum.Font.Gotham)
			eqStatusLbl.Position = UDim2.new(0, 6, 0, 72)
			eqStatusLbl.Size = UDim2.new(1, -12, 0, 16)
			eqStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
			eqStatusLbl.TextXAlignment = Enum.TextXAlignment.Center

			local actionBtn = new("TextButton", {
				Name = "HeroActionBtn",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.fromOffset(130, 32),
				BackgroundColor3 = isCurrentEquipped and Color3.fromRGB(50, 20, 28) or (canEquip and Color3.fromRGB(24, 20, 38) or Color3.fromRGB(20, 18, 26)),
				BorderSizePixel = 0,
				Text = isCurrentEquipped and "UNEQUIP" or (canEquip and (hero.EquippedArtifactUUID and "SWAP" or "EQUIP") or "INCOMPATIBLE"),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				TextColor3 = isCurrentEquipped and C.Red or (canEquip and C.Text or C.TextMuted),
				AutoButtonColor = false,
				ZIndex = 73,
			}, card)
			applyGothicStyle(actionBtn, "Button")

			if canEquip or isCurrentEquipped then
				actionBtn.Activated:Connect(function()
					if self.Busy then return end
					self.Busy = true
					task.spawn(function()
						if isCurrentEquipped then
							self.RequestUnequip:InvokeServer(heroUUID)
						else
							self.RequestEquip:InvokeServer(heroUUID, artUUID)
						end
						self.Busy = false
						self:ClosePicker()
						self:Refresh()
					end)
				end)
			end
		end
	end
end

function Forge:ClosePicker()
	self.PickerMode = "NONE"
	TweenService:Create(self.Drawer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0, 1.5),
	}):Play()
	task.delay(0.2, function()
		if self.PickerMode == "NONE" then
			self.Drawer.Visible = false
		end
	end)
end

--============================================================================
-- LIFECYCLE (OPEN, CLOSE, REFRESH)
--============================================================================

function Forge:Open(initialTab: ("ASSIGN" | "SUMMON" | "UPGRADE")?)
	self.Scrim.Visible = true
	self.Root.Visible = true
	self:SetTab(initialTab or self.ActiveTab or "ASSIGN")
end

function Forge:Close()
	self:ClosePicker()
	self.Scrim.Visible = false
	self.Root.Visible = false
	if self.OnClose then
		self.OnClose()
	end
end

function Forge:Refresh()
	if not self.Root.Visible then return end
	if self.ActiveTab == "ASSIGN" then
		self:RenderAssignView()
	elseif self.ActiveTab == "SUMMON" then
		self:RenderSummonView()
	else
		self:RenderUpgradeView()
	end
	if self.PickerMode ~= "NONE" then
		self:OpenDrawer(self.PickerMode)
	end
end

return Forge
