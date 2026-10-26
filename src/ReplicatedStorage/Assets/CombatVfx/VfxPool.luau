--!strict
-- ReplicatedStorage/Assets/CombatVfx/VfxPool.luau
-- Client-side part pool and effect scheduler for combat VFX (docs/projectile-skill-vfx-plan.md,
-- section 6). Effects are stepped once per frame from EntityRenderer with server time; nothing
-- here uses TweenService or Debris, and released assemblies are parked and reused.
--
-- A parked assembly has no parent. (Moving it far below the map instead gets its parts destroyed
-- by Workspace.FallenPartsDestroyHeight.) An effect that errors is cleaned up on its own and
-- never takes the other effects down with it.
--
--   local pool = VfxPool.new(folder)
--   local model = pool:Acquire("ARROW@1", buildArrow) -- pooled Model of anchored parts
--   pool:Run({ Update = function(now) ... return done end, Cleanup = function() ... end })
--   pool:Step(Workspace:GetServerTimeNow())          -- every frame

local Workspace = game:GetService("Workspace")

local VfxPool = {}
VfxPool.__index = VfxPool

VfxPool.MAX_EFFECTS = 160 -- live effects (flights, bursts, rings); new ones are refused above it
VfxPool.MAX_FREE_PER_KIND = 32 -- parked assemblies kept per kind
VfxPool.CULL_DISTANCE = 180 -- effects with every point farther than this from the camera are skipped

export type Effect = {
	Update: (now: number) -> boolean, -- returns true when finished
	Cleanup: (() -> ())?,
}

export type VfxPool = typeof(setmetatable({} :: {
	Folder: Folder,
	Free: { [string]: { Model } },
	Effects: { Effect },
}, VfxPool))

function VfxPool.new(parent: Instance): VfxPool
	local folder = Instance.new("Folder")
	folder.Name = "ClientCombatVfx"
	folder.Parent = parent
	return setmetatable({ Folder = folder, Free = {}, Effects = {} }, VfxPool)
end

local function setTrails(model: Model, enabled: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("Trail") then
			d.Enabled = enabled
			if enabled then
				d:Clear()
			end
		end
	end
end

-- A parked assembly still has its parts (nothing destroyed them while it waited).
local function intact(model: Model): boolean
	local primary = model.PrimaryPart
	return primary ~= nil and primary:IsDescendantOf(model)
end

-- A pooled assembly of `kind`, built on first use. It stays unparented (invisible) until Show.
function VfxPool.Acquire(self: VfxPool, kind: string, build: () -> Model): Model
	local free = self.Free[kind]
	while free and #free > 0 do
		local model = table.remove(free) :: Model
		if intact(model) then
			return model
		end
		model:Destroy()
	end
	local model = build()
	model:SetAttribute("VfxKind", kind)
	setTrails(model, false)
	return model
end

-- Puts an acquired assembly in the world (position it first) and starts its trails.
function VfxPool.Show(self: VfxPool, model: Model)
	model.Parent = self.Folder
	setTrails(model, true)
end

function VfxPool.Release(self: VfxPool, model: Model)
	local kind = model:GetAttribute("VfxKind") :: string?
	setTrails(model, false)
	model.Parent = nil
	if not kind or not intact(model) then
		model:Destroy()
		return
	end
	local free = self.Free[kind]
	if not free then
		free = {}
		self.Free[kind] = free
	end
	if #free >= VfxPool.MAX_FREE_PER_KIND then
		model:Destroy()
	else
		table.insert(free, model)
	end
end

-- Schedules an effect. Returns false (and runs its cleanup) when the budget is full.
function VfxPool.Run(self: VfxPool, effect: Effect): boolean
	if #self.Effects >= VfxPool.MAX_EFFECTS then
		if effect.Cleanup then
			effect.Cleanup()
		end
		return false
	end
	table.insert(self.Effects, effect)
	return true
end

-- True when any point is within CULL_DISTANCE of the camera.
function VfxPool.Visible(_self: VfxPool, ...: Vector3): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return true
	end
	local eye = camera.CFrame.Position
	for _, point in { ... } do
		if (point - eye).Magnitude <= VfxPool.CULL_DISTANCE then
			return true
		end
	end
	return false
end

function VfxPool.Step(self: VfxPool, now: number)
	local effects = self.Effects
	if #effects == 0 then
		return
	end
	debug.profilebegin("CombatVfx.Step")
	self.Effects = {}
	local keep: { Effect } = {}
	for _, effect in effects do
		local ok, finished = pcall(effect.Update, now)
		if not ok then
			warn(`CombatVfx: effect failed: {finished}`)
		end
		if not ok or finished then
			if effect.Cleanup then
				pcall(effect.Cleanup)
			end
		else
			table.insert(keep, effect)
		end
	end
	-- Effects scheduled from inside an update start next frame.
	for _, added in self.Effects do
		table.insert(keep, added)
	end
	self.Effects = keep
	debug.profileend()
end

-- Ends every effect (room change, view reset).
function VfxPool.Clear(self: VfxPool)
	local effects = self.Effects
	self.Effects = {}
	for _, effect in effects do
		if effect.Cleanup then
			pcall(effect.Cleanup)
		end
	end
end

function VfxPool.Count(self: VfxPool): number
	return #self.Effects
end

return VfxPool
