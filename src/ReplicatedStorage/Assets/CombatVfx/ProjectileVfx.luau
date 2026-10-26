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
-- ASTRAL draws the shaft in light instead of wood. Sized to read at combat camera distance
-- (roughly 1.5x a bow's own arrow), so the silhouette, not the glow, carries the shape.
local SHAFT_LENGTH = 3.0
local HEAD_Z = -(SHAFT_LENGTH / 2 + 0.2)
local TAIL_Z = SHAFT_LENGTH / 2 - 0.35

local function buildArrow(kind: string, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Projectile_" .. kind

	local astral = kind == "ASTRAL"
	local shaft = VfxPrimitives.NewPart("Shaft", Enum.PartType.Block, if astral then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	shaft.Size = Vector3.new(0.14, 0.14, SHAFT_LENGTH) * scale
	shaft.Color = SHAFT_WOOD
	add(model, shaft, CFrame.identity)
	model.PrimaryPart = shaft

	-- A square block turned 45 degrees about the flight axis reads as a diamond tip.
	local head = VfxPrimitives.NewPart("Head", Enum.PartType.Block, Enum.Material.Neon)
	head.Size = Vector3.new(0.3, 0.3, 0.6) * scale
	add(model, head, CFrame.new(0, 0, HEAD_Z * scale) * CFrame.Angles(0, 0, math.rad(45)))

	local glow = VfxPrimitives.NewPart("Glow", Enum.PartType.Ball, Enum.Material.Neon)
	glow.Size = Vector3.one * 0.3 * scale
	glow.Transparency = 0.7
	add(model, glow, CFrame.new(0, 0, (HEAD_Z - 0.15) * scale))

	for i = 1, 2 do
		local fletch = VfxPrimitives.NewPart("Fletch" .. i, Enum.PartType.Block, Enum.Material.Neon)
		fletch.Size = Vector3.new(0.04, 0.5, 0.75) * scale
		fletch.Color = FLETCH_WHITE
		add(model, fletch, CFrame.new(0, 0, TAIL_Z * scale) * CFrame.Angles(0, 0, if i == 1 then 0 else math.pi / 2))
	end

	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.35, TAIL_Z) * scale
	top.Parent = shaft
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -0.35, TAIL_Z) * scale
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

ProjectileVfx.Builders = table.freeze({
	ARROW = buildArrow,
	ASTRAL = buildArrow,
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
				d.Color = if astral then palette.Core else palette.Primary
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
