--!strict
-- StarterPlayerScripts/UI/LeaderboardController.client.luau
-- Player list data for the HUD leaderboard (Phase 5 §2.4). This script hides the CoreGui
-- PlayerList, owns the CustomLeaderboardGui ScreenGui, tracks each player's leaderstats (Floor,
-- Power) and publishes sorted rows to Hud/Store. The panel itself is drawn by HudApp
-- (Components.Leaderboard, portalled into CustomLeaderboardGui) so it can stack under the Next Goal
-- card and above the Right Rail without overlapping either.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Store = require(script.Parent:WaitForChild("Hud"):WaitForChild("Store"))

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 1. Disable the default CoreGui player list, with retries.
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then break end
		task.wait(0.5)
	end
end)

-- 2. ScreenGui container (HudApp renders into it).
local oldGui = PlayerGui:FindFirstChild("CustomLeaderboardGui")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CustomLeaderboardGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 8
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- Not inset below Roblox's top bar, so the leaderboard can sit in it, right side (HudApp places it
-- inside GuiService.TopbarInset, clear of Roblox's buttons).
screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
screenGui.IgnoreGuiInset = true
screenGui.Parent = PlayerGui

-- 3. Player tracking: Floor first, then Power, then name.
type Entry = { Player: Player, Floor: number, Power: number, Connections: { RBXScriptConnection } }

local entries: { [Player]: Entry } = {}
local publishQueued = false

local function publish()
	if publishQueued then return end
	publishQueued = true
	task.defer(function()
		publishQueued = false
		local list = {}
		for _, entry in entries do
			table.insert(list, entry)
		end
		table.sort(list, function(a, b)
			if a.Floor ~= b.Floor then return a.Floor > b.Floor end
			if a.Power ~= b.Power then return a.Power > b.Power end
			return a.Player.Name < b.Player.Name
		end)
		local rows = {}
		for i, entry in list do
			rows[i] = {
				UserId = entry.Player.UserId,
				DisplayName = entry.Player.DisplayName,
				Name = entry.Player.Name,
				Floor = entry.Floor,
				Power = entry.Power,
				IsLocal = entry.Player == LocalPlayer,
			}
		end
		Store.SetPlayers(rows)
	end)
end

local function track(entry: Entry, leaderstats: Instance, statName: string, field: "Floor" | "Power")
	local function bind(value: Instance)
		if not value:IsA("ValueBase") then return end
		local function read()
			entry[field] = tonumber((value :: any).Value) or 0
			publish()
		end
		read()
		table.insert(entry.Connections, (value :: any).Changed:Connect(read))
	end
	local existing = leaderstats:FindFirstChild(statName)
	if existing then
		bind(existing)
	else
		local conn: RBXScriptConnection
		conn = leaderstats.ChildAdded:Connect(function(child)
			if child.Name == statName then
				conn:Disconnect()
				bind(child)
			end
		end)
		table.insert(entry.Connections, conn)
	end
end

local function addPlayer(player: Player)
	if entries[player] then return end
	local entry: Entry = { Player = player, Floor = 0, Power = 0, Connections = {} }
	entries[player] = entry
	local function bindStats(leaderstats: Instance)
		track(entry, leaderstats, "Floor", "Floor")
		track(entry, leaderstats, "Power", "Power")
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		bindStats(leaderstats)
	else
		local conn: RBXScriptConnection
		conn = player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				conn:Disconnect()
				bindStats(child)
			end
		end)
		table.insert(entry.Connections, conn)
	end
	publish()
end

local function removePlayer(player: Player)
	local entry = entries[player]
	if not entry then return end
	for _, conn in entry.Connections do
		conn:Disconnect()
	end
	entries[player] = nil
	publish()
end

for _, p in Players:GetPlayers() do
	addPlayer(p)
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)

script.Destroying:Connect(function()
	for player in entries do
		removePlayer(player)
	end
	screenGui:Destroy()
end)
