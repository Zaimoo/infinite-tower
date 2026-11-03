--!strict
-- StarterPlayerScripts/Rendering/RelicVisualController.client.luau
-- Draws every relic in Workspace.PhysicalRelics. The server only replicates an invisible root (hitbox,
-- billboard, RelicTier / RelicCarried attributes); this builds the tier's model from RelicModelBuilder
-- and adds the outline glow, a vertical loot beam, a pulsing ground ring, idle bob and spin, and a
-- spawn burst. While a relic is carried overhead the beam, ring and bob are hidden.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RelicModelBuilder = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("RelicModelBuilder"))
local RelicConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("RelicConfig"))

local PhysicalRelics = Workspace:WaitForChild("PhysicalRelics")

local FX_CULL_DISTANCE = 300 -- beyond this the beam and particles switch off
local BOB_HEIGHT = 0.4
local BOB_SPEED = 2.2
local SPIN_SPEED = 0.9 -- radians per second
local RING_PERIOD = 1.6
local BURST_SECONDS = 0.4

type Visual = {
	Root: BasePart,
	Model: Model,
	Ring: Part,
	Beam: Beam,
	Light: PointLight?,
	Motes: ParticleEmitter?,
	Fx: RelicModelBuilder.RelicFx,
	Phase: number,
	SpawnedAt: number,
}

local visuals: { [BasePart]: Visual } = {}

local function attach(root: Instance)
	if not root:IsA("BasePart") or visuals[root] then return end
	local tierId = root:GetAttribute("RelicTier")
	if type(tierId) ~= "string" then return end
	local spec = (RelicConfig :: any)[tierId] or RelicConfig.MANA_GEODE
	local fx = RelicModelBuilder.Fx[tierId] or RelicModelBuilder.Fx.MANA_GEODE

	local model = RelicModelBuilder.Build(tierId)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = spec.Color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 1
	highlight.Adornee = model
	highlight.Parent = model

	-- Flat Neon disc on the ground; cylinders run along X, so local X points up once rolled 90 degrees.
	local ring = Instance.new("Part")
	ring.Name = "GroundRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.08, 3, 3)
	ring.Color = spec.Color
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanTouch = false
	ring.CanQuery = false
	ring.CastShadow = false

	local base = Instance.new("Attachment")
	base.Parent = ring
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(fx.BeamHeight, 0, 0)
	top.Parent = ring
	local beam = Instance.new("Beam")
	beam.Attachment0 = base
	beam.Attachment1 = top
	beam.Color = ColorSequence.new(spec.Color)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 1.4
	beam.Width1 = 0.25
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	beam.Segments = 1
	beam.Parent = ring

	-- Parented under the root so the visual is cleaned up with it. The ring stays outside the model so the
	-- outline Highlight and the bob/spin only apply to the relic itself.
	model.Parent = root
	ring.Parent = root
	local anchor = model.PrimaryPart
	local burst = anchor and anchor:FindFirstChild("Burst") :: ParticleEmitter?
	if burst then burst:Emit(30) end

	visuals[root] = {
		Root = root,
		Model = model,
		Ring = ring,
		Beam = beam,
		Light = anchor and anchor:FindFirstChild("Glow") :: PointLight?,
		Motes = anchor and anchor:FindFirstChild("Motes") :: ParticleEmitter?,
		Fx = fx,
		Phase = math.random() * math.pi * 2,
		SpawnedAt = os.clock(),
	}
end

local function detach(root: Instance)
	local visual = visuals[root :: BasePart]
	if not visual then return end
	visuals[root :: BasePart] = nil
	visual.Model:Destroy()
	visual.Ring:Destroy()
end

PhysicalRelics.ChildAdded:Connect(attach)
PhysicalRelics.ChildRemoved:Connect(detach)
for _, child in PhysicalRelics:GetChildren() do
	attach(child)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	for root, visual in visuals do
		if not root.Parent then
			detach(root)
			continue
		end
		local carried = root:GetAttribute("RelicCarried") == true
		local t = now + visual.Phase
		local pos = root.Position
		local bob = if carried then 0 else math.sin(t * BOB_SPEED) * BOB_HEIGHT
		local spin = t * (if carried then SPIN_SPEED * 0.5 else SPIN_SPEED)
		visual.Model:PivotTo(CFrame.new(pos + Vector3.new(0, bob, 0)) * CFrame.Angles(0, spin, 0))

		local near = (pos - eye).Magnitude <= FX_CULL_DISTANCE
		local grounded = not carried
		visual.Beam.Enabled = grounded and near
		if visual.Motes then visual.Motes.Enabled = near end

		-- Ground ring: grows and fades out every RING_PERIOD seconds.
		local cycle = (t % RING_PERIOD) / RING_PERIOD
		local groundY = pos.Y - root.Size.Y / 2 + 0.05
		local diameter = 2.5 + cycle * 4.5
		visual.Ring.Size = Vector3.new(0.08, diameter, diameter)
		visual.Ring.CFrame = CFrame.new(pos.X, groundY, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
		visual.Ring.Transparency = if grounded then 0.35 + cycle * 0.65 else 1

		local light = visual.Light
		if light then
			local brightness = visual.Fx.LightBrightness
			if visual.Fx.Beat then
				-- Double-thump heart beat, about 70 bpm.
				local beat = (now % 0.86) / 0.86
				brightness *= 1 + 0.8 * math.max(math.exp(-((beat - 0.05) / 0.05) ^ 2), 0.6 * math.exp(-((beat - 0.25) / 0.05) ^ 2))
			end
			local sinceSpawn = now - visual.SpawnedAt
			if sinceSpawn < BURST_SECONDS then
				brightness *= 1 + 3 * (1 - sinceSpawn / BURST_SECONDS) -- spawn flash
			end
			light.Brightness = brightness
		end
	end
end)
