--!strict
-- StarterPlayerScripts/UI/HUDController.client.luau
-- Complete Implementation of Document 4 UI/UX Wireframes:
-- 1. MasterHUDScreenGui (Main Tactical HUD)
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

local RequestSummonFunc = TycoonRemotes:WaitForChild("RequestSummon") :: RemoteFunction
local SynthesizeHeroesFunc = TycoonRemotes:WaitForChild("SynthesizeHeroes") :: RemoteFunction
local PromoteHeroStarFunc = TycoonRemotes:WaitForChild("PromoteHeroStar") :: RemoteFunction
local AssignHeroRoleFunc = TycoonRemotes:WaitForChild("AssignHeroRole") :: RemoteFunction
local FacilityInteractEvent = TycoonRemotes:WaitForChild("FacilityInteract") :: RemoteEvent

local PlotEspionageEvent = SyndicateRemotes:WaitForChild("PlotEspionage") :: RemoteEvent
local ProfileDeltaSyncEvent = SyndicateRemotes:WaitForChild("ProfileDeltaSync") :: RemoteEvent
local SystemToastEvent = SyndicateRemotes:WaitForChild("SystemToast") :: RemoteEvent

local CurrentProfile: any = nil
local SelectedPitTargetUUID: string? = nil
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
		s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Thickness = props.Stroke
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
		if k ~= "Parent" then
			(l :: any)[k] = v
		end
	end
	l.TextWrapped = true
 local cap = Instance.new("UITextSizeConstraint");cap.MinTextSize=10;cap.MaxTextSize=18;cap.Parent=l
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
		s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; s.Thickness = props.Stroke
		s.Color = props.StrokeColor or Color3.fromRGB(255, 255, 255)
		s.Parent = b
	end
	if props.OnClick then
		b.Activated:Connect(props.OnClick)
	end
	local base=b.BackgroundColor3
 b.BackgroundColor3=Color3.fromRGB(20,29,46):Lerp(base,.22)
 b.TextColor3=Color3.fromRGB(225,229,237)
 local st=b:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke");st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Color=base:Lerp(Color3.fromRGB(103,125,154),.65);st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Thickness=1;st.Parent=b
 local cap=Instance.new("UITextSizeConstraint");cap.MinTextSize=10;cap.MaxTextSize=16;cap.Parent=b
 b.Parent = props.Parent
 return b
end

--============================================================================
-- 1. MAIN MASTER HUD (`MasterHUDScreenGui`)
--============================================================================

local oldHud = PlayerGui:FindFirstChild("MasterHUDScreenGui")
if oldHud then oldHud:Destroy() end

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
	Text = " GOLD: 500    GEMS: 300    RP: 0",
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
	Position = UDim2.new(0.5, -280, 1, -195),
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

CarriedLootSyncRemote.OnClientEvent:Connect(function(gold: number, gems: number, rp: number)
	if gold > 0 or gems > 0 or rp > 0 then
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

-- Bottom Action Dock (Relic Carry Banner + 5 Squad Slots + [Q] Overdrive & [E] Recall Whistles)
local bottomDock = makeFrame({
	Name = "BottomActionDock",
	Size = UDim2.new(0, 780, 0, 130),
	Position = UDim2.new(0.5, -390, 1, -140),
	BackgroundTransparency = 1,
	Parent = hudGui,
})

local relicCarryBanner = makeFrame({
	Name = "RelicCarryContextBanner",
	Size = UDim2.new(0, 480, 0, 42),
	Position = UDim2.new(0.5, -240, 0, 0),
	BackgroundColor3 = Color3.fromRGB(95, 15, 30),
	Visible = false,
	Corner = 8,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(255, 65, 85),
	Parent = bottomDock,
})

local relicCarryText = makeLabel({
	Size = UDim2.new(1, -16, 0.86, 0),
	Position = UDim2.new(0.02, 0, 0.07, 0),
	Text = " CARRYING RELIC!",
	TextColor3 = Color3.fromRGB(255, 225, 115),
	Parent = relicCarryBanner,
})

relicCarryText.Size = UDim2.new(1, -126, 1, -8)
relicCarryText.Position = UDim2.fromOffset(8, 4)
local dropCarriedButton = makeButton({
	Name = "DropCarriedItemButton",
	Text = "[R] DROP",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Size = UDim2.fromOffset(104, 36),
	BackgroundColor3 = Color3.fromRGB(170, 65, 70),
	Corner = 6,
	OnClick = function() DropCarriedItemRemote:FireServer() end,
	Parent = relicCarryBanner,
})

local squadStrip = makeFrame({
	Name = "DeployedSquadStrip",
	Size = UDim2.new(0, 540, 0, 80),
	Position = UDim2.new(0, 0, 0, 48),
	BackgroundTransparency = 1,
	Parent = bottomDock,
})
local squadLayout = Instance.new("UIListLayout")
squadLayout.FillDirection = Enum.FillDirection.Horizontal
squadLayout.Padding = UDim.new(0, 8)
squadLayout.Parent = squadStrip

local SquadSlotCards: { { Frame: Frame, Title: TextLabel, HPFill: Frame, StamFill: Frame, State: TextLabel } } = {}
for i = 1, 5 do
	local card = makeFrame({
		Name = "SquadSlot_" .. i,
		Size = UDim2.new(0, 101, 1, 0),
		BackgroundColor3 = Color3.fromRGB(20, 22, 34),
		BackgroundTransparency = 0.1,
		Corner = 8,
		Stroke = 1.5,
		StrokeColor = Color3.fromRGB(75, 85, 120),
		Parent = squadStrip,
	})
	local t = makeLabel({
		Size = UDim2.new(1, -6, 0, 22),
		Position = UDim2.new(0, 3, 0, 3),
		Text = i .. ". [EMPTY]",
		TextColor3 = Color3.fromRGB(255, 220, 95),
		Parent = card,
	})
	local hpBg = makeFrame({
		Size = UDim2.new(0.88, 0, 0, 10),
		Position = UDim2.new(0.06, 0, 0, 28),
		BackgroundColor3 = Color3.fromRGB(45, 45, 55),
		Corner = 3,
		Parent = card,
	})
	local hpFill = makeFrame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(65, 235, 115),
		Corner = 3,
		Parent = hpBg,
	})
	local stBg = makeFrame({
		Size = UDim2.new(0.88, 0, 0, 10),
		Position = UDim2.new(0.06, 0, 0, 42),
		BackgroundColor3 = Color3.fromRGB(45, 45, 55),
		Corner = 3,
		Parent = card,
	})
	local stFill = makeFrame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 205, 50),
		Corner = 3,
		Parent = stBg,
	})
	local stText = makeLabel({
		Size = UDim2.new(1, -6, 0, 20),
		Position = UDim2.new(0, 3, 0, 56),
		Text = "BENCHED",
		TextColor3 = Color3.fromRGB(185, 195, 215),
		Parent = card,
	})
	table.insert(SquadSlotCards, {
		Frame = card,
		Title = t,
		HPFill = hpFill,
		StamFill = stFill,
		State = stText,
	})
end

-- Whistle Buttons ([Q] Overdrive & [E] Emergency Recall)
local qButton = makeButton({
	Name = "OverdriveButton_Q",
	Size = UDim2.new(0, 110, 0, 80),
	Position = UDim2.new(0, 550, 0, 48),
	BackgroundColor3 = Color3.fromRGB(205, 115, 25),
	Text = "[Q] OVERDRIVE\n+40% speed · 5s",
	Corner = 10,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(255, 200, 80),
	OnClick = function()
		LastQClock = os.clock()
		WhistleCommandRemote:FireServer(1)
	end,
	Parent = bottomDock,
})

local eButton = makeButton({
	Name = "EmergencyRecallButton_E",
	Size = UDim2.new(0, 110, 0, 80),
	Position = UDim2.new(0, 668, 0, 48),
	BackgroundColor3 = Color3.fromRGB(25, 150, 195),
	Text = "[E] RECALL\nReturn to safety",
	Corner = 10,
	Stroke = 2,
	StrokeColor = Color3.fromRGB(95, 245, 255),
	OnClick = function()
		LastEClock = os.clock()
		WhistleCommandRemote:FireServer(2)
	end,
	Parent = bottomDock,
})

_G.TriggerHUDWhistleCooldown = function(which: string)
	if which == "Q" then
		LastQClock = os.clock()
	elseif which == "E" then
		LastEClock = os.clock()
	end
end

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

_G.OpenMasterModal = function(which: string)
	waitingRoomModal.Visible = (which == "WAITING_ROOM")
	pitModal.Visible = (which == "THE_PIT")
	if which == "WAITING_ROOM" and refreshWaitingRoomModal then
		refreshWaitingRoomModal()
	elseif which == "THE_PIT" and refreshPitModal then
		refreshPitModal()
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

-- Left Pane Controls: Auto-Swap, Mana Conduit, Infirmary, Dimensional Lab & Tech Tree
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

-- Dimensional Lab & Tech Tree Section
local labSummaryLbl = makeLabel({
	Size = UDim2.new(0.94, 0, 0, 40),
	Position = UDim2.new(0.03, 0, 0, 204),
	Text = "3. THE DIMENSIONAL LAB [Lv.1] — RP Buffer: 0 / 100",
	TextColor3 = Color3.fromRGB(215, 135, 255),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.45, 0, 0, 28),
	Position = UDim2.new(0.03, 0, 0, 246),
	BackgroundColor3 = Color3.fromRGB(135, 65, 205),
	Text = " COLLECT RP",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("COLLECT_LAB")
	end,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.45, 0, 0, 28),
	Position = UDim2.new(0.52, 0, 0, 246),
	BackgroundColor3 = Color3.fromRGB(115, 55, 175),
	Text = " UPGRADE LAB",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("UPGRADE_FACILITY", "DimensionalLab")
	end,
	Parent = wrLeftPane,
})

-- Tech Tree Unlock Buttons
makeButton({
	Size = UDim2.new(0.45, 0, 0, 34),
	Position = UDim2.new(0.03, 0, 0, 282),
	BackgroundColor3 = Color3.fromRGB(50, 110, 175),
	Text = " 4th Squad Slot\n(65 RP + 1,200G)",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("UNLOCK_TECH", "tech_squad_slot_4")
	end,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.45, 0, 0, 34),
	Position = UDim2.new(0.52, 0, 0, 282),
	BackgroundColor3 = Color3.fromRGB(155, 60, 215),
	Text = " Ring 2 Barrier Key\n(180 RP + 3,500G)",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("UNLOCK_TECH", "tech_ring2_barrier")
	end,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.45, 0, 0, 34),
	Position = UDim2.new(0.03, 0, 0, 322),
	BackgroundColor3 = Color3.fromRGB(50, 110, 175),
	Text = " 5th Squad Slot\n(420 RP + 12,000G)",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("UNLOCK_TECH", "tech_squad_slot_5")
	end,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.45, 0, 0, 34),
	Position = UDim2.new(0.52, 0, 0, 322),
	BackgroundColor3 = Color3.fromRGB(35, 165, 195),
	Text = " Craft Rift Lure\n(300 RP + 5,000G)",
	Corner = 6,
	OnClick = function()
		FacilityInteractEvent:FireServer("UNLOCK_TECH", "craft_rift_lure")
	end,
	Parent = wrLeftPane,
})
makeButton({
	Size = UDim2.new(0.94, 0, 0, 32),
	Position = UDim2.new(0.03, 0, 0, 364),
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
	local lab = CurrentProfile.Facilities.DimensionalLab

	conduitSummaryLbl.Text = string.format(
		"1. MANA CONDUIT [Lv.%d] — Chest: %d Gems | Workers: %d | Mimic: %s",
		c.Level, math.floor(c.UncollectedOutput), #c.AssignedHeroUUIDs, CurrentProfile.Social.MimicIllusionMode
	)
	infirmarySummaryLbl.Text = string.format(
		"2. THE INFIRMARY [Lv.%d] — Healers: %d (Recovers Stamina & Clears Coma)",
		inf.Level, #inf.AssignedHeroUUIDs
	)
	labSummaryLbl.Text = string.format(
		"3. DIMENSIONAL LAB [Lv.%d] — RP Buffer: %d RP | Scholars: %d",
		lab.Level, math.floor(lab.UncollectedOutput), #lab.AssignedHeroUUIDs
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
			Size = UDim2.new(0.11, 0, 0.72, 0),
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
			Size = UDim2.new(0.11, 0, 0.72, 0),
			Position = UDim2.new(0.63, 0, 0.14, 0),
			BackgroundColor3 = Color3.fromRGB(40, 165, 195),
			Text = "Mana",
			Corner = 4,
			OnClick = function()
				AssignHeroRoleFunc:InvokeServer(uuid, "FACILITY_CONDUIT")
			end,
			Parent = row,
		})
		makeButton({
			Size = UDim2.new(0.11, 0, 0.72, 0),
			Position = UDim2.new(0.75, 0, 0.14, 0),
			BackgroundColor3 = Color3.fromRGB(145, 70, 215),
			Text = "Lab",
			Corner = 4,
			OnClick = function()
				AssignHeroRoleFunc:InvokeServer(uuid, "FACILITY_LAB")
			end,
			Parent = row,
		})
		makeButton({
			Size = UDim2.new(0.11, 0, 0.72, 0),
			Position = UDim2.new(0.87, 0, 0.14, 0),
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
-- 4. BUILD THE PIT MODAL (SYNTHESIS XP & STAR PROMOTION 1 -> 5)
--============================================================================

makeLabel({
	Size = UDim2.new(0.75, 0, 0, 36),
	Position = UDim2.new(0.02, 0, 0, 6),
	Text = " THE PIT — HERO SYNTHESIS (XP FODDER) & STAR PROMOTION (1 -> 5)",
	TextColor3 = Color3.fromRGB(255, 145, 75),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = pitModal,
})
makeButton({
	Size = UDim2.new(0, 90, 0, 30),
	Position = UDim2.new(1, -100, 0, 9),
	BackgroundColor3 = Color3.fromRGB(185, 45, 60),
	Text = "X CLOSE",
	Corner = 6,
	OnClick = function()
		pitModal.Visible = false
	end,
	Parent = pitModal,
})

local pitTargetLabel = makeLabel({
	Size = UDim2.new(0.45, 0, 0, 160),
	Position = UDim2.new(0.02, 0, 0, 52),
	Text = "Select a Target Hero from the list on the right ->",
	TextColor3 = Color3.fromRGB(255, 225, 140),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = pitModal,
})

makeButton({
	Size = UDim2.new(0.45, 0, 0, 44),
	Position = UDim2.new(0.02, 0, 0, 230),
	BackgroundColor3 = Color3.fromRGB(215, 85, 30),
	Text = " FEED UNLOCKED 1 BENCHED FODDER (SYNTHESIS XP)",
	Corner = 8,
	OnClick = function()
		if not CurrentProfile or not SelectedPitTargetUUID then
			return
		end
		local fodders = {}
		for uuid, h in pairs(CurrentProfile.Heroes) do
			if uuid ~= SelectedPitTargetUUID and h.Assignment == "BENCHED" and not h.Locked and h.Stars == 1 then
				table.insert(fodders, uuid)
				if #fodders >= 10 then
					break
				end
			end
		end
		SynthesizeHeroesFunc:InvokeServer(SelectedPitTargetUUID, fodders)
	end,
	Parent = pitModal,
})

makeButton({
	Size = UDim2.new(0.45, 0, 0, 48),
	Position = UDim2.new(0.02, 0, 0, 290),
	BackgroundColor3 = Color3.fromRGB(215, 160, 25),
	Text = " ASCEND STAR TIER (PROMOTE 1 -> 5)",
	Corner = 8,
	OnClick = function()
		if not CurrentProfile or not SelectedPitTargetUUID then
			return
		end
		local target = CurrentProfile.Heroes[SelectedPitTargetUUID]
		if not target then
			return
		end
		local reqStars = target.Stars
		local fodders = {}
		for uuid, h in pairs(CurrentProfile.Heroes) do
			if uuid ~= SelectedPitTargetUUID and h.Assignment == "BENCHED" and not h.Locked and h.Stars == reqStars then
				table.insert(fodders, uuid)
				if #fodders >= reqStars then
					break
				end
			end
		end
		PromoteHeroStarFunc:InvokeServer(SelectedPitTargetUUID, fodders)
	end,
	Parent = pitModal,
})

local pitRosterScroll = Instance.new("ScrollingFrame")
pitRosterScroll.Size = UDim2.new(0.48, 0, 1, -60)
pitRosterScroll.Position = UDim2.new(0.50, 0, 0, 50)
pitRosterScroll.BackgroundTransparency = 1
pitRosterScroll.ScrollBarThickness = 6
pitRosterScroll.Parent = pitModal

local pitRosterLayout = Instance.new("UIListLayout")
pitRosterLayout.Padding = UDim.new(0, 6)
pitRosterLayout.Parent = pitRosterScroll

refreshPitModal = function()
	if not CurrentProfile then
		return
	end
	if not SelectedPitTargetUUID or not CurrentProfile.Heroes[SelectedPitTargetUUID] then
		for uuid, _ in pairs(CurrentProfile.Heroes) do
			SelectedPitTargetUUID = uuid
			break
		end
	end

	local target = SelectedPitTargetUUID and CurrentProfile.Heroes[SelectedPitTargetUUID] or nil
	if target then
		local maxLv = target.Stars * 10
		local reqXP = StatFormulas.GetXPRequiredForNextLevel(target.Level)
		local promoGold = StatFormulas.GetPromotionGoldCost(target.Stars)
		local effATK, effHP, dps = StatFormulas.GetEffectiveCombatStats(target, false, false)
		pitTargetLabel.Text = string.format(
			"TARGET IN CAULDRON: %s (%d)\nLevel: %d / %d (XP: %d / %d)\nEffective HP: %d | ATK: %d | DPS: %.1f\n\nStar Promotion (%d -> %d):\n• Requires Lv.%d + %dx %d Benched Fodder + %d Gold\n• Multiplies Base Combat x1.65 & Labor x1.35!",
			target.DisplayName, target.Stars, target.Level, maxLv, target.XP, reqXP, effHP, effATK, dps,
			target.Stars, target.Stars + 1, maxLv, target.Stars, target.Stars, promoGold
		)
	end

	for _, c in ipairs(pitRosterScroll:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end

	local count = 0
	for uuid, h in pairs(CurrentProfile.Heroes) do
		count += 1
		local row = makeFrame({
			Size = UDim2.new(1, -8, 0, 44),
			BackgroundColor3 = (uuid == SelectedPitTargetUUID) and Color3.fromRGB(85, 45, 35) or Color3.fromRGB(36, 26, 34),
			Corner = 6,
			Parent = pitRosterScroll,
		})
		makeLabel({
			Size = UDim2.new(0.68, 0, 0.86, 0),
			Position = UDim2.new(0.03, 0, 0.07, 0),
			Text = string.format("%s (%d Lv.%d) [%s]", h.DisplayName, h.Stars, h.Level, h.Assignment),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		makeButton({
			Size = UDim2.new(0.25, 0, 0.76, 0),
			Position = UDim2.new(0.72, 0, 0.12, 0),
			BackgroundColor3 = Color3.fromRGB(205, 95, 40),
			Text = "SELECT",
			Corner = 5,
			OnClick = function()
				SelectedPitTargetUUID = uuid
				refreshPitModal()
			end,
			Parent = row,
		})
	end
	pitRosterScroll.CanvasSize = UDim2.new(0, 0, 0, count * 50)
end

--============================================================================
-- 6. PROFILE SYNC & 60 FPS HUD UPDATE LOOP (WITH [E] SKILL-CHECK PULSE)
--============================================================================

ProfileDeltaSyncEvent.OnClientEvent:Connect(function(profile: any)
	CurrentProfile = profile
	if not profile then
		return
	end

	currencyLabel.Text = string.format(
		" GOLD: %d    GEMS: %d    RP: %d",
		math.floor(profile.Currencies.Gold),
		math.floor(profile.Currencies.Gems),
		math.floor(profile.Currencies.ResearchPoints)
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

	-- Right Board Pity & Tech Summary
	rightBoardText.Text = string.format(
		" WORLD BOSS & PITY\n• Min 3.0%% DMG for Loot\n• Boss Pity Meter: %d%% / 100%%\n• Rift Lures Owned: %d\n• Ring 2 Key: %s",
		profile.BossPity,
		profile.RiftLuresOwned,
		profile.UnlockedResearch.Ring2BarrierGate and "UNLOCKED ✓" or "LOCKED "
	)

	-- Update 5 Squad Slot Cards
	local maxSlots = if profile.UnlockedResearch.SquadSlot5 then 5
		elseif profile.UnlockedResearch.SquadSlot4 then 4
		else 3

	for slot = 1, 5 do
		local card = SquadSlotCards[slot]
		local slotTag = "SQUAD_SLOT_" .. tostring(slot)
		local assignedHero: any = nil
		for _, hero in pairs(profile.Heroes) do
			if hero.Assignment == slotTag then
				assignedHero = hero
				break
			end
		end

		if slot > maxSlots then
			card.Title.Text = string.format(" SLOT %d", slot)
			card.State.Text = "UNLOCK IN LAB"
			card.HPFill.Size = UDim2.fromScale(0, 1)
			card.StamFill.Size = UDim2.fromScale(0, 1)
		elseif assignedHero then
			local stars = string.rep("", assignedHero.Stars)
			card.Title.Text = string.format("%s %s", assignedHero.DisplayName, stars)
			card.StamFill.Size = UDim2.fromScale(math.clamp((assignedHero.CurrentStamina or 100) / 100.0, 0, 1), 1)
			if (assignedHero.ComaUntilTimestamp or 0) > os.time() then
				card.State.Text = string.format("COMA (%ds)", assignedHero.ComaUntilTimestamp - os.time())
				card.HPFill.Size = UDim2.fromScale(0, 1)
			else
				card.State.Text = string.format("Lv.%d | ST:%d%%", assignedHero.Level, math.round(assignedHero.CurrentStamina or 100))
				card.HPFill.Size = UDim2.fromScale(1, 1)
			end
		else
			card.Title.Text = string.format("%d. [EMPTY]", slot)
			card.State.Text = "OPEN SLOT"
			card.HPFill.Size = UDim2.fromScale(0, 1)
			card.StamFill.Size = UDim2.fromScale(0, 1)
		end
	end

	if waitingRoomModal.Visible and refreshWaitingRoomModal then
		refreshWaitingRoomModal()
	end
	if pitModal.Visible and refreshPitModal then
		refreshPitModal()
	end
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local cs = _G.ClientCombatState

	-- 1. Check Whistle Cooldowns & [E] Recall Skill-Check Assist Pulse (t = 1.1s..2.8s of Devouring Nova)
	local qRem = math.max(0, 20.0 - (now - LastQClock))
	if qRem > 0 then
		qButton.Text = string.format("[Q] OVERDRIVE\nCD: %.1fs", qRem)
	else
		qButton.Text = "[Q] OVERDRIVE\n+40% speed · 5s"
	end

	local eRem = math.max(0, 6.0 - (now - LastEClock))
	local novaElapsed = (cs and cs.NovaCastStartClock > 0) and (now - cs.NovaCastStartClock) or 999
	local inNovaOptimalWindow = (novaElapsed >= 1.1 and novaElapsed <= 2.8)

	if inNovaOptimalWindow then
		eButton.BackgroundColor3 = Color3.fromRGB(0, 245, 215)
		eButton.Text = " PRESS [E] NOW!\nOPTIMAL DODGE!"
	elseif eRem > 0 then
		eButton.BackgroundColor3 = Color3.fromRGB(20, 95, 125)
		eButton.Text = string.format("[E] RECALL\nCD: %.1fs", eRem)
	else
		eButton.BackgroundColor3 = Color3.fromRGB(25, 150, 195)
		eButton.Text = "[E] RECALL\nReturn to safety"
	end

	-- 2. Update World Boss Top Banner & Devouring Nova Cast Bar
	bossBanner.Visible=cs and cs.WorldBossNetId~=nil or false
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

	-- 3. Dynamic Relic Carry Context Banner & [B] Shatter Pact Temptation
	local char = LocalPlayer.Character
	local carryingRelic = char and char:GetAttribute("CarryingRelic")
	local carryingLootName = char and char:GetAttribute("CarryingLootName")
	if carryingRelic or carryingLootName then
		relicCarryBanner.Visible = true
		local nameStr = carryingRelic or carryingLootName
		relicCarryText.Text = string.format(" CARRYING: %s", tostring(nameStr))
	else
		relicCarryBanner.Visible = false
	end
end)


-- Art-pack UI composition. Gameplay callbacks above remain authoritative.
do
 local TweenService = game:GetService('TweenService')
 local UserInputService = game:GetService('UserInputService')
 local P = {surface=Color3.fromRGB(15,22,36), edge=Color3.fromRGB(58,75,100), gold=Color3.fromRGB(216,180,105), cyan=Color3.fromRGB(73,225,214), muted=Color3.fromRGB(159,177,200)}
 local portraits = {
  hero_han='rbxassetid://134553257432732',hero_jenna='rbxassetid://77764660527713',hero_catio='rbxassetid://121100166936309',
  hero_aaron='rbxassetid://74921274572294',hero_velkist='rbxassetid://99091778282719',hero_eolka='rbxassetid://107164344898405',hero_archon='rbxassetid://119875317197580',
 }
 portraits.starter_iron_vanguard=portraits.hero_han
 hudGui:SetAttribute('ArtPackUIVersion','AnimeR15_20261020')
 hudGui.IgnoreGuiInset=false
 hudGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
 local function stroke(parent,color)
  local st=parent:FindFirstChildOfClass('UIStroke') or Instance.new('UIStroke')
  st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;st.Thickness=1;st.Color=color or P.edge;st.Transparency=.12;st.Parent=parent
 end
 local function image(parent,asset,size,pos)
  local o=Instance.new('ImageLabel');o.BackgroundTransparency=1;o.Image=asset;o.Size=size;o.Position=pos;o.ScaleType=Enum.ScaleType.Fit;o.Parent=parent;return o
 end
 local modalBackdrop=Instance.new('TextButton');modalBackdrop.Name='ModalScrim';modalBackdrop.Text='';modalBackdrop.AutoButtonColor=false;modalBackdrop.BackgroundColor3=Color3.fromRGB(3,6,13);modalBackdrop.BackgroundTransparency=.24;modalBackdrop.Size=UDim2.fromScale(1,1);modalBackdrop.Visible=false;modalBackdrop.ZIndex=10;modalBackdrop.Parent=hudGui
 modalBackdrop.Activated:Connect(function() _G.OpenMasterModal('NONE') end)
 local modalList={waitingRoomModal,pitModal}
 for _,m in modalList do
  m.AnchorPoint=Vector2.new(.5,.5);m.Position=UDim2.fromScale(.5,.5);m.BackgroundColor3=P.surface;m.BackgroundTransparency=.02;m.ZIndex=20;stroke(m,P.gold)
  local g=Instance.new('UIGradient');g.Color=ColorSequence.new(Color3.fromRGB(25,36,56),P.surface);g.Rotation=100;g.Parent=m
  m:GetPropertyChangedSignal('Visible'):Connect(function()
   local any=false;for _,other in modalList do if other.Visible then any=true end end;modalBackdrop.Visible=any; local touch=PlayerGui:FindFirstChild("TouchGui");if touch and touch:IsA("ScreenGui") then touch.Enabled=not any end
  end)
 end
  -- Currency is split into three readable pills with the uploaded pack graphics.
 currencyLabel.Visible=false
 local currencyCluster=Instance.new('Frame');currencyCluster.Name='CurrencyCluster';currencyCluster.BackgroundTransparency=1;currencyCluster.Size=UDim2.fromOffset(370,44);currencyCluster.Position=UDim2.fromOffset(12,10);currencyCluster.Parent=topBar
 local currencyFields={}
 local currencies={{'Gold','rbxassetid://99086944565283',P.gold},{'Gems','rbxassetid://74751786636473',P.cyan},{'ResearchPoints','rbxassetid://80949385662716',Color3.fromRGB(178,143,242)}}
 for i,item in currencies do
  local f=makeFrame({Name=item[1]..'Pill',Size=UDim2.fromOffset(118,42),Position=UDim2.fromOffset((i-1)*124,0),BackgroundColor3=Color3.fromRGB(21,31,48),Corner=9,Parent=currencyCluster});stroke(f)
  image(f,item[2],UDim2.fromOffset(24,24),UDim2.fromOffset(8,9))
  currencyFields[item[1]]=makeLabel({Size=UDim2.new(1,-42,1,0),Position=UDim2.fromOffset(38,0),Text='—',TextColor3=item[3],TextSize=16,TextScaled=false,TextXAlignment=Enum.TextXAlignment.Left,Parent=f})
 end
 local function number(n)
  n=math.floor(n or 0);if n>=1000000 then return string.format('%.1fm',n/1000000) elseif n>=10000 then return string.format('%.1fk',n/1000) else return tostring(n) end
 end
 local function updateCurrency(profile)
  if not profile then return end
  for key,label in currencyFields do label.Text=number(profile.Currencies[key]) end
 end
 ProfileDeltaSyncEvent.OnClientEvent:Connect(updateCurrency);updateCurrency(CurrentProfile)
 -- Portrait cards retain the original profile and combat data connections.
 local cardPortraits={}
 for i,c in SquadSlotCards do
  c.Frame.BackgroundColor3=P.surface;c.Frame.BackgroundTransparency=.04;stroke(c.Frame)
  local art=image(c.Frame,'',UDim2.new(1,-8,0,62),UDim2.fromOffset(4,2));art.Name='HeroPortrait';art.ImageRectOffset=Vector2.new(76,0);art.ImageRectSize=Vector2.new(360,310);cardPortraits[i]=art
  c.Title.Position=UDim2.fromOffset(4,65);c.Title.Size=UDim2.new(1,-8,0,18);c.Title.TextColor3=P.gold;c.Title.TextSize=13;c.Title.TextScaled=false;c.Title.TextTruncate=Enum.TextTruncate.AtEnd
  c.HPFill.Parent.Position=UDim2.new(.07,0,0,87);c.HPFill.Parent.Size=UDim2.new(.86,0,0,5)
  c.StamFill.Parent.Position=UDim2.new(.07,0,0,96);c.StamFill.Parent.Size=UDim2.new(.86,0,0,5)
  c.HPFill.BackgroundColor3=Color3.fromRGB(92,206,145);c.StamFill.BackgroundColor3=P.gold
  c.State.Position=UDim2.fromOffset(3,104);c.State.Size=UDim2.new(1,-6,0,15);c.State.TextScaled=false;c.State.TextSize=10;c.State.TextColor3=P.muted
 end
 local function updatePortraits(profile)
  if not profile then return end
  for i,card in SquadSlotCards do
   local chosen=nil
   for _,h in profile.Heroes do if h.Assignment=='SQUAD_SLOT_'..i then chosen=h;break end end
   cardPortraits[i].Image=chosen and (portraits[chosen.TemplateId] or '') or ''
   cardPortraits[i].ImageTransparency=chosen and 0 or .6
  end
 end
 ProfileDeltaSyncEvent.OnClientEvent:Connect(updatePortraits);updatePortraits(CurrentProfile)
 image(qButton,'rbxassetid://106281518854512',UDim2.fromOffset(26,26),UDim2.fromOffset(6,5))
 image(eButton,'rbxassetid://114326036567745',UDim2.fromOffset(26,26),UDim2.fromOffset(6,5))
 for _,b in {qButton,eButton} do b.TextSize=13;b.TextScaled=false;b.TextWrapped=true;stroke(b,b==qButton and P.gold or P.cyan) end
 -- Keep development hooks out of normal navigation. F8 reveals them in Studio.
 local devButtons={};local primaryButtons={}
 for _,b in navButtonsFrame:GetChildren() do
  if b:IsA('TextButton') then
   if b.Text:find('Spawn Boss') or b.Text:find('Resources') then b.Visible=false;table.insert(devButtons,b) else table.insert(primaryButtons,b) end
  end
 end
 UserInputService.InputBegan:Connect(function(input,processed)
  if processed then return end
  if input.KeyCode==Enum.KeyCode.Escape then _G.OpenMasterModal('NONE') end
  if RunService:IsStudio() and input.KeyCode==Enum.KeyCode.F8 then for _,b in devButtons do b.Visible=not b.Visible end end
 end)
 for _,b in primaryButtons do b.BackgroundColor3=Color3.fromRGB(29,42,62);b.TextColor3=P.gold;b.TextSize=14;b.TextScaled=false;stroke(b) end
 local compact=false;local socialOpen=false;local encounterOpen=false
 local encounterToggle=makeButton({Name='EncounterToggle',Text='Encounter',Size=UDim2.fromOffset(120,32),BackgroundColor3=P.surface,Corner=8,OnClick=function() encounterOpen=not encounterOpen;rightBoard.Visible=not compact or encounterOpen end,Parent=hudGui})
 encounterToggle.TextScaled=false;encounterToggle.TextSize=12;stroke(encounterToggle)
 local wrScroll=Instance.new('ScrollingFrame');wrScroll.Name='WaitingRoomContent';wrScroll.BackgroundTransparency=1;wrScroll.BorderSizePixel=0;wrScroll.ScrollBarThickness=4;wrScroll.ScrollBarImageColor3=P.gold;wrScroll.Parent=waitingRoomModal
 wrLeftPane.Parent=wrScroll;wrRightPane.Parent=wrScroll
 local pitLeft=Instance.new('Frame');pitLeft.Name='PitTargetContent';pitLeft.BackgroundTransparency=1;pitLeft.Parent=pitModal
 local pitContentScroll=Instance.new('ScrollingFrame');pitContentScroll.Name='PitContent';pitContentScroll.BackgroundTransparency=1;pitContentScroll.BorderSizePixel=0;pitContentScroll.ScrollBarThickness=4;pitContentScroll.ScrollBarImageColor3=P.gold;pitContentScroll.Parent=pitModal
 pitLeft.Parent=pitContentScroll;pitRosterScroll.Parent=pitContentScroll
 pitTargetLabel.Parent=pitLeft;pitTargetLabel.Position=UDim2.fromOffset(0,0);pitTargetLabel.Size=UDim2.new(1,0,0,170);pitTargetLabel.TextSize=14;pitTargetLabel.TextScaled=false;pitTargetLabel.TextWrapped=true
 local pitAction=0
 for _,b in pitModal:GetChildren() do
  if b:IsA('TextButton') and (b.Text:find('FEED') or b.Text:find('ASCEND')) then b.Parent=pitLeft;b.Position=UDim2.fromOffset(0,184+pitAction*64);b.Size=UDim2.new(1,0,0,54);pitAction+=1 end
 end
 for _,list in {rosterScroll,pitRosterScroll} do list.AutomaticCanvasSize=Enum.AutomaticSize.Y;list.CanvasSize=UDim2.fromOffset(0,0);list.ScrollBarImageColor3=P.gold end
 -- Modal row sizing now comes from its layout, including rebuilt server lists.
 local function rowStyle(o)
  if not o:IsA('Frame') then return end
  o.BackgroundColor3=Color3.fromRGB(23,33,51);stroke(o)
  
  if o.Parent==rosterScroll then o.Size=UDim2.new(1,-10,0,compact and 86 or 72) end
  for _,v in o:GetDescendants() do if v:IsA('TextLabel') then v.TextWrapped=true;v.TextScaled=false;v.TextSize=compact and 12 or 14 end end
 end
 for _,list in {rosterScroll,pitRosterScroll} do list.ChildAdded:Connect(function(o) task.defer(rowStyle,o) end) end
 local modalWidths={1000,920}
 local function layout()
  local cam=workspace.CurrentCamera;if not cam then return end
  local view=cam.ViewportSize;local w,h=view.X,math.max(300,view.Y-40);compact=w<1100;local portrait=w<650;local stackPanels=portrait or h<540
  topBar.Position=UDim2.fromOffset(12,8);topBar.Size=UDim2.new(1,-24,0,(w<780) and 106 or 64);topBar.BackgroundColor3=P.surface;topBar.BackgroundTransparency=.04;stroke(topBar)
  local moneyScale=currencyCluster:FindFirstChildOfClass('UIScale') or Instance.new('UIScale',currencyCluster);moneyScale.Scale=portrait and math.min(1,(w-48)/370) or 1
  honorLabel.Visible=not compact;honorLabel.Size=UDim2.fromOffset(220,32);honorLabel.Position=UDim2.fromOffset(394,16);honorLabel.TextScaled=false;honorLabel.TextSize=12
  navButtonsFrame.Position=(w<780) and UDim2.fromOffset(12,60) or UDim2.new(1,-382,0,12);navButtonsFrame.Size=(w<780) and UDim2.new(1,-24,0,36) or UDim2.fromOffset(370,40)
  for _,b in primaryButtons do b.Size=UDim2.fromOffset(portrait and math.floor((w-64)/3) or 116,36) end
  navLayout.HorizontalAlignment=(w<780) and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right
  bossBanner.Position=UDim2.new(.5,0,0,compact and 124 or 84);bossBanner.AnchorPoint=Vector2.new(.5,0);bossBanner.Size=UDim2.new(0,math.min(w-32,720),0,58);bossBanner.BackgroundColor3=P.surface;stroke(bossBanner,Color3.fromRGB(144,103,199))
  bossTitleLabel.TextSize=portrait and 12 or 15;bossTitleLabel.TextScaled=false;bossTitleLabel.TextTruncate=Enum.TextTruncate.AtEnd
  novaCastLabel.TextSize=portrait and 10 or 12;novaCastLabel.TextScaled=false
  toastBanner.AnchorPoint=Vector2.new(.5,0);toastBanner.Position=UDim2.new(.5,0,0,compact and 226 or 152);toastBanner.Size=UDim2.new(0,math.min(w-32,650),0,46)
  rightBoard.Position=UDim2.new(1,-16,0,compact and 228 or 180);rightBoard.AnchorPoint=Vector2.new(1,0);rightBoard.Size=UDim2.fromOffset(math.min(260,w-32),170);rightBoard.Visible=not compact or encounterOpen
	rightBoard.BackgroundColor3=P.surface;rightBoard.BackgroundTransparency=.08;stroke(rightBoard)
  encounterToggle.Visible=compact;encounterToggle.Position=UDim2.new(1,-136,0,(w<780) and 122 or 80)
  if portrait then
   bottomDock.Size=UDim2.new(1,-24,0,186);bottomDock.Position=UDim2.new(.5,0,1,-130);bottomDock.AnchorPoint=Vector2.new(.5,1)
   squadStrip.Size=UDim2.new(1,0,0,120);squadStrip.Position=UDim2.fromOffset(0,0)
   for _,c in SquadSlotCards do c.Frame.Size=UDim2.new(.2,-7,0,120) end
   qButton.Size=UDim2.new(.5,-4,0,54);eButton.Size=qButton.Size;qButton.Position=UDim2.fromOffset(0,130);eButton.Position=UDim2.new(.5,4,0,130)
  else
   local short=view.Y<600;local cw=short and math.clamp(math.floor((w-480)/5),42,70) or math.clamp(math.floor((w-280)/5)-8,80,138);local actionW=short and 76 or 104;local total=cw*5+32+actionW*2+20
   bottomDock.Size=UDim2.fromOffset(total,120);bottomDock.Position=UDim2.new(.5,0,1,-14);bottomDock.AnchorPoint=Vector2.new(.5,1)
   squadStrip.Size=UDim2.fromOffset(cw*5+32,120);squadStrip.Position=UDim2.fromOffset(0,0)
   for _,c in SquadSlotCards do c.Frame.Size=UDim2.fromOffset(cw,120) end
   qButton.Size=UDim2.fromOffset(actionW,100);eButton.Size=qButton.Size;qButton.Position=UDim2.fromOffset(cw*5+44,20);eButton.Position=UDim2.fromOffset(cw*5+52+actionW,20)
  end
  local cardH=(view.Y<600) and 94 or 120
  for i,c in SquadSlotCards do
   c.Frame.Size=UDim2.new(c.Frame.Size.X.Scale,c.Frame.Size.X.Offset,0,cardH)
   cardPortraits[i].Size=UDim2.new(1,-8,0,cardH-58)
   c.Title.Position=UDim2.fromOffset(4,cardH-55)
   c.HPFill.Parent.Position=UDim2.new(.07,0,0,cardH-33);c.StamFill.Parent.Position=UDim2.new(.07,0,0,cardH-24)
   c.State.Position=UDim2.fromOffset(3,cardH-16)
  end
  if view.Y<600 and not portrait then
   bottomDock.Size=UDim2.fromOffset(bottomDock.Size.X.Offset,cardH);squadStrip.Size=UDim2.fromOffset(squadStrip.Size.X.Offset,cardH)
   qButton.Size=UDim2.fromOffset(qButton.Size.X.Offset,cardH-4);eButton.Size=qButton.Size;qButton.Position=UDim2.fromOffset(qButton.Position.X.Offset,4);eButton.Position=UDim2.fromOffset(eButton.Position.X.Offset,4)
  end
  relicCarryBanner.AnchorPoint=Vector2.new(.5,1);relicCarryBanner.Position=UDim2.new(.5,0,0,-10);relicCarryBanner.Size=UDim2.fromOffset(math.min(w-32,650),48)
  for i,m in modalList do m.Size=UDim2.fromOffset(math.min(w-24,modalWidths[i]),math.min(h-38,i==4 and 260 or 580)) end
  local mw=waitingRoomModal.AbsoluteSize.X
  wrScroll.Position=UDim2.fromOffset(12,48);wrScroll.Size=UDim2.new(1,-24,1,-62)
  if stackPanels then
   wrScroll.CanvasSize=UDim2.fromOffset(0,810);wrLeftPane.Position=UDim2.fromOffset(0,0);wrLeftPane.Size=UDim2.new(1,-10,0,410);wrRightPane.Position=UDim2.fromOffset(0,430);wrRightPane.Size=UDim2.new(1,-10,0,350)
  else wrScroll.CanvasSize=UDim2.fromOffset(0,0);wrLeftPane.Position=UDim2.fromScale(0,0);wrLeftPane.Size=UDim2.new(.48,0,1,0);wrRightPane.Position=UDim2.fromScale(.5,0);wrRightPane.Size=UDim2.new(.5,-10,1,0) end
  local pitWidth=pitModal.AbsoluteSize.X
  pitContentScroll.Position=UDim2.fromOffset(16,52);pitContentScroll.Size=UDim2.new(1,-32,1,-64)
  if stackPanels then
   pitContentScroll.CanvasSize=UDim2.fromOffset(0,660);pitLeft.Position=UDim2.fromOffset(0,0);pitLeft.Size=UDim2.new(1,-10,0,304);pitRosterScroll.Position=UDim2.fromOffset(0,324);pitRosterScroll.Size=UDim2.new(1,-10,0,320)
  else pitContentScroll.CanvasSize=UDim2.fromOffset(0,0);pitLeft.Position=UDim2.fromScale(0,0);pitLeft.Size=UDim2.new(.46,0,1,0);pitRosterScroll.Position=UDim2.fromScale(.5,0);pitRosterScroll.Size=UDim2.new(.5,-10,1,0) end
  for _,list in {rosterScroll,pitRosterScroll} do for _,o in list:GetChildren() do rowStyle(o) end end
 end
 task.defer(layout)
 if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(layout) end
 workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function() if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(layout);layout() end end)
 -- Feed the footer actual replicated health and stamina, rather than full-health placeholders.
 local elapsed=0
 RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.1 then return end;elapsed=0
  local state=_G.ClientCombatState;if not state or not CurrentProfile then return end
  for id,meta in state.Metadata do
   if meta.IsHero and meta.OwnerUserId==LocalPlayer.UserId and meta.SlotIndex then
    local c=SquadSlotCards[meta.SlotIndex];local node=state.VisualNodes[id]
    if c and node then c.HPFill.Size=UDim2.fromScale(math.clamp(node.HpPermille/1000,0,1),1);c.StamFill.Size=UDim2.fromScale(math.clamp(node.Stamina/100,0,1),1);c.State.Text=string.format('HP %d%%  ·  ST %d%%',math.round(node.HpPermille/10),node.Stamina) end
   end
  end
 end)
end




