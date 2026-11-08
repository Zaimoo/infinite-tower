--!strict
-- Raid boss mesh rigs (docs/raid-boss-plan.md §3): the Blender segments from RaidBossAssets, welded to the
-- entity root with one Motor6D per segment at its Blender pivot, plus Neon glow meshes welded to their
-- segment. Animation is procedural: Clips(bossId) returns pose keyframes keyed by segment name in the
-- TowerEnemyClips format, so EnemyAnimationController drives these rigs exactly like the tower enemies.
-- Used only when RaidBossAssets.HasMeshes(bossId); otherwise the stand-in TowerEnemyRigs rig renders.
local Assets = require(game.ReplicatedStorage.Shared.Config.RaidBossAssets)
local Config = require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat)

local R = {}

local function rot(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

-- The raid boss id for a FirstBiomeCombat enemy id, when its meshes are uploaded.
function R.BossFor(enemyId: string): string?
	local spec = Config.Get(enemyId)
	local bossId = spec and spec.Raid
	if bossId and Assets.HasMeshes(bossId) then return bossId end
	return nil
end

function R.Build(model: Model, root: BasePart, enemyId: string): any
	local spec = assert(Config.Get(enemyId), "Missing raid boss spec: " .. enemyId)
	local bossId = assert(spec.Raid, "Not a raid boss: " .. enemyId)
	local boss = assert(Assets.Bosses[bossId], "Missing raid boss assets: " .. bossId)
	local folder = Instance.new("Model")
	folder.Name = "TowerEnemyArt"
	folder.Parent = model
	-- Model space (origin = ground under the boss) -> world, through the root at RootHeight.
	local ground = root.CFrame * CFrame.new(0, -(spec.RootHeight or 0), 0)
	local rootLocal = Vector3.new(0, spec.RootHeight or 0, 0)
	local rig: any = { Joints = {}, Parts = {}, Root = root, Model = folder, Spec = spec, EnemyId = enemyId, Distance = 0, BossId = bossId }
	local parts: { [string]: BasePart } = {}
	local centres: { [string]: Vector3 } = {}
	local netId = model:GetAttribute("NetId")

	local function mesh(name: string, meshId: string, size: Vector3, centre: Vector3): MeshPart
		local p = Instance.new("MeshPart")
		p.Name = name
		p.MeshId = meshId
		p.Size = size
		p.CFrame = ground * CFrame.new(centre)
		p.Anchored = false
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p:SetAttribute("NetId", netId)
		p.Parent = folder
		table.insert(rig.Parts, p)
		return p
	end

	for _, s in boss.Segments do
		local centre = s.Centre or s.Pivot
		local p: BasePart
		if s.Mesh and s.Size then
			local m = mesh(s.Mesh, s.MeshId, s.Size, centre)
			if s.TextureId ~= "" then m.TextureID = s.TextureId end
			p = m
		else
			-- glow-only segment: an invisible carrier at the pivot so its glow meshes have a joint
			local carrier = Instance.new("Part")
			carrier.Name = s.Name
			carrier.Size = Vector3.new(0.2, 0.2, 0.2)
			carrier.Transparency = 1
			carrier.CanCollide, carrier.CanTouch, carrier.CanQuery, carrier.Massless = false, false, false, true
			carrier.CFrame = ground * CFrame.new(centre)
			carrier.Parent = folder
			p = carrier
		end
		parts[s.Name] = p
		centres[s.Name] = centre
		for _, g in s.Glow do
			local gm = mesh(g.Mesh, g.MeshId, g.Size, g.Centre)
			gm.Material = Enum.Material.Neon
			gm.Color = g.Colour
			gm.CastShadow = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = p
			w.Part1 = gm
			w.Parent = gm
		end
	end
	-- Joints at the Blender pivots. C0 is the pivot in the parent's space (the "bind"); poses rotate about it.
	for _, s in boss.Segments do
		local parentPart = if s.Parent then parts[s.Parent] else root
		local parentCentre = if s.Parent then centres[s.Parent] else rootLocal
		local j = Instance.new("Motor6D")
		j.Name = s.Name
		j.Part0 = parentPart
		j.Part1 = parts[s.Name]
		local bind = CFrame.new(s.Pivot - parentCentre)
		j.C0 = bind
		j.C1 = CFrame.new(s.Pivot - centres[s.Name])
		j.Parent = parentPart
		rig.Joints[s.Name] = { Motor = j, Bind = bind }
	end
	rig.Clips = R.Clips(bossId)
	return rig
end

-- Procedural clips --------------------------------------------------------------------------------
-- Each clip is a list of { time, { [segment] = CFrame } } keyframes, time 0..1.
local SLOTS = { "Idle", "Locomotion", "BasicAttack", "HitReaction", "Death", "Awakening", "Signature1", "Signature2" }

local function keys(n: number, fn: (number) -> { [string]: CFrame }): { any }
	local out = {}
	for i = 0, n do table.insert(out, { i / n, fn(i / n) }) end
	return out
end

local function wave(t: number, offset: number?): number
	return math.sin((t + (offset or 0)) * math.pi * 2)
end
-- 0 -> 1 -> 0 over the clip, peaking at `peak` (the impact frame is at 0.8 of attack clips)
local function swing(t: number, peak: number): number
	if t <= peak then return math.sin(t / peak * math.pi / 2) end
	return math.cos((t - peak) / (1 - peak) * math.pi / 2)
end

local function hollowKing(slot: string)
	return keys(12, function(t)
		local p: { [string]: CFrame } = {}
		if slot == "Idle" then
			p.Hips = CFrame.new(0, wave(t) * 0.15, 0)
			p.Torso = rot(wave(t) * 1.5, 0, 0)
			p.Head = rot(-wave(t) * 2, wave(t, 0.25) * 4, 0)
			p.Cape = rot(-3 + wave(t) * 2, 0, 0)
			p.UpperArmL, p.UpperArmR = rot(wave(t) * 2, 0, -3), rot(-wave(t) * 2, 0, 3)
		elseif slot == "Locomotion" then
			local s = wave(t)
			p.Hips = CFrame.new(0, math.abs(s) * 0.4, 0) * rot(0, s * 4, 0)
			p.UpperLegL, p.UpperLegR = rot(s * 26, 0, 0), rot(-s * 26, 0, 0)
			p.LowerLegL, p.LowerLegR = rot(-math.max(0, -s) * 30, 0, 0), rot(-math.max(0, s) * 30, 0, 0)
			p.UpperArmL, p.UpperArmR = rot(-s * 18, 0, -4), rot(s * 10, 0, 4)
			p.Cape = rot(-10 - math.abs(s) * 6, 0, 0)
		elseif slot == "BasicAttack" or slot == "Signature1" then
			local a = swing(t, 0.8)
			local wind = if t < 0.6 then t / 0.6 else 1 - (t - 0.6) / 0.4
			p.Torso = rot(-6 * wind + 12 * a, -25 * wind + 30 * a, 0)
			p.UpperArmR = rot(-120 * wind + 140 * a, 0, 20 * wind)
			p.LowerArmR = rot(-40 * wind, 0, 0)
			p.UpperArmL = rot(-30 * wind, 0, -10)
			p.Hips = CFrame.new(0, -0.6 * a, 0)
		elseif slot == "Signature2" then
			local a = swing(t, 0.8)
			p.Hips = CFrame.new(0, -1.5 * a + 1.0 * swing(t, 0.4), 0)
			p.UpperArmL, p.UpperArmR = rot(-150 * swing(t, 0.55) + 60 * a, 0, -10), rot(-150 * swing(t, 0.55) + 60 * a, 0, 10)
			p.Torso = rot(-10 * swing(t, 0.55) + 20 * a, 0, 0)
			p.UpperLegL, p.UpperLegR = rot(20 * a, 0, -6 * a), rot(20 * a, 0, 6 * a)
			p.LowerLegL, p.LowerLegR = rot(-30 * a, 0, 0), rot(-30 * a, 0, 0)
		elseif slot == "HitReaction" then
			local a = swing(t, 0.3)
			p.Torso = rot(-10 * a, 6 * a, 0)
			p.Head = rot(-12 * a, 0, 0)
		elseif slot == "Awakening" then
			local a = swing(t, 0.6)
			p.Torso, p.Head = rot(-14 * a, 0, 0), rot(-20 * a, 0, 0)
			p.UpperArmL, p.UpperArmR = rot(-40 * a, 0, -50 * a), rot(-40 * a, 0, 50 * a)
		elseif slot == "Death" then
			p.Hips = CFrame.new(0, -6 * t, 2 * t) * rot(-60 * t, 0, 0)
			p.UpperLegL, p.UpperLegR = rot(80 * t, 0, 0), rot(80 * t, 0, 0)
			p.LowerLegL, p.LowerLegR = rot(-90 * t, 0, 0), rot(-90 * t, 0, 0)
			p.UpperArmL, p.UpperArmR = rot(30 * t, 0, -30 * t), rot(30 * t, 0, 30 * t)
		end
		return p
	end)
end

local function thousandEyed(slot: string)
	return keys(16, function(t)
		local p: { [string]: CFrame } = {}
		local spin = if slot == "Death" then 0 else t * 360
		p.HaloInner = rot(0, spin, 0)
		p.HaloOuter = rot(0, -spin * 0.6, 0)
		p.Eyelets = rot(0, spin * 0.5, 0)
		local bob = if slot == "Death" then -t * 12 else wave(t) * 0.8
		p.Body = CFrame.new(0, bob, 0) * rot(if slot == "Death" then 50 * t else wave(t, 0.2) * 3, 0, 0)
		local curl = if slot == "BasicAttack" or slot == "Signature1" then swing(t, 0.8) else if slot == "Signature2" then swing(t, 0.6) else 0
		for i = 1, 8 do
			local ph = wave(t, i / 8)
			local a = math.rad(i * 45 + 22.5)
			-- tentacles sway outward/inward around their own tangent axis
			local axisX, axisZ = -math.sin(a), math.cos(a)
			local swayA = (ph * 10 - curl * 35) * (if slot == "Death" then 0 else 1)
			local swayB = ph * 18 - curl * 45 + (if slot == "Death" then 60 * t else 0)
			p["Tentacle" .. i .. "A"] = CFrame.fromAxisAngle(Vector3.new(axisX, 0, axisZ), math.rad(swayA))
			p["Tentacle" .. i .. "B"] = CFrame.fromAxisAngle(Vector3.new(axisX, 0, axisZ), math.rad(swayB))
		end
		if slot == "BasicAttack" or slot == "Signature1" or slot == "Signature2" then
			p.Eye = CFrame.new(0, 0, -0.8 * curl) -- the eye bulges at the impact
		elseif slot == "HitReaction" then
			p.Body = p.Body * rot(-8 * swing(t, 0.3), 0, 0)
		end
		return p
	end)
end

local function broodmother(slot: string)
	return keys(12, function(t)
		local p: { [string]: CFrame } = {}
		local gait = if slot == "Locomotion" then 1 else if slot == "Idle" then 0.15 else 0
		for side, sgn in { L = -1, R = 1 } do
			for i = 1, 4 do
				local ph = wave(t, (i % 2) * 0.5 + (if side == "L" then 0.5 else 0))
				local lift = math.max(0, ph)
				-- legs lift (about their forward axis) and swing (about vertical)
				p[`Leg{side}{i}Upper`] = rot(0, ph * 14 * gait, sgn * lift * 18 * gait)
				p[`Leg{side}{i}Lower`] = rot(0, 0, -sgn * lift * 10 * gait)
				if slot == "Death" then
					p[`Leg{side}{i}Upper`] = rot(0, 0, sgn * 35 * t)
					p[`Leg{side}{i}Lower`] = rot(0, 0, -sgn * 70 * t)
				elseif slot == "Signature2" or slot == "Awakening" then
					local a = swing(t, 0.6)
					p[`Leg{side}{i}Upper`] = rot(0, 0, sgn * 22 * a * (if i <= 2 then 1 else 0.3))
				end
			end
		end
		local strike = if slot == "BasicAttack" or slot == "Signature1" then swing(t, 0.8) else 0
		p.Thorax = CFrame.new(0, (if slot == "Death" then -4 * t else wave(t) * 0.12 * (1 + gait)), -1.5 * strike) * rot(-6 * strike + (if slot == "Signature2" then -14 * swing(t, 0.6) else 0), 0, 0)
		p.Abdomen = rot(wave(t, 0.25) * 2 + 8 * strike, 0, 0)
		p.FangL, p.FangR = rot(-25 * strike, 18 * strike, 0), rot(-25 * strike, -18 * strike, 0)
		if slot == "HitReaction" then p.Thorax = rot(8 * swing(t, 0.3), 0, 0) end
		return p
	end)
end

local function shardbound(slot: string)
	return keys(12, function(t)
		local p: { [string]: CFrame } = {}
		local s = wave(t)
		if slot == "Idle" then
			p.Torso = rot(wave(t) * 2, 0, 0)
			p.Head = rot(-wave(t) * 3, wave(t, 0.3) * 6, 0)
		elseif slot == "Locomotion" then
			p.UpperArmL, p.UpperArmR = rot(s * 22, 0, 0), rot(-s * 22, 0, 0)
			p.UpperLegL, p.UpperLegR = rot(-s * 18, 0, 0), rot(s * 18, 0, 0)
			p.Torso = CFrame.new(0, math.abs(s) * 0.5, 0) * rot(0, s * 5, 0)
		elseif slot == "BasicAttack" or slot == "Signature1" then
			local wind = if t < 0.6 then t / 0.6 else 1 - (t - 0.6) / 0.4
			local a = swing(t, 0.8)
			p.UpperArmR = rot(-110 * wind + 120 * a, 0, 15 * wind)
			p.LowerArmR = rot(-50 * wind + 30 * a, 0, 0)
			p.Torso = rot(-8 * wind + 14 * a, -15 * wind, 0)
		elseif slot == "Signature2" or slot == "Awakening" then
			local up = swing(t, 0.5)
			local a = swing(t, 0.8)
			p.UpperArmL, p.UpperArmR = rot(-140 * up + 100 * a, 0, -10), rot(-140 * up + 100 * a, 0, 10)
			p.Torso = rot(-18 * up + 26 * a, 0, 0)
			p.Pelvis = CFrame.new(0, 1.2 * up - 0.8 * a, 0)
		elseif slot == "HitReaction" then
			p.Torso = rot(-8 * swing(t, 0.3), 5 * swing(t, 0.3), 0)
		elseif slot == "Death" then
			p.Pelvis = CFrame.new(0, -5 * t, 0) * rot(0, 0, 20 * t)
			p.Torso = rot(30 * t, 0, 0)
			p.UpperArmL, p.UpperArmR = rot(40 * t, 0, -20 * t), rot(40 * t, 0, 20 * t)
		end
		return p
	end)
end

local builders: { [string]: (string) -> { any } } = {
	HOLLOW_KING = hollowKing,
	THOUSAND_EYED = thousandEyed,
	BROODMOTHER = broodmother,
	SHARDBOUND = shardbound,
}
local cache: { [string]: any } = {}

function R.Clips(bossId: string): any
	if cache[bossId] then return cache[bossId] end
	local build = assert(builders[bossId], "No raid clips for " .. bossId)
	local clips = {}
	for _, slot in SLOTS do clips[slot] = build(slot) end
	cache[bossId] = clips
	return clips
end

return R
