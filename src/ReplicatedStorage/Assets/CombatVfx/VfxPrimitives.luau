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

VfxPrimitives.FLAT = FLAT

return table.freeze(VfxPrimitives)
