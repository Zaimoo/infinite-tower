--!strict
-- ReplicatedStorage/Assets/CombatVfx/ProjectileVfx.luau
-- Projectile bodies for combat VFX (docs/projectile-skill-vfx-plan.md, section 6), built in code
-- and pooled through VfxPool. Every body points along -Z of its pivot (CFrame.lookAt forward) and
-- carries one Trail. Replaces the unused arrow code that lived in CombatFeedback.
--
--   local key, build = ProjectileVfx.Key("ARROW", 1.25)       -- VfxPrimitives.Flight Kind/Build
--   ProjectileVfx.Paint(model, "ARROW", palette, 0.15)      -- Flight's Prepare, on every reuse

local VfxPrimitives = require(script.Parent:WaitForChild("VfxPrimitives"))

local ProjectileVfx = {}

local SHAFT_WOOD = Color3.fromRGB(196, 150, 100)
local FLETCH_WHITE = Color3.fromRGB(240, 244, 240)

local function add(model: Model, part: BasePart, frame: CFrame)
	part.CFrame = frame
	part.Parent = model
end

-- Arrow: shaft, diamond head, a faint glow at the tip, cross fletching and a trail off the tail.
-- ASTRAL draws the shaft in light instead of wood. Deliberately oversized (about twice a bow's
-- own arrow) so it reads at the combat camera's distance; every dimension comes from these.
local SHAFT_LENGTH = 4.5
local SHAFT_WIDTH = 0.28
local HEAD_WIDTH = 0.6
local HEAD_LENGTH = 1.0
local FLETCH_SIZE = Vector3.new(0.08, 0.9, 1.3)
local TRAIL_HALF_WIDTH = 0.6
local HEAD_Z = -(SHAFT_LENGTH / 2 + HEAD_LENGTH * 0.35)
local TAIL_Z = SHAFT_LENGTH / 2 - FLETCH_SIZE.Z / 2

local function buildArrow(kind: string, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Projectile_" .. kind

	local astral = kind == "ASTRAL"
	local shaft = VfxPrimitives.NewPart("Shaft", Enum.PartType.Block, if astral then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	shaft.Size = Vector3.new(SHAFT_WIDTH, SHAFT_WIDTH, SHAFT_LENGTH) * scale
	shaft.Color = SHAFT_WOOD
	add(model, shaft, CFrame.identity)
	model.PrimaryPart = shaft

	-- A square block turned 45 degrees about the flight axis reads as a diamond tip.
	local head = VfxPrimitives.NewPart("Head", Enum.PartType.Block, Enum.Material.Neon)
	head.Size = Vector3.new(HEAD_WIDTH, HEAD_WIDTH, HEAD_LENGTH) * scale
	add(model, head, CFrame.new(0, 0, HEAD_Z * scale) * CFrame.Angles(0, 0, math.rad(45)))

	local glow = VfxPrimitives.NewPart("Glow", Enum.PartType.Ball, Enum.Material.Neon)
	glow.Size = Vector3.one * HEAD_WIDTH * scale
	glow.Transparency = 0.7
	add(model, glow, CFrame.new(0, 0, (HEAD_Z - HEAD_LENGTH * 0.25) * scale))

	for i = 1, 2 do
		local fletch = VfxPrimitives.NewPart("Fletch" .. i, Enum.PartType.Block, Enum.Material.Neon)
		fletch.Size = FLETCH_SIZE * scale
		fletch.Color = FLETCH_WHITE
		add(model, fletch, CFrame.new(0, 0, TAIL_Z * scale) * CFrame.Angles(0, 0, if i == 1 then 0 else math.pi / 2))
	end

	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, TRAIL_HALF_WIDTH, TAIL_Z) * scale
	top.Parent = shaft
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -TRAIL_HALF_WIDTH, TAIL_Z) * scale
	bottom.Parent = shaft
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.MinLength = 0.05
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.Enabled = false
	trail.Parent = shaft
	return model
end

local function addTrail(primary: BasePart, halfWidth: number, z: number)
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, halfWidth, z)
	top.Parent = primary
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -halfWidth, z)
	bottom.Parent = primary
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.MinLength = 0.05
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.Enabled = false
	trail.Parent = primary
end

-- Bolt: a spear of light with a bright diamond tip (healers' and some casters' projectiles).
local function buildBolt(kind: string, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Projectile_" .. kind
	local core = VfxPrimitives.NewPart("Core", Enum.PartType.Block, Enum.Material.Neon)
	core.Size = Vector3.new(0.3, 0.3, 2.6) * scale
	add(model, core, CFrame.identity)
	model.PrimaryPart = core
	local head = VfxPrimitives.NewPart("Head", Enum.PartType.Block, Enum.Material.Neon)
	head.Size = Vector3.new(0.55, 0.55, 0.9) * scale
	add(model, head, CFrame.new(0, 0, -1.5 * scale) * CFrame.Angles(0, 0, math.rad(45)))
	local glow = VfxPrimitives.NewPart("Glow", Enum.PartType.Ball, Enum.Material.Neon)
	glow.Size = Vector3.one * 1.1 * scale
	glow.Transparency = 0.65
	add(model, glow, CFrame.new(0, 0, -1.4 * scale))
	addTrail(core, 0.5 * scale, 1.2 * scale)
	return model
end

-- Orb: a bright core inside a shimmering shell (casters' projectiles).
local function buildOrb(kind: string, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Projectile_" .. kind
	local core = VfxPrimitives.NewPart("Core", Enum.PartType.Ball, Enum.Material.Neon)
	core.Size = Vector3.one * 0.9 * scale
	add(model, core, CFrame.identity)
	model.PrimaryPart = core
	local glow = VfxPrimitives.NewPart("Glow", Enum.PartType.Ball, Enum.Material.Neon)
	glow.Size = Vector3.one * 1.4 * scale
	glow.Transparency = 0.6
	add(model, glow, CFrame.identity)
	local shell = VfxPrimitives.NewPart("Shell", Enum.PartType.Ball, Enum.Material.ForceField)
	shell.Size = Vector3.one * 2.0 * scale
	add(model, shell, CFrame.identity)
	addTrail(core, 0.65 * scale, 0.3 * scale)
	return model
end

-- Void: a sphere of absence. A dark matte core inside a thin violet Neon rim, with a bright halo
-- ring around its waist (perpendicular to the flight) and a trail that fades from violet to
-- black. It reads as a hole by its rim, so the rim and halo stay even at small scales.
local function buildVoid(kind: string, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Projectile_" .. kind
	local void = VfxPrimitives.NewPart("Void", Enum.PartType.Ball, Enum.Material.SmoothPlastic)
	void.Size = Vector3.one * 0.95 * scale
	void.Reflectance = 0
	add(model, void, CFrame.identity)
	model.PrimaryPart = void
	local rim = VfxPrimitives.NewPart("Rim", Enum.PartType.Ball, Enum.Material.Neon)
	rim.Size = Vector3.one * 1.25 * scale
	rim.Transparency = 0.55
	add(model, rim, CFrame.identity)
	-- Cylinders lie along X; turned so the disc's face is across the flight (-Z).
	local halo = VfxPrimitives.NewPart("Halo", Enum.PartType.Cylinder, Enum.Material.Neon)
	halo.Size = Vector3.new(0.06, 1.9 * scale, 1.9 * scale)
	halo.Transparency = 0.45
	add(model, halo, CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.rad(25), 0, 0))
	addTrail(void, 0.55 * scale, 0.3 * scale)
	return model
end

-- Star-bolt (Astrea): a long needle of white light in a violet sheath, with a diamond tip and a
-- four-point star glint across it. It sheds sparks from the tip and draws two trails: a tight
-- bright streak, and a wide soft one that outlives it and spreads as it fades (the nebula).
local function buildStarBolt(kind: string, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Projectile_" .. kind
	local core = VfxPrimitives.NewPart("Core", Enum.PartType.Block, Enum.Material.Neon)
	core.Size = Vector3.new(0.2, 0.2, 5) * scale
	add(model, core, CFrame.identity)
	model.PrimaryPart = core
	local sheath = VfxPrimitives.NewPart("Sheath", Enum.PartType.Block, Enum.Material.Neon)
	sheath.Size = Vector3.new(0.48, 0.48, 3.6) * scale
	sheath.Transparency = 0.55
	add(model, sheath, CFrame.new(0, 0, 0.4 * scale) * CFrame.Angles(0, 0, math.rad(45)))
	local head = VfxPrimitives.NewPart("Head", Enum.PartType.Block, Enum.Material.Neon)
	head.Size = Vector3.new(0.62, 0.62, 1.4) * scale
	add(model, head, CFrame.new(0, 0, -2.7 * scale) * CFrame.Angles(0, 0, math.rad(45)))
	local glow = VfxPrimitives.NewPart("Glow", Enum.PartType.Ball, Enum.Material.Neon)
	glow.Size = Vector3.one * 1.3 * scale
	glow.Transparency = 0.6
	add(model, glow, CFrame.new(0, 0, -2.5 * scale))
	-- The glint: two thin bars crossed over the tip, across the flight.
	for i = 1, 2 do
		local star = VfxPrimitives.NewPart("Star" .. i, Enum.PartType.Block, Enum.Material.Neon)
		star.Size = Vector3.new(2.3, 0.1, 0.1) * scale
		star.Transparency = 0.15
		add(model, star, CFrame.new(0, 0, -2.4 * scale) * CFrame.Angles(0, 0, if i == 1 then 0 else math.pi / 2))
	end

	addTrail(core, 0.3 * scale, 2.4 * scale)
	local top = Instance.new("Attachment")
	top.Name = "NebulaTop"
	top.Position = Vector3.new(0, 1.05 * scale, 2.2 * scale)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Name = "NebulaBottom"
	bottom.Position = Vector3.new(0, -1.05 * scale, 2.2 * scale)
	bottom.Parent = core
	local nebula = Instance.new("Trail")
	nebula.Name = "Nebula"
	nebula.Attachment0 = top
	nebula.Attachment1 = bottom
	nebula.FaceCamera = true
	nebula.LightEmission = 0.8
	nebula.LightInfluence = 0
	nebula.MinLength = 0.05
	nebula.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 1) })
	nebula.WidthScale = NumberSequence.new(0.7, 1.7)
	nebula.Enabled = false
	nebula.Parent = core

	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0, -2.4 * scale)
	tip.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = 70
	sparks.Lifetime = NumberRange.new(0.22, 0.42)
	sparks.Speed = NumberRange.new(1.5, 5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-180, 180)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55 * scale), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new(0.1, 1)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Drag = 3
	sparks.Enabled = false
	sparks.Parent = tip
	return model
end

-- Shard (Seraphine's halo shards): a long glass diamond with a bright core, pointed along the
-- flight, a soft glow at the tip and a pale trail.
local function buildShard(kind: string, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Projectile_" .. kind
	local core = VfxPrimitives.NewPart("Core", Enum.PartType.Block, Enum.Material.Neon)
	core.Size = Vector3.new(0.22, 0.22, 2.2) * scale
	add(model, core, CFrame.Angles(0, 0, math.rad(45)))
	model.PrimaryPart = core
	local shell = VfxPrimitives.NewPart("Shell", Enum.PartType.Block, Enum.Material.Glass)
	shell.Size = Vector3.new(0.5, 0.5, 1.8) * scale
	shell.Transparency = 0.35
	add(model, shell, CFrame.new(0, 0, 0.1 * scale) * CFrame.Angles(0, 0, math.rad(45)))
	local glow = VfxPrimitives.NewPart("Glow", Enum.PartType.Ball, Enum.Material.Neon)
	glow.Size = Vector3.one * 0.9 * scale
	glow.Transparency = 0.6
	add(model, glow, CFrame.new(0, 0, -0.9 * scale))
	addTrail(core, 0.4 * scale, 0.4 * scale)
	return model
end

-- Prism (Seraphine's Refraction): a glass diamond around a bright core, ringed by a thin halo
-- across the flight, with a wide trail.
local function buildPrism(kind: string, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Projectile_" .. kind
	local core = VfxPrimitives.NewPart("Core", Enum.PartType.Block, Enum.Material.Neon)
	core.Size = Vector3.one * 0.6 * scale
	add(model, core, CFrame.Angles(math.rad(45), 0, math.rad(45)))
	model.PrimaryPart = core
	local shell = VfxPrimitives.NewPart("Shell", Enum.PartType.Block, Enum.Material.Glass)
	shell.Size = Vector3.new(1.1, 1.1, 1.6) * scale
	shell.Transparency = 0.3
	add(model, shell, CFrame.Angles(0, 0, math.rad(45)))
	local glow = VfxPrimitives.NewPart("Glow", Enum.PartType.Ball, Enum.Material.Neon)
	glow.Size = Vector3.one * 1.7 * scale
	glow.Transparency = 0.65
	add(model, glow, CFrame.identity)
	-- Cylinders lie along X; turned so the ring's face is across the flight (-Z).
	local halo = VfxPrimitives.NewPart("Halo", Enum.PartType.Cylinder, Enum.Material.Neon)
	halo.Size = Vector3.new(0.06, 2.2 * scale, 2.2 * scale)
	halo.Transparency = 0.5
	add(model, halo, CFrame.Angles(0, math.pi / 2, 0))
	addTrail(core, 0.75 * scale, 0.6 * scale)
	return model
end

ProjectileVfx.Builders = table.freeze({
	ARROW = buildArrow,
	ASTRAL = buildArrow,
	BOLT = buildBolt,
	ORB = buildOrb,
	VOID = buildVoid,
	STARBOLT = buildStarBolt,
	SHARD = buildShard,
	PRISM = buildPrism,
} :: { [string]: (string, number) -> Model })

function ProjectileVfx.Has(kind: string): boolean
	return ProjectileVfx.Builders[kind] ~= nil
end

-- Pool key and builder for a projectile kind at a scale (scales are rounded so the pool stays small).
function ProjectileVfx.Key(kind: string, scale: number?): (string, () -> Model)
	local rounded = math.round((scale or 1) * 20) / 20
	local builder = ProjectileVfx.Builders[kind]
	assert(builder, `ProjectileVfx: unknown kind {kind}`)
	return `{kind}@{rounded}`, function(): Model
		return builder(kind, rounded)
	end
end

-- Colours a pooled projectile for a hero's palette and sets its trail length.
function ProjectileVfx.Paint(model: Model, kind: string, palette: any, trailSeconds: number?)
	local astral = kind == "ASTRAL"
	local starBolt = kind == "STARBOLT"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if starBolt then
				d.Color = if d.Name == "Core" or d.Name == "Head" then palette.Core
					elseif d.Name == "Star1" or d.Name == "Star2" then palette.Secondary
					else palette.Primary
			elseif d.Name == "Void" then
				d.Color = palette.Secondary
			elseif d.Name == "Rim" then
				d.Color = palette.Primary
			elseif d.Name == "Halo" then
				d.Color = palette.Core
			elseif d.Name == "Head" then
				d.Color = if astral or kind == "BOLT" then palette.Core else palette.Primary
			elseif d.Name == "Core" then
				d.Color = if kind == "ORB" or kind == "SHARD" or kind == "PRISM" then palette.Core else palette.Primary
			elseif d.Name == "Shell" then
				d.Color = palette.Secondary
			elseif d.Name == "Glow" then
				d.Color = if astral then palette.Secondary else palette.Primary
			elseif astral and d.Name == "Shaft" then
				d.Color = palette.Core
			elseif astral then
				d.Color = palette.Primary
			end
		elseif d:IsA("Trail") then
			if d.Name == "Nebula" then
				-- The nebula ribbon: deeper in colour and much longer-lived than the streak.
				d.Color = ColorSequence.new(palette.Primary, palette.Accent or palette.Primary)
				d.Lifetime = (trailSeconds or 0.15) * 2.5
			else
				d.Color = if starBolt then ColorSequence.new(palette.Core, palette.Primary) else ColorSequence.new(palette.Primary, palette.Secondary)
				d.Lifetime = trailSeconds or 0.15
			end
		elseif d:IsA("ParticleEmitter") then
			d.Color = ColorSequence.new(palette.Secondary, palette.Primary)
		end
	end
end

return table.freeze(ProjectileVfx)
