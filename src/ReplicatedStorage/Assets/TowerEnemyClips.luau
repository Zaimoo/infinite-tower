--!strict
-- Authored pose keyframes in normalized clip time for all 40 Tower enemies.
-- Includes leg counter-rotation during torso leans so feet stay planted on the floor.
-- Native source, no uploaded Roblox animation asset IDs.
local Config = require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat)
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

local crawl = {}
for i = 0, 4 do
	local phase = i / 4
	local shift = ({ 0, 1, 0, -1, 0 })[i + 1]
	local p: any = { Body = CFrame.new(0, -math.abs(shift) * .04, 0) * rot(0, shift * 2.5, 0) }
	for _, side in { -1, 1 } do
		for leg = 1, 3 do
			local value = shift * (leg % 2 == 0 and -1 or 1) * side
			p["Leg" .. side .. "_" .. leg] = CFrame.new(0, math.max(0, value) * .28, 0) * rot(0, value * 18, 0)
			p["Knee" .. side .. "_" .. leg] = rot(0, 0, side * math.max(0, value) * -20)
		end
	end
	table.insert(crawl, { phase, p })
end

local function crawlerPose(bodyCF: CFrame, headCF: CFrame, jawDeg: number, legPitch: number): any
	local p: any = {
		Body = bodyCF,
		Head = headCF,
		JawL = rot(0, -jawDeg, 0),
		JawR = rot(0, jawDeg, 0),
	}
	for _, side in { -1, 1 } do
		for leg = 1, 3 do
			p["Leg" .. side .. "_" .. leg] = rot(legPitch, 0, 0)
			p["Knee" .. side .. "_" .. leg] = rot(-legPitch * 0.6, 0, 0)
		end
	end
	return p
end

local bite = {
	{ 0, crawlerPose(CFrame.identity, rot(0), 0, 0) },
	{ .6, crawlerPose(CFrame.new(0, -.12, .48) * rot(-7), rot(-12), 32, 7) },
	{ .8, crawlerPose(CFrame.new(0, -.04, -.55) * rot(9), rot(14), -18, -9) },
	{ 1, crawlerPose(CFrame.identity, CFrame.identity, 0, 0) },
}

local crawlerDeath = {
	{ 0, { Body = CFrame.identity } },
	{ .4, { Body = CFrame.new(0, -.55, 0) * rot(0, 0, 22) } },
	{ 1, { Body = CFrame.new(0, -.88, 0) * rot(0, 0, 32) } },
}

local quadWalk = {}
for i = 0, 4 do
	local phase = i / 4
	local shift = ({ 0, 1, 0, -1, 0 })[i + 1]
	local p = {
		Body = CFrame.new(0, -math.abs(shift) * .06, 0) * rot(shift * 2, 0, 0),
		Head = rot(-shift * 2, 0, 0),
		ArmL = rot(shift * 22, 0, 0),
		ForearmL = rot(math.max(0, shift) * -20, 0, 0),
		ArmR = rot(-shift * 22, 0, 0),
		ForearmR = rot(math.max(0, -shift) * -20, 0, 0),
		LegL = rot(-shift * 22, 0, 0),
		KneeL = rot(math.max(0, -shift) * -20, 0, 0),
		LegR = rot(shift * 22, 0, 0),
		KneeR = rot(math.max(0, shift) * -20, 0, 0),
	}
	table.insert(quadWalk, { phase, p })
end

local quadAttack = {
	{ 0, { Body = CFrame.identity, Head = CFrame.identity, ArmL = CFrame.identity, ArmR = CFrame.identity, LegL = CFrame.identity, LegR = CFrame.identity } },
	{ .58, { Body = CFrame.new(0, -.15, .45) * rot(-12), Head = rot(-16), ArmL = rot(-22), ArmR = rot(-22), LegL = rot(14), LegR = rot(14) } },
	{ .8, { Body = CFrame.new(0, .05, -.55) * rot(14), Head = rot(20), ArmL = rot(28), ArmR = rot(28), LegL = rot(-18), LegR = rot(-18) } },
	{ 1, { Body = CFrame.identity, Head = CFrame.identity, ArmL = CFrame.identity, ArmR = CFrame.identity, LegL = CFrame.identity, LegR = CFrame.identity } },
}

local avianWalk = {}
for i = 0, 4 do
	local phase = i / 4
	local shift = ({ 0, 1, 0, -1, 0 })[i + 1]
	local flap = math.abs(shift) * 18
	local p = {
		Body = CFrame.new(0, math.abs(shift) * .08, 0) * rot(3, 0, 0),
		Head = rot(-3, 0, 0),
		ArmL = rot(0, 0, -flap),
		ForearmL = rot(0, 0, -flap * 0.6),
		ArmR = rot(0, 0, flap),
		ForearmR = rot(0, 0, flap * 0.6),
		LegL = rot(shift * 24 - 3, 0, 0),
		KneeL = rot(math.max(0, shift) * -24, 0, 0),
		LegR = rot(-shift * 24 - 3, 0, 0),
		KneeR = rot(math.max(0, -shift) * -24, 0, 0),
	}
	table.insert(avianWalk, { phase, p })
end

local avianStrike = {
	{ 0, { Body = CFrame.identity, ArmL = CFrame.identity, ArmR = CFrame.identity, Head = CFrame.identity, LegL = CFrame.identity, LegR = CFrame.identity } },
	{ .6, { Body = CFrame.new(0, .25, .3) * rot(-14), ArmL = rot(-18, 0, -38), ArmR = rot(-18, 0, 38), Head = rot(-18), LegL = rot(14), LegR = rot(14) } },
	{ .8, { Body = CFrame.new(0, -.12, -.5) * rot(18), ArmL = rot(24, 0, 18), ArmR = rot(24, 0, -18), Head = rot(22), LegL = rot(-18), LegR = rot(-18) } },
	{ 1, { Body = CFrame.identity, ArmL = CFrame.identity, ArmR = CFrame.identity, Head = CFrame.identity, LegL = CFrame.identity, LegR = CFrame.identity } },
}

local slither = {}
for i = 0, 4 do
	local phase = i / 4
	local shift = ({ 0, 1, 0, -1, 0 })[i + 1]
	table.insert(slither, { phase, {
		Body = CFrame.new(shift * .22, 0, 0) * rot(0, shift * 10, shift * 4),
		Head = rot(0, -shift * 12, -shift * 4),
		ArmL = rot(shift * 14, 0, -10),
		ArmR = rot(-shift * 14, 0, 10),
		LegL = rot(0, -shift * 16, 0),
		LegR = rot(0, -shift * 16, 0),
		KneeL = rot(0, shift * 20, 0),
		KneeR = rot(0, shift * 20, 0),
	} })
end

for enemyId, spec in pairs(Config.Entries) do
	local family = spec.CatalogFamily or spec.RigFamily
	local isBoss = spec.Role == "BOSS"
	local isElite = spec.Role == "ELITE"
	local isProjectile = spec.Attacks[1] and spec.Attacks[1].Shape == "PROJECTILE"

	if family == "CRAWLER" or family == "INSECT" or family == "CRUSTACEAN" or family == "SCORPION" or spec.RigFamily == "SIX_LEGGED_CRAWLER" then
		local clips: any = {
			Idle = idle,
			Locomotion = crawl,
			BasicAttack = bite,
			HitReaction = hit,
			Death = crawlerDeath,
		}
		if isElite then
			clips.Special = bite
		end
		C[enemyId] = clips
	elseif family == "QUADRUPED" then
		local clips: any = {
			Idle = idle,
			Locomotion = quadWalk,
			BasicAttack = quadAttack,
			HitReaction = hit,
			Death = death,
		}
		if isElite then
			clips.Special = quadAttack
		end
		C[enemyId] = clips
	elseif family == "AVIAN" or family == "GIANT_AVIAN" then
		local clips: any = {
			Idle = idle,
			Locomotion = avianWalk,
			BasicAttack = avianStrike,
			HitReaction = hit,
			Death = death,
		}
		if isBoss then
			clips.Awakening = awakening
			clips.Signature1 = avianStrike
			clips.Signature2 = sweep
		end
		C[enemyId] = clips
	elseif family == "SERPENT" then
		C[enemyId] = {
			Idle = idle,
			Locomotion = slither,
			BasicAttack = cleave,
			Awakening = awakening,
			Signature1 = slam,
			Signature2 = sweep,
			HitReaction = hit,
			Death = death,
		}
	else
		local clips: any = {
			Idle = idle,
			Locomotion = walk,
			BasicAttack = if isBoss then slam elseif isProjectile then projectileCast else cleave,
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
