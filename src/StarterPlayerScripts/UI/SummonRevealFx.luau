--!strict
-- StarterPlayerScripts/UI/SummonRevealFx.luau
-- Drawn set pieces for SummonReveal (no uploaded art needed):
--   * Circle: the hero summoning circle (tick ring, rune ring, counter-rotating octagram).
--   * Forge:  the artifact anvil, a glowing ingot and a hammer that swings about its grip.
--   * One-shots: Ring (shockwave), Converge (motes pulled into a point), Pillar (light column),
--     Steam (quench puffs) and Ember (a rising spark). One-shots are dropped under Reduce Motion.

local UIFeel = require(script.Parent:WaitForChild("UIFeel"))

local Fx = {}

local tween = UIFeel.Tween
local INK = Color3.fromRGB(14, 10, 22)
local WHITE = Color3.new(1, 1, 1)
local CENTERED = Vector2.new(0.5, 0.5)

Fx.RiftBase = Color3.fromRGB(205, 196, 235) -- the circle before it takes a rarity colour
Fx.Cold = Color3.fromRGB(120, 58, 44) -- the ingot before it heats
Fx.Hot = Color3.fromRGB(255, 142, 52)

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function cancelAll(live: { Tween })
	for _, tw in live do tw:Cancel() end
	table.clear(live)
end

-- Returns Fade(hidden, duration): 0 shows every part of `root` at its built transparency, 1 hides it.
local function fader(root: Instance): (hidden: number, duration: number) -> ()
	local parts: { { Obj: Instance, Prop: string, Base: number } } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("UIStroke") then
			table.insert(parts, { Obj = d, Prop = "Transparency", Base = d.Transparency })
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			table.insert(parts, { Obj = d, Prop = "BackgroundTransparency", Base = d.BackgroundTransparency })
		end
	end
	local live: { Tween } = {}
	return function(hidden: number, duration: number)
		cancelAll(live)
		for _, part in parts do
			local value = part.Base + (1 - part.Base) * hidden
			if duration <= 0 then
				(part.Obj :: any)[part.Prop] = value
			else
				table.insert(live, tween(part.Obj, duration, { [part.Prop] = value }))
			end
		end
	end
end

-- Returns SetColor(color, duration) over a list of { instance, property } pairs.
local function painter(targets: { { Obj: Instance, Prop: string } }): (color: Color3, duration: number) -> ()
	local live: { Tween } = {}
	return function(color: Color3, duration: number)
		cancelAll(live)
		for _, target in targets do
			if duration <= 0 then
				(target.Obj :: any)[target.Prop] = color
			else
				table.insert(live, tween(target.Obj, duration, { [target.Prop] = color }))
			end
		end
	end
end

--============================================================================
-- HERO: SUMMONING CIRCLE
--============================================================================

function Fx.Circle(parent: Instance, at: UDim2, z: number)
	local root = new("Frame", {
		Name = "SummonCircle", AnchorPoint = CENTERED, Position = at, Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1, ZIndex = z, Visible = false,
	}, parent)
	local scale = new("UIScale", {}, root)
	local paint: { { Obj: Instance, Prop: string } } = {}

	local function ring(name: string, frac: number, thickness: number?): Frame
		local f = new("Frame", {
			Name = name, AnchorPoint = CENTERED, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(frac, frac),
			BackgroundTransparency = 1, ZIndex = z,
		}, root)
		if thickness then
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
			table.insert(paint, { Obj = new("UIStroke", { Thickness = thickness, Color = Fx.RiftBase }, f), Prop = "Color" })
		end
		return f
	end

	-- Outer ring: 24 ticks pointing at the centre, every sixth one long.
	local outer = ring("Outer", 1, 3)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		local tick = new("Frame", {
			AnchorPoint = CENTERED, Position = UDim2.fromScale(0.5 + math.cos(a) * 0.45, 0.5 + math.sin(a) * 0.45),
			Size = UDim2.fromOffset(3, if i % 6 == 0 then 20 else 9), Rotation = math.deg(a) + 90,
			BackgroundColor3 = Fx.RiftBase, BorderSizePixel = 0, ZIndex = z,
		}, outer)
		table.insert(paint, { Obj = tick, Prop = "BackgroundColor3" })
	end

	-- Rune ring: eight diamonds riding a thin line.
	local mid = ring("Mid", 0.78, 1.5)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local rune = new("Frame", {
			AnchorPoint = CENTERED, Position = UDim2.fromScale(0.5 + math.cos(a) * 0.5, 0.5 + math.sin(a) * 0.5),
			Size = UDim2.fromOffset(10, 10), Rotation = math.deg(a) + 45,
			BackgroundColor3 = Fx.RiftBase, BorderSizePixel = 0, ZIndex = z + 1,
		}, mid)
		table.insert(paint, { Obj = rune, Prop = "BackgroundColor3" })
	end

	-- Octagram: two squares inscribed in the inner circle, 45° apart.
	local inner = ring("Inner", 0.6, 1.5)
	for i = 0, 1 do
		local square = new("Frame", {
			AnchorPoint = CENTERED, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.707, 0.707),
			Rotation = i * 45, BackgroundTransparency = 1, ZIndex = z,
		}, inner)
		local stroke = new("UIStroke", { Thickness = 2, Color = Fx.RiftBase, LineJoinMode = Enum.LineJoinMode.Miter }, square)
		table.insert(paint, { Obj = stroke, Prop = "Color" })
	end

	return {
		Root = root :: Frame, Scale = scale :: UIScale,
		Outer = outer, Mid = mid, Inner = inner,
		SetColor = painter(paint), Fade = fader(root),
	}
end

--============================================================================
-- ARTIFACT: ANVIL, INGOT AND HAMMER
--============================================================================

Fx.IngotSize = UDim2.fromOffset(120, 22)
Fx.HammerRaised = 55 -- degrees; 0 is the head resting on the ingot

function Fx.Forge(parent: Instance, at: UDim2, z: number)
	-- 360×260; the ingot's top face sits on the root's centre, so effects can aim at `at`.
	local root = new("Frame", {
		Name = "ForgeAnvil", AnchorPoint = CENTERED, Position = at, Size = UDim2.fromOffset(360, 260),
		BackgroundTransparency = 1, ZIndex = z, Visible = false,
	}, parent)
	local scale = new("UIScale", {}, root)

	local function slab(name: string, x: number, y: number, w: number, h: number, color: Color3, host: Instance?, zi: number?): Frame
		local f = new("Frame", {
			Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = zi or z,
		}, host or root)
		new("UICorner", { CornerRadius = UDim.new(0, 5) }, f)
		new("UIStroke", { Color = INK, Thickness = 2 }, f)
		return f
	end

	local steel = Color3.fromRGB(66, 62, 78)
	slab("Base", 105, 218, 150, 28, steel:Lerp(INK, 0.25))
	slab("Waist", 145, 180, 70, 42, steel:Lerp(INK, 0.15))
	slab("Horn", 38, 158, 60, 18, steel)
	local top = slab("Top", 80, 152, 200, 32, steel)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165)) }, top)

	local ingot = new("Frame", {
		Name = "Ingot", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(180, 152), Size = Fx.IngotSize,
		BackgroundColor3 = Fx.Cold, BorderSizePixel = 0, ZIndex = z + 1,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, ingot)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175)) }, ingot)
	local halo = new("UIStroke", { Color = Fx.Cold, Thickness = 5, Transparency = 0.55 }, ingot)

	-- The hammer turns about its grip: a square host centred on the grip, the head at its left edge.
	local hammer = new("Frame", {
		Name = "Hammer", AnchorPoint = CENTERED, Position = UDim2.fromOffset(300, 110), Size = UDim2.fromOffset(280, 280),
		BackgroundTransparency = 1, Rotation = Fx.HammerRaised, ZIndex = z + 2,
	}, root)
	slab("Handle", 14, 135, 132, 10, Color3.fromRGB(124, 86, 54), hammer, z + 2)
	local head = slab("Head", 0, 118, 44, 44, Color3.fromRGB(152, 148, 164), hammer, z + 3)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 150)) }, head)

	return {
		Root = root :: Frame, Scale = scale :: UIScale,
		Ingot = ingot :: Frame, Hammer = hammer :: Frame,
		SetHeat = painter({ { Obj = ingot, Prop = "BackgroundColor3" }, { Obj = halo, Prop = "Color" } }),
		Fade = fader(root),
	}
end

--============================================================================
-- ONE-SHOTS
--============================================================================

-- A ring that grows from `from` to `to` pixels across while it thins out and fades.
function Fx.Ring(parent: Instance, at: UDim2, color: Color3, z: number, from: number, to: number, t: number)
	if UIFeel.ReducedMotion() then return end
	local f = new("Frame", {
		Name = "Shockwave", AnchorPoint = CENTERED, Position = at, Size = UDim2.fromOffset(from, from),
		BackgroundTransparency = 1, ZIndex = z,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	local stroke = new("UIStroke", { Color = color:Lerp(WHITE, 0.3), Thickness = 7, Transparency = 0.1 }, f)
	tween(f, t, { Size = UDim2.fromOffset(to, to) }, Enum.EasingStyle.Quart)
	tween(stroke, t, { Transparency = 1, Thickness = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(t + 0.05, function() f:Destroy() end)
end

-- Motes that start on a circle of `radius` and get pulled into `at`.
function Fx.Converge(parent: Instance, at: UDim2, color: Color3, count: number, z: number, radius: number, t: number)
	if UIFeel.ReducedMotion() then return end
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.6
		local dist = radius * (0.7 + math.random() * 0.5)
		local size = math.random(6, 12)
		local life = t * (0.7 + math.random() * 0.3)
		local p = new("Frame", {
			Name = "Mote", AnchorPoint = CENTERED, Position = at + UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist),
			Size = UDim2.fromOffset(size, size), Rotation = 45, BackgroundColor3 = color:Lerp(WHITE, 0.35),
			BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = z,
		}, parent)
		tween(p, life, { Position = at, Size = UDim2.fromOffset(2, 2), Rotation = 225 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(p, life * 0.5, { BackgroundTransparency = 0 })
		task.delay(life + 0.03, function() p:Destroy() end)
	end
end

-- A column of light through `at` that widens and fades.
function Fx.Pillar(parent: Instance, at: UDim2, color: Color3, z: number, big: boolean)
	if UIFeel.ReducedMotion() then return end
	local f = new("Frame", {
		Name = "Pillar", AnchorPoint = CENTERED, Position = at, Size = UDim2.fromOffset(18, 1600),
		BackgroundColor3 = color:Lerp(WHITE, 0.5), BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = z,
	}, parent)
	new("UIGradient", { Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
	}) }, f)
	local t = if big then 0.75 else 0.5
	tween(f, t, { Size = UDim2.fromOffset(if big then 440 else 260, 1600), BackgroundTransparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(t + 0.05, function() f:Destroy() end)
end

-- Quench steam: soft puffs that rise, swell and fade.
function Fx.Steam(parent: Instance, at: UDim2, z: number)
	if UIFeel.ReducedMotion() then return end
	for _ = 1, 8 do
		local size = math.random(28, 52)
		local life = 0.7 + math.random() * 0.4
		local x = math.random(-80, 80)
		local p = new("Frame", {
			Name = "Steam", AnchorPoint = CENTERED, Position = at + UDim2.fromOffset(x, -4), Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Color3.fromRGB(236, 232, 244), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = z,
		}, parent)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, p)
		tween(p, life, {
			Position = at + UDim2.fromOffset(x * 1.5 + math.random(-20, 20), -math.random(100, 180)),
			Size = UDim2.fromOffset(size * 1.9, size * 1.9), BackgroundTransparency = 1,
		})
		task.delay(life + 0.05, function() p:Destroy() end)
	end
end

-- One spark drifting up from below `at` (looped behind a landed artifact card).
function Fx.Ember(parent: Instance, at: UDim2, color: Color3, z: number)
	if UIFeel.ReducedMotion() then return end
	local size = math.random(4, 9)
	local life = 1 + math.random() * 0.6
	local x = math.random(-190, 190)
	local p = new("Frame", {
		Name = "Ember", AnchorPoint = CENTERED, Position = at + UDim2.fromOffset(x, 200), Size = UDim2.fromOffset(size, size),
		Rotation = 45, BackgroundColor3 = color:Lerp(Fx.Hot, 0.4):Lerp(WHITE, 0.2), BackgroundTransparency = 0.15,
		BorderSizePixel = 0, ZIndex = z,
	}, parent)
	tween(p, life, { Position = at + UDim2.fromOffset(x + math.random(-40, 40), -math.random(120, 240)), Rotation = 225 }, Enum.EasingStyle.Sine)
	tween(p, life, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(life + 0.05, function() p:Destroy() end)
end

return Fx
