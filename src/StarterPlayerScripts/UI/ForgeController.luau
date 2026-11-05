--!strict
-- StarterPlayerScripts/UI/ForgeController.luau
-- Authoritative Blacksmith Forge HUD featuring 3 Sections:
--   1. ASSIGN (Inventory list of all owned artifacts with stats & 1-click hero assignment)
--   2. SUMMON (Dimensional banner gacha for artifacts: 1X & 10X pulls, 50-pull pity counter, rate-up featured items)
--   3. UPGRADE ARTIFACT (Promote weapon stars with up to 6 duplicate copies)
-- Matches exact cosmic purple aesthetic with corner diamond accents, glowing borders, and responsive scaling.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local StatFormulas = require(Shared.Util.StatFormulas)
local StatBalance = require(Shared.Config.StatBalance)
local GothicBoxStyle = require(Shared.Util.GothicBoxStyle)
local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(Shared.Util.GrimoireIcons)
local ArtifactPreview = require(script.Parent.ArtifactPreview)
local SummonLuck = require(Shared.Util.SummonLuck)

local function showArtifact(label: TextLabel, templateId: string?)
	label.TextTransparency = if ArtifactPreview.Show(label, templateId) then 1 else 0
end
local GrimoireSummonButton = require(Shared.Util.GrimoireSummonButton)
local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local ModalFit = require(script.Parent:WaitForChild("ModalFit"))
local SummonReveal = require(script.Parent:WaitForChild("SummonReveal"))
local UIFeel = require(script.Parent:WaitForChild("UIFeel"))

local LocalPlayer = Players.LocalPlayer

local Forge = {}
Forge.__index = Forge

local WIDTH, HEIGHT = 900, 620
-- Content area under the header and tabs (Gilded Grimoire layout).
local VIEW_X, VIEW_Y = 24, 108
local VIEW_W, VIEW_H = WIDTH - 48, HEIGHT - VIEW_Y - 16
-- Summon and Upgrade keep their 616 x 372 layouts, scaled up to fill the content area.
local LEGACY_W, LEGACY_H = 616, 372
local LEGACY_SCALE = math.min(VIEW_W / LEGACY_W, VIEW_H / LEGACY_H)
local LEGACY_X = VIEW_X + math.floor((VIEW_W - LEGACY_W * LEGACY_SCALE) / 2)
-- Artifact cards on the Assign tab.
local CARD_H, CARD_GAP = 228, 12
-- Weapon preview on a card: about the size of the Upgrade tab's target preview (128 x 194 scaled).
local PREVIEW_W, PREVIEW_H = 160, 200

local C = {
	Scrim = Color3.fromRGB(6, 5, 10),
	Panel = Color3.fromHex("#0D0912"),
	PanelInner = Color3.fromHex("#1F162B"),
	CardBg = Color3.fromHex("#140F1D"),
	SlotBg = Color3.fromHex("#0B0811"),
	StatBoxBg = Color3.fromHex("#120D1A"),
	Border = Color3.fromHex("#C084FC"),
	BorderGlow = Color3.fromRGB(222, 208, 255),
	BorderDim = Color3.fromHex("#443A54"),
	BorderCard = Color3.fromHex("#312740"),
	Text = Color3.fromHex("#F6F4FF"),
	TextMuted = Color3.fromHex("#8C7FA6"),
	TextLavender = Color3.fromHex("#A396BA"),
	GoldYellow = Color3.fromHex("#FACC15"),
	GoldWarm = Color3.fromHex("#E4BA73"),
	GoldDeep = Color3.fromHex("#D97706"),
	Green = Color3.fromHex("#4ADE80"),
	Red = Color3.fromHex("#E74C3C"),
	Arrow = Color3.fromHex("#4ADE80"),
	Underline = Color3.fromHex("#F6F4FF"),
	CyanEquipped = Color3.fromHex("#38BDF8"),
	CyanBg = Color3.fromHex("#0F293A"),
	CyanBorder = Color3.fromHex("#1E4E68"),
}

local ICON_MAP: { [string]: string } = {
	BOW = "🏹",
	SWORD_SHIELD = "🛡️",
	DAGGERS = "🗡️",
	AXE = "🪓",
	TOME = "📖",
	STAFF = "🪄",
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

local function applyGothicStyle(container: GuiObject, style: GothicBoxStyle.GothicStyle, opts: GothicBoxStyle.ApplyOptions?): GuiObject
	local options = opts or {}
	options.Style = style
	return GothicBoxStyle.Apply(container, options)
end

local function cornerDiamonds(parent: GuiObject, size: number, color: Color3?)
	-- Styled automatically by GothicBoxStyle
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = font or GothicBoxStyle.Font.LegacyFont or Enum.Font.GothamBold,
		Size = UDim2.new(1, 0, 0, size + 8),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
	}, parent)
	GothicBoxStyle.Font.Apply(lbl, {
		Role = if size >= 20 then "Title" else if size >= 15 then "Header" else "Body",
		Color = color,
		Size = size,
	})
	lbl:SetAttribute("Grimoire", true)
	return lbl
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
	self.RequestSell = artifactRemotes:WaitForChild("RequestSellArtifacts") :: RemoteFunction
	self.SellMode = false
	self.SelectedSellUUIDs = {} :: { [string]: boolean }
	self.ArtifactsModal = nil :: any
	self.ArtifactsModalFilter = "ALL"

	self.ActiveTab = "SUMMON" :: "ASSIGN" | "SUMMON" | "UPGRADE"
	self.SelectedAssignArtifactUUID = nil :: string?
	self.SelectedTargetUUID = nil :: string?
	self.FodderUUIDs = {} :: { string } -- Up to six same-template donor UUIDs.
	self.PickerMode = "NONE" :: "NONE" | "TARGET" | "FODDER" | "EQUIP_LOADOUT"
	self.Busy = false

	self.AssignCardPool = {} :: { any }
	self.EmptyCard = nil :: Frame?
	self.AssignRenderGeneration = 0
	self._lastAssignSig = nil :: string?

	-- 1. Scrim Background (dims world)
	self.Scrim = new("TextButton", {
		Name = "ForgeScrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1, -- no dim behind the window; still catches outside clicks
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
	local root = new("TextButton", {
		Name = "BlacksmithForgeModal",
		Text = "",
		AutoButtonColor = false,
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 51,
	}, gui)
	root.Activated:Connect(function() end)
	self.Root = root
	-- Gilded Grimoire theme: convert this screen's legacy Gotham text (now and as it is rebuilt).
	GildedGrimoire.Watch(root)

	applyGothicStyle(root, "Window")

	self.Scale = new("UIScale", {}, root)

	-- 3. Close Button (High contrast gothic rounded square with Latin 'X')
	local closeBtn = GothicBoxStyle.CreateCloseButton(root, function()
		if not self.Busy then
			self:Close()
		end
	end)
	local _ = closeBtn
	local headerIcon = GrimoireIcons.Create("Forge", 46, root, 53)
	headerIcon.Position = UDim2.fromOffset(22, 10)
	local headerTitle = label(root, "BLACKSMITH FORGE", 26, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	headerTitle.Position = UDim2.fromOffset(78, 14)
	headerTitle.Size = UDim2.fromOffset(460, 32)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.ZIndex = 53
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), GildedGrimoire.Text.Gold) }, headerTitle)

	-- 4. Top Header & 3 Tabs (ASSIGN | SUMMON | UPGRADE ARTIFACT)
	local tabContainer = new("Frame", {
		Name = "TabContainer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.new(0, 510, 0, 36),
		ZIndex = 52,
	}, root)

	local assignTabBtn = new("TextButton", {
		Name = "TabAssign",
		Text = "ASSIGN",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(140, 34),
		Position = UDim2.fromOffset(0, 0),
		ZIndex = 53,
	}, tabContainer)

	local summonTabBtn = new("TextButton", {
		Name = "TabSummon",
		Text = "SUMMON",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.Text,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(140, 34),
		Position = UDim2.fromOffset(150, 0),
		ZIndex = 53,
	}, tabContainer)

	local upgradeTabBtn = new("TextButton", {
		Name = "TabUpgrade",
		Text = "UPGRADE ARTIFACT",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(210, 34),
		Position = UDim2.fromOffset(300, 0),
		ZIndex = 53,
	}, tabContainer)

	-- Active Underline indicator (Stark white rounded pill matching gothic mockup)
	local activeIndicator = new("Frame", {
		Name = "ActiveTabIndicator",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 60, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(220, 26),
		ZIndex = 54,
	}, tabContainer)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, activeIndicator)

	self.AssignTabBtn = assignTabBtn
	self.SummonTabBtn = summonTabBtn
	self.UpgradeTabBtn = upgradeTabBtn
	self.ActiveIndicator = activeIndicator
	-- Gilded Grimoire tabs: solid buttons (a gradient would tint the label) with ink and a rail;
	-- StyleTabs paints the active one gold. The old underline is not used.
	activeIndicator.Visible = false
	for _, tab in { assignTabBtn, summonTabBtn, upgradeTabBtn } do
		tab.BackgroundTransparency = 0
		tab.AutoButtonColor = false
		tab.TextSize = 16 -- >= 16 so the theme gives tabs the heavy title face
		tab.TextStrokeColor3 = GildedGrimoire.Ink
		tab.TextStrokeTransparency = 0.2
		GildedGrimoire.Reframe(tab, { Class = "Button", Fill = false })
	end

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
		Position = UDim2.fromOffset(VIEW_X, 100),
		Size = UDim2.new(0, VIEW_W, 0, 1),
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

	-- 10. ARTIFACT BANNER VIEW & RATES MODAL
	self:BuildArtifactsModal(gui)

	-- Fit the window inside the safe area (below the top bar, clear of the bottom edge).
	ModalFit.Bind(root, self.Scale, WIDTH, HEIGHT)

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

function Forge:StyleTabs()
	for key, btn in { ASSIGN = self.AssignTabBtn, SUMMON = self.SummonTabBtn, UPGRADE = self.UpgradeTabBtn } do
		local active = self.ActiveTab == key
		btn.BackgroundColor3 = if active then Color3.fromRGB(150, 98, 30) else Color3.fromRGB(34, 28, 46)
		btn.TextColor3 = if active then Color3.new(1, 1, 1) else GildedGrimoire.Text.Muted
		local rail = GildedGrimoire.StateStroke(btn)
		if rail then
			rail.Color = if active then Color3.fromRGB(255, 226, 140) else Color3.fromRGB(110, 96, 140)
		end
	end
end

function Forge:SetTab(tab: "ASSIGN" | "SUMMON" | "UPGRADE")
	self.ActiveTab = tab
	self:ClosePicker()
	task.defer(function() self:StyleTabs() end)

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
		Position = UDim2.fromOffset(VIEW_X, VIEW_Y),
		Size = UDim2.new(0, VIEW_W, 0, VIEW_H),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.AssignView = assignView

	local headerBar = new("Frame", {
		Name = "AssignHeaderBar",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 36),
		ZIndex = 53,
	}, assignView)
	self.AssignHeaderBar = headerBar

	local capFrame = new("Frame", {
		Name = "CapacityPill",
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(170, 30),
		BackgroundColor3 = Color3.fromRGB(24, 18, 36),
		BorderSizePixel = 0,
		ZIndex = 54,
	}, headerBar)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, capFrame)
	local capStroke = new("UIStroke", { Color = Color3.fromRGB(80, 60, 110), Thickness = 1.5 }, capFrame)
	self.CapacityStroke = capStroke

	local capLabel = label(capFrame, "Artifacts: 0 / 50", 13, C.TextLavender, Enum.Font.GothamBold)
	capLabel.Position = UDim2.fromScale(0, 0)
	capLabel.Size = UDim2.fromScale(1, 1)
	capLabel.TextXAlignment = Enum.TextXAlignment.Center
	capLabel.ZIndex = 55
	self.CapacityLabel = capLabel

	local sellToggleBtn = new("TextButton", {
		Name = "SellToggleBtn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.fromOffset(140, 30),
		Text = "SELL ARTIFACTS",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 220, 120),
		BackgroundColor3 = Color3.fromRGB(36, 24, 48),
		BorderSizePixel = 0,
		ZIndex = 54,
	}, headerBar)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, sellToggleBtn)
	new("UIStroke", { Color = Color3.fromRGB(160, 120, 50), Thickness = 1.5 }, sellToggleBtn)
	self.SellToggleBtn = sellToggleBtn
	sellToggleBtn.Activated:Connect(function()
		self:ToggleSellMode()
	end)

	local sellControls = new("Frame", {
		Name = "SellControls",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.new(0, 480, 0, 30),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 54,
	}, headerBar)
	self.SellControls = sellControls

	local sellValuation = label(sellControls, "Selected: 0  |  Value: 0 Gold", 12, Color3.fromRGB(255, 220, 120), Enum.Font.GothamBold)
	sellValuation.Position = UDim2.fromOffset(0, 0)
	sellValuation.Size = UDim2.new(1, -260, 1, 0)
	sellValuation.TextXAlignment = Enum.TextXAlignment.Right
	sellValuation.ZIndex = 55
	self.SellValuationLabel = sellValuation

	local selectAllBtn = new("TextButton", {
		Name = "SelectAllBtn",
		Position = UDim2.new(1, -250, 0, 0),
		Size = UDim2.fromOffset(70, 30),
		Text = "ALL",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = C.Text,
		BackgroundColor3 = Color3.fromRGB(45, 35, 60),
		BorderSizePixel = 0,
		ZIndex = 55,
	}, sellControls)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, selectAllBtn)
	selectAllBtn.Activated:Connect(function()
		self:SelectAllUnequippedForSell()
	end)

	local confirmSellBtn = new("TextButton", {
		Name = "ConfirmSellBtn",
		Position = UDim2.new(1, -170, 0, 0),
		Size = UDim2.fromOffset(100, 30),
		Text = "SELL SELECTED",
		Font = Enum.Font.GothamBlack,
		TextSize = 11,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundColor3 = Color3.fromRGB(180, 50, 50),
		BorderSizePixel = 0,
		ZIndex = 55,
	}, sellControls)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, confirmSellBtn)
	self.ConfirmSellBtn = confirmSellBtn
	confirmSellBtn.Activated:Connect(function()
		self:ConfirmSellArtifacts()
	end)

	local cancelSellBtn = new("TextButton", {
		Name = "CancelSellBtn",
		Position = UDim2.new(1, -60, 0, 0),
		Size = UDim2.fromOffset(55, 30),
		Text = "CANCEL",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = C.TextMuted,
		BackgroundColor3 = Color3.fromRGB(30, 25, 40),
		BorderSizePixel = 0,
		ZIndex = 55,
	}, sellControls)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, cancelSellBtn)
	cancelSellBtn.Activated:Connect(function()
		self:ToggleSellMode(false)
	end)

	local scroll = new("ScrollingFrame", {
		Name = "AssignScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 53,
	}, assignView)
	self.AssignScroll = scroll
	self.AssignGrid = new("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellSize = UDim2.new(0.5, -CARD_GAP, 0, CARD_H),
		CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, scroll)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 10),
	}, scroll)
end

local function computeAssignSignature(artifacts: { [string]: any }?, heroes: { [string]: any }?): string
	if not artifacts then return "nil" end
	local count = 0
	local equipSum = 0
	local starSum = 0
	local raritySum = 0
	for _, art in pairs(artifacts) do
		count += 1
		starSum += (art.Star or 1)
		raritySum += (art.Rarity or 1)
		if art.EquippedHeroUUID then
			equipSum += 1
			local h = heroes and heroes[art.EquippedHeroUUID]
			if h then
				equipSum += (h.Level or 1)
			end
		end
	end
	return string.format("%d_%d_%d_%d", count, starSum, raritySum, equipSum)
end

-- One stat column on an artifact card: small caption over an inked number.
local function statCell(parent: Instance, x: number, caption: string, value: string): TextLabel
	local cap = label(parent, caption, 11, C.TextLavender, Enum.Font.GothamMedium)
	cap.Position = UDim2.new(x, 4, 0, 0)
	cap.Size = UDim2.new(1 / 3, -8, 0, 15)
	cap.TextXAlignment = Enum.TextXAlignment.Center
	cap.ZIndex = 56
	cap:SetAttribute("Grimoire", true)
	local val = label(parent, value, 16, C.Text, Enum.Font.GothamBlack)
	val.Position = UDim2.new(x, 4, 0, 16)
	val.Size = UDim2.new(1 / 3, -8, 0, 20)
	val.TextXAlignment = Enum.TextXAlignment.Center
	val.ZIndex = 56
	val:SetAttribute("Grimoire", true)
	GildedGrimoire.StyleText(val, "Number")
	return val
end

type CardNode = {
	Root: Frame,
	Fill: UIGradient?,
	CardRail: UIStroke?,
	IconBox: Frame,
	IconBoxGrad: UIGradient?,
	IconLabel: TextLabel,
	NameLabel: TextLabel,
	StarsLabel: TextLabel,
	Badge: Frame,
	BadgeText: TextLabel,
	CarrierLabel: TextLabel,
	PowerVal: TextLabel,
	DamageVal: TextLabel,
	AtkSpdVal: TextLabel,
	AssignBtn: TextButton,
	SellBtn: TextButton,
	SellStroke: UIStroke?,
	LastEquippedState: boolean?,
	CurrentUUID: string?,
}

local function createCard(scroll: Instance, onAssignClick: (node: CardNode) -> ()): CardNode
	local card = new("Frame", {
		Name = "ArtCard",
		BorderSizePixel = 0,
		ZIndex = 53,
		Visible = false,
	}, scroll)
	GildedGrimoire.Frame(card, { Class = "Card", Tone = "Deep", ZIndex = 53 })
	local fill = card:FindFirstChild("GrimoireFill") :: UIGradient?
	local cardRail = GildedGrimoire.StateStroke(card)
	if cardRail then
		cardRail.Thickness = 2.4
		cardRail.Transparency = 0
	end

	local iconBox = new("Frame", {
		Name = "IconBox",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(PREVIEW_W, PREVIEW_H),
		BorderSizePixel = 0,
		ZIndex = 54,
	}, card)
	applyGothicStyle(iconBox, "Slot", { State = "Filled" })
	local iconBoxGrad = new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(12, 8, 18), Color3.fromRGB(12, 8, 18)),
	}, iconBox)
	local iconLabel = label(iconBox, "⚔️", 72, C.Text)
	iconLabel.Position = UDim2.fromScale(0, 0)
	iconLabel.Size = UDim2.fromScale(1, 1)
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center
	iconLabel.ZIndex = 56
	iconLabel:SetAttribute("Grimoire", true)

	local infoX = 14 + PREVIEW_W + 16
	local nameLabel = label(card, "", 21, C.Text, Enum.Font.GothamBlack)
	nameLabel.Position = UDim2.fromOffset(infoX, 14)
	nameLabel.Size = UDim2.new(1, -infoX - 14, 0, 28)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 56

	local starsLabel = label(card, "", 22, C.GoldYellow, Enum.Font.GothamBold)
	starsLabel.Position = UDim2.fromOffset(infoX, 44)
	starsLabel.Size = UDim2.new(1, -infoX - 14, 0, 24)
	starsLabel.TextXAlignment = Enum.TextXAlignment.Left
	starsLabel.ZIndex = 56

	local badge = new("Frame", {
		Name = "RarityBadge",
		Position = UDim2.fromOffset(infoX, 72),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(180, 180, 180),
		BorderSizePixel = 0,
		ZIndex = 55,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
	new("UIStroke", { Color = GildedGrimoire.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, badge)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200)) }, badge)
	local badgeText = new("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		Text = "COMMON",
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 56,
	}, badge)
	badgeText:SetAttribute("Grimoire", true)
	GildedGrimoire.StyleText(badgeText, "Title")

	local carrierLabel = label(card, "", 14, C.TextMuted, Enum.Font.GothamMedium)
	carrierLabel.Position = UDim2.fromOffset(infoX, 102)
	carrierLabel.Size = UDim2.new(1, -infoX - 14, 0, 20)
	carrierLabel.TextXAlignment = Enum.TextXAlignment.Left
	carrierLabel.ZIndex = 56

	local strip = new("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(infoX, 128),
		Size = UDim2.new(1, -infoX - 14, 0, 44),
		BorderSizePixel = 0,
		ZIndex = 54,
	}, card)
	GildedGrimoire.Frame(strip, { Class = "Row", Tone = "Violet", ZIndex = 54 })
	local powerVal = statCell(strip, 0, "POWER", "0")
	local damageVal = statCell(strip, 1 / 3, "DAMAGE", "0")
	local atkSpdVal = statCell(strip, 2 / 3, "ATK SPD", "0")

	local assignBtn = new("TextButton", {
		Name = "AssignBtn",
		Position = UDim2.fromOffset(infoX, 176),
		Size = UDim2.new(1, -infoX - 14, 0, 38),
		BorderSizePixel = 0,
		Text = "ASSIGN TO HERO",
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 55,
	}, card)
	applyGothicStyle(assignBtn, "Button")
	assignBtn.TextStrokeColor3 = GildedGrimoire.Ink
	assignBtn.TextStrokeTransparency = 0.15
	assignBtn:SetAttribute("Grimoire", true)

	local sellBtn = new("TextButton", {
		Name = "SellBtn",
		Position = UDim2.fromOffset(infoX, 176),
		Size = UDim2.new(1, -infoX - 14, 0, 38),
		BorderSizePixel = 0,
		Text = "SELL ARTIFACT",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(50, 38, 70),
		Visible = false,
		ZIndex = 56,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, sellBtn)
	local sellStroke = new("UIStroke", { Color = Color3.fromRGB(120, 90, 160), Thickness = 1.5 }, sellBtn)

	local node: CardNode = {
		Root = card,
		Fill = fill,
		CardRail = cardRail,
		IconBox = iconBox,
		IconBoxGrad = iconBoxGrad,
		IconLabel = iconLabel,
		NameLabel = nameLabel,
		StarsLabel = starsLabel,
		Badge = badge,
		BadgeText = badgeText,
		CarrierLabel = carrierLabel,
		PowerVal = powerVal,
		DamageVal = damageVal,
		AtkSpdVal = atkSpdVal,
		AssignBtn = assignBtn,
		SellBtn = sellBtn,
		SellStroke = sellStroke,
		LastEquippedState = false,
		CurrentUUID = nil,
	}

	assignBtn.Activated:Connect(function()
		onAssignClick(node)
	end)

	sellBtn.Activated:Connect(function()
		if node.CurrentUUID then
			onAssignClick(node)
		end
	end)

	return node
end

local function updateCard(self: any, node: CardNode, item: { UUID: string, Art: any }, heroMap: any, order: number)
	local uuid = item.UUID
	local art = item.Art
	node.CurrentUUID = uuid
	node.Root.Name = "ArtCard_" .. uuid
	node.Root.LayoutOrder = order
	node.Root.Visible = true

	local rarityInfo = ArtifactCatalog.GetRarityInfo(art.Rarity or 1)
	local rarityColor = rarityInfo.Color
	local equippedHero = art.EquippedHeroUUID and heroMap[art.EquippedHeroUUID]
	local starCount = art.Star or 1
	local isEquipped = equippedHero ~= nil

	if node.Fill then
		local deep = GildedGrimoire.Tones.Deep
		node.Fill.Color = ColorSequence.new(deep.Top:Lerp(rarityColor, 0.28), deep.Bottom:Lerp(rarityColor, 0.08))
	end
	if node.CardRail then
		node.CardRail.Color = rarityColor
	end
	if node.IconBoxGrad then
		node.IconBoxGrad.Color = ColorSequence.new(Color3.fromRGB(12, 8, 18), Color3.fromRGB(12, 8, 18):Lerp(rarityColor, 0.35))
	end
	node.IconLabel.Text = ICON_MAP[art.Type] or "⚔️"
	showArtifact(node.IconLabel, art.TemplateId)
	node.NameLabel.Text = art.DisplayName or "Artifact"
	node.StarsLabel.Text = string.rep("★", starCount)

	node.Badge.BackgroundColor3 = rarityColor
	node.BadgeText.Text = string.upper(rarityInfo.Name or "Common")

	node.CarrierLabel.Text = if isEquipped
		then string.format("Equipped by <b>%s</b>  •  <font color=\"#FACC15\">Lv.%d</font>", equippedHero.DisplayName, equippedHero.Level or 1)
		else "Not equipped"
	node.CarrierLabel.TextColor3 = if isEquipped then C.CyanEquipped else C.TextMuted

	local stats = ArtifactCatalog.GetStatBreakdown(art.TemplateId, starCount, art.Rarity or 1)
	node.PowerVal.Text = string.format("%.0f", stats.Power)
	node.DamageVal.Text = string.format("x%.2f", stats.DamageMultiplier)
	node.AtkSpdVal.Text = string.format("+%.1f%%", stats["Attack Speed"])

	node.AssignBtn.Text = if isEquipped then "CHANGE HERO" else "ASSIGN TO HERO"
	if node.LastEquippedState ~= isEquipped then
		applyGothicStyle(node.AssignBtn, if isEquipped then "ButtonSecondary" else "Button")
		node.AssignBtn.TextStrokeColor3 = GildedGrimoire.Ink
		node.AssignBtn.TextStrokeTransparency = 0.15
		node.AssignBtn:SetAttribute("Grimoire", true)
		node.LastEquippedState = isEquipped
	end

	-- Sell Mode presentation
	if self.SellMode then
		node.AssignBtn.Visible = false
		node.SellBtn.Visible = true
		local canSell = not isEquipped and not art.Locked
		local sellPrice = ArtifactCatalog.CalculateSellPrice(art.Rarity or 1, art.Star or 1)
		if not canSell then
			node.SellBtn.Text = if isEquipped then "EQUIPPED" else "LOCKED"
			node.SellBtn.BackgroundColor3 = Color3.fromRGB(30, 20, 35)
			node.SellBtn.TextColor3 = Color3.fromRGB(140, 120, 140)
			if node.SellStroke then node.SellStroke.Color = Color3.fromRGB(60, 45, 70) end
			node.Root.BackgroundTransparency = 0.35
		else
			node.Root.BackgroundTransparency = 0
			local isSelected = self.SelectedSellUUIDs[uuid] == true
			if isSelected then
				node.SellBtn.Text = string.format("✓ SELECTED (+%d G)", sellPrice)
				node.SellBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
				node.SellBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				if node.SellStroke then node.SellStroke.Color = Color3.fromRGB(255, 200, 80) end
			else
				node.SellBtn.Text = string.format("SELECT (+%d G)", sellPrice)
				node.SellBtn.BackgroundColor3 = Color3.fromRGB(45, 30, 60)
				node.SellBtn.TextColor3 = Color3.fromRGB(255, 220, 120)
				if node.SellStroke then node.SellStroke.Color = Color3.fromRGB(120, 90, 160) end
			end
		end
	else
		node.AssignBtn.Visible = true
		node.SellBtn.Visible = false
		node.Root.BackgroundTransparency = 0
	end
end

local CHUNK_SIZE = 12

function Forge:RenderAssignView(force: boolean?)
	local profile = self:ResolveProfile()
	local artifacts = profile and profile.Artifacts or {}
	local heroMap = profile and profile.Heroes or {}

	local currentSig = computeAssignSignature(artifacts, heroMap)
	if not force and self._lastAssignSig == currentSig then
		return
	end
	self._lastAssignSig = currentSig

	self.AssignRenderGeneration = (self.AssignRenderGeneration or 0) + 1
	local myGen = self.AssignRenderGeneration

	local artList = {}
	for uuid, art in pairs(artifacts) do
		table.insert(artList, { UUID = uuid, Art = art })
	end

	local artCount = #artList
	local maxArt = StatBalance.MaxArtifactInventory or 50
	if self.CapacityLabel then
		self.CapacityLabel.Text = string.format("Artifacts: %d / %d", artCount, maxArt)
		if artCount >= maxArt then
			self.CapacityLabel.TextColor3 = Color3.fromRGB(248, 113, 113)
			if self.CapacityStroke then self.CapacityStroke.Color = Color3.fromRGB(239, 68, 68) end
		else
			self.CapacityLabel.TextColor3 = C.TextLavender
			if self.CapacityStroke then self.CapacityStroke.Color = Color3.fromRGB(80, 60, 110) end
		end
	end
	self:UpdateSellValuationDisplay()

	local scroll = self.AssignScroll
	self.AssignCardPool = self.AssignCardPool or {}

	if #artList == 0 then
		for _, node in ipairs(self.AssignCardPool) do
			node.Root.Visible = false
		end
		self.AssignGrid.CellSize = UDim2.new(1, -8, 0, 220)
		if not self.EmptyCard then
			local emptyCard = new("Frame", {
				Name = "EmptyCard",
				BorderSizePixel = 0,
				ZIndex = 53,
			}, scroll)
			GildedGrimoire.Frame(emptyCard, { Class = "Card", Tone = "Deep", ZIndex = 53 })
			local emptyIcon = GrimoireIcons.Create("Forge", 64, emptyCard, 55)
			emptyIcon.AnchorPoint = Vector2.new(0.5, 0)
			emptyIcon.Position = UDim2.new(0.5, 0, 0, 18)
			local emptyTitle = label(emptyCard, "NO ARTIFACTS IN INVENTORY", 20, C.Text, Enum.Font.GothamBlack)
			emptyTitle.Position = UDim2.fromOffset(0, 88)
			emptyTitle.Size = UDim2.new(1, 0, 0, 26)
			emptyTitle.ZIndex = 55
			local sub = label(emptyCard, "Visit the <b>SUMMON</b> tab to draw weapons from the dimensional banner!", 14, C.TextLavender, Enum.Font.Gotham)
			sub.Position = UDim2.fromOffset(0, 118)
			sub.Size = UDim2.new(1, 0, 0, 22)
			sub.ZIndex = 55
			local goBtn = new("TextButton", {
				Text = "GO TO SUMMON",
				Font = Enum.Font.GothamBlack,
				TextSize = 15,
				TextColor3 = Color3.new(1, 1, 1),
				AnchorPoint = Vector2.new(0.5, 0),
				Size = UDim2.fromOffset(220, 42),
				Position = UDim2.new(0.5, 0, 0, 156),
				ZIndex = 56,
			}, emptyCard)
			applyGothicStyle(goBtn, "Button")
			goBtn.TextStrokeColor3 = GildedGrimoire.Ink
			goBtn.TextStrokeTransparency = 0.15
			goBtn:SetAttribute("Grimoire", true)
			goBtn.Activated:Connect(function()
				self:SetTab("SUMMON")
			end)
			self.EmptyCard = emptyCard
		end
		self.EmptyCard.Visible = true
		return
	end

	if self.EmptyCard then
		self.EmptyCard.Visible = false
	end
	self.AssignGrid.CellSize = UDim2.new(0.5, -CARD_GAP, 0, CARD_H)

	-- Sort: Star desc, Rarity desc, Alphabetical
	table.sort(artList, function(a, b)
		local aStar, bStar = a.Art.Star or 1, b.Art.Star or 1
		if aStar ~= bStar then return aStar > bStar end
		local aR, bR = a.Art.Rarity or 1, b.Art.Rarity or 1
		if aR ~= bR then return aR > bR end
		return (a.Art.DisplayName or "") < (b.Art.DisplayName or "")
	end)

	local function onAssignClick(node: CardNode)
		if self.Busy then return end
		local uuid = node.CurrentUUID
		if not uuid then return end
		if self.SellMode then
			local prof = self:ResolveProfile()
			local art = prof and prof.Artifacts and prof.Artifacts[uuid]
			if art and not art.EquippedHeroUUID and not art.Locked then
				self.SelectedSellUUIDs[uuid] = not self.SelectedSellUUIDs[uuid]
				self:RenderAssignView(true)
			end
			return
		end
		self.SelectedAssignArtifactUUID = uuid
		self:OpenDrawer("EQUIP_LOADOUT", node.CurrentUUID)
	end

	local function renderSlice(startIdx: number, endIdx: number)
		for order = startIdx, endIdx do
			local item = artList[order]
			if not item then break end
			local node = self.AssignCardPool[order]
			if not node then
				node = createCard(scroll, onAssignClick)
				self.AssignCardPool[order] = node
			end
			updateCard(self, node, item, heroMap, order)
		end
	end

	-- Render first chunk immediately
	local firstChunkEnd = math.min(#artList, CHUNK_SIZE)
	renderSlice(1, firstChunkEnd)

	-- Hide any pooled cards beyond total items
	for i = #artList + 1, #self.AssignCardPool do
		self.AssignCardPool[i].Root.Visible = false
	end

	-- If more cards exist, defer the remaining in chunks
	if #artList > CHUNK_SIZE then
		task.spawn(function()
			local current = firstChunkEnd + 1
			while current <= #artList do
				task.wait()
				if self.AssignRenderGeneration ~= myGen then return end
				local nextEnd = math.min(#artList, current + CHUNK_SIZE - 1)
				renderSlice(current, nextEnd)
				current = nextEnd + 1
			end
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
		Position = UDim2.fromOffset(LEGACY_X, VIEW_Y),
		Size = UDim2.new(0, LEGACY_W, 0, LEGACY_H),
		ClipsDescendants = false,
		Visible = true,
		ZIndex = 52,
	}, root)
	self.SummonView = summonView
	new("UIScale", { Scale = LEGACY_SCALE }, summonView)

	-- 1. Main Featured Banner Card (Section Panel with Notched Borders & Cosmic Rift Art)
	local bannerCard = new("Frame", {
		Name = "BannerCard",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 246),
		BorderSizePixel = 0,
		ZIndex = 53,
	}, summonView)
	self.BannerCard = bannerCard
	applyGothicStyle(bannerCard, "Panel")

	-- Top Watermark Tag
	local watermark = label(bannerCard, "5-STAR FEATURED HERO & ARTIFACTS", 11, Color3.fromHex("#C4B8DB"), Enum.Font.GothamBold)
	watermark.Position = UDim2.fromOffset(20, 16)
	watermark.Size = UDim2.new(1, -40, 0, 18)
	watermark.TextXAlignment = Enum.TextXAlignment.Left
	watermark.ZIndex = 56

	-- Procedural Cosmic Rift & Glowing Greatsword Focal Art Container
	local riftContainer = new("Frame", {
		Name = "RiftArtContainer",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(210, 210),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
		ZIndex = 54,
	}, bannerCard)

	-- Arcane Vortex
	local vortex = new("Frame", {
		Name = "RiftVortex",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(190, 190),
		BackgroundColor3 = Color3.fromHex("#C084FC"),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 54,
	}, riftContainer)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, vortex)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromHex("#7E22CE")),
			ColorSequenceKeypoint.new(0.35, Color3.fromHex("#C084FC")),
			ColorSequenceKeypoint.new(0.70, Color3.fromHex("#FAF5FF")),
			ColorSequenceKeypoint.new(1.0, Color3.fromHex("#581C87")),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.8),
			NumberSequenceKeypoint.new(0.4, 0.15),
			NumberSequenceKeypoint.new(1.0, 0.85),
		}),
		Rotation = 45,
	}, vortex)

	-- Deep Rift Core
	local riftCore = new("Frame", {
		Name = "RiftCore",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(94, 94),
		BackgroundColor3 = Color3.fromHex("#07030C"),
		BorderSizePixel = 0,
		ZIndex = 55,
	}, riftContainer)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, riftCore)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromHex("#C084FC"),
		Thickness = 2.5,
		Transparency = 0.2,
	}, riftCore)

	-- Glowing Greatsword Silhouette tilted at 28 degrees
	local swordRoot = new("Frame", {
		Name = "SwordSilhouette",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(36, 140),
		BackgroundTransparency = 1,
		Rotation = 28,
		ZIndex = 56,
	}, riftContainer)

	local blade = new("Frame", {
		Name = "Blade",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 16, 0, 92),
		BackgroundColor3 = Color3.fromHex("#2E1065"),
		BorderSizePixel = 0,
		ZIndex = 56,
	}, swordRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, blade)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromHex("#F0ABFC"),
		Thickness = 1.8,
	}, blade)

	local spine = new("Frame", {
		Name = "Spine",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.05),
		Size = UDim2.new(0, 2, 0, 82),
		BackgroundColor3 = Color3.fromHex("#FAF5FF"),
		BorderSizePixel = 0,
		ZIndex = 57,
	}, blade)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, spine)

	local guard = new("Frame", {
		Name = "Crossguard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		Size = UDim2.fromOffset(40, 8),
		BackgroundColor3 = Color3.fromHex("#581C87"),
		BorderSizePixel = 0,
		ZIndex = 57,
	}, swordRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, guard)
	new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.fromHex("#E879F9"),
		Thickness = 1.5,
	}, guard)

	local hilt = new("Frame", {
		Name = "Hilt",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 98),
		Size = UDim2.fromOffset(6, 22),
		BackgroundColor3 = Color3.fromHex("#3B0764"),
		BorderSizePixel = 0,
		ZIndex = 57,
	}, swordRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, hilt)

	local pommel = new("Frame", {
		Name = "Pommel",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.fromHex("#F0ABFC"),
		BorderSizePixel = 0,
		Rotation = 45,
		ZIndex = 58,
	}, swordRoot)
	new("UICorner", { CornerRadius = UDim.new(0, 2) }, pommel)

	-- Banner Bottom Row (Title + Rate-Up Chips)
	local bannerBottom = new("Frame", {
		Name = "BannerBottomRow",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -14),
		Size = UDim2.new(1, -40, 0, 56),
		BackgroundTransparency = 1,
		ZIndex = 56,
	}, bannerCard)

	local bannerTitle = label(bannerBottom, "ECHOES OF THE RIFT", 26, C.GoldYellow, Enum.Font.GothamBlack)
	bannerTitle.Position = UDim2.fromOffset(0, 0)
	bannerTitle.Size = UDim2.new(0, 320, 0, 28)
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Left
	bannerTitle.ZIndex = 56

	-- Rate-Up Row with supported symbol and chips
	local rateUpContainer = new("Frame", {
		Name = "RateUpRow",
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		ZIndex = 56,
	}, bannerBottom)

	local rateUpLayout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, rateUpContainer)

	local rateUpPrefix = label(rateUpContainer, "Rate Up:", 12, Color3.fromHex("#C084FC"), Enum.Font.GothamBold)
	rateUpPrefix.LayoutOrder = 1
	rateUpPrefix.AutomaticSize = Enum.AutomaticSize.X
	rateUpPrefix.Size = UDim2.new(0, 0, 1, 0)

	local chip1 = new("Frame", {
		Name = "ChipGold",
		LayoutOrder = 2,
		BackgroundColor3 = Color3.fromRGB(18, 13, 26),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 22),
		ZIndex = 56,
	}, rateUpContainer)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, chip1)
	new("UIStroke", { Color = Color3.fromHex("#EAB308"), Thickness = 1 }, chip1)
	new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, chip1)
	local chip1Lbl = label(chip1, "Blade of the Rift (Tier 6)", 11, Color3.fromHex("#FDE047"), Enum.Font.GothamBold)
	chip1Lbl.Size = UDim2.fromScale(1, 1)

	local chip2 = new("Frame", {
		Name = "ChipViolet",
		LayoutOrder = 3,
		BackgroundColor3 = Color3.fromRGB(18, 13, 26),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 22),
		ZIndex = 56,
	}, rateUpContainer)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, chip2)
	new("UIStroke", { Color = Color3.fromHex("#A855F7"), Thickness = 1 }, chip2)
	new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, chip2)
	local chip2Lbl = label(chip2, "Genesis Sunderer (Tier 7)", 11, Color3.fromHex("#E9D5FF"), Enum.Font.GothamBold)
	chip2Lbl.Size = UDim2.fromScale(1, 1)

	local viewArtBtn = new("TextButton", {
		Name = "ViewArtifactsBtn",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(145, 34),
		BackgroundColor3 = Color3.fromRGB(28, 20, 42),
		Text = "VIEW ARTIFACTS",
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = C.GoldYellow,
		BorderSizePixel = 0,
		ZIndex = 58,
	}, bannerBottom)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, viewArtBtn)
	new("UIStroke", { Color = C.GoldYellow, Thickness = 1.5 }, viewArtBtn)
	viewArtBtn.Activated:Connect(function()
		self:OpenArtifactsModal()
	end)

	-- 2. Info Row (Guaranteed Pity & Timer)
	local infoRow = new("Frame", {
		Name = "InfoRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 252),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 53,
	}, summonView)

	local pityLabel = label(infoRow, "Guaranteed Exalted+ in: <b>120</b> summons", 13, Color3.fromHex("#A396BA"), Enum.Font.GothamMedium)
	pityLabel.Position = UDim2.fromOffset(2, 0)
	pityLabel.Size = UDim2.new(0.5, 0, 1, 0)
	pityLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.PityLabel = pityLabel

	local timerLabel = label(infoRow, "Event Ends: <b>2d 14h</b>", 13, Color3.fromHex("#A396BA"), Enum.Font.GothamMedium)
	timerLabel.AnchorPoint = Vector2.new(1, 0)
	timerLabel.Position = UDim2.new(1, -2, 0, 0)
	timerLabel.Size = UDim2.new(0.5, 0, 1, 0)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- Pity Bar Progress Track
	local pityTrack = new("Frame", {
		Name = "PityBarTrack",
		Position = UDim2.fromOffset(0, 272),
		Size = UDim2.new(0, 340, 0, 8),
		BackgroundColor3 = Color3.fromHex("#120D1A"),
		BorderSizePixel = 0,
		ZIndex = 53,
	}, summonView)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, pityTrack)
	new("UIStroke", { Color = Color3.fromHex("#6D5B87"), Thickness = 1 }, pityTrack)

	local pityFill = new("Frame", {
		Name = "PityBarFill",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0.02, 0, 1, 0),
		BackgroundColor3 = Color3.fromHex("#C084FC"),
		BorderSizePixel = 0,
		ZIndex = 54,
	}, pityTrack)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, pityFill)
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromHex("#7E22CE")),
			ColorSequenceKeypoint.new(0.6, Color3.fromHex("#C084FC")),
			ColorSequenceKeypoint.new(1.0, Color3.fromHex("#FEF08A")),
		}),
	}, pityFill)
	self.PityFill = pityFill

	-- 3. Summon Buttons Row (SUMMON 1X / SUMMON 10X)
	local btnRow = new("Frame", {
		Name = "ButtonRow",
		Position = UDim2.fromOffset(0, 288),
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, summonView)

	-- SUMMON 1X / 10X: Gold currency gacha buttons (5,000 Gold / 45,000 Gold)
	local btn1X = GrimoireSummonButton.new(btnRow, {
		Name = "Summon1XBtn",
		Title = "SUMMON 1X",
		Cost = 5000,
		Icon = "Gold",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(0.485, 0, 1, 0),
		ZIndex = 54,
		OnClick = function()
			if self.Busy then return end
			self:PerformSummon(1)
		end,
	})
	self.Summon1XBtn = btn1X.Root

	local btn10X = GrimoireSummonButton.new(btnRow, {
		Name = "Summon10XBtn",
		Title = "SUMMON 10X",
		Cost = 45000,
		Icon = "Gold",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0.485, 0, 1, 0),
		ZIndex = 54,
		OnClick = function()
			if self.Busy then return end
			self:PerformSummon(10)
		end,
	})
	self.Summon10XBtn = btn10X.Root
end

function Forge:RenderSummonView()
	local profile = self:ResolveProfile()
	local pity = profile and profile.ArtifactBannerPity or 0
	local maxPity = ArtifactCatalog.Banner.MaxPity or 120
	local remaining = math.max(1, maxPity - (pity % maxPity))
	local progress = math.clamp((maxPity - remaining) / maxPity, 0.02, 1)

	if self.PityLabel then
		self.PityLabel.Text = string.format("Guaranteed Exalted+ in: <b>%d</b> summons", remaining)
	end
	if self.PityFill then
		self.PityFill.Size = UDim2.new(progress, 0, 1, 0)
	end
end

function Forge:PerformSummon(count: number)
	if self.Busy then return end
	local profile = self:ResolveProfile()
	local cfg = ArtifactCatalog.Banner
	local cost = (count == 10) and cfg.Cost10X or cfg.Cost1X

	local deny = function()
		local row = self.Summon1XBtn and self.Summon1XBtn.Parent
		UIFeel.Deny(if row and row:IsA("GuiObject") then row else nil)
	end
	if not profile or not profile.Currencies or (profile.Currencies.Gold or 0) < cost then
		deny()
		if self.PityLabel then
			UIFeel.Pop(self.PityLabel, 0.12)
		end
		return
	end

	local ownedBefore: { [string]: boolean } = {}
	for _, art in profile.Artifacts or {} do
		if art.TemplateId then ownedBefore[art.TemplateId] = true end
	end
	self.Busy = true
	task.spawn(function()
		local ok, success, _msg, summonedList, pityRemaining = pcall(function()
			return self.RequestSummon:InvokeServer(count)
		end)
		self.Busy = false
		if ok and success and summonedList and #summonedList > 0 then
			if pityRemaining and self.PityLabel then
				self.PityLabel.Text = string.format("Guaranteed Exalted+ in: <b>%d</b> summons", pityRemaining)
			end
			self:ShowSummonResults(summonedList, ownedBefore)
		else
			deny()
		end
		self:Refresh()
	end)
end

--============================================================================
-- SUMMON REVEAL (shared with the hero banners: one animated beat per pull, see SummonReveal.luau)
--============================================================================

function Forge:BuildSummonRevealModal(gui: ScreenGui)
	self.Reveal = SummonReveal.new(gui)
end

-- `ownedBefore`: artifact templates owned before the pull (for the NEW badge).
function Forge:ShowSummonResults(summonedList: { any }, ownedBefore: { [string]: boolean }?)
	local seen = table.clone(ownedBefore or {})
	self.Reveal:Play(summonedList, true, {
		IsNew = function(art: any): boolean
			local id = art.TemplateId
			if not ownedBefore or not id or seen[id] then return false end
			seen[id] = true
			return true
		end,
		Cost1 = ArtifactCatalog.Banner.Cost1X,
		Cost10 = ArtifactCatalog.Banner.Cost10X,
		OnAgain = function(count: number)
			self:PerformSummon(count)
		end,
	})
end

--============================================================================
-- SECTION 3: WEAPON STAR PROMOTION VIEW (up to 6 donor slots)
--============================================================================

function Forge:BuildUpgradeView(root: Frame)
	local upgradeView = new("Frame", {
		Name = "UpgradeView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(LEGACY_X, VIEW_Y),
		Size = UDim2.new(0, LEGACY_W, 0, LEGACY_H),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.UpgradeView = upgradeView
	new("UIScale", { Scale = LEGACY_SCALE }, upgradeView)

	-- Top Grid: Left Target Slot Area (240x194) & Right Preview Panel (364x194)
	local targetArea = new("Frame", {
		Name = "TargetArea",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(240, 194),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, upgradeView)

	-- Target Slot Card (Rounded Slot)
	local targetSlot = new("Frame", {
		Name = "TargetSlotCard",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(128, 194),
		BorderSizePixel = 0,
		ZIndex = 53,
	}, targetArea)
	applyGothicStyle(targetSlot, "Slot", { State = "Filled" })
	self.TargetSlotFrame = targetSlot

	local targetIcon = label(targetSlot, "🪓", 56, C.Text)
	targetIcon.Name = "TargetIcon"
	targetIcon.Position = UDim2.fromScale(0, 0)
	targetIcon.Size = UDim2.fromScale(1, 1)
	targetIcon.TextXAlignment = Enum.TextXAlignment.Center
	self.TargetIcon = targetIcon

	local targetBtn = new("TextButton", {
		Name = "TargetSlotBtn",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 55,
	}, targetSlot)
	targetBtn.Activated:Connect(function()
		self:OpenDrawer("TARGET")
	end)

	-- Target Meta (Right of Target Slot Card)
	local targetMeta = new("Frame", {
		Name = "TargetMeta",
		Position = UDim2.fromOffset(140, 12),
		Size = UDim2.fromOffset(96, 170),
		BackgroundTransparency = 1,
		ZIndex = 54,
	}, targetArea)

	local targetName = label(targetMeta, "Prospector's\nCleaver", 16, C.Text, Enum.Font.GothamBold)
	targetName.Name = "TargetName"
	targetName.Position = UDim2.fromOffset(0, 0)
	targetName.Size = UDim2.new(1, 0, 0, 48)
	targetName.TextWrapped = true
	targetName.TextXAlignment = Enum.TextXAlignment.Left
	targetName.TextYAlignment = Enum.TextYAlignment.Top
	self.TargetName = targetName

	local targetRarityBadge = new("Frame", {
		Name = "TargetRarityBadge",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.fromOffset(94, 22),
		BackgroundColor3 = Color3.fromHex("#2B2832"),
		BorderSizePixel = 0,
		ZIndex = 54,
	}, targetMeta)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, targetRarityBadge)
	new("UIStroke", { Color = Color3.fromHex("#6E6A78"), Thickness = 1 }, targetRarityBadge)

	local targetLevel = label(targetRarityBadge, "Common · 1★", 11, Color3.fromHex("#E2E0E8"), Enum.Font.GothamBold)
	targetLevel.Name = "TargetLevel"
	targetLevel.Position = UDim2.fromScale(0, 0)
	targetLevel.Size = UDim2.fromScale(1, 1)
	targetLevel.TextXAlignment = Enum.TextXAlignment.Center
	self.TargetLevel = targetLevel

	local changeTargetBtn = new("TextButton", {
		Name = "ChangeTargetBtn",
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.fromOffset(94, 28),
		Text = "CHANGE",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		ZIndex = 55,
	}, targetMeta)
	applyGothicStyle(changeTargetBtn, "ButtonSecondary")
	changeTargetBtn.Activated:Connect(function()
		self:OpenDrawer("TARGET")
	end)

	-- Right: Star Promotion Preview Panel (Section Panel Style)
	local previewPanel = new("Frame", {
		Name = "PreviewPanel",
		Position = UDim2.fromOffset(252, 0),
		Size = UDim2.new(1, -252, 0, 194),
		BorderSizePixel = 0,
		ZIndex = 53,
	}, upgradeView)
	applyGothicStyle(previewPanel, "Panel")

	local previewHeading = label(previewPanel, "STAR PROMOTION PREVIEW", 13, C.GoldWarm, Enum.Font.GothamBold)
	previewHeading.Position = UDim2.fromOffset(16, 12)
	previewHeading.Size = UDim2.new(1, -32, 0, 18)
	previewHeading.TextXAlignment = Enum.TextXAlignment.Left

	-- Stat Comparison Table
	local statTable = new("Frame", {
		Name = "StatTable",
		Position = UDim2.fromOffset(16, 34),
		Size = UDim2.new(1, -32, 0, 114),
		BackgroundTransparency = 1,
		ZIndex = 54,
	}, previewPanel)

	new("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
	}, statTable)

	local function createStatRow(name: string, labelText: string, order: number)
		local row = new("Frame", {
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			ZIndex = 54,
		}, statTable)

		local lbl = label(row, labelText, 12, Color3.fromHex("#A396BA"), Enum.Font.GothamMedium)
		lbl.Position = UDim2.fromOffset(0, 0)
		lbl.Size = UDim2.new(0, 140, 1, 0)
		lbl.TextXAlignment = Enum.TextXAlignment.Left

		local oldVal = label(row, "—", 12, Color3.fromHex("#F6F4FF"), Enum.Font.GothamBold)
		oldVal.Name = "OldVal"
		oldVal.Position = UDim2.new(0, 140, 0, 0)
		oldVal.Size = UDim2.new(0, 60, 1, 0)
		oldVal.TextXAlignment = Enum.TextXAlignment.Right

		local arrow = label(row, "→", 12, Color3.fromHex("#4ADE80"), Enum.Font.GothamBold)
		arrow.Position = UDim2.new(0, 202, 0, 0)
		arrow.Size = UDim2.new(0, 24, 1, 0)
		arrow.TextXAlignment = Enum.TextXAlignment.Center

		local newVal = label(row, "—", 12, Color3.fromHex("#4ADE80"), Enum.Font.GothamBold)
		newVal.Name = "NewVal"
		newVal.Position = UDim2.new(0, 228, 0, 0)
		newVal.Size = UDim2.new(1, -228, 1, 0)
		newVal.TextXAlignment = Enum.TextXAlignment.Left

		return { Row = row, Old = oldVal, New = newVal }
	end

	self.StatRows = {
		Power = createStatRow("PowerRow", "Power:", 1),
		Damage = createStatRow("DamageRow", "Damage Multiplier:", 2),
		AtkSpd = createStatRow("AtkSpdRow", "AtkSpd:", 3),
		DPS = createStatRow("DPSRow", "Hit / DPS:", 4),
	}

	-- Preview Cost Footer
	local footerLine = new("Frame", {
		Name = "FooterDivider",
		Position = UDim2.fromOffset(16, 154),
		Size = UDim2.new(1, -32, 0, 1),
		BackgroundColor3 = Color3.fromHex("#352B47"),
		BorderSizePixel = 0,
		ZIndex = 54,
	}, previewPanel)

	local footerLabel = label(previewPanel, "Copies: <b>0/1</b>  |  Gold: <b>500</b>  |  Gems: <b>0</b>", 12, Color3.fromHex("#A396BA"), Enum.Font.Gotham)
	footerLabel.Position = UDim2.fromOffset(16, 160)
	footerLabel.Size = UDim2.new(1, -32, 0, 24)
	footerLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.FodderReqLabel = footerLabel

	-- 6 Fodder Slots Container
	local fodderContainer = new("Frame", {
		Name = "FodderSlotsContainer",
		Position = UDim2.fromOffset(0, 206),
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, upgradeView)

	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}, fodderContainer)

	self.FodderSlotFrames = {}
	local slotW = 92

	for i = 1, 6 do
		local slot = new("Frame", {
			Name = "FodderSlot_" .. i,
			Size = UDim2.fromOffset(slotW, 94),
			BorderSizePixel = 0,
			LayoutOrder = i,
			ZIndex = 53,
		}, fodderContainer)
		applyGothicStyle(slot, "Slot", { State = "Empty" })

		local plus = label(slot, "+", 26, Color3.fromHex("#B4A5D1"), Enum.Font.GothamBold)
		plus.Name = "PlusLabel"
		plus.Position = UDim2.fromScale(0, 0.12)
		plus.Size = UDim2.fromScale(1, 0.44)
		plus.TextXAlignment = Enum.TextXAlignment.Center

		local name = label(slot, "Slot " .. i, 11, Color3.fromHex("#8C7FA6"), Enum.Font.Gotham)
		name.Name = "NameLabel"
		name.Position = UDim2.fromScale(0, 0.58)
		name.Size = UDim2.fromScale(1, 0.32)
		name.TextXAlignment = Enum.TextXAlignment.Center

		local slotBtn = new("TextButton", {
			Name = "SlotBtn",
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 55,
		}, slot)
		slotBtn.Activated:Connect(function()
			self:OpenDrawer("FODDER")
		end)

		table.insert(self.FodderSlotFrames, slot)
	end

	-- Bottom Action Row (Auto-Fill & Enhance Button)
	local bottomRow = new("Frame", {
		Name = "BottomActionRow",
		Position = UDim2.fromOffset(0, 314),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, upgradeView)

	local autoFillBtn = new("TextButton", {
		Name = "AutoFillBtn",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(240, 46),
		BorderSizePixel = 0,
		Text = "AUTO-FILL FODDER",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		ZIndex = 54,
	}, bottomRow)
	applyGothicStyle(autoFillBtn, "ButtonSecondary")
	self.AutoFillBtn = autoFillBtn
	autoFillBtn.Activated:Connect(function()
		self:AutoFillFodder()
	end)

	local enhanceBtn = new("TextButton", {
		Name = "EnhanceBtn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(1, -252, 0, 46),
		BorderSizePixel = 0,
		Text = "PROMOTE TO 2 STARS (0/1)",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		ZIndex = 54,
	}, bottomRow)
	applyGothicStyle(enhanceBtn, "ButtonPrimary", { Disabled = true })
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
		showArtifact(self.TargetIcon, nil)
		self.TargetName.Text = "NO ARTIFACT"
		self.TargetLevel.Text = "Click to pick"
		if self.StatRows then
			self.StatRows.Power.Old.Text = "—"
			self.StatRows.Power.New.Text = "—"
			self.StatRows.Damage.Old.Text = "—"
			self.StatRows.Damage.New.Text = "—"
			self.StatRows.AtkSpd.Old.Text = "—"
			self.StatRows.AtkSpd.New.Text = "—"
			self.StatRows.DPS.Old.Text = "—"
			self.StatRows.DPS.New.Text = "—"
		end
		self.FodderReqLabel.Text = "Copies: <b>0/0</b>  |  Gold: <b>0</b>  |  Gems: <b>0</b>"
		applyGothicStyle(self.EnhanceBtn, "ButtonPrimary", { Disabled = true })
		self.EnhanceBtn.Text = "NO ARTIFACT SELECTED"
		return
	end

	local currentStar = target.Star or 1
	local maxStars = ArtifactCatalog.MaxStars or 7
	local reqFodder = ArtifactCatalog.GetFodderRequirement(currentStar)
	local rarityInfo = ArtifactCatalog.GetRarityInfo(target.Rarity or 1)
	local rarityColor = rarityInfo.Color

	-- Update Target Slot Card
	local iconChar = ICON_MAP[target.Type] or "⚔️"
	self.TargetIcon.Text = iconChar
	showArtifact(self.TargetIcon, target.TemplateId)
	self.TargetName.Text = target.DisplayName or "Artifact"
	self.TargetLevel.Text = string.format("%s · %d★", rarityInfo.Name, currentStar)
	if self.TargetSlotFrame then
		applyGothicStyle(self.TargetSlotFrame, "Slot", { State = "Filled", AccentColor = rarityColor })
	end

	-- Current and Next Stat Breakdown
	local currStats = ArtifactCatalog.GetStatBreakdown(target.TemplateId, currentStar, target.Rarity or 1)
	local simNext = {
		TemplateId = target.TemplateId,
		Star = math.min(maxStars, currentStar + 1),
		Rarity = target.Rarity,
		Type = target.Type,
	}
	local nextStats = ArtifactCatalog.GetStatBreakdown(simNext.TemplateId, simNext.Star, simNext.Rarity or 1)

	if self.StatRows then
		self.StatRows.Power.Old.Text = string.format("%.0f", currStats.Power)
		self.StatRows.Power.New.Text = string.format("%.0f", nextStats.Power)

		self.StatRows.Damage.Old.Text = string.format("x%.2f", currStats.DamageMultiplier)
		self.StatRows.Damage.New.Text = string.format("x%.2f", nextStats.DamageMultiplier)

		self.StatRows.AtkSpd.Old.Text = string.format("+%.1f%%", currStats["Attack Speed"])
		self.StatRows.AtkSpd.New.Text = string.format("+%.1f%%", nextStats["Attack Speed"])

		local equippedHero = target.EquippedHeroUUID and profile.Heroes and profile.Heroes[target.EquippedHeroUUID]
		if equippedHero then
			local before = StatFormulas.GetCombatSnapshot(equippedHero, target)
			local nextWeapon = table.clone(target)
			nextWeapon.Star = math.min(maxStars, currentStar + 1)
			local after = StatFormulas.GetCombatSnapshot(equippedHero, nextWeapon)
			self.StatRows.DPS.Old.Text = StatBalance.Format(before.DPS)
			self.StatRows.DPS.New.Text = StatBalance.Format(after.DPS)
		else
			self.StatRows.DPS.Old.Text = "—"
			self.StatRows.DPS.New.Text = "—"
		end
	end

	-- Cost & Copies
	local isMaxRank = (currentStar >= maxStars)
	local cost = ArtifactCatalog.GetStarPromotionCost(currentStar) or { Gold = 0, Gems = 0 }
	local copiesCount = #self.FodderUUIDs
	local copiesColor = if copiesCount >= reqFodder and reqFodder > 0 then "#4ADE80" else "#F6F4FF"

	if isMaxRank then
		self.FodderReqLabel.Text = "<font color=\"#E4BA73\"><b>MAXIMUM 7-STAR RANK REACHED</b></font>"
		self.EnhanceBtn.Text = "MAX STARS REACHED"
		applyGothicStyle(self.EnhanceBtn, "ButtonPrimary", { Disabled = true })
	else
		self.FodderReqLabel.Text = string.format(
			"Copies: <font color=\"%s\"><b>%d/%d</b></font>  |  Gold: <b>%s</b>  |  Gems: <b>%d</b>",
			copiesColor,
			copiesCount,
			reqFodder,
			StatBalance.Format(cost.Gold),
			cost.Gems
		)

		if not (profile and profile.Unlocks and profile.Unlocks.Forge) then
			-- Phase 4 onboarding: weapon promotion opens after clearing Floor 1.
			self.EnhanceBtn.Text = "CLEAR FLOOR 1 TO UNLOCK PROMOTION"
			applyGothicStyle(self.EnhanceBtn, "ButtonPrimary", { Disabled = true })
		elseif copiesCount >= reqFodder and reqFodder > 0 then
			self.EnhanceBtn.Text = string.format("PROMOTE TO %d STARS (%d/%d)", currentStar + 1, copiesCount, reqFodder)
			applyGothicStyle(self.EnhanceBtn, "ButtonPrimary", { Variant = "Gold", Disabled = false })
		else
			self.EnhanceBtn.Text = string.format("PROMOTE TO %d STARS (%d/%d)", currentStar + 1, copiesCount, reqFodder)
			applyGothicStyle(self.EnhanceBtn, "ButtonPrimary", { Disabled = true })
		end
	end

	-- Update 6 Fodder Slots (without stacking duplicate UIStroke instances!)
	for i = 1, 6 do
		local slotFrame = self.FodderSlotFrames[i]
		if slotFrame then
			local plusLabel = slotFrame:FindFirstChild("PlusLabel") :: TextLabel?
			local lockIcon = slotFrame:FindFirstChild("GrimoireIcon_Lock") :: Frame?
			if not lockIcon then
				lockIcon = GrimoireIcons.Create("Lock", 30, slotFrame, slotFrame.ZIndex + 1)
				;(lockIcon :: Frame).AnchorPoint = Vector2.new(0.5, 0.5)
				;(lockIcon :: Frame).Position = UDim2.fromScale(0.5, 0.34)
			end
			;(lockIcon :: Frame).Visible = false
			local nameLabel = slotFrame:FindFirstChild("NameLabel") :: TextLabel?
			local fUUID = self.FodderUUIDs[i]
			local fArt = fUUID and artifacts[fUUID]
			if plusLabel then showArtifact(plusLabel, fArt and fArt.TemplateId) end

			if fArt then
				local fRarity = ArtifactCatalog.GetRarityInfo(fArt.Rarity or 1)
				applyGothicStyle(slotFrame, "Slot", { State = "Filled", AccentColor = fRarity.Color })
				if plusLabel then
					plusLabel.Text = ICON_MAP[fArt.Type] or "⚔️"
					plusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
				end
				if nameLabel then
					nameLabel.Text = string.format("%s %d★", fArt.DisplayName or "Fodder", fArt.Star or 1)
					nameLabel.TextColor3 = Color3.fromRGB(246, 244, 255)
				end
			elseif i <= reqFodder then
				applyGothicStyle(slotFrame, "Slot", { State = "Empty" })
				if plusLabel then
					plusLabel.Text = "+"
					plusLabel.TextColor3 = Color3.fromHex("#B4A5D1")
				end
				if nameLabel then
					nameLabel.Text = "Slot " .. i
					nameLabel.TextColor3 = Color3.fromHex("#8C7FA6")
				end
			else
				applyGothicStyle(slotFrame, "Slot", { State = "Locked" })
				if plusLabel then
					plusLabel.Text = ""
				end
				;(lockIcon :: Frame).Visible = true
				if nameLabel then
					nameLabel.Text = "Req. " .. (i + 1) .. "★"
					nameLabel.TextColor3 = Color3.fromHex("#706484")
				end
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

	applyGothicStyle(drawer, "Panel")

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
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(225, 210, 250),
		AutoButtonColor = false,
		ZIndex = 72,
	}, header)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, closeDrawerBtn)
	GrimoireIcons.CloseGlyph(closeDrawerBtn, 13)
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
			local rarityInfo = ArtifactCatalog.GetRarityInfo(art.Rarity or 1)

			local card = new("Frame", {
				Name = "TargetCard_" .. uuid,
				Size = UDim2.fromOffset(128, 164),
				BorderSizePixel = 0,
				ZIndex = 72,
			}, scroll)
			applyGothicStyle(card, "Row", { AccentColor = rarityInfo.Color })

			local iconTile = new("Frame", {
				Name = "IconTile",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				Size = UDim2.fromOffset(46, 46),
				BorderSizePixel = 0,
				ZIndex = 73,
			}, card)
			applyGothicStyle(iconTile, "Slot", { State = "Filled", AccentColor = rarityInfo.Color })

			local iconChar = ICON_MAP[art.Type] or "⚔️"
			local iconLbl = label(iconTile, iconChar, 24, C.Text)
			iconLbl.Position = UDim2.fromScale(0, 0)
			iconLbl.Size = UDim2.fromScale(1, 1)
			iconLbl.TextXAlignment = Enum.TextXAlignment.Center
			showArtifact(iconLbl, art.TemplateId)

			local nameLbl = label(card, art.DisplayName or "Artifact", 11, C.Text, Enum.Font.GothamBold)
			nameLbl.Position = UDim2.new(0, 6, 0, 60)
			nameLbl.Size = UDim2.new(1, -12, 0, 30)
			nameLbl.TextWrapped = true
			nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			nameLbl.TextXAlignment = Enum.TextXAlignment.Center

			local lvlBadge = new("Frame", {
				Name = "LvlBadge",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 94),
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

			local selectBtn = new("TextButton", {
				Name = "SelectBtn",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 122),
				Size = UDim2.new(1, -20, 0, 28),
				Text = isSelected and "SELECTED" or "SELECT",
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				ZIndex = 74,
			}, card)

			if isSelected then
				applyGothicStyle(selectBtn, "ButtonSecondary")
			else
				applyGothicStyle(selectBtn, "ButtonPrimary", { Variant = "Gold" })
			end

			selectBtn.Activated:Connect(function()
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
				local rarityInfo = ArtifactCatalog.GetRarityInfo(art.Rarity or 1)

				local card = new("Frame", {
					Name = "FodderCard_" .. uuid,
					Size = UDim2.fromOffset(128, 164),
					BorderSizePixel = 0,
					ZIndex = 72,
				}, scroll)
				applyGothicStyle(card, "Row", { AccentColor = rarityInfo.Color })

				local iconTile = new("Frame", {
					Name = "IconTile",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 10),
					Size = UDim2.fromOffset(46, 46),
					BorderSizePixel = 0,
					ZIndex = 73,
				}, card)
				applyGothicStyle(iconTile, "Slot", { State = "Filled", AccentColor = rarityInfo.Color })

				local iconChar = ICON_MAP[art.Type] or "⚔️"
				local iconLbl = label(iconTile, iconChar, 24, C.Text)
				iconLbl.Position = UDim2.fromScale(0, 0)
				iconLbl.Size = UDim2.fromScale(1, 1)
				iconLbl.TextXAlignment = Enum.TextXAlignment.Center
				showArtifact(iconLbl, art.TemplateId)

				local nameLbl = label(card, art.DisplayName or "Artifact", 11, C.Text, Enum.Font.GothamBold)
				nameLbl.Position = UDim2.new(0, 6, 0, 60)
				nameLbl.Size = UDim2.new(1, -12, 0, 30)
				nameLbl.TextWrapped = true
				nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nameLbl.TextXAlignment = Enum.TextXAlignment.Center

				local lvlBadge = new("Frame", {
					Name = "LvlBadge",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 94),
					Size = UDim2.new(1, -20, 0, 22),
					BackgroundColor3 = isSlotted and Color3.fromRGB(24, 60, 36) or Color3.fromRGB(18, 14, 28),
					BorderSizePixel = 0,
					ZIndex = 73,
				}, card)
				new("UICorner", { CornerRadius = UDim.new(0, 4) }, lvlBadge)
				stroke(lvlBadge, isSlotted and C.Green or C.BorderDim, 1)

				local lvlText = isSlotted and "SLOTTED" or string.format("%d stars", art.Star or 1)
				local lvlColor = isSlotted and C.Green or C.TextMuted
				local lvlLbl = label(lvlBadge, lvlText, 11, lvlColor, Enum.Font.GothamBold)
				lvlLbl.Position = UDim2.fromScale(0, 0)
				lvlLbl.Size = UDim2.fromScale(1, 1)
				lvlLbl.TextXAlignment = Enum.TextXAlignment.Center

				local fodderBtn = new("TextButton", {
					Name = "FodderActionBtn",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 122),
					Size = UDim2.new(1, -20, 0, 28),
					Text = isSlotted and "REMOVE" or "+ ADD",
					Font = Enum.Font.GothamBold,
					TextSize = 11,
					ZIndex = 74,
				}, card)

				if isSlotted then
					applyGothicStyle(fodderBtn, "ButtonSecondary")
				else
					applyGothicStyle(fodderBtn, "ButtonPrimary", { Variant = "Gold" })
				end

				fodderBtn.Activated:Connect(function()
					if isSlotted then
						local idx = table.find(self.FodderUUIDs, uuid)
						if idx then table.remove(self.FodderUUIDs, idx) end
						self:RenderUpgradeView()
						self:OpenDrawer("FODDER")
					else
						if #self.FodderUUIDs < req then
							table.insert(self.FodderUUIDs, uuid)
						end
						self:ClosePicker()
						self:RenderUpgradeView()
					end
				end)
			end
		end
	elseif mode == "EQUIP_LOADOUT" then
		local artUUID = contextUUID or self.SelectedAssignArtifactUUID
		local art = artUUID and artifacts[artUUID]
		if not art then return end

		self.DrawerTitle.Text = string.format("ASSIGN %s (%s) TO HERO", string.upper(art.DisplayName or "ARTIFACT"), string.upper(art.Type or "WEAPON"))

		-- Collect only compatible heroes (hide incompatible ones)
		local compatibleList = {}
		for heroUUID, hero in pairs(heroMap) do
			local heroArchetype = hero.Archetype or (hero.TemplateId and HeroCatalog.Seeds[hero.TemplateId] and HeroCatalog.Seeds[hero.TemplateId].Archetype) or "Striker"
			local canEquip = ArtifactCatalog.CanHeroEquip(heroArchetype, art.Type)
			local isCurrentEquipped = (hero.EquippedArtifactUUID == artUUID)

			if canEquip or isCurrentEquipped then
				table.insert(compatibleList, {
					UUID = heroUUID,
					Hero = hero,
					Archetype = heroArchetype,
					IsCurrent = isCurrentEquipped,
				})
			end
		end

		-- Deterministic sorting: currently equipped first, then highest level, then highest stars, then name
		table.sort(compatibleList, function(a, b)
			if a.IsCurrent ~= b.IsCurrent then
				return a.IsCurrent
			end
			local aLvl = a.Hero.Level or 1
			local bLvl = b.Hero.Level or 1
			if aLvl ~= bLvl then
				return aLvl > bLvl
			end
			local aStars = a.Hero.Stars or 1
			local bStars = b.Hero.Stars or 1
			if aStars ~= bStars then
				return aStars > bStars
			end
			return (a.Hero.DisplayName or "") < (b.Hero.DisplayName or "")
		end)

		if #compatibleList == 0 then
			local emptyLbl = label(scroll, string.format("No compatible %s heroes found in your roster.", art.Type or "weapon"), 14, C.TextMuted, Enum.Font.GothamMedium)
			emptyLbl.Position = UDim2.fromOffset(20, 50)
			emptyLbl.Size = UDim2.new(1, -40, 0, 36)
			emptyLbl.TextXAlignment = Enum.TextXAlignment.Center
			return
		end

		for order, entry in ipairs(compatibleList) do
			local heroUUID = entry.UUID
			local hero = entry.Hero
			local heroArchetype = entry.Archetype
			local isCurrentEquipped = entry.IsCurrent

			local starCount = hero.Stars or 1
			local starColor = (starCount >= 5) and C.GoldYellow or ((starCount >= 4) and Color3.fromRGB(192, 132, 252) or C.TextLavender)

			local card = new("Frame", {
				Name = "HeroCard_" .. heroUUID,
				Size = UDim2.fromOffset(150, 168),
				BorderSizePixel = 0,
				LayoutOrder = order,
				ZIndex = 72,
			}, scroll)
			applyGothicStyle(card, "Row", { AccentColor = if isCurrentEquipped then C.Green else starColor })

			-- Hero Icon / Portrait
			local portraitHost = new("Frame", {
				Name = "PortraitHost",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(54, 54),
				BackgroundColor3 = Color3.fromRGB(14, 10, 22),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				ZIndex = 73,
			}, card)
			new("UICorner", { CornerRadius = UDim.new(0, 8) }, portraitHost)
			local portStroke = stroke(portraitHost, if isCurrentEquipped then C.Green else starColor, 1.2)
			portStroke.Transparency = 0.4

			pcall(HeroCard.Portrait, portraitHost, hero)

			-- Level badge pill on bottom-left of portrait
			local lvlPill = new("Frame", {
				Name = "LevelPill",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 2, 1, -2),
				Size = UDim2.fromOffset(36, 15),
				BackgroundColor3 = Color3.fromRGB(8, 6, 12),
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				ZIndex = 75,
			}, portraitHost)
			new("UICorner", { CornerRadius = UDim.new(0, 4) }, lvlPill)
			local lvlLbl = label(lvlPill, string.format("Lv.%d", hero.Level or 1), 10, C.GoldYellow, Enum.Font.GothamBold)
			lvlLbl.Size = UDim2.fromScale(1, 1)
			lvlLbl.TextXAlignment = Enum.TextXAlignment.Center
			lvlLbl.ZIndex = 76

			-- Archetype icon badge on bottom-right of portrait
			local archPill = new("Frame", {
				Name = "ArchPill",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -2, 1, -2),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = Color3.fromRGB(8, 6, 12),
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				ZIndex = 75,
			}, portraitHost)
			new("UICorner", { CornerRadius = UDim.new(0, 4) }, archPill)
			pcall(function()
				GrimoireIcons.Create(heroArchetype, 14, archPill, 76)
			end)

			-- Hero Name
			local heroNameLbl = label(card, hero.DisplayName or "Hero", 13, C.Text, Enum.Font.GothamBold)
			heroNameLbl.Position = UDim2.new(0, 6, 0, 65)
			heroNameLbl.Size = UDim2.new(1, -12, 0, 16)
			heroNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
			heroNameLbl.TextXAlignment = Enum.TextXAlignment.Center
			heroNameLbl.ZIndex = 73

			-- Hero Level, Stars & Archetype subtitle
			local heroSubLbl = label(card, string.format("<font color=\"#FACC15\">%s</font>  Lv.%d  •  %s", string.rep("★", starCount), hero.Level or 1, heroArchetype), 11, C.TextLavender, Enum.Font.GothamMedium)
			heroSubLbl.Position = UDim2.new(0, 6, 0, 82)
			heroSubLbl.Size = UDim2.new(1, -12, 0, 14)
			heroSubLbl.TextTruncate = Enum.TextTruncate.AtEnd
			heroSubLbl.TextXAlignment = Enum.TextXAlignment.Center
			heroSubLbl.ZIndex = 73

			-- Equipment Status
			local eqArt = hero.EquippedArtifactUUID and artifacts[hero.EquippedArtifactUUID]
			local eqStatusText = isCurrentEquipped and "<font color=\"#4ADE80\">Equipped: This</font>" or (eqArt and ("Equipped: " .. (eqArt.DisplayName or "Artifact")) or "No Artifact")
			local eqStatusColor = if isCurrentEquipped then C.Green else (if eqArt then C.TextLavender else C.TextMuted)
			local eqStatusLbl = label(card, eqStatusText, 10, eqStatusColor, Enum.Font.Gotham)
			eqStatusLbl.Position = UDim2.new(0, 6, 0, 98)
			eqStatusLbl.Size = UDim2.new(1, -12, 0, 14)
			eqStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
			eqStatusLbl.TextXAlignment = Enum.TextXAlignment.Center
			eqStatusLbl.ZIndex = 73

			-- Action Button (EQUIP / UNEQUIP / SWAP)
			local actionBtn = new("TextButton", {
				Name = "HeroActionBtn",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.fromOffset(130, 28),
				BorderSizePixel = 0,
				Text = isCurrentEquipped and "UNEQUIP" or (hero.EquippedArtifactUUID and "SWAP" or "EQUIP"),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				ZIndex = 74,
			}, card)

			if isCurrentEquipped then
				applyGothicStyle(actionBtn, "ButtonSecondary")
			else
				applyGothicStyle(actionBtn, "ButtonPrimary", { Variant = "Gold" })
			end

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
	self:SetTab(initialTab or "SUMMON")
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


--============================================================================
-- SECTION 4: SELLING ARTIFACTS & "VIEW ARTIFACTS" MODAL
--============================================================================

function Forge:ToggleSellMode(enable: boolean?)
	self.SellMode = if enable ~= nil then enable else not self.SellMode
	self.SelectedSellUUIDs = {}
	if self.SellControls then self.SellControls.Visible = self.SellMode end
	if self.SellToggleBtn then self.SellToggleBtn.Visible = not self.SellMode end
	self:RenderAssignView(true)
end

function Forge:UpdateSellValuationDisplay()
	if not self.SellValuationLabel then return end
	local profile = self:ResolveProfile()
	local artifacts = profile and profile.Artifacts or {}
	local totalVal = 0
	local count = 0
	for uuid, sel in pairs(self.SelectedSellUUIDs) do
		if sel and artifacts[uuid] then
			local art = artifacts[uuid]
			totalVal += ArtifactCatalog.CalculateSellPrice(art.Rarity or 1, art.Star or 1)
			count += 1
		end
	end
	self.SellValuationLabel.Text = string.format("Selected: %d  |  Value: %s Gold", count, tostring(totalVal))
end

function Forge:SelectAllUnequippedForSell()
	local profile = self:ResolveProfile()
	local artifacts = profile and profile.Artifacts or {}
	for uuid, art in pairs(artifacts) do
		if not art.EquippedHeroUUID and not art.Locked then
			self.SelectedSellUUIDs[uuid] = true
		end
	end
	self:RenderAssignView(true)
end

function Forge:ConfirmSellArtifacts()
	if self.Busy then return end
	local uuids = {}
	for uuid, sel in pairs(self.SelectedSellUUIDs) do
		if sel then table.insert(uuids, uuid) end
	end
	if #uuids == 0 then return end
	self.Busy = true
	task.spawn(function()
		local ok, success, _msg = pcall(function()
			return self.RequestSell:InvokeServer(uuids)
		end)
		self.Busy = false
		if ok and success then
			self.SelectedSellUUIDs = {}
			self.SellMode = false
			if self.SellControls then self.SellControls.Visible = false end
			if self.SellToggleBtn then self.SellToggleBtn.Visible = true end
		end
		self:Refresh()
	end)
end

local ARCHETYPE_FILTER_KEYS = {
	{ Key = "ALL", Title = "ALL (84)" },
	{ Key = "SWORD_SHIELD", Title = "VANGUARD (14)" },
	{ Key = "DAGGERS", Title = "STRIKER (14)" },
	{ Key = "BOW", Title = "MARKSMAN (14)" },
	{ Key = "AXE", Title = "MINER (14)" },
	{ Key = "STAFF", Title = "SCHOLAR (14)" },
	{ Key = "TOME", Title = "HEALER (14)" },
}

function Forge:BuildArtifactsModal(gui: ScreenGui)
	local scrim = new("TextButton", {
		Name = "ArtifactsCatalogScrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 65,
	}, gui)

	local win = new("Frame", {
		Name = "ArtifactsCatalogWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(840, 540),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		ZIndex = 66,
	}, scrim)
	GildedGrimoire.Frame(win, { Class = "Window", Tone = "Deep", ZIndex = 66 })

	-- Header
	local headerIcon = GrimoireIcons.Create("Forge", 36, win, 68)
	headerIcon.Position = UDim2.fromOffset(18, 12)

	local headerTitle = label(win, "ARTIFACT BANNER CATALOG & LIVE ODDS", 20, Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	headerTitle.Position = UDim2.fromOffset(62, 16)
	headerTitle.Size = UDim2.fromOffset(450, 26)
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.ZIndex = 68

	local closeBtn = new("TextButton", {
		Name = "CloseBtn",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(34, 34),
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = C.TextMuted,
		BackgroundColor3 = Color3.fromRGB(28, 20, 36),
		BorderSizePixel = 0,
		ZIndex = 68,
	}, win)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, closeBtn)
	closeBtn.Activated:Connect(function()
		self:CloseArtifactsModal()
	end)

	-- Rates Banner Box
	local ratesBox = new("Frame", {
		Name = "RatesBox",
		Position = UDim2.fromOffset(18, 56),
		Size = UDim2.new(1, -36, 0, 68),
		BackgroundColor3 = Color3.fromRGB(22, 16, 32),
		BorderSizePixel = 0,
		ZIndex = 67,
	}, win)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, ratesBox)
	new("UIStroke", { Color = Color3.fromRGB(80, 55, 110), Thickness = 1.2 }, ratesBox)

	local ratesRow = new("Frame", {
		Name = "RatesRow",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 24),
		BackgroundTransparency = 1,
		ZIndex = 68,
	}, ratesBox)
	local ratesLayout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
	}, ratesRow)
	self.ModalRatesRow = ratesRow

	local rulesLabel = label(ratesBox, "• 120-Pull Hard Pity: Guaranteed Exalted (Tier 5) or higher   • 60% Standard / 40% Enhanced (+20% Power, +Spd)   • All 1★ Baseline", 12, C.TextLavender, Enum.Font.GothamMedium)
	rulesLabel.Position = UDim2.fromOffset(12, 38)
	rulesLabel.Size = UDim2.new(1, -24, 0, 22)
	rulesLabel.TextXAlignment = Enum.TextXAlignment.Left
	rulesLabel.ZIndex = 68
	self.ModalRulesLabel = rulesLabel

	-- Filter Tabs Row
	local tabsRow = new("Frame", {
		Name = "TabsRow",
		Position = UDim2.fromOffset(18, 132),
		Size = UDim2.new(1, -36, 0, 32),
		BackgroundTransparency = 1,
		ZIndex = 67,
	}, win)
	local tabsLayout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 6),
	}, tabsRow)

	self.ModalTabBtns = {}
	for _, entry in ipairs(ARCHETYPE_FILTER_KEYS) do
		local tabBtn = new("TextButton", {
			Name = "Tab_" .. entry.Key,
			Size = UDim2.fromOffset(108, 30),
			Text = entry.Title,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = if entry.Key == "ALL" then C.GoldYellow else C.TextMuted,
			BackgroundColor3 = if entry.Key == "ALL" then Color3.fromRGB(45, 30, 65) else Color3.fromRGB(24, 18, 32),
			BorderSizePixel = 0,
			ZIndex = 68,
		}, tabsRow)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, tabBtn)
		local stroke = new("UIStroke", {
			Color = if entry.Key == "ALL" then C.GoldYellow else Color3.fromRGB(60, 45, 80),
			Thickness = 1,
		}, tabBtn)
		tabBtn.Activated:Connect(function()
			self.ArtifactsModalFilter = entry.Key
			for k, b in pairs(self.ModalTabBtns) do
				local active = (k == entry.Key)
				b.TextColor3 = if active then C.GoldYellow else C.TextMuted
				b.BackgroundColor3 = if active then Color3.fromRGB(45, 30, 65) else Color3.fromRGB(24, 18, 32)
				local str = b:FindFirstChildOfClass("UIStroke")
				if str then str.Color = if active then C.GoldYellow else Color3.fromRGB(60, 45, 80) end
			end
			self:RenderArtifactsCatalog(entry.Key)
		end)
		self.ModalTabBtns[entry.Key] = tabBtn
	end

	-- Catalog Scroll Grid
	local scroll = new("ScrollingFrame", {
		Name = "CatalogScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 172),
		Size = UDim2.new(1, -36, 1, -186),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 67,
	}, win)
	self.ModalCatalogScroll = scroll

	local grid = new("UIGridLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		CellSize = UDim2.new(0.5, -6, 0, 118),
		CellPadding = UDim2.fromOffset(12, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, scroll)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 6),
	}, scroll)

	scrim.Activated:Connect(function()
		self:CloseArtifactsModal()
	end)

	self.ArtifactsModal = scrim
end

function Forge:OpenArtifactsModal()
	if not self.ArtifactsModal then return end
	self.ArtifactsModal.Visible = true
	self:RenderArtifactsRates()
	self:RenderArtifactsCatalog(self.ArtifactsModalFilter or "ALL")
end

function Forge:CloseArtifactsModal()
	if self.ArtifactsModal then
		self.ArtifactsModal.Visible = false
	end
end

function Forge:RenderArtifactsRates()
	if not self.ModalRatesRow then return end
	for _, child in ipairs(self.ModalRatesRow:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local profile = self:ResolveProfile()
	local luck = SummonLuck.ForProfile(profile)
	local cfg = ArtifactCatalog.Banner
	local boosted = SummonLuck.ApplyLuck(cfg.BaseRarityRates, luck)

	for tier = 1, 7 do
		local rInfo = ArtifactCatalog.GetRarityInfo(tier)
		local pct = boosted[tier] * 100
		local pill = new("Frame", {
			Name = "RatePill_" .. tier,
			BackgroundColor3 = Color3.fromRGB(16, 12, 24),
			BorderSizePixel = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			ZIndex = 69,
		}, self.ModalRatesRow)
		new("UICorner", { CornerRadius = UDim.new(0, 5) }, pill)
		new("UIStroke", { Color = rInfo.Color, Thickness = 1.2 }, pill)
		new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, pill)

		local tLbl = label(pill, string.format("%s: %.1f%%", rInfo.Name, pct), 11, rInfo.Color, Enum.Font.GothamBold)
		tLbl.Size = UDim2.fromScale(1, 1)
		tLbl.ZIndex = 70
	end

	if luck > 0 and self.ModalRulesLabel then
		self.ModalRulesLabel.Text = string.format("• God's Blessing Luck Active: +%.1f%% upper tiers   • 120 Pity: Guaranteed Exalted+   • 60%% Standard / 40%% Enhanced", luck * 100)
	end
end

function Forge:RenderArtifactsCatalog(filter: string)
	local scroll = self.ModalCatalogScroll
	if not scroll then return end
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") and child.Name:sub(1, 8) == "CardMod_" then
			child:Destroy()
		end
	end

	local order = ArtifactCatalog.CatalogOrder or {}
	local count = 0

	for i, templateId in ipairs(order) do
		local seed = ArtifactCatalog.Seeds[templateId]
		if seed and (filter == "ALL" or seed.Type == filter) then
			count += 1
			local tier = seed.RarityTier or 1
			local rInfo = ArtifactCatalog.GetRarityInfo(tier)
			local rColor = rInfo.Color
			local stats = ArtifactCatalog.GetStatBreakdown(templateId, 1, tier)

			local card = new("Frame", {
				Name = "CardMod_" .. templateId,
				LayoutOrder = count,
				BackgroundColor3 = Color3.fromRGB(18, 14, 26),
				BorderSizePixel = 0,
				ZIndex = 68,
			}, scroll)
			new("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
			new("UIStroke", { Color = rColor, Thickness = 1.5 }, card)

			-- Left icon box
			local iconBox = new("Frame", {
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(48, 48),
				BackgroundColor3 = Color3.fromRGB(12, 8, 18),
				BorderSizePixel = 0,
				ZIndex = 69,
			}, card)
			new("UICorner", { CornerRadius = UDim.new(0, 6) }, iconBox)
			local iconLbl = label(iconBox, ICON_MAP[seed.Type] or "⚔️", 28, C.Text)
			iconLbl.Size = UDim2.fromScale(1, 1)
			iconLbl.ZIndex = 70
			showArtifact(iconLbl, templateId)

			-- Name & Variant
			local nameLbl = label(card, seed.DisplayName, 13, C.Text, Enum.Font.GothamBlack)
			nameLbl.Position = UDim2.fromOffset(64, 8)
			nameLbl.Size = UDim2.new(1, -72, 0, 18)
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.ZIndex = 69

			-- Rarity & Variant tag
			local variantTag = label(card, string.format("%s · %s", rInfo.Name, seed.Variant or "Standard"), 11, rColor, Enum.Font.GothamBold)
			variantTag.Position = UDim2.fromOffset(64, 26)
			variantTag.Size = UDim2.new(1, -72, 0, 16)
			variantTag.TextXAlignment = Enum.TextXAlignment.Left
			variantTag.ZIndex = 69

			-- Stats row
			local statsLbl = label(card, string.format("Power: <b>%.0f</b>  |  Dmg: <b>x%.2f</b>  |  Spd: <b>+%.1f%%</b>", stats.Power, stats.DamageMultiplier, stats["Attack Speed"]), 11, C.GoldYellow, Enum.Font.GothamMedium)
			statsLbl.Position = UDim2.fromOffset(64, 44)
			statsLbl.Size = UDim2.new(1, -72, 0, 16)
			statsLbl.TextXAlignment = Enum.TextXAlignment.Left
			statsLbl.ZIndex = 69

			-- Concept Lore
			local loreLbl = label(card, seed.Description or "A legendary weapon forged in the crucible.", 10, C.TextMuted, Enum.Font.Gotham)
			loreLbl.Position = UDim2.fromOffset(8, 64)
			loreLbl.Size = UDim2.new(1, -16, 0, 48)
			loreLbl.TextXAlignment = Enum.TextXAlignment.Left
			loreLbl.TextYAlignment = Enum.TextYAlignment.Top
			loreLbl.TextWrapped = true
			loreLbl.ZIndex = 69
		end
	end
end

return Forge
