--!strict
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config           = require(script.Parent:WaitForChild("DonatedConfig"))
local Utils            = require(script.Parent:WaitForChild("DonatedUtils"))
local LeaderboardRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("LeaderboardRules"))

local DataStoreModule = {}

local ORDERED        = DataStoreService:GetOrderedDataStore(Config.DS_ORDERED_NAME, Config.DS_SCOPE)
local MAIN           = DataStoreService:GetDataStore(Config.DS_MAIN_NAME, Config.DS_SCOPE)
local ORDERED_STUDIO = DataStoreService:GetOrderedDataStore(Config.DS_ORDERED_NAME, "STUDIO")
local MAIN_STUDIO    = DataStoreService:GetDataStore(Config.DS_MAIN_NAME, "STUDIO")

local liveDonated: { [number]: number } = {}
local lastSaveTime: { [number]: number } = {}
local pendingSaves = 0

local onChangedCallback: ((userId: number, amount: number) -> ())? = nil

function DataStoreModule.SetOnChangedCallback(cb: (userId: number, amount: number) -> ())
	onChangedCallback = cb
end

local function keyOf(userId: number): string
	return "don_" .. userId
end

local function loadRaw(userId: number): number
	if userId <= 0 then return 0 end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			local prodVal = MAIN:GetAsync(keyOf(userId))
			local studioVal = MAIN_STUDIO:GetAsync(keyOf(userId))
			local pNum = typeof(prodVal) == "number" and prodVal or 0
			local sNum = typeof(studioVal) == "number" and studioVal or 0
			return math.max(pNum, sNum)
		end)
		if ok then
			return typeof(result) == "number" and result or 0
		end
		if tostring(result):find("Studio access to APIs is not allowed") then
			return 0
		end
		warn("[DonatedDataStore] Load failed attempt", attempt, result)
		task.wait(0.5 * attempt)
	end
	return 0
end

local function setRaw(userId: number, totalDonated: number)
	if userId <= 0 or totalDonated <= 0 then return end
	local intVal = math.floor(totalDonated)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			MAIN:SetAsync(keyOf(userId), intVal)
			ORDERED:SetAsync("u" .. userId, intVal)
			MAIN_STUDIO:SetAsync(keyOf(userId), intVal)
			ORDERED_STUDIO:SetAsync("u" .. userId, intVal)
		end)
		if ok then
			lastSaveTime[userId] = os.clock()
			return
		end
		if tostring(err):find("Studio access to APIs is not allowed") then
			return
		end
		warn("[DonatedDataStore] Save failed attempt", attempt, err)
		task.wait(0.5 * attempt)
	end
end

function DataStoreModule.RecordTotal(userId: number, totalAmount: number)
	if userId <= 0 or typeof(totalAmount) ~= "number" or totalAmount <= 0 then return end
	local best = math.max(liveDonated[userId] or 0, math.floor(totalAmount))
	if liveDonated[userId] ~= best then
		liveDonated[userId] = best
		if onChangedCallback then
			onChangedCallback(userId, best)
		end
		local last = lastSaveTime[userId] or 0
		if os.clock() - last >= 15 then
			lastSaveTime[userId] = os.clock()
			task.spawn(setRaw, userId, best)
		end
	end
end

function DataStoreModule.AddDonated(userId: number, deltaAmount: number)
	if userId <= 0 or typeof(deltaAmount) ~= "number" or deltaAmount <= 0 then return end
	local nextTotal = math.floor((liveDonated[userId] or 0) + deltaAmount)
	liveDonated[userId] = nextTotal
	if onChangedCallback then
		onChangedCallback(userId, nextTotal)
	end
	task.spawn(setRaw, userId, nextTotal)
end

function DataStoreModule.SyncFromProfile(userId: number, profileTotal: number)
	if userId <= 0 or typeof(profileTotal) ~= "number" or profileTotal <= 0 then return end
	DataStoreModule.RecordTotal(userId, profileTotal)
end

function DataStoreModule.GetDonated(userId: number): number
	return liveDonated[userId] or 0
end

function DataStoreModule.IsTracked(userId: number): boolean
	return liveDonated[userId] ~= nil
end

function DataStoreModule.OnPlayerAdded(player: Player)
	local userId = player.UserId
	if userId <= 0 then return end
	task.spawn(function()
		local stored = loadRaw(userId)
		local profileTotal = 0
		local dm = (_G :: any).DataManager
		if dm and dm.GetProfile then
			local prof = dm.GetProfile(player)
			if prof and type(prof.TotalRobuxDonated) == "number" then
				profileTotal = prof.TotalRobuxDonated
			end
		end
		local best = math.max(stored, profileTotal, liveDonated[userId] or 0)
		if best > 0 then
			DataStoreModule.RecordTotal(userId, best)
		end
	end)
end

function DataStoreModule.OnPlayerRemoving(player: Player)
	local userId = player.UserId
	local amount = liveDonated[userId]
	if amount and amount > 0 then
		pendingSaves += 1
		task.spawn(function()
			setRaw(userId, amount)
			pendingSaves -= 1
		end)
	end
	liveDonated[userId] = nil
	lastSaveTime[userId] = nil
end

function DataStoreModule.BindToCloseSaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		local amount = liveDonated[userId]
		if amount and amount > 0 then
			pendingSaves += 1
			task.spawn(function()
				setRaw(userId, amount)
				pendingSaves -= 1
			end)
		end
	end
	local waited = 0
	while pendingSaves > 0 and waited < 25 do
		task.wait(0.25)
		waited += 0.25
	end
end

function DataStoreModule.StartAutoSaveLoop()
	task.spawn(function()
		while true do
			task.wait(Config.SAVE_INTERVAL)
			local players = Players:GetPlayers()
			for i, player in ipairs(players) do
				local uid = player.UserId
				local amount = liveDonated[uid]
				if amount and amount > 0 then
					task.delay((i - 1) * 0.15, function()
						setRaw(uid, amount)
					end)
				end
			end
		end
	end)
end

function DataStoreModule.GetSortedTop(count: number): { { UserId: number, Donated: number } }
	local byUser: { [number]: number } = {}

	local function collectFromStore(store: OrderedDataStore)
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, count)
		end)
		if ok and pages then
			local raw = pages:GetCurrentPage()
			for _, e in ipairs(raw) do
				local uid = Utils.parseUserId(e.key)
				if uid and uid > 0 then
					local stored = typeof(e.value) == "number" and e.value or 0
					local live = liveDonated[uid] or 0
					local best = math.max(stored, live, byUser[uid] or 0)
					if best > 0 then
						byUser[uid] = best
					end
				end
			end
		end
	end

	collectFromStore(ORDERED)
	collectFromStore(ORDERED_STUDIO)

	for userId, amount in pairs(liveDonated) do
		if userId > 0 and amount and amount > 0 then
			byUser[userId] = math.max(byUser[userId] or 0, amount)
		end
	end

	local result = {}
	for uid, amount in pairs(byUser) do
		table.insert(result, { UserId = uid, Donated = amount })
	end

	table.sort(result, function(a, b) return a.Donated > b.Donated end)
	return LeaderboardRules.ClampSorted(result, count)
end

return DataStoreModule
