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

local changed = Instance.new("BindableEvent")
Whistles.Changed = changed.Event

-- Track the Master's floor from the tower Context, and duels from DuelState.
task.spawn(function()
	local tower = Remotes:WaitForChild("TowerRemotes", 30)
	if not tower then return end
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

-- Seconds left on a whistle's cooldown (0 when ready).
function Whistles.Remaining(kind: string): number
	return math.max(0, (Whistles.Cooldown :: any)[kind] - (os.clock() - lastUsed[kind]))
end

-- Why a whistle can't be used right now, or nil when it can.
function Whistles.Blocked(kind: string): string?
	if not Whistles.OnFloor() then return "Only on Tower floors" end
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
