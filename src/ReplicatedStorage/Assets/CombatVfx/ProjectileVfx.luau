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

ProjectileVfx.Builders = table.freeze({
	ARROW = buildArrow,
	ASTRAL = buildArrow,
	BOLT = buildBolt,
	ORB = buildOrb,
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
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Head" then
				d.Color = if astral or kind == "BOLT" then palette.Core else palette.Primary
			elseif d.Name == "Core" then
				d.Color = if kind == "ORB" then palette.Core else palette.Primary
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
			d.Color = ColorSequence.new(palette.Primary, palette.Secondary)
			d.Lifetime = trailSeconds or 0.15
		end
	end
end

return table.freeze(ProjectileVfx)
