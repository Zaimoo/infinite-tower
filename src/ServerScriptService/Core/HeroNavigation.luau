--!strict
-- Server-side collision and waypoint following for lightweight heroes (no Humanoids).
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local Navigation = {}
local states: {[any]: any} = setmetatable({}, {__mode = "k"}) :: any
local computing = 0
local RADIUS, HEIGHT, STEP_UP, MAX_DROP = 1.2, 4.8, 2.2, 3.5
local exclusions: {Instance} = {}

local function refreshExclusions()
	local list: {Instance} = {}
	for _, name in {"ClientVisualEntities", "PhysicalLoot", "PhysicalRelics", "ModelViewer"} do
		local f = Workspace:FindFirstChild(name)
		if f then table.insert(list, f) end
	end
	for _, p in Players:GetPlayers() do if p.Character then table.insert(list, p.Character) end end
	exclusions = list
end
refreshExclusions()
local function trackPlayer(player: Player)
	player.CharacterAdded:Connect(function() task.defer(refreshExclusions) end)
	player.CharacterRemoving:Connect(function() task.defer(refreshExclusions) end)
end
for _, player in Players:GetPlayers() do trackPlayer(player) end
Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function() task.defer(refreshExclusions) end)
Workspace.ChildAdded:Connect(refreshExclusions)

local function parameters(group: string?): RaycastParams
	local p = RaycastParams.new()
	p.FilterType, p.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, exclusions
	p.RespectCanCollide, p.IgnoreWater = true, true
	p.CollisionGroup = group or "Default"
	return p
end

function Navigation.Ground(position: Vector3, group: string?, up: number?, down: number?): Vector3?
	local rise, drop = up or STEP_UP, down or MAX_DROP
	local hit = Workspace:Raycast(position + Vector3.new(0, rise, 0), Vector3.new(0, -(rise + drop), 0), parameters(group))
	if hit and hit.Normal.Y >= .65 then return hit.Position end
	return nil
end

local function groupFor(hero: any): string
	local owner = hero.Owner
	local char = owner and owner.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root.CollisionGroup or "Default"
end

-- Every substep must have support and enough clearance for the hero's whole body.
local function walkSegment(from: Vector3, toward: Vector3, distance: number, group: string): (Vector3, boolean)
	local flat = Vector3.new(toward.X - from.X, 0, toward.Z - from.Z)
	local length = flat.Magnitude
	if length < .02 then return from, math.abs(toward.Y - from.Y) < STEP_UP end
	local direction = flat.Unit
	local travel = math.min(distance, length)
	local steps = math.max(1, math.ceil(travel / 1.5))
	local at = from
	local params = parameters(group)
	for _ = 1, steps do
		local candidate = at + direction * (travel / steps)
		local ground = Navigation.Ground(candidate, group)
		if not ground then return at, false end
		local delta = ground - at
		-- Raise the sweep above small walkable steps; the ground probe limits step height.
		local hit = Workspace:Blockcast(CFrame.new(at + Vector3.new(0, 3.5, 0)), Vector3.new(RADIUS * 2, 2.5, RADIUS * 2), delta, params)
		if hit then return at, false end
		-- Probe the leading edges so formations cannot walk off narrow bridges into the void.
		local across = Vector3.new(-direction.Z, 0, direction.X) * (RADIUS * .8)
		local gA = Navigation.Ground(ground + across, group, 1.5, 3.5)
		local gB = Navigation.Ground(ground - across, group, 1.5, 3.5)
		if not gA and not gB then return at, false end
		at = ground
	end
	return at, true
end

local function clearRoute(from: Vector3, goal: Vector3, group: string): boolean
	local distance = (Vector3.new(goal.X, from.Y, goal.Z) - from).Magnitude
	if distance > 64 or math.abs(from.Y - goal.Y) > 16 then return false end
	local at, clear = walkSegment(from, goal, distance, group)
	return clear and (at - goal).Magnitude < 3.0
end

function Navigation.Clear(hero: any)
	states[hero] = nil
end

function Navigation.Displace(hero: any, destination: Vector3)
	local flat = Vector3.new(destination.X, hero.Position.Y, destination.Z)
	hero.Position = walkSegment(hero.Position, flat, (flat - hero.Position).Magnitude, groupFor(hero))
	Navigation.Clear(hero)
end

function Navigation.PlaceNear(masterRoot: Vector3, offset: Vector3, group: string?): Vector3
	local feet = masterRoot - Vector3.new(0, 3, 0)
	local base = Navigation.Ground(feet, group, 3, 8) or feet
	local desired = Navigation.Ground(base + offset, group)
	if desired and clearRoute(base, desired, group or "Default") then return desired end
	return base
end

local function requestPath(hero: any, state: any, goal: Vector3, now: number)
	if state.Pending or now < state.NextRequest or computing >= 6 then return end
	state.Pending, state.NextRequest = true, now + 0.35
	computing += 1
	local start = hero.Position
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2.0,
			AgentHeight = HEIGHT,
			AgentCanJump = true,
			AgentCanClimb = false,
			WaypointSpacing = 4,
			Costs = {
				BridgeRail = math.huge,
			},
		})
		local ok = pcall(function() path:ComputeAsync(start, goal) end)
		computing -= 1
		if states[hero] ~= state then path:Destroy(); return end
		state.Pending = false
		if ok and path.Status == Enum.PathStatus.Success and (hero.Position - start).Magnitude < 24 then
			state.Points, state.Index, state.Goal = path:GetWaypoints(), 2, goal
		end
		path:Destroy()
	end)
end

function Navigation.Step(hero: any, goal: Vector3, distance: number, now: number)
	local state = states[hero]
	if not state then state = {NextRequest = 0, Index = 2, BlockedCount = 0}; states[hero] = state end
	local group = groupFor(hero)
	local supportedGoal = Navigation.Ground(goal, group, 4, 16) or goal
	goal = supportedGoal
	local old = hero.Position
	local destination = goal
	if clearRoute(old, goal, group) then
		state.Points = nil
		state.Goal = nil
		state.BlockedCount = 0
	else
		if not state.Points or not state.Goal or (state.Goal - goal).Magnitude > 14 then
			requestPath(hero, state, goal, now)
		end
		local points = state.Points
		if points then
			while points[state.Index] do
				local wpPos = points[state.Index].Position
				local flatDist = Vector2.new(wpPos.X - hero.Position.X, wpPos.Z - hero.Position.Z).Magnitude
				if flatDist < 2.0 then
					state.Index += 1
				elseif flatDist < 4.0 and points[state.Index + 1] and clearRoute(hero.Position, points[state.Index + 1].Position, group) then
					state.Index += 1
				else
					break
				end
			end
			local point = points[state.Index]
			if point then
				local wpPos = point.Position
				if wpPos.Y - hero.Position.Y > STEP_UP then
					-- Waypoint is elevated on railing / obstacle. Probe laterally perpendicular to path.
					local nextPt = points[state.Index + 1] or points[state.Index]
					local tangent = nextPt.Position - wpPos
					local flatTangent = Vector2.new(tangent.X, tangent.Z)
					local dir = flatTangent.Magnitude > 0.01 and flatTangent.Unit or Vector2.new(0, 1)
					local lateral = Vector3.new(-dir.Y, 0, dir.X)
					local resolved = nil
					for _, side in {-1, 1} do
						local probePos = wpPos + lateral * (side * 3.0)
						local floor = Navigation.Ground(Vector3.new(probePos.X, hero.Position.Y + 1, probePos.Z), group, 2, 8)
						if floor and math.abs(floor.Y - hero.Position.Y) <= 2.5 then
							resolved = floor
							break
						end
					end
					destination = resolved or Vector3.new(wpPos.X, hero.Position.Y, wpPos.Z)
				else
					local floor = Navigation.Ground(wpPos, group, 2, 8)
					destination = floor or wpPos
				end
			else
				state.Points = nil
				destination = goal
			end
		else
			destination = goal
		end
	end
	local nextPosition, clear = walkSegment(old, destination, distance, group)
	if not clear then
		-- Obstacle avoidance: if moving directly toward destination is blocked by a railing/corner,
		-- try angled (30, 45, 60 deg) and lateral steers with full and fractional step lengths to slip around corners
		local flat = Vector3.new(destination.X - old.X, 0, destination.Z - old.Z)
		if flat.Magnitude > 0.05 then
			local dir = flat.Unit
			local lateral = Vector3.new(-dir.Z, 0, dir.X)
			local testAngles = {
				{ fwd = 0.866, lat = 0.5 },
				{ fwd = 0.707, lat = 0.707 },
				{ fwd = 0.500, lat = 0.866 },
				{ fwd = 0.000, lat = 1.000 },
			}
			for _, test in ipairs(testAngles) do
				for _, side in {-1, 1} do
					local steerDir = (dir * test.fwd + lateral * (side * test.lat)).Unit
					for _, frac in {1.0, 0.65} do
						local trialStep = distance * frac
						if trialStep > 0.3 then
							local trialPos, trialClear = walkSegment(old, old + steerDir * trialStep, trialStep, group)
							if (trialPos - old).Magnitude > 0.2 then
								nextPosition = trialPos
								clear = trialClear
								break
							end
						end
					end
					if clear then break end
				end
				if clear then break end
			end
		end
	end
	-- Sweep against other heroes too, so a fast tick cannot move through a squadmate.
	for other in pairs(states) do
		if other ~= hero and other.FloorId==hero.FloorId and other.RoomGeneration==hero.RoomGeneration and other.State ~= "COMA" and other.Position and math.abs(other.Position.Y - nextPosition.Y) < 3 then
			local movement = Vector3.new(nextPosition.X - old.X, 0, nextPosition.Z - old.Z)
			local offset = Vector3.new(other.Position.X - old.X, 0, other.Position.Z - old.Z)
			local function clearance(delta: Vector3): number
				local t = delta.Magnitude > .01 and math.clamp(offset:Dot(delta) / delta:Dot(delta), 0, 1) or 0
				return (offset - delta * t).Magnitude
			end
			if movement.Magnitude > .01 and clearance(movement) < 1.8 and offset:Dot(movement) > 0 and offset.Magnitude < 2.2 then
				local sideways = Vector3.new(-movement.Z, 0, movement.X).Unit * movement.Magnitude
				local yielded = old
				for _, side in {1, -1} do
					local trial, safe = walkSegment(old, old + sideways * side, movement.Magnitude, group)
					local trialDelta = Vector3.new(trial.X - old.X, 0, trial.Z - old.Z)
					if safe and clearance(trialDelta) >= math.min(1.8, offset.Magnitude - .01) then yielded = trial; break end
				end
				if yielded == old and offset.Magnitude > 1.2 then
					local stepLen = math.min(movement.Magnitude, math.max(0, offset.Magnitude - 1.2))
					if stepLen > 0.01 then
						local trial, safe = walkSegment(old, old + movement.Unit * stepLen, stepLen, group)
						if safe then yielded = trial end
					end
				end
				nextPosition = yielded
			end
		end
	end
	hero.Position = nextPosition
	local moved = nextPosition - old
	if moved.Magnitude > .02 then hero.Yaw = math.atan2(-moved.X, -moved.Z) end
	if not clear then
		state.BlockedCount = (state.BlockedCount or 0) + 1
		if state.BlockedCount >= 6 then
			state.Points = nil
			state.BlockedCount = 0
			state.NextRequest = math.min(state.NextRequest, now + .2)
		end
	else
		state.BlockedCount = 0
	end
end

function Navigation.CanAttack(from: Vector3, target: Vector3, group: string?): boolean
	if math.abs(from.Y - target.Y) > 6 then return false end
	local a, b = from + Vector3.new(0, 2.5, 0), target + Vector3.new(0, 2.5, 0)
	return Workspace:Raycast(a, b - a, parameters(group)) == nil
end

return Navigation
