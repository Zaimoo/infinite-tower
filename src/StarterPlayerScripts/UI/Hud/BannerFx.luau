--!strict
-- StarterPlayerScripts/UI/Hud/BannerFx.luau
-- Motion and light for the Store's summon banners (ShopPanel). All of it is client-only decoration
-- built from plain Frames and tweens (no asset ids) and runs only while the Store is open. With Reduce
-- Motion on (UIFeel.ReducedMotion) only the light stays: the rail pulse and the shimmer sweeps; motes,
-- sparkles and breathing stop.
--   * Backdrop: drifting diamond motes behind the hero tiles, a soft pulse on the banner's rail,
--     a light band sweeping across the banner every few seconds, and sparkle bursts.
--   * Breathe: a slow scale pulse for one element (the featured hero tile, Spark pick buttons).
--   * Shine: a light band sweeping across one button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local UIFeel = require(script.Parent.Parent:WaitForChild("UIFeel"))

local e = React.createElement
local BannerFx = {}

-- A banner-sized layer: motes, rail pulse, shimmer and sparkle bursts.
--   Color: mote and sparkle colour. Accent: rail pulse colour. Motes: how many (default 16).
--   Radius: the banner's corner radius. ZIndex: motes sit here (behind the tiles); light goes above.
function BannerFx.Backdrop(props: { Color: Color3, Accent: Color3, Motes: number?, Radius: number?, ZIndex: number? })
	local hostRef = React.useRef(nil :: Frame?)
	local z = props.ZIndex or 4
	React.useEffect(function()
		local host = hostRef.current
		if not host then return end
		local reduced = UIFeel.ReducedMotion()
		local alive = true

		-- Rail pulse: a bright stroke inside the banner's edge that breathes in and out.
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.Accent
		stroke.Thickness = 2.5
		stroke.Transparency = 0.85
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = host
		local pulse = TweenService:Create(stroke, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.25 })
		pulse:Play()

		-- Motes: small diamonds rising through the banner on their own drift, fading in and out.
		local motes = {}
		for i = 1, if reduced then 0 else props.Motes or 16 do
			local m = Instance.new("Frame")
			m.Name = "Mote"
			m.AnchorPoint = Vector2.new(0.5, 0.5)
			m.BorderSizePixel = 0
			m.BackgroundColor3 = props.Color:Lerp(Color3.new(1, 1, 1), math.random() * 0.4)
			local size = math.random(4, 9)
			m.Size = UDim2.fromOffset(size, size)
			m.ZIndex = z
			m.Parent = host
			table.insert(motes, { Frame = m, X = math.random(), Phase = math.random(), Speed = 0.04 + math.random() * 0.05,
				Sway = 0.01 + math.random() * 0.02, Spin = (math.random() - 0.5) * 120 })
		end
		local t0 = os.clock()
		local conn = if reduced then nil else RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			for _, mote in motes do
				local progress = (mote.Phase + t * mote.Speed) % 1
				mote.Frame.Position = UDim2.fromScale(mote.X + math.sin(t * 1.3 + mote.Phase * 6) * mote.Sway, 1.02 - progress * 1.04)
				mote.Frame.Rotation = 45 + t * mote.Spin
				mote.Frame.BackgroundTransparency = 1 - math.sin(progress * math.pi) * 0.75
			end
		end)

		-- A light band across the banner every few seconds.
		local stopShimmer = UIFeel.Shimmer(host, z + 6, true, 3.6, true)

		-- Sparkle bursts at random spots over the hero tiles.
		task.spawn(function()
			task.wait(0.6)
			while alive and not reduced and host.Parent do
				UIFeel.Burst(host, UDim2.fromScale(0.15 + math.random() * 0.7, 0.2 + math.random() * 0.4), props.Color, 10, z + 5, 80)
				task.wait(2.5 + math.random() * 2)
			end
		end)

		return function()
			alive = false
			if conn then conn:Disconnect() end
			pulse:Cancel()
			stopShimmer()
			stroke:Destroy()
			for _, mote in motes do mote.Frame:Destroy() end
		end
	end, {})
	local radius = props.Radius or 16
	return e("Frame", { ref = hostRef, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = z, Active = false }, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, radius) }),
	})
end

-- A slow scale pulse on the parent element. Use only where the parent has no other UIScale.
function BannerFx.Breathe(props: { Amount: number?, Period: number? })
	local ref = React.useRef(nil :: UIScale?)
	React.useEffect(function()
		local scale = ref.current
		if not scale or UIFeel.ReducedMotion() then return end
		local tween = TweenService:Create(scale, TweenInfo.new((props.Period or 2.4) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1 + (props.Amount or 0.03) })
		tween:Play()
		return function() tween:Cancel() end
	end, {})
	return e("UIScale", { ref = ref })
end

-- A light band sweeping across the parent button every `Period` seconds.
function BannerFx.Shine(props: { Period: number?, ZIndex: number?, Radius: number? })
	local ref = React.useRef(nil :: Frame?)
	React.useEffect(function()
		local host = ref.current
		if not host then return end
		return UIFeel.Shimmer(host, props.ZIndex or host.ZIndex + 1, true, props.Period or 2.8, true) -- light, kept under Reduce Motion
	end, {})
	return e("Frame", { ref = ref, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = props.ZIndex or 9, Active = false }, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, props.Radius or 12) }),
	})
end

return BannerFx
