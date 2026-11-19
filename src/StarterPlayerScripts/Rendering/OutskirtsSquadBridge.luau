--!strict
-- StarterPlayerScripts/Rendering/OutskirtsSquadBridge.luau
-- Client-only visual bridge between AdventurerPatrolController and EntityRenderer.
-- Holds cosmetic position, facing, locomotion, hit-flash, and attack-cue overrides
-- for active squad heroes while they skirmish alongside Outskirts Guard Post defenders.

export type SkirmishMode = "ENGAGING" | "RETURNING"

export type PendingAttack = {
	ActionState: string,
	CastSeconds: number,
	Tier: number,
	Cue: any,
}

export type SquadOverride = {
	NetId: number,
	Mode: SkirmishMode,
	Plot: Model?,
	VisualPos: Vector3,
	VisualYaw: number,
	Walking: boolean,
	MoveSpeedScale: number,
	TargetMobId: number?,
	AttackCycleIdx: number,
	NextAttackAt: number,
	CastLockUntil: number,
	HitFlashUntil: number,
	PendingAttack: PendingAttack?,
}

local OutskirtsSquadBridge = {}

local overrides: { [number]: SquadOverride } = {}

-- Returns the active cosmetic skirmish override for a squad hero NetId, if any.
function OutskirtsSquadBridge.GetOverride(netId: number): SquadOverride?
	return overrides[netId]
end

-- Returns an existing override or initializes one at the hero's current world pose.
function OutskirtsSquadBridge.GetOrCreate(netId: number, initialPos: Vector3, initialYaw: number): SquadOverride
	local existing = overrides[netId]
	if existing then
		return existing
	end
	local created: SquadOverride = {
		NetId = netId,
		Mode = "ENGAGING",
		Plot = nil,
		VisualPos = initialPos,
		VisualYaw = initialYaw,
		Walking = false,
		MoveSpeedScale = 1.0,
		TargetMobId = nil,
		AttackCycleIdx = 1,
		NextAttackAt = 0,
		CastLockUntil = 0,
		HitFlashUntil = 0,
		PendingAttack = nil,
	}
	overrides[netId] = created
	return created
end

-- Removes the override for a single squad hero immediately.
function OutskirtsSquadBridge.ClearHero(netId: number)
	overrides[netId] = nil
end

-- Detaches any overrides bound to `plot` (called when a plot is parked, vacated, or removed).
function OutskirtsSquadBridge.ClearPlot(plot: Model)
	for netId, entry in pairs(overrides) do
		if entry.Plot == plot then
			overrides[netId] = nil
		end
	end
end

-- Clears every active squad skirmish override (used on Tower transitions and view resets).
function OutskirtsSquadBridge.ClearAll()
	table.clear(overrides)
end

-- Returns the backing table of active overrides for iteration by AdventurerPatrolController.
function OutskirtsSquadBridge.GetAll(): { [number]: SquadOverride }
	return overrides
end

return OutskirtsSquadBridge
