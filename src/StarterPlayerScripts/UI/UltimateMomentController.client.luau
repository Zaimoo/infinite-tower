--!strict
-- StarterPlayerScripts/UI/UltimateMomentController.client.luau
-- One-time first-session moments (docs/first-session-and-social-plan.md A5, GDD §4.7). The server
-- decides when they happen (CombatSimulation via TowerRemotes.GuideMoment, once per profile):
--   ULTIMATE      the first Ultimate a new Master's hero fires: a name banner, a dimmed screen and a
--                 short camera punch-in. Under Reduce Motion only the banner shows.
--   HINT_WHISTLE  the first boss: how to speed the squad up during its recovery, with the control for
--                 the player's input (keyboard, gamepad or touch).
-- Decorative only: nothing here changes the fight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local UIFeel = require(script.Parent:WaitForChild("UIFeel"))

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TowerRemotes"):WaitForChild("GuideMoment") :: RemoteEvent

local GOLD = Color3.fromRGB(255, 214, 120)
local INK = Color3.fromRGB(6, 10, 16)

local gui = Instance.new("ScreenGui")
gui.Name = "UltimateMoment"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40 -- above the HUD, below windows and modals
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function text(parent: Instance, font: Font, size: number, color: Color3, y: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, y)
	label.Size = UDim2.new(1, -32, 0, size + 8)
	label.TextWrapped = true
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = label
	return label
end

local function fade(label: TextLabel, to: number, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, { TextTransparency = to }):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then TweenService:Create(stroke, info, { Transparency = to }):Play() end
end

local busy = false

-- A short dolly toward the camera's focus, applied after the camera module each frame. The player's
-- field of view is left alone: the Settings FOV guard re-asserts it on any outside change.
local PUNCH = "UltimateMomentPunch"
local function punchCamera()
	local start = os.clock()
	RunService:BindToRenderStep(PUNCH, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - start
		local k = if t < 0.12 then t / 0.12 elseif t < 0.35 then 1 elseif t < 0.8 then 1 - (t - 0.35) / 0.45 else -1
		if k < 0 then
			RunService:UnbindFromRenderStep(PUNCH)
			return
		end
		k = k * k * (3 - 2 * k)
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CFrame += (camera.Focus.Position - camera.CFrame.Position) * 0.18 * k
		end
	end)
end

local function showUltimate(message: any)
	if busy then return end
	busy = true
	local reduce = UIFeel.ReducedMotion()

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.new(1, 0, 0, 96)
	banner.Parent = gui
	local hero = text(banner, GildedGrimoire.Fonts.Body, 18, Color3.new(1, 1, 1), 0)
	hero.Text = string.upper(tostring(message.HeroName or "Your hero"))
	local skill = text(banner, GildedGrimoire.Fonts.Title, 44, GOLD, 26)
	skill.Text = tostring(message.SkillName or "Ultimate") .. "!"
	local scale = Instance.new("UIScale")
	scale.Scale = if reduce then 1 else 0.86
	scale.Parent = banner

	fade(hero, 0, 0.15)
	fade(skill, 0, 0.15)
	UIFeel.Sfx("AuraPowerUp", nil, 0.82)
	if not reduce then
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(dim, TweenInfo.new(0.12), { BackgroundTransparency = 0.55 }):Play()
		punchCamera()
	end

	task.delay(0.5, function()
		TweenService:Create(dim, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end)
	task.delay(1.4, function()
		fade(hero, 1, 0.35)
		fade(skill, 1, 0.35)
	end)
	task.delay(1.9, function()
		dim:Destroy()
		banner:Destroy()
		busy = false
	end)
end

-- The whistle's control for the player's current input.
local function whistleControl(): string
	local ok, preferred = pcall(function() return (UserInputService :: any).PreferredInput end)
	if ok and preferred ~= nil then
		if preferred == (Enum :: any).PreferredInput.Gamepad then return "Press L1" end
		if preferred == (Enum :: any).PreferredInput.Touch then return "Tap the whistle" end
		return "Press Q"
	end
	local last = UserInputService:GetLastInputType()
	if string.find(last.Name, "Gamepad") then return "Press L1" end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then return "Tap the whistle" end
	return "Press Q"
end

local function showWhistleHint()
	local card = Instance.new("Frame")
	card.Name = "WhistleHint"
	card.BackgroundTransparency = 1
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, 0.18)
	card.Size = UDim2.new(1, 0, 0, 60)
	card.Parent = gui
	local title = text(card, GildedGrimoire.Fonts.Title, 24, GOLD, 0)
	title.Text = "Speed up your heroes"
	local detail = text(card, GildedGrimoire.Fonts.Body, 16, Color3.new(1, 1, 1), 32)
	detail.Text = whistleControl() .. " when the boss stops after a big attack."
	fade(title, 0, 0.2)
	fade(detail, 0, 0.2)
	UIFeel.Sfx("EyeFocusTrigger", 1.1, 0.65)
	task.delay(6, function()
		fade(title, 1, 0.4)
		fade(detail, 1, 0.4)
		task.delay(0.5, function() card:Destroy() end)
	end)
end

remote.OnClientEvent:Connect(function(message: any)
	if type(message) ~= "table" then return end
	if message.Kind == "ULTIMATE" then
		showUltimate(message)
	elseif message.Kind == "HINT_WHISTLE" then
		showWhistleHint()
	end
end)
