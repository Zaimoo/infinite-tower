--!strict
-- ServerScriptService/Core/NotorietyService.luau
-- Reputation (docs/first-session-and-social-plan.md B6, GDD §6.1): counts thefts, bounties claimed
-- and escapes on profile.Notoriety (NotorietyRules decides what counts), shows the title they earn
-- over the Master's head, and keeps the weekly Top Thieves / Top Hunters boards.
--
-- Weekly boards: one OrderedDataStore per ISO week and board ("NotorietyThefts_2026W47"), key =
-- user id, value = that week's total. Totals are written for changed players every 60 s and when
-- they leave (not on every act, to stay inside the write budget); one loop reads the top 10 of each
-- every 60 s and pushes them to every client (NewsRemotes.Boards). Studio uses its own scope.
-- DataManager calls Refresh once a profile loads and Forget before it drops one.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NotorietyRules = require(ReplicatedStorage.Shared.Util.NotorietyRules)

export type Dependencies = {
	GetProfile: (Player) -> any,
	PushBoards: (any) -> (),
}

local NotorietyService = {}
local deps: Dependencies? = nil
local dirty: { [Player]: boolean } = {}
local names: { [number]: string } = {}
local boards: any = { Week = "", Thieves = {}, Hunters = {} }

local BOARD_SIZE = 10
local SCOPE = if RunService:IsStudio() then "STUDIO" else "global"

local function storeFor(board: string, week: string): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(`Notoriety{board}_{week}`, SCOPE)
	end)
	return if ok then store else nil
end

local function state(profile: any): NotorietyRules.State
	profile.Notoriety = NotorietyRules.Ensure(profile.Notoriety)
	return profile.Notoriety
end

-- The title over the Master's head (a server billboard, so everyone sees it) and on the player.
local function applyTitle(player: Player)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not profile then return end
	local s = state(profile)
	local title = NotorietyRules.Title(s)
	local thisWeek = s.Week == NotorietyRules.WeekKey(os.time())
	player:SetAttribute("NotorietyTitle", title)
	player:SetAttribute("NotorietyWeekThefts", if thisWeek then s.WeekThefts else 0)
	player:SetAttribute("NotorietyWeekHunts", if thisWeek then s.WeekHunts else 0)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then return end
	local tag = head:FindFirstChild("NotorietyTag") :: BillboardGui?
	if not title then
		if tag then tag:Destroy() end
		return
	end
	if not tag then
		local created = Instance.new("BillboardGui")
		created.Name = "NotorietyTag"
		created.Size = UDim2.fromOffset(170, 22)
		created.StudsOffset = Vector3.new(0, 2.5, 0) -- under the [Loot Thief] tag (3.2)
		created.AlwaysOnTop = false
		created.MaxDistance = 90
		local label = Instance.new("TextLabel")
		label.Name = "Title"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextSize = 15
		label.Font = Enum.Font.GothamBold
		label.TextStrokeTransparency = 0.4
		label.Parent = created
		created.Parent = head
		tag = created
	end
	local label = (tag :: BillboardGui):FindFirstChild("Title") :: TextLabel?
	if label then
		label.Text = title
		local hunter = title == "Bounty Hunter" or title == "Warden"
		label.TextColor3 = if hunter then Color3.fromRGB(255, 214, 120) else Color3.fromRGB(255, 120, 120)
	end
end

-- Records one act for `player` if it counts (NotorietyRules.Record): never training, never against a
-- Roblox friend, at most DAILY_CAP a day against the same victim. Yields for the friend check, so
-- it runs on its own thread.
function NotorietyService.Record(player: Player, kind: NotorietyRules.Kind, victimUserId: number, training: boolean?)
	task.spawn(function()
		local d = deps
		if not d or training or victimUserId <= 0 then return end
		local okFriend, isFriend = pcall(function() return player:IsFriendsWith(victimUserId) end)
		local profile = d.GetProfile(player)
		if not profile or player.Parent ~= Players then return end
		if NotorietyRules.Record(state(profile), kind, victimUserId, os.time(), okFriend and isFriend == true, false) then
			dirty[player] = true
			applyTitle(player)
		end
	end)
end

-- Writes this week's totals for a player whose counts changed. Reads the profile at once (the
-- caller may drop it next) and writes on its own thread.
local function flush(player: Player)
	local d = deps
	local profile = d and d.GetProfile(player)
	if not profile or not dirty[player] then return end
	dirty[player] = nil
	local s = state(profile)
	if s.Week == "" then return end
	local key, week = tostring(player.UserId), s.Week
	local totals = { Thefts = s.WeekThefts, Hunts = s.WeekHunts }
	task.spawn(function()
		for board, value in totals do
			if value > 0 then
				local store = storeFor(board, week)
				if store then pcall(function() store:SetAsync(key, value) end) end
			end
		end
	end)
end

-- Shows the saved title once a profile has loaded (DataManager calls this).
function NotorietyService.Refresh(player: Player)
	applyTitle(player)
end

-- A player leaving: writes their totals before DataManager drops the profile.
function NotorietyService.Forget(player: Player)
	flush(player)
	dirty[player] = nil
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then return cached end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		names[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	names[userId] = if ok and type(name) == "string" then name else "Master"
	return names[userId]
end

local function readBoard(board: string, week: string): { any }
	local rows = {}
	local store = storeFor(board, week)
	if not store then return rows end
	local ok, pages = pcall(function() return store:GetSortedAsync(false, BOARD_SIZE) end)
	if not ok or not pages then return rows end
	local okPage, page = pcall(function() return pages:GetCurrentPage() end)
	if not okPage or type(page) ~= "table" then return rows end
	for rank, entry in page do
		local userId = tonumber(entry.key)
		if userId then
			table.insert(rows, { Rank = rank, UserId = userId, Name = nameOf(userId), Value = entry.value })
		end
	end
	return rows
end

local function refreshBoards()
	local week = NotorietyRules.WeekKey(os.time())
	boards = { Week = week, Thieves = readBoard("Thefts", week), Hunters = readBoard("Hunts", week) }
	if deps then deps.PushBoards(boards) end
end

function NotorietyService.Boards(): any
	return boards
end

function NotorietyService.Init(dependencies: Dependencies)
	deps = dependencies
	local function bind(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			applyTitle(player)
		end)
		if player.Character then task.defer(applyTitle, player) end
	end
	for _, player in Players:GetPlayers() do bind(player) end
	Players.PlayerAdded:Connect(bind)
	task.spawn(function()
		task.wait(5)
		refreshBoards()
		while true do
			task.wait(60)
			for player in dirty do flush(player) end
			refreshBoards()
		end
	end)
end

return NotorietyService
