--!strict
-- StarterPlayerScripts/UI/Hud/Whistles.luau
-- Overdrive (1) and Recall (2) whistles (Phase 5 §2.1). One place for the client cooldowns, the
-- Tower-floor and duel gating, and the remote, used by both the Right Rail and the Q/E/L1/R1
-- bindings. The server re-checks cooldowns and blocks Recall in a duel; this is display + intent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local WhistleCommand = Remotes:WaitForChild("CombatRemotes"):WaitForChild("WhistleCommand") :: RemoteEvent

local Whistles = {}

Whistles.Cooldown = table.freeze({ Overdrive = 20, Recall = 6 })
local CODE = { Overdrive = 1, Recall = 2 }

local lastUsed: { [string]: number } = { Overdrive = -999, Recall = -999 }
local floorId = 0
local inDuel = false
-- Squad mode (GDD 2.5): the floor the squad is assigned to, or nil while it is active with the Master.
local assignedFloor: number? = nil
local regroupAt: number? = nil
local regroupFloor: number? = nil

local changed = Instance.new("BindableEvent")
Whistles.Changed = changed.Event
-- Fires (newAssignedFloor?, previousAssignedFloor?) when the squad switches between assigned and active.
local modeChanged = Instance.new("BindableEvent")
Whistles.ModeChanged = modeChanged.Event

-- Track the Master's floor from the tower Context, duels from DuelState, the squad mode from
-- Presence and an assigned squad's regroup countdown from SquadStatus.
task.spawn(function()
	local tower = Remotes:WaitForChild("TowerRemotes", 30)
	if not tower then return end
	local presence = tower:WaitForChild("Presence", 30)
	if presence and presence:IsA("RemoteEvent") then
		presence.OnClientEvent:Connect(function(p: any)
			if type(p) ~= "table" or type(p.Self) ~= "table" then return end
			local a = p.Self.SquadAssignment
			local nextFloor = if type(a) == "number" and a > 0 then a else nil
			if nextFloor ~= assignedFloor then
				local previous = assignedFloor
				assignedFloor = nextFloor
				if not nextFloor then regroupAt, regroupFloor = nil, nil end
				modeChanged:Fire(nextFloor, previous)
				changed:Fire()
			end
		end)
	end
	local status = tower:WaitForChild("SquadStatus", 30)
	if status and status:IsA("RemoteEvent") then
		status.OnClientEvent:Connect(function(s: any)
			if type(s) ~= "table" then return end
			regroupAt = if type(s.RegroupIn) == "number" then os.clock() + s.RegroupIn else nil
			regroupFloor = if type(s.AssignedFloor) == "number" then s.AssignedFloor else nil
			changed:Fire()
		end)
	end
	local context = tower:WaitForChild("Context", 30)
	if context and context:IsA("RemoteEvent") then
		context.OnClientEvent:Connect(function(c: any)
			if type(c) == "table" and c.Stage ~= "PREPARE" and type(c.FloorId) == "number" then
				floorId = c.FloorId
				changed:Fire()
			end
		end)
	end
	local duel = tower:WaitForChild("DuelState", 30)
	if duel and duel:IsA("RemoteEvent") then
		duel.OnClientEvent:Connect(function(m: any)
			if type(m) ~= "table" then return end
			if m.Kind == "START" then inDuel = true elseif m.Kind == "CLEAR" then inDuel = false end
			changed:Fire()
		end)
	end
end)

function Whistles.OnFloor(): boolean
	return floorId >= 1
end

function Whistles.InDuel(): boolean
	return inDuel
end

-- The floor the squad is assigned to, or nil while it is active with the Master.
function Whistles.AssignedFloor(): number?
	return assignedFloor
end

-- Seconds until a fully downed assigned squad stands back up, and its floor; nil when not regrouping.
function Whistles.RegroupLeft(): (number?, number?)
	if not regroupAt or not assignedFloor then return nil, nil end
	return math.max(0, regroupAt - os.clock()), regroupFloor or assignedFloor
end

-- Seconds left on a whistle's cooldown (0 when ready).
function Whistles.Remaining(kind: string): number
	return math.max(0, (Whistles.Cooldown :: any)[kind] - (os.clock() - lastUsed[kind]))
end

-- Why a whistle can't be used right now, or nil when it can.
function Whistles.Blocked(kind: string): string?
	-- An assigned squad can be recalled from anywhere, the hub included, but takes no other commands.
	if kind == "Recall" and assignedFloor then
		if inDuel then return "Not during a duel" end
		if Whistles.Remaining(kind) > 0 then return "Cooling down" end
		return nil
	end
	if not Whistles.OnFloor() then return "Only on Tower floors" end
	if assignedFloor then return "Recall your squad to command it" end
	if inDuel then return "Not during a duel" end
	if Whistles.Remaining(kind) > 0 then return "Cooling down" end
	return nil
end

function Whistles.Fire(kind: string): boolean
	if Whistles.Blocked(kind) then return false end
	lastUsed[kind] = os.clock()
	WhistleCommand:FireServer(CODE[kind])
	-- The legacy HUD still draws its own cooldown text until it is retired.
	if _G.TriggerHUDWhistleCooldown then
		_G.TriggerHUDWhistleCooldown(if kind == "Overdrive" then "Q" else "E")
	end
	changed:Fire()
	return true
end

return Whistles
