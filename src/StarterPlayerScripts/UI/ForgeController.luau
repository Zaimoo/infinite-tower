--!strict
-- StarterPlayerScripts/UI/ForgeController.luau
-- Authoritative Blacksmith Forge HUD featuring 3 Sections:
--   1. ASSIGN (Inventory list of all owned artifacts with stats & 1-click hero assignment)
--   2. SUMMON (Dimensional banner gacha for artifacts: 1X & 10X pulls, 50-pull pity counter, rate-up featured items)
--   3. UPGRADE ARTIFACT (Enhance artifact levels using 5 fodder slots & stat comparisons)
-- Matches exact cosmic purple aesthetic with corner diamond accents, glowing borders, and responsive scaling.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))

local LocalPlayer = Players.LocalPlayer

local Forge = {}
Forge.__index = Forge

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

local function cornerDiamonds(parent: GuiObject, size: number, color: Color3?)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local d = new("Frame", {
			Name = "CornerDiamond",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			Position = UDim2.fromScale(corner.X, corner.Y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			ZIndex = parent.ZIndex + 2,
		}, parent)
		stroke(d, color or C.Border, 1)
	end
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

-- Formats artifact stat string e.g. "ATK +150 | Crit Rate +5%" matching mockup
local function formatStatSummary(art: any): string
	local stats = ArtifactCatalog.GetStatBreakdown(art.TemplateId, art.Star or 1, art.Rarity or 1, art.Level or 0)
	local parts = {}
	if stats["ATK"] and stats["ATK"] > 0 then
		table.insert(parts, string.format("ATK +%d", stats["ATK"]))
	end
	if stats["DEF"] and stats["DEF"] > 0 then
		table.insert(parts, string.format("DEF +%d", stats["DEF"]))
	end
	if stats["HP"] and stats["HP"] > 0 then
		table.insert(parts, string.format("HP +%d", stats["HP"]))
	end
	if stats["SPD"] and stats["SPD"] > 0 then
		table.insert(parts, string.format("SPD +%d", stats["SPD"]))
	end
	if stats["Crit Rate"] and stats["Crit Rate"] > 0 then
		table.insert(parts, string.format("Crit Rate +%d%%", stats["Crit Rate"]))
	end
	if stats["Evasion"] and stats["Evasion"] > 0 then
		table.insert(parts, string.format("Evasion +%d%%", stats["Evasion"]))
	end
	if #parts == 0 then
		local baseAtk = stats["ATK"] or 15
		table.insert(parts, string.format("ATK +%d | AtkSpd +5%%", baseAtk))
	end
	return table.concat(parts, " | ")
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
	self.FodderUUIDs = {} :: { string } -- Array of up to 5 artifact UUIDs
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

	-- 2. Modal Frame
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

	stroke(root, C.Border, 1.2, 0.05)
	glow(root, 10, C.BorderGlow, 0.8)
	cornerDiamonds(root, 8, C.Border)

	local inner = new("Frame", {
		Name = "InnerBorder",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		ZIndex = 51,
	}, root)
	stroke(inner, C.BorderDim, 1, 0.4)

	self.Scale = new("UIScale", {}, root)

	-- 3. Close Button
	local closeBtn = new("TextButton", {
		Name = "CloseButton",
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(1, -36, 0, 10),
		ZIndex = 60,
	}, root)
	closeBtn.Activated:Connect(function()
		if not self.Busy then
			self:Close()
		end
	end)

	-- 4. Top Header & 3 Tabs (ASSIGN | SUMMON | UPGRADE ARTIFACT)
	local tabContainer = new("Frame", {
		Name = "TabContainer",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -70, 0, 44),
		ZIndex = 52,
	}, root)

	local assignTabBtn = new("TextButton", {
		Name = "TabAssign",
		Text = "ASSIGN",
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.Text,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(100, 36),
		Position = UDim2.fromOffset(10, 0),
		ZIndex = 53,
	}, tabContainer)

	local summonTabBtn = new("TextButton", {
		Name = "TabSummon",
		Text = "SUMMON",
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(110, 36),
		Position = UDim2.fromOffset(130, 0),
		ZIndex = 53,
	}, tabContainer)

	local upgradeTabBtn = new("TextButton", {
		Name = "TabUpgrade",
		Text = "UPGRADE ARTIFACT",
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(180, 36),
		Position = UDim2.fromOffset(260, 0),
		ZIndex = 53,
	}, tabContainer)

	-- Active Underline indicator
	local activeIndicator = new("Frame", {
		Name = "ActiveTabIndicator",
		BackgroundColor3 = C.Underline,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 70, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(60, 36),
		ZIndex = 54,
	}, tabContainer)
	stroke(activeIndicator, C.BorderGlow, 1.5, 0.4)

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
		BackgroundColor3 = C.BorderDim,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 1),
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
			Position = UDim2.fromOffset(targetX, 36),
			Size = UDim2.fromOffset(70, 3),
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
			Position = UDim2.fromOffset(targetX, 36),
			Size = UDim2.fromOffset(78, 3),
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
			Position = UDim2.fromOffset(targetX, 36),
			Size = UDim2.fromOffset(130, 3),
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
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 1, -82),
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

		label(emptyCard, "📦 NO ARTIFACTS IN INVENTORY", 18, C.Text, Enum.Font.GothamBold).Position = UDim2.new(0, 0, 0.3, 0)
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
		local aLvl = a.Art.Level or 0
		local bLvl = b.Art.Level or 0
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
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, card)
		stroke(card, C.BorderCard, 1)

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
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, iconBox)
		stroke(iconBox, C.BorderCard, 1)

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
		if art.Level and art.Level > 0 then
			displayName = string.format("%s +%d", displayName, art.Level)
		end

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
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, assignBtn)
		stroke(assignBtn, C.Border, 1)
		cornerDiamonds(assignBtn, 4, C.Border)

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
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 1, -82),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.SummonView = summonView

	-- 1. Main Featured Banner Card (Image 1)
	local bannerCard = new("Frame", {
		Name = "BannerCard",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 246),
		BackgroundColor3 = Color3.fromRGB(19, 14, 34),
		BorderSizePixel = 0,
		ZIndex = 53,
	}, summonView)
	self.BannerCard = bannerCard

	new("UICorner", { CornerRadius = UDim.new(0, 8) }, bannerCard)
	stroke(bannerCard, C.Border, 1.2, 0.05)
	glow(bannerCard, 8, C.BorderGlow, 0.85)
	cornerDiamonds(bannerCard, 6, C.Border)

	-- Cosmic Gradient
	local grad = new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(28, 19, 50)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 14, 36)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(12, 9, 22)),
		}),
		Rotation = 35,
	}, bannerCard)

	-- Top Watermark
	local watermark = label(bannerCard, "★ 5-STAR FEATURED HERO & ARTIFACTS", 15, Color3.fromRGB(230, 220, 255), Enum.Font.GothamBold)
	watermark.TextTransparency = 0.55
	watermark.Position = UDim2.fromOffset(24, 18)
	watermark.Size = UDim2.new(1, -48, 0, 20)
	watermark.TextXAlignment = Enum.TextXAlignment.Left

	-- Big Glowing Banner Title
	local bannerTitle = label(bannerCard, "ECHOES OF THE RIFT", 34, C.GoldYellow, Enum.Font.GothamBlack)
	bannerTitle.AnchorPoint = Vector2.new(0, 1)
	bannerTitle.Position = UDim2.new(0, 24, 1, -26)
	bannerTitle.Size = UDim2.new(0, 420, 0, 44)
	bannerTitle.TextXAlignment = Enum.TextXAlignment.Left
	bannerTitle.TextStrokeTransparency = 0.35
	bannerTitle.TextStrokeColor3 = Color3.fromRGB(120, 80, 0)

	-- Featured Rate-Up Pill Label
	local rateUpLabel = label(bannerCard, "✦ Rate Up: Blade of the Rift (5★)  |  Aegis Core (5★)", 12, Color3.fromRGB(205, 175, 245), Enum.Font.GothamBold)
	rateUpLabel.AnchorPoint = Vector2.new(1, 1)
	rateUpLabel.Position = UDim2.new(1, -24, 1, -26)
	rateUpLabel.Size = UDim2.new(0, 320, 0, 22)
	rateUpLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- 2. Info Row (Guaranteed Pity & Timer)
	local infoRow = new("Frame", {
		Name = "InfoRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 258),
		Size = UDim2.new(1, 0, 0, 28),
		ZIndex = 53,
	}, summonView)

	local pityLabel = label(infoRow, "Guaranteed 5-Star in: <b>42</b> summons", 14, C.TextLavender, Enum.Font.GothamMedium)
	pityLabel.Position = UDim2.fromOffset(6, 4)
	pityLabel.Size = UDim2.new(0.5, 0, 0, 20)
	pityLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.PityLabel = pityLabel

	local timerLabel = label(infoRow, "Event Ends: 2d 14h", 14, C.TextLavender, Enum.Font.GothamMedium)
	timerLabel.AnchorPoint = Vector2.new(1, 0)
	timerLabel.Position = UDim2.new(1, -6, 0, 4)
	timerLabel.Size = UDim2.new(0.5, 0, 0, 20)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right

	-- 3. Summon Buttons Container (Image 1)
	local btnRow = new("Frame", {
		Name = "ButtonRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 296),
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
		AutoButtonColor = true,
		ZIndex = 54,
	}, btnRow)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, btn1X)
	stroke(btn1X, C.Border, 1.2)
	cornerDiamonds(btn1X, 4, C.Border)

	local t1X = label(btn1X, "SUMMON 1X", 15, C.Text, Enum.Font.GothamBold)
	t1X.AnchorPoint = Vector2.new(0.5, 0.5)
	t1X.Position = UDim2.new(0.5, 0, 0.34, 0)
	t1X.Size = UDim2.new(1, 0, 0, 20)

	local c1X = label(btn1X, "💎 160", 15, C.GoldYellow, Enum.Font.GothamBold)
	c1X.AnchorPoint = Vector2.new(0.5, 0.5)
	c1X.Position = UDim2.new(0.5, 0, 0.72, 0)
	c1X.Size = UDim2.new(1, 0, 0, 20)

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
		AutoButtonColor = true,
		ZIndex = 54,
	}, btnRow)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, btn10X)
	stroke(btn10X, C.Border, 1.2)
	cornerDiamonds(btn10X, 4, C.Border)

	local t10X = label(btn10X, "SUMMON 10X", 15, C.Text, Enum.Font.GothamBold)
	t10X.AnchorPoint = Vector2.new(0.5, 0.5)
	t10X.Position = UDim2.new(0.5, 0, 0.34, 0)
	t10X.Size = UDim2.new(1, 0, 0, 20)

	local c10X = label(btn10X, "💎 1600", 15, C.GoldYellow, Enum.Font.GothamBold)
	c10X.AnchorPoint = Vector2.new(0.5, 0.5)
	c10X.Position = UDim2.new(0.5, 0, 0.72, 0)
	c10X.Size = UDim2.new(1, 0, 0, 20)

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

	stroke(modal, C.Border, 1.5)
	glow(modal, 12, C.BorderGlow, 0.8)
	cornerDiamonds(modal, 8, C.Border)

	label(modal, "✨ DIMENSIONAL ARTIFACTS SUMMONED", 20, C.GoldYellow, Enum.Font.GothamBlack).Position = UDim2.new(0, 0, 0, 20)

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
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, collectBtn)
	stroke(collectBtn, C.Border, 1.2)
	cornerDiamonds(collectBtn, 4, C.Border)

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
-- SECTION 3: UPGRADE ARTIFACT VIEW (Level Enhancement & 5 Fodder Slots)
--============================================================================

function Forge:BuildUpgradeView(root: Frame)
	local upgradeView = new("Frame", {
		Name = "UpgradeView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 1, -82),
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
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, targetSlot)
	stroke(targetSlot, C.Border, 1.2)
	cornerDiamonds(targetSlot, 5, C.Border)

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
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, statBox)
	stroke(statBox, C.BorderCard, 1)

	label(statBox, "ENHANCEMENT PREVIEW", 15, C.Text, Enum.Font.GothamBold).Position = UDim2.new(0, 18, 0, 14)

	local currentStatsLabel = label(statBox, "Current Stats: Select an artifact", 13, C.TextLavender, Enum.Font.GothamMedium)
	currentStatsLabel.Position = UDim2.new(0, 18, 0, 48)
	currentStatsLabel.Size = UDim2.new(1, -36, 0, 24)
	currentStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.CurrentStatsLabel = currentStatsLabel

	local arrowLabel = label(statBox, "▼  UPGRADE BOOST  ▼", 12, C.Arrow, Enum.Font.GothamBold)
	arrowLabel.Position = UDim2.new(0, 18, 0, 84)
	arrowLabel.Size = UDim2.new(1, -36, 0, 20)
	arrowLabel.TextXAlignment = Enum.TextXAlignment.Left

	local nextStatsLabel = label(statBox, "Next Level: —", 14, C.Green, Enum.Font.GothamBold)
	nextStatsLabel.Position = UDim2.new(0, 18, 0, 114)
	nextStatsLabel.Size = UDim2.new(1, -36, 0, 24)
	nextStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.NextStatsLabel = nextStatsLabel

	local fodderReqLabel = label(statBox, "Fodder Required: 0 / 0", 12, C.TextMuted, Enum.Font.Gotham)
	fodderReqLabel.Position = UDim2.new(0, 18, 0, 146)
	fodderReqLabel.Size = UDim2.new(1, -36, 0, 20)
	fodderReqLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.FodderReqLabel = fodderReqLabel

	-- 5 Fodder Slots (Image 2)
	local fodderContainer = new("Frame", {
		Name = "FodderSlotsContainer",
		Position = UDim2.fromOffset(24, 214),
		Size = UDim2.new(1, -48, 0, 100),
		BackgroundTransparency = 1,
		ZIndex = 53,
	}, upgradeView)

	self.FodderSlotFrames = {}
	local slotW = 110
	local spacing = 16

	for i = 1, 5 do
		local slot = new("Frame", {
			Name = "FodderSlot_" .. i,
			Position = UDim2.fromOffset((i - 1) * (slotW + spacing), 0),
			Size = UDim2.fromOffset(slotW, 90),
			BackgroundColor3 = C.SlotBg,
			BorderSizePixel = 0,
			ZIndex = 53,
		}, fodderContainer)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, slot)
		stroke(slot, C.BorderDim, 1)

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
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, autoFillBtn)
	stroke(autoFillBtn, C.BorderCard, 1)
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
		Text = "⚒️ ENHANCE ARTIFACT",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C.Text,
		ZIndex = 54,
	}, bottomRow)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, enhanceBtn)
	stroke(enhanceBtn, C.Border, 1.2)
	glow(enhanceBtn, 6, C.BorderGlow, 0.85)
	cornerDiamonds(enhanceBtn, 4, C.Border)
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
		self.NextStatsLabel.Text = "Next Level: —"
		self.FodderReqLabel.Text = "Fodder Required: 0 / 0"
		return
	end

	-- Update Target Slot
	local iconChar = ICON_MAP[target.Type] or "⚔️"
	self.TargetIcon.Text = iconChar
	self.TargetName.Text = target.DisplayName or "Artifact"
	self.TargetLevel.Text = string.format("Level +%d", target.Level or 0)

	local currentLevel = target.Level or 0
	local maxLevel = ArtifactCatalog.MaxEnhancementLevel or 10
	local reqFodder = ArtifactCatalog.GetFodderRequirement(currentLevel)

	-- Update Stats
	local currentStats = formatStatSummary(target)
	self.CurrentStatsLabel.Text = string.format("Current Stats: %s", currentStats)

	if currentLevel >= maxLevel then
		self.NextStatsLabel.Text = "★ MAXIMUM ENHANCEMENT LEVEL REACHED"
		self.FodderReqLabel.Text = "Max Level (+10)"
		self.EnhanceBtn.Text = "MAX LEVEL REACHED"
	else
		-- Simulate next level
		local simNext = {
			TemplateId = target.TemplateId,
			Star = target.Star,
			Rarity = target.Rarity,
			Level = currentLevel + 1,
			Type = target.Type,
		}
		local nextStats = formatStatSummary(simNext)
		self.NextStatsLabel.Text = string.format("Next Level (+%d): %s", currentLevel + 1, nextStats)
		self.FodderReqLabel.Text = string.format("Fodder Required: %d / %d items slotted", #self.FodderUUIDs, reqFodder)
		self.EnhanceBtn.Text = string.format("⚒️ ENHANCE TO +%d (%d/%d)", currentLevel + 1, #self.FodderUUIDs, reqFodder)
	end

	-- Update Fodder Slots
	for i = 1, 5 do
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

	local currentLevel = target.Level or 0
	local reqFodder = ArtifactCatalog.GetFodderRequirement(currentLevel)

	table.clear(self.FodderUUIDs)

	-- Fill with unequipped, unlocked, non-target artifacts (lower star/level preferred)
	local candidates = {}
	for uuid, art in pairs(artifacts) do
		if uuid ~= self.SelectedTargetUUID and not art.EquippedHeroUUID and not art.Locked then
			table.insert(candidates, { UUID = uuid, Art = art })
		end
	end

	table.sort(candidates, function(a, b)
		local aLvl = a.Art.Level or 0
		local bLvl = b.Art.Level or 0
		if aLvl ~= bLvl then return aLvl < bLvl end
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

	local currentLevel = target.Level or 0
	local reqFodder = ArtifactCatalog.GetFodderRequirement(currentLevel)

	if #self.FodderUUIDs < reqFodder then
		return
	end

	self.Busy = true
	task.spawn(function()
		local success, msg, newLevel = self.RequestUpgrade:InvokeServer(self.SelectedTargetUUID, self.FodderUUIDs)
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

	new("UICorner", { CornerRadius = UDim.new(0, 8) }, drawer)
	stroke(drawer, C.Border, 1.2)
	cornerDiamonds(drawer, 6, C.Border)

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
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, -30, 0, 0),
		ZIndex = 72,
	}, header)
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
			local card = new("Frame", {
				Name = "TargetCard_" .. uuid,
				Size = UDim2.fromOffset(110, 170),
				BackgroundColor3 = C.CardBg,
				BorderSizePixel = 0,
				ZIndex = 72,
			}, scroll)
			new("UICorner", { CornerRadius = UDim.new(0, 6) }, card)
			stroke(card, (uuid == self.SelectedTargetUUID) and C.Border or C.BorderDim, 1)

			local iconChar = ICON_MAP[art.Type] or "⚔️"
			label(card, iconChar, 34, C.Text).Position = UDim2.fromScale(0, 0.1)
			label(card, art.DisplayName or "Artifact", 12, C.Text, Enum.Font.GothamBold).Position = UDim2.fromScale(0, 0.5)
			label(card, string.format("+%d", art.Level or 0), 12, C.GoldYellow).Position = UDim2.fromScale(0, 0.72)

			local btn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 73 }, card)
			btn.Activated:Connect(function()
				self.SelectedTargetUUID = uuid
				table.clear(self.FodderUUIDs)
				self:ClosePicker()
				self:RenderUpgradeView()
			end)
		end
	elseif mode == "FODDER" then
		self.DrawerTitle.Text = "SELECT ENHANCEMENT FODDER (UNEQUIPPED ARTIFACTS)"
		local target = self.SelectedTargetUUID and artifacts[self.SelectedTargetUUID]
		local req = target and ArtifactCatalog.GetFodderRequirement(target.Level or 0) or 5

		for uuid, art in pairs(artifacts) do
			if uuid ~= self.SelectedTargetUUID and not art.EquippedHeroUUID and not art.Locked then
				local isSlotted = table.find(self.FodderUUIDs, uuid) ~= nil
				local card = new("Frame", {
					Name = "FodderCard_" .. uuid,
					Size = UDim2.fromOffset(110, 170),
					BackgroundColor3 = isSlotted and Color3.fromRGB(34, 25, 48) or C.CardBg,
					BorderSizePixel = 0,
					ZIndex = 72,
				}, scroll)
				new("UICorner", { CornerRadius = UDim.new(0, 6) }, card)
				stroke(card, isSlotted and C.Border or C.BorderDim, 1)

				local iconChar = ICON_MAP[art.Type] or "⚔️"
				label(card, iconChar, 34, C.Text).Position = UDim2.fromScale(0, 0.1)
				label(card, art.DisplayName or "Artifact", 12, C.Text, Enum.Font.GothamBold).Position = UDim2.fromScale(0, 0.5)
				label(card, isSlotted and "✓ SLOTTED" or string.format("+%d", art.Level or 0), 12, isSlotted and C.Green or C.TextMuted).Position = UDim2.fromScale(0, 0.72)

				local btn = new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 73 }, card)
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
				Size = UDim2.fromOffset(150, 170),
				BackgroundColor3 = isCurrentEquipped and Color3.fromRGB(30, 24, 46) or C.CardBg,
				BorderSizePixel = 0,
				ZIndex = 72,
			}, scroll)
			new("UICorner", { CornerRadius = UDim.new(0, 6) }, card)
			stroke(card, isCurrentEquipped and C.Border or (canEquip and C.BorderDim or Color3.fromRGB(45, 35, 55)), 1)

			label(card, string.rep("★", hero.Stars or 1), 12, C.GoldYellow).Position = UDim2.fromScale(0, 0.08)
			label(card, hero.DisplayName or "Hero", 15, C.Text, Enum.Font.GothamBold).Position = UDim2.fromScale(0, 0.26)
			label(card, hero.Archetype or "Class", 12, C.TextLavender).Position = UDim2.fromScale(0, 0.46)

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
				AutoButtonColor = canEquip,
				ZIndex = 73,
			}, card)
			new("UICorner", { CornerRadius = UDim.new(0, 4) }, actionBtn)
			stroke(actionBtn, isCurrentEquipped and C.Red or (canEquip and C.Border or Color3.fromRGB(45, 35, 55)), 1)

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
