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
		-- Probe the leading edges as well so formations cannot walk off narrow bridges.
		local across = Vector3.new(-direction.Z, 0, direction.X) * (RADIUS * .8)
		if not Navigation.Ground(ground + across, group, .5, 2.5) or not Navigation.Ground(ground - across, group, .5, 2.5) then return at, false end
		at = ground
	end
	return at, true
end

local function clearRoute(from: Vector3, goal: Vector3, group: string): boolean
	local distance = (Vector3.new(goal.X, from.Y, goal.Z) - from).Magnitude
	if distance > 32 or math.abs(from.Y - goal.Y) > 7 then return false end
	local at, clear = walkSegment(from, goal, distance, group)
	return clear and (at - goal).Magnitude < 2.5
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
	if state.Pending or now < state.NextRequest or computing >= 3 then return end
	state.Pending, state.NextRequest = true, now + 1
	computing += 1
	local start = hero.Position
	task.spawn(function()
		local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = HEIGHT, AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 3})
		local ok = pcall(function() path:ComputeAsync(start, goal) end)
		computing -= 1
		if states[hero] ~= state then path:Destroy(); return end
		state.Pending = false
		if ok and path.Status == Enum.PathStatus.Success and (hero.Position - start).Magnitude < 12 then
			state.Points, state.Index, state.Goal = path:GetWaypoints(), 2, goal
		else
			state.Points = nil
		end
		path:Destroy()
	end)
end

function Navigation.Step(hero: any, goal: Vector3, distance: number, now: number)
	local state = states[hero]
	if not state then state = {NextRequest = 0, Index = 2}; states[hero] = state end
	local group = groupFor(hero)
	local supportedGoal = Navigation.Ground(goal, group, 2, 6)
	if not supportedGoal then return end
	goal = supportedGoal
	local old = hero.Position
	local destination = goal
	if clearRoute(old, goal, group) then
		state.Points = nil
	else
		if not state.Goal or (state.Goal - goal).Magnitude > 7 or not state.Points then requestPath(hero, state, goal, now) end
		local points = state.Points
		if not points then return end
		while points[state.Index] and (points[state.Index].Position - hero.Position).Magnitude < 1.3 do state.Index += 1 end
		local point = points[state.Index]
		if not point then state.Points = nil; return end
		destination = point.Position
	end
	local nextPosition, clear = walkSegment(old, destination, distance, group)
	-- Sweep against other heroes too, so a fast tick cannot move through a squadmate.
	for other in pairs(states) do
		if other ~= hero and other.FloorId==hero.FloorId and other.RoomGeneration==hero.RoomGeneration and other.State ~= "COMA" and other.Position and math.abs(other.Position.Y - nextPosition.Y) < 3 then
			local movement = Vector3.new(nextPosition.X - old.X, 0, nextPosition.Z - old.Z)
			local offset = Vector3.new(other.Position.X - old.X, 0, other.Position.Z - old.Z)
			local function clearance(delta: Vector3): number
				local t = delta.Magnitude > .01 and math.clamp(offset:Dot(delta) / delta:Dot(delta), 0, 1) or 0
				return (offset - delta * t).Magnitude
			end
			if movement.Magnitude > .01 and clearance(movement) < 2.3 and offset:Dot(movement) > 0 then
				local sideways = Vector3.new(-movement.Z, 0, movement.X).Unit * movement.Magnitude
				local yielded = old
				for _, side in {1, -1} do
					local trial, safe = walkSegment(old, old + sideways * side, movement.Magnitude, group)
					local trialDelta = Vector3.new(trial.X - old.X, 0, trial.Z - old.Z)
					if safe and clearance(trialDelta) >= math.min(2.3, offset.Magnitude - .01) then yielded = trial; break end
				end
				nextPosition = yielded
			end
		end
	end
	hero.Position = nextPosition
	local moved = nextPosition - old
	if moved.Magnitude > .02 then hero.Yaw = math.atan2(-moved.X, -moved.Z) end
	if not clear then state.Points = nil; state.NextRequest = math.min(state.NextRequest, now + .2) end
end

function Navigation.CanAttack(from: Vector3, target: Vector3, group: string?): boolean
	if math.abs(from.Y - target.Y) > 6 then return false end
	local a, b = from + Vector3.new(0, 2.5, 0), target + Vector3.new(0, 2.5, 0)
	return Workspace:Raycast(a, b - a, parameters(group)) == nil
end

return Navigation
