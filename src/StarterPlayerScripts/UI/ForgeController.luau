--!strict
-- StarterPlayerScripts/UI/ForgeController.luau
-- Authoritative Blacksmith Forge HUD featuring 2 Sections:
--   1. CRAFT ARTIFACT (Refine & forge artifacts with gathered materials)
--   2. UPGRADE ARTIFACT (Enhance artifact levels using 5 fodder slots & stat comparisons)
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

local WIDTH, HEIGHT = 720, 560

local C = {
	Scrim = Color3.fromRGB(6, 5, 10),
	Panel = Color3.fromRGB(15, 13, 22),
	PanelInner = Color3.fromRGB(20, 17, 30),
	CardBg = Color3.fromRGB(22, 19, 32),
	SlotBg = Color3.fromRGB(18, 15, 26),
	StatBoxBg = Color3.fromRGB(12, 10, 18),
	Border = Color3.fromRGB(195, 145, 230),
	BorderGlow = Color3.fromRGB(175, 115, 215),
	BorderDim = Color3.fromRGB(58, 48, 75),
	BorderCard = Color3.fromRGB(65, 52, 85),
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(155, 145, 175),
	TextLavender = Color3.fromRGB(195, 185, 220),
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

--============================================================================
-- CONSTRUCTOR
--============================================================================

function Forge.new(gui: ScreenGui, artifactRemotes: Folder, getProfile: (() -> any)?, onClose: (() -> ())?)
	local self: any = setmetatable({}, Forge)
	self.Remotes = artifactRemotes
	self.GetProfile = getProfile
	self.OnClose = onClose
	self.RequestCraft = artifactRemotes:WaitForChild("RequestCraftArtifact") :: RemoteFunction
	self.RequestUpgrade = artifactRemotes:WaitForChild("RequestUpgradeArtifact") :: RemoteFunction
	self.RequestEquip = artifactRemotes:WaitForChild("RequestEquipArtifact") :: RemoteFunction
	self.RequestUnequip = artifactRemotes:WaitForChild("RequestUnequipArtifact") :: RemoteFunction

	self.ActiveTab = "CRAFT" -- "CRAFT" | "UPGRADE"
	self.SelectedTargetUUID = nil :: string?
	self.FodderUUIDs = {} :: { string } -- Array of up to 5 artifact UUIDs
	self.PickerMode = "NONE" :: "NONE" | "TARGET" | "FODDER" | "EQUIP"
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
		ZIndex = 48,
	}, gui)
	self.Scrim.Activated:Connect(function()
		if not self.Busy then
			self:Close()
		end
	end)

	-- 2. Modal Window Container
	local root = new("Frame", {
		Name = "BlacksmithForgeModal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = C.Panel,
		BorderSizePixel = 0,
		Visible = false,
		Active = true,
		ZIndex = 50,
	}, gui)
	self.Root = root

	stroke(root, C.Border, 1.2, 0.05)
	glow(root, 10, C.BorderGlow, 0.8)
	cornerDiamonds(root, 8, C.Border)

	local inner = new("Frame", {
		Name = "InnerBorder",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10),
		ZIndex = 51,
	}, root)
	stroke(inner, C.BorderDim, 1, 0.4)

	self.Scale = new("UIScale", {}, root)

	-- 3. Close Button
	local closeBtn = new("TextButton", {
		Name = "CloseBtn",
		Text = "×",
		TextSize = 26,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -44, 0, 10),
		Size = UDim2.fromOffset(34, 34),
		ZIndex = 55,
	}, root)
	closeBtn.Activated:Connect(function()
		if not self.Busy then
			self:Close()
		end
	end)

	-- 4. Top Header & Tabs (Image 1 & 2)
	local tabContainer = new("Frame", {
		Name = "TabContainer",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(40, 14),
		Size = UDim2.new(1, -80, 0, 48),
		ZIndex = 52,
	}, root)

	local craftTabBtn = new("TextButton", {
		Name = "TabCraft",
		Text = "CRAFT ARTIFACT",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.Text,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.25, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(180, 40),
		ZIndex = 53,
	}, tabContainer)

	local upgradeTabBtn = new("TextButton", {
		Name = "TabUpgrade",
		Text = "UPGRADE ARTIFACT",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.75, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(180, 40),
		ZIndex = 53,
	}, tabContainer)

	-- Active Indicator Underline bar
	local activeIndicator = new("Frame", {
		Name = "ActiveIndicator",
		BackgroundColor3 = C.Underline,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(140, 3),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.25, 0, 1, 0),
		ZIndex = 54,
	}, tabContainer)
	stroke(activeIndicator, C.BorderGlow, 1.5, 0.4)

	self.CraftTabBtn = craftTabBtn
	self.UpgradeTabBtn = upgradeTabBtn
	self.ActiveIndicator = activeIndicator

	craftTabBtn.Activated:Connect(function()
		self:SetTab("CRAFT")
	end)
	upgradeTabBtn.Activated:Connect(function()
		self:SetTab("UPGRADE")
	end)

	-- Divider Line beneath tabs
	local tabDivider = new("Frame", {
		Name = "TabDivider",
		BackgroundColor3 = C.BorderDim,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 0, 1),
		ZIndex = 52,
	}, root)

	-- 5. SECTION 1: CRAFT ARTIFACT VIEW
	self:BuildCraftView(root)

	-- 6. SECTION 2: UPGRADE ARTIFACT VIEW
	self:BuildUpgradeView(root)

	-- 7. SELECTION DRAWER (Bottom overlay for picking target / fodder / equip)
	self:BuildPickerDrawer(root)

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

function Forge:SetTab(tab: "CRAFT" | "UPGRADE")
	self.ActiveTab = tab
	self:ClosePicker()

	if tab == "CRAFT" then
		self.CraftTabBtn.TextColor3 = C.Text
		self.UpgradeTabBtn.TextColor3 = C.TextMuted
		self.CraftView.Visible = true
		self.UpgradeView.Visible = false
		TweenService:Create(self.ActiveIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.25, 0, 1, 0),
		}):Play()
		self:RenderCraftRecipes()
	else
		self.CraftTabBtn.TextColor3 = C.TextMuted
		self.UpgradeTabBtn.TextColor3 = C.Text
		self.CraftView.Visible = false
		self.UpgradeView.Visible = true
		TweenService:Create(self.ActiveIndicator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.75, 0, 1, 0),
		}):Play()
		self:RenderUpgradeView()
	end
end

--============================================================================
-- BUILD CRAFT VIEW (SECTION 1 — IMAGE 1)
--============================================================================

function Forge:BuildCraftView(root: Frame)
	local craftView = new("Frame", {
		Name = "CraftView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 1, -84),
		Visible = true,
		ZIndex = 52,
	}, root)
	self.CraftView = craftView

	local scroll = new("ScrollingFrame", {
		Name = "RecipeScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Border,
		BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
		ZIndex = 53,
	}, craftView)
	self.RecipeScroll = scroll

	local layout = new("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroll)
	local pad = new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 10),
	}, scroll)
end

function Forge:RenderCraftRecipes()
	local scroll = self.RecipeScroll
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local profile = self:ResolveProfile()
	local pitMaterials = (profile and profile.PitMaterials) or {}

	local recipeOrder = ArtifactCatalog.CraftingRecipeOrder or {}
	local totalCount = 0

	for orderIdx, templateId in ipairs(recipeOrder) do
		local seed = ArtifactCatalog.Seeds[templateId]
		if seed and seed.CraftCost then
			totalCount += 1
			local card = new("Frame", {
				Name = "RecipeCard_" .. templateId,
				BackgroundColor3 = C.CardBg,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 92),
				LayoutOrder = orderIdx,
				ZIndex = 54,
			}, scroll)

			stroke(card, C.BorderCard, 1, 0.2)
			cornerDiamonds(card, 6, C.Border)

			-- Left: Icon Box
			local iconBox = new("Frame", {
				Name = "IconBox",
				BackgroundColor3 = C.Panel,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(68, 68),
				ZIndex = 55,
			}, card)
			stroke(iconBox, C.BorderDim, 1)
			cornerDiamonds(iconBox, 5, C.BorderDim)

			local iconText = ICON_MAP[seed.Type] or "⚔️"
			local iconLbl = label(iconBox, iconText, 32, C.Text)
			iconLbl.Size = UDim2.fromScale(1, 1)
			iconLbl.ZIndex = 56

			-- Middle-Left: Name & Stats
			local nameLbl = label(card, seed.DisplayName, 17, C.Text)
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.Position = UDim2.fromOffset(92, 18)
			nameLbl.Size = UDim2.new(0.38, 0, 0, 22)
			nameLbl.ZIndex = 55

			-- Formatted stats string matching mockup
			local statsStr = ""
			if seed.BaseATK and seed.BaseCritRate then
				statsStr = string.format("ATK +%d | Crit Rate +%d%%", seed.BaseATK, math.round(seed.BaseCritRate * 100))
			elseif seed.BaseDEF and seed.BaseHP then
				statsStr = string.format("DEF +%d | HP +%d", seed.BaseDEF, seed.BaseHP)
			elseif seed.BaseSPD and seed.BaseEvasion then
				statsStr = string.format("SPD +%d | Evasion +%d%%", seed.BaseSPD, math.round(seed.BaseEvasion * 100))
			else
				local baseATK, baseSpeed = ArtifactCatalog.GetStarBaseStats(seed.DefaultStar)
				statsStr = string.format("ATK +%d | AtkSpd +%d%%", baseATK, math.round(baseSpeed * 100))
			end

			local statsLbl = label(card, statsStr, 13, C.TextLavender, Enum.Font.GothamMedium)
			statsLbl.TextXAlignment = Enum.TextXAlignment.Left
			statsLbl.Position = UDim2.fromOffset(92, 46)
			statsLbl.Size = UDim2.new(0.38, 0, 0, 18)
			statsLbl.ZIndex = 55

			-- Middle-Right: Materials Requirements Container
			local matContainer = new("Frame", {
				Name = "MatContainer",
				BackgroundTransparency = 1,
				Position = UDim2.new(0.55, 0, 0, 12),
				Size = UDim2.new(0.24, 0, 0, 68),
				ZIndex = 55,
			}, card)

			local matLayout = new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 16),
			}, matContainer)

			local canCraftAll = true

			for matId, reqQty in pairs(seed.CraftCost) do
				local matInfo = ArtifactCatalog.CraftingMaterials[matId]
				local playerHave = pitMaterials[matId] or 0
				local hasEnough = playerHave >= reqQty
				if not hasEnough then
					canCraftAll = false
				end

				local matSlot = new("Frame", {
					Name = "MatSlot_" .. matId,
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(48, 64),
					ZIndex = 56,
				}, matContainer)

				local matIconBox = new("Frame", {
					BackgroundColor3 = C.SlotBg,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(6, 4),
					Size = UDim2.fromOffset(36, 36),
					ZIndex = 57,
				}, matSlot)
				stroke(matIconBox, C.BorderDim, 1)

				local matIconLbl = label(matIconBox, matInfo and matInfo.Icon or "⚙️", 18, C.Text)
				matIconLbl.Size = UDim2.fromScale(1, 1)
				matIconLbl.ZIndex = 58

				local countColor = hasEnough and C.Green or C.Red
				local countLbl = label(matSlot, string.format("%d/%d", playerHave, reqQty), 12, countColor, Enum.Font.GothamBold)
				countLbl.Position = UDim2.fromOffset(0, 44)
				countLbl.Size = UDim2.new(1, 0, 0, 16)
				countLbl.ZIndex = 58
			end

			-- Far-Right: CRAFT Button (matching mockup)
			local craftBtn = new("TextButton", {
				Name = "CraftButton",
				Text = "CRAFT",
				TextSize = 14,
				Font = Enum.Font.GothamBlack,
				TextColor3 = canCraftAll and C.Text or C.TextMuted,
				BackgroundColor3 = canCraftAll and Color3.fromRGB(26, 21, 38) or Color3.fromRGB(16, 14, 22),
				BorderSizePixel = 0,
				AutoButtonColor = canCraftAll,
				Position = UDim2.new(1, -132, 0.5, -22),
				Size = UDim2.fromOffset(118, 44),
				ZIndex = 56,
			}, card)

			local btnBorderColor = canCraftAll and C.Border or C.BorderDim
			stroke(craftBtn, btnBorderColor, 1.2)
			cornerDiamonds(craftBtn, 6, btnBorderColor)
			if canCraftAll then
				glow(craftBtn, 4, C.BorderGlow, 0.85)
			end

			craftBtn.Activated:Connect(function()
				if self.Busy then return end
				local curProfile = self:ResolveProfile()
				local curMats = (curProfile and curProfile.PitMaterials) or {}
				local canCraftNow = true
				for matId, reqQty in pairs(seed.CraftCost) do
					if (curMats[matId] or 0) < reqQty then
						canCraftNow = false
						break
					end
				end
				if not canCraftNow then return end

				self.Busy = true
				task.spawn(function()
					local success, msg = self.RequestCraft:InvokeServer(templateId)
					self.Busy = false
					self:RenderCraftRecipes()
				end)
			end)
		end
	end

	scroll.CanvasSize = UDim2.new(0, 0, 0, totalCount * 102 + 10)
end

--============================================================================
-- BUILD UPGRADE VIEW (SECTION 2 — IMAGE 2)
--============================================================================

function Forge:BuildUpgradeView(root: Frame)
	local upView = new("Frame", {
		Name = "UpgradeView",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 74),
		Size = UDim2.new(1, -32, 1, -84),
		Visible = false,
		ZIndex = 52,
	}, root)
	self.UpgradeView = upView

	-- 1. Large Target Artifact Slot in upper center (100x100)
	local targetSlot = new("TextButton", {
		Name = "TargetSlot",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = C.SlotBg,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(108, 108),
		ZIndex = 54,
	}, upView)
	stroke(targetSlot, C.Border, 1.5)
	glow(targetSlot, 8, C.BorderGlow, 0.78)
	cornerDiamonds(targetSlot, 7, C.Border)
	self.TargetSlot = targetSlot

	self.TargetIcon = label(targetSlot, "A", 40, C.TextLavender, Enum.Font.GothamBlack)
	self.TargetIcon.Size = UDim2.fromScale(1, 0.7)
	self.TargetIcon.Position = UDim2.fromScale(0, 0.08)
	self.TargetIcon.ZIndex = 55

	self.TargetLevelPill = label(targetSlot, "", 12, C.Green, Enum.Font.GothamBold)
	self.TargetLevelPill.Size = UDim2.fromScale(1, 0.24)
	self.TargetLevelPill.Position = UDim2.fromScale(0, 0.72)
	self.TargetLevelPill.ZIndex = 55

	targetSlot.Activated:Connect(function()
		if not self.Busy then
			self:OpenPicker("TARGET")
		end
	end)

	-- Target Artifact Subtitle (Name & Equip Status)
	self.TargetNameLabel = label(upView, "Click to Select Target Artifact", 13, C.TextMuted, Enum.Font.GothamMedium)
	self.TargetNameLabel.Position = UDim2.new(0.5, -200, 0, 130)
	self.TargetNameLabel.Size = UDim2.fromOffset(400, 20)
	self.TargetNameLabel.ZIndex = 54

	-- 2. Stat Comparison Box (Dark rounded box in middle)
	local statBox = new("Frame", {
		Name = "StatComparisonBox",
		BackgroundColor3 = C.StatBoxBg,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 156),
		Size = UDim2.fromOffset(360, 78),
		ZIndex = 54,
	}, upView)
	stroke(statBox, C.BorderDim, 1, 0.2)
	cornerDiamonds(statBox, 5, C.BorderDim)

	-- Line 1: Level  +4 -> +5
	local lvlRow = new("Frame", {
		Name = "LevelRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 12),
		Size = UDim2.new(1, -48, 0, 24),
		ZIndex = 55,
	}, statBox)

	local lvlTitle = label(lvlRow, "Level", 15, C.Text, Enum.Font.GothamBold)
	lvlTitle.TextXAlignment = Enum.TextXAlignment.Left
	lvlTitle.Size = UDim2.fromScale(0.4, 1)
	lvlTitle.ZIndex = 56

	self.LvlCurrentLbl = label(lvlRow, "+4", 15, C.Text, Enum.Font.GothamBold)
	self.LvlCurrentLbl.TextXAlignment = Enum.TextXAlignment.Right
	self.LvlCurrentLbl.Position = UDim2.fromScale(0.4, 0)
	self.LvlCurrentLbl.Size = UDim2.fromScale(0.2, 1)
	self.LvlCurrentLbl.ZIndex = 56

	self.LvlArrowLbl = label(lvlRow, "➔", 15, C.Arrow, Enum.Font.GothamBold)
	self.LvlArrowLbl.Position = UDim2.fromScale(0.62, 0)
	self.LvlArrowLbl.Size = UDim2.fromScale(0.12, 1)
	self.LvlArrowLbl.ZIndex = 56

	self.LvlNextLbl = label(lvlRow, "+5", 15, C.Green, Enum.Font.GothamBold)
	self.LvlNextLbl.TextXAlignment = Enum.TextXAlignment.Left
	self.LvlNextLbl.Position = UDim2.fromScale(0.76, 0)
	self.LvlNextLbl.Size = UDim2.fromScale(0.24, 1)
	self.LvlNextLbl.ZIndex = 56

	-- Line 2: ATK  120 -> 155
	local statRow = new("Frame", {
		Name = "StatRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 40),
		Size = UDim2.new(1, -48, 0, 24),
		ZIndex = 55,
	}, statBox)

	self.StatNameLbl = label(statRow, "ATK", 15, C.Text, Enum.Font.GothamBold)
	self.StatNameLbl.TextXAlignment = Enum.TextXAlignment.Left
	self.StatNameLbl.Size = UDim2.fromScale(0.4, 1)
	self.StatNameLbl.ZIndex = 56

	self.StatCurrentLbl = label(statRow, "120", 15, C.Text, Enum.Font.GothamBold)
	self.StatCurrentLbl.TextXAlignment = Enum.TextXAlignment.Right
	self.StatCurrentLbl.Position = UDim2.fromScale(0.4, 0)
	self.StatCurrentLbl.Size = UDim2.fromScale(0.2, 1)
	self.StatCurrentLbl.ZIndex = 56

	self.StatArrowLbl = label(statRow, "➔", 15, C.Arrow, Enum.Font.GothamBold)
	self.StatArrowLbl.Position = UDim2.fromScale(0.62, 0)
	self.StatArrowLbl.Size = UDim2.fromScale(0.12, 1)
	self.StatArrowLbl.ZIndex = 56

	self.StatNextLbl = label(statRow, "155", 15, C.Green, Enum.Font.GothamBold)
	self.StatNextLbl.TextXAlignment = Enum.TextXAlignment.Left
	self.StatNextLbl.Position = UDim2.fromScale(0.76, 0)
	self.StatNextLbl.Size = UDim2.fromScale(0.24, 1)
	self.StatNextLbl.ZIndex = 56

	-- 3. Enhancement Fodder Section
	local fodderHeader = label(upView, "- ENHANCEMENT FODDER -", 12, C.TextMuted, Enum.Font.GothamBold)
	fodderHeader.Position = UDim2.new(0.5, -160, 0, 248)
	fodderHeader.Size = UDim2.fromOffset(320, 18)
	fodderHeader.ZIndex = 54

	-- 5 Fodder Slots Row
	self.FodderSlotButtons = {}
	self.FodderSlotLabels = {}
	local slotW, gap = 56, 14
	local totalW = 5 * slotW + 4 * gap
	local startX = -totalW / 2

	for i = 1, 5 do
		local btn = new("TextButton", {
			Name = "FodderSlot_" .. i,
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = C.SlotBg,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, startX + (i - 1) * (slotW + gap), 0, 274),
			Size = UDim2.fromOffset(slotW, slotW),
			ZIndex = 55,
		}, upView)
		stroke(btn, C.BorderDim, 1)
		cornerDiamonds(btn, 5, C.BorderDim)

		local plusLbl = label(btn, "+", 22, C.TextMuted, Enum.Font.GothamMedium)
		plusLbl.Size = UDim2.fromScale(1, 1)
		plusLbl.ZIndex = 56

		btn.Activated:Connect(function()
			if self.Busy then return end
			if self.FodderUUIDs[i] then
				-- Remove this fodder item
				table.remove(self.FodderUUIDs, i)
				self:RenderUpgradeView()
			else
				-- Open picker to add fodder
				self:OpenPicker("FODDER")
			end
		end)

		self.FodderSlotButtons[i] = btn
		self.FodderSlotLabels[i] = plusLbl
	end

	-- Auto-Fill & Clear Buttons Row
	local helperRow = new("Frame", {
		Name = "HelperRow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 338),
		Size = UDim2.fromOffset(360, 24),
		ZIndex = 54,
	}, upView)

	local autoFillBtn = new("TextButton", {
		Name = "AutoFillBtn",
		Text = "⚡ AUTO-FILL FODDER",
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextLavender,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.2, 0),
		Size = UDim2.fromScale(0.4, 1),
		ZIndex = 55,
	}, helperRow)
	autoFillBtn.Activated:Connect(function()
		self:AutoFillFodder()
	end)

	local clearBtn = new("TextButton", {
		Name = "ClearBtn",
		Text = "✕ CLEAR FODDER",
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.7, 0),
		Size = UDim2.fromScale(0.3, 1),
		ZIndex = 55,
	}, helperRow)
	clearBtn.Activated:Connect(function()
		self.FodderUUIDs = {}
		self:RenderUpgradeView()
	end)

	-- 4. Large Upgrade Button at bottom
	local upgradeBtn = new("TextButton", {
		Name = "UpgradeButton",
		Text = "UPGRADE",
		TextSize = 16,
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Text,
		BackgroundColor3 = Color3.fromRGB(24, 19, 36),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 374),
		Size = UDim2.fromOffset(360, 48),
		ZIndex = 55,
	}, upView)
	self.UpgradeButton = upgradeBtn
	self.UpgradeStroke = stroke(upgradeBtn, C.Border, 1.2)
	cornerDiamonds(upgradeBtn, 7, C.Border)
	glow(upgradeBtn, 6, C.BorderGlow, 0.82)

	upgradeBtn.Activated:Connect(function()
		self:PerformUpgrade()
	end)

	-- Equip to Hero helper link below upgrade button
	local equipHeroBtn = new("TextButton", {
		Name = "EquipHeroBtn",
		Text = "⚔️ EQUIP / MANAGE HERO LOADOUT",
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextLavender,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 432),
		Size = UDim2.fromOffset(360, 24),
		ZIndex = 55,
	}, upView)
	equipHeroBtn.Activated:Connect(function()
		if not self.Busy and self.SelectedTargetUUID then
			self:OpenPicker("EQUIP")
		end
	end)
	self.EquipHeroBtn = equipHeroBtn
end

function Forge:RenderUpgradeView()
	local profile = self:ResolveProfile()
	local artifacts = (profile and profile.Artifacts) or {}

	-- If no target selected, try to pick one
	if not self.SelectedTargetUUID or not artifacts[self.SelectedTargetUUID] then
		for uuid, _ in pairs(artifacts) do
			self.SelectedTargetUUID = uuid
			break
		end
	end

	local target = self.SelectedTargetUUID and artifacts[self.SelectedTargetUUID]

	if target then
		local seed = ArtifactCatalog.Seeds[target.TemplateId]
		local iconStr = ICON_MAP[target.Type] or "⚔️"
		local curLvl = target.Level or 0
		local maxLvl = ArtifactCatalog.MaxEnhancementLevel
		local isMax = curLvl >= maxLvl

		self.TargetIcon.Text = iconStr
		self.TargetLevelPill.Text = string.format("+%d", curLvl)
		self.TargetLevelPill.TextColor3 = C.Green

		local equipStr = "[Available in Inventory]"
		if target.EquippedHeroUUID and profile.Heroes and profile.Heroes[target.EquippedHeroUUID] then
			local h = profile.Heroes[target.EquippedHeroUUID]
			equipStr = string.format("[Equipped to %s]", h.DisplayName)
		end
		self.TargetNameLabel.Text = string.format("%s (+%d) • %s", target.DisplayName, curLvl, equipStr)
		self.TargetNameLabel.TextColor3 = C.Text

		-- Stat Comparison
		local nextLvl = math.min(maxLvl, curLvl + 1)
		self.LvlCurrentLbl.Text = string.format("+%d", curLvl)

		if isMax then
			self.LvlNextLbl.Text = "MAX"
			self.LvlNextLbl.TextColor3 = Color3.fromRGB(255, 205, 100)
		else
			self.LvlNextLbl.Text = string.format("+%d", nextLvl)
			self.LvlNextLbl.TextColor3 = C.Green
		end

		-- Primary Stat Line
		local curBreakdown = ArtifactCatalog.GetStatBreakdown(target.TemplateId, target.Star, target.Rarity, curLvl)
		local nextBreakdown = ArtifactCatalog.GetStatBreakdown(target.TemplateId, target.Star, target.Rarity, nextLvl)

		local primaryStatName = "ATK"
		if curBreakdown["DEF"] then
			primaryStatName = "DEF"
		elseif curBreakdown["SPD"] then
			primaryStatName = "SPD"
		end

		local curVal = curBreakdown[primaryStatName] or 0
		local nextVal = isMax and curVal or (nextBreakdown[primaryStatName] or curVal)

		self.StatNameLbl.Text = primaryStatName
		self.StatCurrentLbl.Text = tostring(curVal)
		self.StatNextLbl.Text = tostring(nextVal)
		self.StatNextLbl.TextColor3 = isMax and C.TextMuted or C.Green

		-- Update Fodder Slots
		local reqFodder = ArtifactCatalog.GetFodderRequirement(curLvl)
		for i = 1, 5 do
			local btn = self.FodderSlotButtons[i]
			local lbl = self.FodderSlotLabels[i]
			local fUUID = self.FodderUUIDs[i]

			if fUUID and artifacts[fUUID] then
				local fArt = artifacts[fUUID]
				lbl.Text = string.format("%s\n+%d", ICON_MAP[fArt.Type] or "⚔️", fArt.Level or 0)
				lbl.TextSize = 13
				lbl.TextColor3 = C.Text
				btn.BackgroundColor3 = Color3.fromRGB(35, 25, 48)
				stroke(btn, C.Border, 1)
			else
				lbl.Text = "+"
				lbl.TextSize = 22
				lbl.TextColor3 = (i <= reqFodder) and C.TextLavender or C.BorderDim
				btn.BackgroundColor3 = C.SlotBg
				stroke(btn, (i <= reqFodder) and C.BorderCard or C.BorderDim, 1)
			end
		end

		-- Upgrade Button state
		local hasRequiredFodder = #self.FodderUUIDs >= reqFodder
		local canUpgrade = not isMax and hasRequiredFodder

		if isMax then
			self.UpgradeButton.Text = "MAX LEVEL REACHED"
			self.UpgradeButton.TextColor3 = C.TextMuted
			self.UpgradeButton.BackgroundColor3 = Color3.fromRGB(18, 16, 24)
			self.UpgradeStroke.Color = C.BorderDim
		elseif canUpgrade then
			self.UpgradeButton.Text = string.format("UPGRADE TO +%d", nextLvl)
			self.UpgradeButton.TextColor3 = C.Text
			self.UpgradeButton.BackgroundColor3 = Color3.fromRGB(38, 26, 56)
			self.UpgradeStroke.Color = C.Border
		else
			self.UpgradeButton.Text = string.format("UPGRADE (%d/%d FODDER)", #self.FodderUUIDs, reqFodder)
			self.UpgradeButton.TextColor3 = C.TextMuted
			self.UpgradeButton.BackgroundColor3 = Color3.fromRGB(20, 17, 28)
			self.UpgradeStroke.Color = C.BorderDim
		end
	else
		self.TargetIcon.Text = "A"
		self.TargetLevelPill.Text = ""
		self.TargetNameLabel.Text = "No artifacts available. Craft one first!"
		self.LvlCurrentLbl.Text = "--"
		self.LvlNextLbl.Text = "--"
		self.StatCurrentLbl.Text = "--"
		self.StatNextLbl.Text = "--"
		self.UpgradeButton.Text = "NO ARTIFACT SELECTED"
		self.UpgradeButton.TextColor3 = C.TextMuted
		self.UpgradeStroke.Color = C.BorderDim
	end
end

-- Auto-fill up to 5 unequipped, non-target, non-locked fodder artifacts
function Forge:AutoFillFodder()
	local profile = self:ResolveProfile()
	if not profile or not self.SelectedTargetUUID then return end
	local artifacts = profile.Artifacts or {}
	local target = artifacts[self.SelectedTargetUUID]
	if not target then return end

	local req = ArtifactCatalog.GetFodderRequirement(target.Level or 0)
	self.FodderUUIDs = {}

	for uuid, art in pairs(artifacts) do
		if uuid ~= self.SelectedTargetUUID and not art.EquippedHeroUUID and not art.Locked then
			table.insert(self.FodderUUIDs, uuid)
			if #self.FodderUUIDs >= req then
				break
			end
		end
	end

	self:RenderUpgradeView()
end

function Forge:PerformUpgrade()
	if self.Busy or not self.SelectedTargetUUID then return end
	local profile = self:ResolveProfile()
	if not profile then return end
	local target = profile.Artifacts and profile.Artifacts[self.SelectedTargetUUID]
	if not target then return end

	local reqFodder = ArtifactCatalog.GetFodderRequirement(target.Level or 0)
	if #self.FodderUUIDs < reqFodder then
		if _G.DataManager and _G.DataManager.SendToast then
			_G.DataManager.SendToast(LocalPlayer, string.format("Need %d fodder artifacts to upgrade!", reqFodder), "WARN")
		end
		return
	end

	self.Busy = true
	task.spawn(function()
		local success, msg, newLvl = self.RequestUpgrade:InvokeServer(self.SelectedTargetUUID, self.FodderUUIDs)
		self.Busy = false
		if success then
			self.FodderUUIDs = {}
			-- Celebratory flash animation
			TweenService:Create(self.TargetSlot, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {
				BackgroundColor3 = Color3.fromRGB(75, 45, 110),
			}):Play()
		end
		self:RenderUpgradeView()
	end)
end

--============================================================================
-- SELECTION DRAWER (TARGET / FODDER / EQUIP PICKER)
--============================================================================

function Forge:BuildPickerDrawer(root: Frame)
	local drawer = new("Frame", {
		Name = "PickerDrawer",
		BackgroundColor3 = Color3.fromRGB(14, 12, 20),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 1), -- Hidden below initially
		Size = UDim2.new(1, 0, 0, 240),
		Visible = false,
		ZIndex = 60,
	}, root)
	self.Drawer = drawer

	stroke(drawer, C.Border, 1.2)
	cornerDiamonds(drawer, 6, C.Border)

	self.DrawerTitle = label(drawer, "Select Artifact", 14, C.Text, Enum.Font.GothamBold)
	self.DrawerTitle.Position = UDim2.fromOffset(20, 10)
	self.DrawerTitle.Size = UDim2.new(1, -80, 0, 22)
	self.DrawerTitle.TextXAlignment = Enum.TextXAlignment.Left
	self.DrawerTitle.ZIndex = 61

	local drawerClose = new("TextButton", {
		Name = "DrawerClose",
		Text = "✕",
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.TextMuted,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -36, 0, 10),
		Size = UDim2.fromOffset(26, 26),
		ZIndex = 61,
	}, drawer)
	drawerClose.Activated:Connect(function()
		self:ClosePicker()
	end)

	local drawerScroll = new("ScrollingFrame", {
		Name = "DrawerScroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(16, 40),
		Size = UDim2.new(1, -32, 1, -48),
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Border,
		ZIndex = 61,
	}, drawer)
	self.DrawerScroll = drawerScroll

	local dLayout = new("UIListLayout", {
		Padding = UDim.new(0, 6),
	}, drawerScroll)
end

function Forge:OpenPicker(mode: "TARGET" | "FODDER" | "EQUIP")
	self.PickerMode = mode
	self.Drawer.Visible = true
	self.Drawer.Position = UDim2.fromScale(0, 1)

	TweenService:Create(self.Drawer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(0, HEIGHT - 240),
	}):Play()

	local scroll = self.DrawerScroll
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	local profile = self:ResolveProfile()
	local artifacts = (profile and profile.Artifacts) or {}

	if mode == "TARGET" then
		self.DrawerTitle.Text = "SELECT TARGET ARTIFACT TO ENHANCE"
		local count = 0
		for uuid, art in pairs(artifacts) do
			count += 1
			local isSelected = (uuid == self.SelectedTargetUUID)
			local row = new("Frame", {
				BackgroundColor3 = isSelected and Color3.fromRGB(42, 32, 60) or C.CardBg,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 42),
				ZIndex = 62,
			}, scroll)
			stroke(row, isSelected and C.Border or C.BorderDim, 1)

			local icon = label(row, ICON_MAP[art.Type] or "⚔️", 20, C.Text)
			icon.Position = UDim2.fromOffset(8, 0)
			icon.Size = UDim2.fromOffset(36, 42)
			icon.ZIndex = 63

			local info = label(row, string.format("%s (+%d) • %s", art.DisplayName, art.Level or 0, art.Type), 13, C.Text)
			info.TextXAlignment = Enum.TextXAlignment.Left
			info.Position = UDim2.fromOffset(48, 0)
			info.Size = UDim2.new(0.65, 0, 1, 0)
			info.ZIndex = 63

			local selBtn = new("TextButton", {
				Text = isSelected and "SELECTED" or "SELECT",
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextColor3 = isSelected and C.Green or C.Text,
				BackgroundColor3 = isSelected and Color3.fromRGB(30, 45, 35) or Color3.fromRGB(35, 28, 50),
				BorderSizePixel = 0,
				Position = UDim2.new(1, -90, 0.5, -14),
				Size = UDim2.fromOffset(82, 28),
				ZIndex = 63,
			}, row)
			stroke(selBtn, isSelected and C.Green or C.Border, 1)

			selBtn.Activated:Connect(function()
				self.SelectedTargetUUID = uuid
				self.FodderUUIDs = {}
				self:ClosePicker()
				self:RenderUpgradeView()
			end)
		end
		scroll.CanvasSize = UDim2.new(0, 0, 0, count * 48)

	elseif mode == "FODDER" then
		self.DrawerTitle.Text = "SELECT ENHANCEMENT FODDER (UNEQUIPPED ARTIFACTS)"
		local count = 0
		local target = self.SelectedTargetUUID and artifacts[self.SelectedTargetUUID]
		local req = target and ArtifactCatalog.GetFodderRequirement(target.Level or 0) or 5

		for uuid, art in pairs(artifacts) do
			if uuid ~= self.SelectedTargetUUID then
				count += 1
				local isSlotted = table.find(self.FodderUUIDs, uuid) ~= nil
				local isEquipped = art.EquippedHeroUUID ~= nil

				local row = new("Frame", {
					BackgroundColor3 = isSlotted and Color3.fromRGB(42, 32, 60) or C.CardBg,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 42),
					ZIndex = 62,
				}, scroll)
				stroke(row, isSlotted and C.Border or C.BorderDim, 1)

				local icon = label(row, ICON_MAP[art.Type] or "⚔️", 20, C.Text)
				icon.Position = UDim2.fromOffset(8, 0)
				icon.Size = UDim2.fromOffset(36, 42)
				icon.ZIndex = 63

				local desc = string.format("%s (+%d)", art.DisplayName, art.Level or 0)
				if isEquipped then
					desc ..= " [Equipped: Protected]"
				end
				local info = label(row, desc, 13, isEquipped and C.TextMuted or C.Text)
				info.TextXAlignment = Enum.TextXAlignment.Left
				info.Position = UDim2.fromOffset(48, 0)
				info.Size = UDim2.new(0.65, 0, 1, 0)
				info.ZIndex = 63

				local selBtn = new("TextButton", {
					Text = isSlotted and "REMOVE" or (isEquipped and "EQUIPPED" or "SLOT"),
					TextSize = 12,
					Font = Enum.Font.GothamBold,
					TextColor3 = isSlotted and C.Red or (isEquipped and C.TextMuted or C.Text),
					BackgroundColor3 = isSlotted and Color3.fromRGB(45, 25, 30) or Color3.fromRGB(35, 28, 50),
					BorderSizePixel = 0,
					Position = UDim2.new(1, -90, 0.5, -14),
					Size = UDim2.fromOffset(82, 28),
					AutoButtonColor = not isEquipped,
					ZIndex = 63,
				}, row)
				stroke(selBtn, isSlotted and C.Red or C.BorderDim, 1)

				selBtn.Activated:Connect(function()
					if isEquipped then return end
					if isSlotted then
						local idx = table.find(self.FodderUUIDs, uuid)
						if idx then table.remove(self.FodderUUIDs, idx) end
					else
						if #self.FodderUUIDs < req then
							table.insert(self.FodderUUIDs, uuid)
						end
					end
					self:OpenPicker("FODDER")
					self:RenderUpgradeView()
				end)
			end
		end
		scroll.CanvasSize = UDim2.new(0, 0, 0, count * 48)

	elseif mode == "EQUIP" then
		self.DrawerTitle.Text = "MANAGE HERO LOADOUT (EQUIP WEAPON)"
		local target = self.SelectedTargetUUID and artifacts[self.SelectedTargetUUID]
		if not target then return end

		local count = 0
		local heroes = (profile and profile.Heroes) or {}

		for hUUID, hero in pairs(heroes) do
			local canEquip = ArtifactCatalog.CanHeroEquip(hero.Archetype, target.Type)
			if canEquip then
				count += 1
				local isCurrentlyHolding = (target.EquippedHeroUUID == hUUID)

				local row = new("Frame", {
					BackgroundColor3 = isCurrentlyHolding and Color3.fromRGB(30, 48, 38) or C.CardBg,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 42),
					ZIndex = 62,
				}, scroll)
				stroke(row, isCurrentlyHolding and C.Green or C.BorderDim, 1)

				local hInfo = label(row, string.format("%s (%s Lv.%d)", hero.DisplayName, hero.Archetype, hero.Level), 13, C.Text)
				hInfo.TextXAlignment = Enum.TextXAlignment.Left
				hInfo.Position = UDim2.fromOffset(16, 0)
				hInfo.Size = UDim2.new(0.65, 0, 1, 0)
				hInfo.ZIndex = 63

				local eqBtn = new("TextButton", {
					Text = isCurrentlyHolding and "UNEQUIP" or "EQUIP",
					TextSize = 12,
					Font = Enum.Font.GothamBold,
					TextColor3 = isCurrentlyHolding and C.Red or C.Text,
					BackgroundColor3 = isCurrentlyHolding and Color3.fromRGB(50, 25, 30) or Color3.fromRGB(28, 48, 80),
					BorderSizePixel = 0,
					Position = UDim2.new(1, -94, 0.5, -14),
					Size = UDim2.fromOffset(84, 28),
					ZIndex = 63,
				}, row)
				stroke(eqBtn, isCurrentlyHolding and C.Red or C.Border, 1)

				eqBtn.Activated:Connect(function()
					task.spawn(function()
						if isCurrentlyHolding then
							self.RequestUnequip:InvokeServer(hUUID)
						else
							self.RequestEquip:InvokeServer(hUUID, target.UUID)
						end
						self:OpenPicker("EQUIP")
						self:RenderUpgradeView()
					end)
				end)
			end
		end
		scroll.CanvasSize = UDim2.new(0, 0, 0, count * 48)
	end
end

function Forge:ClosePicker()
	self.PickerMode = "NONE"
	TweenService:Create(self.Drawer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0, 1),
	}):Play()
	task.delay(0.22, function()
		if self.PickerMode == "NONE" then
			self.Drawer.Visible = false
		end
	end)
end

--============================================================================
-- PUBLIC OPEN / CLOSE / REFRESH API
--============================================================================

function Forge:Open(initialTab: ("CRAFT" | "UPGRADE")?)
	self.Scrim.Visible = true
	self.Root.Visible = true
	self:SetTab(initialTab or self.ActiveTab or "CRAFT")
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
	if self.ActiveTab == "CRAFT" then
		self:RenderCraftRecipes()
	else
		self:RenderUpgradeView()
	end
	if self.PickerMode ~= "NONE" then
		self:OpenPicker(self.PickerMode)
	end
end

return Forge
