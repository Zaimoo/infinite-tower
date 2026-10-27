--!strict
-- StarterPlayerScripts/UI/GoalTrackerController.client.luau
-- Pinned "Next Goal" card for the onboarding quest chain (Phase 4 §2). Listens to
-- ProgressionRemotes.OnboardingSync; the server decides progress, this script only renders it.
-- Phase 5 replaces this with the React Goal Tracker.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local SyncRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ProgressionRemotes"):WaitForChild("OnboardingSync") :: RemoteEvent

local GOLD = Color3.fromRGB(250, 204, 21)

local gui = Instance.new("ScreenGui")
gui.Name = "GoalTrackerGui"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 5
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "NextGoalCard"
card.AnchorPoint = Vector2.new(1, 0)
card.Position = UDim2.new(1, -16, 0, 96)
card.Size = UDim2.fromOffset(270, 74)
card.BackgroundColor3 = Color3.fromRGB(15, 13, 22)
card.BackgroundTransparency = 0.12
card.Visible = false
card.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = card
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 1.4
stroke.Transparency = 0.25
stroke.Parent = card

local function label(name: string, y: number, height: number, size: number, color: Color3, font: Enum.Font): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(12, y)
	l.Size = UDim2.new(1, -24, 0, height)
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.RichText = true
	l.Text = ""
	l.Parent = card
	return l
end

local header = label("Header", 6, 14, 11, GOLD, Enum.Font.GothamBold)
local title = label("Title", 21, 18, 15, Color3.new(1, 1, 1), Enum.Font.GothamBold)
local hint = label("Hint", 40, 30, 11, Color3.fromRGB(170, 160, 190), Enum.Font.GothamMedium)

local lastStepId: string? = nil

SyncRemote.OnClientEvent:Connect(function(message: any)
	if type(message) ~= "table" then return end
	local step = message.Step
	if type(step) ~= "table" then
		card.Visible = false
		lastStepId = nil
		return
	end
	local reward = step.Reward
	local rewardText = ""
	if type(reward) == "table" then
		local parts = {}
		if reward.Gold then table.insert(parts, string.format("%d Gold", reward.Gold)) end
		if reward.Gems then table.insert(parts, string.format("%d Gems", reward.Gems)) end
		if #parts > 0 then rewardText = "  ·  Reward: " .. table.concat(parts, ", ") end
	end
	header.Text = string.format("NEXT GOAL  %d/%d%s", step.Index or 1, step.Total or 1, rewardText)
	title.Text = tostring(step.Title)
	hint.Text = tostring(step.Description)
	card.Visible = true
	if step.Id ~= lastStepId then
		lastStepId = step.Id
		-- Flash the border when a new goal arrives.
		stroke.Transparency = 0
		TweenService:Create(stroke, TweenInfo.new(1.2), { Transparency = 0.25 }):Play()
	end
end)
