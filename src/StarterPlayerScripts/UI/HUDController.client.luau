--!strict
-- StarterPlayerScripts/UI/HUDController.client.luau
-- Complete Implementation of Document 4 UI/UX Wireframes:
-- 1. MasterHUDScreenGui (Main Tactical HUD + Clean Bottom Toolbar)
-- 2. WaitingRoomScreenGui (Tycoon, Facilities, Tech Tree, Gacha & Roster)
-- 3. ThePitScreenGui (Synthesis XP Fodder & 1->5 Star Promotion)
-- 4. MercenaryScreenGui (Noticeboard, Secret Directives & 50G Audit Soul Reveal)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
-- 2. MODAL WINDOWS (`WaitingRoom`, `ThePit`)
--============================================================================

local waitingRoomModal = makeFrame({
	Name = "WaitingRoomModal",
	Size = UDim2.new(0, 860, 0, 500),
	Position = UDim2.new(0.5, -430, 0.5, -240),
	BackgroundColor3 = Color3.fromRGB(18, 20, 32),
	Visible = false,
	Corner = 12,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(95, 165, 255),
	Parent = hudGui,
})

local pitModal = makeFrame({
	Name = "ThePitModal",
	Size = UDim2.new(0, 820, 0, 480),
	Position = UDim2.new(0.5, -410, 0.5, -230),
	BackgroundColor3 = Color3.fromRGB(26, 16, 24),
	Visible = false,
	Corner = 12,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(255, 105, 45),
	Parent = hudGui,
})

local refreshWaitingRoomModal: () -> ()
local refreshPitModal: () -> ()
local facilityController: any = nil
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
-- BOTTOM NAVIGATION & TOOL BAR (Gothic Obsidian & White Filigree Container)
--============================================================================
local SLATE_TEXT = Color3.fromRGB(232, 226, 245)
local SLATE_ACTIVE = Color3.fromRGB(230, 192, 112)
local DIVIDER_GRAY = Color3.fromRGB(112, 100, 132)

local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomToolbar"
bottomBar.Size = UDim2.new(1, -24, 0, 50)
bottomBar.Position = UDim2.new(0.5, 0, 1, -6)
bottomBar.AnchorPoint = Vector2.new(0.5, 1)
bottomBar.BackgroundColor3 = Color3.fromRGB(20, 14, 28)
bottomBar.BorderSizePixel = 0
bottomBar.ZIndex = 8
bottomBar.Parent = hudGui

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

local function makeBarTextButton(parent: Instance, name: string, label: string, width: number, onClick: () -> ()): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, width, 0, 36)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBold
	btn.Text = label
	btn.TextSize = 11
	btn.TextColor3 = SLATE_TEXT
	btn.ZIndex = 11
	btn.Parent = parent

	btn.MouseEnter:Connect(function()
		if btn:GetAttribute("IsActiveTab") ~= true then
			btn.TextColor3 = SLATE_ACTIVE
		end
	end)
	btn.MouseLeave:Connect(function()
		if btn:GetAttribute("IsActiveTab") ~= true then
			btn.TextColor3 = SLATE_TEXT
		end
	end)
	btn.Activated:Connect(onClick)
	return btn
end

local function makeBarIconButton(parent: Instance, name: string, onClick: () -> ()): (TextButton, Frame)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 30, 0, 30)
	btn.BackgroundTransparency = 1
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.ZIndex = 11
	btn.Parent = parent

	local iconCanvas = Instance.new("Frame")
	iconCanvas.Name = "IconCanvas"
	iconCanvas.Size = UDim2.fromOffset(18, 18)
	iconCanvas.Position = UDim2.fromScale(0.5, 0.5)
	iconCanvas.AnchorPoint = Vector2.new(0.5, 0.5)
	iconCanvas.BackgroundTransparency = 1
	iconCanvas.ZIndex = 11
	iconCanvas.Parent = btn

	local function tintIcon(col: Color3)
		for _, d in ipairs(iconCanvas:GetDescendants()) do
			if d:IsA("Frame") and d.Name ~= "Hole" then
				d.BackgroundColor3 = col
			end
			if d:IsA("UIStroke") then
				d.Color = col
			end
		end
	end

	btn.MouseEnter:Connect(function()
		tintIcon(SLATE_ACTIVE)
	end)
	btn.MouseLeave:Connect(function()
		tintIcon(SLATE_TEXT)
	end)
	btn.Activated:Connect(onClick)
	return btn, iconCanvas
end

local function addPart(parent: Instance, x: number, y: number, w: number, h: number, rot: number?, corner: number?): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(w, h)
	f.Position = UDim2.fromOffset(x, y)
	f.BackgroundColor3 = SLATE_TEXT
	f.BorderSizePixel = 0
	f.ZIndex = 11
	if rot then
		f.Rotation = rot
	end
	if corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, corner)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

-- Left: PATCH NOTES
local patchNotesBtn = makeBarTextButton(bottomBar, "PatchNotesButton", "PATCH NOTES", 100, function()
	showClientToast("INFINITE TOWER — Waiting Room, The Pit, World Boss & Tactical Whistles Active")
end)
patchNotesBtn.Position = UDim2.new(0, 26, 0.5, 0)
patchNotesBtn.AnchorPoint = Vector2.new(0, 0.5)
patchNotesBtn.TextXAlignment = Enum.TextXAlignment.Left

-- Center Group: 5 Infinite Tower Text Tabs | Divider | 4 Quick-Action Tool Icons
local centerGroup = Instance.new("Frame")
centerGroup.Name = "CenterToolbarGroup"
centerGroup.Size = UDim2.new(0, 692, 1, 0)
centerGroup.Position = UDim2.new(0.5, 0, 0, 0)
centerGroup.AnchorPoint = Vector2.new(0.5, 0)
centerGroup.BackgroundTransparency = 1
centerGroup.ZIndex = 11
centerGroup.Parent = bottomBar

local centerLayout = Instance.new("UIListLayout")
centerLayout.FillDirection = Enum.FillDirection.Horizontal
centerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
centerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
centerLayout.SortOrder = Enum.SortOrder.LayoutOrder
centerLayout.Padding = UDim.new(0, 18)
centerLayout.Parent = centerGroup

local wrTabBtn = makeBarTextButton(centerGroup, "Tab_WaitingRoom", "WAITING ROOM", 98, function()
	_G.OpenMasterModal(waitingRoomModal.Visible and "NONE" or "WAITING_ROOM")
end)
wrTabBtn.LayoutOrder = 1

local pitTabBtn = makeBarTextButton(centerGroup, "Tab_ThePit", "THE PIT", 62, function()
	_G.OpenMasterModal(pitModal.Visible and "NONE" or "THE_PIT")
end)
pitTabBtn.LayoutOrder = 2

local heroesTabBtn = makeBarTextButton(centerGroup, "Tab_Heroes", "HEROES", 62, function()
	_G.OpenMasterModal("WAITING_ROOM")
	AssignHeroRoleFunc:InvokeServer("AUTO_SWAP_EXHAUSTED", "")
end)
heroesTabBtn.LayoutOrder = 3

local qButton = makeBarTextButton(centerGroup, "OverdriveButton_Q", "OVERDRIVE", 88, function()
	LastQClock = os.clock()
	WhistleCommandRemote:FireServer(1)
end)
qButton.LayoutOrder = 4

local eButton = makeBarTextButton(centerGroup, "EmergencyRecallButton_E", "RECALL", 72, function()
	LastEClock = os.clock()
	WhistleCommandRemote:FireServer(2)
end)
eButton.LayoutOrder = 5

-- Vertical Divider
local centerDivider = Instance.new("Frame")
centerDivider.Name = "Divider"
centerDivider.Size = UDim2.fromOffset(1, 22)
centerDivider.BackgroundColor3 = DIVIDER_GRAY
centerDivider.BorderSizePixel = 0
centerDivider.LayoutOrder = 6
centerDivider.ZIndex = 11
centerDivider.Parent = centerGroup

-- Icon 1: Trash Can (Purge Conduit Rune)
local iconTrashBtn, trashCanvas = makeBarIconButton(centerGroup, "Tool_PurgeRune", function()
	PlotEspionageEvent:FireServer(4, 1, "ManaConduit")
	showClientToast("Purging Mana Conduit Rune...")
end)
iconTrashBtn.LayoutOrder = 7
do
	addPart(trashCanvas, 3, 2, 12, 2, 0, 1)
	addPart(trashCanvas, 7, 0, 4, 2, 0, 1)
	local bin = Instance.new("Frame")
	bin.Size = UDim2.fromOffset(10, 12)
	bin.Position = UDim2.fromOffset(4, 5)
	bin.BackgroundTransparency = 1
	bin.ZIndex = 11
	bin.Parent = trashCanvas
	local st = Instance.new("UIStroke")
	st.Thickness = 1.6
	st.Color = SLATE_TEXT
	st.Parent = bin
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 1)
	c.Parent = bin
	addPart(trashCanvas, 7, 7, 1, 7)
	addPart(trashCanvas, 10, 7, 1, 7)
end

-- Icon 2: 4-Way Move/Expand Arrows (Auto-Swap Exhausted Heroes)
local iconMoveBtn, moveCanvas = makeBarIconButton(centerGroup, "Tool_AutoSwap", function()
	AssignHeroRoleFunc:InvokeServer("AUTO_SWAP_EXHAUSTED", "")
	showClientToast("Swapped exhausted heroes with fresh bench heroes!")
end)
iconMoveBtn.LayoutOrder = 8
do
	addPart(moveCanvas, 2, 2, 5, 2)
	addPart(moveCanvas, 2, 2, 2, 5)
	addPart(moveCanvas, 11, 2, 5, 2)
	addPart(moveCanvas, 14, 2, 2, 5)
	addPart(moveCanvas, 2, 14, 5, 2)
	addPart(moveCanvas, 2, 11, 2, 5)
	addPart(moveCanvas, 11, 14, 5, 2)
	addPart(moveCanvas, 14, 11, 2, 5)
	addPart(moveCanvas, 3, 8, 12, 2, 45)
	addPart(moveCanvas, 3, 8, 12, 2, -45)
end

-- Icon 3: Paint Bucket / Collect Gems (Collect Mana Conduit)
local iconBucketBtn, bucketCanvas = makeBarIconButton(centerGroup, "Tool_CollectGems", function()
	FacilityInteractEvent:FireServer("COLLECT_CONDUIT")
	showClientToast("Collected Mana Conduit Gems!")
end)
iconBucketBtn.LayoutOrder = 9
do
	local body = addPart(bucketCanvas, 4, 5, 8, 8, 45, 1)
	body.ZIndex = 11
	addPart(bucketCanvas, 6, 2, 5, 2, -25, 1)
	addPart(bucketCanvas, 13, 12, 3, 4, 0, 2)
end

-- Icon 4: 3x3 Grid (Toggle Summon / Roster View)
local iconGridBtn, gridCanvas = makeBarIconButton(centerGroup, "Tool_RosterGrid", function()
	_G.OpenMasterModal(waitingRoomModal.Visible and "NONE" or "WAITING_ROOM")
end)
iconGridBtn.LayoutOrder = 10
do
	for row = 0, 2 do
		for col = 0, 2 do
			addPart(gridCanvas, 2 + col * 6, 2 + row * 6, 3, 3, 0, 1)
		end
	end
end

-- Right Group: Gear Icon + SAVE Button
local rightGroup = Instance.new("Frame")
rightGroup.Name = "RightToolbarGroup"
rightGroup.Size = UDim2.new(0, 110, 1, 0)
rightGroup.Position = UDim2.new(1, -26, 0, 0)
rightGroup.AnchorPoint = Vector2.new(1, 0)
rightGroup.BackgroundTransparency = 1
rightGroup.ZIndex = 11
rightGroup.Parent = bottomBar

local rightLayout = Instance.new("UIListLayout")
rightLayout.FillDirection = Enum.FillDirection.Horizontal
rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
rightLayout.Padding = UDim.new(0, 14)
rightLayout.Parent = rightGroup

local settingsBtn, gearCanvas = makeBarIconButton(rightGroup, "SettingsGearButton", function()
	rightBoard.Visible = not rightBoard.Visible
end)
settingsBtn.LayoutOrder = 1
do
	for deg = 0, 135, 45 do
		addPart(gearCanvas, 2, 7, 14, 4, deg, 1)
	end
	local ring = addPart(gearCanvas, 3, 3, 12, 12, 0, 6)
	ring.ZIndex = 11
	local hole = Instance.new("Frame")
	hole.Name = "Hole"
	hole.Size = UDim2.fromOffset(6, 6)
	hole.Position = UDim2.fromOffset(6, 6)
	hole.BackgroundColor3 = Color3.fromRGB(20, 14, 28)
	hole.BorderSizePixel = 0
	hole.ZIndex = 12
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(1, 0)
	hc.Parent = hole
	hole.Parent = gearCanvas
end

local saveBtn = makeBarTextButton(rightGroup, "SaveButton", "SAVE", 44, function()
	showClientToast("Profile synced & saved!")
end)
saveBtn.LayoutOrder = 2
saveBtn.TextXAlignment = Enum.TextXAlignment.Right

_G.TriggerHUDWhistleCooldown = function(which: string)
	if which == "Q" then
		LastQClock = os.clock()
	elseif which == "E" then
		LastEClock = os.clock()
	end
end

local function updateBottomTabHighlights()
	local wrActive = waitingRoomModal.Visible
	local pitActive = pitModal.Visible
	wrTabBtn:SetAttribute("IsActiveTab", wrActive)
	pitTabBtn:SetAttribute("IsActiveTab", pitActive)
	wrTabBtn.TextColor3 = wrActive and SLATE_ACTIVE or SLATE_TEXT
	pitTabBtn.TextColor3 = pitActive and SLATE_ACTIVE or SLATE_TEXT
end

_G.OpenMasterModal = function(which: string)
	if facilityController then facilityController:Close() end
	waitingRoomModal.Visible = (which == "WAITING_ROOM")
	pitModal.Visible = (which == "THE_PIT")
	blacksmithModal.Visible = (which == "BLACKSMITH")
	updateBottomTabHighlights()
	if which == "WAITING_ROOM" and refreshWaitingRoomModal then
		refreshWaitingRoomModal()
	elseif which == "THE_PIT" and refreshPitModal then
		refreshPitModal()
	elseif which == "BLACKSMITH" and refreshBlacksmithModal then
		refreshBlacksmithModal()
	end
end

-- Add Top Bar Navigation Buttons
makeButton({
	Size = UDim2.new(0, 118, 1, 0),
	BackgroundColor3 = Color3.fromRGB(45, 115, 205),
	Text = " Waiting Room",
	Corner = 6,
	OnClick = function()
		_G.OpenMasterModal(waitingRoomModal.Visible and "NONE" or "WAITING_ROOM")
	end,
	Parent = navButtonsFrame,
})
makeButton({
	Size = UDim2.new(0, 100, 1, 0),
	BackgroundColor3 = Color3.fromRGB(210, 85, 35),
	Text = " The Pit",
	Corner = 6,
	OnClick = function()
		_G.OpenMasterModal(pitModal.Visible and "NONE" or "THE_PIT")
	end,
	Parent = navButtonsFrame,
})
makeButton({
	Size = UDim2.new(0, 115, 1, 0),
	BackgroundColor3 = Color3.fromRGB(200, 115, 25),
	Text = "⚒️ Blacksmith",
	Corner = 6,
	OnClick = function()
		_G.OpenMasterModal(blacksmithModal.Visible and "NONE" or "BLACKSMITH")
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
-- 3. BUILD WAITING ROOM MODAL CONTENTS (Document 4 Section 2)
--============================================================================

makeLabel({
	Size = UDim2.new(0.75, 0, 0, 36),
	Position = UDim2.new(0.02, 0, 0, 6),
	Text = " THE WAITING ROOM",
	TextColor3 = Color3.fromRGB(115, 200, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = waitingRoomModal,
})
makeButton({
	Size = UDim2.new(0, 90, 0, 30),
	Position = UDim2.new(1, -100, 0, 9),
	BackgroundColor3 = Color3.fromRGB(185, 45, 60),
	Text = "X CLOSE",
	Corner = 6,
	OnClick = function()
		waitingRoomModal.Visible = false
		updateBottomTabHighlights()
	end,
	Parent = waitingRoomModal,
})

local wrLeftPane = makeFrame({
	Size = UDim2.new(0.47, 0, 1, -54),
	Position = UDim2.new(0.015, 0, 0, 46),
	BackgroundColor3 = Color3.fromRGB(24, 27, 42),
	Corner = 8,
	Parent = waitingRoomModal,
})

local wrRightPane = makeFrame({
	Size = UDim2.new(0.485, 0, 1, -54),
	Position = UDim2.new(0.50, 0, 0, 46),
	BackgroundColor3 = Color3.fromRGB(24, 27, 42),
	Corner = 8,
	Parent = waitingRoomModal,
})

-- Left Pane Controls: Auto-Swap, Mana Conduit & Infirmary
makeButton({
	Size = UDim2.new(0.94, 0, 0, 32),
	Position = UDim2.new(0.03, 0, 0, 8),
	BackgroundColor3 = Color3.fromRGB(45, 165, 110),
	Text = " REST EXHAUSTED & DEPLOY FRESH HEROES",
	Corner = 6,
	OnClick = function()
		AssignHeroRoleFunc:InvokeServer("AUTO_SWAP_EXHAUSTED", "")
	end,
	Parent = wrLeftPane,
})

local conduitSummaryLbl = makeLabel({
	Size = UDim2.new(0.94, 0, 0, 42),
	Position = UDim2.new(0.03, 0, 0, 46),
	Text = "1. MANA CONDUIT [Lv.1] — Gem Chest: 0 / 150",
	TextColor3 = Color3.fromRGB(95, 215, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = wrLeftPane,
})

makeButton({
	Size = UDim2.new(0.30, 0, 0, 28),
	Position = UDim2.new(0.03, 0, 0, 90),
	BackgroundColor3 = Color3.fromRGB(35, 145, 205),
	Text = " COLLECT GEMS",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("COLLECT_CONDUIT")
	end,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.30, 0, 0, 28),
	Position = UDim2.new(0.35, 0, 0, 90),
	BackgroundColor3 = Color3.fromRGB(65, 115, 185),
	Text = " UPGRADE MANA",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("UPGRADE_FACILITY", "ManaConduit")
	end,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.30, 0, 0, 28),
	Position = UDim2.new(0.67, 0, 0, 90),
	BackgroundColor3 = Color3.fromRGB(205, 115, 30),
	Text = " PURGE RUNE (15s)",
	Corner = 6,
	OnClick = function()
		PlotEspionageEvent:FireServer(4, 1, "ManaConduit")
	end,
	Parent = wrLeftPane,
})

-- Mimic Chest & Espionage Row
makeButton({
	Size = UDim2.new(0.30, 0, 0, 26),
	Position = UDim2.new(0.03, 0, 0, 122),
	BackgroundColor3 = Color3.fromRGB(145, 95, 35),
	Text = " MIMIC CHEST",
	Corner = 5,
	OnClick = function()
		PlotEspionageEvent:FireServer(5, 1, "FOOLS_GOLD")
	end,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.30, 0, 0, 26),
	Position = UDim2.new(0.35, 0, 0, 122),
	BackgroundColor3 = Color3.fromRGB(55, 155, 95),
	Text = " Bless (+25 Gems)",
	Corner = 5,
	OnClick = function()
		PlotEspionageEvent:FireServer(2, 1, "ManaConduit")
	end,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.30, 0, 0, 26),
	Position = UDim2.new(0.67, 0, 0, 122),
	BackgroundColor3 = Color3.fromRGB(165, 40, 85),
	Text = " Plant Leech (-20%)",
	Corner = 5,
	OnClick = function()
		PlotEspionageEvent:FireServer(3, 1, "ManaConduit")
	end,
	Parent = wrLeftPane,
})

-- Infirmary Section
local infirmarySummaryLbl = makeLabel({
	Size = UDim2.new(0.62, 0, 0, 42),
	Position = UDim2.new(0.03, 0, 0, 156),
	Text = "2. THE INFIRMARY & BARRACKS [Lv.1]",
	TextColor3 = Color3.fromRGB(95, 245, 150),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.30, 0, 0, 32),
	Position = UDim2.new(0.67, 0, 0, 160),
	BackgroundColor3 = Color3.fromRGB(45, 155, 95),
	Text = " UPGRADE",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("UPGRADE_FACILITY", "Infirmary")
	end,
	Parent = wrLeftPane,
})

makeButton({
	Size = UDim2.new(0.94, 0, 0, 32),
	Position = UDim2.new(0.03, 0, 0, 206),
	BackgroundColor3 = Color3.fromRGB(30, 145, 175),
	Text = " SUMMON RIFT WARDEN AT RING 3 (Uses 1x Rift Lure)",
	Corner = 6,
	OnClick = function()
		WorldBossTriggerRemote:FireServer("USE_RIFT_LURE")
	end,
	Parent = wrLeftPane,
})

-- Right Pane: Summoning Altar Buttons + Scrollable Hero Roster
makeButton({
	Size = UDim2.new(0.46, 0, 0, 34),
	Position = UDim2.new(0.02, 0, 0, 8),
	BackgroundColor3 = Color3.fromRGB(135, 55, 225),
	Text = " SUMMON 1x (100 Gems)",
	Corner = 6,
	OnClick = function()
		RequestSummonFunc:InvokeServer(1)
	end,
	Parent = wrRightPane,
})
makeButton({
	Size = UDim2.new(0.46, 0, 0, 34),
	Position = UDim2.new(0.52, 0, 0, 8),
	BackgroundColor3 = Color3.fromRGB(185, 65, 245),
	Text = " SUMMON 10x (900 Gems)",
	Corner = 6,
	OnClick = function()
		RequestSummonFunc:InvokeServer(10)
	end,
	Parent = wrRightPane,
})

local rosterScroll = Instance.new("ScrollingFrame")
rosterScroll.Size = UDim2.new(0.96, 0, 1, -54)
rosterScroll.Position = UDim2.new(0.02, 0, 0, 48)
rosterScroll.BackgroundTransparency = 1
rosterScroll.ScrollBarThickness = 6
rosterScroll.Parent = wrRightPane

local rosterLayout = Instance.new("UIListLayout")
rosterLayout.Padding = UDim.new(0, 6)
rosterLayout.Parent = rosterScroll

refreshWaitingRoomModal = function()
	if not CurrentProfile then
		return
	end
	local c = CurrentProfile.Facilities.ManaConduit
	local inf = CurrentProfile.Facilities.Infirmary

	conduitSummaryLbl.Text = string.format(
		"1. MANA CONDUIT [Lv.%d] — Chest: %d Gems | Workers: %d | Mimic: %s",
		c.Level, math.floor(c.UncollectedOutput), #c.AssignedHeroUUIDs, CurrentProfile.Social.MimicIllusionMode
	)
	infirmarySummaryLbl.Text = string.format(
		"2. THE INFIRMARY [Lv.%d] — Healers: %d (Recovers Stamina & Clears Coma)",
		inf.Level, #inf.AssignedHeroUUIDs
	)

	for _, child in ipairs(rosterScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local heroList = {}
	for _, h in pairs(CurrentProfile.Heroes) do
		table.insert(heroList, h)
	end
	table.sort(heroList, function(a, b)
		if a.Stars ~= b.Stars then
			return a.Stars > b.Stars
		end
		return a.Level > b.Level
	end)

	for _, h in ipairs(heroList) do
		local row = makeFrame({
			Size = UDim2.new(1, -8, 0, 58),
			BackgroundColor3 = Color3.fromRGB(32, 36, 54),
			Corner = 6,
			Parent = rosterScroll,
		})
		local _, effHP, dps = StatFormulas.GetEffectiveCombatStats(h, false, false)
		local labor = StatFormulas.GetEffectiveLabor(h, nil)
		local stars = string.rep("", h.Stars)
		makeLabel({
			Size = UDim2.new(0.48, 0, 0.9, 0),
			Position = UDim2.new(0.02, 0, 0.05, 0),
			Text = string.format("%s %s Lv.%d (%s)\nHP:%d | DPS:%.0f | Lab:%.1f/m | [%s]", h.DisplayName, stars, h.Level, h.Archetype, effHP, dps, labor, h.Assignment),
			TextColor3 = Color3.fromRGB(240, 240, 255),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		local uuid = h.UUID
		makeButton({
			Size = UDim2.new(0.15, 0, 0.72, 0),
			Position = UDim2.new(0.51, 0, 0.14, 0),
			BackgroundColor3 = Color3.fromRGB(45, 145, 215),
			Text = "Squad",
			Corner = 4,
			OnClick = function()
				AssignHeroRoleFunc:InvokeServer(uuid, "SQUAD_AUTO")
			end,
			Parent = row,
		})
		makeButton({
			Size = UDim2.new(0.15, 0, 0.72, 0),
			Position = UDim2.new(0.67, 0, 0.14, 0),
			BackgroundColor3 = Color3.fromRGB(40, 165, 195),
			Text = "Mana",
			Corner = 4,
			OnClick = function()
				AssignHeroRoleFunc:InvokeServer(uuid, "FACILITY_CONDUIT")
			end,
			Parent = row,
		})
		makeButton({
			Size = UDim2.new(0.15, 0, 0.72, 0),
			Position = UDim2.new(0.83, 0, 0.14, 0),
			BackgroundColor3 = Color3.fromRGB(95, 100, 120),
			Text = "Bench",
			Corner = 4,
			OnClick = function()
				AssignHeroRoleFunc:InvokeServer(uuid, "BENCHED")
			end,
			Parent = row,
		})
	end
	rosterScroll.CanvasSize = UDim2.new(0, 0, 0, #heroList * 64)
end

--============================================================================
-- 4. THE PIT: modular recipient / donor workspace and authoritative transactions.
--============================================================================
local PitController = require(script.Parent:WaitForChild("PitController"))
local pitController = PitController.new(
	pitModal,
	TycoonRemotes:WaitForChild("PitRequest") :: RemoteFunction,
	FacilityInteractEvent,
	function() _G.OpenMasterModal("NONE") end
)
_G.PitController = pitController
refreshPitModal = function() pitController:Refresh() end
local FacilityController = require(script.Parent:WaitForChild("FacilityController"))
facilityController = FacilityController.new(hudGui, function() return CurrentProfile end, TycoonRemotes)
_G.OpenFacilityHUD = function(facility: string)
	if facility == "Synthesis" or facility == "Promotion" then
		_G.OpenMasterModal("THE_PIT")
		pitController:SetTab(facility)
	else
		_G.OpenMasterModal("NONE")
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
	facilityController:Refresh()

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

	if waitingRoomModal.Visible and refreshWaitingRoomModal then
		refreshWaitingRoomModal()
	end
	pitController:ProfileChanged(profile)
	if blacksmithModal.Visible and refreshBlacksmithModal then
		refreshBlacksmithModal()
	end
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local cs = _G.ClientCombatState

	-- 1. Check Whistle Cooldowns & [E] Recall Skill-Check Assist Pulse (t = 1.1s..2.8s of Devouring Nova)
	local qRem = math.max(0, 20.0 - (now - LastQClock))
	if qRem > 0 then
		qButton.Text = string.format("OVERDRIVE (%.0fs)", qRem)
	else
		qButton.Text = "OVERDRIVE"
	end

	local eRem = math.max(0, 6.0 - (now - LastEClock))
	local novaElapsed = (cs and cs.NovaCastStartClock > 0) and (now - cs.NovaCastStartClock) or 999
	local inNovaOptimalWindow = (novaElapsed >= 1.1 and novaElapsed <= 2.8)

	if inNovaOptimalWindow then
		eButton.TextColor3 = SLATE_ACTIVE
		eButton.Text = "RECALL [E]!"
	elseif eRem > 0 then
		eButton.Text = string.format("RECALL (%.0fs)", eRem)
	else
		eButton.Text = "RECALL"
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

	local modalList = { waitingRoomModal, pitModal }
	for _, m in modalList do
		m.AnchorPoint = Vector2.new(0.5, 0.5)
		m.Position = UDim2.fromScale(0.5, 0.5)
		m.ZIndex = 20
		if m == waitingRoomModal then
			m.BackgroundColor3 = P.surface
			m.BackgroundTransparency = 0.02
			stroke(m, P.gold)
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(Color3.fromRGB(25, 36, 56), P.surface)
			g.Rotation = 100
			g.Parent = m
		end
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

	-- Apply Gothic Obsidian & White Filigree Container Design to the Bottom Menu Bar
	applyGothicBoxStyle(bottomBar, true, 8)

	-- Remove top menu bar so the viewport top is unobstructed and currencies live in the bottom-left
	topBar.Visible = false
	currencyLabel.Visible = false
	honorLabel.Visible = false

	carriedLootPill.Parent = hudGui
	carriedLootPill.AnchorPoint = Vector2.new(0, 1)
	carriedLootPill.Position = UDim2.new(0, 14, 1, -120)
	carriedLootPill.ZIndex = 8

	-- Bottom-left Gold & Diamond Currency Containers (above PATCH NOTES) using Gothic Box Design
	local currencyCluster = Instance.new("Frame")
	currencyCluster.Name = "CurrencyCluster"
	currencyCluster.BackgroundTransparency = 1
	currencyCluster.Size = UDim2.fromOffset(258, 44)
	currencyCluster.AnchorPoint = Vector2.new(0, 1)
	currencyCluster.Position = UDim2.new(0, 14, 1, -64)
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

	local wrScroll = Instance.new("ScrollingFrame")
	wrScroll.Name = "WaitingRoomContent"
	wrScroll.BackgroundTransparency = 1
	wrScroll.BorderSizePixel = 0
	wrScroll.ScrollBarThickness = 4
	wrScroll.ScrollBarImageColor3 = P.gold
	wrScroll.Parent = waitingRoomModal
	wrLeftPane.Parent = wrScroll
	wrRightPane.Parent = wrScroll

	for _, list in { rosterScroll } do
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.fromOffset(0, 0)
		list.ScrollBarImageColor3 = P.gold
	end

	local function rowStyle(o: Instance)
		if not o:IsA("Frame") then
			return
		end
		o.BackgroundColor3 = Color3.fromRGB(23, 33, 51)
		stroke(o)
		if o.Parent == rosterScroll then
			o.Size = UDim2.new(1, -10, 0, compact and 86 or 72)
		end
		for _, v in o:GetDescendants() do
			if v:IsA("TextLabel") then
				v.TextWrapped = true
				v.TextScaled = false
				v.TextSize = compact and 12 or 14
			end
		end
	end
	for _, list in { rosterScroll } do
		list.ChildAdded:Connect(function(o)
			task.defer(rowStyle, o)
		end)
	end

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

		topBar.Visible = false
		honorLabel.Visible = false

		currencyCluster.AnchorPoint = Vector2.new(0, 1)
		currencyCluster.Position = UDim2.new(0, 14, 1, -64)
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

		-- Responsive scaling for the BottomToolbar on smaller screens
		patchNotesBtn.Visible = w >= 720
		local centerScale = centerGroup:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", centerGroup)
		if w < 720 then
			centerScale.Scale = math.clamp((w - 130) / 740, 0.55, 1)
			centerGroup.Position = UDim2.new(0, 12, 0, 0)
			centerGroup.AnchorPoint = Vector2.new(0, 0)
		elseif w < 1040 then
			centerScale.Scale = math.clamp((w - 280) / 740, 0.72, 1)
			centerGroup.Position = UDim2.new(0.5, 0, 0, 0)
			centerGroup.AnchorPoint = Vector2.new(0.5, 0)
		else
			centerScale.Scale = 1
			centerGroup.Position = UDim2.new(0.5, 0, 0, 0)
			centerGroup.AnchorPoint = Vector2.new(0.5, 0)
		end

		waitingRoomModal.Size = UDim2.fromOffset(math.min(w - 24, modalWidths[1]), math.min(h - 70, 560))
		wrScroll.Position = UDim2.fromOffset(12, 48)
		wrScroll.Size = UDim2.new(1, -24, 1, -62)
		if stackPanels then
			wrScroll.CanvasSize = UDim2.fromOffset(0, 810)
			wrLeftPane.Position = UDim2.fromOffset(0, 0)
			wrLeftPane.Size = UDim2.new(1, -10, 0, 410)
			wrRightPane.Position = UDim2.fromOffset(0, 430)
			wrRightPane.Size = UDim2.new(1, -10, 0, 350)
		else
			wrScroll.CanvasSize = UDim2.fromOffset(0, 0)
			wrLeftPane.Position = UDim2.fromScale(0, 0)
			wrLeftPane.Size = UDim2.new(0.48, 0, 1, 0)
			wrRightPane.Position = UDim2.fromScale(0.5, 0)
			wrRightPane.Size = UDim2.new(0.5, -10, 1, 0)
		end

		-- The Pit composes its own columns and phone steps from these bounds.
		pitModal.Size = UDim2.fromOffset(math.min(w - 20, 1340), math.max(360, math.min(h - 76, 850)))

		for _, list in { rosterScroll } do
			for _, o in list:GetChildren() do
				rowStyle(o)
			end
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
