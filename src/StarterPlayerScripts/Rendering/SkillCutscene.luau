--!strict
-- StarterPlayerScripts/Rendering/SkillCutscene.luau
-- The skill cutscene (GDD §4.7). When one of the local Master's heroes fires its Skill (its
-- HERO_CUE; EntityRenderer calls OnSkill), and its cutscene is due (its first Skill in the session,
-- or every one with Always Show Skill Cutscenes on), black letterbox bars slide in with the hero's
-- name and the skill's name, the camera pans to the hero and follows the Skill's animation (a front
-- three-quarter shot that swings over the shoulder at the release, so the effect lands in frame),
-- then it hands back to the normal camera. When several Skills fire together, the most important
-- one gets the camera and the others get cut-in banners (SkillCutIn). Every Skill opens with the hero's wind-up and its
-- charge effects (HeroClips.Windup, SkillVfx.PlayWindup), so the cutscene frames those first.
--
-- Settings > Graphics > Always Show Skill Cutscenes (off by default) plays it on every Skill
-- instead of once per hero per session. Reduce Motion keeps only the bars and the caption.
--
-- Cosmetic and client-only: the fight keeps running at its normal speed, and nothing here touches
-- the simulation.
--
-- Camera: rather than taking the camera over, the cutscene blends on top of whichever camera is
-- active (the default player camera, the squad bird's-eye view or the duel camera). It binds after
-- every other camera step and lerps the CFrame they produced towards its own shot, and it puts that
-- CFrame back before the camera step of the next frame, so the other camera never sees the
-- cutscene's view and resumes exactly where it would have been. The player's field of view is left
-- alone. Under Reduce Motion only the bars and the caption show.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local UIFeel = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("UIFeel"))
local HeroCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HeroCatalog"))
local SkillCutIn = require(script.Parent:WaitForChild("SkillCutIn"))

local SkillCutscene = {}

-- Timing (seconds).
local PAN_IN = 0.2 -- base camera -> hero shot (quick, so the Skill is framed almost from its start)
local SWING = 0.6 -- front shot -> over-the-shoulder shot, centred just after the release
local HOLD = 0.45 -- after the cast ends, so the impact can play out
local PAN_OUT = 0.55 -- hero shot -> base camera
local BARS_IN = 0.3
local BARS_OUT = 0.35
local BAR_HEIGHT = 0.12 -- share of the screen height, each bar
local LEAVE_DISTANCE = 3 -- studs the hero is drawn from where it cast before the wide shot takes over
local WIDE_BLEND = 0.45 -- hero shot -> wide shot
-- A cue that arrives this far into its cast has missed most of it; the hero keeps its cutscene
-- for its next cast instead.
local LATE_SHARE = 0.4
-- Skills that fire this close together are weighed against each other for the camera, so the most
-- important one gets it rather than whichever cue happened to arrive first.
local ELECT_SECONDS = 0.1

local GOLD = Color3.fromRGB(255, 214, 120)
local PRE_STEP = "SkillCutscenePre"
local POST_STEP = "SkillCutscenePost"

export type Request = {
	Key: string, -- one cutscene per key per session (the hero's TemplateId)
	HeroName: string,
	SkillName: string,
	Root: BasePart, -- the hero's rendered root, followed live
	Aim: Vector3, -- where the skill is aimed
	CastSeconds: number,
	ReleaseSeconds: number,
	Elapsed: number, -- how far into the cast the cue arrived
	WeaponType: string?, -- for the cut-in's colours
}

local player = Players.LocalPlayer
local seen: { [string]: boolean } = {}
local active = false

local gui = Instance.new("ScreenGui")
gui.Name = "SkillCutscene"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 39 -- over the HUD, under the Ultimate banner (40) and windows
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function bar(name: string, anchorY: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0, anchorY)
	frame.Position = UDim2.fromScale(0, anchorY)
	frame.Size = UDim2.fromScale(1, 0)
	frame.ClipsDescendants = true
	frame.Parent = gui
	return frame
end

local topBar = bar("TopBar", 0)
local bottomBar = bar("BottomBar", 1)

-- Sized as a share of the bar so it fits on a phone; capped at maxSize on large screens.
local function caption(font: Font, maxSize: number, color: Color3, centreY: number, heightShare: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextScaled = true
	label.TextColor3 = color
	label.TextTransparency = 1
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 48, centreY, 0)
	label.Size = UDim2.new(1, -96, heightShare, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = bottomBar
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = label
	return label
end

local heroLabel = caption(GildedGrimoire.Fonts.Body, 16, Color3.new(1, 1, 1), 0.3, 0.26)
local skillLabel = caption(GildedGrimoire.Fonts.Title, 30, GOLD, 0.64, 0.4)

local function tween(obj: Instance, seconds: number, goal: { [string]: any }, direction: Enum.EasingDirection?)
	TweenService:Create(obj, TweenInfo.new(seconds, Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal):Play()
end

local function showBars(heroName: string, skillName: string)
	heroLabel.Text = string.upper(heroName)
	skillLabel.Text = skillName
	gui.Enabled = true
	tween(topBar, BARS_IN, { Size = UDim2.fromScale(1, BAR_HEIGHT) })
	tween(bottomBar, BARS_IN, { Size = UDim2.fromScale(1, BAR_HEIGHT) })
	task.delay(BARS_IN * 0.5, function()
		tween(heroLabel, 0.25, { TextTransparency = 0 })
		tween(skillLabel, 0.25, { TextTransparency = 0 })
	end)
end

local function hideBars()
	tween(heroLabel, 0.2, { TextTransparency = 1 })
	tween(skillLabel, 0.2, { TextTransparency = 1 })
	tween(topBar, BARS_OUT, { Size = UDim2.fromScale(1, 0) }, Enum.EasingDirection.In)
	tween(bottomBar, BARS_OUT, { Size = UDim2.fromScale(1, 0) }, Enum.EasingDirection.In)
end

local function smooth(x: number): number
	local k = math.clamp(x, 0, 1)
	return k * k * (3 - 2 * k)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Pulls the camera in front of walls between it and the hero. Rendered visuals, characters and
-- see-through or non-colliding parts don't block it.
local occlusionParams = RaycastParams.new()
occlusionParams.FilterType = Enum.RaycastFilterType.Exclude
occlusionParams.IgnoreWater = true

local function unoccluded(from: Vector3, to: Vector3): Vector3
	local ignore: { Instance } = {}
	local visuals = Workspace:FindFirstChild("ClientVisualEntities")
	if visuals then table.insert(ignore, visuals) end
	for _, other in Players:GetPlayers() do
		if other.Character then table.insert(ignore, other.Character) end
	end
	local offset = to - from
	for _ = 1, 6 do
		occlusionParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, offset, occlusionParams)
		if not hit then return to end
		local part = hit.Instance
		if part:IsA("BasePart") and (not part.CanCollide or part.Transparency > 0.6) then
			table.insert(ignore, part)
		else
			return hit.Position - offset.Unit * 0.8
		end
	end
	return to
end

type Cast = {
	Clock: number, -- os.clock() when the cast started
	CastSeconds: number,
	ReleaseSeconds: number,
	Forward: Vector3,
	Right: Vector3,
	AimDistance: number,
	Swings: boolean,
	From: Vector3, -- where the hero stood when it cast
	WideCentre: Vector3,
	WideReach: number,
}

type Scene = {
	Key: string,
	Root: BasePart,
	Camera: Camera,
	Height: number,
	StartClock: number,
	HeroPos: Vector3,
	Cast: Cast,
	OutAt: number, -- scene time the pan back out starts
	EndAt: number,
	LeftHome: boolean,
	Wide: number, -- 0 = hero shot, 1 = the wide shot over the skill area
	WideShot: CFrame,
	Reach: number, -- share of the shot's distance the walls leave clear, smoothed
	Base: CFrame?, -- the other camera's own view this frame
	Done: boolean,
}

local scene: Scene? = nil

-- Camera shake inside the cutscene. The usual combat shake moves the camera before the cutscene's
-- camera step, which would overwrite it, so shakes asked for during a cutscene play here instead.
local shakeMagnitude, shakeStart, shakeSeconds = 0, 0, 0.2

-- Shakes the cutscene camera; returns false (nothing to shake) when no cutscene is on screen.
function SkillCutscene.Shake(magnitude: number, seconds: number?): boolean
	if not scene then return false end
	shakeMagnitude = math.clamp(magnitude, 0, 0.5)
	shakeStart = os.clock()
	shakeSeconds = seconds or 0.22
	return true
end

-- Whether this hero's Skill gets a cutscene: its first in the session, or every one with
-- Settings > Always Show Skill Cutscenes (SettingsConfig.AlwaysSkillCutscenes) on.
function SkillCutscene.Due(key: string): boolean
	return not seen[key] or player:GetAttribute("Settings_AlwaysSkillCutscenes") == true
end

local function endScene(s: Scene)
	if s.Done then return end
	s.Done = true
	RunService:UnbindFromRenderStep(PRE_STEP)
	RunService:UnbindFromRenderStep(POST_STEP)
	if s.Base and Workspace.CurrentCamera == s.Camera then s.Camera.CFrame = s.Base end
	if scene == s then scene = nil end
	hideBars()
	task.delay(BARS_OUT, function()
		gui.Enabled = false
		active = false
	end)
end

local function stepScene(s: Scene, dt: number)
	local camera = s.Camera
	if Workspace.CurrentCamera ~= camera then
		endScene(s)
		return
	end
	local t = os.clock() - s.StartClock
	if t >= s.EndAt then
		endScene(s)
		return
	end
	local current = camera.CFrame
	s.Base = current
	local cast = s.Cast
	local root = s.Root

	-- Follow the hero while it stays where it cast from; if its visual is gone, pan back out now.
	if root.Parent then
		if not s.LeftHome and (root.Position - cast.From).Magnitude > LEAVE_DISTANCE then
			s.LeftHome = true
		end
		if not s.LeftHome then
			s.HeroPos = s.HeroPos:Lerp(root.Position, 1 - math.exp(-12 * dt))
		end
	elseif s.OutAt > t then
		s.OutAt = t
		s.EndAt = t + PAN_OUT
	end

	-- A front three-quarter shot drifting slowly round on the wind-up, that swings over the
	-- shoulder at the release so the effect lands in frame.
	local h = s.Height
	local chest = s.HeroPos + Vector3.new(0, h * 0.42, 0)
	local castT = os.clock() - cast.Clock
	local swing = if cast.Swings then smooth((castT - (cast.ReleaseSeconds - SWING * 0.35)) / SWING) else 0
	local drift = smooth(castT / math.max(0.2, cast.CastSeconds))
	local angle = math.rad(32 + 12 * drift + 110 * swing)
	local around = cast.Forward * math.cos(angle) + cast.Right * math.sin(angle)
	local eye = s.HeroPos + around * h * (1.75 - 0.25 * drift + 0.15 * swing) + Vector3.new(0, h * (0.42 + 0.18 * swing), 0)
	local impact = s.HeroPos + cast.Forward * cast.AimDistance + Vector3.new(0, h * 0.3, 0)
	local look = chest:Lerp(impact, 0.55 * swing)

	-- A wall pulls the camera in at once, but it eases back out, so a wall edge can't flicker it.
	local clear = (unoccluded(chest, eye) - chest).Magnitude / math.max(0.01, (eye - chest).Magnitude)
	s.Reach = if clear < s.Reach then clear else s.Reach + (clear - s.Reach) * (1 - math.exp(-6 * dt))
	local shot = CFrame.lookAt(chest:Lerp(eye, s.Reach), look)

	-- Skills that draw the hero somewhere else (Han's Abyssal Wake flashes round a circle, Nyx's
	-- Mirror Step) would drag the hero shot along with every flash. Once the hero leaves where it
	-- cast from, the camera stops following it and eases out to one steady wide shot over the area.
	if s.LeftHome then
		if s.Wide == 0 then
			-- Pull back along the side the camera is already on, high enough to see the whole area.
			local flatAround = flat(around)
			local wideAround = if flatAround.Magnitude > 0.1 then flatAround.Unit else -cast.Forward
			local wideWanted = cast.WideCentre + wideAround * cast.WideReach * 1.5 + Vector3.new(0, cast.WideReach * 0.9, 0)
			s.WideShot = CFrame.lookAt(unoccluded(cast.WideCentre, wideWanted), cast.WideCentre)
		end
		s.Wide = math.min(1, s.Wide + dt / WIDE_BLEND)
		shot = shot:Lerp(s.WideShot, smooth(s.Wide))
	end

	local outWeight = if t < s.OutAt then 1 else 1 - smooth((t - s.OutAt) / PAN_OUT)
	local weight = math.min(smooth(t / PAN_IN), outWeight)
	local view = current:Lerp(shot, weight)
	local shaking = os.clock() - shakeStart
	if shakeMagnitude > 0 and shaking < shakeSeconds then
		local m = shakeMagnitude * (1 - shaking / shakeSeconds) * weight
		view *= CFrame.new((math.random() - 0.5) * 2 * m, (math.random() - 0.5) * 2 * m, 0)
	end
	camera.CFrame = view
end

local function startScene(request: Request): boolean
	local camera = Workspace.CurrentCamera
	if not camera then return false end
	local root = request.Root
	local model = root:FindFirstAncestorOfClass("Model")
	local height = 5
	if model then
		local ok, size = pcall(function() return model:GetExtentsSize() end)
		if ok then height = math.clamp(size.Y, 4, 14) end
	end
	local from = root.Position
	local toAim = flat(request.Aim - from)
	local facing = flat(root.CFrame.LookVector)
	local forward = if toAim.Magnitude > 0.5 then toAim.Unit elseif facing.Magnitude > 0.1 then facing.Unit else Vector3.zAxis
	-- Self-cast skills (a roar, a barrier) have nothing out front to swing towards.
	local aimDistance = math.min(toAim.Magnitude, 16)
	local swings = aimDistance > 4
	local castLeft = math.max(0, request.CastSeconds - request.Elapsed)
	local s: Scene = {
		Key = request.Key,
		Root = root,
		Camera = camera,
		Height = height,
		StartClock = os.clock(),
		HeroPos = from,
		Cast = {
			Clock = os.clock() - request.Elapsed,
			CastSeconds = request.CastSeconds,
			ReleaseSeconds = request.ReleaseSeconds,
			Forward = forward,
			Right = forward:Cross(Vector3.yAxis),
			AimDistance = aimDistance,
			Swings = swings,
			From = from,
			WideCentre = from:Lerp(from + forward * aimDistance, if swings then 0.6 else 0) + Vector3.new(0, height * 0.3, 0),
			WideReach = aimDistance * 0.5 + 10,
		},
		OutAt = castLeft + HOLD,
		EndAt = castLeft + HOLD + PAN_OUT,
		LeftHome = false,
		Wide = 0,
		WideShot = CFrame.identity,
		Reach = 1,
		Base = nil,
		Done = false,
	}
	seen[request.Key] = true
	active = true
	scene = s
	showBars(request.HeroName, request.SkillName)

	-- Before the camera step: hand the other camera back its own view from last frame.
	RunService:BindToRenderStep(PRE_STEP, Enum.RenderPriority.Camera.Value - 1, function()
		if s.Base and Workspace.CurrentCamera == s.Camera then s.Camera.CFrame = s.Base end
	end)
	-- After every camera step: blend towards the cutscene's shot.
	RunService:BindToRenderStep(POST_STEP, Enum.RenderPriority.Camera.Value + 10, function(dt: number)
		stepScene(s, dt)
	end)
	return true
end

-- Plays the cutscene for a Skill. False if it can't (no longer due, too late, its hero gone).
local function play(request: Request): boolean
	if active or not SkillCutscene.Due(request.Key) then return false end
	if request.Elapsed > request.CastSeconds * LATE_SHARE then return false end
	if not request.Root.Parent then return false end

	if UIFeel.ReducedMotion() then
		seen[request.Key] = true
		active = true
		showBars(request.HeroName, request.SkillName)
		task.delay(math.max(0, request.CastSeconds - request.Elapsed) + HOLD + PAN_OUT, function()
			hideBars()
			task.delay(BARS_OUT, function()
				gui.Enabled = false
				active = false
			end)
		end)
		return true
	end

	return startScene(request)
end

local function cutIn(request: Request)
	local ok, err = pcall(SkillCutIn.Show, {
		HeroId = request.Key,
		WeaponType = request.WeaponType,
		HeroName = request.HeroName,
		SkillName = request.SkillName,
	})
	if not ok then
		warn(`SkillCutIn failed: {err}`)
	end
end

-- Which of several Skills fired together gets the camera: a hero's first Skill of the session
-- first, then the rarest hero; on a tie, the first to fire.
local function priority(request: Request): number
	return (if seen[request.Key] then 0 else 100) + HeroCatalog.RarityOf(request.Key)
end

type Waiting = { Request: Request, At: number }
local waiting: { Waiting } = {}
local electing = false

local function elect()
	electing = false
	local list = waiting
	waiting = {}
	local best: Waiting? = nil
	local bestScore = -math.huge
	for _, entry in list do
		local request = entry.Request
		request.Elapsed += os.clock() - entry.At
		if SkillCutscene.Due(request.Key) and request.Elapsed <= request.CastSeconds * LATE_SHARE and request.Root.Parent then
			local score = priority(request)
			if score > bestScore then
				best, bestScore = entry, score
			end
		end
	end
	if not best or not play(best.Request) then
		return
	end
	-- The others that fired with it get cut-ins.
	for _, entry in list do
		if entry ~= best then
			cutIn(entry.Request)
		end
	end
end

-- One of the local Master's heroes has fired its Skill (its HERO_CUE). Skills that fire within
-- ELECT_SECONDS of each other are weighed together: the most important one whose cutscene is due
-- gets the camera, and the others get cut-in banners (SkillCutIn). A Skill that fires while a
-- cutscene is on screen gets a cut-in. With no cutscene due, nothing shows.
function SkillCutscene.OnSkill(request: Request)
	if active then
		cutIn(request)
		return
	end
	table.insert(waiting, { Request = request, At = os.clock() })
	if not electing then
		electing = true
		task.delay(ELECT_SECONDS, elect)
	end
end

-- True while a cutscene is on screen.
function SkillCutscene.IsActive(): boolean
	return active
end

return SkillCutscene
