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
--   Far          true beyond full-rate LOD distance: springs rest, no fidgets, head aim or turn lean
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
EnemyAnimator.FIDGET_SECONDS = 2.2 -- a fidget's length
EnemyAnimator.FIDGET_MIN, EnemyAnimator.FIDGET_SPREAD = 6, 8 -- seconds between fidgets: 6 + 0..8, seeded (plan §3.7)
EnemyAnimator.FIDGET_CALM = 3 -- seconds of quiet (no move, attack or awakening) before a fidget may start
EnemyAnimator.STRIKE_LEAD = 0.15 -- share of the windup the strike takes...
EnemyAnimator.STRIKE_LEAD_MAX = 0.25 -- ...capped in seconds

local IDENTITY = CFrame.identity

-- Head aim (plan §3.7): through an attack's anticipation the head turns towards the action's aim, clamped;
-- quadrupeds and serpents turn their body with it. Turn lean (§3.6): the body rolls into a turn while walking.
EnemyAnimator.AIM_MAX = math.rad(35)
EnemyAnimator.AIM_IN = 0.2 -- seconds to turn onto the aim
EnemyAnimator.AIM_OUT = 0.35 -- seconds to turn back after impact
EnemyAnimator.AIM_BODY = { QUADRUPED = 0.45, SERPENT = 0.5 } -- share of the aim the body takes
EnemyAnimator.TURN_LEAN = 0.09 -- radians of roll per rad/s of yaw rate
EnemyAnimator.TURN_LEAN_MAX = math.rad(7)
EnemyAnimator.TURN_RATE = 8 -- per second, smoothing of the measured yaw rate

-- Yaw (radians, + to the rig's right) from the rig's facing to a world direction, clamped to the aim limit.
function EnemyAnimator.AimYaw(facing: CFrame, dir: Vector3): number
	local l = facing:VectorToObjectSpace(Vector3.new(dir.X, 0, dir.Z))
	if l.Magnitude < 1e-3 then return 0 end
	local m = EnemyAnimator.AIM_MAX
	return math.clamp(math.atan2(l.X, -l.Z), -m, m)
end

-- Weight of the head aim at `elapsed` seconds into an action that lands at `impact`.
function EnemyAnimator.AimWeight(elapsed: number, impact: number): number
	if elapsed < 0 then return 0 end
	if elapsed <= impact then return math.clamp(elapsed / EnemyAnimator.AIM_IN, 0, 1) end
	return math.clamp(1 - (elapsed - impact) / EnemyAnimator.AIM_OUT, 0, 1)
end

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

-- ------------------------------------------------------------------ size (plan §3.5, §3.6)
-- Clip translations are authored for one hip height per clip group; MotionScale stretches them to the drawn
-- model so a death drop, lunge or bob reads the same on a 2-stud mite and a 25-stud boss.
EnemyAnimator.REFERENCE_HIP = { BIPED = 3.5, MULTILEG = 1.3, QUADRUPED = 2.4, AVIAN = 2.8, SERPENT = 4.2 }
-- Studs per walk cycle per stud of hip height: two steps of 2 * leg * sin(swing). Biped and avian legs swing
-- ±24°, quadrupeds ±22°; crawler legs sweep ±18° with a reach about 1.4x their hip; the serpent's S-wave
-- travels about one and a half hip heights.
EnemyAnimator.STRIDE_PER_HIP = {
	BIPED = 4 * math.sin(math.rad(24)),
	AVIAN = 4 * math.sin(math.rad(24)),
	QUADRUPED = 4 * math.sin(math.rad(22)),
	MULTILEG = 4 * 1.4 * math.sin(math.rad(18)),
	SERPENT = 1.5,
}

export type Metrics = { Group: string, Height: number, HipHeight: number, MotionScale: number, Stride: number }

-- Size metrics for a rig. `entry` is the TowerEnemyModelIndex entry for a remodelled template (nil for the
-- part rig, which uses its combat spec); `renderScale` is how much bigger the template is drawn.
function EnemyAnimator.Metrics(enemyId: string, spec: any, entry: any?, renderScale: number?): Metrics
	local group = Clips.GroupFor(enemyId)
	local s = renderScale or 1
	local hip, height
	if entry then
		local sum, n = 0, 0
		for _, seg in entry.Segments do
			if (group == "MULTILEG" and string.match(seg.Name, "^Leg%-?1_%d$")) or (group ~= "MULTILEG" and seg.Name == "LegL") then
				sum += seg.Pivot.Y
				n += 1
			end
		end
		hip = (if n > 0 then sum / n else entry.Height * 0.45) * s
		height = entry.Height * s
	else
		hip = (spec and spec.RootHeight) or 3
		height = (spec and spec.Height) or hip * 2
	end
	hip = math.max(0.3, hip)
	local ref = EnemyAnimator.REFERENCE_HIP[group] or 3.5
	return {
		Group = group,
		Height = height,
		HipHeight = hip,
		MotionScale = math.clamp(hip / ref, 0.4, 4),
		Stride = (EnemyAnimator.STRIDE_PER_HIP[group] or 1.6) * hip,
	}
end

-- Studs per locomotion cycle: from the rig's leg length, else the old per-role table (raid stand-ins).
function EnemyAnimator.Stride(rig: any): number
	if rig.Metrics then return rig.Metrics.Stride end
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

-- ------------------------------------------------------------------ springs (plan §3.7, §3.8)
-- Extra*/Trophy_* joints that no playing clip keys move as damped springs on two tilt axes (local X: fore/aft,
-- local Z: sideways), driven three ways:
--   * rotation inertia: when the parent turns, the piece keeps most of its world orientation and swings back,
--     so a censer or whip trails an arm swing, a body bob or a turn (the main source of motion);
--   * linear inertia: the pivot's acceleration pushes the piece the other way (starts, stops, lunges);
--   * idle sway: a slow seeded drift, so cloth and hanging pieces never sit dead still.
-- Spin joints just turn. Roles come from tools/blender/mob_extras.py.
export type SpringParams = { K: number, C: number, G: number, Max: number, Inertia: number, Sway: number, SwayHz: number }
EnemyAnimator.SPRINGS = {
	Cloth = { K = 30, C = 4, G = 0.5, Max = 0.6, Inertia = 0.8, Sway = 0.07, SwayHz = 0.7 } :: SpringParams,
	Hanging = { K = 22, C = 2.2, G = 0.45, Max = 0.7, Inertia = 0.9, Sway = 0.05, SwayHz = 0.6 } :: SpringParams,
	Rigid = { K = 110, C = 9, G = 0.4, Max = 0.18, Inertia = 0.5, Sway = 0.04, SwayHz = 1.1 } :: SpringParams,
}
EnemyAnimator.SPIN_RATE = 1.2 -- radians per second
EnemyAnimator.MAX_ACCEL = 250 -- studs/s², clamps teleports and snapshot hitches
EnemyAnimator.MAX_TURN_STEP = 0.5 -- radians per frame of parent rotation fed to inertia (teleports, snaps)

export type SpringState = { X: number, Z: number, VX: number, VZ: number, Angle: number, LastPos: Vector3?, LastVel: Vector3?, LastRot: CFrame? }

-- Advance one spring by dt towards a sway target (radians) under a pivot acceleration (parent-local X and Z,
-- studs/s²). Pure; exposed for tests.
function EnemyAnimator.SpringStep(st: SpringState, accX: number, accZ: number, dt: number, p: SpringParams, swayX: number?, swayZ: number?)
	local tx, tz = swayX or 0, swayZ or 0
	local steps = math.max(1, math.ceil(dt / (1 / 60)))
	local h = dt / steps
	for _ = 1, steps do
		st.VX += (p.K * (tx - st.X) - p.C * st.VX + p.G * accZ) * h
		st.VZ += (p.K * (tz - st.Z) - p.C * st.VZ - p.G * accX) * h
		st.X = math.clamp(st.X + st.VX * h, -p.Max, p.Max)
		st.Z = math.clamp(st.Z + st.VZ * h, -p.Max, p.Max)
	end
end

-- Counter-rotate a spring by its parent's turn this frame (parent-local radians about X and Z). Pure.
function EnemyAnimator.SpringTurn(st: SpringState, turnX: number, turnZ: number, p: SpringParams)
	local m = EnemyAnimator.MAX_TURN_STEP
	st.X = math.clamp(st.X - math.clamp(turnX, -m, m) * p.Inertia, -p.Max, p.Max)
	st.Z = math.clamp(st.Z - math.clamp(turnZ, -m, m) * p.Inertia, -p.Max, p.Max)
end

local function springPose(self: any, name: string, motion: string, joint: any, dt: number, far: boolean, now: number): CFrame
	local springs = self.Springs
	local st: SpringState = springs[name]
	if not st then
		st = { X = 0, Z = 0, VX = 0, VZ = 0, Angle = 0 }
		springs[name] = st
	end
	if motion == "Spin" then
		st.Angle = (st.Angle + EnemyAnimator.SPIN_RATE * dt) % (2 * math.pi)
		return CFrame.Angles(0, st.Angle, 0)
	end
	local p = EnemyAnimator.SPRINGS[motion]
	if not p or far then
		st.X, st.Z, st.VX, st.VZ, st.LastPos, st.LastVel, st.LastRot = 0, 0, 0, 0, nil, nil, nil
		return IDENTITY
	end
	if dt <= 0 then return CFrame.Angles(st.X, 0, st.Z) end
	-- seeded sway: each joint drifts on its own phase
	local phase = (self.IdleOffset + #name * 0.137) * 2 * math.pi
	local w = 2 * math.pi * p.SwayHz * self.IdleRate
	local swayX = p.Sway * math.sin(now * w + phase)
	local swayZ = p.Sway * 0.6 * math.sin(now * w * 0.73 + phase * 1.7)
	local accX, accZ = 0, 0
	local part0 = joint.Motor.Part0
	if part0 then
		local frame = part0.CFrame * joint.Bind
		local rot = frame.Rotation
		if st.LastRot then
			local turnX, _, turnZ = st.LastRot:ToObjectSpace(rot):ToEulerAnglesXYZ()
			EnemyAnimator.SpringTurn(st, turnX, turnZ, p)
		end
		st.LastRot = rot
		local pos = frame.Position
		local vel = if st.LastPos then (pos - st.LastPos) / dt else Vector3.zero
		local acc = if st.LastVel then (vel - st.LastVel) / dt else Vector3.zero
		if acc.Magnitude > EnemyAnimator.MAX_ACCEL then acc = acc.Unit * EnemyAnimator.MAX_ACCEL end
		st.LastPos, st.LastVel = pos, vel
		local localAcc = frame:VectorToObjectSpace(acc)
		accX, accZ = localAcc.X, localAcc.Z
	end
	EnemyAnimator.SpringStep(st, accX, accZ, dt, p, swayX, swayZ)
	return CFrame.Angles(st.X, 0, st.Z)
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
	self.Springs = {} :: { [string]: SpringState }
	self.IdleOut = {} :: { [string]: CFrame }
	self.LocoOut = {} :: { [string]: CFrame }
	self.ActOut = {} :: { [string]: CFrame }
	self.HitOut = {} :: { [string]: CFrame }
	self.HitBase = {} :: { [string]: CFrame }
	self.DeathOut = {} :: { [string]: CFrame }
	if self.Clips and self.Clips.HitReaction then
		EnemyAnimator.SampleInto(self.Clips.HitReaction, 0, self.HitBase)
	end
	-- per-set timing from the clip library (biped sets and later); older clip groups use the defaults
	local meta = if rig.Clips then nil else Clips.MetaFor(rig.EnemyId)
	self.IdleSeconds = (meta and meta.IdleSeconds) or EnemyAnimator.IDLE_SECONDS
	self.StrideScale = (meta and meta.StrideScale) or 1
	self.Fidgets = meta and meta.Fidgets
	self.Seed = seed
	self.FidgetCount = 0
	self.NextFidgetAt = nil :: number?
	self.FidgetAt = nil :: number?
	self.FidgetFrames = nil :: any
	self.LastBusyAt = -math.huge
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
	local idlePhase = (now * self.IdleRate / self.IdleSeconds + self.IdleOffset) % 1
	local idle = EnemyAnimator.SampleInto(clips.Idle, idlePhase, self.IdleOut)
	local locoWeight = self.LocoWeight
	local loco: { [string]: CFrame }? = nil
	if locoWeight > 0.001 and clips.Locomotion then
		local stride = EnemyAnimator.Stride(self.Rig) * self.StrideScale / self.GaitRate
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
		-- "<Slot>:<Shape>" first, so two moves sharing a slot play their own styles (cached per action record)
		if action ~= self.CachedAction then
			self.CachedAction = action
			self.CachedFrames = (action.Shape and clips[action.AnimationKey .. ":" .. action.Shape]) or clips[action.AnimationKey] or clips.BasicAttack
		end
		local frames = self.CachedFrames
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
	-- fidgets: every 6–14 s (seeded) a calm, standing mob plays one of its set's fidgets, eased in and out
	local fidgets = if input.Far then nil else self.Fidgets
	if fidgets and #fidgets > 0 then
		if act or self.Moving or input.DeathAt then
			self.LastBusyAt = now
			self.FidgetAt = nil
		end
		if not self.NextFidgetAt then
			self.NextFidgetAt = now + EnemyAnimator.FIDGET_MIN + EnemyAnimator.FIDGET_SPREAD * EnemyAnimator.Hash(self.Seed, 10)
		end
		if not act and not self.Moving and not input.DeathAt then
			if not self.FidgetAt and now >= self.NextFidgetAt and now - self.LastBusyAt >= EnemyAnimator.FIDGET_CALM then
				self.FidgetCount += 1
				local pick = 1 + math.floor(EnemyAnimator.Hash(self.Seed, 20 + self.FidgetCount) * #fidgets) % #fidgets
				self.FidgetAt = now
				self.FidgetFrames = fidgets[pick]
			end
			local at = self.FidgetAt
			if at then
				local t = (now - at) / EnemyAnimator.FIDGET_SECONDS
				if t >= 1 then
					self.FidgetAt = nil
					self.NextFidgetAt = now + EnemyAnimator.FIDGET_MIN + EnemyAnimator.FIDGET_SPREAD * EnemyAnimator.Hash(self.Seed, 30 + self.FidgetCount)
				else
					act = EnemyAnimator.SampleInto(self.FidgetFrames, t, self.ActOut)
					actWeight = math.sin(math.pi * t)
				end
			end
		end
	end
	local maskLegs = self.Moving

	-- head aim and turn lean (full-rate mobs only)
	local aimYaw, bodyYaw, roll = 0, 0, 0
	local root = self.Rig.Root
	if root and not input.Far and not input.DeathAt then
		local facing = root.CFrame
		if action and action.Aim and action.Origin then
			local w = EnemyAnimator.AimWeight(now - action.StartServerTime, action.WindupSeconds or action.ImpactOffsetSeconds)
			if w > 0 then
				local yaw = EnemyAnimator.AimYaw(facing, action.Aim - action.Origin) * w
				local share = EnemyAnimator.AIM_BODY[Clips.GroupFor(self.Rig.EnemyId)] or 0
				bodyYaw, aimYaw = yaw * share, yaw * (1 - share)
			end
		end
		local look = facing.LookVector
		local heading = math.atan2(-look.X, -look.Z)
		local last = self.LastHeading
		self.LastHeading = heading
		if last and dt > 0 then
			local d = (heading - last + math.pi) % (2 * math.pi) - math.pi
			self.YawRate = (self.YawRate or 0) + (d / dt - (self.YawRate or 0)) * (1 - math.exp(-dt * EnemyAnimator.TURN_RATE))
		end
		local m = EnemyAnimator.TURN_LEAN_MAX
		roll = math.clamp((self.YawRate or 0) * EnemyAnimator.TURN_LEAN, -m, m) * self.LocoWeight
	else
		self.LastHeading, self.YawRate = nil, 0
	end

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
	local motionScale = if self.Rig.Metrics then self.Rig.Metrics.MotionScale else 1
	local motions = self.Rig.JointMotion
	for name, joint in self.Rig.Joints do
		local motion = motions and motions[name]
		local keyed = idle[name] or (loco and loco[name]) or (act and act[name]) or (death and death[name])
		local pose = if motion and not keyed then springPose(self, name, motion, joint, dt, input.Far == true, now)
			else idle[name] or IDENTITY
		if loco then pose = pose:Lerp(loco[name] or IDENTITY, locoWeight) end
		if act and actWeight > 0 and not (maskLegs and isLeg(name)) then
			pose = pose:Lerp(act[name] or IDENTITY, actWeight)
		end
		if hit then
			local h = hit[name]
			if h then pose = pose * ((self.HitBase[name] or IDENTITY):Inverse() * h) end
		end
		if death then pose = pose:Lerp(death[name] or IDENTITY, deathWeight) end
		if name == "Head" and aimYaw ~= 0 then
			pose = CFrame.Angles(0, -aimYaw, 0) * pose
		elseif name == "Body" and (bodyYaw ~= 0 or roll ~= 0) then
			-- a left turn (heading rising) rolls the body left, into the turn
			pose = CFrame.new(pose.X, pose.Y, pose.Z) * CFrame.Angles(0, -bodyYaw, roll) * pose.Rotation
		end
		if motionScale ~= 1 then pose = pose + Vector3.new(pose.X, pose.Y, pose.Z) * (motionScale - 1) end
		targets[name] = pose
	end
	return targets, snap
end

-- MicroProfiler labels (plan §3.9 budget: <= 0.6 ms for 48 mobs); no-ops outside Roblox.
local profileBegin: (string) -> () = (debug :: any).profilebegin or function(_: string) end
local profileEnd: () -> () = (debug :: any).profileend or function() end

function EnemyAnimator:Step(now: number, input: any)
	profileBegin("EnemyAnimator.Step")
	self:StepInner(now, input)
	profileEnd()
end

function EnemyAnimator:StepInner(now: number, input: any)
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
