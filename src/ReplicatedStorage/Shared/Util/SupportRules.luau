--!strict
-- Pure rules for support Regulars (Phase D). No Roblox services, so specs can run it directly.
-- A support never fights while an ally stands: it stays behind the line and casts one kit.
--   MEND  heals the ally with the lowest HP%.
--   WARD  shields the ally nearest the squad.
--   ROUSE gives every ally around it more ATK and move speed.
-- Casts are interruptible: a hit during the windup cancels them (TowerEncounterRuntime).
local SupportRules = {}

export type Kit = {
	Shape: string, -- ALLY_BEAM (one ally) or ALLY_AURA (allies around the caster)
	Windup: number,
	Recovery: number,
	Range: number,
	Radius: number,
	Cooldown: number,
	HealFraction: number?,
	ShieldFraction: number?,
	ShieldSeconds: number?,
	AtkBonus: number?,
	SpeedBonus: number?,
	BuffSeconds: number?,
}

SupportRules.Kits = table.freeze({
	MEND = table.freeze({ Shape = "ALLY_BEAM", Windup = 2.0, Recovery = 0.8, Range = 30, Radius = 40, Cooldown = 7, HealFraction = 0.12 }),
	WARD = table.freeze({ Shape = "ALLY_BEAM", Windup = 1.4, Recovery = 0.6, Range = 26, Radius = 40, Cooldown = 9, ShieldFraction = 0.15, ShieldSeconds = 6 }),
	ROUSE = table.freeze({ Shape = "ALLY_AURA", Windup = 1.2, Recovery = 0.6, Range = 18, Radius = 18, Cooldown = 10, AtkBonus = 0.25, SpeedBonus = 0.2, BuffSeconds = 5 }),
}) :: { [string]: Kit }

SupportRules.HpScale = 0.7 -- of a Regular's MaxHP
SupportRules.AtkScale = 0.5 -- of a Regular's ATK (its weak bolt, used only when no ally is left)
SupportRules.KiteGap = 21 -- studs it keeps behind its anchor ally, away from the squad
SupportRules.AllyRange = 40 -- allies further away are ignored
SupportRules.InterruptLockout = 2 -- seconds before an interrupted support may cast again

type Point = { X: number, Z: number }
-- Plain mob view: anything with these fields (the runtime's mob records qualify).
export type Unit = { Position: Point, CurrentHP: number, MaxHP: number, ShieldUntil: number?, State: string? }

local function flatDistance(a: Point, b: Point): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- Who a support casts on right now, or nil to hold. `allies` excludes the caster; `squad` is the
-- positions of heroes it can see. ROUSE returns the caster itself (the aura is centred on it).
function SupportRules.PickTarget(kitName: string, caster: Unit, allies: { Unit }, squad: { Point }, now: number): Unit?
	local kit = SupportRules.Kits[kitName]
	if not kit then return nil end
	if kitName == "MEND" then
		local best: Unit? = nil
		local bestFraction = 0.95 -- only allies that are actually hurt
		for _, ally in allies do
			local fraction = ally.CurrentHP / math.max(1, ally.MaxHP)
			if ally.CurrentHP > 0 and fraction < bestFraction and flatDistance(caster.Position, ally.Position) <= kit.Range then
				best, bestFraction = ally, fraction
			end
		end
		return best
	elseif kitName == "WARD" then
		local best: Unit? = nil
		local bestDistance = math.huge
		for _, ally in allies do
			if ally.CurrentHP > 0 and (ally.ShieldUntil or 0) <= now and flatDistance(caster.Position, ally.Position) <= kit.Range then
				for _, hero in squad do
					local d = flatDistance(ally.Position, hero)
					if d < bestDistance then
						best, bestDistance = ally, d
					end
				end
			end
		end
		return best
	end
	-- ROUSE: worth casting once an ally within the aura is fighting.
	for _, ally in allies do
		if ally.CurrentHP > 0 and flatDistance(caster.Position, ally.Position) <= kit.Radius
			and (ally.State == "CHASE" or ally.State == "WINDUP" or ally.State == "RECOVERY") then
			return caster
		end
	end
	return nil
end

-- Where a support stands: KiteGap behind its anchor ally, on the side away from the nearest hero.
function SupportRules.KitePoint(anchor: Point, hero: Point): Point
	local dx, dz = anchor.X - hero.X, anchor.Z - hero.Z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.01 then
		dx, dz, length = 0, 1, 1
	end
	return { X = anchor.X + dx / length * SupportRules.KiteGap, Z = anchor.Z + dz / length * SupportRules.KiteGap }
end

-- Mutates `target` with the kit's effect. Returns the healed amount (0 for other kits).
function SupportRules.Apply(kitName: string, target: any, now: number): number
	local kit = SupportRules.Kits[kitName]
	if kitName == "MEND" then
		local before = target.CurrentHP
		target.CurrentHP = math.min(target.MaxHP, target.CurrentHP + math.round(target.MaxHP * (kit.HealFraction :: number)))
		return target.CurrentHP - before
	elseif kitName == "WARD" then
		target.Shield = math.round(target.MaxHP * (kit.ShieldFraction :: number))
		target.ShieldUntil = now + (kit.ShieldSeconds :: number)
	elseif kitName == "ROUSE" then
		target.BuffUntil = now + (kit.BuffSeconds :: number)
		target.BuffAtk = kit.AtkBonus
		target.BuffSpeed = kit.SpeedBonus
	end
	return 0
end

-- Damage left after a WARD shield soaks what it can. Mutates the shield.
function SupportRules.Absorb(target: any, damage: number, now: number): number
	local shield = target.Shield or 0
	if shield <= 0 or (target.ShieldUntil or 0) <= now then
		return damage
	end
	local soaked = math.min(shield, damage)
	target.Shield = shield - soaked
	return damage - soaked
end

function SupportRules.Shielded(target: any, now: number): boolean
	return (target.Shield or 0) > 0 and (target.ShieldUntil or 0) > now
end

function SupportRules.Roused(target: any, now: number): boolean
	return (target.BuffUntil or 0) > now
end

function SupportRules.AtkMultiplier(target: any, now: number): number
	return if SupportRules.Roused(target, now) then 1 + (target.BuffAtk or 0) else 1
end

function SupportRules.SpeedMultiplier(target: any, now: number): number
	return if SupportRules.Roused(target, now) then 1 + (target.BuffSpeed or 0) else 1
end

-- Clears shields and buffs (on respawn).
function SupportRules.Reset(target: any)
	target.Shield, target.ShieldUntil = nil, nil
	target.BuffUntil, target.BuffAtk, target.BuffSpeed = nil, nil, nil
end

return table.freeze(SupportRules)
