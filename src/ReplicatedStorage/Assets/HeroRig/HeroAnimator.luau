--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroAnimator.luau
-- Client-side clip player for hero rigs (hero-rig-rebuild-plan.md, Phase 4). Drives
-- Motor6D.Transform directly; rigs carry no Animator.
--
--   local animator = HeroAnimator.new(rig, { HeroId = "hero_jenna", WeaponType = "BOW" })
--   animator:SetLocomotion("Move")          -- Idle | Move | Coma | Carry | Sleep | Labor
--   animator:PlayAction("AttackBasic", 0.8) -- AttackBasic | AttackSpecial | AttackSkill | Hit
--   animator.OnMarker = function(name, action) end -- clip markers ("Release", "Nock"), then "End"
--   animator:Step(dt)                       -- every frame
--
-- The locomotion clip loops underneath; an action plays once on top with short fades. While
-- moving, actions only drive the upper body so the legs keep walking. OnMarker fires as the
-- action passes each clip marker, and "End" when the action finishes or is replaced, so a
-- caller can always undo what a marker did (e.g. show the bow arrow again).

local HeroRigSpec = require(script.Parent:WaitForChild("HeroRigSpec"))
local HeroRigBuilder = require(script.Parent:WaitForChild("HeroRigBuilder"))
local HeroClips = require(script.Parent:WaitForChild("HeroClips"))

export type Options = { HeroId: string?, WeaponType: string? }

export type Action = {
	Clip: HeroClips.Clip,
	Started: number,
	Duration: number,
	Name: string,
	Fraction: number, -- how far markers have been fired (0..1)
	Data: any?, -- caller data passed to PlayAction (e.g. the server's attack cue)
}

local HeroAnimator = {}
HeroAnimator.__index = HeroAnimator

HeroAnimator.FADE = 0.08 -- action fade in/out, seconds
HeroAnimator.SMOOTHING = 18 -- exponential smoothing rate of Transform writes (state changes)

export type HeroAnimator = typeof(setmetatable({} :: {
	Rig: Model,
	Joints: { [string]: Motor6D },
	HeroId: string?,
	WeaponType: string,
	Locomotion: string,
	LocomotionClip: HeroClips.Clip?,
	LocomotionTime: number,
	Action: Action?,
	Clock: number,
	OnMarker: ((name: string, action: Action) -> ())?,
}, HeroAnimator))

local function toCFrame(rotation: { number }?, offset: { number }?): CFrame
	local r = rotation or { 0, 0, 0 }
	local base = if offset then CFrame.new(offset[1], offset[2], offset[3]) else CFrame.identity
	return base * CFrame.Angles(math.rad(r[1]), math.rad(r[2]), math.rad(r[3]))
end

-- Joint -> CFrame for a clip at normalized time t (0..1), interpolating between keys.
function HeroAnimator.Sample(clip: HeroClips.Clip, t: number): { [string]: CFrame }
	local keys = clip.Keys
	local a, b = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].T and t <= keys[i + 1].T then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local span = b.T - a.T
	local alpha = if span > 0 then math.clamp((t - a.T) / span, 0, 1) else 0
	-- Ease in and out between keys.
	alpha = alpha * alpha * (3 - 2 * alpha)

	local result: { [string]: CFrame } = {}
	local joints: { [string]: boolean } = {}
	for joint in a.Pose do joints[joint] = true end
	for joint in b.Pose do joints[joint] = true end
	joints.RootOffset = nil
	for joint in joints do
		local fromOffset = if joint == "Root" then a.Pose.RootOffset else nil
		local toOffset = if joint == "Root" then b.Pose.RootOffset else nil
		result[joint] = toCFrame(a.Pose[joint], fromOffset):Lerp(toCFrame(b.Pose[joint], toOffset), alpha)
	end
	-- A RootOffset without a Root rotation still moves the root.
	if not result.Root and (a.Pose.RootOffset or b.Pose.RootOffset) then
		result.Root = toCFrame(nil, a.Pose.RootOffset):Lerp(toCFrame(nil, b.Pose.RootOffset), alpha)
	end
	return result
end

function HeroAnimator.new(rig: Model, options: Options?): HeroAnimator
	local opts = options or {}
	local self = setmetatable({
		Rig = rig,
		Joints = HeroRigBuilder.GetJoints(rig),
		HeroId = opts.HeroId or (rig:GetAttribute("HeroId") :: string?),
		WeaponType = opts.WeaponType or (rig:GetAttribute("EquippedWeaponType") :: string?) or "UNARMED",
		Locomotion = "Idle",
		LocomotionClip = nil :: HeroClips.Clip?,
		LocomotionTime = 0,
		Action = nil :: Action?,
		Clock = 0,
		OnMarker = nil :: ((name: string, action: Action) -> ())?,
	}, HeroAnimator)
	self.LocomotionClip = HeroClips.Get(self.HeroId, self.WeaponType, "Idle")
	return self
end

function HeroAnimator.SetWeaponType(self: HeroAnimator, weaponType: string?)
	self.WeaponType = weaponType or "UNARMED"
	self.LocomotionClip = HeroClips.Get(self.HeroId, self.WeaponType, self.Locomotion)
end

function HeroAnimator.SetLocomotion(self: HeroAnimator, state: string)
	if state == self.Locomotion then
		return
	end
	assert(HeroClips.LOCOMOTION_STATES[state], `HeroAnimator: {state} is not a locomotion state`)
	self.Locomotion = state
	self.LocomotionClip = HeroClips.Get(self.HeroId, self.WeaponType, state)
	self.LocomotionTime = 0
end

local function fire(self: HeroAnimator, name: string, action: Action)
	local callback = self.OnMarker
	if callback then
		callback(name, action)
	end
end

-- Plays an action once. Duration defaults to the clip's own length (attacks are passed the
-- server's cast time so the swing lines up with the hit). startOffset starts the clip that many
-- seconds in, for a cue that arrived late; markers before that point are skipped.
function HeroAnimator.PlayAction(self: HeroAnimator, state: string, duration: number?, startOffset: number?, data: any?)
	local clip = HeroClips.Get(self.HeroId, self.WeaponType, state)
	if not clip then
		return
	end
	local length = math.max(0.1, duration or clip.Duration)
	local offset = math.clamp(startOffset or 0, 0, length)
	local previous = self.Action
	self.Action = {
		Clip = clip,
		Started = self.Clock - offset,
		Duration = length,
		Name = state,
		Fraction = offset / length,
		Data = data,
	}
	if previous then
		fire(self, "End", previous)
	end
end

-- Target pose for this frame (joint -> Transform), without smoothing. Exposed for tests.
function HeroAnimator.Evaluate(self: HeroAnimator): { [string]: CFrame }
	local pose: { [string]: CFrame } = {}
	local loco = self.LocomotionClip
	if loco then
		local t = if loco.Looped then (self.LocomotionTime / loco.Duration) % 1 else math.clamp(self.LocomotionTime / loco.Duration, 0, 1)
		pose = HeroAnimator.Sample(loco, t)
	end

	local action = self.Action
	if action then
		local elapsed = self.Clock - action.Started
		local t = math.clamp(elapsed / action.Duration, 0, 1)
		local weight = math.min(1, elapsed / HeroAnimator.FADE, (action.Duration - elapsed) / HeroAnimator.FADE)
		weight = math.clamp(weight, 0, 1)
		local actionPose = HeroAnimator.Sample(action.Clip, t)
		local upperOnly = self.Locomotion == "Move"
		for joint in self.Joints do
			if upperOnly and not HeroClips.UPPER_BODY[joint] then
				continue
			end
			local base = pose[joint] or CFrame.identity
			local target = actionPose[joint] or CFrame.identity
			pose[joint] = base:Lerp(target, weight)
		end
	end
	return pose
end

function HeroAnimator.Step(self: HeroAnimator, dt: number)
	self.Clock += dt
	self.LocomotionTime += dt
	local action = self.Action
	if action then
		local elapsed = self.Clock - action.Started
		local t = math.clamp(elapsed / action.Duration, 0, 1)
		local from = action.Fraction
		action.Fraction = t
		for _, name in HeroClips.MarkersBetween(action.Clip, from, t) do
			fire(self, name, action)
		end
		if elapsed >= action.Duration and self.Action == action then
			self.Action = nil
			fire(self, "End", action)
		end
	end
	local pose = self:Evaluate()
	local alpha = 1 - math.exp(-HeroAnimator.SMOOTHING * dt)
	for joint, motor in self.Joints do
		motor.Transform = motor.Transform:Lerp(pose[joint] or CFrame.identity, alpha)
	end
end

-- Applies a pose immediately with no smoothing (rigs in the simulated world).
function HeroAnimator.ApplyPose(self: HeroAnimator, pose: { [string]: CFrame })
	for joint, motor in self.Joints do
		motor.Transform = pose[joint] or CFrame.identity
	end
end

-- Poses a rig whose parts are all anchored, such as a clone in a ViewportFrame where joints
-- are never simulated: writes part CFrames down the joint chain, then moves every part held
-- by a Weld (costume pieces, socketed weapon handles) after its Part0.
function HeroAnimator.ApplyStaticPose(rig: Model, pose: { [string]: CFrame })
	local joints = HeroRigBuilder.GetJoints(rig)
	for _, spec in HeroRigSpec.JOINTS do
		local motor = joints[spec.Name]
		if motor and motor.Part0 and motor.Part1 then
			motor.Part1.CFrame = motor.Part0.CFrame * motor.C0 * (pose[spec.Name] or CFrame.identity) * motor.C1:Inverse()
		end
	end
	for _, weld in rig:GetDescendants() do
		if weld:IsA("Weld") and weld.Part0 and weld.Part1 then
			weld.Part1.CFrame = weld.Part0.CFrame * weld.C0 * weld.C1:Inverse()
		end
	end
end

return HeroAnimator
