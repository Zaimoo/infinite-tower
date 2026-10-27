--!strict
-- StarterPlayerScripts/UI/DuelController.client.luau
-- Retaliation duel presentation (GDD 6.1): a fixed high-angle camera over the hex arena with this
-- player's squad in the foreground, and a banner with the countdown, squads left and the result.
-- The server runs the duel; this script only listens to TowerRemotes.DuelState.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local DuelStateRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TowerRemotes"):WaitForChild("DuelState") :: RemoteEvent

local CAMERA_BACK = 46 -- studs behind this player's squad
local CAMERA_UP = 50
local CAMERA_FOV = 45
local GOLD = Color3.fromRGB(255, 214, 120)
local GREEN = Color3.fromRGB(120, 235, 120)
local ORANGE = Color3.fromRGB(255, 160, 70)

local gui = Instance.new("ScreenGui")
gui.Name = "DuelScreenGui"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 20
gui.Enabled = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local banner = Instance.new("Frame")
banner.Name = "DuelBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 12)
banner.Size = UDim2.fromScale(0.5, 0.12)
banner.BackgroundColor3 = Color3.fromRGB(18, 14, 22)
banner.BackgroundTransparency = 0.15
banner.Parent = gui
local bannerSize = Instance.new("UISizeConstraint")
bannerSize.MinSize = Vector2.new(300, 72)
bannerSize.MaxSize = Vector2.new(560, 96)
bannerSize.Parent = banner
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = banner
local stroke = Instance.new("UIStroke")
stroke.Color = GOLD
stroke.Thickness = 2
stroke.Parent = banner

local function label(name: string, position: UDim2, size: UDim2, color: Color3, font: Enum.Font, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = position
	l.Size = size
	l.BackgroundTransparency = 1
	l.TextColor3 = color
	l.Font = font
	l.TextScaled = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Text = ""
	l.Parent = banner
	return l
end

local titleLabel = label("Title", UDim2.fromScale(0.25, 0.06), UDim2.fromScale(0.5, 0.3), GOLD, Enum.Font.GothamBlack)
local myLabel = label("MySquad", UDim2.fromScale(0.04, 0.4), UDim2.fromScale(0.36, 0.3), GREEN, Enum.Font.GothamBold, Enum.TextXAlignment.Left)
local scoreLabel = label("Score", UDim2.fromScale(0.4, 0.38), UDim2.fromScale(0.2, 0.34), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
local enemyLabel = label("EnemySquad", UDim2.fromScale(0.6, 0.4), UDim2.fromScale(0.36, 0.3), ORANGE, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
local timerLabel = label("Timer", UDim2.fromScale(0.3, 0.72), UDim2.fromScale(0.4, 0.22), Color3.fromRGB(220, 220, 230), Enum.Font.GothamMedium)

local resultLabel = Instance.new("TextLabel")
resultLabel.Name = "Result"
resultLabel.AnchorPoint = Vector2.new(0.5, 0.5)
resultLabel.Position = UDim2.fromScale(0.5, 0.42)
resultLabel.Size = UDim2.fromScale(0.6, 0.14)
resultLabel.BackgroundTransparency = 1
resultLabel.Font = Enum.Font.GothamBlack
resultLabel.TextScaled = true
resultLabel.TextStrokeTransparency = 0.3
resultLabel.Visible = false
resultLabel.Parent = gui
local resultSub = resultLabel:Clone()
resultSub.Name = "ResultDetail"
resultSub.Position = UDim2.fromScale(0.5, 0.53)
resultSub.Size = UDim2.fromScale(0.6, 0.06)
resultSub.Font = Enum.Font.GothamBold
resultSub.TextColor3 = Color3.new(1, 1, 1)
resultSub.Parent = gui

type DuelView = { Id: number, Side: string, FightAt: number, EndsAt: number, Ended: boolean }
local current: DuelView? = nil
local savedCamera: { CameraType: Enum.CameraType, FieldOfView: number }? = nil

local function myCount(message: any): (number, number)
	if message.Side == "A" then
		return message.AliveA or 0, message.AliveB or 0
	end
	return message.AliveB or 0, message.AliveA or 0
end

local function frameArena(center: Vector3, forward: Vector3, side: string)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	if not savedCamera then
		savedCamera = { CameraType = camera.CameraType, FieldOfView = camera.FieldOfView }
	end
	-- Look from behind this player's squad toward the opponent, like a tabletop battle board.
	local toward = if side == "A" then forward else -forward
	local eye = center - toward * CAMERA_BACK + Vector3.new(0, CAMERA_UP, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(eye, center + toward * 3),
		FieldOfView = CAMERA_FOV,
	}):Play()
end

local function releaseCamera()
	local camera = Workspace.CurrentCamera
	local saved = savedCamera
	savedCamera = nil
	if not camera or not saved then return end
	camera.CameraType = if saved.CameraType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else saved.CameraType
	camera.FieldOfView = saved.FieldOfView
	local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function updateScore(message: any)
	local mine, theirs = myCount(message)
	scoreLabel.Text = string.format("%d ⚔ %d", mine, theirs)
end

DuelStateRemote.OnClientEvent:Connect(function(message: any)
	if type(message) ~= "table" or type(message.DuelId) ~= "number" then return end
	if message.Kind == "START" then
		if typeof(message.Center) ~= "Vector3" or typeof(message.Forward) ~= "Vector3" then return end
		current = { Id = message.DuelId, Side = message.Side, FightAt = message.FightAt or 0, EndsAt = message.EndsAt or 0, Ended = false }
		local mine = if message.Side == "A" then message.NameA else message.NameB
		local theirs = if message.Side == "A" then message.NameB else message.NameA
		titleLabel.Text = "⚔ RETALIATION DUEL"
		myLabel.Text = tostring(mine)
		enemyLabel.Text = tostring(theirs)
		updateScore(message)
		resultLabel.Visible = false
		resultSub.Visible = false
		gui.Enabled = true
		frameArena(message.Center, message.Forward, message.Side)
		return
	end
	local view = current
	if not view or view.Id ~= message.DuelId then return end
	if message.Kind == "SCORE" or message.Kind == "FIGHT" then
		updateScore(message)
	elseif message.Kind == "END" then
		view.Ended = true
		updateScore(message)
		local won = message.Winner == view.Side
		local iAmOwner = view.Side == "A"
		resultLabel.Text = if won then "VICTORY" else "DEFEAT"
		resultLabel.TextColor3 = if won then GOLD else Color3.fromRGB(255, 95, 95)
		resultSub.Text = if won
			then (if iAmOwner then "You take back your drop." else "The stolen drop is yours to keep.")
			else "You are locked out of this drop."
		if message.Reason == "TIMEOUT" then
			resultSub.Text ..= " (time up: more HP left wins)"
		end
		resultLabel.Visible = true
		resultSub.Visible = true
		timerLabel.Text = ""
	elseif message.Kind == "CLEAR" then
		current = nil
		gui.Enabled = false
		releaseCamera()
	end
end)

-- Countdown text: "Fight in 2" during the line-up, then the time left before a decision on HP.
task.spawn(function()
	while true do
		task.wait(0.2)
		local view = current
		if view and not view.Ended then
			local now = Workspace:GetServerTimeNow()
			if now < view.FightAt then
				timerLabel.Text = string.format("Fight in %d", math.ceil(view.FightAt - now))
			else
				timerLabel.Text = string.format("%ds", math.max(0, math.ceil(view.EndsAt - now)))
			end
		end
	end
end)
