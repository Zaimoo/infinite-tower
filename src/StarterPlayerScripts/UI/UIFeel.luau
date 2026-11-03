--!strict
-- StarterPlayerScripts/UI/UIFeel.luau
-- Game feel for every screen: button hover/press springs, click and hover sounds, haptics,
-- window open pops, screen shake, sparkle bursts, shimmer sweeps and number count-ups.
--   * UIFeelController.client.luau calls UIFeel.WatchGui(PlayerGui), so every GuiButton gets the
--     hover/press spring, a click sound and a UIClick haptic without any per-screen code.
--   * Opt a button out with the attribute NoFeel = true. Buttons that already own a UIScale (the
--     React rail buttons, the Fortress Tree nodes) keep their own spring and only get the sound and
--     haptic; full-screen tap catchers get nothing. FeelSound = "<UIAssets.Sounds key>" swaps the click.
--   * Motion respects GuiService.ReducedMotionEnabled and the in-game Reduce Motion setting:
--     springs, shakes and bursts are dropped, sounds and haptics stay.
-- Sounds come from UIAssets.Sounds and play through SoundService.SFX, the group the Settings
-- volume slider drives. An empty asset slot is silent.

local GuiService = game:GetService("GuiService")
local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIAssets = require(script.Parent:WaitForChild("UIAssets"))

local UIFeel = {}

local HOVER_SCALE = 1.04
local PRESS_SCALE = 0.93
local HOVER_SFX_GAP = 0.06 -- seconds; sweeping the mouse over a grid must not machine-gun

local SPRING_OUT = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SPRING_IN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOVER_IN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--============================================================================
-- MOTION PREFERENCE
--============================================================================

function UIFeel.ReducedMotion(): boolean
	local ok, on = pcall(function() return (GuiService :: any).ReducedMotionEnabled end)
	if ok and on == true then return true end
	local player = Players.LocalPlayer
	return player ~= nil and player:GetAttribute("Settings_ReduceMotion") == true
end

--============================================================================
-- SOUND
--============================================================================

local sfxGroup: SoundGroup? = nil
local function group(): SoundGroup
	if sfxGroup and sfxGroup.Parent then return sfxGroup end
	local existing = SoundService:FindFirstChild("SFX")
	if existing and existing:IsA("SoundGroup") then
		sfxGroup = existing
		return existing
	end
	-- Settings looks this group up by name, so creating it here makes the SFX slider work.
	local g = Instance.new("SoundGroup")
	g.Name = "SFX"
	g.Volume = 0.65
	g.Parent = SoundService
	sfxGroup = g
	return g
end

-- Plays a UIAssets.Sounds entry. `pitch` (default 1) lets a sequence climb, e.g. star ticks.
function UIFeel.Sfx(name: string, pitch: number?, volume: number?)
	local id = (UIAssets.Sounds :: any)[name]
	if type(id) ~= "string" or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	s.SoundGroup = group()
	s.Parent = SoundService
	s.Ended:Once(function() s:Destroy() end)
	s:Play()
	task.delay(6, function() if s.Parent then s:Destroy() end end)
end

--============================================================================
-- HAPTICS
--============================================================================

-- HapticEffect (mobile + gamepad) when the engine has it, the gamepad motor otherwise.
-- kind: "Hover" | "Click" | "Notify" | "Impact"
local effects: { [string]: any } = {}
local EFFECT_TYPE = { Hover = "UIHover", Click = "UIClick", Notify = "UINotification", Impact = "GameplayExplosion" }

local function hapticEffect(kind: string): any
	if effects[kind] ~= nil then return effects[kind] or nil end
	local ok, effect = pcall(function()
		local h = Instance.new("HapticEffect" :: any) :: any
		h.Type = (Enum :: any).HapticEffectType[EFFECT_TYPE[kind]]
		h.Parent = SoundService
		return h
	end)
	effects[kind] = if ok then effect else false
	return if ok then effect else nil
end

local MOTOR = { Hover = 0.08, Click = 0.25, Notify = 0.45, Impact = 1 }
local motorToken = 0

function UIFeel.Haptic(kind: string)
	local effect = hapticEffect(kind)
	if effect then
		pcall(function() effect:Play() end)
		return
	end
	local pad = Enum.UserInputType.Gamepad1
	if UserInputService.PreferredInput ~= Enum.PreferredInput.Gamepad then return end
	if not HapticService:IsVibrationSupported(pad) or not HapticService:IsMotorSupported(pad, Enum.VibrationMotor.Small) then return end
	local strength = MOTOR[kind] or 0.2
	local motor = if kind == "Impact" then Enum.VibrationMotor.Large else Enum.VibrationMotor.Small
	motorToken += 1
	local token = motorToken
	HapticService:SetMotor(pad, motor, strength)
	task.delay(if kind == "Impact" then 0.35 else 0.06, function()
		if motorToken == token then HapticService:SetMotor(pad, motor, 0) end
	end)
end

--============================================================================
-- TWEENS
--============================================================================

function UIFeel.Tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- The object's UIScale, created on first use.
function UIFeel.Scale(obj: GuiObject): UIScale
	local s = obj:FindFirstChildOfClass("UIScale")
	if s then return s end
	local n = Instance.new("UIScale")
	n.Name = "FeelScale"
	n.Parent = obj
	return n
end

-- A quick "boing": overshoot then settle. Use on badges, counters, freshly-added items.
function UIFeel.Pop(obj: GuiObject, amount: number?)
	if UIFeel.ReducedMotion() then return end
	local s = UIFeel.Scale(obj)
	s.Scale = 1 + (amount or 0.18)
	TweenService:Create(s, SPRING_OUT, { Scale = 1 }):Play()
end

-- Grow in from `from` (default 0) with an overshoot. Used for the 10x grid and new cards.
function UIFeel.PopIn(obj: GuiObject, from: number?, t: number?)
	local s = UIFeel.Scale(obj)
	if UIFeel.ReducedMotion() then s.Scale = 1 return end
	s.Scale = from or 0
	UIFeel.Tween(s, t or 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Rotational wobble, for refusals ("not enough Gems") and heavy impacts.
function UIFeel.Shake(obj: GuiObject, degrees: number?, duration: number?)
	if UIFeel.ReducedMotion() then return end
	local amp, dur = degrees or 3, duration or 0.35
	local base = obj:GetAttribute("FeelBaseRotation") :: number?
	if base == nil then
		base = obj.Rotation
		obj:SetAttribute("FeelBaseRotation", base)
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= dur or not obj.Parent then
			conn:Disconnect()
			obj.Rotation = base :: number
			obj:SetAttribute("FeelBaseRotation", nil)
			return
		end
		local k = 1 - t / dur
		obj.Rotation = (base :: number) + math.sin(t * 60) * amp * k
	end)
end

-- "No": shake, error sound, light haptic. One call for every refused action.
function UIFeel.Deny(obj: GuiObject?)
	if obj then UIFeel.Shake(obj, 4, 0.3) end
	UIFeel.Sfx("Error")
	UIFeel.Haptic("Notify")
end

-- Sparkles flying out from `at` (a UDim2 inside `parent`). Drawn frames unless RevealSparkle is uploaded.
function UIFeel.Burst(parent: GuiObject, at: UDim2, color: Color3, count: number?, zIndex: number?, radius: number?)
	if UIFeel.ReducedMotion() then return end
	local n = count or 14
	local r = radius or 180
	local image = UIAssets.Images.RevealSparkle
	for i = 1, n do
		local size = math.random(8, 18)
		local p: GuiObject
		if image ~= "" then
			local img = Instance.new("ImageLabel")
			img.Image = image
			img.ImageColor3 = color
			img.BackgroundTransparency = 1
			p = img
		else
			local f = Instance.new("Frame")
			f.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.35)
			f.BorderSizePixel = 0
			f.Rotation = 45
			p = f
		end
		p.Name = "Spark"
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = at
		p.Size = UDim2.fromOffset(size, size)
		p.ZIndex = zIndex or 100
		p.Parent = parent
		local angle = (i / n) * math.pi * 2 + math.random() * 0.5
		local dist = r * (0.55 + math.random() * 0.6)
		local life = 0.55 + math.random() * 0.35
		local target = at + UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist)
		UIFeel.Tween(p, life, { Position = target, Rotation = p.Rotation + math.random(-180, 180), Size = UDim2.fromOffset(2, 2) }, Enum.EasingStyle.Quart)
		UIFeel.Tween(p, life, { BackgroundTransparency = 1, ImageTransparency = if p:IsA("ImageLabel") then 1 else nil } :: any, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(life + 0.05, function() p:Destroy() end)
	end
end

-- A diagonal light band sweeping across `host` (which should clip, or carry matching corners).
-- Returns a stop function; with `loop` it repeats every `period` seconds until stopped.
function UIFeel.Shimmer(host: GuiObject, zIndex: number?, loop: boolean?, period: number?): () -> ()
	local band = Instance.new("Frame")
	band.Name = "Shimmer"
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.Size = UDim2.fromScale(1, 1)
	band.ZIndex = zIndex or host.ZIndex + 1
	band.Active = false
	band.Parent = host
	local corner = host:FindFirstChildOfClass("UICorner")
	if corner then corner:Clone().Parent = band end
	local grad = Instance.new("UIGradient")
	grad.Rotation = 25
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
	})
	grad.Parent = band
	local alive = true
	task.spawn(function()
		repeat
			grad.Offset = Vector2.new(-1, 0)
			if not UIFeel.ReducedMotion() then
				local tw = UIFeel.Tween(grad, 0.7, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				tw.Completed:Wait()
			end
			if loop then task.wait(period or 2.4) end
		until not loop or not alive or not band.Parent
		if not loop then band:Destroy() end
	end)
	return function()
		alive = false
		band:Destroy()
	end
end

-- Counts a label from `from` to `to` (formatted by `fmt`, default "%d").
function UIFeel.CountUp(label: TextLabel, from: number, to: number, duration: number?, fmt: string?)
	local f = fmt or "%d"
	local integer = string.find(f, "%d", 1, true) ~= nil -- "%d" errors on non-integers
	if UIFeel.ReducedMotion() or from == to then
		label.Text = string.format(f, if integer then math.round(to) else to)
		return
	end
	local dur = duration or 0.6
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local k = math.min(1, (os.clock() - t0) / dur)
		local eased = 1 - (1 - k) ^ 3
		local value = from + (to - from) * eased
		if integer then value = math.round(value) end
		label.Text = string.format(f, value)
		if k >= 1 or not label.Parent then conn:Disconnect() end
	end)
end

--============================================================================
-- WINDOW TRANSITIONS
--============================================================================

-- Pops a window in whenever it becomes visible: its UIScale grows from 92% of `target()` with an
-- overshoot. ModalFit.Bind wires this for every fitted window. `target` returns the resting scale.
function UIFeel.BindOpen(root: GuiObject, scale: UIScale, target: () -> number)
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if not root.Visible then return end
		local rest = target()
		if UIFeel.ReducedMotion() then
			scale.Scale = rest
			return
		end
		scale.Scale = rest * 0.92
		TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = rest }):Play()
		UIFeel.Sfx("WindowOpen")
	end)
end

--============================================================================
-- BUTTON FEEL
--============================================================================

local lastHoverSfx = 0
local attached: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Full-screen tap catchers (scrims) and huge hit areas get no spring.
local function isCatcher(b: GuiButton): boolean
	local gui = b:FindFirstAncestorOfClass("ScreenGui")
	if not gui then return false end
	local s, a = gui.AbsoluteSize, b.AbsoluteSize
	return s.X > 0 and a.X >= s.X * 0.7 and a.Y >= s.Y * 0.7
end

function UIFeel.Attach(button: GuiButton)
	if attached[button] then return end
	if button:GetAttribute("NoFeel") == true then return end
	attached[button] = true
	button.Activated:Connect(function()
		if isCatcher(button) then return end
		local sound = button:GetAttribute("FeelSound")
		UIFeel.Sfx(if type(sound) == "string" then sound else "Click", 1 + (math.random() - 0.5) * 0.06)
		UIFeel.Haptic("Click")
	end)
	button.Destroying:Connect(function() attached[button] = nil end)
	-- A button that already owns a UIScale animates itself; it keeps only the sound and haptic.
	if button:FindFirstChildOfClass("UIScale") then return end
	local scale: UIScale? = nil
	local hovered, pressed = false, false

	local function getScale(): UIScale
		if scale and scale.Parent then return scale end
		scale = UIFeel.Scale(button)
		return scale :: UIScale
	end
	local function settle(info: TweenInfo)
		if UIFeel.ReducedMotion() then
			getScale().Scale = 1
			return
		end
		local target = if pressed then PRESS_SCALE elseif hovered then HOVER_SCALE else 1
		TweenService:Create(getScale(), info, { Scale = target }):Play()
	end

	local function enter()
		if hovered or not button.Active or isCatcher(button) then return end
		hovered = true
		settle(HOVER_IN)
		local now = os.clock()
		if now - lastHoverSfx > HOVER_SFX_GAP then
			lastHoverSfx = now
			UIFeel.Sfx("Hover", 1 + (math.random() - 0.5) * 0.08, 0.35)
		end
		UIFeel.Haptic("Hover")
	end
	local function leave()
		if not hovered and not pressed then return end
		hovered, pressed = false, false
		settle(SPRING_OUT)
	end

	button.MouseEnter:Connect(enter)
	button.MouseLeave:Connect(leave)
	button.SelectionGained:Connect(enter)
	button.SelectionLost:Connect(leave)
	button.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
			or (input.KeyCode == Enum.KeyCode.ButtonA and GuiService.SelectedObject == button) then
			if isCatcher(button) then return end
			pressed = true
			settle(SPRING_IN)
		end
	end)
	button.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			if not pressed then return end
			pressed = false
			if t == Enum.UserInputType.Touch then hovered = false end -- no hover state on touch
			settle(SPRING_OUT)
		end
	end)
end

-- Attaches button feel to every GuiButton under `root`, now and as screens build or rebuild.
function UIFeel.WatchGui(root: Instance): RBXScriptConnection
	local function consider(obj: Instance)
		if obj:IsA("GuiButton") then
			-- Deferred: React and the builders add a button's UIScale right after the button itself.
			task.defer(function()
				if obj.Parent then UIFeel.Attach(obj) end
			end)
		end
	end
	for _, d in root:GetDescendants() do consider(d) end
	return root.DescendantAdded:Connect(consider)
end

return UIFeel
