--!strict
-- ReplicatedStorage/Assets/CombatVfx/VfxPrimitives.luau
-- Building blocks for combat VFX (docs/projectile-skill-vfx-plan.md, section 6). Each one
-- schedules a pooled effect on a VfxPool with server-time start and end, so effects line up with
-- the server's hits. Phase 3 needs Flight, Burst, Disc, Sigil and At; later phases add more.

local VfxMath = require(script.Parent:WaitForChild("VfxMath"))
local VfxPool = require(script.Parent:WaitForChild("VfxPool"))

local VfxPrimitives = {}

local function newPart(name: string, shape: Enum.PartType, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end
VfxPrimitives.NewPart = newPart

local function single(name: string, shape: Enum.PartType, material: Enum.Material): () -> Model
	return function(): Model
		local model = Instance.new("Model")
		model.Name = name
		local part = newPart(name, shape, material)
		part.Parent = model
		model.PrimaryPart = part
		return model
	end
end

local buildBurst = single("VfxBurst", Enum.PartType.Ball, Enum.Material.Neon)
local buildDisc = single("VfxDisc", Enum.PartType.Cylinder, Enum.Material.ForceField)
local buildSpoke = single("VfxSpoke", Enum.PartType.Block, Enum.Material.Neon)

-- Cylinder parts lie along X; this turns one flat on the ground.
local FLAT = CFrame.Angles(0, 0, math.pi / 2)

-- Calls `fn` once at server time `at` (or on the next frame if that has passed).
function VfxPrimitives.At(pool: VfxPool.VfxPool, at: number, fn: () -> ())
	pool:Run({
		Update = function(now: number): boolean
			if now < at then
				return false
			end
			fn()
			return true
		end,
	})
end

export type FlightOptions = {
	Kind: string, -- pool key
	Build: () -> Model, -- builds the projectile; -Z of its pivot is forward
	Prepare: ((Model) -> ())?, -- runs on every acquire (pooled bodies are shared between heroes)
	From: Vector3,
	To: () -> Vector3, -- read every frame so the projectile follows a moving target
	StartAt: number,
	EndAt: number,
	Lift: number?, -- studs of arc at mid-flight
	OnArrive: ((at: Vector3) -> ())?,
}

-- A projectile flying From -> To over [StartAt, EndAt]. It appears at StartAt, faces along its
-- path, and is released back to the pool on arrival.
function VfxPrimitives.Flight(pool: VfxPool.VfxPool, options: FlightOptions): boolean
	local model = pool:Acquire(options.Kind, options.Build)
	if options.Prepare then
		options.Prepare(model)
	end
	local lift = options.Lift or 0
	local shown = false
	local last = options.From
	return pool:Run({
		Update = function(now: number): boolean
			if now < options.StartAt then
				return false
			end
			local target = options.To()
			local alpha = VfxMath.Progress(options.StartAt, options.EndAt, now)
			local position = VfxMath.ArcPoint(options.From, target, alpha, lift)
			local ahead = VfxMath.ArcPoint(options.From, target, math.min(1, alpha + 0.02), lift)
			if (ahead - position).Magnitude < 1e-3 then
				local heading = target - options.From
				ahead = position + (if heading.Magnitude > 1e-3 then heading.Unit else Vector3.new(0, 0, -1))
			end
			model:PivotTo(CFrame.lookAt(position, ahead))
			if not shown then
				shown = true
				pool:Show(model)
			end
			last = position
			if alpha >= 1 then
				if options.OnArrive then
					options.OnArrive(last)
				end
				return true
			end
			return false
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

-- A glowing sphere that swells to `size` and fades out over `duration` seconds from `at`.
function VfxPrimitives.Burst(pool: VfxPool.VfxPool, position: Vector3, color: Color3, size: number, at: number, duration: number?)
	local model = pool:Acquire("BURST", buildBurst)
	local part = model.PrimaryPart :: BasePart
	local length = duration or 0.25
	part.Color = color
	part.Transparency = 1
	part.Size = Vector3.one * 0.1
	part.CFrame = CFrame.new(position)
	pool:Show(model)
	pool:Run({
		Update = function(now: number): boolean
			if now < at then
				return false
			end
			local t = VfxMath.Progress(at, at + length, now)
			local eased = 1 - (1 - t) * (1 - t)
			part.Size = Vector3.one * math.max(0.1, size * (0.3 + 0.7 * eased))
			part.Transparency = 0.15 + 0.85 * t
			return t >= 1
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

export type DiscOptions = {
	CFrame: CFrame, -- centre; the disc's face is perpendicular to this CFrame's X axis
	Radius: number,
	Color: Color3,
	StartAt: number,
	EndAt: number,
	Grow: number?, -- fraction of the radius it starts at (default 1)
	Transparency: number?, -- at full strength (default 0.35)
}

-- A thin glowing disc that fades in, holds and fades out over [StartAt, EndAt].
function VfxPrimitives.Disc(pool: VfxPool.VfxPool, options: DiscOptions)
	local model = pool:Acquire("DISC", buildDisc)
	local part = model.PrimaryPart :: BasePart
	local base = options.Transparency or 0.35
	local grow = options.Grow or 1
	part.Color = options.Color
	part.Transparency = 1
	part.CFrame = options.CFrame
	pool:Show(model)
	pool:Run({
		Update = function(now: number): boolean
			if now < options.StartAt then
				return false
			end
			local t = VfxMath.Progress(options.StartAt, options.EndAt, now)
			local fade = math.min(1, t / 0.15, (1 - t) / 0.2)
			local radius = options.Radius * (grow + (1 - grow) * math.min(1, t / 0.25))
			part.Size = Vector3.new(0.08, radius * 2, radius * 2)
			part.Transparency = 1 - (1 - base) * math.clamp(fade, 0, 1)
			return t >= 1
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

-- A flat sigil on the ground: a disc, an inner disc and turning spokes, over [startAt, endAt].
function VfxPrimitives.Sigil(pool: VfxPool.VfxPool, center: Vector3, radius: number, palette: any, startAt: number, endAt: number)
	local ground = CFrame.new(center + Vector3.new(0, 0.15, 0))
	VfxPrimitives.Disc(pool, { CFrame = ground * FLAT, Radius = radius, Color = palette.Secondary, StartAt = startAt, EndAt = endAt, Grow = 0.2, Transparency = 0.45 })
	VfxPrimitives.Disc(pool, { CFrame = (ground + Vector3.new(0, 0.05, 0)) * FLAT, Radius = radius * 0.55, Color = palette.Primary, StartAt = startAt, EndAt = endAt, Grow = 0.1, Transparency = 0.3 })

	local spokes = 6
	for i = 1, spokes do
		local model = pool:Acquire("SPOKE", buildSpoke)
		local part = model.PrimaryPart :: BasePart
		part.Color = palette.Primary
		part.Transparency = 1
		pool:Show(model)
		local offset = (i - 1) / spokes * math.pi * 2
		pool:Run({
			Update = function(now: number): boolean
				if now < startAt then
					return false
				end
				local t = VfxMath.Progress(startAt, endAt, now)
				local fade = math.clamp(math.min(1, t / 0.15, (1 - t) / 0.2), 0, 1)
				local length = radius * 0.9 * math.min(1, t / 0.25)
				local angle = offset + (now - startAt) * 1.6
				part.Size = Vector3.new(0.2, 0.06, math.max(0.1, length))
				part.CFrame = (ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -length / 2)
				part.Transparency = 1 - 0.75 * fade
				return t >= 1
			end,
			Cleanup = function()
				pool:Release(model)
			end,
		})
	end
end

-- A ring of light facing along `direction` (a disc seen edge-on reads as a ring as it passes).
function VfxPrimitives.FlightRing(pool: VfxPool.VfxPool, position: Vector3, direction: Vector3, radius: number, color: Color3, at: number)
	if direction.Magnitude < 1e-3 then
		return
	end
	local frame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.pi / 2, 0)
	VfxPrimitives.Disc(pool, { CFrame = frame, Radius = radius, Color = color, StartAt = at, EndAt = at + 0.35, Grow = 0.3, Transparency = 0.25 })
end

-- Multi-segment assemblies: `count` neon blocks under one model, laid out each frame.
local function segments(name: string, count: number, material: Enum.Material?): () -> Model
	return function(): Model
		local model = Instance.new("Model")
		model.Name = name
		local first: BasePart? = nil
		for i = 1, count do
			local part = newPart(`{name}_{i}`, Enum.PartType.Block, material or Enum.Material.Neon)
			part.Transparency = 1
			part:SetAttribute("Index", i)
			part.Parent = model
			first = first or part
		end
		model.PrimaryPart = first
		return model
	end
end

local function parts(model: Model): { BasePart }
	local list: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
	end)
	return list
end

local function fadeIn(t: number, inPart: number, outPart: number): number
	return math.clamp(math.min(1, t / inPart, (1 - t) / outPart), 0, 1)
end

-- Yaw that turns -Z towards a horizontal direction (the server's hero yaw convention).
function VfxPrimitives.Yaw(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local RING_SEGMENTS = 16
local buildRing = segments("VfxRing", RING_SEGMENTS)

export type RingOptions = {
	Center: Vector3, -- on the ground
	From: number, -- starting radius
	To: number, -- final radius
	Color: Color3,
	StartAt: number,
	EndAt: number,
	Arc: number?, -- degrees of the circle drawn (default 360)
	Facing: number?, -- yaw of the arc's middle (default 0)
	Width: number?, -- band width, studs (default 0.6)
}

-- An expanding ring of light on the ground (a shockwave), or a cone-shaped part of one.
function VfxPrimitives.Ring(pool: VfxPool.VfxPool, options: RingOptions)
	local model = pool:Acquire("RING", buildRing)
	local list = parts(model)
	local arc = math.rad(options.Arc or 360)
	local facing = options.Facing or 0
	local width = options.Width or 0.6
	local base = CFrame.new(options.Center + Vector3.new(0, 0.2, 0))
	for _, part in list do
		part.Color = options.Color
		part.Transparency = 1
	end
	pool:Show(model)
	pool:Run({
		Update = function(now: number): boolean
			if now < options.StartAt then
				return false
			end
			local t = VfxMath.Progress(options.StartAt, options.EndAt, now)
			local eased = 1 - (1 - t) * (1 - t)
			local radius = options.From + (options.To - options.From) * eased
			local step = arc / #list
			local length = 2 * radius * math.sin(step / 2) * 1.08
			local transparency = 1 - 0.85 * fadeIn(t, 0.1, 0.6)
			for i, part in list do
				local angle = facing - arc / 2 + step * (i - 0.5)
				part.Size = Vector3.new(math.max(0.1, length), 0.12, width)
				part.CFrame = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
				part.Transparency = transparency
			end
			return t >= 1
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

local ARC_SEGMENTS = 9
local buildArc = segments("VfxArc", ARC_SEGMENTS)

-- A crescent slash swept across `frame` (its -Z faces the viewer side of the cut; roll it about
-- Z for diagonal cuts): drawn over 0.1 s from `at`, then faded.
function VfxPrimitives.SlashArc(pool: VfxPool.VfxPool, frame: CFrame, radius: number, color: Color3, at: number, duration: number?)
	local model = pool:Acquire("ARC", buildArc)
	local list = parts(model)
	local span = math.rad(165)
	local length = duration or 0.32
	local sweep = 0.1
	for _, part in list do
		part.Color = color
		part.Transparency = 1
	end
	pool:Show(model)
	pool:Run({
		Update = function(now: number): boolean
			if now < at then
				return false
			end
			local drawn = math.clamp((now - at) / sweep, 0, 1)
			local t = VfxMath.Progress(at, at + length, now)
			local fade = 1 - math.clamp((t - 0.35) / 0.65, 0, 1)
			local step = span / #list
			for i, part in list do
				local u = (i - 0.5) / #list
				local angle = -span / 2 + step * (i - 0.5)
				local thickness = 0.3 * radius * math.sin(math.pi * u)
				part.Size = Vector3.new(2 * radius * math.sin(step / 2) * 1.1, 0.14, math.max(0.05, thickness))
				part.CFrame = frame * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
				part.Transparency = if u <= drawn then 1 - 0.9 * fade else 1
			end
			return t >= 1
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

local buildShell = single("VfxShell", Enum.PartType.Ball, Enum.Material.ForceField)

-- A protective sphere that follows `center()` over [startAt, endAt].
function VfxPrimitives.Shell(pool: VfxPool.VfxPool, center: () -> Vector3, radius: number, color: Color3, startAt: number, endAt: number)
	local model = pool:Acquire("SHELL", buildShell)
	local part = model.PrimaryPart :: BasePart
	part.Color = color
	part.Transparency = 1
	part.CFrame = CFrame.new(center())
	pool:Show(model)
	pool:Run({
		Update = function(now: number): boolean
			if now < startAt then
				return false
			end
			local t = VfxMath.Progress(startAt, endAt, now)
			local grow = math.min(1, (now - startAt) / 0.2)
			part.Size = Vector3.one * radius * 2 * (0.6 + 0.4 * grow)
			part.CFrame = CFrame.new(center())
			part.Transparency = 1 - 0.8 * fadeIn(t, 0.05, 0.1)
			return t >= 1
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

local buildPillar = single("VfxPillar", Enum.PartType.Cylinder, Enum.Material.Neon)
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

-- A column of light at `base`: it reaches down from `height` to the ground over
-- [startAt, impactAt], then holds and fades over `hold` seconds.
function VfxPrimitives.Pillar(pool: VfxPool.VfxPool, base: Vector3, radius: number, height: number, color: Color3, startAt: number, impactAt: number, hold: number)
	local model = pool:Acquire("PILLAR", buildPillar)
	local part = model.PrimaryPart :: BasePart
	part.Color = color
	part.Transparency = 1
	part.CFrame = CFrame.new(base + Vector3.new(0, height, 0)) * UPRIGHT
	pool:Show(model)
	local endAt = impactAt + hold
	pool:Run({
		Update = function(now: number): boolean
			if now < startAt then
				return false
			end
			local reach = VfxMath.Progress(startAt, impactAt, now)
			local length = math.max(0.2, height * reach)
			local after = VfxMath.Progress(impactAt, endAt, now)
			local width = radius * 2 * (if now < impactAt then 0.6 else 1 - 0.5 * after)
			part.Size = Vector3.new(length, width, width)
			part.CFrame = CFrame.new(base + Vector3.new(0, height - length / 2, 0)) * UPRIGHT
			part.Transparency = if now < impactAt then 0.25 else 0.25 + 0.75 * after
			return now >= endAt
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

local BEAM_SEGMENTS = 4
local buildBeam = segments("VfxBeam", BEAM_SEGMENTS)

-- A jagged arc of energy from `a` to `b`, flickering for `duration` seconds from `at`.
function VfxPrimitives.Beam(pool: VfxPool.VfxPool, a: Vector3, b: Vector3, color: Color3, at: number, duration: number?, seed: number?)
	local model = pool:Acquire("BEAM", buildBeam)
	local list = parts(model)
	local length = duration or 0.3
	local s = seed or 0
	-- Fixed zigzag points between a and b, offset sideways and up.
	local points = { a }
	local direction = b - a
	local side = if direction.Magnitude > 1e-3 then direction:Cross(Vector3.yAxis) else Vector3.xAxis
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	for i = 1, #list - 1 do
		local f = i / #list
		local jitter = math.sin(s * 12.9898 + i * 78.233) * 0.9
		table.insert(points, a:Lerp(b, f) + side * jitter + Vector3.new(0, math.cos(s + i) * 0.5, 0))
	end
	table.insert(points, b)
	for i, part in list do
		local p0, p1 = points[i], points[i + 1]
		part.Color = color
		part.Transparency = 1
		part.Size = Vector3.new(0.18, 0.18, math.max(0.1, (p1 - p0).Magnitude))
		part.CFrame = CFrame.lookAt(p0:Lerp(p1, 0.5), p1)
	end
	pool:Show(model)
	pool:Run({
		Update = function(now: number): boolean
			if now < at then
				return false
			end
			local t = VfxMath.Progress(at, at + length, now)
			local flicker = if math.floor((now - at) * 30) % 2 == 0 then 0.05 else 0.35
			for _, part in list do
				part.Transparency = math.min(1, flicker + 0.95 * t)
			end
			return t >= 1
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

local buildSpike = single("VfxSpike", Enum.PartType.Block, Enum.Material.Neon)

-- A crystal spike that shoots up out of the ground at `at`, holds for `hold` and fades.
function VfxPrimitives.Spike(pool: VfxPool.VfxPool, base: Vector3, height: number, color: Color3, at: number, hold: number, seed: number?)
	local model = pool:Acquire("SPIKE", buildSpike)
	local part = model.PrimaryPart :: BasePart
	local s = seed or 0
	local tilt = CFrame.Angles(math.rad(math.sin(s * 3.1) * 14), math.rad(45 + s * 37 % 90), math.rad(math.cos(s * 2.3) * 14))
	local width = height * 0.22
	part.Color = color
	part.Transparency = 1
	part.Size = Vector3.new(width, height, width)
	part.CFrame = CFrame.new(base) * tilt * CFrame.new(0, -height / 2, 0)
	pool:Show(model)
	local rise = 0.12
	local endAt = at + rise + hold + 0.3
	pool:Run({
		Update = function(now: number): boolean
			if now < at then
				return false
			end
			local up = math.clamp((now - at) / rise, 0, 1)
			local fade = math.clamp((now - (at + rise + hold)) / 0.3, 0, 1)
			part.CFrame = CFrame.new(base) * tilt * CFrame.new(0, -height / 2 + height * up * 0.95, 0)
			part.Transparency = 0.15 + 0.85 * fade
			return now >= endAt
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

local buildMote = single("VfxMote", Enum.PartType.Ball, Enum.Material.Neon)

-- `count` small motes of light rising from around `center` over `duration` seconds from `at`.
function VfxPrimitives.Motes(pool: VfxPool.VfxPool, center: Vector3, color: Color3, at: number, count: number, duration: number?)
	local length = duration or 0.8
	for i = 1, count do
		local model = pool:Acquire("MOTE", buildMote)
		local part = model.PrimaryPart :: BasePart
		local angle = i / count * math.pi * 2
		local start = center + Vector3.new(math.cos(angle) * 1.2, -0.5 + (i % 3) * 0.4, math.sin(angle) * 1.2)
		part.Color = color
		part.Transparency = 1
		part.Size = Vector3.one * 0.35
		part.CFrame = CFrame.new(start)
		pool:Show(model)
		pool:Run({
			Update = function(now: number): boolean
				if now < at then
					return false
				end
				local t = VfxMath.Progress(at, at + length, now)
				part.CFrame = CFrame.new(start + Vector3.new(0, 3 * t, 0))
				part.Transparency = 0.1 + 0.9 * t
				return t >= 1
			end,
			Cleanup = function()
				pool:Release(model)
			end,
		})
	end
end

-- The reverse of Burst: a sphere that collapses from `size` to a point over `duration` seconds
-- from `at`, accelerating and brightening as it closes (a hit being swallowed).
function VfxPrimitives.Implode(pool: VfxPool.VfxPool, position: Vector3, color: Color3, size: number, at: number, duration: number?)
	local model = pool:Acquire("BURST", buildBurst)
	local part = model.PrimaryPart :: BasePart
	local length = duration or 0.14
	part.Color = color
	part.Transparency = 1
	part.Size = Vector3.one * size
	part.CFrame = CFrame.new(position)
	pool:Show(model)
	pool:Run({
		Update = function(now: number): boolean
			if now < at then
				return false
			end
			local t = VfxMath.Progress(at, at + length, now)
			part.Size = Vector3.one * math.max(0.1, size * (1 - t * t))
			part.Transparency = 0.75 - 0.6 * t
			return t >= 1
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

-- A small spell glyph that follows `frame()` over [startAt, endAt]: a faint disc with three
-- spokes turning inside it (a six-pointed star), growing in and fading out. The glyph lies in
-- the frame's XY plane, facing along its -Z (CFrame.lookAt towards what it casts at).
function VfxPrimitives.Glyph(pool: VfxPool.VfxPool, frame: () -> CFrame, radius: number, palette: any, startAt: number, endAt: number)
	local discModel = pool:Acquire("DISC", buildDisc)
	local disc = discModel.PrimaryPart :: BasePart
	disc.Color = palette.Secondary
	disc.Transparency = 1
	pool:Show(discModel)
	local spokes: { Model } = {}
	for i = 1, 3 do
		local model = pool:Acquire("SPOKE", buildSpoke)
		local part = model.PrimaryPart :: BasePart
		part.Color = if i == 1 then palette.Core else palette.Primary
		part.Transparency = 1
		pool:Show(model)
		spokes[i] = model
	end
	pool:Run({
		Update = function(now: number): boolean
			if now < startAt then
				return false
			end
			local t = VfxMath.Progress(startAt, endAt, now)
			local grow = math.min(1, t / 0.3)
			local fade = fadeIn(t, 0.2, 0.15)
			local r = math.max(0.05, radius * (0.3 + 0.7 * grow))
			local at = frame()
			disc.Size = Vector3.new(0.04, r * 2, r * 2)
			disc.CFrame = at * CFrame.Angles(0, math.pi / 2, 0)
			disc.Transparency = 1 - 0.55 * fade
			-- Spins up as it charges: a quarter turn per second at first, two turns at the end.
			local spin = (now - startAt) * (1.5 + 10 * t)
			for i, model in spokes do
				local part = model.PrimaryPart :: BasePart
				part.Size = Vector3.new(0.05, r * 1.9, 0.03)
				part.CFrame = at * CFrame.new(0, 0, -0.03) * CFrame.Angles(0, 0, spin + (i - 1) * math.pi / 3)
				part.Transparency = 1 - 0.85 * fade
			end
			return t >= 1
		end,
		Cleanup = function()
			pool:Release(discModel)
			for _, model in spokes do
				pool:Release(model)
			end
		end,
	})
end

-- `count` motes drawn in from a shell of `radius` around `center()` to its centre over
-- [startAt, endAt], each starting a little later than the last and spiralling as it closes.
function VfxPrimitives.Converge(pool: VfxPool.VfxPool, center: () -> Vector3, color: Color3, radius: number, count: number, startAt: number, endAt: number, seed: number?)
	local span = math.max(0.05, endAt - startAt)
	local base = seed or 0
	for i = 1, count do
		local model = pool:Acquire("MOTE", buildMote)
		local part = model.PrimaryPart :: BasePart
		-- Spread start directions over a sphere (golden-angle spiral), turned by the seed.
		local y = 1 - 2 * (i - 0.5) / count
		local ring = math.sqrt(math.max(0, 1 - y * y))
		local angle = base + i * 2.399963
		local direction = Vector3.new(math.cos(angle) * ring, y * 0.6, math.sin(angle) * ring)
		local from = startAt + span * 0.4 * (i - 1) / math.max(1, count - 1)
		part.Color = color
		part.Transparency = 1
		part.Size = Vector3.one * 0.22
		pool:Show(model)
		pool:Run({
			Update = function(now: number): boolean
				if now < from then
					return false
				end
				local t = VfxMath.Progress(from, endAt, now)
				local closing = t * t
				local twist = CFrame.Angles(0, closing * 2.2, 0)
				local offset = twist:VectorToWorldSpace(direction) * radius * (1 - closing)
				part.CFrame = CFrame.new(center() + offset)
				part.Size = Vector3.one * (0.22 + 0.1 * t)
				part.Transparency = 1 - 0.85 * fadeIn(t, 0.25, 0.08)
				return t >= 1
			end,
			Cleanup = function()
				pool:Release(model)
			end,
		})
	end
end

-- Vane's void kit (docs/vane-spell-animations-plan.md) ------------------------------------

local function lanceModel(): Model
	local model = Instance.new("Model")
	model.Name = "VfxLance"
	for i, spec in { { "Core", Enum.Material.Neon }, { "Sheath", Enum.Material.Neon }, { "Haze", Enum.Material.ForceField } } do
		local part = newPart(spec[1], Enum.PartType.Cylinder, spec[2])
		part:SetAttribute("Index", i)
		part.Parent = model
		if i == 1 then
			model.PrimaryPart = part
		end
	end
	return model
end

-- A straight beam of light from `a` to `b`, `width` studs across: a bright core, a coloured
-- sheath and a shimmering haze. Its head shoots out from `a` to `b` over `extend` seconds from
-- `at`, holds for `hold`, then thins to nothing and fades over `fade`.
function VfxPrimitives.Lance(pool: VfxPool.VfxPool, a: Vector3, b: Vector3, width: number, palette: any, at: number, extend: number, hold: number, fade: number)
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.1 then
		return
	end
	local model = pool:Acquire("LANCE", lanceModel)
	local list = parts(model)
	local colors = { palette.Core, palette.Primary, palette.Primary }
	local widths = { 0.3, 0.6, 1.0 }
	local opacity = { 0, 0.25, 0.4 }
	for i, part in list do
		part.Color = colors[i]
		part.Transparency = 1
	end
	pool:Show(model)
	-- Cylinders lie along X; this turn points local +X from `a` towards `b`.
	local frame = CFrame.lookAt(a, b) * CFrame.Angles(0, math.pi / 2, 0)
	local finish = at + extend + hold + fade
	pool:Run({
		Update = function(now: number): boolean
			if now < at then
				return false
			end
			local reach = length * VfxMath.Progress(at, at + extend, now)
			local thin = 1 - VfxMath.Progress(at + extend + hold, finish, now)
			local swell = 1 + 0.25 * (1 - VfxMath.Progress(at, at + extend + 0.06, now))
			for i, part in list do
				local diameter = math.max(0.05, width * widths[i] * thin * swell)
				part.Size = Vector3.new(math.max(0.1, reach), diameter, diameter)
				part.CFrame = frame * CFrame.new(reach / 2, 0, 0)
				part.Transparency = 1 - (1 - opacity[i]) * math.clamp(thin * 1.4, 0, 1)
			end
			return now >= finish
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

local buildBallSmooth = single("VfxBallSmooth", Enum.PartType.Ball, Enum.Material.SmoothPlastic)
local buildBallNeon = single("VfxBallNeon", Enum.PartType.Ball, Enum.Material.Neon)

export type OrbOptions = {
	Center: () -> Vector3,
	Diameter: (now: number) -> number, -- studs; 0 hides it
	Color: Color3,
	Neon: boolean?, -- glowing (a rim) instead of matte (a void)
	Transparency: number?, -- at full strength (default 0)
	StartAt: number,
	EndAt: number,
}

-- A ball whose size is driven by `Diameter(now)` over [StartAt, EndAt]: the event sphere of a
-- black hole, the well charging on a staff tip, a rim shell around either.
function VfxPrimitives.Orb(pool: VfxPool.VfxPool, options: OrbOptions)
	local model = if options.Neon then pool:Acquire("BALL_NEON", buildBallNeon) else pool:Acquire("BALL_SMOOTH", buildBallSmooth)
	local part = model.PrimaryPart :: BasePart
	part.Color = options.Color
	part.Reflectance = 0
	part.Transparency = 1
	pool:Show(model)
	pool:Run({
		Update = function(now: number): boolean
			if now < options.StartAt then
				return false
			end
			local diameter = options.Diameter(now)
			part.Size = Vector3.one * math.max(0.05, diameter)
			part.CFrame = CFrame.new(options.Center())
			part.Transparency = if diameter <= 0.05 then 1 else options.Transparency or 0
			return now >= options.EndAt
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

local ACCRETION_SEGMENTS = 20
local buildAccretion = segments("VfxAccretion", ACCRETION_SEGMENTS)

export type AccretionOptions = {
	Center: Vector3,
	Radius: number,
	Tilt: number, -- radians the disc leans from flat
	Inner: Color3,
	Outer: Color3,
	StartAt: number,
	EndAt: number,
	Spin: number?, -- turns per second (default 1)
	Pulses: { number }?, -- server times it flashes brighter (damage ticks)
}

-- A tilted, spinning ring of light around a black hole: alternating segments in two colours, so
-- the spin reads. It opens over 0.15 s, flashes on each pulse and collapses over its last 0.12 s.
function VfxPrimitives.Accretion(pool: VfxPool.VfxPool, options: AccretionOptions)
	local model = pool:Acquire("ACCRETION", buildAccretion)
	local list = parts(model)
	for i, part in list do
		part.Color = if i % 2 == 0 then options.Outer else options.Inner
		part.Transparency = 1
	end
	pool:Show(model)
	local base = CFrame.new(options.Center) * CFrame.Angles(options.Tilt, 0, 0)
	local spin = (options.Spin or 1) * math.pi * 2
	local pulses = options.Pulses or {}
	pool:Run({
		Update = function(now: number): boolean
			if now < options.StartAt then
				return false
			end
			local open = VfxMath.Progress(options.StartAt, options.StartAt + 0.15, now)
			local close = 1 - VfxMath.Progress(options.EndAt - 0.12, options.EndAt, now)
			local radius = options.Radius * open * close
			local flash = 0
			for _, pulse in pulses do
				local since = now - pulse
				if since >= 0 and since < 0.12 then
					flash = math.max(flash, 1 - since / 0.12)
				end
			end
			local step = math.pi * 2 / #list
			local length = 2 * radius * math.sin(step / 2) * 1.1
			local turn = (now - options.StartAt) * spin
			for i, part in list do
				local angle = turn + step * (i - 0.5)
				part.Size = Vector3.new(math.max(0.1, length), 0.1, 0.35 + 0.25 * flash)
				part.CFrame = base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius)
				part.Transparency = if radius < 0.05 then 1 else 0.35 - 0.3 * flash
			end
			return now >= options.EndAt
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

local buildFlare = segments("VfxFlare", 2)

-- A cross-shaped lens glint at `position()`, facing the camera: snaps open, then shrinks away
-- over `duration` seconds from `at`.
function VfxPrimitives.Flare(pool: VfxPool.VfxPool, position: () -> Vector3, size: number, color: Color3, at: number, duration: number?)
	local model = pool:Acquire("FLARE", buildFlare)
	local list = parts(model)
	local length = duration or 0.18
	for _, part in list do
		part.Color = color
		part.Transparency = 1
	end
	pool:Show(model)
	pool:Run({
		Update = function(now: number): boolean
			if now < at then
				return false
			end
			local t = VfxMath.Progress(at, at + length, now)
			local camera = workspace.CurrentCamera
			local at3 = position()
			local facing = if camera then CFrame.lookAt(at3, camera.CFrame.Position) else CFrame.new(at3)
			local scale = size * (if t < 0.25 then t / 0.25 else 1 - (t - 0.25) / 0.75)
			for i, part in list do
				part.Size = Vector3.new(math.max(0.05, if i == 1 then scale else scale * 0.12), math.max(0.05, if i == 1 then scale * 0.12 else scale), 0.05)
				part.CFrame = facing * CFrame.Angles(0, 0, math.rad(20))
				part.Transparency = 0.05 + 0.5 * t
			end
			return t >= 1
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

-- Astrea's star kit ---------------------------------------------------------------------------

local RIBBON_SEGMENTS = 12
local buildRibbon = segments("VfxRibbon", RIBBON_SEGMENTS)

export type RibbonOptions = {
	From: Vector3,
	To: Vector3,
	StartAt: number, -- when the head of whatever leaves the ribbon is at From
	EndAt: number, -- and when it reaches To
	Width: number, -- studs across when fresh
	Inner: Color3, -- fresh colour
	Outer: Color3, -- colour it cools to
	Linger: number, -- seconds each stretch takes to spread and fade
	Seed: number?,
}

-- A ribbon of light left along a straight path: each stretch appears as the head passes it,
-- then drifts off the line, spreads to about three times its width and cools from Inner to
-- Outer as it fades over `Linger` seconds (a nebula wake).
function VfxPrimitives.Ribbon(pool: VfxPool.VfxPool, options: RibbonOptions)
	local delta = options.To - options.From
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local model = pool:Acquire("RIBBON", buildRibbon)
	local list = parts(model)
	for _, part in list do
		part.Transparency = 1
	end
	pool:Show(model)
	local direction = delta.Unit
	local side = direction:Cross(Vector3.yAxis)
	side = if side.Magnitude > 1e-3 then side.Unit else Vector3.xAxis
	local up = side:Cross(direction)
	local frame = CFrame.lookAt(options.From, options.To)
	local seed = options.Seed or 0
	local step = length / #list
	local linger = math.max(0.05, options.Linger)
	local finish = options.EndAt + linger
	pool:Run({
		Update = function(now: number): boolean
			if now < options.StartAt then
				return false
			end
			for i, part in list do
				local u = (i - 0.5) / #list
				local passedAt = options.StartAt + (options.EndAt - options.StartAt) * u
				if now < passedAt then
					part.Transparency = 1
					continue
				end
				local t = math.clamp((now - passedAt) / linger, 0, 1)
				local spread = 1 - (1 - t) * (1 - t)
				local width = options.Width * (0.45 + 2.2 * spread)
				-- Each stretch drifts its own way, so the ribbon breaks into wisps as it fades.
				local drift = side * (math.sin(seed + i * 2.17) * 0.9 * spread) + up * (math.cos(seed * 1.3 + i * 1.31) * 0.55 * spread)
				part.Color = options.Inner:Lerp(options.Outer, spread)
				part.Size = Vector3.new(width, math.max(0.05, width * 0.3), step * 1.15)
				part.CFrame = (frame + direction * (length * u) + drift) * CFrame.Angles(0, 0, seed + i * 0.7 + t * 1.5)
				part.Transparency = 0.3 + 0.7 * t
			end
			return now >= finish
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

-- One model holding a figure's stars, their halos and its lines.
local function buildConstellation(stars: number, lines: number): () -> Model
	return function(): Model
		local model = Instance.new("Model")
		model.Name = "VfxConstellation"
		for i = 1, stars * 2 + lines do
			local isLine = i > stars * 2
			local part = newPart(if isLine then "Line" elseif i > stars then "Halo" else "Star", if isLine then Enum.PartType.Block else Enum.PartType.Ball, Enum.Material.Neon)
			part.Transparency = 1
			part:SetAttribute("Index", i)
			part.Parent = model
			if i == 1 then
				model.PrimaryPart = part
			end
		end
		return model
	end
end

export type ConstellationOptions = {
	Stars: { Vector3 }, -- world positions
	Lines: { { number } }, -- pairs of star indices, in drawing order
	LineStarts: { number }, -- when each line starts drawing (VfxMath.FigureTrace)
	LineSeconds: number, -- how long a line takes to draw
	StarAt: { number }, -- when each star lights
	DropAt: { number }, -- when each star leaves the sky: it flares, then is gone
	EndAt: number,
	StarSize: number, -- studs
	Palette: any,
}

-- A constellation that draws itself: each star pops alight as the pen reaches it, the lines
-- grow from star to star, and the finished figure twinkles until its stars leave. A star
-- flares just before its DropAt and vanishes on it; the lines it held fade with it.
function VfxPrimitives.Constellation(pool: VfxPool.VfxPool, options: ConstellationOptions)
	local stars, lines = options.Stars, options.Lines
	local count = #stars
	local model = pool:Acquire(`CONSTELLATION@{count}_{#lines}`, buildConstellation(count, #lines))
	local list = parts(model)
	local palette = options.Palette
	for i, part in list do
		part.Color = if i <= count then palette.Core elseif i <= count * 2 then palette.Secondary else palette.Primary
		part.Transparency = 1
		part.Size = Vector3.one * 0.1
		part.CFrame = CFrame.new(stars[if i <= count then i elseif i <= count * 2 then i - count else lines[i - count * 2][1]])
	end
	pool:Show(model)
	local size = options.StarSize
	local startAt = math.huge
	for _, at in options.StarAt do
		startAt = math.min(startAt, at)
	end
	pool:Run({
		Update = function(now: number): boolean
			if now < startAt then
				return false
			end
			for i = 1, count do
				local star, halo = list[i], list[count + i]
				local lit, drop = options.StarAt[i], options.DropAt[i]
				if now < lit or now >= drop then
					star.Transparency = 1
					halo.Transparency = 1
					continue
				end
				-- Pops in oversized and settles, twinkles, then swells as it is about to fall.
				local pop = math.clamp((now - lit) / 0.16, 0, 1)
				local flare = math.clamp((now - (drop - 0.1)) / 0.1, 0, 1)
				local twinkle = 1 + 0.14 * math.sin(now * 11 + i * 2.1)
				local scale = (1 + 1.1 * (1 - pop)) * twinkle * (1 + 1.3 * flare)
				star.Size = Vector3.one * size * scale
				star.Transparency = 0
				halo.Size = Vector3.one * size * 2.6 * scale
				halo.Transparency = 0.78 - 0.3 * math.max(1 - pop, flare)
			end
			for k, line in lines do
				local part = list[count * 2 + k]
				local from = options.LineStarts[k]
				local gone = math.min(options.DropAt[line[1]], options.DropAt[line[2]])
				local fade = math.clamp((now - (gone - 0.06)) / 0.2, 0, 1)
				if now < from or fade >= 1 then
					part.Transparency = 1
					continue
				end
				local a, b = stars[line[1]], stars[line[2]]
				local drawn = math.clamp((now - from) / options.LineSeconds, 0, 1)
				local tip = a:Lerp(b, drawn)
				local span = (tip - a).Magnitude
				if span < 0.05 then
					part.Transparency = 1
					continue
				end
				-- Bright while it is being drawn, then it settles to a thin thread.
				local fresh = 1 - math.clamp((now - from - options.LineSeconds) / 0.25, 0, 1)
				local thickness = size * (0.14 + 0.12 * fresh)
				part.Size = Vector3.new(thickness, thickness, span)
				part.CFrame = CFrame.lookAt(a:Lerp(tip, 0.5), tip)
				part.Transparency = 1 - (0.6 + 0.3 * fresh) * (1 - fade)
			end
			return now >= options.EndAt
		end,
		Cleanup = function()
			pool:Release(model)
		end,
	})
end

VfxPrimitives.FLAT = FLAT

return table.freeze(VfxPrimitives)
