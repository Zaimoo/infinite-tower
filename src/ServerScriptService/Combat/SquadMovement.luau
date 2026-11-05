--!strict
-- ServerScriptService/Combat/SquadMovement.luau
-- Destination policy for active floor-run following (Phase 3) and assigned squads (Phase 4).

local Layout = require(game.ReplicatedStorage.Shared.Config.TowerLayout)
local Graph = require(script.Parent.Parent.Core.TowerNavigationGraph)

local SquadMovement = {}

SquadMovement.MASTER_FORMATION_RADIUS = 6.0
SquadMovement.FOLLOW_CATCHUP_RADIUS = 14.0
SquadMovement.FOLLOW_CATCHUP_SPAN = 50.0
SquadMovement.FOLLOW_CATCHUP_MAX_BONUS = 0.65
SquadMovement.MASTER_SPRINT_MULTIPLIER = 3.0
SquadMovement.SPRINT_FOLLOW_BUFFER = 1.05
SquadMovement.SPRINT_VELOCITY_THRESHOLD = 22.0
SquadMovement.MAX_TRAIL_POINTS = 48
SquadMovement.TRAIL_SAMPLE_DISTANCE = 2.5
SquadMovement.TRAIL_SAMPLE_INTERVAL = 0.35
SquadMovement.TELEPORT_RESET_DISTANCE = 36.0
SquadMovement.TELEPORT_SPEED_THRESHOLD = 120.0

export type TrailSample = {
	Seq: number,
	Position: Vector3,
	Forward: Vector3,
	At: number,
	LocationKey: string,
	ConnectorId: string?,
	UsableWidth: number?,
	WalkableFromPrev: boolean,
}

export type FollowPlan = {
	Goal: Vector3,
	TerminalGoal: Vector3,
	FormationOffset: Vector3,
	RouteLag: number,
	FollowSpeed: number,
	BaseFollowSpeed: number,
	IsSprinting: boolean,
	UsableWidth: number?,
	UseGraphFallback: boolean,
	CursorSeq: number,
}

local SLOT_SPECS: { { Lateral: number, Back: number } } = {
	{ Lateral = -3.2, Back = 2.6 },
	{ Lateral = 3.2, Back = 2.6 },
	{ Lateral = -5.4, Back = 5.0 },
	{ Lateral = 5.4, Back = 5.0 },
	{ Lateral = 0.0, Back = 6.0 },
}

local graphs: { [number]: any } = {}
local masterStates: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

local function v3(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function flatDist(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function dist3(a: Vector3, b: Vector3): number
	local dx, dy, dz = a.X - b.X, a.Y - b.Y, a.Z - b.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function unitFlat(dx: number, dz: number, fallback: Vector3?): Vector3
	local len = math.sqrt(dx * dx + dz * dz)
	if len > 0.001 then
		return v3(dx / len, 0, dz / len)
	end
	return fallback or v3(0, 0, -1)
end

local function defaultOrigin(floorId: number): Vector3
	return v3(12000 + ((floorId - 1) % 10) * 2400, 1000, 12000 + math.floor((floorId - 1) / 10) * 2400)
end

local function graphFor(floorId: number): any?
	if not floorId or floorId <= 0 then
		return nil
	end
	local idx = ((floorId - 1) % 5) + 1
	if not graphs[idx] then
		graphs[idx] = Graph.new(Layout.Get(idx))
	end
	return graphs[idx]
end

local function locatePoint(floorId: number, worldPos: Vector3, origin: Vector3?): (any?, any?)
	local g = graphFor(floorId)
	if not g then
		return nil, nil
	end
	local orig = origin or defaultOrigin(floorId)
	local lp = { X = worldPos.X - orig.X, Y = worldPos.Y - orig.Y, Z = worldPos.Z - orig.Z }
	local loc = Graph.Locate(g, lp)
	local link = nil
	if loc and loc.Link then
		for _, candidate in g.Links do
			if candidate.Id == loc.Link then
				link = candidate
				break
			end
		end
	end
	return loc, link
end

function SquadMovement.RadialOffset(slotIndex: number): Vector3
	local idx = math.clamp(slotIndex or 1, 1, 5)
	local angle = ((idx - 1) / 5) * (math.pi * 2)
	return v3(
		math.cos(angle) * SquadMovement.MASTER_FORMATION_RADIUS,
		0,
		math.sin(angle) * SquadMovement.MASTER_FORMATION_RADIUS
	)
end

function SquadMovement.SlotComponents(slotIndex: number, usableWidth: number?, distanceToAnchor: number?): (number, number)
	local idx = math.clamp(slotIndex or 1, 1, 5)
	local spec = SLOT_SPECS[idx]
	local lat = spec.Lateral
	local back = spec.Back
	if usableWidth and usableWidth > 0 then
		local maxLat = math.max(1.0, usableWidth * 0.5 - 1.6)
		local compression = math.clamp((usableWidth - 4.0) / 14.0, 0.35, 1.0)
		lat = math.clamp(lat * compression, -maxLat, maxLat)
		back = back * (1.0 + (1.0 - compression) * 0.45)
	elseif distanceToAnchor and distanceToAnchor > 18.0 then
		local tighten = math.clamp(18.0 / distanceToAnchor, 0.65, 1.0)
		lat *= tighten
	end
	return lat, back
end

function SquadMovement.SlotOffset(slotIndex: number, forward: Vector3?, usableWidth: number?, distanceToAnchor: number?): Vector3
	if not forward then
		return SquadMovement.RadialOffset(slotIndex)
	end
	local fwd = unitFlat(forward.X, forward.Z)
	local right = v3(-fwd.Z, 0, fwd.X)
	local lat, back = SquadMovement.SlotComponents(slotIndex, usableWidth, distanceToAnchor)
	return v3(
		right.X * lat - fwd.X * back,
		0,
		right.Z * lat - fwd.Z * back
	)
end

function SquadMovement.LateralSlotOffset(slotIndex: number, forward: Vector3?, usableWidth: number?): Vector3
	local fwd = if forward then unitFlat(forward.X, forward.Z) else v3(0, 0, -1)
	local right = v3(-fwd.Z, 0, fwd.X)
	local lat, _ = SquadMovement.SlotComponents(slotIndex, usableWidth, nil)
	local stagger = ((math.clamp(slotIndex or 1, 1, 5) - 1) % 3) * 0.65
	return v3(
		right.X * lat - fwd.X * stagger,
		0,
		right.Z * lat - fwd.Z * stagger
	)
end

function SquadMovement.ResolveSlotGoal(
	anchor: Vector3,
	slotIndex: number,
	forward: Vector3?,
	usableWidth: number?,
	distanceToAnchor: number?,
	placeOnGround: ((Vector3, Vector3) -> Vector3)?
): (Vector3, Vector3)
	local fwd = if forward then unitFlat(forward.X, forward.Z) else v3(0, 0, -1)
	local right = v3(-fwd.Z, 0, fwd.X)
	local lat, back = SquadMovement.SlotComponents(slotIndex, usableWidth, distanceToAnchor)
	local idx = math.clamp(slotIndex or 1, 1, 5)
	local centerLane = (idx - 3) * 0.55

	local candidates = {
		v3(right.X * lat - fwd.X * back, 0, right.Z * lat - fwd.Z * back),
		v3(right.X * (lat * 0.55) - fwd.X * back, 0, right.Z * (lat * 0.55) - fwd.Z * back),
		v3(right.X * centerLane - fwd.X * (1.2 + idx * 0.9), 0, right.Z * centerLane - fwd.Z * (1.2 + idx * 0.9)),
		v3(right.X * lat, 0, right.Z * lat),
		SquadMovement.RadialOffset(idx),
	}

	if not placeOnGround then
		local primary = candidates[1]
		return anchor + primary, primary
	end

	for _, offset in candidates do
		if flatDist(offset, v3(0, 0, 0)) > 0.1 then
			local placed = placeOnGround(anchor, offset)
			if flatDist(placed, anchor) > 0.25 then
				return placed, v3(placed.X - anchor.X, 0, placed.Z - anchor.Z)
			end
		end
	end

	return anchor, v3(0, 0, 0)
end

function SquadMovement.ComputeSpeed(params: {
	Assigned: boolean?,
	HeroBaseSpeed: number?,
	Overdrive: boolean?,
	IsSprintingAttr: boolean?,
	WalkSpeed: number?,
	HorizontalVelocity: number?,
	RouteLag: number?,
}): {
	IsSprinting: boolean,
	EffectiveMasterWalkSpeed: number,
	BaseFollowSpeed: number,
	CatchUpMultiplier: number,
	FollowSpeed: number,
}
	local assigned = params.Assigned == true
	local walkSpeed = if assigned then 16.0 else (params.WalkSpeed or 16.0)
	local horizVel = if assigned then 0.0 else (params.HorizontalVelocity or 0.0)
	local isSprinting = not assigned and (
		params.IsSprintingAttr == true
		or walkSpeed > SquadMovement.SPRINT_VELOCITY_THRESHOLD
		or horizVel > SquadMovement.SPRINT_VELOCITY_THRESHOLD
	)
	local effectiveMasterSpeed = if assigned
		then 16.0
		elseif isSprinting and walkSpeed <= SquadMovement.SPRINT_VELOCITY_THRESHOLD then walkSpeed * SquadMovement.MASTER_SPRINT_MULTIPLIER
		else walkSpeed
	local heroBase = params.HeroBaseSpeed or 20.0
	local overdriveMult = if params.Overdrive then 1.20 else 1.0
	local baseFollowSpeed = (if assigned
		then heroBase
		else math.max(heroBase, effectiveMasterSpeed * SquadMovement.SPRINT_FOLLOW_BUFFER, horizVel)) * overdriveMult
	local lag = params.RouteLag or 0.0
	local catchUpMult = if lag > SquadMovement.FOLLOW_CATCHUP_RADIUS
		then 1.0 + math.clamp((lag - SquadMovement.FOLLOW_CATCHUP_RADIUS) / SquadMovement.FOLLOW_CATCHUP_SPAN, 0.0, SquadMovement.FOLLOW_CATCHUP_MAX_BONUS)
		else 1.0
	return {
		IsSprinting = isSprinting,
		EffectiveMasterWalkSpeed = effectiveMasterSpeed,
		BaseFollowSpeed = baseFollowSpeed,
		CatchUpMultiplier = catchUpMult,
		FollowSpeed = baseFollowSpeed * catchUpMult,
	}
end

local function newMasterState(floorId: number, roomGen: number, assigned: boolean): any
	return {
		FloorId = floorId,
		RoomGeneration = roomGen,
		Assigned = assigned,
		Origin = nil,
		Trail = {} :: { TrailSample },
		Sequence = 0,
		Forward = v3(0, 0, -1),
		HeadPosition = nil :: Vector3?,
		HeadLocationKey = "WORLD",
		HeadConnectorId = nil :: string?,
		HeadUsableWidth = nil :: number?,
		LastRawPos = nil :: Vector3?,
		LastClock = 0,
		HorizontalSpeed = 0.0,
		IsSprinting = false,
		EffectiveMasterWalkSpeed = 16.0,
		GapPending = false,
		Heroes = {},
	}
end

function SquadMovement.Reset(ownerKey: any)
	if ownerKey ~= nil then
		masterStates[ownerKey] = nil
	end
end

function SquadMovement.ClearHero(ownerKey: any, heroKey: any)
	local state = ownerKey and masterStates[ownerKey]
	if state and heroKey ~= nil then
		state.Heroes[heroKey] = nil
	end
end

function SquadMovement.MarkCombat(ownerKey: any, hero: any)
	local state = ownerKey and masterStates[ownerKey]
	if not state or not hero then
		return
	end
	local key = hero.NetId or hero
	local track = state.Heroes[key]
	if not track then
		track = {
			FloorId = hero.FloorId,
			RoomGeneration = hero.RoomGeneration,
			EntityGeneration = hero.EntityGeneration,
			CursorSeq = nil,
			InCombat = true,
		}
		state.Heroes[key] = track
	else
		track.InCombat = true
	end
end

function SquadMovement.UpdateMaster(ownerKey: any, input: {
	FloorId: number?,
	RoomGeneration: number?,
	Assigned: boolean?,
	RawRootPosition: Vector3?,
	SupportedPosition: Vector3?,
	Origin: Vector3?,
	IsJumping: boolean?,
	IsSprintingAttr: boolean?,
	HumanoidWalkSpeed: number?,
	RootVelocity: Vector3?,
	Now: number,
	DeltaTime: number?,
	CanWalk: ((Vector3, Vector3) -> boolean)?,
}): any
	local floorId = input.FloorId or 0
	local roomGen = input.RoomGeneration or 1
	local assigned = input.Assigned == true
	local now = input.Now
	local dt = math.max(0.001, input.DeltaTime or 0.1)

	local state = masterStates[ownerKey]
	if not state or state.FloorId ~= floorId or state.RoomGeneration ~= roomGen or state.Assigned ~= assigned then
		state = newMasterState(floorId, roomGen, assigned)
		masterStates[ownerKey] = state
	end
	state.Origin = input.Origin or (if floorId > 0 then defaultOrigin(floorId) else v3(0, 0, 0))

	local rawPos = input.RawRootPosition or input.SupportedPosition
	local trackedSpeed = 0.0
	local teleported = false
	if rawPos then
		if state.LastRawPos then
			local stepHoriz = flatDist(rawPos, state.LastRawPos)
			local instSpeed = stepHoriz / dt
			if stepHoriz > SquadMovement.TELEPORT_RESET_DISTANCE or instSpeed > SquadMovement.TELEPORT_SPEED_THRESHOLD then
				teleported = true
				table.clear(state.Trail)
				table.clear(state.Heroes)
				state.Sequence = 0
				state.GapPending = false
				state.HorizontalSpeed = 0.0
			else
				trackedSpeed = instSpeed
				state.HorizontalSpeed = instSpeed
			end
		end
		state.LastRawPos = rawPos
		state.LastClock = now
	else
		state.HorizontalSpeed = 0.0
	end

	local rootVel = input.RootVelocity
	local rootHoriz = if rootVel then flatDist(rootVel, v3(0, 0, 0)) else 0.0
	local horizVel = math.max(rootHoriz, trackedSpeed)
	local speedInfo = SquadMovement.ComputeSpeed({
		Assigned = assigned,
		IsSprintingAttr = input.IsSprintingAttr,
		WalkSpeed = input.HumanoidWalkSpeed,
		HorizontalVelocity = horizVel,
	})
	state.IsSprinting = speedInfo.IsSprinting
	state.EffectiveMasterWalkSpeed = speedInfo.EffectiveMasterWalkSpeed
	state.CombinedHorizVelocity = horizVel

	if assigned then
		return state
	end

	local supported = input.SupportedPosition
	if not supported or input.IsJumping == true then
		state.GapPending = true
		return state
	end

	local loc, link = locatePoint(floorId, supported, state.Origin)
	local locKey = if loc then loc.Key else "WORLD"
	local linkId = if link then link.Id else nil
	local usableWidth = if link then link.UsableWidth else nil

	if link and state.HeadPosition then
		local moveDx = supported.X - state.HeadPosition.X
		local moveDz = supported.Z - state.HeadPosition.Z
		local linkDx = link.BX - link.AX
		local linkDz = link.BZ - link.AZ
		if math.sqrt(moveDx * moveDx + moveDz * moveDz) > 0.2 then
			local sign = if (moveDx * linkDx + moveDz * linkDz) >= 0 then 1 else -1
			state.Forward = unitFlat(linkDx * sign, linkDz * sign, state.Forward)
		end
	end

	state.HeadPosition = supported
	state.HeadLocationKey = locKey
	state.HeadConnectorId = linkId
	state.HeadUsableWidth = usableWidth

	local trail = state.Trail
	local last = trail[#trail]
	if not last then
		state.Sequence += 1
		state.GapPending = false
		table.insert(trail, {
			Seq = state.Sequence,
			Position = supported,
			Forward = state.Forward,
			At = now,
			LocationKey = locKey,
			ConnectorId = linkId,
			UsableWidth = usableWidth,
			WalkableFromPrev = true,
		})
		return state
	end

	local dx = supported.X - last.Position.X
	local dz = supported.Z - last.Position.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	local dy = math.abs(supported.Y - last.Position.Y)
	local regionChanged = locKey ~= last.LocationKey
	local shouldSample = dist >= SquadMovement.TRAIL_SAMPLE_DISTANCE
		or (regionChanged and dist >= 0.75)
		or (now - last.At >= SquadMovement.TRAIL_SAMPLE_INTERVAL and dist >= 0.9)
		or state.GapPending

	if shouldSample and dist >= 0.25 then
		local fwd = unitFlat(dx, dz, last.Forward)
		if link then
			local linkDx, linkDz = link.BX - link.AX, link.BZ - link.AZ
			local sign = if (dx * linkDx + dz * linkDz) >= 0 then 1 else -1
			fwd = unitFlat(linkDx * sign, linkDz * sign, fwd)
		end
		state.Forward = fwd
		local walkable = not teleported and dy <= math.max(3.5, dist * 0.40 + 1.5)
		if walkable and state.GapPending and (dist > 6.0 or dy > 2.2) then
			walkable = if input.CanWalk then input.CanWalk(last.Position, supported) else false
		elseif walkable and input.CanWalk and dist > 12.0 then
			walkable = input.CanWalk(last.Position, supported)
		end
		state.GapPending = false
		state.Sequence += 1
		table.insert(trail, {
			Seq = state.Sequence,
			Position = supported,
			Forward = fwd,
			At = now,
			LocationKey = locKey,
			ConnectorId = linkId,
			UsableWidth = usableWidth,
			WalkableFromPrev = walkable,
		})
		while #trail > SquadMovement.MAX_TRAIL_POINTS do
			table.remove(trail, 1)
		end
	elseif dist > 0.2 then
		local fwd = unitFlat(dx, dz, state.Forward)
		state.Forward = fwd
		if #trail == 1 then
			last.Position = supported
			last.Forward = fwd
			last.At = now
			last.LocationKey = locKey
			last.ConnectorId = linkId
			last.UsableWidth = usableWidth
		end
	end

	return state
end

local function trailDistanceFrom(trail: { TrailSample }, startIdx: number): number
	local total = 0.0
	for i = startIdx, #trail - 1 do
		total += flatDist(trail[i].Position, trail[i + 1].Position)
	end
	return total
end

local function projectOntoConnectorLane(
	heroPos: Vector3,
	goalPos: Vector3,
	slotIndex: number,
	origin: Vector3,
	link: any,
	placeOnGround: ((Vector3, Vector3) -> Vector3)?
): Vector3?
	local p = heroPos - origin
	local g = goalPos - origin
	local dx, dz = link.BX - link.AX, link.BZ - link.AZ
	local len2 = dx * dx + dz * dz
	if len2 < 0.01 then
		return nil
	end
	local tHero = ((p.X - link.AX) * dx + (p.Z - link.AZ) * dz) / len2
	local tGoal = ((g.X - link.AX) * dx + (g.Z - link.AZ) * dz) / len2
	if tHero < 0.06 or tHero > 0.94 then
		return nil
	end
	if tGoal >= 0.0 and tGoal <= 1.0 then
		return nil
	end
	local forwardSign = if tGoal > 1.0 then 1.0 else -1.0
	local exitT = if forwardSign > 0 then 0.96 else 0.04
	if (forwardSign > 0 and tHero >= 0.90) or (forwardSign < 0 and tHero <= 0.10) then
		return nil
	end
	local base = v3(
		origin.X + link.AX + dx * exitT,
		origin.Y + link.AY + (link.BY - link.AY) * exitT,
		origin.Z + link.AZ + dz * exitT
	)
	local fwd = unitFlat(dx * forwardSign, dz * forwardSign)
	local offset = SquadMovement.LateralSlotOffset(slotIndex, fwd, link.UsableWidth)
	if placeOnGround then
		return placeOnGround(base, offset)
	end
	return base + offset
end

function SquadMovement.PlanActiveFollow(
	ownerKey: any,
	hero: any,
	masterPos: Vector3,
	now: number,
	helpers: {
		HeroBaseSpeed: number?,
		Overdrive: boolean?,
		PlaceOnGround: ((Vector3, Vector3) -> Vector3)?,
		CanShortcut: ((Vector3, Vector3) -> boolean)?,
	}?
): FollowPlan
	local opts = helpers or {}
	local placeOnGround = opts.PlaceOnGround
	local canShortcut = opts.CanShortcut
	local state = ownerKey and masterStates[ownerKey]
	local floorId = hero.FloorId or (state and state.FloorId) or 0
	local origin = (state and state.Origin) or (if floorId > 0 then defaultOrigin(floorId) else v3(0, 0, 0))
	local heroLoc, heroLink = locatePoint(floorId, hero.Position, origin)
	local heroLocKey = if heroLoc then heroLoc.Key else "WORLD"
	local heroWidth = if heroLink then heroLink.UsableWidth else nil

	if not state or #state.Trail == 0 then
		local distToMaster = dist3(masterPos, hero.Position)
		local usableWidth = heroWidth
		local terminalGoal, offset = SquadMovement.ResolveSlotGoal(
			masterPos,
			hero.SlotIndex or 1,
			v3(0, 0, -1),
			usableWidth,
			distToMaster,
			placeOnGround
		)
		local routeLag = flatDist(hero.Position, terminalGoal)
		local speed = SquadMovement.ComputeSpeed({
			Assigned = false,
			HeroBaseSpeed = opts.HeroBaseSpeed or hero.MoveSpeed,
			Overdrive = opts.Overdrive,
			RouteLag = routeLag,
		})
		return {
			Goal = terminalGoal,
			TerminalGoal = terminalGoal,
			FormationOffset = offset,
			RouteLag = routeLag,
			FollowSpeed = speed.FollowSpeed,
			BaseFollowSpeed = speed.BaseFollowSpeed,
			IsSprinting = speed.IsSprinting,
			UsableWidth = usableWidth,
			UseGraphFallback = false,
			CursorSeq = 0,
		}
	end

	local trail: { TrailSample } = state.Trail
	local headPos: Vector3 = state.HeadPosition or masterPos
	local headWidth: number? = state.HeadUsableWidth or heroWidth
	local distToMaster = dist3(headPos, hero.Position)

	local terminalForward = state.Forward
	if heroLink then
		local dx, dz = heroLink.BX - heroLink.AX, heroLink.BZ - heroLink.AZ
		local toMasterX, toMasterZ = headPos.X - hero.Position.X, headPos.Z - hero.Position.Z
		local sign = if (toMasterX * dx + toMasterZ * dz) >= 0 then 1 else -1
		terminalForward = unitFlat(dx * sign, dz * sign, terminalForward)
	end

	local terminalGoal, terminalOffset = SquadMovement.ResolveSlotGoal(
		headPos,
		hero.SlotIndex or 1,
		terminalForward,
		headWidth,
		distToMaster,
		placeOnGround
	)

	local heroKey = hero.NetId or hero
	local track = state.Heroes[heroKey]
	if not track
		or track.FloorId ~= hero.FloorId
		or track.RoomGeneration ~= hero.RoomGeneration
		or track.EntityGeneration ~= hero.EntityGeneration
	then
		track = {
			FloorId = hero.FloorId,
			RoomGeneration = hero.RoomGeneration,
			EntityGeneration = hero.EntityGeneration,
			CursorSeq = nil,
			InCombat = false,
		}
		state.Heroes[heroKey] = track
	end

	local function shortcutAllowed(targetPos: Vector3, sampleLocKey: string?): boolean
		if math.abs(hero.Position.Y - targetPos.Y) > 4.5 then
			return false
		end
		if canShortcut then
			return canShortcut(hero.Position, targetPos)
		end
		if sampleLocKey and sampleLocKey ~= "WORLD" and sampleLocKey == heroLocKey then
			return flatDist(hero.Position, targetPos) <= 18.0
		end
		return flatDist(hero.Position, targetPos) <= 24.0
	end

	local cursorIdx = 1
	if track.InCombat or track.CursorSeq == nil then
		track.InCombat = false
		local chosenIdx: number? = nil
		for i = #trail, 1, -1 do
			local s = trail[i]
			if s.WalkableFromPrev or i == #trail then
				if shortcutAllowed(s.Position, s.LocationKey) then
					chosenIdx = i
					break
				end
			end
		end
		if not chosenIdx then
			local bestScore = math.huge
			for i = 1, #trail do
				local s = trail[i]
				local score = flatDist(hero.Position, s.Position) + 0.35 * trailDistanceFrom(trail, i)
				if score < bestScore then
					bestScore = score
					chosenIdx = i
				end
			end
		end
		cursorIdx = chosenIdx or #trail
		track.CursorSeq = trail[cursorIdx].Seq
	else
		for i = 1, #trail do
			if trail[i].Seq >= track.CursorSeq then
				cursorIdx = i
				break
			end
			cursorIdx = i
		end
	end

	-- Advance cursor past reached samples, passed segments, and U-turn loops on the same surface.
	for j = #trail, cursorIdx + 1, -1 do
		local later = trail[j]
		if later.WalkableFromPrev and later.LocationKey == heroLocKey and math.abs(hero.Position.Y - later.Position.Y) <= 3.5 then
			if flatDist(hero.Position, later.Position) + 1.0 < flatDist(hero.Position, trail[cursorIdx].Position) then
				cursorIdx = j
				break
			end
		end
	end

	while cursorIdx < #trail do
		local cur = trail[cursorIdx]
		local nxt = trail[cursorIdx + 1]
		if not nxt.WalkableFromPrev then
			break
		end
		local dCur = flatDist(hero.Position, cur.Position)
		local curSlot = cur.Position + SquadMovement.LateralSlotOffset(hero.SlotIndex or 1, cur.Forward, cur.UsableWidth or heroWidth)
		local dSlot = flatDist(hero.Position, curSlot)
		if (dCur <= 4.0 or dSlot <= 3.5) and math.abs(hero.Position.Y - cur.Position.Y) <= 3.5 then
			cursorIdx += 1
		elseif math.abs(hero.Position.Y - cur.Position.Y) <= 3.5 then
			local segX, segZ = nxt.Position.X - cur.Position.X, nxt.Position.Z - cur.Position.Z
			local relX, relZ = hero.Position.X - cur.Position.X, hero.Position.Z - cur.Position.Z
			local segLen = math.sqrt(segX * segX + segZ * segZ)
			local along = if segLen > 0.1 then (relX * segX + relZ * segZ) / segLen else -1
			local cross = if segLen > 0.1 then math.abs(relX * segZ - relZ * segX) / segLen else math.huge
			if segLen > 0.1 and along >= segLen * 0.45 and cross <= 9.5 then
				cursorIdx += 1
			else
				break
			end
		else
			break
		end
	end

	-- Find contiguous walkable span from cursorIdx; detect non-walkable jump gaps.
	local maxWalkableIdx = cursorIdx
	local gapDetected = false
	for i = cursorIdx + 1, #trail do
		if trail[i].WalkableFromPrev then
			maxWalkableIdx = i
		else
			gapDetected = true
			break
		end
	end

	local useGraphFallback = false
	local targetIdx = cursorIdx
	local maxSample = trail[maxWalkableIdx]
	local maxSampleOffset = SquadMovement.LateralSlotOffset(hero.SlotIndex or 1, maxSample.Forward, maxSample.UsableWidth or heroWidth)
	local maxSampleGoal = if placeOnGround then placeOnGround(maxSample.Position, maxSampleOffset) else (maxSample.Position + maxSampleOffset)
	if gapDetected and (flatDist(hero.Position, maxSampleGoal) <= 4.5 or flatDist(hero.Position, maxSample.Position) <= 6.5) then
		-- Hero reached the edge of a jumped gap: fall back to the connector graph toward the Master.
		useGraphFallback = true
		targetIdx = #trail
	else
		local foundShortcut = false
		for i = maxWalkableIdx, cursorIdx + 1, -1 do
			local candidate = trail[i]
			local candOffset = SquadMovement.LateralSlotOffset(hero.SlotIndex or 1, candidate.Forward, candidate.UsableWidth or heroWidth)
			local candGoal = if placeOnGround then placeOnGround(candidate.Position, candOffset) else (candidate.Position + candOffset)
			if shortcutAllowed(candGoal, candidate.LocationKey) or shortcutAllowed(candidate.Position, candidate.LocationKey) then
				targetIdx = i
				foundShortcut = true
				break
			end
		end
		if not foundShortcut then
			local curSample = trail[cursorIdx]
			local curOffset = SquadMovement.LateralSlotOffset(hero.SlotIndex or 1, curSample.Forward, curSample.UsableWidth or heroWidth)
			local curGoal = if placeOnGround then placeOnGround(curSample.Position, curOffset) else (curSample.Position + curOffset)
			if not shortcutAllowed(curGoal, curSample.LocationKey) and not shortcutAllowed(curSample.Position, curSample.LocationKey) then
				useGraphFallback = true
				targetIdx = #trail
			end
		end
	end

	track.CursorSeq = trail[targetIdx].Seq

	local chosenGoal = terminalGoal
	local activeWidth = headWidth
	if targetIdx < #trail and not useGraphFallback then
		local sample = trail[targetIdx]
		activeWidth = sample.UsableWidth or heroWidth
		local latOffset = SquadMovement.LateralSlotOffset(hero.SlotIndex or 1, sample.Forward, activeWidth)
		if placeOnGround then
			chosenGoal = placeOnGround(sample.Position, latOffset)
		else
			chosenGoal = sample.Position + latOffset
		end
	end

	local routeLag = flatDist(hero.Position, chosenGoal)
	if targetIdx < #trail then
		routeLag += trailDistanceFrom(trail, targetIdx)
		routeLag = math.max(0.0, routeLag - flatDist(headPos, terminalGoal))
	else
		routeLag = flatDist(hero.Position, terminalGoal)
	end

	local speed = SquadMovement.ComputeSpeed({
		Assigned = false,
		HeroBaseSpeed = opts.HeroBaseSpeed or hero.MoveSpeed,
		Overdrive = opts.Overdrive,
		IsSprintingAttr = state.IsSprinting,
		WalkSpeed = state.EffectiveMasterWalkSpeed,
		HorizontalVelocity = state.CombinedHorizVelocity,
		RouteLag = routeLag,
	})

	track.LastRouteLag = routeLag
	track.LastGoal = chosenGoal
	track.LastTerminalGoal = terminalGoal

	return {
		Goal = chosenGoal,
		TerminalGoal = terminalGoal,
		FormationOffset = terminalOffset,
		RouteLag = routeLag,
		FollowSpeed = speed.FollowSpeed,
		BaseFollowSpeed = speed.BaseFollowSpeed,
		IsSprinting = speed.IsSprinting,
		UsableWidth = activeWidth,
		UseGraphFallback = useGraphFallback,
		CursorSeq = track.CursorSeq,
	}
end

function SquadMovement.DebugState(ownerKey: any): any
	local state = ownerKey and masterStates[ownerKey]
	if not state then
		return nil
	end
	return {
		FloorId = state.FloorId,
		RoomGeneration = state.RoomGeneration,
		Assigned = state.Assigned,
		TrailCount = #state.Trail,
		Sequence = state.Sequence,
		IsSprinting = state.IsSprinting,
		HorizontalSpeed = state.HorizontalSpeed,
		HeadLocationKey = state.HeadLocationKey,
		HeadConnectorId = state.HeadConnectorId,
		HeadUsableWidth = state.HeadUsableWidth,
	}
end

return SquadMovement
