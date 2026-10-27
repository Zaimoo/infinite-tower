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
--   pool:Step(Workspace:GetServerTimeNow(), dt)      -- every frame
--
-- Budget (Phase 6): a VfxQuality state caps live effects and sets the detail SkillVfx draws at.
-- The player's graphics setting is the ceiling; slow frames lower it automatically.

local Workspace = game:GetService("Workspace")

local VfxQuality = require(script.Parent:WaitForChild("VfxQuality"))

local VfxPool = {}
VfxPool.__index = VfxPool

VfxPool.MAX_FREE_PER_KIND = 32 -- parked assemblies kept per kind
VfxPool.CULL_DISTANCE = 180 -- effects with every point farther than this from the camera are skipped

export type Effect = {
	Update: (now: number) -> boolean, -- returns true when finished
	Cleanup: (() -> ())?,
}

export type Stats = {
	Live: number, -- effects running
	Parked: number, -- assemblies waiting in the pool
	Refused: number, -- effects refused over budget since the last Stats call
	StepMs: number, -- smoothed Step cost, milliseconds
	Quality: string, -- effective quality level
	Setting: string, -- the player's quality setting
}

export type VfxPool = typeof(setmetatable({} :: {
	Folder: Folder,
	Free: { [string]: { Model } },
	Effects: { Effect },
	Quality: VfxQuality.State,
	Refused: number,
	StepMs: number,
	MoveParts: { BasePart },
	MoveFrames: { CFrame },
	Offsets: { [Model]: { { Part: BasePart, Offset: CFrame } } },
}, VfxPool))

function VfxPool.new(parent: Instance): VfxPool
	local folder = Instance.new("Folder")
	folder.Name = "ClientCombatVfx"
	folder.Parent = parent
	return setmetatable({
		Folder = folder,
		Free = {},
		Effects = {},
		Quality = VfxQuality.New(),
		Refused = 0,
		StepMs = 0,
		MoveParts = {},
		MoveFrames = {},
		Offsets = setmetatable({}, { __mode = "k" }) :: any,
	}, VfxPool)
end

-- Queues a part's CFrame for this frame. Step writes every queued CFrame with one
-- Workspace:BulkMoveTo, which is much cheaper than setting CFrame part by part.
function VfxPool.Move(self: VfxPool, part: BasePart, frame: CFrame)
	table.insert(self.MoveParts, part)
	table.insert(self.MoveFrames, frame)
end

-- Queues a whole assembly so its PrimaryPart lands on `pivot` (a batched PivotTo). Part offsets
-- are measured once per assembly; pooled assemblies are rigid, so they never change.
function VfxPool.MoveModel(self: VfxPool, model: Model, pivot: CFrame)
	local offsets = self.Offsets[model]
	if not offsets then
		local primary = model.PrimaryPart :: BasePart
		offsets = {}
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(offsets, { Part = d, Offset = primary.CFrame:ToObjectSpace(d.CFrame) })
			end
		end
		self.Offsets[model] = offsets
	end
	for _, entry in offsets do
		self:Move(entry.Part, pivot * entry.Offset)
	end
end

local function flush(self: VfxPool)
	if #self.MoveParts > 0 then
		Workspace:BulkMoveTo(self.MoveParts, self.MoveFrames, Enum.BulkMoveMode.FireCFrameChanged)
		table.clear(self.MoveParts)
		table.clear(self.MoveFrames)
	end
end

-- The player's graphics quality setting ("High" | "Medium" | "Low"); the ceiling for auto drops.
function VfxPool.SetQuality(self: VfxPool, setting: any)
	VfxQuality.SetSetting(self.Quality, VfxQuality.Parse(setting))
end

-- Detail multiplier for effect counts at the effective quality (1 = full).
function VfxPool.Detail(self: VfxPool): number
	return VfxQuality.Detail(self.Quality)
end

-- Live effects as a share of the budget (0..1+). Decoration is skipped when this runs high.
function VfxPool.Pressure(self: VfxPool): number
	return #self.Effects / VfxQuality.MaxEffects(self.Quality)
end

-- Whether optional decoration (spokes, rings, motes) should be drawn right now.
function VfxPool.Decor(self: VfxPool): boolean
	return self:Detail() >= VfxQuality.DECOR_DETAIL and self:Pressure() < VfxQuality.DECOR_PRESSURE
end

function VfxPool.Stats(self: VfxPool): Stats
	local parked = 0
	for _, free in self.Free do
		parked += #free
	end
	local refused = self.Refused
	self.Refused = 0
	return {
		Live = #self.Effects,
		Parked = parked,
		Refused = refused,
		StepMs = self.StepMs,
		Quality = VfxQuality.Effective(self.Quality),
		Setting = self.Quality.Setting,
	}
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

-- Builds `count` assemblies of `kind` ahead of time so the first big skill does not hitch.
function VfxPool.Prewarm(self: VfxPool, kind: string, build: () -> Model, count: number)
	local free = self.Free[kind]
	if not free then
		free = {}
		self.Free[kind] = free
	end
	while #free < math.min(count, VfxPool.MAX_FREE_PER_KIND) do
		local model = build()
		model:SetAttribute("VfxKind", kind)
		setTrails(model, false)
		table.insert(free, model)
	end
end

-- Schedules an effect. Returns false (and runs its cleanup) when the budget is full.
function VfxPool.Run(self: VfxPool, effect: Effect): boolean
	if #self.Effects >= VfxQuality.MaxEffects(self.Quality) then
		self.Refused += 1
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

-- Runs every effect for this frame. `dt` (the frame's duration) drives the automatic quality drop.
function VfxPool.Step(self: VfxPool, now: number, dt: number?)
	if dt then
		VfxQuality.Observe(self.Quality, dt)
	end
	local effects = self.Effects
	if #effects == 0 then
		self.StepMs *= 0.9
		return
	end
	local started = os.clock()
	debug.profilebegin("CombatVfx.Step")
	self.Effects = {}
	local keep: { Effect } = {}
	local finishedEffects: { Effect } = {}
	for _, effect in effects do
		local ok, finished = pcall(effect.Update, now)
		if not ok then
			warn(`CombatVfx: effect failed: {finished}`)
		end
		if not ok or finished then
			table.insert(finishedEffects, effect)
		else
			table.insert(keep, effect)
		end
	end
	-- Write this frame's positions in one batch, then release what finished (cleanup parks
	-- assemblies, so it runs after their last move).
	local moved, err = pcall(flush, self)
	if not moved then
		warn(`CombatVfx: batched move failed: {err}`)
		table.clear(self.MoveParts)
		table.clear(self.MoveFrames)
	end
	for _, effect in finishedEffects do
		if effect.Cleanup then
			pcall(effect.Cleanup)
		end
	end
	-- Effects scheduled from inside an update start next frame.
	for _, added in self.Effects do
		table.insert(keep, added)
	end
	self.Effects = keep
	debug.profileend()
	self.StepMs += ((os.clock() - started) * 1000 - self.StepMs) * 0.1
end

-- Ends every effect (room change, view reset).
function VfxPool.Clear(self: VfxPool)
	local effects = self.Effects
	self.Effects = {}
	table.clear(self.MoveParts)
	table.clear(self.MoveFrames)
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
