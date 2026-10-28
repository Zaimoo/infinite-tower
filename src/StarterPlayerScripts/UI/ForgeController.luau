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
local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(Shared.Util.GrimoireIcons)
local GrimoireSummonButton = require(Shared.Util.GrimoireSummonButton)

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
	return lbl
end

-- Formats artifact stat string e.g. "ATK +150 | Crit Rate +5%" matching mockup
local function formatStatSummary(art: any): string
	local stats = ArtifactCatalog.GetStatBreakdown(art.TemplateId, art.Star or 1, art.Rarity or 1)
	return string.format("Power <b>%.0f</b>  ·  Damage <b>x%.2f</b>  ·  AtkSpd <b>+%.1f%%</b>", stats.Power, stats.DamageMultiplier, stats["Attack Speed"])
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
		Position = UDim2.fromOffset(24, 58),
		Size = UDim2.new(0, 560, 0, 36),
		ZIndex = 52,
	}, root)

	local assignTabBtn = new("TextButton", {
		Name = "TabAssign",
		Text = "ASSIGN",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.Text,
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
		TextColor3 = C.TextMuted,
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
		Visible = true,
		ZIndex = 52,
	}, root)
	self.AssignView = assignView

	local scroll = new("ScrollingFrame", {
		Name = "AssignScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
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

-- One stat column on an artifact card: small caption over an inked number.
local function statCell(parent: Instance, x: number, caption: string, value: string)
	local cap = label(parent, caption, 11, C.TextLavender, Enum.Font.GothamMedium)
	cap.Position = UDim2.new(x, 4, 0, 0)
	cap.Size = UDim2.new(1 / 3, -8, 0, 15)
	cap.TextXAlignment = Enum.TextXAlignment.Center
	cap.ZIndex = 56
	local val = label(parent, value, 16, C.Text, Enum.Font.GothamBlack)
	val.Position = UDim2.new(x, 4, 0, 16)
	val.Size = UDim2.new(1 / 3, -8, 0, 20)
	val.TextXAlignment = Enum.TextXAlignment.Center
	val.ZIndex = 56
	val:SetAttribute("Grimoire", true)
	GildedGrimoire.StyleText(val, "Number")
end

function Forge:RenderAssignView()
	local scroll = self.AssignScroll
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local profile = self:ResolveProfile()
	local artifacts = profile and profile.Artifacts or {}
	local heroMap = profile and profile.Heroes or {}

	local artList = {}
	for uuid, art in pairs(artifacts) do
		table.insert(artList, { UUID = uuid, Art = art })
	end

	if #artList == 0 then
		self.AssignGrid.CellSize = UDim2.new(1, -8, 0, 220)
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
		goBtn.Activated:Connect(function()
			self:SetTab("SUMMON")
		end)
		return
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

	for order, item in ipairs(artList) do
		local uuid = item.UUID
		local art = item.Art
		local rarityInfo = ArtifactCatalog.GetRarityInfo(art.Rarity or 1)
		local rarityColor = rarityInfo.Color
		local equippedHero = art.EquippedHeroUUID and heroMap[art.EquippedHeroUUID]
		local starCount = art.Star or 1

		local card = new("Frame", {
			Name = "ArtCard_" .. uuid,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 53,
		}, scroll)
		-- Rarity reads at a glance: the card is tinted toward the rarity colour and its rail is drawn
		-- solid in that colour; the badge below names the exact tier.
		GildedGrimoire.Frame(card, { Class = "Card", Tone = "Deep", Rail = rarityColor, ZIndex = 53 })
		local fill = card:FindFirstChild("GrimoireFill") :: UIGradient?
		if fill then
			local deep = GildedGrimoire.Tones.Deep
			fill.Color = ColorSequence.new(deep.Top:Lerp(rarityColor, 0.28), deep.Bottom:Lerp(rarityColor, 0.08))
		end
		local cardRail = GildedGrimoire.StateStroke(card)
		if cardRail then
			cardRail.Thickness = 2.4
			cardRail.Transparency = 0
		end

		-- Weapon preview (weapon art comes later from the models; the glyph is a stand-in).
		local iconBox = new("Frame", {
			Name = "IconBox",
			Position = UDim2.fromOffset(14, 14),
			Size = UDim2.fromOffset(PREVIEW_W, PREVIEW_H),
			BorderSizePixel = 0,
			ZIndex = 54,
		}, card)
		applyGothicStyle(iconBox, "Slot", { State = "Filled", AccentColor = rarityColor })
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(12, 8, 18), Color3.fromRGB(12, 8, 18):Lerp(rarityColor, 0.35)),
		}, iconBox)
		local iconLabel = label(iconBox, ICON_MAP[art.Type] or "⚔️", 72, C.Text)
		iconLabel.Position = UDim2.fromScale(0, 0)
		iconLabel.Size = UDim2.fromScale(1, 1)
		iconLabel.TextXAlignment = Enum.TextXAlignment.Center
		iconLabel.ZIndex = 56

		local infoX = 14 + PREVIEW_W + 16
		local function infoLine(text: string, size: number, color: Color3, font: Enum.Font, y: number, h: number): TextLabel
			local l = label(card, text, size, color, font)
			l.Position = UDim2.fromOffset(infoX, y)
			l.Size = UDim2.new(1, -infoX - 14, 0, h)
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.ZIndex = 56
			return l
		end

		-- Name and stars
		infoLine(art.DisplayName or "Artifact", 21, C.Text, Enum.Font.GothamBlack, 14, 28)
		infoLine(string.rep("★", starCount), 22, C.GoldYellow, Enum.Font.GothamBold, 44, 24)

		-- Rarity badge: solid rarity colour with a dark, inked label.
		local badge = new("Frame", {
			Name = "RarityBadge",
			Position = UDim2.fromOffset(infoX, 72),
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = rarityColor,
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
			Text = string.upper(rarityInfo.Name or "Common"),
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 56,
		}, badge)
		badgeText:SetAttribute("Grimoire", true)
		GildedGrimoire.StyleText(badgeText, "Title")

		-- Who carries it
		infoLine(if equippedHero then "Equipped by <b>" .. equippedHero.DisplayName .. "</b>" else "Not equipped", 14,
			if equippedHero then C.CyanEquipped else C.TextMuted, Enum.Font.GothamMedium, 102, 20)

		-- Stats strip
		local stats = ArtifactCatalog.GetStatBreakdown(art.TemplateId, starCount, art.Rarity or 1)
		local strip = new("Frame", {
			Name = "Stats",
			Position = UDim2.fromOffset(infoX, 128),
			Size = UDim2.new(1, -infoX - 14, 0, 44),
			BorderSizePixel = 0,
			ZIndex = 54,
		}, card)
		GildedGrimoire.Frame(strip, { Class = "Row", Tone = "Violet", ZIndex = 54 })
		statCell(strip, 0, "POWER", string.format("%.0f", stats.Power))
		statCell(strip, 1 / 3, "DAMAGE", string.format("x%.2f", stats.DamageMultiplier))
		statCell(strip, 2 / 3, "ATK SPD", string.format("+%.1f%%", stats["Attack Speed"]))

		-- Assign / change hero
		local assignBtn = new("TextButton", {
			Name = "AssignBtn",
			Position = UDim2.fromOffset(infoX, 176),
			Size = UDim2.new(1, -infoX - 14, 0, 38),
			BorderSizePixel = 0,
			Text = if equippedHero then "CHANGE HERO" else "ASSIGN TO HERO",
			Font = Enum.Font.GothamBlack,
			TextSize = 16,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = 55,
		}, card)
		applyGothicStyle(assignBtn, if equippedHero then "ButtonSecondary" else "Button")
		assignBtn.TextStrokeColor3 = GildedGrimoire.Ink
		assignBtn.TextStrokeTransparency = 0.15
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
		Position = UDim2.fromOffset(LEGACY_X, VIEW_Y),
		Size = UDim2.new(0, LEGACY_W, 0, LEGACY_H),
		ClipsDescendants = false,
		Visible = false,
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
	local chip1Lbl = label(chip1, "Blade of the Rift (5★)", 11, Color3.fromHex("#FDE047"), Enum.Font.GothamBold)
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
	local chip2Lbl = label(chip2, "Aegis Core (5★)", 11, Color3.fromHex("#E9D5FF"), Enum.Font.GothamBold)
	chip2Lbl.Size = UDim2.fromScale(1, 1)

	-- 2. Info Row (Guaranteed Pity & Timer)
	local infoRow = new("Frame", {
		Name = "InfoRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 252),
		Size = UDim2.new(1, 0, 0, 18),
		ZIndex = 53,
	}, summonView)

	local pityLabel = label(infoRow, "Guaranteed 5-Star in: <b>42</b> summons", 13, Color3.fromHex("#A396BA"), Enum.Font.GothamMedium)
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
		Size = UDim2.new(0.66, 0, 1, 0),
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

	-- SUMMON 1X / 10X: the shared Gilded Grimoire summon button (same as the hero banners).
	local btn1X = GrimoireSummonButton.new(btnRow, {
		Name = "Summon1XBtn",
		Title = "SUMMON 1X",
		Cost = 160,
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
		Cost = 1600,
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
	local pity = profile and profile.ArtifactBannerPity or 8
	local remaining = math.max(1, 50 - (pity % 50))
	local progress = math.clamp((50 - remaining) / 50, 0.05, 1)

	if self.PityLabel then
		self.PityLabel.Text = string.format("Guaranteed 5-Star in: <b>%d</b> summons", remaining)
	end
	if self.PityFill then
		self.PityFill.Size = UDim2.new(progress, 0, 1, 0)
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
	-- Gilded Grimoire theme: convert this screen's legacy Gotham text (now and as it is rebuilt).
	GildedGrimoire.Watch(revealScrim)

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

	local revealTitle = label(modal, "DIMENSIONAL ARTIFACTS SUMMONED", 20, C.GoldYellow, Enum.Font.GothamBlack)
	revealTitle.Position = UDim2.new(0, 0, 0, 20)
	revealTitle.Size = UDim2.new(1, 0, 0, 28)
	for side = -1, 1, 2 do
		local spark = GrimoireIcons.Create("Spark", 26, modal, revealTitle.ZIndex)
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position = UDim2.new(0.5, side * 250, 0, 34)
	end

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
		BorderSizePixel = 0,
		Text = "COLLECT ARTIFACTS",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		ZIndex = 82,
	}, modal)
	applyGothicStyle(collectBtn, "ButtonPrimary", { Variant = "Gold" })

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
		-- Star Rating string
		local starCount = art.Star or 1
		local starStr = string.rep("★", starCount)
		local starColor = (starCount >= 5) and C.GoldYellow or ((starCount >= 4) and Color3.fromRGB(192, 132, 252) or C.TextLavender)

		local row = new("Frame", {
			Name = "ResultRow_" .. order,
			Size = UDim2.new(1, -4, 0, 64),
			BackgroundColor3 = C.CardBg,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 83,
		}, scroll)
		applyGothicStyle(row, "Row", { AccentColor = starColor })

		-- Left Icon Box (Slot)
		local iconBox = new("Frame", {
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(48, 48),
			BorderSizePixel = 0,
			ZIndex = 84,
		}, row)
		applyGothicStyle(iconBox, "Slot", { State = "Filled", AccentColor = starColor })

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
				Size = UDim2.fromOffset(150, 164),
				BorderSizePixel = 0,
				ZIndex = 72,
			}, scroll)
			applyGothicStyle(card, "Row")

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
				BorderSizePixel = 0,
				Text = isCurrentEquipped and "UNEQUIP" or (canEquip and (hero.EquippedArtifactUUID and "SWAP" or "EQUIP") or "INCOMPATIBLE"),
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				ZIndex = 73,
			}, card)

			if isCurrentEquipped then
				applyGothicStyle(actionBtn, "ButtonSecondary")
			elseif canEquip then
				applyGothicStyle(actionBtn, "ButtonPrimary", { Variant = "Gold" })
			else
				applyGothicStyle(actionBtn, "ButtonSecondary", { Disabled = true })
			end

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
