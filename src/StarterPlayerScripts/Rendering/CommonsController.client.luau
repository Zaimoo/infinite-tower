--!strict
-- StarterPlayerScripts/Rendering/CommonsController.client.luau
-- Client-only ambient motion in the hub, so the server never animates scenery:
--   "CommonsSpinner" parts (the Wayfinder Crystal) spin and bob.
--   "CausewayPulse" parts (Pilgrim's Causeway runes, eyes and souls) throb, in a wave that rolls toward the tower.
--   "WallTorchFlicker" PointLights on the Gothic Fortress walls oscillate Brightness between 1.95 and 2.45.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local HubPresence = require(script.Parent:WaitForChild("HubPresence"))

local SPIN_SPEED = math.rad(40) -- radians per second
local BOB_HEIGHT = 1.2
local BOB_PERIOD = 4

local PULSE_SPEED = 2.2 -- radians per second
local PULSE_DEPTH = 0.45 -- extra transparency at the dim point of the pulse
local PULSE_WAVELENGTH = 0.06 -- radians of phase per stud along Z, so the glow travels toward the tower

type Spinner = { Part: BasePart, Base: CFrame }
type Pulser = { Part: BasePart, Base: number, Phase: number }
type TorchLight = { Light: PointLight, Seed: number }
local spinners: { [BasePart]: Spinner } = {}
local pulsers: { [BasePart]: Pulser } = {}
local torchLights: { [PointLight]: TorchLight } = {}
local torchSeedCounter = 0

local function addSpinner(inst: Instance)
	if inst:IsA("BasePart") and not spinners[inst] then
		spinners[inst] = { Part = inst, Base = inst.CFrame }
	end
end

local function addPulser(inst: Instance)
	if inst:IsA("BasePart") and not pulsers[inst] then
		local base = inst:GetAttribute("PulseBase")
		local phase = inst:GetAttribute("PulsePhase")
		pulsers[inst] = {
			Part = inst,
			Base = if type(base) == "number" then base else inst.Transparency,
			-- Crest moves toward +Z (the tower sits south of the park)
			Phase = (if type(phase) == "number" then phase else 0) - inst.Position.Z * PULSE_WAVELENGTH,
		}
	end
end

local function addTorchLight(inst: Instance)
	if inst:IsA("PointLight") and not torchLights[inst] then
		torchSeedCounter += 1
		torchLights[inst] = { Light = inst, Seed = torchSeedCounter * 1.732 }
	end
end

local function track(tag: string, add: (Instance) -> (), list: { [any]: any })
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst: Instance)
		list[inst] = nil
	end)
end

track("CommonsSpinner", addSpinner, spinners)
track("CausewayPulse", addPulser, pulsers)
track("WallTorchFlicker", addTorchLight, torchLights)

local function stepCommons()
	if HubPresence.InTower() then
		return -- the Commons is not visible from a tower floor
	end
	local t = os.clock()
	if next(spinners) ~= nil then
		local bob = math.sin(t * math.pi * 2 / BOB_PERIOD) * BOB_HEIGHT
		for part, s in spinners do
			if part.Parent then
				local base = s.Base
				part.CFrame = CFrame.new(base.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * SPIN_SPEED, 0) * base.Rotation
			end
		end
	end
	for part, p in pulsers do
		if part.Parent then
			local dim = 0.5 + 0.5 * math.sin(t * PULSE_SPEED + p.Phase)
			part.Transparency = math.min(0.95, p.Base + dim * PULSE_DEPTH)
		end
	end
	for light, tl in torchLights do
		if light.Parent then
			local n = math.noise(t * 3.8, tl.Seed, 0)
			light.Brightness = 2.2 + math.clamp(n * 0.35, -0.25, 0.25)
		end
	end
end
RunService.RenderStepped:Connect(function()
	debug.profilebegin("Commons")
	stepCommons()
	debug.profileend()
end)
