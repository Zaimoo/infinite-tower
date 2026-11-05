local SquadMovement = require(nodes["ServerScriptService.Combat.SquadMovement"])
local Layout = require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local passed = 0
local function test(name, fn)
	fn()
	passed += 1
	print("PASS " .. name)
end
local function v3(x, y, z)
	return Vector3.new(x, y, z)
end
local function dist(a, b)
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end
local function flatDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

test("Player trail stays bounded, ignores airborne frames, and resets on teleports and lifecycle changes", function()
	local owner = {}
	SquadMovement.Reset(owner)
	local origin = v3(0, 0, 0)
	for i = 1, 80 do
		local pos = v3(i * 3, 0, 0)
		SquadMovement.UpdateMaster(owner, {
			FloorId = 18,
			RoomGeneration = 1,
			Assigned = false,
			RawRootPosition = pos + v3(0, 3, 0),
			SupportedPosition = pos,
			Origin = origin,
			Now = i * 0.1,
			DeltaTime = 0.1,
		})
	end
	local dbg = SquadMovement.DebugState(owner)
	assert(dbg.TrailCount == SquadMovement.MAX_TRAIL_POINTS, "Trail exceeded max bound")

	-- Airborne frames must not add unsupported points
	local seqBefore = dbg.Sequence
	SquadMovement.UpdateMaster(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Assigned = false,
		RawRootPosition = v3(245, 12, 0),
		SupportedPosition = nil,
		IsJumping = true,
		Origin = origin,
		Now = 9.0,
		DeltaTime = 0.1,
	})
	assert(SquadMovement.DebugState(owner).Sequence == seqBefore, "Airborne frame recorded as trail point")

	-- Cross-room or recall teleport (> 36 studs in one tick) resets trail instead of linking segment
	SquadMovement.UpdateMaster(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Assigned = false,
		RawRootPosition = v3(500, 3, 500),
		SupportedPosition = v3(500, 0, 500),
		Origin = origin,
		Now = 9.1,
		DeltaTime = 0.1,
	})
	assert(SquadMovement.DebugState(owner).TrailCount == 1, "Teleport did not reset walkable trail")

	-- Room generation change resets trail
	SquadMovement.UpdateMaster(owner, {
		FloorId = 18,
		RoomGeneration = 2,
		Assigned = false,
		RawRootPosition = v3(10, 3, 10),
		SupportedPosition = v3(10, 0, 10),
		Origin = origin,
		Now = 9.2,
		DeltaTime = 0.1,
	})
	assert(SquadMovement.DebugState(owner).RoomGeneration == 2 and SquadMovement.DebugState(owner).Sequence == 1)
	SquadMovement.Reset(owner)
	assert(SquadMovement.DebugState(owner) == nil)
end)

test("Formation slots compress inside ramp usable width and expand on platforms without collapsing", function()
	local fwd = v3(0, 0, 1)
	local anchor = v3(0, 0, 0)
	local platformGoals = {}
	local rampGoals = {}
	local rampWidth = 8.0
	local maxAllowedLat = rampWidth * 0.5 - 1.6 + 0.001

	for slot = 1, 5 do
		local pGoal = SquadMovement.ResolveSlotGoal(anchor, slot, fwd, nil, 0, function(base, off)
			return base + off
		end)
		local rGoal = SquadMovement.ResolveSlotGoal(anchor, slot, fwd, rampWidth, 0, function(base, off)
			return base + off
		end)
		platformGoals[slot] = pGoal
		rampGoals[slot] = rGoal
		assert(math.abs(rGoal.X) <= maxAllowedLat, "Slot " .. slot .. " exceeded ramp usable width")
		if math.abs(pGoal.X) > 0.1 then
			assert(math.abs(rGoal.X) < math.abs(pGoal.X), "Slot " .. slot .. " did not compress laterally on ramp")
		end
	end

	for i = 1, 5 do
		for j = i + 1, 5 do
			assert(flatDist(platformGoals[i], platformGoals[j]) >= 1.5, "Platform slots collapsed")
			assert(flatDist(rampGoals[i], rampGoals[j]) >= 1.2, "Ramp slots collapsed")
		end
	end

	-- Narrow ledge fallback: when wide lateral offsets fail support, slots still stay distinct along the centerline
	local narrowGoals = {}
	for slot = 1, 5 do
		narrowGoals[slot] = SquadMovement.ResolveSlotGoal(anchor, slot, fwd, nil, 0, function(base, off)
			if math.abs(off.X) > 1.5 then
				return base -- simulate unsupported wide shoulder
			end
			return base + off
		end)
	end
	for i = 1, 5 do
		for j = i + 1, 5 do
			assert(flatDist(narrowGoals[i], narrowGoals[j]) >= 0.5, "Fallback slots collapsed to single point")
		end
	end
end)

test("Forward lookahead follows corners, skips U-turn loops, and falls back to graph across jumped gaps", function()
	local owner = {}
	local layout = Layout.Get(3)
	local basin = layout.Platforms.Basin
	local origin = v3(0, 0, 0)

	-- Record an L-shaped corner trail on Basin
	local pts = {
		v3(basin.X - 12, basin.Y, basin.Z - 10),
		v3(basin.X - 6, basin.Y, basin.Z - 10),
		v3(basin.X, basin.Y, basin.Z - 10),
		v3(basin.X, basin.Y, basin.Z - 4),
		v3(basin.X, basin.Y, basin.Z + 2),
	}
	for idx, pt in ipairs(pts) do
		SquadMovement.UpdateMaster(owner, {
			FloorId = 18,
			RoomGeneration = 1,
			Assigned = false,
			RawRootPosition = pt + v3(0, 3, 0),
			SupportedPosition = pt,
			Origin = origin,
			Now = idx * 0.2,
			DeltaTime = 0.2,
		})
	end

	local hero = { NetId = 1, SlotIndex = 1, FloorId = 18, RoomGeneration = 1, EntityGeneration = 1, Position = pts[1], MoveSpeed = 20 }
	-- When direct shortcut to the final point is blocked by a corner, lookahead stops at the corner sample
	local blockedPlan = SquadMovement.PlanActiveFollow(owner, hero, pts[#pts], 1.2, {
		PlaceOnGround = function(base, off) return base + off end,
		CanShortcut = function(from, goal)
			return math.abs(from.Z - goal.Z) < 1.0 -- only along the first leg before the corner
		end,
	})
	assert(blockedPlan.CursorSeq <= 3, "Lookahead cut through blocked corner")

	-- U-turn: Master walks back near pts[2]; follower near pts[1] skips the far turnaround loop
	local returnPt = v3(basin.X - 9, basin.Y, basin.Z - 10)
	SquadMovement.UpdateMaster(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Assigned = false,
		RawRootPosition = returnPt + v3(0, 3, 0),
		SupportedPosition = returnPt,
		Origin = origin,
		Now = 2.0,
		DeltaTime = 0.2,
	})
	local uturnPlan = SquadMovement.PlanActiveFollow(owner, hero, returnPt, 2.0, {
		PlaceOnGround = function(base, off) return base + off end,
		CanShortcut = function() return true end,
	})
	assert(flatDist(uturnPlan.Goal, uturnPlan.TerminalGoal) < 0.01, "U-turn did not skip obsolete turnaround points")

	-- Jumped gap: player jumps across an unwalkable chasm; follower at gap edge triggers graph fallback
	SquadMovement.Reset(owner)
	local preGap = v3(basin.X, basin.Y, basin.Z)
	local postGap = v3(basin.X + 18, basin.Y, basin.Z)
	SquadMovement.UpdateMaster(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Assigned = false,
		RawRootPosition = preGap + v3(0, 3, 0),
		SupportedPosition = preGap,
		Origin = origin,
		Now = 1.0,
		DeltaTime = 0.1,
	})
	SquadMovement.UpdateMaster(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Assigned = false,
		RawRootPosition = preGap + v3(9, 8, 0),
		SupportedPosition = nil,
		IsJumping = true,
		Origin = origin,
		Now = 1.2,
		DeltaTime = 0.2,
	})
	SquadMovement.UpdateMaster(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Assigned = false,
		RawRootPosition = postGap + v3(0, 3, 0),
		SupportedPosition = postGap,
		Origin = origin,
		Now = 1.4,
		DeltaTime = 0.2,
		CanWalk = function() return false end,
	})
	hero.Position = preGap
	local gapPlan = SquadMovement.PlanActiveFollow(owner, hero, postGap, 1.4, {
		PlaceOnGround = function(base, off) return base + off end,
		CanShortcut = function() return false end,
	})
	assert(gapPlan.UseGraphFallback == true, "Jumped gap did not fall back to connector graph")
	SquadMovement.Reset(owner)
end)

test("Combat disengagement rejoins a forward trail point and server route lag excludes formation spacing", function()
	local owner = {}
	local origin = v3(0, 0, 0)
	for i = 1, 10 do
		local p = v3(0, 0, i * 4)
		SquadMovement.UpdateMaster(owner, {
			FloorId = 1,
			RoomGeneration = 1,
			Assigned = false,
			RawRootPosition = p + v3(0, 3, 0),
			SupportedPosition = p,
			Origin = origin,
			Now = i * 0.1,
			DeltaTime = 0.1,
			IsSprintingAttr = true,
			HumanoidWalkSpeed = 16,
		})
	end
	local head = v3(0, 0, 40)
	local hero = { NetId = 5, SlotIndex = 5, FloorId = 1, RoomGeneration = 1, EntityGeneration = 1, Position = v3(6, 0, 28), MoveSpeed = 20 }
	SquadMovement.MarkCombat(owner, hero)
	local rejoinPlan = SquadMovement.PlanActiveFollow(owner, hero, head, 1.1, {
		PlaceOnGround = function(base, off) return base + off end,
		CanShortcut = function(from, goal) return flatDist(from, goal) <= 16 end,
	})
	assert(rejoinPlan.CursorSeq >= 7, "Combat rejoin returned to obsolete early trail entrance")
	assert(rejoinPlan.IsSprinting == true and rejoinPlan.FollowSpeed > 48, "Sprint follow speed not preserved")

	-- Hero standing right at its formation slot has 0 server route lag despite 6-stud offset from Master
	hero.Position = rejoinPlan.TerminalGoal
	local settledPlan = SquadMovement.PlanActiveFollow(owner, hero, head, 1.2, {
		PlaceOnGround = function(base, off) return base + off end,
		CanShortcut = function() return true end,
	})
	assert(settledPlan.RouteLag < 0.01 and flatDist(hero.Position, head) > 5.0, "Server route lag conflated with formation spacing")
	SquadMovement.Reset(owner)
end)

print(string.format("Squad movement tests: %d passed", passed))
