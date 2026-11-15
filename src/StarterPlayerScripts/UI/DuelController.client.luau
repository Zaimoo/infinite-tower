--!strict
-- StarterPlayerScripts/UI/DuelController.client.luau
-- Duel presentation (GDD 6.1, plan B2): a fixed high-angle camera over the hex arena with this
-- player's squad in the foreground, a "VS" intro card through the line-up (headshots, names and
-- squad power), a banner with the countdown and squads left, and a result naming the prize. Other
-- Masters on the floor get a Watch button that frames the arena for them (NEARBY / NEARBY_END).
-- The server runs the duel; this script only listens to TowerRemotes.DuelState.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local DuelStateRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TowerRemotes"):WaitForChild("DuelState") :: RemoteEvent

local OPT_IN_DELAY = 4 -- after the outro, before the notifications opt-in prompt
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
-- Clear Glass: the HUD glass body with a Danger accent bar; Montserrat type.
local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
GildedGrimoire.GlassFrame(banner, { Accent = GildedGrimoire.Glass.Danger })

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
	l.ZIndex = 3
	l.Parent = banner
	GildedGrimoire.GlassText(l, if font == Enum.Font.GothamMedium then "Body" else "Title")
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
GildedGrimoire.GlassText(resultLabel, "Title")
GildedGrimoire.GlassText(resultSub, "Body")
-- The result floats over the world with no panel, so it keeps a stronger stroke.
resultLabel.TextStrokeTransparency = 0.3
resultSub.TextStrokeTransparency = 0.3

--== Intro card: "VS" with both Masters, through the line-up ===================================
local intro = Instance.new("Frame")
intro.Name = "DuelIntro"
intro.AnchorPoint = Vector2.new(0.5, 0.5)
intro.Position = UDim2.fromScale(0.5, 0.42)
intro.Size = UDim2.fromOffset(520, 150)
intro.BackgroundColor3 = Color3.fromRGB(18, 14, 22)
intro.BackgroundTransparency = 0.12
intro.Visible = false
intro.Parent = gui
local introCorner = Instance.new("UICorner")
introCorner.CornerRadius = UDim.new(0, 14)
introCorner.Parent = intro
local introFit = Instance.new("UISizeConstraint")
introFit.MaxSize = Vector2.new(520, 150)
introFit.Parent = intro

local function introSide(xScale: number, color: Color3): (ImageLabel, TextLabel, TextLabel)
	local face = Instance.new("ImageLabel")
	face.AnchorPoint = Vector2.new(0.5, 0)
	face.Position = UDim2.new(xScale, 0, 0, 14)
	face.Size = UDim2.fromOffset(64, 64)
	face.BackgroundColor3 = Color3.fromRGB(10, 8, 14)
	face.Parent = intro
	local faceCorner = Instance.new("UICorner")
	faceCorner.CornerRadius = UDim.new(0.5, 0)
	faceCorner.Parent = face
	local ring = Instance.new("UIStroke")
	ring.Color = color
	ring.Thickness = 2
	ring.Parent = face
	local nameLabel = Instance.new("TextLabel")
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(xScale, 0, 0, 84)
	nameLabel.Size = UDim2.new(0.4, 0, 0, 24)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = color
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.Parent = intro
	GildedGrimoire.GlassText(nameLabel, "Title")
	local powerLabel = nameLabel:Clone()
	powerLabel.Position = UDim2.new(xScale, 0, 0, 112)
	powerLabel.Size = UDim2.new(0.4, 0, 0, 18)
	powerLabel.TextColor3 = Color3.fromRGB(230, 226, 238)
	powerLabel.Font = Enum.Font.GothamBold
	powerLabel.Parent = intro
	GildedGrimoire.GlassText(powerLabel, "Body")
	return face, nameLabel, powerLabel
end
local myFace, myIntroName, myIntroPower = introSide(0.22, GREEN)
local theirFace, theirIntroName, theirIntroPower = introSide(0.78, ORANGE)
local vsLabel = Instance.new("TextLabel")
vsLabel.AnchorPoint = Vector2.new(0.5, 0.5)
vsLabel.Position = UDim2.fromScale(0.5, 0.42)
vsLabel.Size = UDim2.fromOffset(90, 56)
vsLabel.BackgroundTransparency = 1
vsLabel.Text = "VS"
vsLabel.TextColor3 = GOLD
vsLabel.TextScaled = true
vsLabel.Font = Enum.Font.GothamBlack
vsLabel.Parent = intro
GildedGrimoire.GlassText(vsLabel, "Title")

local function headshotFor(userId: number?): string
	if type(userId) ~= "number" or userId <= 0 then return "" end -- server-run rivals have no avatar
	local ok, url = pcall(function()
		return (Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100))
	end)
	return if ok and url then url else ""
end

local function formatPower(power: any): string
	if type(power) ~= "number" then return "" end
	if power >= 1000 then return string.format("Power %.1fK", power / 1000) end
	return string.format("Power %d", power)
end

--== Watch button: other Masters on the floor can frame someone else's duel ===================
local watchGui = Instance.new("ScreenGui")
watchGui.Name = "DuelWatchGui"
watchGui.ResetOnSpawn = false
watchGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
watchGui.DisplayOrder = 20
watchGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
local watchButton = Instance.new("TextButton")
watchButton.Name = "WatchDuel"
watchButton.AnchorPoint = Vector2.new(0.5, 0)
watchButton.Position = UDim2.new(0.5, 0, 0, 120)
watchButton.Size = UDim2.fromOffset(240, 34)
watchButton.BackgroundColor3 = Color3.fromRGB(150, 32, 44)
watchButton.TextColor3 = Color3.new(1, 1, 1)
watchButton.Font = Enum.Font.GothamBlack
watchButton.TextScaled = true
watchButton.Visible = false
watchButton.Parent = watchGui
local watchCorner = Instance.new("UICorner")
watchCorner.CornerRadius = UDim.new(0, 8)
watchCorner.Parent = watchButton
local watchPad = Instance.new("UIPadding")
watchPad.PaddingTop, watchPad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
watchPad.Parent = watchButton
type Nearby = { Id: number, Center: Vector3, Forward: Vector3, Title: string }
local nearby: Nearby? = nil
local watching = false

type DuelView = { Id: number, Side: string, FightAt: number, EndsAt: number, Ended: boolean, Kind: string? }
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
	scoreLabel.Text = string.format("%d  –  %d", mine, theirs)
end

DuelStateRemote.OnClientEvent:Connect(function(message: any)
	if type(message) ~= "table" or type(message.DuelId) ~= "number" then return end
	if message.Kind == "START" then
		if typeof(message.Center) ~= "Vector3" or typeof(message.Forward) ~= "Vector3" then return end
		current = { Id = message.DuelId, Side = message.Side, FightAt = message.FightAt or 0, EndsAt = message.EndsAt or 0, Ended = false, Kind = message.DuelKind }
		-- A duelist stops watching someone else's duel.
		if watching then
			watching = false
		end
		nearby = nil
		watchButton.Visible = false
		local mineA = message.Side == "A"
		myIntroName.Text = tostring(if mineA then message.NameA else message.NameB)
		theirIntroName.Text = tostring(if mineA then message.NameB else message.NameA)
		myIntroPower.Text = formatPower(if mineA then message.PowerA else message.PowerB)
		theirIntroPower.Text = formatPower(if mineA then message.PowerB else message.PowerA)
		myFace.Image, theirFace.Image = "", ""
		intro.Visible = true
		task.spawn(function()
			local mine, theirs = headshotFor(if mineA then message.UserIdA else message.UserIdB), headshotFor(if mineA then message.UserIdB else message.UserIdA)
			if current and current.Id == message.DuelId then
				myFace.Image, theirFace.Image = mine, theirs
			end
		end)
		local mine = if message.Side == "A" then message.NameA else message.NameB
		local theirs = if message.Side == "A" then message.NameB else message.NameA
		titleLabel.Text = if message.DuelKind == "CARRY" then "RELIC DUEL" else "BOUNTY DUEL"
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
		if message.Kind == "FIGHT" then intro.Visible = false end
		updateScore(message)
	elseif message.Kind == "END" then
		view.Ended = true
		updateScore(message)
		local won = message.Winner == view.Side
		local iAmOwner = view.Side == "A"
		resultLabel.Text = if won then "VICTORY" else "DEFEAT"
		resultLabel.TextColor3 = if won then GOLD else Color3.fromRGB(255, 95, 95)
		local prize = tostring(message.PrizeName or "drop")
		if message.Training then
			-- The Rival lesson never ends on a loss: the Rival lets the relic go.
			resultSub.Text = if won then string.format("The %s is yours. Bank it!", prize) else string.format("The Rival lets you keep the %s.", prize)
		elseif message.DuelKind == "CARRY" then
			resultSub.Text = if won
				then (if iAmOwner then string.format("You took the %s.", prize) else string.format("You kept your %s.", prize))
				else string.format("You are locked out of the %s.", prize)
		else
			resultSub.Text = if won
				then (if iAmOwner then string.format("You claimed the bounty: the %s.", prize) else string.format("You escaped with the %s.", prize))
				else string.format("You are locked out of the %s.", prize)
		end
		intro.Visible = false
		if message.Reason == "TIMEOUT" then
			resultSub.Text ..= " (time up: more HP left wins)"
		end
		resultLabel.Visible = true
		resultSub.Visible = true
		timerLabel.Text = ""
		-- Winning the Rival lesson's duel is session 1's high point: ask then whether this Master would
		-- like experience notifications (plan A6). Roblox decides whether the prompt may show.
		if won and message.Training then
			task.delay(OPT_IN_DELAY, function()
				pcall(function()
					local notifications = game:GetService("ExperienceNotificationService")
					if notifications:CanPromptOptInAsync() then notifications:PromptOptIn() end
				end)
			end)
		end
	elseif message.Kind == "CLEAR" then
		current = nil
		gui.Enabled = false
		intro.Visible = false
		releaseCamera()
	end
end)

-- Someone else's duel on this floor: offer to watch it.
DuelStateRemote.OnClientEvent:Connect(function(message: any)
	if type(message) ~= "table" or type(message.DuelId) ~= "number" then return end
	if message.Kind == "NEARBY" and current == nil then
		if typeof(message.Center) ~= "Vector3" or typeof(message.Forward) ~= "Vector3" then return end
		nearby = { Id = message.DuelId, Center = message.Center, Forward = message.Forward,
			Title = string.format("%s vs %s", tostring(message.NameA), tostring(message.NameB)) }
		watchButton.Text = "WATCH DUEL"
		watchButton.Visible = true
	elseif message.Kind == "NEARBY_END" and nearby and nearby.Id == message.DuelId then
		nearby = nil
		watchButton.Visible = false
		if watching then
			watching = false
			releaseCamera()
		end
	end
end)

watchButton.Activated:Connect(function()
	local duel = nearby
	if not duel or current ~= nil then return end
	if watching then
		watching = false
		watchButton.Text = "WATCH DUEL"
		releaseCamera()
	else
		watching = true
		watchButton.Text = "STOP WATCHING"
		frameArena(duel.Center, duel.Forward, "A")
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

_G.IsDuelActive = function(): boolean
	return current ~= nil
end
