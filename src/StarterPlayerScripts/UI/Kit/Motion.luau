--!strict
-- StarterPlayerScripts/UI/Kit/Motion.luau
-- Motion presets (UI overhaul plan §4.8) on top of UIFeel. Every preset respects Reduce Motion:
-- with it on, things snap to their end state (sounds and haptics still play where relevant).

local TweenService = game:GetService("TweenService")

local UIFeel = require(script.Parent.Parent:WaitForChild("UIFeel"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))

local Motion = {}

local OPEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out) -- tiles (Stagger)
local SLIDE = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function reduced(): boolean
	return UIFeel.ReducedMotion()
end

-- Window open and close: the shared motion in UIFeel (pop from 94%, shrink to 96%).
function Motion.Open(root: GuiObject, scale: UIScale, target: number?)
	root.Visible = true
	UIFeel.WindowIn(scale, target or 1)
end

-- `onDone` runs once the window is hidden.
function Motion.Close(root: GuiObject, scale: UIScale, onDone: (() -> ())?)
	local function finish()
		root.Visible = false
		if onDone then onDone() end
	end
	if not root.Visible then finish() return end
	UIFeel.WindowOut(scale, finish)
end

-- New tab content slides 12 px in from the side it came from (dir 1 = from the right).
function Motion.TabSwap(content: GuiObject, dir: number?)
	UIFeel.Sfx("TabSwitch", 1, 0.4)
	if reduced() then return end
	local base = content.Position
	content.Position = base + UDim2.fromOffset(12 * (dir or 1), 0)
	TweenService:Create(content, SLIDE, { Position = base }):Play()
end

-- Grid children pop in one after another (18 ms apart). Past `cap` they appear at once.
function Motion.Stagger(items: { GuiObject }, step: number?, cap: number?)
	if reduced() then return end
	local gap, limit = step or 0.018, cap or 12
	for i, item in items do
		if i > limit then break end
		local scale = UIFeel.Scale(item)
		scale.Scale = 0.6
		task.delay((i - 1) * gap, function()
			if item.Parent then
				TweenService:Create(scale, OPEN, { Scale = 1 }):Play()
			end
		end)
	end
end

-- A tile being picked: a quick 1 → 1.06 → 1.03 settle.
function Motion.Select(obj: GuiObject)
	if reduced() then return end
	local scale = UIFeel.Scale(obj)
	local up = TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 1.06 })
	up.Completed:Once(function()
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1.03 }):Play()
	end)
	up:Play()
end

-- Something new or claimable: a slow pulse until the returned stop function is called.
function Motion.Attention(obj: GuiObject, period: number?): () -> ()
	local alive = true
	if reduced() then return function() alive = false end end
	local scale = UIFeel.Scale(obj)
	task.spawn(function()
		while alive and obj.Parent do
			local up = TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Scale = 1.07 })
			up:Play()
			up.Completed:Wait()
			if not alive then break end
			local down = TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Scale = 1 })
			down:Play()
			down.Completed:Wait()
			task.wait(period or 1.6)
		end
		scale.Scale = 1
	end)
	return function() alive = false end
end

-- A number changing: counts up and flashes green (up) or red (down) before settling back.
function Motion.NumberTick(label: TextLabel, from: number, to: number, format: ((number) -> string)?)
	local fmt = format or function(n: number) return tostring(math.round(n)) end
	if reduced() or from == to then label.Text = fmt(to) return end
	local rest = label.TextColor3
	label.TextColor3 = if to > from then Tokens.Severity.success else Tokens.Severity.error
	local start = os.clock()
	local duration = 0.45
	task.spawn(function()
		while label.Parent do
			local t = math.min(1, (os.clock() - start) / duration)
			local eased = 1 - (1 - t) ^ 3
			label.Text = fmt(from + (to - from) * eased)
			if t >= 1 then break end
			task.wait()
		end
		TweenService:Create(label, TweenInfo.new(0.4), { TextColor3 = rest }):Play()
	end)
end

-- A bar's fill tweening to `fraction` (0..1).
function Motion.BarFill(fill: GuiObject, fraction: number)
	local goal = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	if reduced() then fill.Size = goal return end
	TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = goal }):Play()
end

-- Commit success: a burst and shimmer on `host` (usually the primary button).
function Motion.Success(host: GuiObject)
	UIFeel.Sfx("Reward", 1, 0.5)
	if reduced() then return end
	UIFeel.Burst(host, UDim2.fromScale(0.5, 0.5), Tokens.Severity.reward, 10, host.ZIndex + 5, 60)
	UIFeel.Shimmer(host, host.ZIndex + 4)
end

Motion.Deny = UIFeel.Deny

return table.freeze(Motion)
