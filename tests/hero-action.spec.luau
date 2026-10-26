-- tests/hero-action.spec.luau
-- Hero attack timeline (docs/projectile-skill-vfx-plan.md, Phase 1): shared timing, the server
-- impact queue, and secondary skill effects resolved at impact.
local Timing = require(nodes["ReplicatedStorage.Shared.Util.HeroActionTiming"])
local Skills = require(nodes["ReplicatedStorage.Shared.Config.ArchetypeCombatSkills"])
local Clips = require(nodes["ReplicatedStorage.Assets.HeroRig.HeroClips"])
local Queue = require(nodes["ServerScriptService.Combat.HeroImpactQueue"])
local Effects = require(nodes["ServerScriptService.Combat.HeroSkillEffects"])

local function near(a: number, b: number, msg: string)
	assert(math.abs(a - b) < 1e-6, msg .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

-- Timing ---------------------------------------------------------------------------------
do
	local marksman = Skills.GetSkillProfile("hero_jenna", "Marksman")

	-- Bow basic: cast = interval, release at the clip's 0.72 marker, arrow at 95 studs/s.
	local t = Timing.For("hero_jenna", "BOW", "BASIC", marksman.Basic, 0.8, 19)
	near(t.CastSeconds, 0.8, "bow basic cast")
	near(t.ReleaseSeconds, 0.8 * 0.72, "bow basic release")
	near(t.TravelSeconds, 0.2, "bow basic travel")
	near(t.ImpactSeconds, 0.8 * 0.72 + 0.2, "bow basic impact")

	-- Cast stays inside the animation bounds.
	near(Timing.CastSeconds(marksman.Basic, 0.1), Timing.MIN_CAST, "fast hero cast clamps up")
	near(Timing.CastSeconds(marksman.Basic, 3), Timing.MAX_CAST, "slow hero cast clamps down")

	-- Skill holds the hero for at least its CastSeconds and lands as a 4-tick area.
	local skill = Timing.For("hero_jenna", "BOW", "SKILL", marksman.Skill, 0.8, 20)
	near(skill.CastSeconds, 1.1, "marksman skill cast lock")
	near(skill.TravelSeconds, 0.35, "marksman skill flare travel ignores distance")
	local ticks, gap = Timing.Ticks(marksman.Skill)
	assert(ticks == 4 and gap == 0.15, "marksman skill ticks")
	local basicTicks, basicGap = Timing.Ticks(marksman.Basic)
	assert(basicTicks == 1 and basicGap == 0, "basic is a single tick")

	-- Melee has no travel; projectiles never fly longer than MAX_TRAVEL.
	local vanguard = Skills.GetSkillProfile("Vanguard")
	near(Timing.TravelSeconds(vanguard.Basic, 50), 0, "melee travel")
	near(Timing.TravelSeconds(marksman.Basic, 1000), Timing.MAX_TRAVEL, "travel clamp")

	-- An unknown weapon falls back to the unarmed clip's marker.
	near(Timing.ReleaseFraction("hero_none", "NOT_A_WEAPON", "BASIC"), 0.35, "unarmed fallback release")

	-- Every weapon's attack clips carry a Release marker inside the clip; bows re-nock after it.
	for _, weaponType in Clips.WEAPON_TYPES do
		for tier, state in Timing.TIER_STATES do
			local clip = Clips.Get(nil, weaponType, state)
			local release = Clips.Marker(clip, "Release", -1)
			assert(release > 0 and release < 1, weaponType .. " " .. tier .. " has a Release marker")
			if weaponType == "BOW" then
				assert(Clips.Marker(clip, "Nock", -1) > release, "bow " .. tier .. " nocks after release")
			end
		end
	end
end

-- Impact queue ------------------------------------------------------------------------------
do
	local q = Queue.new()
	local resolved = {}
	local releaseChecks = 0
	local function canRelease(impact)
		releaseChecks += 1
		return impact.Allowed
	end
	local function resolve(impact, tick)
		table.insert(resolved, impact.Name .. tick)
	end

	q:Push({ Name = "a", ReleaseAt = 1, At = 1.5, Ticks = 1, TickSeconds = 0, Tick = 0, Released = false, Allowed = true })
	q:Push({ Name = "b", ReleaseAt = 1, At = 1.2, Ticks = 1, TickSeconds = 0, Tick = 0, Released = false, Allowed = false })
	q:Push({ Name = "r", ReleaseAt = 1, At = 1.3, Ticks = 4, TickSeconds = 0.15, Tick = 0, Released = false, Allowed = true })

	q:Drain(0.5, canRelease, resolve)
	assert(#resolved == 0 and releaseChecks == 0 and q:Count() == 3, "nothing happens before release")

	q:Drain(1.0, canRelease, resolve)
	assert(#resolved == 0 and q:Count() == 2, "a blocked release drops the attack")

	q:Drain(1.3, canRelease, resolve)
	assert(#resolved == 1 and resolved[1] == "r1", "first rain tick lands at impact")

	-- A late drain catches up on every tick that came due.
	q:Drain(1.62, canRelease, resolve)
	assert(table.concat(resolved, ",") == "r1,a1,r2,r3", "late drain resolves due ticks: " .. table.concat(resolved, ","))
	assert(q:Count() == 1, "the rain still has a tick to go")
	q:Drain(1.8, canRelease, resolve)
	assert(resolved[5] == "r4" and q:Count() == 0, "finished impacts leave the queue")
	assert(releaseChecks == 3, "release is checked once per attack")
end

-- Skill effects ---------------------------------------------------------------------------
do
	local owner = { UserId = 7 }
	local function mob(netId: number, x: number, room: number?)
		return {
			NetId = netId, IsAlive = true, FloorId = 1, RoomGeneration = room or 1,
			Position = Vector3.new(x, 0, 0), CurrentHP = 10000, MaxHP = 10000, DamageLedger = {},
		}
	end
	local function context(mobs)
		local broadcasts = {}
		return {
			Mobs = mobs,
			Squad = nil,
			Now = 100,
			Same = function(a, b) return a.FloorId == b.FloorId and a.RoomGeneration == b.RoomGeneration end,
			IsCombatSafe = function() return false end,
			Broadcast = function(_, kind, _, amount) table.insert(broadcasts, { kind, amount }) end,
			HandleMobDeath = function() end,
		}, broadcasts
	end

	-- Marksman rain: splash split across 4 ticks, defense shred applied once.
	local primary, other, farAway, otherRoom = mob(1, 0), mob(2, 5), mob(3, 40), mob(4, 3, 2)
	local mobs = { primary, other, farAway, otherRoom }
	local ctx = context(mobs)
	local attacker = { NetId = 50, Owner = owner, Archetype = "Marksman", Position = Vector3.new(-20, 0, 0), MaxHP = 100 }
	local profile = Skills.GetSkillProfile("hero_jenna", "Marksman")
	local impact = { FloorId = 1, RoomGeneration = 1, Atk = 100, DamageMult = profile.Skill.DamageMultiplier, Ticks = 4, Origin = attacker.Position }
	local perTick = math.round(100 * profile.Skill.DamageMultiplier * 0.5 / 4)
	for tick = 1, 4 do
		if tick == 2 then
			other.DefenseShredUntil = nil
		end
		Effects.Resolve(ctx, { Impact = impact, Attacker = attacker, Profile = profile, Tier = "SKILL", Tick = tick, Primary = primary, Center = Vector3.new(0, 0, 0) })
	end
	assert(other.CurrentHP == 10000 - perTick * 4, "splash target takes every tick")
	assert(other.DefenseShredUntil == nil, "defense shred applies on the first tick only")
	assert(primary.CurrentHP == 10000 and primary.DefenseShredUntil == 105, "primary is shredded but left to the primary hit")
	assert(farAway.CurrentHP == 10000 and otherRoom.CurrentHP == 10000, "out of radius and other rooms are untouched")

	-- Marksman pierce: exactly one other mob within the line range from the archer.
	local a, b, c = mob(11, 0), mob(12, -5), mob(13, -6)
	ctx = context({ a, b, c })
	impact = { FloorId = 1, RoomGeneration = 1, Atk = 100, DamageMult = profile.Special.DamageMultiplier, Ticks = 1, Origin = attacker.Position }
	local bonus = Effects.Resolve(ctx, { Impact = impact, Attacker = attacker, Profile = profile, Tier = "SPECIAL", Tick = 1, Primary = a, Center = a.Position })
	assert(bonus == 1, "pierce adds no primary bonus")
	local pierced = (if b.CurrentHP < 10000 then 1 else 0) + (if c.CurrentHP < 10000 then 1 else 0)
	assert(pierced == 1 and a.CurrentHP == 10000, "pierce hits one other mob")

	-- Vanguard ultimate: barrier and taunt once, on the first tick.
	local vanguard = { NetId = 60, Owner = owner, Archetype = "Vanguard", Position = Vector3.new(0, 0, 0), MaxHP = 1000 }
	local taunted = mob(21, 10)
	ctx = context({ taunted })
	local vProfile = Skills.GetSkillProfile("Vanguard")
	impact = { FloorId = 1, RoomGeneration = 1, Atk = 100, DamageMult = vProfile.Skill.DamageMultiplier, Ticks = 1, Origin = vanguard.Position }
	Effects.Resolve(ctx, { Impact = impact, Attacker = vanguard, Profile = vProfile, Tier = "SKILL", Tick = 1, Center = vanguard.Position })
	assert(vanguard.BarrierHP == math.round(1000 * (vProfile.Skill.BarrierPercent or 0.40)), "vanguard barrier")
	assert(taunted.TargetNetId == 60, "vanguard taunt")
end

print("hero-action.spec: ok")
