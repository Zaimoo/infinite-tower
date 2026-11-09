--!strict
-- Authored pose keyframes in normalized clip time for all 40 Tower enemies.
-- Includes leg counter-rotation during torso leans so feet stay planted on the floor.
-- Native source, no uploaded Roblox animation asset IDs.
local Config = require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat)
local Common = require(game.ReplicatedStorage.Assets.EnemyClips.Common)
local Bipeds = require(game.ReplicatedStorage.Assets.EnemyClips.Bipeds)
local Colossi = require(game.ReplicatedStorage.Assets.EnemyClips.Colossi)
local Creatures = require(game.ReplicatedStorage.Assets.EnemyClips.Creatures)
local C: any = {}

local function rot(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function plantedPose(pitch: number?, yaw: number?, yDrop: number?, armL: number?, armR: number?, foreL: number?, foreR: number?, headPitch: number?): any
	local p = pitch or 0
	local y = yaw or 0
	local drop = yDrop or 0
	local kneeFlex = math.max(0, -drop * 38)
	return {
		Body = CFrame.new(0, drop, 0) * rot(p, y, 0),
		Head = rot(headPitch or (-p * 0.45), -y * 0.35, 0),
		ArmL = rot(armL or 0, 0, -6),
		ArmR = rot(armR or (armL or 0), 0, 6),
		ForearmL = rot(foreL or -12, 0, 0),
		ForearmR = rot(foreR or (foreL or -12), 0, 0),
		-- Counter-rotate legs against body pitch/yaw so feet stay planted on the ground
		LegL = CFrame.new(0, -drop * 0.55, 0) * rot(-p + kneeFlex * 0.5, -y * 0.4, 0),
		LegR = CFrame.new(0, -drop * 0.55, 0) * rot(-p + kneeFlex * 0.5, -y * 0.4, 0),
		KneeL = rot(-kneeFlex, 0, 0),
		KneeR = rot(-kneeFlex, 0, 0),
	}
end

local idle = {
	{ 0, plantedPose(-1, 0, 0, -4, -4, -14, -14, 1) },
	{ .5, plantedPose(1.5, 0, -.04, 3, 3, -18, -18, -1.5) },
	{ 1, plantedPose(-1, 0, 0, -4, -4, -14, -14, 1) },
}

local hit = {
	{ 0, plantedPose(0, 0, 0, 0, 0, -12, -12, 0) },
	{ .18, plantedPose(-9, 4, -.06, -18, -12, -25, -20, -10) },
	{ 1, plantedPose(0, 0, 0, 0, 0, -12, -12, 0) },
}

local death = {
	{ 0, plantedPose(0, 0, 0, 0, 0, -10, -10, 0) },
	{ .25, plantedPose(16, -6, -.45, -22, -18, -28, -24, -18) },
	{ .7, {
		Body = CFrame.new(0, -2.0, 0) * rot(68, 0, 0),
		Head = rot(15, 0, 0),
		ArmL = rot(-65, 0, -10),
		ArmR = rot(-65, 0, 10),
		ForearmL = rot(-20, 0, 0),
		ForearmR = rot(-20, 0, 0),
		LegL = rot(-25, 0, 0),
		LegR = rot(-25, 0, 0),
		KneeL = rot(-35, 0, 0),
		KneeR = rot(-35, 0, 0),
	} },
	{ 1, {
		Body = CFrame.new(0, -2.4, 0) * rot(78, 0, 0),
		Head = rot(20, 0, 0),
		ArmL = rot(-75, 0, -12),
		ArmR = rot(-75, 0, 12),
		ForearmL = rot(-15, 0, 0),
		ForearmR = rot(-15, 0, 0),
		LegL = rot(-20, 0, 0),
		LegR = rot(-20, 0, 0),
		KneeL = rot(-30, 0, 0),
		KneeR = rot(-30, 0, 0),
	} },
}

local cleave = {
	{ 0, plantedPose(0, 0, 0, -6, -6, -14, -14, 0) },
	{ .55, plantedPose(-10, -22, -.08, -35, -108, -24, -42, -8) },
	{ .76, plantedPose(-14, -30, -.12, -45, -128, -28, -48, -10) },
	{ .8, plantedPose(18, 26, -.16, 22, 38, -12, -8, 12) },
	{ 1, plantedPose(0, 0, 0, -6, -6, -14, -14, 0) },
}

local projectileCast = {
	{ 0, plantedPose(0, 0, 0, -8, -12, -16, -22, 0) },
	{ .45, plantedPose(-8, -12, -.06, -65, -95, -35, -45, -10) },
	{ .65, plantedPose(12, 10, -.1, -30, -45, -10, -15, 8) },
	{ .82, plantedPose(8, 6, -.05, -20, -30, -14, -18, 4) },
	{ 1, plantedPose(0, 0, 0, -8, -12, -16, -22, 0) },
}

local cast = {
	{ 0, plantedPose(0, 0, 0, -6, -6, -14, -14, 0) },
	{ .45, plantedPose(-6, 0, -.06, -82, -82, -32, -32, -10) },
	{ .76, plantedPose(-12, 0, -.12, -132, -132, -40, -40, -18) },
	{ .8, plantedPose(14, 0, -.18, -32, -32, -12, -12, 12) },
	{ 1, plantedPose(0, 0, 0, -6, -6, -14, -14, 0) },
}

local slam = {
	{ 0, plantedPose(0, 0, 0, -6, -6, -14, -14, 0) },
	{ .35, plantedPose(-10, 0, -.08, -100, -100, -32, -32, -12) },
	{ .72, plantedPose(-16, 0, -.14, -156, -156, -42, -42, -20) },
	{ .8, plantedPose(24, 0, -.32, 32, 32, -10, -10, 16) },
	{ .9, plantedPose(14, 0, -.16, 18, 18, -14, -14, 8) },
	{ 1, plantedPose(0, 0, 0, -6, -6, -14, -14, 0) },
}

local sweep = {
	{ 0, plantedPose(0, 0, 0, -6, -6, -14, -14, 0) },
	{ .5, plantedPose(-8, -42, -.08, -75, -85, -28, -32, -8) },
	{ .76, plantedPose(-10, -60, -.12, -92, -105, -34, -38, -12) },
	{ .8, plantedPose(12, 58, -.18, -22, -28, -12, -12, 12) },
	{ 1, plantedPose(0, 0, 0, -6, -6, -14, -14, 0) },
}

local awakening = {
	{ 0, plantedPose(20, 0, -.45, 20, 20, -24, -24, 24) },
	{ .6, plantedPose(-10, 0, -.06, -55, -55, -28, -28, -16) },
	{ 1, plantedPose(0, 0, 0, -6, -6, -14, -14, 0) },
}

local walk = {}
for i = 0, 4 do
	local phase = i / 4
	local shift = ({ 0, 1, 0, -1, 0 })[i + 1]
	local p = plantedPose(2, shift * 3, -math.abs(shift) * .05, -shift * 14, shift * 14, -16, -16, -1)
	p.LegL = CFrame.new(0, shift > 0 and .18 or 0, -shift * .28) * rot(shift * 24 - 2, 0, 0)
	p.LegR = CFrame.new(0, shift < 0 and .18 or 0, shift * .28) * rot(-shift * 24 - 2, 0, 0)
	p.KneeL = rot(math.max(0, shift) * -26, 0, 0)
	p.KneeR = rot(math.max(0, -shift) * -26, 0, 0)
	table.insert(walk, { phase, p })
end

-- Attack markers (docs/mob-reanimation-plan.md §3.3): Release = the strike starts, Impact = contact or launch.
-- EnemyAnimator maps the server's windup/impact/recovery onto them. Clips without an entry use 0.72 / 0.8.
local MARKERS: { [any]: { number } } = {
	[cleave] = { .76, .8 },
	[cast] = { .76, .8 },
	[slam] = { .72, .8 },
	[sweep] = { .76, .8 },
	[projectileCast] = { .45, .65 },
}

-- Per-enemy animation meta for EnemyAnimator: motion set, idle loop length, stride scale, fidgets.
local META: { [string]: any } = {}

for enemyId, spec in pairs(Config.Entries) do
	local family = spec.CatalogFamily or spec.RigFamily
	local isBoss = spec.Role == "BOSS"
	local isElite = spec.Role == "ELITE"
	local isProjectile = spec.Attacks[1] and spec.Attacks[1].Shape == "PROJECTILE"

	local bipedSet = Bipeds.FamilySet[family]
	if bipedSet then
		-- Biped motion sets (docs/mob-reanimation-plan.md step 5). Each move plays the style its shape maps to;
		-- "<Slot>:<Shape>" keys let two moves share a slot (Alpha Specials, support kits), and the bare slot
		-- plays the slot's first move.
		local set = Bipeds.Set(bipedSet)
		local clips: any = { Idle = set.Idle, Locomotion = set.Locomotion, HitReaction = set.HitReaction, Death = set.Death }
		for _, move in spec.Attacks do
			local frames = set.Styles[Bipeds.StyleFor(bipedSet, enemyId, move.Shape)]
			clips[move.AnimationKey .. ":" .. move.Shape] = frames
			if not clips[move.AnimationKey] then clips[move.AnimationKey] = frames end
		end
		clips.BasicAttack = clips.BasicAttack or set.Styles.Slash
		if isElite then clips.Special = clips.Special or set.Styles.Overhead end
		if isBoss then
			clips.Awakening = set.Awakening
			clips.Signature1 = clips.Signature1 or set.Styles.Stomp
			clips.Signature2 = clips.Signature2 or set.Styles.Overhead
		end
		META[enemyId] = { Set = bipedSet, IdleSeconds = set.IdleSeconds, StrideScale = set.StrideScale, Fidgets = set.Fidgets }
		C[enemyId] = clips
	elseif Colossi.Families[family] then
		-- The Colossus set (step 6): Biome Bosses and the raid bosses' stand-in rigs. Moves resolve by
		-- "<Slot>:<Shape>" like the bipeds, so a raid boss's two Signature2 moves differ.
		local set = Colossi.Set()
		local clips: any = { Idle = set.Idle, Locomotion = set.Locomotion, HitReaction = set.HitReaction, Death = set.Death, Awakening = set.Awakening }
		for _, move in spec.Attacks do
			local frames = set.Styles[Colossi.StyleFor(move.Shape)]
			clips[move.AnimationKey .. ":" .. move.Shape] = frames
			if not clips[move.AnimationKey] then clips[move.AnimationKey] = frames end
		end
		clips.BasicAttack = clips.BasicAttack or set.Styles.Sweep
		clips.Signature1 = clips.Signature1 or set.Styles.Quake
		clips.Signature2 = clips.Signature2 or set.Styles.Pound
		META[enemyId] = { Set = "Colossus", IdleSeconds = set.IdleSeconds, StrideScale = set.StrideScale, Fidgets = set.Fidgets }
		C[enemyId] = clips
	elseif Creatures.FamilySet[family] or Creatures.FamilySet[spec.RigFamily] then
		-- Creature sets (step 7): Quadruped, Avian, Serpent, Multileg. Moves resolve by "<Slot>:<Shape>".
		local setName = Creatures.FamilySet[family] or Creatures.FamilySet[spec.RigFamily]
		local set = Creatures.Set(setName)
		local clips: any = { Idle = set.Idle, Locomotion = set.Locomotion, HitReaction = set.HitReaction, Death = set.Death }
		for _, move in spec.Attacks do
			local frames = set.Styles[Creatures.StyleFor(setName, family, enemyId, move.Shape)]
			clips[move.AnimationKey .. ":" .. move.Shape] = frames
			if not clips[move.AnimationKey] then clips[move.AnimationKey] = frames end
		end
		clips.BasicAttack = clips.BasicAttack or set.Styles[set.ByShape.ARC]
		if isElite then clips.Special = clips.Special or set.Styles[set.ByShape.TARGET_DISC] end
		if isBoss then
			clips.Awakening = set.Awakening or awakening
			clips.Signature1 = clips.Signature1 or set.Styles[set.ByShape.SELF_DISC]
			clips.Signature2 = clips.Signature2 or set.Styles[set.ByShape.TARGET_DISC]
		end
		META[enemyId] = { Set = setName, IdleSeconds = set.IdleSeconds, StrideScale = set.StrideScale, Fidgets = set.Fidgets }
		C[enemyId] = clips
	else
		local clips: any = {
			Idle = idle,
			Locomotion = walk,
			BasicAttack = if isBoss then slam elseif spec.Support then cast elseif isProjectile then projectileCast else cleave,
			HitReaction = hit,
			Death = death,
		}
		if isElite then
			clips.Special = cast
		elseif isBoss then
			clips.Awakening = awakening
			clips.Signature1 = slam
			clips.Signature2 = sweep
		end
		C[enemyId] = clips
	end
end

-- Which shared clip group an enemy uses, for size scaling and stride (EnemyAnimator.Metrics).
local GROUPS: { [string]: string } = {}
for enemyId, spec in pairs(Config.Entries) do
	local family = spec.CatalogFamily or spec.RigFamily
	GROUPS[enemyId] = if family == "CRAWLER" or family == "INSECT" or family == "CRUSTACEAN" or family == "SCORPION" or spec.RigFamily == "SIX_LEGGED_CRAWLER" then "MULTILEG"
		elseif family == "QUADRUPED" then "QUADRUPED"
		elseif family == "AVIAN" or family == "GIANT_AVIAN" then "AVIAN"
		elseif family == "SERPENT" then "SERPENT"
		else "BIPED"
end
function C.GroupFor(enemyId: string): string
	return GROUPS[enemyId] or "BIPED"
end

function C.MetaFor(enemyId: string?): any
	return enemyId and META[enemyId]
end

function C.MarkersFor(frames: any): (number, number)
	local m = MARKERS[frames] or Common.Markers[frames]
	if m then return m[1], m[2] end
	return .72, .8
end

function C.Sample(frames: any, t: number): any
	t = math.clamp(t, 0, 1)
	local a, b = frames[1], frames[#frames]
	for i = 2, #frames do
		if t <= frames[i][1] then
			a = frames[i - 1]
			b = frames[i]
			break
		end
	end
	local alpha = math.clamp((t - a[1]) / math.max(.0001, b[1] - a[1]), 0, 1)
	alpha = alpha * alpha * (3 - 2 * alpha)
	local result = {}
	local keys = {}
	for key in pairs(a[2]) do keys[key] = true end
	for key in pairs(b[2]) do keys[key] = true end
	for key in pairs(keys) do
		result[key] = (a[2][key] or CFrame.identity):Lerp(b[2][key] or CFrame.identity, alpha)
	end
	return result
end

return C
