--!strict
-- ServerScriptService/Combat/RivalLesson.server.luau
-- The Rival Master lesson (docs/first-session-and-social-plan.md A7, GDD §4.7 and §6.1): every new
-- Master's first theft and bounty duel, against a server-run rival.
--
--   ARRIVING  on a Tower floor 2-4, out of any sanctuary, a Rival Master walks in ahead of the player
--   WAITING   and drops its relic. Only this player may take it (RelicService TrainingFor); taking
--             it is a real theft with a private, training bounty (CombatSimulation registerPickup).
--   HUNTING   the Rival closes in and claims the bounty a moment later,
--   DUELING   which starts the real bounty duel against its squad (CombatSimulation.StartRivalDuel).
--             If the Rival wins, it lets the relic go anyway: the lesson never ends on a loss.
--   LEAVING   the Rival walks off and is removed.
--
-- The lesson runs once per profile (guide fact Steal, via the RelicStolen guide event); an
-- abandoned attempt (the player walks away, leaves the floor, or never takes the relic) cleans up
-- and tries again later in the session. The guide reads RelicWaiting / Hunting (_G.RivalLesson).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Core = script.Parent.Parent:WaitForChild("Core")
local Tower = require(Core:WaitForChild("TowerFloorService"))
local HeroNavigation = require(Core:WaitForChild("HeroNavigation"))

local RIVAL_NAME = "Rival Master"
-- The Rival's squad: one Common hero at level 1, so a new Master's showcase hero wins comfortably.
-- The duel also holds both squads to the player's Rift Attunement cap (the rival's MaxFloorReached).
local ROSTER = { { TemplateId = "hero_shurn", Level = 1 } }
local RELIC_TIER = "MANA_GEODE"
local FLOORS = { min = 2, max = 4 } -- the lesson happens on the first of these floors a player visits
local DROP_DISTANCE = 12 -- studs ahead of the player
local APPROACH_DISTANCE = 14 -- the Rival walks in from this far beyond the drop
local ARRIVE_SECONDS = 5 -- the relic drops when the Rival arrives, or after this long
local WAIT_SECONDS = 120 -- the relic waits this long for the player before the attempt is abandoned
local CLAIM_SECONDS = 2.0 -- after the theft, the Rival claims the bounty within this long
local CLAIM_RANGE = 7
local LEAVE_SECONDS = 2.5
local RETRY_SECONDS = 30
local MAX_ATTEMPTS = 3 -- per session

type Phase = "ARRIVING" | "WAITING" | "HUNTING" | "DUELING" | "LEAVING"
type Lesson = {
	Phase: Phase,
	Rival: any, -- CombatSimulation's stand-in Master
	Body: Model?,
	FloorId: number,
	RoomGeneration: number,
	Drop: Vector3, -- feet position of the relic
	Approach: Vector3, -- where the Rival walks in from, and leaves to
	RelicId: number?,
	Stole: boolean,
	Until: number, -- the current phase's deadline
}

local Lessons: { [Player]: Lesson } = {}
local Attempts: { [Player]: number } = {}
local NextTry: { [Player]: number } = {}

local function services(): (any, any, any)
	return _G.CombatSimulation, _G.RelicService, _G.DataManager
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function inSafeZone(state: any, position: Vector3): boolean
	local zone = Tower.GetSafety(state, position)
	return zone.CombatSafe == true or zone.CanBankCargo == true
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- The flat direction from `from` to `to`, or `fallback` when they (nearly) coincide.
local function towards(from: Vector3, to: Vector3, fallback: Vector3): Vector3
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return if d.Magnitude > 0.5 then d.Unit else fallback
end

-- A spot ahead of the player on the same floor, off any sanctuary, with a clear walk from the
-- player; tries the facing first, then wider angles. Returns (drop feet, approach feet).
local function findSpot(state: any, root: BasePart): (Vector3?, Vector3?)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
	for _, angle in { 0, 35, -35, 70, -70, 120, -120, 180 } do
		local dir = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(flat)
		local drop = HeroNavigation.PlaceNear(root.Position, dir * DROP_DISTANCE)
		local context = Tower.ContextAt(drop + Vector3.new(0, 3, 0))
		if flatDistance(drop, root.Position) >= DROP_DISTANCE * 0.6 and Tower.Same(context, state)
			and not inSafeZone(state, drop + Vector3.new(0, 3, 0)) then
			local approach = HeroNavigation.PlaceNear(drop + Vector3.new(0, 3, 0), dir * APPROACH_DISTANCE)
			return drop, approach
		end
	end
	return nil, nil
end

-- The Rival's body: a plain avatar with its name over its head. Cosmetic: the duel uses its
-- server-run squad, never this model. nil if the avatar can't be built (the lesson still runs).
local function buildBody(at: Vector3): Model?
	local ok, model = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local navy, crimson = Color3.fromRGB(28, 32, 52), Color3.fromRGB(150, 32, 44)
		description.TorsoColor = crimson
		description.LeftArmColor, description.RightArmColor = navy, navy
		description.LeftLegColor, description.RightLegColor = navy, navy
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then return nil end
	model.Name = "RivalMaster"
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = RIVAL_NAME
		humanoid.WalkSpeed = 18
	end
	model:PivotTo(CFrame.new(at + Vector3.new(0, 3, 0)))
	model.Parent = Workspace
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		pcall(function() root:SetNetworkOwner(nil) end)
	end
	return model
end

local function walk(body: Model?, target: Vector3, speed: number?)
	local humanoid = body and body:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if speed then humanoid.WalkSpeed = speed end
	humanoid:MoveTo(target)
end

local function bodyPosition(lesson: Lesson): Vector3
	local body = lesson.Body
	local root = body and body:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else lesson.Drop + Vector3.new(0, 3, 0)
end

local function nudgeGuide(player: Player)
	local _, _, dm = services()
	if dm and dm.ReportProgress then dm.ReportProgress(player, "RivalLesson") end
end

-- Ends a lesson. `finished`: the player stole the relic, so the lesson is done for good;
-- otherwise the attempt was abandoned and may be tried again.
local function finish(player: Player, lesson: Lesson, finished: boolean)
	local combat, relics, dm = services()
	Lessons[player] = nil
	if lesson.RelicId and relics and not lesson.Stole then relics.RemoveRelic(lesson.RelicId) end
	if combat and lesson.Rival then combat.DismissRival(lesson.Rival) end
	local body = lesson.Body
	if body then
		walk(body, lesson.Approach, 18)
		task.delay(LEAVE_SECONDS, function() body:Destroy() end)
	end
	if finished then
		-- If the Rival never got its duel (the player banked the relic first), the step still passes.
		if dm and dm.ReportProgress then dm.ReportProgress(player, "DuelLesson") end
	else
		Attempts[player] = (Attempts[player] or 0) + 1
		NextTry[player] = os.clock() + RETRY_SECONDS
	end
	nudgeGuide(player)
end

local function eligible(player: Player, now: number): (any, BasePart?)
	local combat, relics, dm = services()
	if not combat or not relics or not dm or not dm.RivalLessonDue then return nil, nil end
	if (Attempts[player] or 0) >= MAX_ATTEMPTS or now < (NextTry[player] or 0) then return nil, nil end
	if not dm.RivalLessonDue(player) then return nil, nil end
	local state = Tower.GetState(player)
	if state.FloorId < FLOORS.min or state.FloorId > FLOORS.max or Tower.IsTransitioning(player) then return nil, nil end
	local root = rootOf(player)
	local char = player.Character
	if not root or not char or char:GetAttribute("CarryingRelic") ~= nil or char:GetAttribute("IsLootThief") == true then return nil, nil end
	if char:GetAttribute("SquadWiped") == true or combat.IsInDuel(player) or combat.StandingHeroes(player) < 1 then return nil, nil end
	if inSafeZone(state, root.Position) then return nil, nil end
	return state, root
end

local function begin(player: Player, state: any, root: BasePart, now: number)
	local combat, _, dm = services()
	local drop, approach = findSpot(state, root)
	if not drop or not approach then
		NextTry[player] = now + 5 -- try again once the player has moved
		return
	end
	local profile = dm.GetProfile(player)
	-- The Rival has no squad until it claims the bounty (CombatSimulation.ArmRival).
	local rival = combat.CreateRival(RIVAL_NAME, approach + Vector3.new(0, 3, 0), state.FloorId, state.RoomGeneration, {},
		profile and profile.MaxFloorReached or state.FloorId)
	local lesson: Lesson = {
		Phase = "ARRIVING", Rival = rival, Body = nil, FloorId = state.FloorId, RoomGeneration = state.RoomGeneration,
		Drop = drop, Approach = approach, RelicId = nil, Stole = false, Until = now + ARRIVE_SECONDS,
	}
	Lessons[player] = lesson
	task.spawn(function()
		local body = buildBody(approach)
		if Lessons[player] ~= lesson then
			if body then body:Destroy() end
			return
		end
		lesson.Body = body
		walk(body, drop + Vector3.new(0, 3, 0))
	end)
end

local function dropRelic(player: Player, lesson: Lesson, now: number)
	local _, relics, dm = services()
	local relic = relics.SpawnRelic(RELIC_TIER, lesson.Drop, lesson.Rival.UserId)
	relic.TrainingFor = player.UserId
	relic.KillerName = RIVAL_NAME
	relic.LockedUserId, relic.LockExpiresAt, relic.LockKind = nil, 0, nil -- the Rival fumbled it: no seal
	lesson.RelicId = relic.RelicId
	lesson.Phase = "WAITING"
	lesson.Until = now + WAIT_SECONDS
	-- Step back from it.
	walk(lesson.Body, lesson.Drop + towards(lesson.Drop, lesson.Approach, Vector3.new(0, 0, 1)) * 5 + Vector3.new(0, 3, 0))
	dm.SendToast(player, "Rival dropped a relic|Take it before they do", "INFO")
	nudgeGuide(player)
end

local function step(player: Player, lesson: Lesson, now: number)
	local combat, relics = services()
	local state = Tower.GetState(player)
	local onFloor = state.FloorId == lesson.FloorId and state.RoomGeneration == lesson.RoomGeneration
	if lesson.Phase == "ARRIVING" then
		if not onFloor then finish(player, lesson, false) return end
		local arrived = lesson.Body ~= nil and flatDistance(bodyPosition(lesson), lesson.Drop) <= 3
		if arrived or now >= lesson.Until then dropRelic(player, lesson, now) end
	elseif lesson.Phase == "WAITING" then
		local relic = lesson.RelicId and relics.GetRelic(lesson.RelicId)
		if relic and relic.Carrier == player then
			lesson.Stole = true
			lesson.Phase = "HUNTING"
			lesson.Until = now + CLAIM_SECONDS
			nudgeGuide(player)
		elseif not relic or not onFloor or now >= lesson.Until then
			finish(player, lesson, false)
		end
	elseif lesson.Phase == "HUNTING" then
		local root = rootOf(player)
		if root then walk(lesson.Body, root.Position, 30) end
		local close = root ~= nil and flatDistance(bodyPosition(lesson), root.Position) <= CLAIM_RANGE
		if close or now >= lesson.Until then
			local contest = lesson.RelicId and combat.Contests[lesson.RelicId]
			-- The duel's arena centres on the hunter: stand the Rival beside the player.
			lesson.Rival.Position = if root then root.Position + towards(root.Position, bodyPosition(lesson), Vector3.new(0, 0, 1)) * 6 else bodyPosition(lesson)
			combat.ArmRival(lesson.Rival, ROSTER)
			local ok = contest ~= nil and contest.Training == true and combat.StartRivalDuel(lesson.Rival, contest)
			if ok then
				lesson.Phase = "DUELING"
				nudgeGuide(player)
			else
				-- The relic was banked or dropped first, or the duel can't start: the lesson still counts.
				finish(player, lesson, true)
			end
		end
	elseif lesson.Phase == "DUELING" then
		local contest = lesson.RelicId and combat.Contests[lesson.RelicId]
		if not combat.IsInDuel(player) and (not contest or contest.Status ~= "DUELING") then
			finish(player, lesson, true)
		end
	end
end

local RivalLesson = {}

-- The lesson's relic lies on the ground for this player (the guide's Steal step).
function RivalLesson.RelicWaiting(player: Player): boolean
	local lesson = Lessons[player]
	return lesson ~= nil and lesson.Phase == "WAITING"
end

-- The Rival is coming for its relic, or duelling for it (the guide's Duel step).
function RivalLesson.Hunting(player: Player): boolean
	local lesson = Lessons[player]
	return lesson ~= nil and (lesson.Phase == "HUNTING" or lesson.Phase == "DUELING")
end

_G.RivalLesson = RivalLesson

Players.PlayerRemoving:Connect(function(player)
	local lesson = Lessons[player]
	if lesson then finish(player, lesson, false) end
	Attempts[player] = nil
	NextTry[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local lesson = Lessons[player]
			if lesson then
				local ok, err = pcall(step, player, lesson, now)
				if not ok then
					warn("[RivalLesson] " .. tostring(err))
					if Lessons[player] == lesson then finish(player, lesson, false) end
				end
			else
				local state, root = eligible(player, now)
				if state and root then
					local ok, err = pcall(begin, player, state, root, now)
					if not ok then
						warn("[RivalLesson] " .. tostring(err))
						NextTry[player] = now + RETRY_SECONDS
					end
				end
			end
		end
	end
end)
