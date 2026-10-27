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
			pool:MoveModel(model, CFrame.lookAt(position, ahead))
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
-- `spokes` defaults to 6; pass 0 to skip them at low quality.
function VfxPrimitives.Sigil(pool: VfxPool.VfxPool, center: Vector3, radius: number, palette: any, startAt: number, endAt: number, spokeCount: number?)
	local ground = CFrame.new(center + Vector3.new(0, 0.15, 0))
	VfxPrimitives.Disc(pool, { CFrame = ground * FLAT, Radius = radius, Color = palette.Secondary, StartAt = startAt, EndAt = endAt, Grow = 0.2, Transparency = 0.45 })
	VfxPrimitives.Disc(pool, { CFrame = (ground + Vector3.new(0, 0.05, 0)) * FLAT, Radius = radius * 0.55, Color = palette.Primary, StartAt = startAt, EndAt = endAt, Grow = 0.1, Transparency = 0.3 })

	local spokes = spokeCount or 6
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
				pool:Move(part, (ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -length / 2))
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
				pool:Move(part, base * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius))
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
				pool:Move(part, frame * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -radius))
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
			pool:Move(part, CFrame.new(center()))
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
			pool:Move(part, CFrame.new(base + Vector3.new(0, height - length / 2, 0)) * UPRIGHT)
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
			pool:Move(part, CFrame.new(base) * tilt * CFrame.new(0, -height / 2 + height * up * 0.95, 0))
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
				pool:Move(part, CFrame.new(start + Vector3.new(0, 3 * t, 0)))
				part.Transparency = 0.1 + 0.9 * t
				return t >= 1
			end,
			Cleanup = function()
				pool:Release(model)
			end,
		})
	end
end

-- Builds the common assemblies ahead of the first fight (VfxPool.Prewarm), so the first big
-- skill does not hitch while it creates parts.
function VfxPrimitives.Prewarm(pool: VfxPool.VfxPool)
	pool:Prewarm("BURST", buildBurst, 16)
	pool:Prewarm("DISC", buildDisc, 6)
	pool:Prewarm("SPOKE", buildSpoke, 6)
	pool:Prewarm("RING", buildRing, 4)
	pool:Prewarm("ARC", buildArc, 8)
	pool:Prewarm("SPIKE", buildSpike, 8)
	pool:Prewarm("MOTE", buildMote, 12)
end

VfxPrimitives.FLAT = FLAT

return table.freeze(VfxPrimitives)
