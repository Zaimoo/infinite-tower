--!strict
-- StarterPlayerScripts/UI/HUDController.client.luau
-- Complete Implementation of Document 4 UI/UX Wireframes:
-- 1. MasterHUDScreenGui (Main Tactical HUD + Clean Bottom Toolbar)
-- 2. SquadDeployScreenGui (Active 5-Hero Squad & Roster Management via War Banner)
-- 3. ThePitScreenGui (Synthesis XP Fodder & 1->5 Star Promotion)
-- 4. MercenaryScreenGui (Noticeboard, Secret Directives & 50G Audit Soul Reveal)

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local TowerFloorConfig = require(Shared:WaitForChild("Config"):WaitForChild("TowerFloorConfig"))

-- 1234567 -> "1.2M", matching the floor selector's power readout.
local function abbreviatePower(n: number): string
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= unit[1] then
			return (string.gsub(string.format("%.1f%s", n / unit[1], unit[2]), "%.0(%a)$", "%1"))
		end
	end
	return tostring(math.round(n))
end

-- Recommended power per floor; fixed data, so it is computed once per floor instead of every frame.
local recommendedPowerCache: { [number]: number } = {}
local function recommendedPower(floorId: number): number
	local cached = recommendedPowerCache[floorId]
	if not cached then
		cached = TowerFloorConfig.RecommendedPower(floorId)
		recommendedPowerCache[floorId] = cached
	end
	return cached
end
local RAID_FLOOR = require(Shared:WaitForChild("Config"):WaitForChild("RaidConfig")).FloorId -- raid arena (docs/raid-boss-plan.md)
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local GothicBoxStyle = require(Shared:WaitForChild("Util"):WaitForChild("GothicBoxStyle"))
local GothicVectorIcons = require(Shared:WaitForChild("Util"):WaitForChild("GothicVectorIcons"))
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local BillboardThemes = require(Shared:WaitForChild("Config"):WaitForChild("BillboardThemes"))
local UIFeel = require(script.Parent:WaitForChild("UIFeel"))
local Store = require(script.Parent:WaitForChild("Hud"):WaitForChild("Store"))
local WindowManager = require(script.Parent:WaitForChild("WindowManager"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatRemotes = Remotes:WaitForChild("CombatRemotes")
local RelicPactRemotes = Remotes:WaitForChild("RelicPactRemotes")
local TycoonRemotes = Remotes:WaitForChild("TycoonGachaRemotes")
local SyndicateRemotes = Remotes:WaitForChild("SyndicateRemotes")

local WhistleCommandRemote = CombatRemotes:WaitForChild("WhistleCommand") :: RemoteEvent

local FocusTargetRemote = CombatRemotes:WaitForChild("FocusTarget") :: RemoteEvent
local SquadWipeStateRemote = CombatRemotes:WaitForChild("SquadWipeState") :: RemoteEvent
local DropCarriedItemRemote = CombatRemotes:WaitForChild("DropCarriedItem") :: RemoteEvent
local TowerRemotes = Remotes:WaitForChild("TowerRemotes")
local FloorProgressRemote = TowerRemotes:WaitForChild("FloorProgress") :: RemoteEvent
local SquadDefeatedRemote = TowerRemotes:WaitForChild("SquadDefeated") :: RemoteEvent
local SquadStatusRemote = TowerRemotes:WaitForChild("SquadStatus") :: RemoteEvent

local clientFloorProgress = {
	FloorId = 0,
	CurrentKills = 0,
	RequiredKills = 13,
	BossSpawned = false,
	BossDefeated = false,
}

FloorProgressRemote.OnClientEvent:Connect(function(progress: any)
	if type(progress) == "table" and type(progress.FloorId) == "number" then
		clientFloorProgress.FloorId = progress.FloorId
		clientFloorProgress.CurrentKills = tonumber(progress.CurrentKills) or 0
		clientFloorProgress.RequiredKills = tonumber(progress.RequiredKills) or math.max(1, math.round(12 + 0.5 * progress.FloorId))
		clientFloorProgress.BossSpawned = progress.BossSpawned == true
		clientFloorProgress.BossDefeated = progress.BossDefeated == true
	end
end)

local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local ArtifactRemotes = Remotes:WaitForChild("ArtifactRemotes")
local RequestEquipArtifactFunc = ArtifactRemotes:WaitForChild("RequestEquipArtifact") :: RemoteFunction
local RequestUnequipArtifactFunc = ArtifactRemotes:WaitForChild("RequestUnequipArtifact") :: RemoteFunction

local RequestSummonFunc = TycoonRemotes:WaitForChild("RequestSummon") :: RemoteFunction
local AssignHeroRoleFunc = TycoonRemotes:WaitForChild("AssignHeroRole") :: RemoteFunction
local FacilityInteractEvent = TycoonRemotes:WaitForChild("FacilityInteract") :: RemoteEvent

local ProfileDeltaSyncEvent = SyndicateRemotes:WaitForChild("ProfileDeltaSync") :: RemoteEvent
local SystemToastEvent = SyndicateRemotes:WaitForChild("SystemToast") :: RemoteEvent

local CurrentProfile: any = nil
local SelectedMercDirective: string = "PARASITE"
local LastQClock = -99
local LastEClock = -99

--============================================================================
-- UI BUILDER HELPERS
--============================================================================

-- Gilded Grimoire: no emoji in the UI. Server messages may still carry them, so drop emoji
-- code points (keeping ★ and the ✓ ✕ ✗ marks) before showing the text.
local function stripEmoji(text: string): string
	local ok, parts = pcall(function()
		local out = {}
		for _, c in utf8.codes(text) do
			local emoji = (c >= 0x1F000 and c <= 0x1FAFF) or (c >= 0x2300 and c <= 0x23FF) or c == 0xFE0F or c == 0x200D
				or (c >= 0x2600 and c <= 0x27BF and c ~= 0x2605 and c ~= 0x2713 and c ~= 0x2715 and c ~= 0x2717)
			if not emoji then
				table.insert(out, utf8.char(c))
			end
		end
		return out
	end)
	if not ok then return text end -- not valid UTF-8: show it unchanged
	return (string.gsub(table.concat(parts), "^%s+", ""))
end

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
-- Phase 5: building screens live here and must draw over the React HUD zones (DisplayOrder 1)
-- but under the React overlay (DisplayOrder 10).
hudGui.DisplayOrder = 5
hudGui.Parent = PlayerGui
-- Gilded Grimoire: every legacy Gotham label in the HUD (alerts, banners) uses the theme fonts.
GildedGrimoire.Watch(hudGui)

--============================================================================
-- MODAL FOCUS MODE (FULL-SCREEN DIMMER, LIGHTING POLISH & SELECTIVE HUD HIDING)
--============================================================================

local oldModalFocusGui = PlayerGui:FindFirstChild("ModalFocusScreenGui")
if oldModalFocusGui then
	oldModalFocusGui:Destroy()
end

local modalFocusGui = Instance.new("ScreenGui")
modalFocusGui.Name = "ModalFocusScreenGui"
modalFocusGui.ResetOnSpawn = false
modalFocusGui.IgnoreGuiInset = true
modalFocusGui.ScreenInsets = Enum.ScreenInsets.None
modalFocusGui.DisplayOrder = 4
modalFocusGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
modalFocusGui.Parent = PlayerGui

local modalFocusOverlay = Instance.new("Frame")
modalFocusOverlay.Name = "ModalFocusOverlay"
modalFocusOverlay.Size = UDim2.fromScale(1, 1)
modalFocusOverlay.Position = UDim2.fromScale(0, 0)
modalFocusOverlay.BackgroundColor3 = Color3.fromHex("#06040A")
modalFocusOverlay.BackgroundTransparency = 1
modalFocusOverlay.BorderSizePixel = 0
modalFocusOverlay.Visible = false
modalFocusOverlay.ZIndex = 1
modalFocusOverlay.Active = false
modalFocusOverlay.Parent = modalFocusGui

local function getOrCreateEffect<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing :: any
	end
	if existing then existing:Destroy() end
	local eff = Instance.new(className)
	eff.Name = name
	eff.Parent = Lighting
	return eff :: any
end

local focusBlur = getOrCreateEffect("BlurEffect", "ModalFocusBlur") :: BlurEffect
focusBlur.Size = 0
focusBlur.Enabled = false

local focusColorCorrection = getOrCreateEffect("ColorCorrectionEffect", "ModalFocusColorCorrection") :: ColorCorrectionEffect
focusColorCorrection.Brightness = 0
focusColorCorrection.Contrast = 0.04
focusColorCorrection.Enabled = false

local isFocusModeActive = false
local currentOverlayTween: Tween? = nil
local currentBlurTween: Tween? = nil
local currentCCTween: Tween? = nil

local function applyFocusMode(isFocused: boolean, _options: { [string]: any }?)
	if isFocusModeActive == isFocused then return end
	isFocusModeActive = isFocused

	if currentOverlayTween then currentOverlayTween:Cancel() currentOverlayTween = nil end
	if currentBlurTween then currentBlurTween:Cancel() currentBlurTween = nil end
	if currentCCTween then currentCCTween:Cancel() currentCCTween = nil end

	local reduced = UIFeel.ReducedMotion()
	local duration = if isFocused then (if reduced then 0.05 else 0.22) else (if reduced then 0.05 else 0.18)
	local ease = Enum.EasingStyle.Quad
	local dir = Enum.EasingDirection.Out

	if isFocused then
		-- 1. Dimmer Backdrop
		modalFocusOverlay.Visible = true
		currentOverlayTween = TweenService:Create(modalFocusOverlay, TweenInfo.new(duration, ease, dir), {
			BackgroundTransparency = 0.35,
		})
		currentOverlayTween:Play()

		-- 2. 3D Lighting Polish
		focusBlur.Enabled = true
		currentBlurTween = TweenService:Create(focusBlur, TweenInfo.new(duration, ease, dir), {
			Size = 8,
		})
		currentBlurTween:Play()

		focusColorCorrection.Enabled = true
		currentCCTween = TweenService:Create(focusColorCorrection, TweenInfo.new(duration, ease, dir), {
			Brightness = -0.08,
		})
		currentCCTween:Play()

		-- 3. World Interactions & Clutter
		pcall(function() ProximityPromptService.Enabled = false end)

		local lbGui = PlayerGui:FindFirstChild("CustomLeaderboardGui") :: ScreenGui?
		if lbGui then lbGui.Enabled = false end

		local topBarRight = PlayerGui:FindFirstChild("TopBarRightScreenGui") :: ScreenGui?
		if topBarRight then topBarRight.Enabled = false end

		-- 4. React HUD Rails & Squad Drawer (keeps Currencies visible in Overlay)
		Store.SetModalFocus(true)
	else
		-- 1. Dimmer Backdrop
		currentOverlayTween = TweenService:Create(modalFocusOverlay, TweenInfo.new(duration, ease, dir), {
			BackgroundTransparency = 1,
		})
		currentOverlayTween:Play()
		currentOverlayTween.Completed:Connect(function()
			if not isFocusModeActive then
				modalFocusOverlay.Visible = false
			end
		end)

		-- 2. 3D Lighting Polish
		currentBlurTween = TweenService:Create(focusBlur, TweenInfo.new(duration, ease, dir), {
			Size = 0,
		})
		currentBlurTween:Play()
		currentBlurTween.Completed:Connect(function()
			if not isFocusModeActive then
				focusBlur.Enabled = false
			end
		end)

		currentCCTween = TweenService:Create(focusColorCorrection, TweenInfo.new(duration, ease, dir), {
			Brightness = 0,
		})
		currentCCTween:Play()
		currentCCTween.Completed:Connect(function()
			if not isFocusModeActive then
				focusColorCorrection.Enabled = false
			end
		end)

		-- 3. World Interactions & Clutter
		pcall(function() ProximityPromptService.Enabled = true end)

		local lbGui = PlayerGui:FindFirstChild("CustomLeaderboardGui") :: ScreenGui?
		if lbGui then lbGui.Enabled = true end

		local topBarRight = PlayerGui:FindFirstChild("TopBarRightScreenGui") :: ScreenGui?
		if topBarRight then topBarRight.Enabled = true end

		-- 4. React HUD Rails & Squad Drawer
		Store.SetModalFocus(false)
	end
end

local function setModalFocusMode(isFocused: boolean, options: { [string]: any }?)
	if not isFocused then
		task.defer(function()
			if _G.IsAnyMasterModalOpen and _G.IsAnyMasterModalOpen() then
				return
			end
			applyFocusMode(false, options)
		end)
	else
		applyFocusMode(true, options)
	end
end

_G.SetModalFocusMode = setModalFocusMode
_G.IsModalFocusMode = function(): boolean
	return isFocusModeActive
end

LocalPlayer.CharacterRemoving:Connect(function()
	setModalFocusMode(false)
end)

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
local toastScale = Instance.new("UIScale")
toastScale.Parent = toastBanner

-- Toasts pop in (overshoot, sound, haptic for warnings), hold, then shrink away.
-- A new toast while one is showing re-pops in place instead of stacking.
local function playToast(msg: string, color: Color3, holdSeconds: number, isWarn: boolean)
	toastCounter += 1
	local myId = toastCounter
	-- Gilded Grimoire: no emoji in the UI (server messages may still carry them).
	toastText.Text = stripEmoji(msg)
	toastText.TextColor3 = color
	toastBanner.Visible = true
	if UIFeel.ReducedMotion() then
		toastScale.Scale = 1
	else
		toastScale.Scale = 0.6
		TweenService:Create(toastScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	UIFeel.Sfx(if isWarn then "Error" else "ToastIn")
	if isWarn then
		UIFeel.Haptic("Notify")
		UIFeel.Shake(toastBanner, 2.5, 0.3)
	end
	task.delay(holdSeconds, function()
		if toastCounter ~= myId then return end
		if UIFeel.ReducedMotion() then
			toastBanner.Visible = false
			return
		end
		local out = TweenService:Create(toastScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		out:Play()
		out.Completed:Wait()
		if toastCounter == myId then
			toastBanner.Visible = false
			toastScale.Scale = 1
		end
	end)
end

-- Server toasts go through the kit's stacked toasts (Kit/Notify). The single-slot playToast above
-- stays only as a fallback if the kit fails to load.
local KitNotify = (function()
	local ok, kit = pcall(function() return require(script.Parent:WaitForChild("Kit")) end)
	if ok then return kit.Notify end
	warn("[HUD] UI kit failed to load; using the legacy toast:", kit)
	return nil
end)()

SystemToastEvent.OnClientEvent:Connect(function(msg: string, colorType: string, receipt: any?)
	if KitNotify then
		if type(receipt) == "table" then
			KitNotify.RelicReceipt(receipt)
		else
			KitNotify.Push(if colorType == "WARN" then "warn" elseif colorType == "SUCCESS" then "success" else "info", tostring(msg))
		end
		return
	end
	local color = if colorType == "WARN" then Color3.fromRGB(255, 105, 105)
		elseif colorType == "SUCCESS" then Color3.fromRGB(95, 250, 145)
		else Color3.fromRGB(135, 225, 255)
	playToast(msg, color, 4.5, colorType == "WARN")
end)

do
	local runSummary = TowerRemotes:WaitForChild("RunSummary") :: RemoteEvent
	runSummary.OnClientEvent:Connect(function(summary)
		local title: string
		local lines: { string } = {}
		local isWipe = summary.Reason == "WIPE"
		if isWipe then
			title = "Squad defeated"
			if summary.Streak > 0 then
				table.insert(lines, "Streak ended · Banked loot is safe")
			end
			if summary.LossGold > 0 or summary.LossGems > 0 then
				table.insert(lines, string.format("Lost %d Gold · %d Gems", summary.LossGold, summary.LossGems))
			end
			table.insert(lines, "Carried loot dropped")
		elseif summary.Reason == "RETURN" then
			title = "Run ended"
			if summary.BestStreak > 0 then
				table.insert(lines, string.format("Best streak · %d %s", summary.BestStreak, if summary.BestStreak == 1 then "floor" else "floors"))
			end
			if summary.FloorsCleared > 0 or summary.Kills > 0 then
				table.insert(lines, string.format("Floors %d–%d · %d cleared", summary.StartFloor, summary.HighestFloor, summary.FloorsCleared))
				table.insert(lines, string.format("+%d Gold · +%d Gems", summary.GoldEarned + summary.RelicGold, summary.GemsEarned + summary.RelicGems))
			else
				table.insert(lines, string.format("Returned from Floor %d.", summary.StartFloor))
			end
		else
			return
		end
		if KitNotify then
			KitNotify.Push(if isWipe then "warn" else "info", title, { Lines = lines, Hold = 5 })
		else
			playToast(title .. " · " .. table.concat(lines, " · "), if isWipe then Color3.fromRGB(255, 105, 105) else Color3.fromRGB(135, 225, 255), 5, isWipe)
		end
	end)
end

-- Loot Stolen Bounty Banner
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
	Text = "LOOT STOLEN!",
	TextColor3 = Color3.fromRGB(255, 180, 180),
	TextSize = 13,
	TextScaled = false,
	Parent = lootStolenBanner,
})

-- The banner tracks the newest contested drop; it stays up with a countdown for the whole
-- bounty window, and the server clears it when the drop is recovered, duelled or gone. The duel is
-- claimed in the world (walk up to the thief and press F), so the banner only carries the hint.
local currentContest: any = nil
local bountyHint = makeLabel({
	Size = UDim2.new(0.30, 0, 0.8, 0),
	Position = UDim2.new(0.68, 0, 0.1, 0),
	BackgroundColor3 = Color3.fromRGB(220, 35, 45),
	Text = "HUNT THEM: [F]",
	TextColor3 = Color3.fromRGB(255, 255, 255),
	TextSize = 13,
	TextScaled = false,
	Corner = 6,
	Parent = lootStolenBanner,
})

-- The server puts a "Claim Bounty" [F] prompt on every [Loot Thief]. Hide the one on our own
-- character locally (the server also rejects a thief claiming their own bounty).
local function hideOwnBountyPrompt(character: Model)
	local function hide(child: Instance)
		if child:IsA("ProximityPrompt") and child.Name == "BountyPrompt" then
			child.Enabled = false
		end
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then return end
	for _, child in root:GetChildren() do hide(child) end
	root.ChildAdded:Connect(hide)
end
if LocalPlayer.Character then task.spawn(hideOwnBountyPrompt, LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(hideOwnBountyPrompt)

local function refreshContestBanner()
	local contest = currentContest
	if not contest then
		lootStolenBanner.Visible = false
		return
	end
	local remaining = math.max(0, math.ceil(contest.ExpiresAt - os.clock()))
	if remaining <= 0 then
		currentContest = nil
		lootStolenBanner.Visible = false
		return
	end
	lootStolenText.Text = string.format("%s STOLE YOUR %s! (%d:%02d)", string.upper(contest.ThiefName), string.upper(contest.Label), remaining // 60, remaining % 60)
	lootStolenBanner.Visible = true
end

-- Bound in the background so a missing remote can never stall the rest of the HUD.
task.spawn(function()
	local LootContestedRemote = TowerRemotes:WaitForChild("LootContested") :: RemoteEvent
	LootContestedRemote.OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" then return end
		if message.Kind == "STOLEN" and type(message.DropId) == "number" then
			currentContest = {
				DropId = message.DropId,
				ThiefName = tostring(message.ThiefName),
				Label = tostring(message.Label or "loot"),
				ExpiresAt = os.clock() + (tonumber(message.Seconds) or 0),
			}
		elseif message.Kind == "CLEAR" and currentContest and currentContest.DropId == message.DropId then
			currentContest = nil
		end
		refreshContestBanner()
	end)
end)

task.spawn(function()
	while true do
		task.wait(1)
		if currentContest then refreshContestBanner() end
	end
end)

-- Squad alerts (wiped / heroes down) are outlined text with no panel, so they never cover the fight.
local squadWipeBanner = makeFrame({
	Name = "SquadWipeRecoveryBanner",
	Size = UDim2.new(0, 560, 0, 28),
	Position = UDim2.new(0.5, -280, 1, -105),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = hudGui,
})

local squadWipeText = makeLabel({
	Size = UDim2.new(1, -12, 1, 0),
	Position = UDim2.new(0, 6, 0, 0),
	Text = "SQUAD DOWN · Recover at your plot",
	TextColor3 = Color3.fromRGB(255, 110, 110),
	TextSize = 16,
	TextScaled = false,
	Parent = squadWipeBanner,
})

local partiallyDefeatedBanner: Frame? = nil

SquadWipeStateRemote.OnClientEvent:Connect(function(isWiped: boolean)
	squadWipeBanner.Visible = isWiped
	if isWiped and partiallyDefeatedBanner then
		partiallyDefeatedBanner.Visible = false
	end
end)

-- Partially Defeated Squad Warning Banner & Detailed Tooltip Popover
partiallyDefeatedBanner = makeFrame({
	Name = "PartiallyDefeatedSquadBanner",
	Size = UDim2.new(0, 560, 0, 40),
	Position = UDim2.new(0.5, -280, 1, -108),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = hudGui,
})

local partialHeader = makeLabel({
	Size = UDim2.new(1, -16, 0, 22),
	Position = UDim2.new(0, 8, 0, 0),
	Text = "1/5 HEROES DOWN",
	TextColor3 = Color3.fromRGB(251, 191, 36), -- Gold Amber
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextScaled = false,
	Parent = partiallyDefeatedBanner,
})

local partialSubtext = makeLabel({
	Size = UDim2.new(1, -16, 0, 18),
	Position = UDim2.new(0, 8, 0, 22),
	Text = "Revive on floor travel or Hub return",
	TextColor3 = Color3.fromRGB(254, 243, 199), -- Warm Amber Cream
	TextSize = 12,
	Font = Enum.Font.GothamMedium,
	TextScaled = false,
	Parent = partiallyDefeatedBanner,
})

local partialTooltipPopover = makeFrame({
	Name = "SquadVitalityTooltip",
	Size = UDim2.new(0, 340, 0, 160),
	Position = UDim2.new(0.5, -170, 0, -168),
	BackgroundColor3 = Color3.fromRGB(18, 14, 24),
	BackgroundTransparency = 0.05,
	Corner = 8,
	Stroke = 1.5,
	StrokeColor = Color3.fromRGB(245, 158, 11),
	Visible = false,
	Parent = partiallyDefeatedBanner,
})

local tooltipTitle = makeLabel({
	Size = UDim2.new(1, -16, 0, 22),
	Position = UDim2.new(0, 8, 0, 6),
	Text = "SQUAD",
	TextColor3 = Color3.fromRGB(251, 191, 36),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	Parent = partialTooltipPopover,
})

local tooltipList = makeLabel({
	Size = UDim2.new(1, -16, 0, 78),
	Position = UDim2.new(0, 8, 0, 30),
	Text = "Tracking squad members...",
	TextColor3 = Color3.fromRGB(225, 220, 240),
	TextSize = 11,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = partialTooltipPopover,
})

local tooltipFooter = makeLabel({
	Size = UDim2.new(1, -16, 0, 38),
	Position = UDim2.new(0, 8, 1, -42),
	Text = "Floor travel or Hub return revives everyone.",
	TextColor3 = Color3.fromRGB(147, 197, 253),
	TextSize = 10,
	Font = Enum.Font.GothamMedium,
	Parent = partialTooltipPopover,
})

partiallyDefeatedBanner.MouseEnter:Connect(function()
	partialTooltipPopover.Visible = true
end)
partiallyDefeatedBanner.MouseLeave:Connect(function()
	partialTooltipPopover.Visible = false
end)
partiallyDefeatedBanner.InputBegan:Connect(function(input: InputObject)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		partialTooltipPopover.Visible = not partialTooltipPopover.Visible
	end
end)

SquadStatusRemote.OnClientEvent:Connect(function(status: any)
	if type(status) ~= "table" then return end
	local fallen = status.FallenCount or 0
	local total = status.TotalCount or 0
	local alive = status.AliveCount or 0
	local isWiped = status.IsWiped == true
	local fallenList = status.FallenHeroes or {}
	local statuses = status.HeroStatuses or {}
	local isStationed = status.IsStationed == true or (Store.SquadAssignment ~= nil and Store.SquadAssignment > 0)

	if isWiped then
		partiallyDefeatedBanner.Visible = false
		partialTooltipPopover.Visible = false
		squadWipeBanner.Visible = not isStationed
		return
	end

	squadWipeBanner.Visible = false

	if not isStationed and fallen > 0 and alive > 0 and clientFloorProgress.FloorId > 0 then
		partiallyDefeatedBanner.Visible = true
		partialHeader.Text = string.format("%d/%d %s DOWN", fallen, total, if total == 1 then "HERO" else "HEROES")
		local namesText = if #fallenList > 0 then table.concat(fallenList, ", ") else "Hero"
		partialSubtext.Text = string.format("%s · revives when you change floor", namesText)

		local lines = {}
		for _, h in ipairs(statuses) do
			if h.Alive then
				table.insert(lines, string.format("%s · %d%% HP", h.Name, h.HpPct or 100))
			else
				table.insert(lines, string.format("%s · Down", h.Name))
			end
		end
		tooltipList.Text = table.concat(lines, "\n")
	else
		partiallyDefeatedBanner.Visible = false
		partialTooltipPopover.Visible = false
	end
end)

Store.Changed:Connect(function()
	local isStationed = Store.SquadAssignment ~= nil and Store.SquadAssignment > 0
	if isStationed and partiallyDefeatedBanner and partiallyDefeatedBanner.Visible then
		partiallyDefeatedBanner.Visible = false
		partialTooltipPopover.Visible = false
	end
end)

-- Both squad alerts sit bottom-centre. They used to be 560 px wide at a fixed height, which put them
-- on top of the Squad drawer whenever it was expanded (and danger auto-expands it). Now they are
-- narrower, and lift above the drawer and the bottom-right badges when they would touch either.
local function placeSquadBanners()
	local size = hudGui.AbsoluteSize
	local width = math.min(420, size.X - 24)
	local left = size.X / 2 - width / 2
	local crowded = left < math.max(Store.DrawerRight, 230) + 8
	local bottom = if crowded then math.max(Store.DrawerTop, 132) + 10 else 60
	for _, banner in { squadWipeBanner, partiallyDefeatedBanner :: Frame } do
		banner.AnchorPoint = Vector2.new(0.5, 1)
		banner.Size = UDim2.fromOffset(width, banner.Size.Y.Offset)
		banner.Position = UDim2.new(0.5, 0, 1, -bottom)
	end
end
placeSquadBanners()
hudGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeSquadBanners)
task.spawn(function()
	-- The drawer slides open a moment after an alert appears; follow it while an alert is up.
	while true do
		task.wait(0.2)
		if squadWipeBanner.Visible or (partiallyDefeatedBanner :: Frame).Visible then placeSquadBanners() end
	end
end)

-- Connected after the banner exists: an earlier connection captured an undeclared
-- (nil) squadWipeBanner and errored on every wipe.
SquadDefeatedRemote.OnClientEvent:Connect(function(floorId: number)
	squadWipeBanner.Visible = true
	squadWipeText.Text = string.format("SQUAD WIPED · Floor %d · Carried loot dropped", floorId or 0)
end)

-- Top-centre tower strip. It has no panel, so it never covers the fight:
--   floor   "FLOOR 3 · VERDANT RUINS", a thin kill-progress line and "3 / 14" under it;
--   boss    the name in the boss tier colour over a wide, ink-outlined HP bar with the percentage
--           inside and a pale trail that drains after each hit; phase and raid timer under it.
local BOSS_THEME = BillboardThemes.Mob.BIOME_BOSS
local FLOOR_BANNER_WIDTH, BOSS_BANNER_WIDTH = 300, 560
local FLOOR_BAR_HEIGHT, BOSS_BAR_HEIGHT = 6, 18
local BANNER_TITLE_HEIGHT = 24

local bossBanner = makeFrame({
	Name = "FloorBossTopBanner",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(FLOOR_BANNER_WIDTH, 58),
	Position = UDim2.new(0.5, 0, 0, 14),
	BackgroundTransparency = 1,
	Parent = hudGui,
})

local function bannerText(name: string, size: number, role: string, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = ""
	label.TextSize = size
	label.TextColor3 = GildedGrimoire.Text.White
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.RichText = true
	label.ZIndex = 6
	label:SetAttribute("Grimoire", true)
	label.Parent = parent
	GildedGrimoire.StyleText(label, role)
	return label
end

local bossTitleLabel = bannerText("Title", 15, "Title", bossBanner)
bossTitleLabel.Size = UDim2.new(1, 0, 0, BANNER_TITLE_HEIGHT)
local bossTitleGradient = Instance.new("UIGradient")
bossTitleGradient.Enabled = false
do
	local stops = BOSS_THEME.TitleGradient or { BOSS_THEME.Title, BOSS_THEME.Title }
	local keys = {}
	for i, c in stops do table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#stops - 1), c)) end
	bossTitleGradient.Color = ColorSequence.new(keys)
end
bossTitleGradient.Parent = bossTitleLabel

local novaBarBg, novaBarFill = GildedGrimoire.Bar(bossBanner, GildedGrimoire.Text.Gold, 2.5)
novaBarBg.Position = UDim2.fromOffset(0, BANNER_TITLE_HEIGHT + 2)
novaBarBg.Size = UDim2.new(1, 0, 0, FLOOR_BAR_HEIGHT)
novaBarBg.BackgroundTransparency = 0.25
novaBarBg.ZIndex = 3
novaBarFill.ZIndex = 5
-- Pale trail behind the fill: it holds the old HP for a moment, then drains to the new value.
local bossHpTrail = Instance.new("Frame")
bossHpTrail.Name = "Trail"
bossHpTrail.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
bossHpTrail.BorderSizePixel = 0
bossHpTrail.Size = UDim2.fromScale(0, 1)
bossHpTrail.ZIndex = 4
bossHpTrail.Visible = false
do
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bossHpTrail
end
bossHpTrail.Parent = novaBarBg
local bossHpLabel = bannerText("Percent", 13, "Number", novaBarBg)
bossHpLabel.Size = UDim2.fromScale(1, 1)
bossHpLabel.Visible = false
-- One short line under the bar: kills, or the boss phase and the raid timer.
local novaCastLabel = bannerText("Caption", 12, "Body", bossBanner)
novaCastLabel.Size = UDim2.new(1, 0, 0, 16)
novaCastLabel.TextColor3 = GildedGrimoire.Text.Parchment
novaCastLabel.TextStrokeTransparency = 0

local bannerBossMode: boolean? = nil
local bossTrailFraction, bossTrailHoldUntil, bossTrailNetId = 1, 0, nil :: number?
-- Switches the strip between its floor and boss layouts (only when the mode or the screen changes).
local function setBannerMode(boss: boolean, force: boolean?)
	if bannerBossMode == boss and not force then return end
	bannerBossMode = boss
	local barHeight = if boss then BOSS_BAR_HEIGHT else FLOOR_BAR_HEIGHT
	local width = math.min(hudGui.AbsoluteSize.X - 32, if boss then BOSS_BANNER_WIDTH else FLOOR_BANNER_WIDTH)
	bossBanner.Size = UDim2.fromOffset(math.max(160, width), 58)
	bossTitleLabel.TextSize = if boss then 20 else 15
	bossTitleGradient.Enabled = boss
	novaBarBg.Size = UDim2.new(1, 0, 0, barHeight)
	novaCastLabel.Position = UDim2.fromOffset(0, BANNER_TITLE_HEIGHT + 2 + barHeight + 3)
	bossHpLabel.Visible = boss
	bossHpTrail.Visible = boss
end
setBannerMode(false, true)
hudGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	setBannerMode(bannerBossMode == true, true)
end)

--============================================================================
-- Clear Glass: alerts and tower banners share the HUD's glass (GildedGrimoire.Glass); a 2px
-- accent bar on the left carries the meaning colour.
--============================================================================
local Glass = GildedGrimoire.Glass
GildedGrimoire.Reframe(toastBanner, { Tone = "Glass", Rail = Glass.Arcane })
GildedGrimoire.Reframe(lootStolenBanner, { Tone = "Glass", Rail = Glass.Danger })
GildedGrimoire.GlassFrame(partialTooltipPopover, { Transparency = 0.12 })
-- Bounty hint: a solid Danger chip with a hairline edge.
GildedGrimoire.GlassFrame(bountyHint)
bountyHint.BackgroundColor3 = Glass.Danger
bountyHint.BackgroundTransparency = 0
bountyHint.TextColor3 = Glass.Text
-- Every label in these banners moves to Montserrat; headlines take the bold weight.
for _, banner in { toastBanner, lootStolenBanner, partialTooltipPopover } do
	GildedGrimoire.GlassTexts(banner)
end
for _, headline in { lootStolenText, tooltipTitle, toastText, bountyHint } do
	GildedGrimoire.GlassText(headline, "Title")
end
for _, line in { partialSubtext, tooltipList, tooltipFooter } do
	line:SetAttribute("Grimoire", true)
	GildedGrimoire.StyleText(line, "Body")
end
-- The two squad alerts have no panel: heavy inked headlines, and a fully outlined second line.
for _, headline in { squadWipeText, partialHeader } do
	headline:SetAttribute("Grimoire", true)
	GildedGrimoire.StyleText(headline, "Title")
end
partialSubtext.TextStrokeTransparency = 0

local updateClimbStreak = require(script.Parent.Hud.TowerStreakHud).Mount(bossBanner, bossTitleLabel, novaBarBg, TowerRemotes)

--============================================================================
-- 2. MODAL WINDOWS (`ThePit`, `Blacksmith`, `SquadController`)
--============================================================================

local squadController: any = nil
local promotionController: any = nil

local facilityController: any = nil
local fortressTreeController: any = nil
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
-- FLOATING ACTION MENU ICONS (SHOP, SQUAD, OVERDRIVE, RECALL, TOWER)
--============================================================================
local ACTION_COLORS = {
	Shop = Color3.fromRGB(250, 204, 21),       -- #FACC15 Gold
	Squad = Color3.fromRGB(56, 189, 248),      -- #38BDF8 Azure
	Overdrive = Color3.fromRGB(245, 158, 11),   -- #F59E0B Amber
	Recall = Color3.fromRGB(34, 211, 238),     -- #22D3EE Cyan
	Tower = Color3.fromRGB(192, 132, 252),     -- #C084FC Violet
	Fortress = Color3.fromRGB(214, 180, 120),  -- Parchment: the Fortress Tree (Phase 4)
}

local function triggerHUDWhistleCooldown(which: string)
	if which == "Q" then
		LastQClock = os.clock()
	elseif which == "E" then
		LastEClock = os.clock()
	end
end
_G.TriggerHUDWhistleCooldown = triggerHUDWhistleCooldown

local function showClientToast(msg: string)
	if KitNotify then KitNotify.Push("info", msg) return end
	playToast(msg, Color3.fromRGB(135, 225, 255), 3.5, false)
end

-- Floating Bottom HUD Toolbar Container
local floatingMenuContainer = Instance.new("Frame")
floatingMenuContainer.Name = "FloatingToolbar"
floatingMenuContainer.Size = UDim2.fromOffset(494, 96)
floatingMenuContainer.Position = UDim2.new(0.5, 0, 1, -16)
floatingMenuContainer.AnchorPoint = Vector2.new(0.5, 1)
floatingMenuContainer.BackgroundColor3 = Color3.fromRGB(13, 9, 18) -- #0D0912
floatingMenuContainer.BackgroundTransparency = 0.20
floatingMenuContainer.BorderSizePixel = 0
floatingMenuContainer.ZIndex = 12
floatingMenuContainer.Parent = hudGui
-- Phase 5: the bottom toolbar is replaced by the React Left/Right Rails (Phase5HudController).
-- It stays built, hidden, so the legacy highlight code keeps working until the HUD is retired.
floatingMenuContainer.Visible = false

local floatCorner = Instance.new("UICorner")
floatCorner.CornerRadius = UDim.new(0, 16)
floatCorner.Parent = floatingMenuContainer

local floatStroke = Instance.new("UIStroke")
floatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
floatStroke.Color = Color3.fromRGB(49, 39, 64) -- #312740
floatStroke.Thickness = 1.2
floatStroke.Parent = floatingMenuContainer

local floatingLayout = Instance.new("UIListLayout")
floatingLayout.FillDirection = Enum.FillDirection.Horizontal
floatingLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
floatingLayout.VerticalAlignment = Enum.VerticalAlignment.Center
floatingLayout.SortOrder = Enum.SortOrder.LayoutOrder
floatingLayout.Padding = UDim.new(0, 12)
floatingLayout.Parent = floatingMenuContainer

export type ActionButtonHandle = {
	Container: Frame,
	Button: ImageButton,
	Scale: UIScale,
	Disc: Frame?,
	DiscStroke: UIStroke?,
	VectorGlyph: ImageLabel?,
	ShadowGlow: ImageLabel?,
	KeybindPill: Frame?,
	CooldownText: TextLabel?,
	LabelPill: Frame,
	PillStroke: UIStroke,
	PillLabel: TextLabel,
	AccentColor: Color3,
	HasCooldown: boolean,
}

local function createFloatingIconButton(
	name: string,
	layoutOrder: number,
	keybindText: string?,
	labelText: string,
	accentColor: Color3,
	hasCooldown: boolean,
	onClick: () -> ()
): ActionButtonHandle
	local container = Instance.new("Frame")
	container.Name = name .. "Button"
	container.Size = UDim2.fromOffset(64, 82)
	container.BackgroundTransparency = 1
	container.LayoutOrder = layoutOrder
	container.ZIndex = 12
	container.Parent = floatingMenuContainer

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = container

	-- Create Vector Medallion Badge Base
	local badge = GothicVectorIcons.Create(name, {
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		AccentColor = accentColor,
		ZIndex = 12,
		Parent = container,
	})

	local disc = badge:FindFirstChild("ObsidianDisc") :: Frame?
	local discStroke = disc and disc:FindFirstChild("DiscBorder") :: UIStroke?
	local vectorGlyph = disc and disc:FindFirstChild("VectorGlyph") :: ImageLabel?
	local shadowGlow = disc and disc:FindFirstChild("ShadowGlow") :: ImageLabel?

	-- Hitbox Button on top (ZIndex 30)
	local btn = Instance.new("ImageButton")
	btn.Name = "Hitbox"
	btn.Size = UDim2.fromOffset(56, 56)
	btn.Position = UDim2.new(0.5, 0, 0, 0)
	btn.AnchorPoint = Vector2.new(0.5, 0)
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	btn.ZIndex = 30
	btn.Parent = container

	-- Optional Keybind Pill (e.g. [Q], [E]) at top-right
	local keybindPill: Frame? = nil
	if keybindText then
		keybindPill = Instance.new("Frame")
		keybindPill.Name = "KeybindPill"
		keybindPill.Size = UDim2.fromOffset(18, 18)
		keybindPill.Position = UDim2.new(1, 2, 0, -2)
		keybindPill.AnchorPoint = Vector2.new(1, 0)
		keybindPill.BackgroundColor3 = Color3.fromRGB(246, 244, 255)
		keybindPill.BorderSizePixel = 0
		keybindPill.ZIndex = 32

		local kpCorner = Instance.new("UICorner")
		kpCorner.CornerRadius = UDim.new(1, 0)
		kpCorner.Parent = keybindPill

		local kpStroke = Instance.new("UIStroke")
		kpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		kpStroke.Color = Color3.fromRGB(13, 9, 18)
		kpStroke.Thickness = 1
		kpStroke.Parent = keybindPill

		local kpLabel = Instance.new("TextLabel")
		kpLabel.Size = UDim2.fromScale(1, 1)
		kpLabel.BackgroundTransparency = 1
		kpLabel.Font = Enum.Font.GothamBold
		kpLabel.Text = keybindText
		kpLabel.TextSize = 11
		kpLabel.TextColor3 = Color3.fromRGB(13, 9, 18)
		kpLabel.ZIndex = 33
		kpLabel.Parent = keybindPill

		keybindPill.Parent = container
	end

	-- Cooldown Countdown Overlay (Only created if hasCooldown is true)
	local cdText: TextLabel? = nil
	if hasCooldown and disc then
		cdText = Instance.new("TextLabel")
		cdText.Name = "CooldownText"
		cdText.Size = UDim2.fromScale(1, 1)
		cdText.Position = UDim2.fromScale(0.5, 0.5)
		cdText.AnchorPoint = Vector2.new(0.5, 0.5)
		cdText.BackgroundTransparency = 1
		cdText.Font = Enum.Font.GothamBold
		cdText.Text = ""
		cdText.TextSize = 22
		cdText.TextColor3 = Color3.fromRGB(246, 244, 255)
		cdText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		cdText.TextStrokeTransparency = 0.2
		cdText.Visible = false
		cdText.ZIndex = 25
		cdText.Parent = disc
	end

	-- Bottom Text Label Pill (SHOP, SQUAD, OVERDRIVE, RECALL, TOWER)
	local labelPill = Instance.new("Frame")
	labelPill.Name = "LabelPill"
	labelPill.Size = UDim2.fromOffset(60, 18)
	labelPill.Position = UDim2.new(0.5, 0, 1, 0)
	labelPill.AnchorPoint = Vector2.new(0.5, 1)
	labelPill.BackgroundColor3 = Color3.fromRGB(13, 9, 18)
	labelPill.BorderSizePixel = 0
	labelPill.ZIndex = 14

	local lpCorner = Instance.new("UICorner")
	lpCorner.CornerRadius = UDim.new(1, 0)
	lpCorner.Parent = labelPill

	local lpStroke = Instance.new("UIStroke")
	lpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	lpStroke.Color = accentColor
	lpStroke.Thickness = 1
	lpStroke.Transparency = 0.5
	lpStroke.Parent = labelPill

	local lpLabel = Instance.new("TextLabel")
	lpLabel.Size = UDim2.fromScale(1, 1)
	lpLabel.BackgroundTransparency = 1
	lpLabel.Font = Enum.Font.GothamBold
	lpLabel.Text = labelText
	lpLabel.TextSize = 9
	lpLabel.TextColor3 = accentColor
	lpLabel.ZIndex = 15
	lpLabel.Parent = labelPill

	labelPill.Parent = container

	-- Hover & Click Micro-interactions
	local isHovered = false
	btn.MouseEnter:Connect(function()
		isHovered = true
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
		TweenService:Create(lpStroke, TweenInfo.new(0.2), { Transparency = 0.1 }):Play()
		if discStroke then
			TweenService:Create(discStroke, TweenInfo.new(0.2), { Thickness = 2.2 }):Play()
		end
	end)

	btn.MouseLeave:Connect(function()
		isHovered = false
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.0 }):Play()
		TweenService:Create(lpStroke, TweenInfo.new(0.2), { Transparency = 0.5 }):Play()
		if discStroke then
			TweenService:Create(discStroke, TweenInfo.new(0.2), { Thickness = 1.6 }):Play()
		end
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 0.94 }):Play()
	end)

	btn.MouseButton1Up:Connect(function()
		local targetScale = if isHovered then 1.15 else 1.0
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = targetScale }):Play()
	end)

	local lastClickTime = 0
	btn.Activated:Connect(function()
		local now = os.clock()
		if now - lastClickTime < 0.25 then return end
		lastClickTime = now
		onClick()
	end)

	return {
		Container = container,
		Button = btn,
		Scale = scale,
		Disc = disc,
		DiscStroke = discStroke,
		VectorGlyph = vectorGlyph,
		ShadowGlow = shadowGlow,
		KeybindPill = keybindPill,
		CooldownText = cdText,
		LabelPill = labelPill,
		PillStroke = lpStroke,
		PillLabel = lpLabel,
		AccentColor = accentColor,
		HasCooldown = hasCooldown,
	}
end

local function toggleShop()
	if facilityController and facilityController.Root and facilityController.Root.Visible and facilityController.Current == "Summoning" then
		facilityController:Close()
	else
		_G.OpenFacilityHUD("Summoning")
	end
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end
end
_G.ToggleShop = toggleShop
_G.OpenShop = toggleShop

-- 1. SHOP (Gold #FACC15, NO COOLDOWN)
local shopHandle = createFloatingIconButton(
	"Shop",
	1,
	nil,
	"SHOP",
	ACTION_COLORS.Shop,
	false,
	function()
		toggleShop()
	end
)

-- 2. SQUAD (Azure #38BDF8, NO COOLDOWN)
local squadHandle = createFloatingIconButton(
	"Squad",
	2,
	nil,
	"SQUAD",
	ACTION_COLORS.Squad,
	false,
	function()
		local isSquadOpen = squadController and squadController:IsOpen()
		_G.OpenMasterModal(isSquadOpen and "NONE" or "SQUAD")
	end
)

-- 3. OVERDRIVE (Amber #F59E0B, Keybind [Q], 20s COOLDOWN)
local overdriveHandle = createFloatingIconButton(
	"Overdrive",
	3,
	"Q",
	"OVERDRIVE",
	ACTION_COLORS.Overdrive,
	true,
	function()
		local now = os.clock()
		local qRem = math.max(0, 20.0 - (now - LastQClock))
		if qRem <= 0 then
			triggerHUDWhistleCooldown("Q")
			if WhistleCommandRemote then
				WhistleCommandRemote:FireServer(1)
			end
		end
	end
)

-- 4. RECALL (Cyan #22D3EE, Keybind [E], 6s COOLDOWN)
local recallHandle = createFloatingIconButton(
	"Recall",
	4,
	"E",
	"RECALL",
	ACTION_COLORS.Recall,
	true,
	function()
		local now = os.clock()
		local eRem = math.max(0, 6.0 - (now - LastEClock))
		if eRem <= 0 then
			triggerHUDWhistleCooldown("E")
			if WhistleCommandRemote then
				WhistleCommandRemote:FireServer(2)
			end
		end
	end
)

local function toggleTower()
	if _G.IsTowerSelectorOpen and _G.IsTowerSelectorOpen() then
		if _G.CloseTowerSelector then
			_G.CloseTowerSelector()
		end
	else
		if _G.OpenTowerSelector then
			_G.OpenTowerSelector()
		elseif _G.RequestTowerHub then
			local ok = _G.RequestTowerHub()
			if ok ~= false then
				showClientToast("To the Tower")
			end
		end
	end
	if _G.UpdateBottomTabHighlights then
		_G.UpdateBottomTabHighlights()
	end
end
_G.ToggleTower = toggleTower

-- 5. TOWER (Violet #C084FC, NO COOLDOWN)
local towerHandle = createFloatingIconButton(
	"Tower",
	5,
	nil,
	"TOWER",
	ACTION_COLORS.Tower,
	false,
	function()
		toggleTower()
	end
)

-- 6. UPGRADES (Parchment, NO COOLDOWN): the Fortress Tree, also opened at the Architect's Table.
local fortressHandle = createFloatingIconButton(
	"Fortress",
	6,
	nil,
	"UPGRADES",
	ACTION_COLORS.Fortress,
	false,
	function()
		if fortressTreeController and fortressTreeController:IsOpen() then
			fortressTreeController:Close()
		elseif _G.OpenFacilityHUD then
			_G.OpenFacilityHUD("FortressTree")
		end
	end
)

local function updateBottomTabHighlights()
	local squadActive = squadController ~= nil and squadController:IsOpen()
	if squadHandle.DiscStroke then
		squadHandle.DiscStroke.Thickness = if squadActive then 2.4 else 1.6
		squadHandle.DiscStroke.Color = if squadActive then Color3.fromRGB(230, 192, 112) else ACTION_COLORS.Squad
	end
	squadHandle.PillLabel.TextColor3 = if squadActive then Color3.fromRGB(230, 192, 112) else ACTION_COLORS.Squad
	squadHandle.PillStroke.Color = if squadActive then Color3.fromRGB(230, 192, 112) else ACTION_COLORS.Squad

	local shopActive = facilityController ~= nil and facilityController.Root ~= nil and facilityController.Root.Visible and facilityController.Current == "Summoning"
	if shopHandle.DiscStroke then
		shopHandle.DiscStroke.Thickness = if shopActive then 2.4 else 1.6
		shopHandle.DiscStroke.Color = if shopActive then Color3.fromRGB(255, 240, 160) else ACTION_COLORS.Shop
	end
	shopHandle.PillLabel.TextColor3 = if shopActive then Color3.fromRGB(255, 240, 160) else ACTION_COLORS.Shop
	shopHandle.PillStroke.Color = if shopActive then Color3.fromRGB(255, 240, 160) else ACTION_COLORS.Shop

	local towerActive = _G.IsTowerSelectorOpen ~= nil and _G.IsTowerSelectorOpen()
	if towerHandle.DiscStroke then
		towerHandle.DiscStroke.Thickness = if towerActive then 2.4 else 1.6
		towerHandle.DiscStroke.Color = if towerActive then Color3.fromRGB(230, 192, 112) else ACTION_COLORS.Tower
	end
	towerHandle.PillLabel.TextColor3 = if towerActive then Color3.fromRGB(230, 192, 112) else ACTION_COLORS.Tower
	towerHandle.PillStroke.Color = if towerActive then Color3.fromRGB(230, 192, 112) else ACTION_COLORS.Tower

	local fortressActive = fortressTreeController ~= nil and fortressTreeController:IsOpen()
	if fortressHandle.DiscStroke then
		fortressHandle.DiscStroke.Thickness = if fortressActive then 2.4 else 1.6
		fortressHandle.DiscStroke.Color = if fortressActive then Color3.fromRGB(255, 240, 160) else ACTION_COLORS.Fortress
	end
	fortressHandle.PillLabel.TextColor3 = if fortressActive then Color3.fromRGB(255, 240, 160) else ACTION_COLORS.Fortress
	fortressHandle.PillStroke.Color = if fortressActive then Color3.fromRGB(255, 240, 160) else ACTION_COLORS.Fortress
end
_G.UpdateBottomTabHighlights = updateBottomTabHighlights

--============================================================================
-- WINDOW REGISTRY (UI overhaul plan §4.1)
-- Every modal window, for WindowManager: one open at a time, Backspace / gamepad B to the topmost one,
-- animated close. Windows owned by other scripts (React panels, Settings, the Tower selector) are
-- reached through their _G functions at call time, so load order doesn't matter.
--============================================================================
local function g(name: string): any return (_G :: any)[name] end
WindowManager.Register("Backpack", {
	IsOpen = function() return g("IsBackpackOpen") ~= nil and g("IsBackpackOpen")() end,
	Close = function() if g("CloseBackpack") then g("CloseBackpack")() end end,
})
WindowManager.Register("Index", { -- Hero/Artifact Index and the Store share one panel slot
	IsOpen = function() return g("IsHeroIndexOpen") ~= nil and g("IsHeroIndexOpen")() end,
	Close = function() if g("CloseHeroIndex") then g("CloseHeroIndex")() end end,
})
WindowManager.Register("FacilityPanel", {
	IsOpen = function() return g("IsFacilityPanelOpen") ~= nil and g("IsFacilityPanelOpen")() end,
	Close = function() if g("CloseFacilityPanel") then g("CloseFacilityPanel")() end end,
	HudCurrency = true,
})
WindowManager.Register("Tower", {
	IsOpen = function() return g("IsTowerSelectorOpen") ~= nil and g("IsTowerSelectorOpen")() end,
	Close = function() if g("CloseTowerSelector") then g("CloseTowerSelector")() end end,
	OwnsBack = true, -- TowerController handles Backspace / B itself
})
WindowManager.Register("Settings", {
	IsOpen = function() return g("IsSettingsOpen") ~= nil and g("IsSettingsOpen")() end,
	Close = function() if g("CloseSettings") then g("CloseSettings")() end end,
	-- Settings asks before discarding unapplied changes.
	Back = function() return g("SettingsBack") ~= nil and g("SettingsBack")() end,
})
WindowManager.Register("Facility", {
	IsOpen = function() return facilityController ~= nil and facilityController:IsOpen() end,
	Close = function() facilityController:Close() end,
	Root = function() return facilityController and facilityController.Root end,
	HudCurrency = true,
})
WindowManager.Register("Fortress", {
	IsOpen = function() return fortressTreeController ~= nil and fortressTreeController:IsOpen() end,
	Close = function() fortressTreeController:Close() end,
	HudCurrency = true,
})
WindowManager.Register("Synthesis", {
	IsOpen = function() return synthesisController ~= nil and synthesisController.Root ~= nil and synthesisController.Root.Visible end,
	Close = function() synthesisController:Close() end,
	Root = function() return synthesisController and synthesisController.Root end,
})
WindowManager.Register("Promotion", {
	IsOpen = function() return promotionController ~= nil and promotionController:IsOpen() end,
	Close = function() promotionController:Close() end,
	Back = function() return promotionController ~= nil and promotionController.Back ~= nil and promotionController:Back() end,
	Root = function() return promotionController and promotionController.Root end,
})
WindowManager.Register("Forge", {
	IsOpen = function() return forgeController ~= nil and forgeController:IsOpen() end,
	Close = function() forgeController:Close() end,
	OwnsBack = true, -- the Workbench steps back through dialogs and routes on Backspace / B itself
})
WindowManager.Register("Squad", {
	IsOpen = function() return squadController ~= nil and squadController:IsOpen() end,
	Close = function() squadController:Close() end,
	Root = function() return squadController and squadController.Root end,
})
_G.WindowManager = WindowManager

-- A window that finishes its close animation may be the last one: drop focus mode then.
WindowManager.Changed:Connect(function(_, open: boolean)
	if not open then setModalFocusMode(false) end
end)

-- OpenMasterModal's names for the windows it keeps open.
local MASTER_KEEP = {
	INDEX = "Index", SHOP = "Index", FACILITY = "FacilityPanel", SETTINGS = "Settings",
	BLACKSMITH = "Forge", SQUAD = "Squad", WAITING_ROOM = "Squad",
}

_G.IsAnyMasterModalOpen = function(): boolean
	return WindowManager.IsAnyOpen() or blacksmithModal.Visible
end
_G.OpenMasterModal = function(which: string)
	-- One window at a time: close everything but the one being opened (animated).
	WindowManager.CloseAll(MASTER_KEEP[which])
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
	if which == "BLACKSMITH" and not forgeController and refreshBlacksmithModal then
		refreshBlacksmithModal()
	end
	if MASTER_KEEP[which] then WindowManager.Opened(MASTER_KEEP[which]) end
	if which == "NONE" then
		setModalFocusMode(false)
	else
		setModalFocusMode(true)
	end
end

-- Add Top Bar Navigation Buttons
makeButton({
	Size = UDim2.new(0, 118, 1, 0),
	BackgroundColor3 = Color3.fromRGB(45, 115, 205),
	Text = "Squad Deploy",
	Corner = 6,
	OnClick = function()
		if squadController then
			squadController:Toggle()
		end
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
local FortressTreeController = require(script.Parent:WaitForChild("FortressTreeController"))
fortressTreeController = FortressTreeController.new(hudGui, function() return CurrentProfile end, Remotes:WaitForChild("ProgressionRemotes"))
local SynthesisController = require(script.Parent:WaitForChild("SynthesisController"))
synthesisController = SynthesisController.new(hudGui, TycoonRemotes:WaitForChild("PitRequest") :: RemoteFunction)
_G.SynthesisController = synthesisController
local ForgeController = require(script.Parent:WaitForChild("ForgeWorkbenchController"))
local ArtifactRemotes = Remotes:WaitForChild("ArtifactRemotes") :: Folder
forgeController = ForgeController.new(hudGui, ArtifactRemotes, function() return CurrentProfile end, updateBottomTabHighlights)
-- Every window's own close button now leaves through WindowManager (one close animation for all).
for id, controller in { Squad = squadController, Promotion = promotionController, Facility = facilityController,
	Fortress = fortressTreeController, Synthesis = synthesisController, Forge = forgeController } do
	WindowManager.Route(id, controller)
end
_G.ForgeController = forgeController
_G.OpenFacilityHUD = function(facility: string)
	setModalFocusMode(true)
	-- Phase 5: The Pit has one prompt and opens on its Synthesis tab (the React tab bar switches).
	if facility == "Pit" or facility == "ThePit" then
		facility = "Synthesis"
	end
	if facility == "Synthesis" then
		-- Focused synthesis HUD: recipient slot, level preview and material slots.
		_G.OpenMasterModal("NONE")
		if forgeController then forgeController:Close() end
		if promotionController then promotionController:Close() end
		synthesisController:Open()
		WindowManager.Opened("Synthesis")
	elseif facility == "Promotion" then
		-- Dedicated Hero Promotion Ritual HUD matching the Gothic Ascension Mockup.
		_G.OpenMasterModal("NONE")
		if forgeController then forgeController:Close() end
		if synthesisController then synthesisController:Close() end
		promotionController:Open()
		WindowManager.Opened("Promotion")
	elseif facility == "SquadManagement" or facility == "Squad" then
		_G.OpenMasterModal("SQUAD")
	elseif _G.OpenFacilityPanel and (facility == "GuardPost" or facility == "Market" or facility == "TrainingGrounds" or facility == "GodsBlessing") then
		-- Phase 5 §4.5: support facilities open the gothic React panel.
		_G.OpenFacilityPanel(facility)
		WindowManager.Opened("FacilityPanel")
	elseif facility == "FortressTree" then
		_G.OpenMasterModal("NONE")
		fortressTreeController:Open()
		WindowManager.Opened("Fortress")
		updateBottomTabHighlights()
	elseif facility == "Blacksmith" or facility == "Forge" then
		_G.OpenMasterModal("BLACKSMITH")
	else
		_G.OpenMasterModal("NONE")
		if synthesisController then synthesisController:Close() end
		if promotionController then promotionController:Close() end
		if forgeController then forgeController:Close() end
		facilityController:Open(facility)
		WindowManager.Opened("Facility")
	end
end

--============================================================================
-- 5. BUILD THE BLACKSMITH MODAL (EQUIPPABLE ARTIFACTS & 16-TIER RARITY FORGE)
--============================================================================

makeLabel({
	Size = UDim2.new(0.75, 0, 0, 36),
	Position = UDim2.new(0.02, 0, 0, 6),
	Text = "BLACKSMITH FORGE — HERO ARTIFACTS & 16 RARITY TIERS (COMMON -> ORIGIN)",
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
	if not blacksmithModal.Visible then return end
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
				Text = string.format("UNEQUIP FROM %s", equippedHeroName),
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
		for _, key in {"Currencies", "PitMaterials", "PitRevision", "ForgeRevision", "UnlockedResearch", "SquadPower", "SquadPowerByHero"} do
			if profile[key] ~= nil then CurrentProfile[key] = profile[key] end
		end
		profile = CurrentProfile
	else CurrentProfile = profile end
	_G.CurrentProfile = CurrentProfile
	facilityController:Refresh()
	if fortressTreeController and fortressTreeController:IsOpen() then
		fortressTreeController:Refresh()
	end
	-- Note: SynthesisController and PromotionController fetch STATE on Open()
	-- and reconcile on COMMIT. Do NOT auto-refresh them on ProfileDeltaSyncEvent
	-- as it fires continuously (every 3s passive gold tick, combat) and causes network/render lag.
	if forgeController and forgeController.Root and forgeController.Root.Visible then
		forgeController:Refresh()
	end

	currencyLabel.Text = string.format(
		" GOLD: %d    GEMS: %d",
		math.floor(profile.Currencies.Gold),
		math.floor(profile.Currencies.Gems)
	)

	if squadController and squadController:IsOpen() then
		squadController:Refresh()
	end
	if blacksmithModal.Visible and refreshBlacksmithModal then
		refreshBlacksmithModal()
	end
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local cs = _G.ClientCombatState

	-- 1. Whistle Cooldowns & Devouring Nova Recall Skill-Check Pulse
	local qRem = math.max(0, 20.0 - (now - LastQClock))
	if qRem > 0 then
		if overdriveHandle.CooldownText then
			overdriveHandle.CooldownText.Visible = true
			overdriveHandle.CooldownText.Text = tostring(math.ceil(qRem))
		end
		if overdriveHandle.KeybindPill then overdriveHandle.KeybindPill.Visible = false end
		if overdriveHandle.VectorGlyph then
			overdriveHandle.VectorGlyph.ImageColor3 = Color3.fromRGB(120, 120, 130)
			overdriveHandle.VectorGlyph.ImageTransparency = 0.7
		end
		if overdriveHandle.ShadowGlow then overdriveHandle.ShadowGlow.Visible = false end
		if overdriveHandle.DiscStroke then overdriveHandle.DiscStroke.Color = Color3.fromRGB(49, 39, 64) end
		overdriveHandle.PillStroke.Color = Color3.fromRGB(49, 39, 64)
		overdriveHandle.PillLabel.TextColor3 = Color3.fromRGB(120, 115, 130)
	else
		if overdriveHandle.CooldownText then overdriveHandle.CooldownText.Visible = false end
		if overdriveHandle.KeybindPill then overdriveHandle.KeybindPill.Visible = true end
		if overdriveHandle.VectorGlyph then
			overdriveHandle.VectorGlyph.ImageColor3 = ACTION_COLORS.Overdrive
			overdriveHandle.VectorGlyph.ImageTransparency = 0
		end
		if overdriveHandle.ShadowGlow then overdriveHandle.ShadowGlow.Visible = true end
		if overdriveHandle.DiscStroke then overdriveHandle.DiscStroke.Color = ACTION_COLORS.Overdrive end
		overdriveHandle.PillStroke.Color = ACTION_COLORS.Overdrive
		overdriveHandle.PillLabel.TextColor3 = ACTION_COLORS.Overdrive
	end

	local eRem = math.max(0, 6.0 - (now - LastEClock))
	local novaStart = cs and cs.NovaCastStartClock or 0
	local novaElapsed = if novaStart > 0 then (now - novaStart) else 999
	local inNovaOptimalWindow = (novaElapsed >= 1.1 and novaElapsed <= 2.8)

	if inNovaOptimalWindow then
		if recallHandle.CooldownText then recallHandle.CooldownText.Visible = false end
		if recallHandle.KeybindPill then recallHandle.KeybindPill.Visible = true end
		if recallHandle.VectorGlyph then
			recallHandle.VectorGlyph.ImageColor3 = Color3.fromRGB(255, 230, 80)
			recallHandle.VectorGlyph.ImageTransparency = 0
		end
		if recallHandle.ShadowGlow then
			recallHandle.ShadowGlow.Visible = true
			recallHandle.ShadowGlow.ImageColor3 = Color3.fromRGB(255, 230, 80)
		end
		if recallHandle.DiscStroke then recallHandle.DiscStroke.Color = Color3.fromRGB(255, 230, 80) end
		recallHandle.PillStroke.Color = Color3.fromRGB(255, 230, 80)
		recallHandle.PillLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	elseif eRem > 0 then
		if recallHandle.CooldownText then
			recallHandle.CooldownText.Visible = true
			recallHandle.CooldownText.Text = tostring(math.ceil(eRem))
		end
		if recallHandle.KeybindPill then recallHandle.KeybindPill.Visible = false end
		if recallHandle.VectorGlyph then
			recallHandle.VectorGlyph.ImageColor3 = Color3.fromRGB(120, 120, 130)
			recallHandle.VectorGlyph.ImageTransparency = 0.7
		end
		if recallHandle.ShadowGlow then recallHandle.ShadowGlow.Visible = false end
		if recallHandle.DiscStroke then recallHandle.DiscStroke.Color = Color3.fromRGB(49, 39, 64) end
		recallHandle.PillStroke.Color = Color3.fromRGB(49, 39, 64)
		recallHandle.PillLabel.TextColor3 = Color3.fromRGB(120, 115, 130)
	else
		if recallHandle.CooldownText then recallHandle.CooldownText.Visible = false end
		if recallHandle.KeybindPill then recallHandle.KeybindPill.Visible = true end
		if recallHandle.VectorGlyph then
			recallHandle.VectorGlyph.ImageColor3 = ACTION_COLORS.Recall
			recallHandle.VectorGlyph.ImageTransparency = 0
		end
		if recallHandle.ShadowGlow then
			recallHandle.ShadowGlow.Visible = true
			recallHandle.ShadowGlow.ImageColor3 = ACTION_COLORS.Recall
		end
		if recallHandle.DiscStroke then recallHandle.DiscStroke.Color = ACTION_COLORS.Recall end
		recallHandle.PillStroke.Color = ACTION_COLORS.Recall
		recallHandle.PillLabel.TextColor3 = ACTION_COLORS.Recall
	end

	-- 2. Update World Boss Top Banner & Devouring Nova Cast Bar
	local floorBoss = cs and cs.FloorBoss
	local hasFloorBoss = floorBoss and floorBoss.Enabled == true
	local char = LocalPlayer.Character
	local charFloor = if char then (char:GetAttribute("TowerFloorId") or 0) else 0
	local curFloor = if charFloor > 0 then charFloor elseif (_G.TowerView and _G.TowerView.FloorId) then _G.TowerView.FloorId else 0
	if charFloor == 0 then
		curFloor = 0
	end
	local inRaid = curFloor == RAID_FLOOR
	local hideFloorHud = curFloor > 0 and (Store.ModalFocus or (_G.IsAnyMasterModalOpen and _G.IsAnyMasterModalOpen()))
	if inRaid and not hasFloorBoss then
		-- Raid arena: the banner only shows the boss (staging, results and the timer live in RaidHud).
		bossBanner.Visible = false
	elseif not hasFloorBoss and curFloor > 0 then
		bossBanner.Visible = not hideFloorHud
		setBannerMode(false)
		local floorSpec = TowerFloorConfig.Get(curFloor)
		local floorName = floorSpec and floorSpec.DisplayName or ("Floor " .. tostring(curFloor))
		local curKills = if clientFloorProgress.FloorId == curFloor then clientFloorProgress.CurrentKills else 0
		local reqKills = if clientFloorProgress.FloorId == curFloor and clientFloorProgress.RequiredKills > 0 then clientFloorProgress.RequiredKills else math.max(1, math.round(12 + 0.5 * curFloor))
		local pct = math.clamp(curKills / math.max(1, reqKills), 0, 1)
		bossTitleLabel.Text = string.format("FLOOR %d  ·  %s", curFloor, string.upper(floorName))
		novaBarFill.Size = UDim2.fromScale(pct, 1)
		novaBarFill.BackgroundColor3 = if curKills >= reqKills then GildedGrimoire.Text.Good else GildedGrimoire.Text.Gold
		-- Recommended Squad Power only speaks up when the squad is under it.
		local recommended = recommendedPower(curFloor)
		local mine = CurrentProfile and CurrentProfile.SquadPower or 0 -- the same Squad Power as the badge
		local warning = if mine < recommended then string.format("  ·  <font color=\"#FF6B6B\">REC. POWER %s</font>", abbreviatePower(recommended)) else ""
		if clientFloorProgress.FloorId == curFloor and clientFloorProgress.BossDefeated then
			novaCastLabel.Text = "<font color=\"#78FF8C\">CLEARED</font>"
		elseif curKills >= reqKills then
			novaCastLabel.Text = "<font color=\"#FF7A7A\">BOSS SUMMONED</font>" .. warning
		else
			novaCastLabel.Text = string.format("%d / %d", curKills, reqKills) .. warning
		end
	else
		bossBanner.Visible = (hasFloorBoss and curFloor > 0 and not hideFloorHud) or false
	end
	if hasFloorBoss and curFloor > 0 then
		setBannerMode(true)
		local node = cs.VisualNodes and cs.VisualNodes[floorBoss.NetId]
		local hpPct = if node and node.HpPermille then node.HpPermille / 10.0 else (floorBoss.CurrentHP or 1) / math.max(1, floorBoss.MaxHP or 1) * 100.0
		local phase = if hpPct <= 50.0 then 2 else (floorBoss.Phase or 1)
		local fraction = math.clamp(hpPct / 100.0, 0, 1)
		bossTitleLabel.Text = string.upper(floorBoss.Name or (if inRaid then "RAID BOSS" else "FLOOR BOSS"))
		novaBarFill.Size = UDim2.fromScale(fraction, 1)
		novaBarFill.BackgroundColor3 = BOSS_THEME.Accent
		bossHpLabel.Text = if hpPct >= 10 then string.format("%d%%", math.ceil(hpPct)) else string.format("%.1f%%", hpPct)
		-- Damage trail: hold for a beat after a hit, then drain towards the fill.
		local now = os.clock()
		if bossTrailNetId ~= floorBoss.NetId or fraction >= bossTrailFraction then
			bossTrailNetId, bossTrailFraction, bossTrailHoldUntil = floorBoss.NetId, fraction, 0
		else
			if bossTrailHoldUntil == 0 then bossTrailHoldUntil = now + 0.35 end
			if now >= bossTrailHoldUntil then
				bossTrailFraction = math.max(fraction, bossTrailFraction - 0.012)
			end
		end
		bossHpTrail.Size = UDim2.fromScale(bossTrailFraction, 1)
		local caption = if phase >= 2 then "<font color=\"#FF7A7A\">ENRAGED</font>" else ""
		if inRaid then
			local endsAt = ReplicatedStorage:GetAttribute("RaidEndsAt") or 0
			local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
			caption = string.format("%s%s%d:%02d", caption, if caption ~= "" then "  ·  " else "", left // 60, left % 60)
		end
		novaCastLabel.Text = caption
	end
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local personalFloor = TowerFloorConfig.IsFloorId(charFloor) and not Store.ViewingSquad and humanoid ~= nil and humanoid.Health > 0
	updateClimbStreak(charFloor, personalFloor, if CurrentProfile then CurrentProfile.HighestClearedFloor or 0 else 0)
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
	hudGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
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
	modalBackdrop.BackgroundTransparency = 1 -- no dim behind modals
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
		return GothicBoxStyle.Apply(container, {
			Style = if isCompact then "Compact" else "Card",
			ZIndex = baseZ,
		}) :: Frame
	end



	-- Remove top menu bar so the viewport top is unobstructed and currencies live in the bottom-left
	topBar.Visible = false
	currencyLabel.Visible = false

	-- Bottom-left Gold & Diamond Currency Display
	-- Total row width locked to Squad container bar width (W_squad = 296px).
	-- Two equal split pills with 8px gap: (296 - 8) / 2 = 144px -> UDim2.new(0.5, -4, 1, 0).
	local SQUAD_BAR_WIDTH = 296
	local CURRENCY_GAP = 8
	local CURRENCY_HEIGHT = 32

	local currencyCluster = Instance.new("Frame")
	currencyCluster.Name = "CurrencyCluster"
	currencyCluster.BackgroundTransparency = 1
	currencyCluster.BorderSizePixel = 0
	currencyCluster.Size = UDim2.fromOffset(SQUAD_BAR_WIDTH, CURRENCY_HEIGHT)
	currencyCluster.AnchorPoint = Vector2.new(0, 1)
	currencyCluster.Position = UDim2.new(0, 20, 1, -20)
	-- Phase 5: Gold and Gems are drawn by the React HUD (HudApp/Components) above the Squad Status Card.
	currencyCluster.Visible = false
	currencyCluster.ZIndex = 8
	currencyCluster.Parent = hudGui

	local clusterLayout = Instance.new("UIListLayout")
	clusterLayout.Name = "ClusterLayout"
	clusterLayout.FillDirection = Enum.FillDirection.Horizontal
	clusterLayout.SortOrder = Enum.SortOrder.LayoutOrder
	clusterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	clusterLayout.Padding = UDim.new(0, CURRENCY_GAP)
	clusterLayout.Parent = currencyCluster

	local currencyFields: { [string]: TextLabel } = {}
	local currencies = {
		{ "Gold", P.gold },
		{ "Gems", P.cyan },
	}
	for i, item in currencies do
		local row = Instance.new("Frame")
		row.Name = item[1] .. "Display"
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(0.5, -math.floor(CURRENCY_GAP / 2), 1, 0)
		row.LayoutOrder = i
		row.Parent = currencyCluster

		local rowPadding = Instance.new("UIPadding")
		rowPadding.Name = "RowPadding"
		rowPadding.PaddingLeft = UDim.new(0, 10)
		rowPadding.PaddingRight = UDim.new(0, 10)
		rowPadding.Parent = row

		local rowLayout = Instance.new("UIListLayout")
		rowLayout.Name = "RowLayout"
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.Padding = UDim.new(0, 6)
		rowLayout.Parent = row

		local icon = GothicVectorIcons.Create(item[1] :: string, {
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromOffset(0, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			ZIndex = 11,
			Parent = row,
		})
		icon.LayoutOrder = 1

		local lbl = Instance.new("TextLabel")
		lbl.Name = item[1] .. "Value"
		lbl.BackgroundTransparency = 1
		lbl.BorderSizePixel = 0
		lbl.Size = UDim2.new(1, -26, 1, 0)
		lbl.LayoutOrder = 2
		lbl.Text = if item[1] == "Gold" then "500" else "300"
		lbl.TextColor3 = item[2] :: Color3
		lbl.Font = Enum.Font.Fantasy
		lbl.TextSize = 16
		lbl.TextScaled = false
		lbl.TextStrokeColor3 = Color3.fromRGB(12, 8, 18)
		lbl.TextStrokeTransparency = 0.2
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Center
		lbl.ZIndex = 11
		lbl.Parent = row

		local textConstraint = Instance.new("UITextSizeConstraint")
		textConstraint.MaxTextSize = 18
		textConstraint.Parent = lbl

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

	-- Top-right Setting Icon Button (Roblox TopBar style matched circular button in dedicated topbar overlay)
	local topBarRightGui = PlayerGui:FindFirstChild("TopBarRightScreenGui") :: ScreenGui?
	if not topBarRightGui then
		topBarRightGui = Instance.new("ScreenGui")
		topBarRightGui.Name = "TopBarRightScreenGui"
		topBarRightGui.ResetOnSpawn = false
		topBarRightGui.IgnoreGuiInset = true
		topBarRightGui.ScreenInsets = Enum.ScreenInsets.None
		topBarRightGui.DisplayOrder = 10
		topBarRightGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		topBarRightGui.Parent = PlayerGui
	end
	topBarRightGui.Enabled = not isFocusModeActive

	local settingsButton = Instance.new("ImageButton")
	settingsButton.Name = "SettingsButton"
	settingsButton:SetAttribute("NoFeel", true) -- Disable spring hover/press scaling from UIFeel (does not enlarge when hovered)
	settingsButton.AnchorPoint = Vector2.new(1, 0)
	settingsButton.Position = UDim2.new(1, -16, 0, 12)
	settingsButton.Size = UDim2.fromOffset(44, 44)
	settingsButton.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
	settingsButton.BackgroundTransparency = 0.15
	settingsButton.AutoButtonColor = false
	settingsButton.ZIndex = 15
	settingsButton.Visible = true
	settingsButton.Parent = topBarRightGui

	local settingsCorner = Instance.new("UICorner")
	settingsCorner.CornerRadius = UDim.new(1, 0)
	settingsCorner.Parent = settingsButton

	local settingsStroke = Instance.new("UIStroke")
	settingsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	settingsStroke.Thickness = 1
	settingsStroke.Color = Color3.fromRGB(45, 45, 52)
	settingsStroke.Transparency = 0.6
	settingsStroke.Parent = settingsButton

	local gearIcon = Instance.new("ImageLabel")
	gearIcon.Name = "GearIcon"
	gearIcon.Image = "rbxassetid://116900178322793"
	gearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	gearIcon.Position = UDim2.fromScale(0.5, 0.5)
	gearIcon.Size = UDim2.fromOffset(26, 26)
	gearIcon.BackgroundTransparency = 1
	gearIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	gearIcon.ScaleType = Enum.ScaleType.Fit
	gearIcon.ZIndex = 16
	gearIcon.Parent = settingsButton

	-- Highlight overlay (matching Roblox TopBar StateOverlayRound: lightens the circle on hover/press with no animations)
	local stateOverlay = Instance.new("Frame")
	stateOverlay.Name = "StateOverlayRound"
	stateOverlay.Size = UDim2.fromScale(1, 1)
	stateOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	stateOverlay.BackgroundTransparency = 1
	stateOverlay.ZIndex = 17

	local stateOverlayCorner = Instance.new("UICorner")
	stateOverlayCorner.CornerRadius = UDim.new(1, 0)
	stateOverlayCorner.Parent = stateOverlay
	stateOverlay.Parent = settingsButton

	settingsButton.MouseEnter:Connect(function()
		stateOverlay.BackgroundTransparency = 0.88
	end)

	settingsButton.MouseLeave:Connect(function()
		stateOverlay.BackgroundTransparency = 1
	end)

	settingsButton.MouseButton1Down:Connect(function()
		stateOverlay.BackgroundTransparency = 0.75
	end)

	settingsButton.MouseButton1Up:Connect(function()
		stateOverlay.BackgroundTransparency = 0.88
	end)

	local lastSettingsToggleTime = 0
	local function onSettingsTrigger()
		local now = os.clock()
		if now - lastSettingsToggleTime < 0.25 then return end
		lastSettingsToggleTime = now

		if _G.ToggleSettings then
			_G.ToggleSettings()
		end
	end
	settingsButton.Activated:Connect(onSettingsTrigger)

	-- Keep Studio F8 development hooks available without the top menu bar (positioned to the left of settings button)
	navButtonsFrame.Parent = topBarRightGui
	navButtonsFrame.AnchorPoint = Vector2.new(1, 0)
	navButtonsFrame.Position = UDim2.new(1, -68, 0, 12)
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
		-- Backspace / gamepad B: WindowManager closes only the topmost window (or steps back inside it).
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


--============================================================================
	local modalWidths = { 1000 }
	local function layout()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local view = cam.ViewportSize
		local w, h = view.X, math.max(300, view.Y - 40)
		local portrait = w < 650
		local stackPanels = portrait or h < 540



		topBar.Visible = false

		-- The top-centre tower strip sizes itself (setBannerMode).

		toastBanner.AnchorPoint = Vector2.new(0.5, 0)
		toastBanner.Position = UDim2.new(0.5, 0, 0, 82)
		toastBanner.Size = UDim2.new(0, math.min(w - 32, 650), 0, 46)


		-- Responsive positioning and scaling for Currencies and Floating Toolbar
		local isNarrow = w < 720
		currencyCluster.AnchorPoint = Vector2.new(0, 1)
		currencyCluster.Position = if isNarrow then UDim2.new(0, 14, 1, -100) else UDim2.new(0, 20, 1, -20)
		currencyCluster.Size = UDim2.fromOffset(SQUAD_BAR_WIDTH, CURRENCY_HEIGHT)
		local moneyScale = currencyCluster:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", currencyCluster)
		moneyScale.Scale = portrait and math.min(1, (w - 48) / SQUAD_BAR_WIDTH) or 1

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
