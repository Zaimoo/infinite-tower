--!strict
-- Pure patrol movement (Phase E). No Roblox services, so specs can run it directly.
-- A patrol's anchor walks its route's waypoints back and forth (ping-pong); members hold a formation
-- around the anchor. Points are plain {X, Y, Z} tables in local floor coordinates.
local PatrolPath = {}

export type Point = { X: number, Y: number, Z: number }
-- Leg: the anchor walks from waypoint Leg toward waypoint Leg + Dir.
export type State = { Leg: number, Dir: number, X: number, Y: number, Z: number }

PatrolPath.Speed = 5 -- studs per second: a walk, not a run
PatrolPath.Formation = table.freeze({ -- offsets from the anchor, by member index
	table.freeze({ X = 0, Z = 0 }),
	table.freeze({ X = -6, Z = 4 }),
	table.freeze({ X = 6, Z = 4 }),
	table.freeze({ X = 0, Z = 8 }),
})

function PatrolPath.Start(route: { Point }): State
	assert(#route >= 2, "A patrol route needs two waypoints")
	return { Leg = 1, Dir = 1, X = route[1].X, Y = route[1].Y, Z = route[1].Z }
end

-- Moves the anchor `distance` studs along the route, turning back at either end. Mutates `state`.
function PatrolPath.Advance(route: { Point }, state: State, distance: number): State
	local remaining = math.max(0, distance)
	for _ = 1, 64 do
		if remaining <= 0 then break end
		local nextIndex = state.Leg + state.Dir
		if nextIndex < 1 or nextIndex > #route then
			state.Dir = -state.Dir
			nextIndex = state.Leg + state.Dir
		end
		local target = route[nextIndex]
		local dx, dy, dz = target.X - state.X, target.Y - state.Y, target.Z - state.Z
		local length = math.sqrt(dx * dx + dy * dy + dz * dz)
		if length <= remaining then
			state.X, state.Y, state.Z = target.X, target.Y, target.Z
			state.Leg = nextIndex
			remaining -= length
		else
			local f = remaining / length
			state.X, state.Y, state.Z = state.X + dx * f, state.Y + dy * f, state.Z + dz * f
			remaining = 0
		end
	end
	return state
end

-- Length of one full there-and-back loop of the route.
function PatrolPath.LoopLength(route: { Point }): number
	local total = 0
	for i = 2, #route do
		local a, b = route[i - 1], route[i]
		local dx, dy, dz = b.X - a.X, b.Y - a.Y, b.Z - a.Z
		total += math.sqrt(dx * dx + dy * dy + dz * dz)
	end
	return total * 2
end

return table.freeze(PatrolPath)
