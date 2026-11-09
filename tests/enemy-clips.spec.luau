-- EnemyAnimator and the tower enemy clips (docs/mob-reanimation-plan.md §6, step 1). Bundled by run.ps1;
-- `nodes` and `require` come from the shim.
local C = require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local Clips = require(nodes["ReplicatedStorage.Assets.TowerEnemyClips"])
local Anim = require(nodes["ReplicatedStorage.Assets.EnemyAnimator"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end
local function sameCF(a: any, b: any): boolean
	return near(a.X, b.X) and near(a.Y, b.Y) and near(a.Z, b.Z) and near(a.rx, b.rx) and near(a.ry, b.ry) and near(a.rz, b.rz)
end

local ATTACK_SLOTS = { "BasicAttack", "Special", "Signature1", "Signature2" }

local function firstEnemy(pred: (any) -> boolean): string
	local ids = {}
	for id in C.Entries do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ids do
		if pred(C.Entries[id]) then return id end
	end
	error("no enemy matched")
end

local function fakeRig(enemyId: string): any
	local joints = {}
	for _, name in { "Body", "Head", "ArmL", "ArmR", "ForearmL", "ForearmR", "LegL", "LegR", "KneeL", "KneeR" } do
		joints[name] = { Motor = {}, Bind = CFrame.identity }
	end
	return { EnemyId = enemyId, Spec = C.Get(enemyId), Joints = joints }
end

test("Every enemy has every required slot", function()
	for id, spec in C.Entries do
		local set = assert(Clips[id], "no clips for " .. id)
		for _, slot in spec.RequiredSlots or {} do
			assert(set[slot], id .. " is missing " .. slot)
		end
		for _, move in spec.Attacks or {} do
			assert(set[move.AnimationKey] or set.BasicAttack, id .. ": no clip for " .. tostring(move.AnimationKey))
		end
	end
end)

test("Compiled sampling matches TowerEnemyClips.Sample and reuses its table", function()
	local out = {}
	for id in C.Entries do
		for slot, frames in Clips[id] do
			for _, t in { 0, 0.13, 0.5, 0.79, 0.8, 1 } do
				local want = Clips.Sample(frames, t)
				local got = Anim.SampleInto(frames, t, out)
				assert(got == out, "SampleInto must return the table it was given")
				for joint, cf in want do
					assert(got[joint] and sameCF(got[joint], cf), id .. "/" .. slot .. "/" .. joint .. " differs at t=" .. t)
				end
				for joint in got do assert(want[joint], id .. "/" .. slot .. ": stale joint " .. joint) end
			end
		end
	end
end)

test("Attack clips have ordered markers inside the clip", function()
	for id in C.Entries do
		for slot, frames in Clips[id] do
			local base = string.match(slot, "^([^:]+)")
			if table.find(ATTACK_SLOTS, base) then
				local release, impact = Clips.MarkersFor(frames)
				assert(release > 0 and release <= impact and impact < 1, id .. "/" .. slot .. " markers out of order")
				assert(frames[1][1] == 0 and frames[#frames][1] == 1, id .. "/" .. slot .. " must span 0..1")
			end
		end
	end
end)

test("Action time follows the server's windup, impact and recovery", function()
	local function check(w: number, i: number, r: number)
		local release, impact = 0.76, 0.8
		local lead = math.min(w * Anim.STRIKE_LEAD, Anim.STRIKE_LEAD_MAX)
		assert(near(Anim.ActionPhase(0, w, i, r, release, impact), 0))
		assert(near(Anim.ActionPhase(w - lead, w, i, r, release, impact), release, 1e-4), "release not at the strike start")
		assert(near(Anim.ActionPhase(w, w, i, r, release, impact), impact, 1e-4), "impact mark not at the windup end")
		assert(near(Anim.ActionPhase((w + i) / 2, w, i, r, release, impact), impact), "follow-through must hold the impact pose")
		assert(near(Anim.ActionPhase(i + r, w, i, r, release, impact), 1))
		local prev = -1
		for k = 0, 200 do
			local p = Anim.ActionPhase((i + r) * k / 200, w, i, r, release, impact)
			assert(p >= prev - 1e-9 and p >= 0 and p <= 1, "phase must rise within 0..1")
			prev = p
		end
	end
	check(0.9, 0.9, 0.8) -- melee
	check(1.0, 1.4, 0.9) -- projectile: 0.4 s flight
	check(0.3, 0.3, 0.2) -- quick bite
end)

test("Walk and idle switch with hysteresis, not every frame", function()
	local id = firstEnemy(function(s) return s.Role == "REGULAR" end)
	local a = Anim.new(fakeRig(id), 7)
	local input: any = { Moved = 0 }
	local now = 0
	a:Step(now, input)
	for _ = 1, 30 do -- 0.5 s at 6 studs/s
		now += 1 / 60
		input.Moved = 0.1
		a:Step(now, input)
	end
	assert(a.Moving, "should be walking")
	now += 1 / 60
	input.Moved = 0
	a:Step(now, input)
	assert(a.Moving, "one still frame must not stop the walk")
	for _ = 1, 60 do
		now += 1 / 60
		a:Step(now, input)
	end
	assert(not a.Moving, "should be idle after a second standing still")
end)

test("Idle is desynced per seed and stable for the same seed", function()
	local id = firstEnemy(function(s) return s.Role == "REGULAR" end)
	local a, b, c = Anim.new(fakeRig(id), 101), Anim.new(fakeRig(id), 202), Anim.new(fakeRig(id), 101)
	assert(a.IdleOffset ~= b.IdleOffset, "different seeds should give different idle phases")
	assert(a.IdleOffset == c.IdleOffset and a.IdleRate == c.IdleRate, "the same seed should give the same idle")
	assert(a.IdleRate >= 0.9 and a.IdleRate <= 1.1)
end)

test("Step writes Transform on every joint and a hit flinch starts from the current pose", function()
	local id = firstEnemy(function(s) return s.Role == "REGULAR" and (s.CatalogFamily or s.RigFamily) ~= "CRAWLER" end)
	local rig = fakeRig(id)
	local a = Anim.new(rig, 3)
	local input: any = { Moved = 0 }
	local base = {}
	for name, cf in a:Evaluate(10, input, 0) do base[name] = cf end
	local b = Anim.new(rig, 3)
	input.HitAt = 10
	for name, cf in b:Evaluate(10, input, 0) do
		assert(sameCF(cf, base[name]), "hit at phase 0 must not move " .. name)
	end
	b:Step(10, input)
	for name, joint in rig.Joints do
		assert(joint.Motor.Transform, name .. " has no Transform")
	end
end)

test("Death overrides the action and the walk", function()
	local id = firstEnemy(function(s) return s.Role == "REGULAR" end)
	local rig = fakeRig(id)
	local a = Anim.new(rig, 5)
	local now = 20
	local input: any = { Moved = 0, DeathAt = now - 1.6, Action = { AnimationKey = "BasicAttack", StartServerTime = now - 0.3, WindupSeconds = 0.6, ImpactOffsetSeconds = 0.6, RecoverySeconds = 0.6 } }
	local targets = a:Evaluate(now, input, 0)
	local final = Clips.Sample(Clips[id].Death, 1)
	for name, cf in targets do
		assert(sameCF(cf, final[name] or CFrame.identity), "death pose wrong on " .. name)
	end
end)

local Index = require(nodes["ReplicatedStorage.Shared.Config.TowerEnemyModelIndex"])

test("Every remodelled enemy gets size metrics, and stride grows with leg length", function()
	for id, entry in Index do
		local spec = C.Get(id)
		local m = Anim.Metrics(id, spec, entry, 1.25)
		assert(m.HipHeight > 0 and m.Height > m.HipHeight, id .. ": bad hip/height")
		assert(m.MotionScale >= 0.4 and m.MotionScale <= 4, id .. ": motion scale out of range")
		assert(m.Stride > 0, id .. ": no stride")
		local big = Anim.Metrics(id, spec, entry, 1.25 * 1.4)
		assert(big.Stride > m.Stride and big.MotionScale >= m.MotionScale, id .. ": stride must grow with size")
	end
	-- the Throne Executioner's legs cover ~7.5 studs a cycle, not the old 4.8
	local exec = Anim.Metrics("elite_throne_executioner", C.Get("elite_throne_executioner"), Index.elite_throne_executioner, 1.25)
	assert(exec.Stride > 7 and exec.Stride < 8, "executioner stride " .. exec.Stride)
end)

test("MotionScale stretches clip translations, not rotations", function()
	local id = firstEnemy(function(s) return s.Role == "REGULAR" end)
	local now = 30
	local input: any = { Moved = 0, DeathAt = now - 1.6 }
	local one, two = fakeRig(id), fakeRig(id)
	one.Metrics = { MotionScale = 1, Stride = 5 }
	two.Metrics = { MotionScale = 2, Stride = 5 }
	local a = Anim.new(one, 9):Evaluate(now, input, 0)
	local b = Anim.new(two, 9):Evaluate(now, input, 0)
	assert(math.abs(a.Body.Y) > 0.1, "death should drop the body")
	for name, cf in a do
		local d = b[name]
		assert(near(d.X, cf.X * 2) and near(d.Y, cf.Y * 2) and near(d.Z, cf.Z * 2), name .. ": translation not doubled")
		assert(near(d.rx, cf.rx) and near(d.ry, cf.ry) and near(d.rz, cf.rz), name .. ": rotation changed")
	end
end)

test("Springs settle, trail the pull and stay bounded", function()
	for motion, params in Anim.SPRINGS do
		local st: any = { X = 0, Z = 0, VX = 0, VZ = 0, Angle = 0 }
		Anim.SpringStep(st, 0, 0, 1, params)
		assert(st.X == 0 and st.Z == 0, motion .. ": moved with no pull")
		for _ = 1, 120 do Anim.SpringStep(st, 0, 40, 1 / 60, params) end
		assert(st.X > 0, motion .. ": should tilt with a forward/back pull")
		for _ = 1, 600 do Anim.SpringStep(st, -1000, 1000, 1 / 60, params) end
		assert(math.abs(st.X) <= params.Max + 1e-9 and math.abs(st.Z) <= params.Max + 1e-9, motion .. ": exceeded its limit")
		for _ = 1, 600 do Anim.SpringStep(st, 0, 0, 1 / 60, params) end
		assert(math.abs(st.X) < 0.01 and math.abs(st.Z) < 0.01, motion .. ": did not settle")
	end
end)

test("Springs trail their parent's turn and drift towards their sway", function()
	for motion, params in Anim.SPRINGS do
		local st: any = { X = 0, Z = 0, VX = 0, VZ = 0, Angle = 0 }
		Anim.SpringTurn(st, 0.2, -0.1, params)
		assert(st.X < 0 and st.Z > 0, motion .. ": should swing against the parent's turn")
		assert(math.abs(st.X) <= params.Max + 1e-9, motion .. ": turn kick exceeded its limit")
		Anim.SpringTurn(st, 50, 0, params)
		assert(st.X >= -params.Max - 1e-9, motion .. ": a teleport turn must stay clamped")
		local s2: any = { X = 0, Z = 0, VX = 0, VZ = 0, Angle = 0 }
		for _ = 1, 600 do Anim.SpringStep(s2, 0, 0, 1 / 60, params, 0.05, -0.03) end
		assert(near(s2.X, 0.05, 1e-3) and near(s2.Z, -0.03, 1e-3), motion .. ": should settle on its sway target")
	end
end)

test("Unkeyed extra joints get their spring role; clip joints keep their clips", function()
	local id = firstEnemy(function(s) return s.Role == "REGULAR" end)
	local rig = fakeRig(id)
	rig.Joints.ExtraKey = { Motor = {}, Bind = CFrame.identity }
	rig.Joints.Trophy_Crown = { Motor = {}, Bind = CFrame.identity }
	rig.JointMotion = { ExtraKey = "Spin", Trophy_Crown = "Rigid", Head = "Cloth" }
	local a = Anim.new(rig, 4)
	local input: any = { Moved = 0 }
	a:Evaluate(40, input, 0)
	local t = a:Evaluate(40.5, input, 0.5)
	assert(near(t.ExtraKey.ry, Anim.SPIN_RATE * 0.5, 1e-6), "spin joint should turn at SPIN_RATE")
	local rigid = Anim.SPRINGS.Rigid
	assert(math.abs(t.Trophy_Crown.rx) <= rigid.Sway + 1e-6 and math.abs(t.Trophy_Crown.rz) <= rigid.Sway + 1e-6 and t.Trophy_Crown.ry == 0,
		"a rigid trophy at rest only sways gently")
	local idle = Clips.Sample(Clips[id].Idle, (40.5 * a.IdleRate / a.IdleSeconds + a.IdleOffset) % 1)
	assert(sameCF(t.Head, idle.Head), "a joint the clips key ignores its motion role")
	input.Far = true
	local far = a:Evaluate(41, input, 0.5)
	assert(sameCF(far.Trophy_Crown, CFrame.identity), "far springs rest")
end)

local Bipeds = require(nodes["ReplicatedStorage.Assets.EnemyClips.Bipeds"])
local Common = require(nodes["ReplicatedStorage.Assets.EnemyClips.Common"])

test("Every biped move resolves to its own slot:shape clip with markers", function()
	local n = 0
	for id, spec in C.Entries do
		local family = spec.CatalogFamily or spec.RigFamily
		local setName = Bipeds.FamilySet[family]
		if setName then
			n += 1
			local meta = assert(Clips.MetaFor(id), id .. ": no animation meta")
			assert(meta.Set == setName and meta.IdleSeconds > 0 and meta.StrideScale > 0 and #meta.Fidgets >= 1, id .. ": bad meta")
			for _, move in spec.Attacks do
				local frames = Clips[id][move.AnimationKey .. ":" .. move.Shape]
				assert(frames, id .. ": no clip for " .. move.AnimationKey .. ":" .. move.Shape)
				local release, impact = Clips.MarkersFor(frames)
				assert(Common.Markers[frames], id .. ": " .. move.Shape .. " style has no authored markers")
				assert(release < 1 and impact < 1)
			end
		end
	end
	assert(n >= 30, "expected the biped families to cover most enemies, got " .. n)
end)

test("Moves that share a slot play different styles", function()
	local alpha = Clips.alpha_glacier_knight
	assert(alpha["Special:TARGET_DISC"] ~= alpha["Special:SELF_DISC"], "Alpha Specials should differ")
	local support = Clips.mob_ember_oracle
	assert(support["BasicAttack:ALLY_BEAM"] ~= support["BasicAttack:PROJECTILE"], "a support's kit and bolt should differ")
	assert(Clips.mob_rime_sentry.BasicAttack ~= Clips.mob_ash_raider.BasicAttack, "the spear thrusts, the khopesh slashes")
	assert(Clips.elite_molten_taskmaster.BasicAttack ~= Clips.elite_mycelial_brute.BasicAttack, "the chain lashes")
end)

test("Animator plays a move by slot and shape", function()
	local rig = fakeRig("alpha_glacier_knight")
	local a = Anim.new(rig, 2)
	local action: any = { AnimationKey = "Special", Shape = "SELF_DISC", StartServerTime = 50, WindupSeconds = 1.6, ImpactOffsetSeconds = 1.6, RecoverySeconds = 1.1 }
	a:Evaluate(51, { Moved = 0, Action = action }, 0)
	assert(a.CachedFrames == Clips.alpha_glacier_knight["Special:SELF_DISC"], "should pick the SELF_DISC style")
	action = { AnimationKey = "Special", StartServerTime = 50, WindupSeconds = 1.6, ImpactOffsetSeconds = 1.6, RecoverySeconds = 1.1 }
	a:Evaluate(51, { Moved = 0, Action = action }, 0)
	assert(a.CachedFrames == Clips.alpha_glacier_knight.Special, "without a shape the bare slot plays")
end)

test("Pose helper keeps planted feet under a leaning, turning body", function()
	local p = Common.pose({ lean = 20, twist = 15, tilt = 5 })
	for _, leg in { "LegL", "LegR" } do
		assert(near(p[leg].rx, -p.Body.rx) and near(p[leg].ry, -p.Body.ry) and near(p[leg].rz, -p.Body.rz), leg .. " should cancel the body")
	end
	local fallen = Common.pose({ lean = 80, planted = false })
	assert(near(fallen.LegL.rx, 0), "a falling body takes its legs with it")
	local c = Common.crouch({}, 0.3)
	assert(c.bob == -0.3 and c.legL.fwd > 20 and c.legL.fwd < 28 and near(c.kneeL, 2 * c.legL.fwd), "crouch keeps a 3.5-stud leg's feet down")
end)

test("Fidgets wait for calm, then play eased in and out on a seeded schedule", function()
	local rig = fakeRig("mob_ruin_guardian")
	local a = Anim.new(rig, 77)
	local input: any = { Moved = 0 }
	local t = 100
	a:Evaluate(t, input, 0)
	local due = a.NextFidgetAt
	assert(due >= t + Anim.FIDGET_MIN and due <= t + Anim.FIDGET_MIN + Anim.FIDGET_SPREAD, "first fidget 6–14 s out")
	-- an attack just before it is due delays it for FIDGET_CALM
	input.Action = { AnimationKey = "BasicAttack", Shape = "ARC", StartServerTime = due - 1.5, WindupSeconds = 0.68, ImpactOffsetSeconds = 0.68, RecoverySeconds = 0.68 }
	a:Evaluate(due - 0.5, input, 1 / 60)
	input.Action = nil
	a:Evaluate(due + 0.1, input, 1 / 60)
	assert(a.FidgetAt == nil, "no fidget right after an attack")
	local start = due - 0.5 + Anim.FIDGET_CALM + 0.05
	a:Evaluate(start, input, 1 / 60)
	assert(a.FidgetAt ~= nil, "fidget starts once calm")
	a:Evaluate(start + Anim.FIDGET_SECONDS + 0.01, input, 1 / 60)
	assert(a.FidgetAt == nil and a.NextFidgetAt > start + Anim.FIDGET_MIN, "then the next one is scheduled")
end)

print(string.format("enemy-clips: %d passed", passed))
