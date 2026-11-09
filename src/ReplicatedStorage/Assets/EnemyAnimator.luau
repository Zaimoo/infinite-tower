--!strict
-- One clip player for every tower enemy rig (docs/mob-reanimation-plan.md §3.1, step 1): the tower renderer
-- (EnemyAnimationController), the hub patrol and the Facility preview all drive their rigs through it.
--
--   local anim = EnemyAnimator.new(rig, seed)    -- rig from EnemyRigFactory / RaidBossRigs; seed = NetId etc.
--   anim:Step(now, input)                        -- every frame; writes Motor6D.Transform (C0 stays Bind)
--
-- `input` is the caller's state, read each frame (reuse one table, it is not kept):
--   Moved        studs travelled since the last Step (ignored when Treadmill is set)
--   Speed        optional studs/s that decides walk vs idle (the tower passes its snapshot glide speed)
--   Treadmill    studs per second to walk in place (Facility preview)
--   Action       { AnimationKey, StartServerTime, WindupSeconds?, ImpactOffsetSeconds, RecoverySeconds } or nil
--   HitAt, DeathAt, BornAt, AwakenSeconds
--
-- Layers: Idle and Locomotion blend by a speed weight with hysteresis; an action plays on top (legs keep
-- walking while the mob moves); a hit flinch is added on top of anything; death overrides all. Each joint
-- eases towards its target, except through an attack's strike, which plays crisp.
local Clips = require(game.ReplicatedStorage.Assets.TowerEnemyClips)

local EnemyAnimator = {}
EnemyAnimator.__index = EnemyAnimator

EnemyAnimator.SMOOTHING = 14 -- per second, exponential ease of every joint towards its target
EnemyAnimator.ACTION_FADE = 0.12
EnemyAnimator.DEATH_FADE = 0.1
EnemyAnimator.DEATH_SECONDS = 1.6
EnemyAnimator.HIT_SECONDS = 0.28
EnemyAnimator.IDLE_SECONDS = 3
EnemyAnimator.MOVE_START = 0.6 -- studs/s to start walking
EnemyAnimator.MOVE_STOP = 0.3 -- studs/s below which walking stops after MOVE_GRACE
EnemyAnimator.MOVE_GRACE = 0.35 -- longer than a 5 Hz snapshot gap plus jitter
EnemyAnimator.SPEED_RATE = 6.5 -- per second, smoothing of the measured speed
EnemyAnimator.LOCO_BLEND_RATE = 8 -- per second, idle <-> walk weight
EnemyAnimator.STRIKE_LEAD = 0.15 -- share of the windup the strike takes...
EnemyAnimator.STRIKE_LEAD_MAX = 0.25 -- ...capped in seconds

local IDENTITY = CFrame.identity

-- ------------------------------------------------------------------ compiled clips
type Compiled = { Times: { number }, Names: { string }, Keys: { [string]: { CFrame } } }
local compiled: { [any]: Compiled } = setmetatable({}, { __mode = "k" }) :: any

local function compile(frames: any): Compiled
	local c = compiled[frames]
	if c then return c end
	local names: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, frame in frames do
		for name in frame[2] do
			if not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end
	local times: { number } = {}
	local keys: { [string]: { CFrame } } = {}
	for _, name in names do keys[name] = {} end
	for i, frame in frames do
		times[i] = frame[1]
		for _, name in names do
			keys[name][i] = frame[2][name] or IDENTITY
		end
	end
	c = { Times = times, Names = names, Keys = keys }
	compiled[frames] = c
	return c
end
EnemyAnimator.Compile = compile

-- Sample `frames` at normalized t into `out` (cleared first), with the same eased interpolation as
-- TowerEnemyClips.Sample. Allocates no tables once the clip is compiled.
function EnemyAnimator.SampleInto(frames: any, t: number, out: { [string]: CFrame }): { [string]: CFrame }
	table.clear(out)
	local c = compile(frames)
	local times = c.Times
	local n = #times
	t = math.clamp(t, 0, 1)
	local a, b = 1, n
	for i = 2, n do
		if t <= times[i] then
			a, b = i - 1, i
			break
		end
	end
	local alpha = math.clamp((t - times[a]) / math.max(0.0001, times[b] - times[a]), 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	for _, name in c.Names do
		local k = c.Keys[name]
		out[name] = k[a]:Lerp(k[b], alpha)
	end
	return out
end

-- ------------------------------------------------------------------ attack timing
-- Real seconds since the action started -> clip time, following the server's timings (plan §3.4):
-- anticipation up to the strike, the strike in the last part of the windup, a held follow-through while a
-- projectile flies, then recovery.
function EnemyAnimator.ActionPhase(elapsed: number, windup: number?, impact: number, recovery: number, release: number, impactMark: number): number
	local w = math.min(windup or impact, impact)
	local lead = math.min(w * EnemyAnimator.STRIKE_LEAD, EnemyAnimator.STRIKE_LEAD_MAX)
	if elapsed <= 0 then
		return 0
	elseif elapsed < w - lead then
		return release * elapsed / math.max(0.001, w - lead)
	elseif elapsed < w then
		return release + (impactMark - release) * (elapsed - (w - lead)) / math.max(0.001, lead)
	elseif elapsed < impact then
		return impactMark
	end
	return impactMark + (1 - impactMark) * math.clamp((elapsed - impact) / math.max(0.001, recovery), 0, 1)
end

-- True while the clip is between the start of the strike and just after impact.
local function inStrike(elapsed: number, windup: number?, impact: number): boolean
	local w = math.min(windup or impact, impact)
	local lead = math.min(w * EnemyAnimator.STRIKE_LEAD, EnemyAnimator.STRIKE_LEAD_MAX)
	return elapsed >= w - lead and elapsed <= impact + 0.05
end

-- Studs per locomotion cycle (step 2 of the plan replaces this with one measured from leg length).
function EnemyAnimator.Stride(rig: any): number
	local role = rig.Spec and rig.Spec.Role
	return if role == "BOSS" then 9.6 elseif role == "REGULAR" then 3.6 else 4.8
end

-- A stable 0..1 value from a seed (NetId, patrol index, a string...).
function EnemyAnimator.Hash(seed: any, salt: number): number
	local n = 0
	if type(seed) == "number" then
		n = math.floor(math.abs(seed)) % 2147483647
	else
		local s = tostring(seed)
		for i = 1, #s do n = (n * 31 + string.byte(s, i)) % 2147483647 end
	end
	n = (n * 1103515245 + 12345 + salt * 2654435) % 2147483648
	n = (n * 1103515245 + 12345) % 2147483648
	return n / 2147483648
end

local legJoint: { [string]: boolean } = {}
local function isLeg(name: string): boolean
	local cached = legJoint[name]
	if cached == nil then
		cached = string.sub(name, 1, 3) == "Leg" or string.sub(name, 1, 4) == "Knee"
		legJoint[name] = cached
	end
	return cached
end

-- ------------------------------------------------------------------ animator
function EnemyAnimator.new(rig: any, seed: any)
	local self = setmetatable({}, EnemyAnimator) :: any
	self.Rig = rig
	self.Clips = rig.Clips or Clips[rig.EnemyId] -- mesh raid bosses carry their own clips
	self.IdleOffset = EnemyAnimator.Hash(seed, 1)
	self.IdleRate = 0.9 + 0.2 * EnemyAnimator.Hash(seed, 2)
	self.GaitRate = 0.95 + 0.1 * EnemyAnimator.Hash(seed, 3)
	self.Distance = 0
	self.Speed = 0
	self.Moving = false
	self.WalkingUntil = 0
	self.LocoWeight = 0
	self.LastNow = nil :: number?
	self.Current = {} :: { [string]: CFrame }
	self.IdleOut = {} :: { [string]: CFrame }
	self.LocoOut = {} :: { [string]: CFrame }
	self.ActOut = {} :: { [string]: CFrame }
	self.HitOut = {} :: { [string]: CFrame }
	self.HitBase = {} :: { [string]: CFrame }
	self.DeathOut = {} :: { [string]: CFrame }
	if self.Clips and self.Clips.HitReaction then
		EnemyAnimator.SampleInto(self.Clips.HitReaction, 0, self.HitBase)
	end
	return self
end

-- The joint -> Transform targets for this frame, before smoothing. Exposed for tests.
function EnemyAnimator:Evaluate(now: number, input: any, dt: number): ({ [string]: CFrame }?, boolean)
	local clips = self.Clips
	if not clips then return nil, false end

	-- speed, hysteresis and the idle <-> walk weight
	local moved = if input.Treadmill then input.Treadmill * dt else (input.Moved or 0)
	self.Distance += math.min(moved, 4)
	if input.Speed then
		self.Speed = input.Speed
	elseif dt > 0 then
		local instant = moved / dt
		self.Speed += (instant - self.Speed) * (1 - math.exp(-dt * EnemyAnimator.SPEED_RATE))
	end
	local threshold = if self.Moving then EnemyAnimator.MOVE_STOP else EnemyAnimator.MOVE_START
	if input.Treadmill or self.Speed > threshold then
		self.Moving = true
		self.WalkingUntil = now + EnemyAnimator.MOVE_GRACE
	elseif now >= self.WalkingUntil then
		self.Moving = false
	end
	local wantLoco = if self.Moving and not input.DeathAt then 1 else 0
	self.LocoWeight += (wantLoco - self.LocoWeight) * (if dt > 0 then 1 - math.exp(-dt * EnemyAnimator.LOCO_BLEND_RATE) else 1)

	-- base layer
	local idlePhase = (now * self.IdleRate / EnemyAnimator.IDLE_SECONDS + self.IdleOffset) % 1
	local idle = EnemyAnimator.SampleInto(clips.Idle, idlePhase, self.IdleOut)
	local locoWeight = self.LocoWeight
	local loco: { [string]: CFrame }? = nil
	if locoWeight > 0.001 and clips.Locomotion then
		local stride = EnemyAnimator.Stride(self.Rig) / self.GaitRate
		loco = EnemyAnimator.SampleInto(clips.Locomotion, (self.Distance / stride) % 1, self.LocoOut)
	end

	-- action layer: an attack, else the awakening
	local act: { [string]: CFrame }? = nil
	local actWeight = 0
	local snap = false
	local action = input.Action
	if action and not input.DeathAt then
		local elapsed = now - action.StartServerTime
		local total = action.ImpactOffsetSeconds + action.RecoverySeconds
		local frames = clips[action.AnimationKey] or clips.BasicAttack
		if frames and elapsed >= 0 and elapsed <= total then
			local release, impactMark = Clips.MarkersFor(frames)
			local phase = EnemyAnimator.ActionPhase(elapsed, action.WindupSeconds, action.ImpactOffsetSeconds, action.RecoverySeconds, release, impactMark)
			act = EnemyAnimator.SampleInto(frames, phase, self.ActOut)
			actWeight = math.clamp(elapsed / EnemyAnimator.ACTION_FADE, 0, 1)
			snap = inStrike(elapsed, action.WindupSeconds, action.ImpactOffsetSeconds)
		end
	end
	if not act and not input.DeathAt and input.BornAt and clips.Awakening then
		local span = input.AwakenSeconds or 2.2
		local elapsed = now - input.BornAt
		if elapsed >= 0 and elapsed < span then
			act = EnemyAnimator.SampleInto(clips.Awakening, elapsed / span, self.ActOut)
			actWeight = 1
		end
	end
	local maskLegs = self.Moving

	-- hit flinch (additive) and death
	local hit: { [string]: CFrame }? = nil
	if input.HitAt and not input.DeathAt and clips.HitReaction then
		local elapsed = now - input.HitAt
		if elapsed >= 0 and elapsed < EnemyAnimator.HIT_SECONDS then
			hit = EnemyAnimator.SampleInto(clips.HitReaction, elapsed / EnemyAnimator.HIT_SECONDS, self.HitOut)
		end
	end
	local death: { [string]: CFrame }? = nil
	local deathWeight = 0
	if input.DeathAt and clips.Death then
		local elapsed = now - input.DeathAt
		death = EnemyAnimator.SampleInto(clips.Death, elapsed / EnemyAnimator.DEATH_SECONDS, self.DeathOut)
		deathWeight = math.clamp(elapsed / EnemyAnimator.DEATH_FADE, 0, 1)
	end

	-- compose into Current's sibling table (targets), reusing one table
	local targets = self.Targets
	if not targets then
		targets = {}
		self.Targets = targets
	end
	for name in self.Rig.Joints do
		local pose = idle[name] or IDENTITY
		if loco then pose = pose:Lerp(loco[name] or IDENTITY, locoWeight) end
		if act and actWeight > 0 and not (maskLegs and isLeg(name)) then
			pose = pose:Lerp(act[name] or IDENTITY, actWeight)
		end
		if hit then
			local h = hit[name]
			if h then pose = pose * ((self.HitBase[name] or IDENTITY):Inverse() * h) end
		end
		if death then pose = pose:Lerp(death[name] or IDENTITY, deathWeight) end
		targets[name] = pose
	end
	return targets, snap
end

function EnemyAnimator:Step(now: number, input: any)
	local dt = if self.LastNow then math.clamp(now - self.LastNow, 0, 0.25) else 0
	self.LastNow = now
	local targets, snap = self:Evaluate(now, input, dt)
	if not targets then return end
	local k = if snap or dt <= 0 then 1 else 1 - math.exp(-dt * EnemyAnimator.SMOOTHING)
	local current = self.Current
	for name, joint in self.Rig.Joints do
		local target = targets[name]
		local value = current[name]
		value = if value and k < 1 then value:Lerp(target, k) else target
		current[name] = value
		joint.Motor.Transform = value
	end
end

return EnemyAnimator
