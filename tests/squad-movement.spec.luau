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

test("Assigned anchor retains valid objective, uses connector route cost across chasms, and ignores stranded-hero drag", function()
	local owner = {}
	SquadMovement.Reset(owner)
	local layout = Layout.Get(3) -- Floor 18 uses variant 3
	local origin = v3(0, 0, 0)
	local basin = layout.Platforms.Basin
	local east = layout.Platforms.EastGallery
	local apex = layout.Platforms.Apex
	local basinPos = v3(basin.X, basin.Y, basin.Z)
	local eastPos = v3(east.X, east.Y, east.Z)
	local apexPos = v3(apex.X, apex.Y, apex.Z)

	local h1 = { NetId = 1, SlotIndex = 1, FloorId = 18, RoomGeneration = 1, Position = basinPos + v3(2, 0, 0), CurrentHP = 100, State = "FOLLOW_MASTER", MoveSpeed = 20 }
	local h2 = { NetId = 2, SlotIndex = 2, FloorId = 18, RoomGeneration = 1, Position = basinPos + v3(-2, 0, 0), CurrentHP = 100, State = "FOLLOW_MASTER", MoveSpeed = 20 }
	-- Stranded hero far away on Apex in UNREACHABLE state must not drag the squad reference point away from Basin
	local h3 = { NetId = 3, SlotIndex = 3, FloorId = 18, RoomGeneration = 1, Position = apexPos, CurrentHP = 100, State = "FOLLOW_MASTER", NavigationStatus = "UNREACHABLE", NoProgressSeconds = 3.5, MoveSpeed = 20 }
	local heroes = { h1, h2, h3 }

	local mobEast = { NetId = 101, FloorId = 18, RoomGeneration = 1, EntityGeneration = 1, IsAlive = true, Position = eastPos }
	local mobApex = { NetId = 102, FloorId = 18, RoomGeneration = 1, EntityGeneration = 1, IsAlive = true, Position = apexPos }
	local mobs = { [101] = mobEast, [102] = mobApex }

	-- Route cost from Basin to EastGallery (direct ramp) is shorter than Basin -> Crossing -> Apex
	local costEast = SquadMovement.RouteCost(18, basinPos, eastPos, origin)
	local costApex = SquadMovement.RouteCost(18, basinPos, apexPos, origin)
	assert(costEast < costApex, "RouteCost did not prefer direct ramp over multi-hop path")

	local sel1 = SquadMovement.SelectAssignedAnchor(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Origin = origin,
		DefaultSpawnPosition = basinPos,
		Heroes = heroes,
		Mobs = mobs,
		Now = 1.0,
	})
	assert(sel1.ObjectiveNetId == 101, "Assigned anchor did not pick lowest route-cost objective from healthy cluster")

	-- Same-tick cache returns identical table without recomputing
	local selSameTick = SquadMovement.SelectAssignedAnchor(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Origin = origin,
		DefaultSpawnPosition = basinPos,
		Heroes = heroes,
		Mobs = mobs,
		Now = 1.0,
	})
	assert(selSameTick == sel1, "Assigned anchor did not reuse per-tick cached result")

	-- Retain current objective on subsequent tick even if heroes move closer to another mob
	h1.Position = apexPos + v3(4, 0, 0)
	h2.Position = apexPos + v3(-4, 0, 0)
	local selRetained = SquadMovement.SelectAssignedAnchor(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Origin = origin,
		DefaultSpawnPosition = basinPos,
		Heroes = heroes,
		Mobs = mobs,
		Now = 1.2,
	})
	assert(selRetained.ObjectiveNetId == 101 and selRetained.Retained == true, "Valid assigned objective was not retained")

	-- When retained objective dies, advance to next reachable objective (102)
	mobEast.IsAlive = false
	local selNext = SquadMovement.SelectAssignedAnchor(owner, {
		FloorId = 18,
		RoomGeneration = 1,
		Origin = origin,
		DefaultSpawnPosition = basinPos,
		Heroes = heroes,
		Mobs = mobs,
		Now = 1.4,
	})
	assert(selNext.ObjectiveNetId == 102 and selNext.Retained == false, "Did not transition to next eligible objective after target death")

	-- Assist list is deterministic and leads with the squad's chosen objective
	h2.TargetNetId = 102
	local assist = SquadMovement.BuildAssignedAssistList(owner, h1, heroes)
	assert(#assist == 1 and assist[1] == 102, "Assist list did not deduplicate and lead with squad objective")

	-- Regroup speed operates independently of owner sprint attributes
	local regroupPlan = SquadMovement.PlanAssignedRegroup(owner, h1, selNext.RegroupAnchor, 1.4, {
		HeroBaseSpeed = 20,
		Overdrive = false,
		PlaceOnGround = function(base, off) return base + off end,
	})
	assert(regroupPlan.IsSprinting == false and regroupPlan.BaseFollowSpeed == 20, "Assigned regroup depended on owner sprint state")
	SquadMovement.Reset(owner)
end)

test("Combat move outcome tries alternative supported attack position before generation-scoped target rejection", function()
	local owner = {}
	SquadMovement.Reset(owner)
	local hero = {
		NetId = 1,
		SlotIndex = 1,
		FloorId = 18,
		RoomGeneration = 1,
		Position = v3(0, 0, 0),
		AttackRange = 14,
		State = "MOVE_TO_TARGET",
		TargetNetId = 55,
	}
	local mob = {
		NetId = 55,
		FloorId = 18,
		RoomGeneration = 1,
		EntityGeneration = 3,
		IsAlive = true,
		Position = v3(20, 0, 0),
	}

	-- First UNREACHABLE outcome for a ranged hero finds an alternative attack position within AttackRange
	local firstOutcome = SquadMovement.HandleCombatMoveOutcome(owner, hero, mob, { Status = "UNREACHABLE" }, 10.0, {
		ExcludeSeconds = 5.0,
		PlaceOnGround = function(base, off) return base + off end,
		CanAttack = function(from, to) return dist(from, to) <= 14 end,
		CanShortcut = function() return true end,
	})
	assert(firstOutcome.Action == "RETRY_ALTERNATIVE" and firstOutcome.Goal ~= nil, "Did not attempt alternative attack position first")
	assert(hero.AlternativeAttackGoal ~= nil and hero.TargetNetId == 55, "Cleared target prematurely before trying alternative attack position")

	-- Second UNREACHABLE outcome on the same target generation rejects the target for ExcludeSeconds
	local secondOutcome = SquadMovement.HandleCombatMoveOutcome(owner, hero, mob, { Status = "UNREACHABLE" }, 11.0, {
		ExcludeSeconds = 5.0,
		PlaceOnGround = function(base, off) return base + off end,
		CanAttack = function(from, to) return dist(from, to) <= 14 end,
		CanShortcut = function() return true end,
	})
	assert(secondOutcome.Action == "REJECTED", "Did not reject target after alternative attack position also failed")
	assert(hero.TargetNetId == nil and hero.State == "FOLLOW_MASTER", "Rejected target did not return hero to FOLLOW_MASTER")
	local rej = hero.NavigationRejectedTargets and hero.NavigationRejectedTargets[55]
	assert(rej ~= nil and rej.Until == 16.0 and rej.Generation == 3, "Generation-scoped target exclusion not recorded")
	SquadMovement.Reset(owner)
end)

test("Assigned squad on diagonal ramp stays committed to current camp until cleared when both end camps spawn", function()
	local owner = {}
	SquadMovement.Reset(owner)
	local layout = Layout.Get(1)
	local origin = v3(0, 0, 0)
	local basin = layout.Platforms.Basin
	local west = layout.Platforms.WestGallery
	local basinPos = v3(basin.X, basin.Y, basin.Z)

	-- 5 heroes spread along the Basin_WestGallery diagonal ramp
	local link
	for _, l in ipairs(layout.Links) do
		if l.From == "Basin" and l.To == "WestGallery" then
			link = l
			break
		end
	end
	assert(link ~= nil, "Missing Basin_WestGallery ramp")
	local rampA = v3(link.AX, link.AY, link.AZ)
	local rampB = v3(link.BX, link.BY, link.BZ)

	local heroes = {}
	for slot = 1, 5 do
		local t = 0.85 - (slot - 1) * 0.18
		heroes[slot] = {
			NetId = slot,
			SlotIndex = slot,
			FloorId = 1,
			RoomGeneration = 1,
			Position = rampA:Lerp(rampB, t),
			CurrentHP = 100,
			State = "MOVE_TO_TARGET",
			MoveSpeed = 20,
		}
	end

	-- Camp at WestGallery (top of ramp) has 2 mobs; Camp at BasinWest (bottom of ramp) spawns 2 mobs
	local mobUpper1 = { NetId = 201, FloorId = 1, RoomGeneration = 1, EntityGeneration = 1, IsAlive = true, CampId = "CAMP_WEST_GALLERY", Position = v3(west.X, west.Y, west.Z) }
	local mobUpper2 = { NetId = 202, FloorId = 1, RoomGeneration = 1, EntityGeneration = 1, IsAlive = true, CampId = "CAMP_WEST_GALLERY", Position = v3(west.X - 12, west.Y, west.Z - 10) }
	local mobLower1 = { NetId = 101, FloorId = 1, RoomGeneration = 1, EntityGeneration = 1, IsAlive = true, CampId = "CAMP_BASIN_WEST", Position = v3(basin.X - 60, basin.Y, basin.Z - 10) }
	local mobLower2 = { NetId = 102, FloorId = 1, RoomGeneration = 1, EntityGeneration = 1, IsAlive = true, CampId = "CAMP_BASIN_WEST", Position = v3(basin.X - 70, basin.Y, basin.Z) }

	-- Initially only upper camp is alive; squad commits to CAMP_WEST_GALLERY (201)
	local mobs = { [201] = mobUpper1, [202] = mobUpper2 }
	local sel1 = SquadMovement.SelectAssignedAnchor(owner, {
		FloorId = 1,
		RoomGeneration = 1,
		Origin = origin,
		DefaultSpawnPosition = basinPos,
		Heroes = heroes,
		Mobs = mobs,
		Now = 1.0,
	})
	assert(sel1.ObjectiveNetId == 201 and sel1.ObjectiveCampId == "CAMP_WEST_GALLERY", "Did not lock upper camp")

	-- Now lower camp spawns behind the squad while trailing heroes (slots 3, 4, 5) are still on the lower ramp closer to lower camp,
	-- and mobUpper1 dies. Squad must NOT flip to CAMP_BASIN_WEST while mobUpper2 in CAMP_WEST_GALLERY is still alive!
	mobs[101] = mobLower1
	mobs[102] = mobLower2
	mobUpper1.IsAlive = false

	local sel2 = SquadMovement.SelectAssignedAnchor(owner, {
		FloorId = 1,
		RoomGeneration = 1,
		Origin = origin,
		DefaultSpawnPosition = basinPos,
		Heroes = heroes,
		Mobs = mobs,
		Now = 1.2,
	})
	assert(sel2.ObjectiveNetId == 202 and sel2.ObjectiveCampId == "CAMP_WEST_GALLERY" and sel2.Retained == true, "Squad flipped to lower camp before finishing committed upper camp")

	-- Assist list only contains mobs from the committed camp, never mixing camps
	heroes[5].TargetNetId = 101 -- even if a trailing hero had a stale target id from the other camp
	local assist = SquadMovement.BuildAssignedAssistList(owner, heroes[1], heroes)
	for _, id in ipairs(assist) do
		assert(id == 202, "Assist list leaked target from uncommitted camp: " .. tostring(id))
	end

	-- Once the entire upper camp is cleared, squad cleanly transitions to CAMP_BASIN_WEST
	mobUpper2.IsAlive = false
	local sel3 = SquadMovement.SelectAssignedAnchor(owner, {
		FloorId = 1,
		RoomGeneration = 1,
		Origin = origin,
		DefaultSpawnPosition = basinPos,
		Heroes = heroes,
		Mobs = mobs,
		Now = 1.4,
	})
	assert(sel3.ObjectiveCampId == "CAMP_BASIN_WEST" and (sel3.ObjectiveNetId == 101 or sel3.ObjectiveNetId == 102), "Squad did not transition to lower camp after upper camp cleared")
	SquadMovement.Reset(owner)
end)

print(string.format("Squad movement tests: %d passed", passed))
