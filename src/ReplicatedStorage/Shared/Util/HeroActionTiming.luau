--!strict
-- ReplicatedStorage/Shared/Util/HeroActionTiming.luau
-- When a hero's attack lands (docs/projectile-skill-vfx-plan.md, section 1). Pure: the server
-- uses it to schedule the hit, the client to time the swing and the effect, so both read the
-- same clip markers and config and cannot drift apart.
--
--   0 ............ ReleaseSeconds ............ ImpactSeconds ...... CastSeconds
--   decision       blow lands / arrow leaves   arrow arrives        animation ends

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroClips = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HeroRig"):WaitForChild("HeroClips"))

local HeroActionTiming = {}

export type Tier = "BASIC" | "SPECIAL" | "SKILL"
export type Timing = {
	CastSeconds: number,
	ReleaseSeconds: number,
	TravelSeconds: number,
	ImpactSeconds: number,
}

-- Attack animations are stretched to the attack interval within these bounds.
HeroActionTiming.MIN_CAST = 0.35
HeroActionTiming.MAX_CAST = 1.2
-- Release fraction for a clip without a Release marker.
HeroActionTiming.DEFAULT_RELEASE = 0.6
-- Longest projectile flight, so a far or stale target cannot hold a hit in the queue.
HeroActionTiming.MAX_TRAVEL = 1.0

HeroActionTiming.TIER_STATES = table.freeze({
	BASIC = "AttackBasic",
	SPECIAL = "AttackSpecial",
	SKILL = "AttackSkill",
})

-- How long the attack animation plays: the attack interval, clamped, and never shorter than a
-- Skill's CastSeconds.
function HeroActionTiming.CastSeconds(tierDef: any, interval: number): number
	local cast = math.clamp(interval, HeroActionTiming.MIN_CAST, HeroActionTiming.MAX_CAST)
	local minimum = tierDef and tierDef.CastSeconds
	if type(minimum) == "number" then
		cast = math.max(cast, minimum)
	end
	return cast
end

-- Release marker of the attack clip this hero plays for the tier.
function HeroActionTiming.ReleaseFraction(heroId: string?, weaponType: string?, tier: Tier): number
	local clip = HeroClips.Get(heroId, weaponType, HeroActionTiming.TIER_STATES[tier])
	return HeroClips.Marker(clip, "Release", HeroActionTiming.DEFAULT_RELEASE)
end

-- Release-to-impact delay for a tier definition and the attacker-to-target distance.
function HeroActionTiming.TravelSeconds(tierDef: any, distance: number): number
	local delivery = tierDef and tierDef.Delivery
	local travel = 0
	if delivery == "PROJECTILE" then
		local speed = tierDef.ProjectileSpeed
		if type(speed) == "number" and speed > 0 then
			travel = math.max(0, distance) / speed
		end
	elseif delivery == "AREA" then
		travel = if type(tierDef.TravelSeconds) == "number" then tierDef.TravelSeconds else 0
	end
	return math.clamp(travel, 0, HeroActionTiming.MAX_TRAVEL)
end

function HeroActionTiming.For(heroId: string?, weaponType: string?, tier: Tier, tierDef: any, interval: number, distance: number): Timing
	local cast = HeroActionTiming.CastSeconds(tierDef, interval)
	local release = cast * HeroActionTiming.ReleaseFraction(heroId, weaponType, tier)
	local travel = HeroActionTiming.TravelSeconds(tierDef, distance)
	return {
		CastSeconds = cast,
		ReleaseSeconds = release,
		TravelSeconds = travel,
		ImpactSeconds = release + travel,
	}
end

-- Number of damage ticks and the gap between them for a tier definition.
function HeroActionTiming.Ticks(tierDef: any): (number, number)
	local ticks = tierDef and tierDef.Ticks
	local gap = tierDef and tierDef.TickSeconds
	local count = if type(ticks) == "number" then math.max(1, math.floor(ticks)) else 1
	return count, if type(gap) == "number" and gap > 0 then gap else 0
end

return table.freeze(HeroActionTiming)
