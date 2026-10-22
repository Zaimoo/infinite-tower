--!strict
-- StarterPlayerScripts/UI/HUDController.client.luau
-- Complete Implementation of Document 4 UI/UX Wireframes:
-- 1. MasterHUDScreenGui (Main Tactical HUD + Clean Bottom Toolbar)
-- 2. SquadDeployScreenGui (Active 5-Hero Squad & Roster Management via War Banner)
-- 3. ThePitScreenGui (Synthesis XP Fodder & 1->5 Star Promotion)
-- 4. MercenaryScreenGui (Noticeboard, Secret Directives & 50G Audit Soul Reveal)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatRemotes = Remotes:WaitForChild("CombatRemotes")
local RelicPactRemotes = Remotes:WaitForChild("RelicPactRemotes")
local TycoonRemotes = Remotes:WaitForChild("TycoonGachaRemotes")
local SyndicateRemotes = Remotes:WaitForChild("SyndicateRemotes")

local WhistleCommandRemote = CombatRemotes:WaitForChild("WhistleCommand") :: RemoteEvent
local WorldBossTriggerRemote = CombatRemotes:WaitForChild("WorldBossTrigger") :: RemoteEvent
local FocusTargetRemote = CombatRemotes:WaitForChild("FocusTarget") :: RemoteEvent
local LootStolenAlertRemote = CombatRemotes:WaitForChild("LootStolenAlert") :: RemoteEvent
local SquadWipeStateRemote = CombatRemotes:WaitForChild("SquadWipeState") :: RemoteEvent
local DropCarriedItemRemote = CombatRemotes:WaitForChild("DropCarriedItem") :: RemoteEvent
local CarriedLootSyncRemote = CombatRemotes:WaitForChild("CarriedLootSync") :: RemoteEvent

local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local ArtifactRemotes = Remotes:WaitForChild("ArtifactRemotes")
local RequestEquipArtifactFunc = ArtifactRemotes:WaitForChild("RequestEquipArtifact") :: RemoteFunction
local RequestUnequipArtifactFunc = ArtifactRemotes:WaitForChild("RequestUnequipArtifact") :: RemoteFunction
local RequestUpgradeRarityFunc = ArtifactRemotes:WaitForChild("RequestUpgradeRarity") :: RemoteFunction

local RequestSummonFunc = TycoonRemotes:WaitForChild("RequestSummon") :: RemoteFunction
local AssignHeroRoleFunc = TycoonRemotes:WaitForChild("AssignHeroRole") :: RemoteFunction
local FacilityInteractEvent = TycoonRemotes:WaitForChild("FacilityInteract") :: RemoteEvent

local PlotEspionageEvent = SyndicateRemotes:WaitForChild("PlotEspionage") :: RemoteEvent
local ProfileDeltaSyncEvent = SyndicateRemotes:WaitForChild("ProfileDeltaSync") :: RemoteEvent
local SystemToastEvent = SyndicateRemotes:WaitForChild("SystemToast") :: RemoteEvent

local CurrentProfile: any = nil
local SelectedMercDirective: string = "PARASITE"
local LastQClock = -99
local LastEClock = -99

--============================================================================
-- UI BUILDER HELPERS
--============================================================================

local function makeFrame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Corner" and k ~= "Stroke" and k ~= "StrokeColor" then
			(f :: any)[k] = v
		end
	end
	if props.Corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, props.Corner)
		c.Parent = f
	end
	if props.Stroke then
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Thickness = props.Stroke
		s.Color = props.StrokeColor or Color3.fromRGB(90, 95, 130)
		s.Parent = f
	end
	f.Parent = props.Parent
	return f
end

local function makeLabel(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = if props.BackgroundTransparency ~= nil then props.BackgroundTransparency else 1
	l.Font = props.Font or Enum.Font.GothamBold
	l.TextColor3 = props.TextColor3 or Color3.fromRGB(240, 240, 250)
	l.TextScaled = if props.TextScaled ~= nil then props.TextScaled else true
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Corner" and k ~= "Stroke" and k ~= "StrokeColor" then
			(l :: any)[k] = v
		end
	end
	if props.Corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, props.Corner)
		c.Parent = l
	end
	l.TextWrapped = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MinTextSize = 10
	cap.MaxTextSize = 18
	cap.Parent = l
	l.Parent = props.Parent
	return l
end

local function makeButton(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.BorderSizePixel = 0
	b.Font = props.Font or Enum.Font.GothamBold
	b.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
	b.TextScaled = if props.TextScaled ~= nil then props.TextScaled else true
	b.AutoButtonColor = true
	b.TextWrapped = true
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Corner" and k ~= "Stroke" and k ~= "StrokeColor" and k ~= "OnClick" then
			(b :: any)[k] = v
		end
	end
	if props.Corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, props.Corner)
		c.Parent = b
	end
	if props.Stroke then
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Thickness = props.Stroke
		s.Color = props.StrokeColor or Color3.fromRGB(255, 255, 255)
		s.Parent = b
	end
	if props.OnClick then
		b.Activated:Connect(props.OnClick)
	end
	local base = b.BackgroundColor3
	b.BackgroundColor3 = Color3.fromRGB(20, 29, 46):Lerp(base, 0.22)
	b.TextColor3 = Color3.fromRGB(225, 229, 237)
	local st = b:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = base:Lerp(Color3.fromRGB(103, 125, 154), 0.65)
	st.Thickness = 1
	st.Parent = b
	local cap = Instance.new("UITextSizeConstraint")
	cap.MinTextSize = 10
	cap.MaxTextSize = 16
	cap.Parent = b
	b.Parent = props.Parent
	return b
end

--============================================================================
-- 1. MAIN MASTER HUD (`MasterHUDScreenGui`)
--============================================================================

local oldHud = PlayerGui:FindFirstChild("MasterHUDScreenGui")
if oldHud then
	oldHud:Destroy()
end

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "MasterHUDScreenGui"
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.Parent = PlayerGui

-- Top Bar Container
local topBar = makeFrame({
	Name = "TopBarContainer",
	Size = UDim2.new(1, -24, 0, 48),
	Position = UDim2.new(0, 12, 0, 8),
	BackgroundColor3 = Color3.fromRGB(16, 17, 26),
	BackgroundTransparency = 0.12,
	Corner = 10,
	Stroke = 1.5,
	StrokeColor = Color3.fromRGB(70, 75, 110),
	Parent = hudGui,
})

local currencyLabel = makeLabel({
	Name = "CurrencyLabel",
	Size = UDim2.new(0.36, 0, 0.8, 0),
	Position = UDim2.new(0.01, 0, 0.1, 0),
	Text = " GOLD: 500    GEMS: 300",
	TextColor3 = Color3.fromRGB(255, 225, 95),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = topBar,
})

local honorLabel = makeLabel({
	Name = "HonorStatusBadge",
	Size = UDim2.new(0.22, 0, 0.8, 0),
	Position = UDim2.new(0.37, 0, 0.1, 0),
	Text = " HONOR: 0 (NEUTRAL MASTER)",
	TextColor3 = Color3.fromRGB(130, 225, 255),
	Parent = topBar,
})

-- Top Right Navigation & Prototype Test Buttons
local navButtonsFrame = makeFrame({
	Size = UDim2.new(0.40, 0, 0.82, 0),
	Position = UDim2.new(0.595, 0, 0.09, 0),
	BackgroundTransparency = 1,
	Parent = topBar,
})
local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Horizontal
navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
navLayout.Padding = UDim.new(0, 6)
navLayout.Parent = navButtonsFrame

-- Toast Notification Banner
local toastBanner = makeFrame({
	Name = "ToastBanner",
	Size = UDim2.new(0.52, 0, 0, 34),
	Position = UDim2.new(0.24, 0, 0, 112),
	BackgroundColor3 = Color3.fromRGB(22, 24, 38),
	BackgroundTransparency = 0.1,
	Visible = false,
	Corner = 8,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(95, 225, 255),
	Parent = hudGui,
})
local toastText = makeLabel({
	Size = UDim2.new(1, -16, 0.84, 0),
	Position = UDim2.new(0, 8, 0.08, 0),
	Text = "",
	Parent = toastBanner,
})

local toastCounter = 0
SystemToastEvent.OnClientEvent:Connect(function(msg: string, colorType: string)
	toastCounter += 1
	local myId = toastCounter
	toastBanner.Visible = true
	toastText.Text = msg
	if colorType == "WARN" then
		toastText.TextColor3 = Color3.fromRGB(255, 105, 105)
	elseif colorType == "SUCCESS" then
		toastText.TextColor3 = Color3.fromRGB(95, 250, 145)
	else
		toastText.TextColor3 = Color3.fromRGB(135, 225, 255)
	end
	task.delay(4.5, function()
		if toastCounter == myId then
			toastBanner.Visible = false
		end
	end)
end)

-- Loot Stolen Retaliation Banner
local lootStolenBanner = makeFrame({
	Name = "LootStolenBanner",
	Size = UDim2.new(0, 520, 0, 48),
	Position = UDim2.new(0.5, -260, 0, 110),
	BackgroundColor3 = Color3.fromRGB(45, 12, 16),
	BackgroundTransparency = 0.05,
	Corner = 8,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(255, 60, 60),
	Visible = false,
	Parent = hudGui,
})

local lootStolenText = makeLabel({
	Size = UDim2.new(0.66, 0, 0.9, 0),
	Position = UDim2.new(0.02, 0, 0.05, 0),
	Text = "🚨 LOOT STOLEN!",
	TextColor3 = Color3.fromRGB(255, 180, 180),
	TextSize = 13,
	TextScaled = false,
	Parent = lootStolenBanner,
})

local currentThiefUserId = 0
local retaliateBtn = makeButton({
	Size = UDim2.new(0.30, 0, 0.8, 0),
	Position = UDim2.new(0.68, 0, 0.1, 0),
	BackgroundColor3 = Color3.fromRGB(220, 35, 45),
	Text = "⚔️ RETALIATE",
	Corner = 6,
	Parent = lootStolenBanner,
	OnClick = function()
		if currentThiefUserId ~= 0 and _G.ClientCombatState and _G.ClientCombatState.Metadata then
			local foundNetId = nil
			for nId, meta in pairs(_G.ClientCombatState.Metadata) do
				if meta.IsHero and meta.OwnerUserId == currentThiefUserId then
					foundNetId = nId
					break
				end
			end
			if foundNetId then
				FocusTargetRemote:FireServer(foundNetId)
				lootStolenBanner.Visible = false
			end
		end
	end,
})

local lootAlertCounter = 0
LootStolenAlertRemote.OnClientEvent:Connect(function(thiefUserId: number, thiefName: string, lootType: string, amount: number)
	currentThiefUserId = thiefUserId
	lootAlertCounter += 1
	local myAlertId = lootAlertCounter
	lootStolenText.Text = string.format("🚨 %s STOLE %d %s!", string.upper(thiefName), amount, lootType)
	lootStolenBanner.Visible = true

	task.delay(8.0, function()
		if lootAlertCounter == myAlertId then
			lootStolenBanner.Visible = false
		end
	end)
end)

-- Squad Wipe Recovery Lockout Banner
local squadWipeBanner = makeFrame({
	Name = "SquadWipeRecoveryBanner",
	Size = UDim2.new(0, 560, 0, 44),
	Position = UDim2.new(0.5, -280, 1, -105),
	BackgroundColor3 = Color3.fromRGB(38, 10, 14),
	BackgroundTransparency = 0.08,
	Corner = 8,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(255, 75, 75),
	Visible = false,
	Parent = hudGui,
})

local squadWipeText = makeLabel({
	Size = UDim2.new(1, -12, 1, 0),
	Position = UDim2.new(0, 6, 0, 0),
	Text = "💀 SQUAD DOWN! LOOTING LOCKED — RETURN TO WAITING ROOM TO HEAL/SWAP HEROES",
	TextColor3 = Color3.fromRGB(255, 120, 120),
	TextSize = 13,
	TextScaled = false,
	Parent = squadWipeBanner,
})

SquadWipeStateRemote.OnClientEvent:Connect(function(isWiped: boolean)
	squadWipeBanner.Visible = isWiped
end)

-- Carried Field Loot Indicator
local carriedLootPill = makeFrame({
	Name = "CarriedLootPill",
	Size = UDim2.fromOffset(160, 36),
	Position = UDim2.fromOffset(12, 58),
	BackgroundColor3 = Color3.fromRGB(26, 32, 46),
	BackgroundTransparency = 0.1,
	Corner = 8,
	Stroke = 1.5,
	StrokeColor = Color3.fromRGB(245, 195, 65),
	Visible = false,
	Parent = topBar,
})

local carriedLootLabel = makeLabel({
	Size = UDim2.new(1, -8, 1, 0),
	Position = UDim2.new(0, 4, 0, 0),
	Text = "🎒 Field: 0G, 0💎",
	TextColor3 = Color3.fromRGB(255, 235, 145),
	TextSize = 13,
	TextScaled = false,
	Parent = carriedLootPill,
})

CarriedLootSyncRemote.OnClientEvent:Connect(function(gold: number, gems: number)
	if gold > 0 or gems > 0 then
		carriedLootPill.Visible = true
		carriedLootLabel.Text = string.format("🎒 Field: %dG, %d💎", gold, gems)
	else
		carriedLootPill.Visible = false
	end
end)

-- World Boss Top Banner
local bossBanner = makeFrame({
	Name = "WorldBossTopBanner",
	Size = UDim2.new(0.54, 0, 0, 46),
	Position = UDim2.new(0.23, 0, 0, 60),
	BackgroundColor3 = Color3.fromRGB(28, 16, 38),
	BackgroundTransparency = 0.12,
	Corner = 8,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(195, 65, 255),
	Parent = hudGui,
})

local bossTitleLabel = makeLabel({
	Size = UDim2.new(0.96, 0, 0.48, 0),
	Position = UDim2.new(0.02, 0, 0.04, 0),
	Text = "THE DIMENSIONAL SOVEREIGN",
	TextColor3 = Color3.fromRGB(235, 165, 255),
	Parent = bossBanner,
})

local novaBarBg = makeFrame({
	Size = UDim2.new(0.94, 0, 0.34, 0),
	Position = UDim2.new(0.03, 0, 0.56, 0),
	BackgroundColor3 = Color3.fromRGB(45, 30, 55),
	Corner = 4,
	Parent = bossBanner,
})
local novaBarFill = makeFrame({
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(175, 45, 235),
	Corner = 4,
	Parent = novaBarBg,
})
local novaCastLabel = makeLabel({
	Size = UDim2.fromScale(1, 1),
	Text = "Prepare your squad. The rift is gathering strength.",
	Parent = novaBarBg,
})

-- Right World Boss Pity & Info Card
local rightBoard = makeFrame({
	Name = "RightWorldBossLeaderboard",
	Size = UDim2.new(0, 245, 0, 145),
	Position = UDim2.new(1, -257, 0.34, 0),
	BackgroundColor3 = Color3.fromRGB(18, 20, 30),
	BackgroundTransparency = 0.18,
	Corner = 10,
	Stroke = 1.5,
	StrokeColor = Color3.fromRGB(140, 75, 195),
	Parent = hudGui,
})

local rightBoardText = makeLabel({
	Size = UDim2.new(1, -16, 1, -12),
	Position = UDim2.new(0, 8, 0, 6),
	Text = " WORLD BOSS & PITY\n• Min 3.0% DMG for Loot\n• 50% Direct + 50% Calamity Heart\n• Boss Pity: 0% / 100%\n• Rift Lures Owned: 0",
	TextColor3 = Color3.fromRGB(230, 215, 250),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = rightBoard,
})

--============================================================================
-- 2. MODAL WINDOWS (`ThePit`, `Blacksmith`, `SquadController`)
--============================================================================

local squadController: any = nil
local promotionController: any = nil

local facilityController: any = nil
local synthesisController: any = nil
local forgeController: any = nil
local refreshBlacksmithModal: () -> ()
local selectedArtifactUUID: string? = nil

local blacksmithModal = makeFrame({
	Name = "BlacksmithModal",
	Size = UDim2.new(0, 880, 0, 520),
	Position = UDim2.new(0.5, -440, 0.5, -260),
	BackgroundColor3 = Color3.fromRGB(22, 20, 26),
	Visible = false,
	Corner = 12,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(255, 160, 45),
	Parent = hudGui,
})

--============================================================================
--============================================================================
-- FLOATING ACTION MENU ICONS (SQUAD, OVERDRIVE, RECALL, TOWER)
--============================================================================
local SLATE_TEXT = Color3.fromRGB(232, 226, 245)
local SLATE_ACTIVE = Color3.fromRGB(230, 192, 112)

local function showClientToast(msg: string)
	toastCounter += 1
	local myId = toastCounter
	toastBanner.Visible = true
	toastText.Text = msg
	toastText.TextColor3 = Color3.fromRGB(135, 225, 255)
	task.delay(3.5, function()
		if toastCounter == myId then
			toastBanner.Visible = false
		end
	end)
end

local ICON_ASSETS = {
	Squad = "rbxassetid://110935032339286",
	Overdrive = "rbxassetid://82000429636857",
	Recall = "rbxassetid://118937189328311",
	Tower = "rbxassetid://126197768286000",
}

local floatingMenuContainer = Instance.new("Frame")
floatingMenuContainer.Name = "FloatingToolbar"
floatingMenuContainer.Size = UDim2.fromOffset(400, 88)
floatingMenuContainer.Position = UDim2.new(0.5, 0, 1, -16)
floatingMenuContainer.AnchorPoint = Vector2.new(0.5, 1)
floatingMenuContainer.BackgroundTransparency = 1
floatingMenuContainer.ZIndex = 12
floatingMenuContainer.Parent = hudGui

local floatingLayout = Instance.new("UIListLayout")
floatingLayout.FillDirection = Enum.FillDirection.Horizontal
floatingLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
floatingLayout.VerticalAlignment = Enum.VerticalAlignment.Center
floatingLayout.SortOrder = Enum.SortOrder.LayoutOrder
floatingLayout.Padding = UDim.new(0, 16)
floatingLayout.Parent = floatingMenuContainer

local function createFloatingIconButton(
	name: string,
	imageAsset: string,
	layoutOrder: number,
	keybindText: string?,
	onClick: () -> ()
): (Frame, ImageButton, ImageLabel, Frame, TextLabel)
	local container = Instance.new("Frame")
	container.Name = name .. "Button"
	container.Size = UDim2.fromOffset(80, 80)
	container.BackgroundTransparency = 1
	container.LayoutOrder = layoutOrder
	container.ZIndex = 12
	container.Parent = floatingMenuContainer

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = container

	-- Outer aura / glow for active state or optimal window
	local aura = Instance.new("ImageLabel")
	aura.Name = "ActiveAura"
	aura.Size = UDim2.fromScale(1.22, 1.22)
	aura.Position = UDim2.fromScale(0.5, 0.5)
	aura.AnchorPoint = Vector2.new(0.5, 0.5)
	aura.BackgroundTransparency = 1
	aura.Image = "rbxassetid://99086944565283"
	aura.ImageColor3 = Color3.fromRGB(200, 140, 255)
	aura.ImageTransparency = 0.4
	aura.Visible = false
	aura.ZIndex = 11
	aura.Parent = container

	-- The circular floating badge ImageButton
	local btn = Instance.new("ImageButton")
	btn.Name = "Hitbox"
	btn.Size = UDim2.fromScale(1, 1)
	btn.Position = UDim2.fromScale(0.5, 0.5)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.BackgroundTransparency = 1
	btn.Image = imageAsset
	btn.ScaleType = Enum.ScaleType.Fit
	btn.AutoButtonColor = false
	btn.ZIndex = 12
	btn.Parent = container

	-- Cooldown overlay (dark circular frame with countdown text)
	local cdFrame = Instance.new("Frame")
	cdFrame.Name = "CooldownFrame"
	cdFrame.Size = UDim2.fromScale(0.82, 0.82)
	cdFrame.Position = UDim2.fromScale(0.5, 0.45)
	cdFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	cdFrame.BackgroundColor3 = Color3.fromRGB(12, 8, 18)
	cdFrame.BackgroundTransparency = 0.35
	cdFrame.BorderSizePixel = 0
	cdFrame.Visible = false
	cdFrame.ZIndex = 14
	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(1, 0)
	cdCorner.Parent = cdFrame

	local cdLabel = Instance.new("TextLabel")
	cdLabel.Name = "CooldownLabel"
	cdLabel.Size = UDim2.fromScale(1, 1)
	cdLabel.BackgroundTransparency = 1
	cdLabel.Font = Enum.Font.GothamBold
	cdLabel.Text = ""
	cdLabel.TextSize = 20
	cdLabel.TextColor3 = Color3.fromRGB(255, 235, 160)
	cdLabel.TextStrokeColor3 = Color3.fromRGB(15, 10, 25)
	cdLabel.TextStrokeTransparency = 0.2
	cdLabel.ZIndex = 15
	cdLabel.Parent = cdFrame
	cdFrame.Parent = container

	-- Optional keybind pill (e.g. [Q], [E])
	if keybindText then
		local pill = Instance.new("Frame")
		pill.Name = "KeybindPill"
		pill.Size = UDim2.fromOffset(20, 20)
		pill.Position = UDim2.new(1, -4, 0, 4)
		pill.AnchorPoint = Vector2.new(1, 0)
		pill.BackgroundColor3 = Color3.fromRGB(24, 16, 34)
		pill.BackgroundTransparency = 0.15
		pill.BorderSizePixel = 0
		pill.ZIndex = 16

		local pillCorner = Instance.new("UICorner")
		pillCorner.CornerRadius = UDim.new(1, 0)
		pillCorner.Parent = pill

		local pillStroke = Instance.new("UIStroke")
		pillStroke.Color = Color3.fromRGB(160, 130, 210)
		pillStroke.Thickness = 1.2
		pillStroke.Transparency = 0.3
		pillStroke.Parent = pill

		local pillLabel = Instance.new("TextLabel")
		pillLabel.Size = UDim2.fromScale(1, 1)
		pillLabel.BackgroundTransparency = 1
		pillLabel.Font = Enum.Font.GothamBold
		pillLabel.Text = keybindText
		pillLabel.TextSize = 11
		pillLabel.TextColor3 = Color3.fromRGB(240, 230, 255)
		pillLabel.ZIndex = 17
		pillLabel.Parent = pill

		pill.Parent = container
	end

	-- Hover & Click Tweens
	local isHovered = false
	btn.MouseEnter:Connect(function()
		isHovered = true
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.08 }):Play()
	end)
	btn.MouseLeave:Connect(function()
		isHovered = false
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
	end)
	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 }):Play()
	end)
	btn.MouseButton1Up:Connect(function()
		local targetScale = isHovered and 1.08 or 1.0
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = targetScale }):Play()
	end)

	btn.Activated:Connect(onClick)

	return container, btn, aura, cdFrame, cdLabel
end

-- 1. SQUAD (Leftmost)
local squadContainer, squadBtn, squadAura, _, _ = createFloatingIconButton(
	"Squad",
	ICON_ASSETS.Squad,
	1,
	nil,
	function()
		local isSquadOpen = squadController and squadController:IsOpen()
		_G.OpenMasterModal(isSquadOpen and "NONE" or "SQUAD")
	end
)

-- 2. OVERDRIVE
local overdriveContainer, overdriveBtn, overdriveAura, overdriveCdFrame, overdriveCdLabel = createFloatingIconButton(
	"Overdrive",
	ICON_ASSETS.Overdrive,
	2,
	"Q",
	function()
		local now = os.clock()
		local qRem = math.max(0, 20.0 - (now - LastQClock))
		if qRem <= 0 then
			LastQClock = now
			WhistleCommandRemote:FireServer(1)
		end
	end
)

-- 3. RECALL
local recallContainer, recallBtn, recallAura, recallCdFrame, recallCdLabel = createFloatingIconButton(
	"Recall",
	ICON_ASSETS.Recall,
	3,
	"E",
	function()
		local now = os.clock()
		local eRem = math.max(0, 6.0 - (now - LastEClock))
		if eRem <= 0 then
			LastEClock = now
			WhistleCommandRemote:FireServer(2)
		end
	end
)

-- 4. TOWER (Teleport to Tower Hub)
local towerContainer, towerBtn, towerAura, _, _ = createFloatingIconButton(
	"Tower",
	ICON_ASSETS.Tower,
	4,
	nil,
	function()
		if _G.RequestTowerHub then
			local ok = _G.RequestTowerHub()
			if ok ~= false then
				showClientToast("Teleporting to Tower Hub...")
			end
		else
			showClientToast("Connecting to Tower...")
		end
	end
)

_G.TriggerHUDWhistleCooldown = function(which: string)
	if which == "Q" then
		LastQClock = os.clock()
	elseif which == "E" then
		LastEClock = os.clock()
	end
end

local function updateBottomTabHighlights()
	local squadActive = squadController ~= nil and squadController:IsOpen()
	squadAura.Visible = squadActive
	if squadActive then
		squadAura.ImageColor3 = Color3.fromRGB(230, 192, 112)
		squadAura.ImageTransparency = 0.25
	end
end
_G.OpenMasterModal = function(which: string)
	if facilityController then facilityController:Close() end
	if synthesisController then synthesisController:Close() end
	if promotionController then promotionController:Close() end
	if forgeController then forgeController:Close() end
	if which ~= "SQUAD" and which ~= "WAITING_ROOM" and squadController and squadController:IsOpen() then
		squadController:Close()
	end
	if which == "BLACKSMITH" and forgeController then
		blacksmithModal.Visible = false
		forgeController:Open()
	else
		blacksmithModal.Visible = (which == "BLACKSMITH")
	end
	if (which == "WAITING_ROOM" or which == "SQUAD") and squadController then
		if not squadController:IsOpen() then
			squadController:Open()
		end
	end
	updateBottomTabHighlights()
	if which == "BLACKSMITH" and refreshBlacksmithModal then
		refreshBlacksmithModal()
	end
end

-- Add Top Bar Navigation Buttons
makeButton({
	Size = UDim2.new(0, 118, 1, 0),
	BackgroundColor3 = Color3.fromRGB(45, 115, 205),
	Text = "⚔️ Squad Deploy",
	Corner = 6,
	OnClick = function()
		if squadController then
			squadController:Toggle()
		end
	end,
	Parent = navButtonsFrame,
})
makeButton({
	Size = UDim2.new(0, 118, 1, 0),
	BackgroundColor3 = Color3.fromRGB(155, 40, 210),
	Text = " Spawn Boss",
	Corner = 6,
	OnClick = function()
		WorldBossTriggerRemote:FireServer("SPAWN_WORLD_BOSS")
	end,
	Parent = navButtonsFrame,
})
makeButton({
	Size = UDim2.new(0, 105, 1, 0),
	BackgroundColor3 = Color3.fromRGB(40, 155, 95),
	Text = " +Resources",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("DEV_GRANT_RESOURCES")
	end,
	Parent = navButtonsFrame,
})

--============================================================================
-- 3. SQUAD DEPLOY, SYNTHESIS & PROMOTION CONTROLLERS
--============================================================================
local SquadController = require(script.Parent:WaitForChild("SquadController"))
squadController = SquadController.new(hudGui, function() return CurrentProfile end, TycoonRemotes, updateBottomTabHighlights)
_G.SquadController = squadController
_G.OpenSquadManagement = function()
	_G.OpenMasterModal("SQUAD")
end

local PromotionController = require(script.Parent:WaitForChild("PromotionController"))
promotionController = PromotionController.new(hudGui, TycoonRemotes:WaitForChild("PitRequest") :: RemoteFunction)
_G.PromotionController = promotionController
_G.OpenPromotion = function()
	_G.OpenFacilityHUD("Promotion")
end

local FacilityController = require(script.Parent:WaitForChild("FacilityController"))
facilityController = FacilityController.new(hudGui, function() return CurrentProfile end, TycoonRemotes)
local SynthesisController = require(script.Parent:WaitForChild("SynthesisController"))
synthesisController = SynthesisController.new(hudGui, TycoonRemotes:WaitForChild("PitRequest") :: RemoteFunction)
_G.SynthesisController = synthesisController
local ForgeController = require(script.Parent:WaitForChild("ForgeController"))
local ArtifactRemotes = Remotes:WaitForChild("ArtifactRemotes") :: Folder
forgeController = ForgeController.new(hudGui, ArtifactRemotes, function() return CurrentProfile end, updateBottomTabHighlights)
_G.ForgeController = forgeController
_G.OpenFacilityHUD = function(facility: string)
	if facility == "Synthesis" then
		-- Focused synthesis HUD: recipient slot, level preview and material slots.
		_G.OpenMasterModal("NONE")
		if forgeController then forgeController:Close() end
		if promotionController then promotionController:Close() end
		synthesisController:Open()
	elseif facility == "Promotion" then
		-- Dedicated Hero Promotion Ritual HUD matching the Gothic Ascension Mockup.
		_G.OpenMasterModal("NONE")
		if forgeController then forgeController:Close() end
		if synthesisController then synthesisController:Close() end
		promotionController:Open()
	elseif facility == "SquadManagement" or facility == "Squad" then
		_G.OpenMasterModal("SQUAD")
	else
		_G.OpenMasterModal("NONE")
		if synthesisController then synthesisController:Close() end
		if promotionController then promotionController:Close() end
		if forgeController then forgeController:Close() end
		facilityController:Open(facility)
	end
end

--============================================================================
-- 5. BUILD THE BLACKSMITH MODAL (EQUIPPABLE ARTIFACTS & 16-TIER RARITY FORGE)
--============================================================================

makeLabel({
	Size = UDim2.new(0.75, 0, 0, 36),
	Position = UDim2.new(0.02, 0, 0, 6),
	Text = "⚒️ BLACKSMITH FORGE — HERO ARTIFACTS & 16 RARITY TIERS (COMMON -> ORIGIN)",
	TextColor3 = Color3.fromRGB(255, 175, 55),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = blacksmithModal,
})

makeButton({
	Size = UDim2.new(0, 90, 0, 30),
	Position = UDim2.new(1, -100, 0, 9),
	BackgroundColor3 = Color3.fromRGB(185, 45, 60),
	Text = "X CLOSE",
	Corner = 6,
	OnClick = function()
		blacksmithModal.Visible = false
		updateBottomTabHighlights()
	end,
	Parent = blacksmithModal,
})

-- Left Panel: Selected Artifact Detail & Upgrade Forge
local forgeDetailFrame = makeFrame({
	Size = UDim2.new(0.48, -12, 1, -56),
	Position = UDim2.new(0.02, 0, 0, 46),
	BackgroundColor3 = Color3.fromRGB(30, 26, 32),
	Corner = 10,
	Stroke = 1,
	StrokeColor = Color3.fromRGB(120, 90, 60),
	Parent = blacksmithModal,
})

local artifactTitleLabel = makeLabel({
	Size = UDim2.new(0.96, 0, 0, 32),
	Position = UDim2.new(0.02, 0, 0.02, 0),
	Text = "Select an Artifact from Inventory ->",
	TextColor3 = Color3.fromRGB(255, 230, 140),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = forgeDetailFrame,
})

local rarityBadgeLabel = makeLabel({
	Size = UDim2.new(0.96, 0, 0, 26),
	Position = UDim2.new(0.02, 0, 0.09, 0),
	Text = "[COMMON] Multiplier x1.00",
	TextColor3 = Color3.fromRGB(200, 200, 200),
	BackgroundColor3 = Color3.fromRGB(45, 45, 55),
	Corner = 4,
	Parent = forgeDetailFrame,
})

local statsDetailLabel = makeLabel({
	Size = UDim2.new(0.96, 0, 0, 90),
	Position = UDim2.new(0.02, 0, 0.16, 0),
	Text = "Base Stats:\nEffective Stats:\nEquipped To: None",
	TextColor3 = Color3.fromRGB(220, 225, 235),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = forgeDetailFrame,
})

local upgradeForgeFrame = makeFrame({
	Size = UDim2.new(0.96, 0, 0, 110),
	Position = UDim2.new(0.02, 0, 0.38, 0),
	BackgroundColor3 = Color3.fromRGB(40, 32, 38),
	Corner = 8,
	Stroke = 1,
	StrokeColor = Color3.fromRGB(200, 120, 40),
	Parent = forgeDetailFrame,
})

local nextRarityLabel = makeLabel({
	Size = UDim2.new(0.96, 0, 0, 24),
	Position = UDim2.new(0.02, 0, 0.06, 0),
	Text = "Next Rarity Preview: None",
	TextColor3 = Color3.fromRGB(255, 215, 120),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = upgradeForgeFrame,
})

local upgradeCostLabel = makeLabel({
	Size = UDim2.new(0.96, 0, 0, 24),
	Position = UDim2.new(0.02, 0, 0.30, 0),
	Text = "Cost: 0 Gold, 0 Gems",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = upgradeForgeFrame,
})

local upgradeButton = makeButton({
	Size = UDim2.new(0.96, 0, 0, 38),
	Position = UDim2.new(0.02, 0, 0.58, 0),
	BackgroundColor3 = Color3.fromRGB(215, 115, 30),
	Text = "⚒️ UPGRADE RARITY",
	Corner = 6,
	OnClick = function()
		if not CurrentProfile or not selectedArtifactUUID then return end
		local sel = CurrentProfile.Artifacts and CurrentProfile.Artifacts[selectedArtifactUUID]
		if not sel or sel.Rarity >= 16 then return end
		local cost = ArtifactCatalog.GetUpgradeCost(sel.Rarity)
		if not cost then return end
		local haveGold = CurrentProfile.Currencies.Gold or 0
		local haveGems = CurrentProfile.Currencies.Gems or 0
		if haveGold >= cost.Gold and haveGems >= cost.Gems then
			task.spawn(function()
				local success, msg = RequestUpgradeRarityFunc:InvokeServer(sel.UUID)
				if refreshBlacksmithModal then refreshBlacksmithModal() end
			end)
		end
	end,
	Parent = upgradeForgeFrame,
})

-- Equip / Unequip Section
local heroEquipHeader = makeLabel({
	Size = UDim2.new(0.96, 0, 0, 24),
	Position = UDim2.new(0.02, 0, 0.65, 0),
	Text = "Hero Equipping (Archetype Restricted):",
	TextColor3 = Color3.fromRGB(255, 215, 120),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = forgeDetailFrame,
})

local heroEquipScroll = Instance.new("ScrollingFrame")
heroEquipScroll.Name = "HeroEquipScroll"
heroEquipScroll.Size = UDim2.new(0.96, 0, 0.28, 0)
heroEquipScroll.Position = UDim2.new(0.02, 0, 0.70, 0)
heroEquipScroll.BackgroundTransparency = 1
heroEquipScroll.BorderSizePixel = 0
heroEquipScroll.ScrollBarThickness = 5
heroEquipScroll.Parent = forgeDetailFrame

local heroEquipLayout = Instance.new("UIListLayout")
heroEquipLayout.Padding = UDim.new(0, 4)
heroEquipLayout.Parent = heroEquipScroll

-- Right Panel: Inventory Artifact List
local artifactListFrame = makeFrame({
	Size = UDim2.new(0.48, -12, 1, -56),
	Position = UDim2.new(0.50, 4, 0, 46),
	BackgroundColor3 = Color3.fromRGB(24, 22, 28),
	Corner = 10,
	Stroke = 1,
	StrokeColor = Color3.fromRGB(90, 80, 95),
	Parent = blacksmithModal,
})

local artifactScroll = Instance.new("ScrollingFrame")
artifactScroll.Name = "ArtifactScroll"
artifactScroll.Size = UDim2.new(0.96, 0, 0.94, 0)
artifactScroll.Position = UDim2.new(0.02, 0, 0.03, 0)
artifactScroll.BackgroundTransparency = 1
artifactScroll.BorderSizePixel = 0
artifactScroll.ScrollBarThickness = 6
artifactScroll.Parent = artifactListFrame

local artifactLayout = Instance.new("UIListLayout")
artifactLayout.Padding = UDim.new(0, 6)
artifactLayout.Parent = artifactScroll

refreshBlacksmithModal = function()
	if forgeController then
		forgeController:Refresh()
	end
	if not CurrentProfile then return end
	local artifacts = CurrentProfile.Artifacts or {}

	if (not selectedArtifactUUID or not artifacts[selectedArtifactUUID]) then
		for uuid, _ in pairs(artifacts) do
			selectedArtifactUUID = uuid
			break
		end
	end

	local sel = selectedArtifactUUID and artifacts[selectedArtifactUUID]
	if sel then
		local rInfo = ArtifactCatalog.GetRarityInfo(sel.Rarity)
		local baseATK, baseSpd = ArtifactCatalog.GetStarBaseStats(sel.Star)
		local effATK, effSpd = ArtifactCatalog.CalculateEffectiveStats(sel.Star, sel.Rarity)
		local starsStr = string.rep("★", sel.Star or 1)

		artifactTitleLabel.Text = string.format("%s %s [%s]", sel.DisplayName or "Artifact", starsStr, sel.Type or "WEAPON")
		artifactTitleLabel.TextColor3 = rInfo.Color

		rarityBadgeLabel.Text = string.format("Tier %d: %s (Multiplier x%0.2f)", sel.Rarity, rInfo.Name:upper(), rInfo.Multiplier)
		rarityBadgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		rarityBadgeLabel.BackgroundColor3 = rInfo.Color:Lerp(Color3.fromRGB(15, 15, 20), 0.5)

		local equippedHeroName = "None (Available in Inventory)"
		local equippedHeroUUID: string? = nil
		if sel.EquippedHeroUUID and CurrentProfile.Heroes and CurrentProfile.Heroes[sel.EquippedHeroUUID] then
			local h = CurrentProfile.Heroes[sel.EquippedHeroUUID]
			equippedHeroName = string.format("%s (%s Lv.%d)", h.DisplayName, h.Archetype, h.Level)
			equippedHeroUUID = sel.EquippedHeroUUID
		end

		statsDetailLabel.Text = string.format(
			"Base Stats (Tier %d★): +%d ATK, +%0.1f%% AtkSpd\nEffective Stats (x%0.2f): +%d ATK, +%0.1f%% AtkSpd\nEquipped to: %s",
			sel.Star, baseATK, baseSpd * 100,
			rInfo.Multiplier, effATK, effSpd * 100,
			equippedHeroName
		)

		local nextRarity = sel.Rarity + 1
		local cost = ArtifactCatalog.GetUpgradeCost(sel.Rarity)
		if nextRarity <= 16 and cost then
			local nextInfo = ArtifactCatalog.GetRarityInfo(nextRarity)
			local nextEffATK, nextEffSpd = ArtifactCatalog.CalculateEffectiveStats(sel.Star, nextRarity)
			nextRarityLabel.Text = string.format("Next: %s (x%0.2f) -> +%d ATK, +%0.1f%% Spd", nextInfo.Name, nextInfo.Multiplier, nextEffATK, nextEffSpd * 100)
			nextRarityLabel.TextColor3 = nextInfo.Color

			local haveGold = CurrentProfile.Currencies.Gold or 0
			local haveGems = CurrentProfile.Currencies.Gems or 0
			local canAfford = haveGold >= cost.Gold and haveGems >= cost.Gems

			upgradeCostLabel.Text = string.format("Cost: %d Gold, %d Gems (Have: %d G, %d Gems)", cost.Gold, cost.Gems, math.floor(haveGold), math.floor(haveGems))
			upgradeCostLabel.TextColor3 = canAfford and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 120, 120)

			upgradeButton.Text = string.format("⚒️ FORGE UPGRADE TO %s", nextInfo.Name:upper())
			upgradeButton.BackgroundColor3 = canAfford and Color3.fromRGB(215, 115, 30) or Color3.fromRGB(90, 70, 65)
			upgradeButton.AutoButtonColor = canAfford
		else
			nextRarityLabel.Text = "🌟 MAX RARITY ACHIEVED (16: ORIGIN)!"
			nextRarityLabel.TextColor3 = Color3.fromRGB(255, 160, 245)
			upgradeCostLabel.Text = "Maximum multiplier reached (x18.00)!"
			upgradeCostLabel.TextColor3 = Color3.fromRGB(255, 230, 140)
			upgradeButton.Text = "MAX RARITY REACHED"
			upgradeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		end

		for _, c in ipairs(heroEquipScroll:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end
		local listCount = 0

		if equippedHeroUUID then
			listCount += 1
			local unequipRow = makeFrame({
				Size = UDim2.new(1, -8, 0, 32),
				BackgroundColor3 = Color3.fromRGB(150, 40, 50),
				Corner = 5,
				Parent = heroEquipScroll,
			})
			makeButton({
				Size = UDim2.fromScale(1, 1),
				Text = string.format("⚔️ UNEQUIP FROM %s", equippedHeroName),
				BackgroundColor3 = Color3.fromRGB(160, 45, 55),
				Corner = 5,
				OnClick = function()
					task.spawn(function()
						RequestUnequipArtifactFunc:InvokeServer(equippedHeroUUID)
						if refreshBlacksmithModal then refreshBlacksmithModal() end
					end)
				end,
				Parent = unequipRow,
			})
		end

		for heroUUID, hero in pairs(CurrentProfile.Heroes or {}) do
			if ArtifactCatalog.CanHeroEquip(hero.Archetype, sel.Type) then
				listCount += 1
				local isCurrentHolder = (heroUUID == equippedHeroUUID)
				local hRow = makeFrame({
					Size = UDim2.new(1, -8, 0, 32),
					BackgroundColor3 = isCurrentHolder and Color3.fromRGB(50, 70, 50) or Color3.fromRGB(40, 42, 54),
					Corner = 5,
					Parent = heroEquipScroll,
				})
				makeLabel({
					Size = UDim2.new(0.65, 0, 1, 0),
					Position = UDim2.new(0.03, 0, 0, 0),
					Text = string.format("%s (%s Lv.%d)", hero.DisplayName, hero.Archetype, hero.Level),
					TextColor3 = isCurrentHolder and Color3.fromRGB(140, 255, 140) or Color3.fromRGB(235, 235, 245),
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = hRow,
				})
				makeButton({
					Size = UDim2.new(0.30, 0, 0.8, 0),
					Position = UDim2.new(0.68, 0, 0.1, 0),
					BackgroundColor3 = isCurrentHolder and Color3.fromRGB(70, 90, 70) or Color3.fromRGB(45, 125, 215),
					Text = isCurrentHolder and "EQUIPPED" or "EQUIP",
					Corner = 4,
					OnClick = function()
						if not isCurrentHolder then
							task.spawn(function()
								RequestEquipArtifactFunc:InvokeServer(heroUUID, sel.UUID)
								if refreshBlacksmithModal then refreshBlacksmithModal() end
							end)
						end
					end,
					Parent = hRow,
				})
			end
		end
		heroEquipScroll.CanvasSize = UDim2.new(0, 0, 0, listCount * 36)
	else
		artifactTitleLabel.Text = "No Artifacts in Inventory"
		rarityBadgeLabel.Text = "Defeat Bosses or Visit Waiting Room to obtain Artifacts!"
		statsDetailLabel.Text = ""
		nextRarityLabel.Text = ""
		upgradeCostLabel.Text = ""
		upgradeButton.Text = "NO ARTIFACT SELECTED"
		heroEquipScroll:ClearAllChildren()
	end

	for _, c in ipairs(artifactScroll:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
		end
	local artCount = 0
	for uuid, art in pairs(artifacts) do
		artCount += 1
		local rInfo = ArtifactCatalog.GetRarityInfo(art.Rarity)
		local effATK, effSpd = ArtifactCatalog.CalculateEffectiveStats(art.Star, art.Rarity)
		local isSel = (uuid == selectedArtifactUUID)

		local card = makeFrame({
			Size = UDim2.new(1, -8, 0, 56),
			BackgroundColor3 = isSel and Color3.fromRGB(55, 45, 40) or Color3.fromRGB(32, 30, 38),
			Corner = 6,
			Stroke = isSel and 2 or 1,
			StrokeColor = isSel and Color3.fromRGB(255, 180, 50) or rInfo.Color,
			Parent = artifactScroll,
		})

		local equipTag = "[Available]"
		if art.EquippedHeroUUID and CurrentProfile.Heroes and CurrentProfile.Heroes[art.EquippedHeroUUID] then
			equipTag = "[" .. CurrentProfile.Heroes[art.EquippedHeroUUID].DisplayName .. "]"
		end

		makeLabel({
			Size = UDim2.new(0.68, 0, 0.5, 0),
			Position = UDim2.new(0.03, 0, 0.05, 0),
			Text = string.format("%s %s [%s]", art.DisplayName, string.rep("★", art.Star or 1), art.Type),
			TextColor3 = rInfo.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		makeLabel({
			Size = UDim2.new(0.68, 0, 0.45, 0),
			Position = UDim2.new(0.03, 0, 0.52, 0),
			Text = string.format("%s (x%0.2f) • +%d ATK, +%0.0f%% Spd", rInfo.Name, rInfo.Multiplier, effATK, effSpd * 100),
			TextColor3 = Color3.fromRGB(180, 185, 195),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		makeButton({
			Size = UDim2.new(0.26, 0, 0.72, 0),
			Position = UDim2.new(0.71, 0, 0.14, 0),
			BackgroundColor3 = isSel and Color3.fromRGB(220, 125, 30) or Color3.fromRGB(60, 62, 75),
			Text = isSel and "FORGING" or equipTag,
			Corner = 4,
			OnClick = function()
				selectedArtifactUUID = uuid
				refreshBlacksmithModal()
			end,
			Parent = card,
		})
	end
	artifactScroll.CanvasSize = UDim2.new(0, 0, 0, artCount * 62)
end

--============================================================================
-- 6. PROFILE SYNC & 60 FPS HUD UPDATE LOOP (WITH [E] SKILL-CHECK PULSE)
--============================================================================

ProfileDeltaSyncEvent.OnClientEvent:Connect(function(profile: any)
	if not profile then return end
	if profile._PitDelta then
		-- Pit and combat EXP send small updates; retain unrelated profile fields.
		if not CurrentProfile then return end
		for uuid, hero in profile.Heroes or {} do CurrentProfile.Heroes[uuid] = hero end
		for _, uuid in profile.Removed or {} do CurrentProfile.Heroes[uuid] = nil end
		for _, key in {"Currencies", "PitMaterials", "PitRevision", "UnlockedResearch"} do
			if profile[key] ~= nil then CurrentProfile[key] = profile[key] end
		end
		profile = CurrentProfile
	else CurrentProfile = profile end
	_G.CurrentProfile = CurrentProfile
	facilityController:Refresh()
	if synthesisController and synthesisController.Root and synthesisController.Root.Visible then
		synthesisController:Refresh()
	end
	if forgeController and forgeController.Root and forgeController.Root.Visible then
		forgeController:Refresh()
	end

	currencyLabel.Text = string.format(
		" GOLD: %d    GEMS: %d",
		math.floor(profile.Currencies.Gold),
		math.floor(profile.Currencies.Gems)
	)

	local h = profile.Social.Honor
	local isRogue = (h <= -30) or (os.time() < (profile.Social.RogueUntilTimestamp or 0))
	if isRogue then
		local rem = math.max(0, (profile.Social.RogueUntilTimestamp or 0) - os.time())
		honorLabel.Text = string.format(" ROGUE MASTER (Hon: %d | %ds)", h, rem)
		honorLabel.TextColor3 = Color3.fromRGB(255, 75, 85)
	elseif h >= 50 then
		honorLabel.Text = string.format(" SYNDICATE SAINT (Hon: +%d)", h)
		honorLabel.TextColor3 = Color3.fromRGB(255, 220, 75)
	else
		honorLabel.Text = string.format(" HONOR: %d (NEUTRAL)", h)
		honorLabel.TextColor3 = Color3.fromRGB(130, 225, 255)
	end

	-- Right Board Pity Summary
	rightBoardText.Text = string.format(
		" WORLD BOSS & PITY\n• Min 3.0%% DMG for Loot\n• Boss Pity Meter: %d%% / 100%%\n• Rift Lures Owned: %d",
		profile.BossPity,
		profile.RiftLuresOwned
	)

	if squadController and squadController:IsOpen() then
		squadController:Refresh()
	end
	if promotionController and promotionController:IsOpen() then
		promotionController:Refresh()
	end
	if ((forgeController and forgeController.Root and forgeController.Root.Visible) or blacksmithModal.Visible) and refreshBlacksmithModal then
		refreshBlacksmithModal()
	end
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local cs = _G.ClientCombatState

	-- 1. Whistle Cooldowns & Devouring Nova Recall Skill-Check Pulse
	local qRem = math.max(0, 20.0 - (now - LastQClock))
	if qRem > 0 then
		overdriveCdFrame.Visible = true
		overdriveCdLabel.Text = string.format("%.0fs", math.ceil(qRem))
	else
		overdriveCdFrame.Visible = false
	end

	local eRem = math.max(0, 6.0 - (now - LastEClock))
	local novaElapsed = (cs and cs.NovaCastStartClock > 0) and (now - cs.NovaCastStartClock) or 999
	local inNovaOptimalWindow = (novaElapsed >= 1.1 and novaElapsed <= 2.8)

	if inNovaOptimalWindow then
		recallAura.Visible = true
		recallAura.ImageColor3 = Color3.fromRGB(255, 215, 75)
		recallAura.ImageTransparency = 0.15 + 0.15 * math.sin(now * 12)
		recallCdFrame.Visible = false
	elseif eRem > 0 then
		recallAura.Visible = false
		recallCdFrame.Visible = true
		recallCdLabel.Text = string.format("%.0fs", math.ceil(eRem))
	else
		recallAura.Visible = false
		recallCdFrame.Visible = false
	end

	-- 2. Update World Boss Top Banner & Devouring Nova Cast Bar
	bossBanner.Visible = cs and cs.WorldBossNetId ~= nil or false
	if cs and cs.WorldBossNetId then
		local hpPct = (cs.WorldBossHPPerMille or 1000) / 10.0
		local coreTag = cs.WorldBossCoreExposed and " [ CORE EXPOSED: +25% DMG! PRESS Q!]" or ""
		bossTitleLabel.Text = string.format(
			" THE DIMENSIONAL SOVEREIGN (PHASE %d) — HP: %.1f%%%s",
			cs.WorldBossPhase or 1, hpPct, coreTag
		)
		if novaElapsed <= (cs.NovaCastDuration or 3.0) then
			local ratio = math.clamp(novaElapsed / (cs.NovaCastDuration or 3.0), 0, 1)
			novaBarFill.Size = UDim2.fromScale(ratio, 1)
			novaBarFill.BackgroundColor3 = Color3.fromRGB(255, 35, 65)
			novaCastLabel.Text = string.format(" DEVOURING NOVA IN %.1fs — STAND IN SAFE RIM (R>85) & PRESS [E]!", (cs.NovaCastDuration or 3.0) - novaElapsed)
		else
			novaBarFill.Size = UDim2.fromScale(math.clamp(hpPct / 100.0, 0, 1), 1)
			novaBarFill.BackgroundColor3 = cs.WorldBossCoreExposed and Color3.fromRGB(255, 195, 40) or Color3.fromRGB(185, 45, 245)
			novaCastLabel.Text = string.format("BOSS HP: %.1f%% | Devouring Nova every 20s", hpPct)
		end
	else
		bossTitleLabel.Text = "THE DIMENSIONAL SOVEREIGN"
		novaBarFill.Size = UDim2.fromScale(1, 1)
		novaCastLabel.Text = "Prepare your squad. The rift is gathering strength."
	end
end)

-- Art-pack UI composition. Gameplay callbacks above remain authoritative.
do
	local UserInputService = game:GetService("UserInputService")
	local P = {
		surface = Color3.fromRGB(15, 22, 36),
		edge = Color3.fromRGB(58, 75, 100),
		gold = Color3.fromRGB(216, 180, 105),
		cyan = Color3.fromRGB(73, 225, 214),
		muted = Color3.fromRGB(159, 177, 200),
	}
	hudGui:SetAttribute("ArtPackUIVersion", "AnimeR15_20261020")
	hudGui.IgnoreGuiInset = false
	hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function stroke(parent: Instance, color: Color3?)
		local st = parent:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Thickness = 1
		st.Color = color or P.edge
		st.Transparency = 0.12
		st.Parent = parent
	end

	local function image(parent: Instance, asset: string, size: UDim2, pos: UDim2): ImageLabel
		local o = Instance.new("ImageLabel")
		o.BackgroundTransparency = 1
		o.Image = asset
		o.Size = size
		o.Position = pos
		o.ScaleType = Enum.ScaleType.Fit
		o.Parent = parent
		return o
	end

	local modalBackdrop = Instance.new("TextButton")
	modalBackdrop.Name = "ModalScrim"
	modalBackdrop.Text = ""
	modalBackdrop.AutoButtonColor = false
	modalBackdrop.BackgroundColor3 = Color3.fromRGB(3, 6, 13)
	modalBackdrop.BackgroundTransparency = 0.24
	modalBackdrop.Size = UDim2.fromScale(1, 1)
	modalBackdrop.Visible = false
	modalBackdrop.ZIndex = 10
	modalBackdrop.Parent = hudGui
	modalBackdrop.Activated:Connect(function()
		_G.OpenMasterModal("NONE")
	end)

	local modalList = { blacksmithModal }
	for _, m in modalList do
		m.AnchorPoint = Vector2.new(0.5, 0.5)
		m.Position = UDim2.fromScale(0.5, 0.5)
		m.ZIndex = 20
		m:GetPropertyChangedSignal("Visible"):Connect(function()
			local any = false
			for _, other in modalList do
				if other.Visible then
					any = true
				end
			end
			modalBackdrop.Visible = any
			local touch = PlayerGui:FindFirstChild("TouchGui")
			if touch and touch:IsA("ScreenGui") then
				touch.Enabled = not any
			end
		end)
	end

	--========================================================================
	-- SAVED GOTHIC UI TEXT BOX DESIGN (Obsidian Sheen + White Filigree Corners)
	--========================================================================
	local GothicPalette = {
		ObsidianDark = Color3.fromRGB(13, 9, 18),
		ObsidianMid = Color3.fromRGB(20, 14, 28),
		ObsidianSheen = Color3.fromRGB(38, 28, 50),
		FiligreeWhite = Color3.fromRGB(246, 244, 255),
		OuterGlow = Color3.fromRGB(222, 205, 255),
		CornerCutout = Color3.fromRGB(26, 15, 38),
		InnerLineBright = Color3.fromRGB(112, 100, 132),
		InnerLineMuted = Color3.fromRGB(68, 58, 84),
	}

	local function applyGothicBoxStyle(container: Frame, compact: boolean?, zOrder: number?): Frame
		local isCompact = if compact ~= nil then compact else false
		local baseZ = zOrder or container.ZIndex or 8

		container.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		container.BackgroundTransparency = 0
		container.BorderSizePixel = 0
		container.ZIndex = baseZ

		for _, child in ipairs(container:GetChildren()) do
			if
				child:IsA("UICorner")
				or child:IsA("UIStroke")
				or child:IsA("UIGradient")
				or child.Name == "GothicDecorRoot"
			then
				child:Destroy()
			end
		end

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, isCompact and 3 or 4)
		corner.Parent = container

		local grad = Instance.new("UIGradient")
		grad.Rotation = 128
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, GothicPalette.ObsidianDark),
			ColorSequenceKeypoint.new(0.28, GothicPalette.ObsidianMid),
			ColorSequenceKeypoint.new(0.46, GothicPalette.ObsidianSheen),
			ColorSequenceKeypoint.new(0.62, GothicPalette.ObsidianMid),
			ColorSequenceKeypoint.new(1.00, GothicPalette.ObsidianDark),
		})
		grad.Parent = container

		local outerStroke = Instance.new("UIStroke")
		outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outerStroke.Thickness = isCompact and 1.5 or 2
		outerStroke.Color = GothicPalette.FiligreeWhite
		outerStroke.Transparency = 0.04
		outerStroke.Parent = container

		local decorRoot = Instance.new("Folder")
		decorRoot.Name = "GothicDecorRoot"
		decorRoot.Parent = container

		local glowFrame = Instance.new("Frame")
		glowFrame.Name = "OuterGlow"
		glowFrame.Size = UDim2.new(1, isCompact and 6 or 10, 1, isCompact and 6 or 10)
		glowFrame.Position = UDim2.fromScale(0.5, 0.5)
		glowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		glowFrame.BackgroundTransparency = 1
		glowFrame.ZIndex = baseZ
		glowFrame.Parent = decorRoot

		local glowCorner = Instance.new("UICorner")
		glowCorner.CornerRadius = UDim.new(0, isCompact and 5 or 7)
		glowCorner.Parent = glowFrame

		local glowStroke = Instance.new("UIStroke")
		glowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		glowStroke.Thickness = isCompact and 2.5 or 4
		glowStroke.Color = GothicPalette.OuterGlow
		glowStroke.Transparency = 0.62
		glowStroke.Parent = glowFrame

		local insetX = isCompact and 10 or 18
		local line1Y = isCompact and 4 or 7
		local line2Y = isCompact and 6 or 11

		local function makeTrimLine(name: string, yOffset: number, fromBottom: boolean, col: Color3, trans: number)
			local line = Instance.new("Frame")
			line.Name = name
			line.Size = UDim2.new(1, -insetX * 2, 0, 1)
			line.Position = if fromBottom
				then UDim2.new(0, insetX, 1, -yOffset)
				else UDim2.new(0, insetX, 0, yOffset)
			line.BackgroundColor3 = col
			line.BackgroundTransparency = trans
			line.BorderSizePixel = 0
			line.ZIndex = baseZ + 1
			line.Parent = decorRoot
		end

		makeTrimLine("TopTrimOuter", line1Y, false, GothicPalette.InnerLineBright, 0.25)
		makeTrimLine("TopTrimInner", line2Y, false, GothicPalette.InnerLineMuted, 0.42)
		makeTrimLine("BottomTrimOuter", line1Y, true, GothicPalette.InnerLineBright, 0.25)
		makeTrimLine("BottomTrimInner", line2Y, true, GothicPalette.InnerLineMuted, 0.42)

		local wingLen = isCompact and 13 or 24
		local wingThick = isCompact and 2 or 3
		local diamondOuter = isCompact and 9 or 15
		local diamondInner = isCompact and 5 or 8
		local spurSize = isCompact and 4 or 6

		local corners = {
			{ Name = "CornerTL", X = 0, Y = 0, AX = 0, AY = 0, SX = 1, SY = 1 },
			{ Name = "CornerTR", X = 1, Y = 0, AX = 1, AY = 0, SX = -1, SY = 1 },
			{ Name = "CornerBL", X = 0, Y = 1, AX = 0, AY = 1, SX = 1, SY = -1 },
			{ Name = "CornerBR", X = 1, Y = 1, AX = 1, AY = 1, SX = -1, SY = -1 },
		}

		for _, c in ipairs(corners) do
			local hWing = Instance.new("Frame")
			hWing.Name = c.Name .. "_HWing"
			hWing.Size = UDim2.fromOffset(wingLen, wingThick)
			hWing.AnchorPoint = Vector2.new(c.AX, c.AY)
			hWing.Position = UDim2.new(c.X, -c.SX * 1, c.Y, -c.SY * 1)
			hWing.BackgroundColor3 = GothicPalette.FiligreeWhite
			hWing.BorderSizePixel = 0
			hWing.ZIndex = baseZ + 2
			hWing.Parent = decorRoot

			local vWing = Instance.new("Frame")
			vWing.Name = c.Name .. "_VWing"
			vWing.Size = UDim2.fromOffset(wingThick, wingLen)
			vWing.AnchorPoint = Vector2.new(c.AX, c.AY)
			vWing.Position = UDim2.new(c.X, -c.SX * 1, c.Y, -c.SY * 1)
			vWing.BackgroundColor3 = GothicPalette.FiligreeWhite
			vWing.BorderSizePixel = 0
			vWing.ZIndex = baseZ + 2
			vWing.Parent = decorRoot

			local hSpur = Instance.new("Frame")
			hSpur.Name = c.Name .. "_HSpur"
			hSpur.Size = UDim2.fromOffset(spurSize, spurSize)
			hSpur.AnchorPoint = Vector2.new(0.5, 0.5)
			hSpur.Position = UDim2.new(c.X, c.SX * (wingLen - 2), c.Y, c.SY * 1)
			hSpur.Rotation = 45
			hSpur.BackgroundColor3 = GothicPalette.FiligreeWhite
			hSpur.BorderSizePixel = 0
			hSpur.ZIndex = baseZ + 2
			hSpur.Parent = decorRoot

			local vSpur = Instance.new("Frame")
			vSpur.Name = c.Name .. "_VSpur"
			vSpur.Size = UDim2.fromOffset(spurSize, spurSize)
			vSpur.AnchorPoint = Vector2.new(0.5, 0.5)
			vSpur.Position = UDim2.new(c.X, c.SX * 1, c.Y, c.SY * (wingLen - 2))
			vSpur.Rotation = 45
			vSpur.BackgroundColor3 = GothicPalette.FiligreeWhite
			vSpur.BorderSizePixel = 0
			vSpur.ZIndex = baseZ + 2
			vSpur.Parent = decorRoot

			local crestOuter = Instance.new("Frame")
			crestOuter.Name = c.Name .. "_CrestOuter"
			crestOuter.Size = UDim2.fromOffset(diamondOuter, diamondOuter)
			crestOuter.AnchorPoint = Vector2.new(0.5, 0.5)
			crestOuter.Position = UDim2.new(c.X, c.SX * (isCompact and 3 or 5), c.Y, c.SY * (isCompact and 3 or 5))
			crestOuter.Rotation = 45
			crestOuter.BackgroundColor3 = GothicPalette.FiligreeWhite
			crestOuter.BorderSizePixel = 0
			crestOuter.ZIndex = baseZ + 2
			crestOuter.Parent = decorRoot

			local crestCutout = Instance.new("Frame")
			crestCutout.Name = "DarkCutout"
			crestCutout.Size = UDim2.fromOffset(diamondInner, diamondInner)
			crestCutout.AnchorPoint = Vector2.new(0.5, 0.5)
			crestCutout.Position = UDim2.fromScale(0.5, 0.5)
			crestCutout.BackgroundColor3 = GothicPalette.CornerCutout
			crestCutout.BorderSizePixel = 0
			crestCutout.ZIndex = baseZ + 3
			crestCutout.Parent = crestOuter
		end

		return container
	end



	-- Remove top menu bar so the viewport top is unobstructed and currencies live in the bottom-left
	topBar.Visible = false
	currencyLabel.Visible = false
	honorLabel.Visible = false

	carriedLootPill.Parent = hudGui
	carriedLootPill.AnchorPoint = Vector2.new(0, 1)
	carriedLootPill.Position = UDim2.new(0, 16, 1, -74)
	carriedLootPill.ZIndex = 8

	-- Bottom-left Gold & Diamond Currency Containers (above PATCH NOTES) using Gothic Box Design
	local currencyCluster = Instance.new("Frame")
	currencyCluster.Name = "CurrencyCluster"
	currencyCluster.BackgroundTransparency = 1
	currencyCluster.Size = UDim2.fromOffset(258, 44)
	currencyCluster.AnchorPoint = Vector2.new(0, 1)
	currencyCluster.Position = UDim2.new(0, 16, 1, -18)
	currencyCluster.ZIndex = 8
	currencyCluster.Parent = hudGui

	local currencyFields: { [string]: TextLabel } = {}
	local currencies = {
		{ "Gold", "rbxassetid://99086944565283", P.gold },
		{ "Gems", "rbxassetid://74751786636473", P.cyan },
	}
	for i, item in currencies do
		local f = makeFrame({
			Name = item[1] .. "Pill",
			Size = UDim2.fromOffset(122, 42),
			Position = UDim2.fromOffset((i - 1) * 134, 1),
			BackgroundColor3 = GothicPalette.ObsidianDark,
			Parent = currencyCluster,
		})
		applyGothicBoxStyle(f, true, 8)
		local icon = image(f, item[2] :: string, UDim2.fromOffset(22, 22), UDim2.fromOffset(12, 10))
		icon.ZIndex = 11
		local lbl = makeLabel({
			Size = UDim2.new(1, -46, 1, 0),
			Position = UDim2.fromOffset(40, 0),
			Text = if item[1] == "Gold" then "500" else "300",
			TextColor3 = item[3] :: Color3,
			Font = Enum.Font.Fantasy,
			TextSize = 17,
			TextScaled = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = f,
		})
		lbl.ZIndex = 11
		currencyFields[item[1] :: string] = lbl
	end

	local function number(n: number?): string
		local val = math.floor(n or 0)
		if val >= 1000000 then
			return string.format("%.1fm", val / 1000000)
		elseif val >= 10000 then
			return string.format("%.1fk", val / 1000)
		else
			return tostring(val)
		end
	end

	local function updateCurrency(profile: any)
		if not profile then return end
		if profile._PitDelta then profile = CurrentProfile end
		if not profile or not profile.Currencies then return end
		for key, label in currencyFields do
			label.Text = number(profile.Currencies[key])
		end
	end
	ProfileDeltaSyncEvent.OnClientEvent:Connect(updateCurrency)
	updateCurrency(CurrentProfile)

	-- Keep Studio F8 development hooks available without the top menu bar
	navButtonsFrame.Parent = hudGui
	navButtonsFrame.AnchorPoint = Vector2.new(1, 0)
	navButtonsFrame.Position = UDim2.new(1, -16, 0, 12)
	navButtonsFrame.Size = UDim2.fromOffset(240, 36)
	local devButtons = {}
	for _, b in navButtonsFrame:GetChildren() do
		if b:IsA("TextButton") then
			b.Visible = false
			if b.Text:find("Spawn Boss") or b.Text:find("Resources") then
				table.insert(devButtons, b)
			end
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			_G.OpenMasterModal("NONE")
		end
		if input.KeyCode == Enum.KeyCode.B then
			if _G.ToggleShop then
				_G.ToggleShop()
			end
		end
		if RunService:IsStudio() and input.KeyCode == Enum.KeyCode.F8 then
			for _, b in devButtons do
				b.Visible = not b.Visible
			end
		end
	end)

	local compact = false
	local encounterOpen = false
	local encounterToggle = makeButton({
		Name = "EncounterToggle",
		Text = "Encounter",
		Size = UDim2.fromOffset(120, 32),
		BackgroundColor3 = P.surface,
		Corner = 8,
		OnClick = function()
			encounterOpen = not encounterOpen
			rightBoard.Visible = not compact or encounterOpen
		end,
		Parent = hudGui,
	})
	encounterToggle.TextScaled = false
	encounterToggle.TextSize = 12
	stroke(encounterToggle)

	--============================================================================
	-- LEFT SIDEBAR NAVIGATION (Shop Icon & Future Sidebar Tools)
	--============================================================================
	local leftSidebar = Instance.new("Frame")
	leftSidebar.Name = "LeftSidebar"
	leftSidebar.Size = UDim2.fromOffset(80, 240)
	leftSidebar.Position = UDim2.new(0, 16, 0.40, 0)
	leftSidebar.AnchorPoint = Vector2.new(0, 0.5)
	leftSidebar.BackgroundTransparency = 1
	leftSidebar.ZIndex = 12
	leftSidebar.Parent = hudGui

	local leftList = Instance.new("UIListLayout")
	leftList.FillDirection = Enum.FillDirection.Vertical
	leftList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	leftList.SortOrder = Enum.SortOrder.LayoutOrder
	leftList.Padding = UDim.new(0, 12)
	leftList.Parent = leftSidebar

	-- Pure Floating Shop Icon Button (no box container, pure transparent silhouette)
	local shopBtn = Instance.new("ImageButton")
	shopBtn.Name = "ShopIconButton"
	shopBtn.Size = UDim2.fromOffset(88, 88)
	shopBtn.BackgroundTransparency = 1
	shopBtn.BorderSizePixel = 0
	shopBtn.AutoButtonColor = false
	shopBtn.Image = "rbxassetid://95822585057439"
	shopBtn.ScaleType = Enum.ScaleType.Fit
	shopBtn.LayoutOrder = 1
	shopBtn.ZIndex = 12
	shopBtn.Parent = leftSidebar

	local shopScale = Instance.new("UIScale")
	shopScale.Scale = 1
	shopScale.Parent = shopBtn

	-- Notification Badge ("!") with breathing animation
	local shopBadge = Instance.new("Frame")
	shopBadge.Name = "NotificationBadge"
	shopBadge.Size = UDim2.fromOffset(22, 22)
	shopBadge.Position = UDim2.new(1, -6, 0, 4)
	shopBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	shopBadge.BackgroundColor3 = Color3.fromRGB(235, 45, 65)
	shopBadge.BorderSizePixel = 0
	shopBadge.ZIndex = 15
	shopBadge.Parent = shopBtn

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = shopBadge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	badgeStroke.Thickness = 1.5
	badgeStroke.Color = Color3.fromRGB(255, 255, 255)
	badgeStroke.Parent = shopBadge

	local badgeLabel = Instance.new("TextLabel")
	badgeLabel.Size = UDim2.fromScale(1, 1)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.Text = "!"
	badgeLabel.Font = Enum.Font.GothamBold
	badgeLabel.TextSize = 13
	badgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeLabel.ZIndex = 16
	badgeLabel.Parent = shopBadge

	local badgeTween = TweenService:Create(
		shopBadge,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = UDim2.fromOffset(25, 25) }
	)
	badgeTween:Play()

	-- Smooth Hover & Click Animations on Floating Icon
	local isShopHovered = false
	shopBtn.MouseEnter:Connect(function()
		isShopHovered = true
		TweenService:Create(shopScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.10 }):Play()
		TweenService:Create(shopBtn, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(255, 235, 255) }):Play()
	end)

	shopBtn.MouseLeave:Connect(function()
		isShopHovered = false
		TweenService:Create(shopScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
		TweenService:Create(shopBtn, TweenInfo.new(0.2), { ImageColor3 = Color3.fromRGB(255, 255, 255) }):Play()
	end)

	shopBtn.MouseButton1Down:Connect(function()
		TweenService:Create(shopScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.92 }):Play()
	end)

	shopBtn.MouseButton1Up:Connect(function()
		local target = isShopHovered and 1.10 or 1.0
		TweenService:Create(shopScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
	end)

	local function toggleShop()
		if facilityController and facilityController.Root and facilityController.Root.Visible and facilityController.Current == "Summoning" then
			facilityController:Close()
		else
			_G.OpenFacilityHUD("Summoning")
		end
	end
	_G.ToggleShop = toggleShop
	_G.OpenShop = toggleShop

	shopBtn.Activated:Connect(function()
		toggleShop()
	end)

	local modalWidths = { 1000 }
	local function layout()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local view = cam.ViewportSize
		local w, h = view.X, math.max(300, view.Y - 40)
		compact = w < 1100
		local portrait = w < 650
		local stackPanels = portrait or h < 540

		-- LeftSidebar responsive positioning & scaling
		leftSidebar.Position = portrait and UDim2.new(0, 8, 0.38, 0) or UDim2.new(0, 16, 0.40, 0)
		local sidebarScale = leftSidebar:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", leftSidebar)
		if h < 550 or portrait then
			sidebarScale.Scale = math.clamp(h / 650, 0.72, 1.0)
		else
			sidebarScale.Scale = 1.0
		end

		topBar.Visible = false
		honorLabel.Visible = false

		currencyCluster.AnchorPoint = Vector2.new(0, 1)
		currencyCluster.Position = UDim2.new(0, 16, 1, -18)
		local moneyScale = currencyCluster:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", currencyCluster)
		moneyScale.Scale = portrait and math.min(1, (w - 48) / 258) or 1

		bossBanner.Position = UDim2.new(0.5, 0, 0, 14)
		bossBanner.AnchorPoint = Vector2.new(0.5, 0)
		bossBanner.Size = UDim2.new(0, math.min(w - 32, 720), 0, 58)
		bossBanner.BackgroundColor3 = P.surface
		stroke(bossBanner, Color3.fromRGB(144, 103, 199))
		bossTitleLabel.TextSize = portrait and 12 or 15
		bossTitleLabel.TextScaled = false
		bossTitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
		novaCastLabel.TextSize = portrait and 10 or 12
		novaCastLabel.TextScaled = false

		toastBanner.AnchorPoint = Vector2.new(0.5, 0)
		toastBanner.Position = UDim2.new(0.5, 0, 0, 82)
		toastBanner.Size = UDim2.new(0, math.min(w - 32, 650), 0, 46)

		rightBoard.Position = UDim2.new(1, -16, 0, compact and 136 or 96)
		rightBoard.AnchorPoint = Vector2.new(1, 0)
		rightBoard.Size = UDim2.fromOffset(math.min(260, w - 32), 170)
		rightBoard.Visible = not compact or encounterOpen
		rightBoard.BackgroundColor3 = P.surface
		rightBoard.BackgroundTransparency = 0.08
		stroke(rightBoard)
		encounterToggle.Visible = compact
		encounterToggle.Position = UDim2.new(1, -136, 0, 16)

		-- Responsive positioning and scaling for Currencies and Floating Toolbar
		local isNarrow = w < 720
		currencyCluster.AnchorPoint = Vector2.new(0, 1)
		currencyCluster.Position = if isNarrow then UDim2.new(0, 14, 1, -100) else UDim2.new(0, 16, 1, -18)
		local moneyScale = currencyCluster:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", currencyCluster)
		moneyScale.Scale = portrait and math.min(1, (w - 48) / 258) or 1

		local menuScale = floatingMenuContainer:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", floatingMenuContainer)
		if w < 540 then
			menuScale.Scale = math.clamp((w - 32) / 380, 0.65, 0.85)
		elseif w < 850 then
			menuScale.Scale = 0.9
		else
			menuScale.Scale = 1.0
		end
	end

	task.defer(layout)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
			layout()
		end
	end)
end
