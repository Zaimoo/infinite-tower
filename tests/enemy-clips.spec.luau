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
		for _, slot in ATTACK_SLOTS do
			local frames = Clips[id][slot]
			if frames then
				local release, impact = Clips.MarkersFor(frames)
				assert(release > 0 and release <= impact and impact < 1, id .. "/" .. slot .. " markers out of order")
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

print(string.format("enemy-clips: %d passed", passed))
