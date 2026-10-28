--!strict
-- StarterPlayerScripts/UI/OfflineRewardModal.client.luau
-- Displays "Welcome Back, Master!" Offline Accumulation Modal (GDD Sections 2.4 & 4.3)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TycoonRemotes = Remotes:WaitForChild("TycoonGachaRemotes")
local OfflineRewardEvent = TycoonRemotes:WaitForChild("OfflineRewardClaimed") :: RemoteEvent
local Util = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util")
local GothicBoxStyle = require(Util:WaitForChild("GothicBoxStyle"))
local GildedGrimoire = require(Util:WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(Util:WaitForChild("GrimoireIcons"))

local C = {
	Scrim = Color3.fromRGB(6, 5, 10),
	Panel = Color3.fromRGB(16, 13, 24),
	CardBg = Color3.fromRGB(25, 21, 38),
	Border = Color3.fromRGB(245, 195, 75),
	BorderGlow = Color3.fromRGB(215, 165, 45),
	BorderCard = Color3.fromRGB(75, 60, 95),
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(160, 150, 180),
	GoldYellow = Color3.fromRGB(250, 204, 21),
	Green = Color3.fromRGB(74, 222, 128),
}

local function createModalGui(): (ScreenGui, Frame, Frame, TextLabel, TextLabel, TextLabel, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "OfflineRewardScreenGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = PlayerGui

	local scrim = Instance.new("Frame")
	scrim.Name = "Scrim"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = C.Scrim
	scrim.BackgroundTransparency = 0.35
	scrim.Visible = false
	scrim.Parent = gui

	local modal = Instance.new("Frame")
	modal.Name = "ModalFrame"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromOffset(560, 420)
	modal.BackgroundColor3 = C.Panel
	modal.BorderSizePixel = 0
	modal.Visible = false
	modal.Parent = gui

	-- Gilded Grimoire window (ink outline, gold rail and corner studs) with theme fonts.
	GothicBoxStyle.Apply(modal, { Style = "Window" })
	GildedGrimoire.Watch(modal)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 36)
	title.Position = UDim2.fromOffset(20, 24)
	title.BackgroundTransparency = 1
	title.Text = "WELCOME BACK, MASTER!"
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 22
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = modal
	local titleGold = Instance.new("UIGradient")
	titleGold.Rotation = 90
	titleGold.Color = ColorSequence.new(Color3.new(1, 1, 1), GildedGrimoire.Text.Gold)
	titleGold.Parent = title

	local sub = Instance.new("TextLabel")
	sub.Name = "Subtitle"
	sub.Size = UDim2.new(1, -40, 0, 22)
	sub.Position = UDim2.fromOffset(20, 62)
	sub.BackgroundTransparency = 1
	sub.Text = "YOUR STATIONED ADVENTURERS DEFENDED THE OUTSKIRTS"
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 12
	sub.TextColor3 = C.TextMuted
	sub.Parent = modal

	local card = Instance.new("Frame")
	card.Name = "RewardCard"
	card.Size = UDim2.new(1, -48, 0, 190)
	card.Position = UDim2.fromOffset(24, 100)
	card.BackgroundColor3 = C.CardBg
	card.BorderSizePixel = 0
	card.Parent = modal

	GildedGrimoire.Frame(card, { Class = "Card", Tone = "Bronze" })
	-- A drawn gold-coin stack beside the amount.
	local coin = GrimoireIcons.Create("Gold", 52, card, 3)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 24, 0, 50)

	local goldDisplay = Instance.new("TextLabel")
	goldDisplay.Name = "GoldDisplay"
	goldDisplay.Size = UDim2.new(1, -20, 0, 60)
	goldDisplay.Position = UDim2.fromOffset(10, 20)
	goldDisplay.BackgroundTransparency = 1
	goldDisplay.Text = "+0 GOLD"
	goldDisplay.Font = Enum.Font.GothamBlack
	goldDisplay.TextSize = 34
	goldDisplay.TextColor3 = C.GoldYellow
	goldDisplay.Parent = card

	local details = Instance.new("TextLabel")
	details.Name = "Details"
	details.Size = UDim2.new(1, -24, 0, 80)
	details.Position = UDim2.fromOffset(12, 90)
	details.BackgroundTransparency = 1
	details.Text = ""
	details.Font = Enum.Font.GothamMedium
	details.TextSize = 14
	details.TextColor3 = C.Text
	details.RichText = true
	details.Parent = card

	local claimBtn = Instance.new("TextButton")
	claimBtn.Name = "ClaimButton"
	claimBtn.AnchorPoint = Vector2.new(0.5, 1)
	claimBtn.Position = UDim2.new(0.5, 0, 1, -24)
	claimBtn.Size = UDim2.fromOffset(260, 46)
	claimBtn.BackgroundColor3 = Color3.fromRGB(32, 26, 48)
	claimBtn.BorderSizePixel = 0
	claimBtn.Text = "CLAIM & CONTINUE"
	claimBtn.Font = Enum.Font.GothamBold
	claimBtn.TextSize = 15
	claimBtn.TextColor3 = C.GoldYellow
	claimBtn.AutoButtonColor = true
	claimBtn.Parent = modal

	claimBtn.AutoButtonColor = false
	claimBtn.TextColor3 = Color3.new(1, 1, 1)
	GothicBoxStyle.Apply(claimBtn, { Style = "Button" })
	claimBtn.TextStrokeColor3 = GildedGrimoire.Ink
	claimBtn.TextStrokeTransparency = 0.15

	return gui, scrim, modal, title, sub, details, claimBtn
end

local gui, scrim, modal, titleLbl, subLbl, detailsLbl, claimBtn = createModalGui()
local goldDisplayLbl = modal:WaitForChild("RewardCard"):WaitForChild("GoldDisplay") :: TextLabel

local function formatTime(minutes: number): string
	local h = math.floor(minutes / 60)
	local m = minutes % 60
	if h > 0 and m > 0 then
		return string.format("%d hours %d minutes", h, m)
	elseif h > 0 then
		return string.format("%d hours", h)
	end
	return string.format("%d minutes", m)
end

OfflineRewardEvent.OnClientEvent:Connect(function(payload: any)
	if not payload or type(payload.GoldEarned) ~= "number" then return end

	local gold = payload.GoldEarned
	local offlineMin = payload.OfflineMinutes or 0
	local cappedMin = payload.CappedMinutes or offlineMin
	local rate = payload.RatePerMin or 0
	local level = payload.GuardPostLevel or 1
	local bossTier = payload.BiomeBossTier or 0

	goldDisplayLbl.Text = string.format("+%d GOLD", gold)

	local timeText = formatTime(offlineMin)
	local capNotice = ""
	if offlineMin > cappedMin then
		capNotice = string.format(" <font color=\"#EF4444\">(Capped at %s)</font>", formatTime(cappedMin))
	end

	local bossBonusText = bossTier > 0 and string.format("  •  Boss Tier %d (+%d%%)", bossTier, bossTier * 15) or ""

	detailsLbl.Text = string.format(
		"Time Offline: <b>%s</b>%s\nOutskirts Guard Post: <b>Lv.%d</b>%s\nPassive Generation: <b>%.1f Gold / min</b>\n<font color=\"#4ADE80\">Gold has been credited directly to your treasury!</font>",
		timeText,
		capNotice,
		level,
		bossBonusText,
		rate
	)

	scrim.Visible = true
	modal.Visible = true
	modal.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(modal, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5)
	}):Play()
end)

claimBtn.Activated:Connect(function()
	TweenService:Create(modal, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.55)
	}):Play()
	task.wait(0.18)
	scrim.Visible = false
	modal.Visible = false
end)
