local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(script.Parent:WaitForChild("PlaytimeConfig"))
local Utils  = require(script.Parent:WaitForChild("PlaytimeUtils"))

local DataStoreModule = {}

local ORDERED = DataStoreService:GetOrderedDataStore(Config.DS_ORDERED_NAME, Config.DS_SCOPE)
local MAIN    = DataStoreService:GetDataStore(Config.DS_MAIN_NAME, Config.DS_SCOPE)
local ORDERED_STUDIO = DataStoreService:GetOrderedDataStore(Config.DS_ORDERED_NAME, "STUDIO")
local MAIN_STUDIO    = DataStoreService:GetDataStore(Config.DS_MAIN_NAME, "STUDIO")

local sessionStart: { [number]: number } = {}
local totalCache:   { [number]: number } = {}
local pendingSaves = 0

local function keyOf(userId: number): string
	return "pt_" .. userId
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
		warn("[PlaytimeDataStore] Load gagal attempt", attempt, result)
		task.wait(0.5 * attempt)
	end
	return 0
end

local function setRaw(userId: number, totalSeconds: number)
	if userId <= 0 then return end
	local intSec = math.floor(totalSeconds)
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			MAIN:SetAsync(keyOf(userId), intSec)
			ORDERED:SetAsync("u" .. userId, intSec)
			MAIN_STUDIO:SetAsync(keyOf(userId), intSec)
			ORDERED_STUDIO:SetAsync("u" .. userId, intSec)
		end)
		if ok then return end
		if tostring(err):find("Studio access to APIs is not allowed") then
			return
		end
		warn("[PlaytimeDataStore] Save gagal attempt", attempt, err)
		task.wait(0.5 * attempt)
	end
end

local function addRaw(userId: number, addSeconds: number): number?
	local newTotal: number? = nil
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			MAIN:UpdateAsync(keyOf(userId), function(old)
				local base = typeof(old) == "number" and old or 0
				newTotal = base + addSeconds
				return newTotal
			end)
			ORDERED:UpdateAsync("u" .. userId, function(old)
				local base = typeof(old) == "number" and old or 0
				return base + addSeconds
			end)
		end)
		if ok then return newTotal end
		if tostring(err):find("Studio access to APIs is not allowed") then
			return nil
		end
		warn("[PlaytimeDataStore] AddRaw gagal attempt", attempt)
		task.wait(0.5 * attempt)
	end
	return nil
end

local function sessionSeconds(userId: number): number
	local start = sessionStart[userId]
	if not start then return 0 end
	return os.clock() - start
end

function DataStoreModule.GetTotalSeconds(userId: number): number
	return (totalCache[userId] or 0) + sessionSeconds(userId)
end

function DataStoreModule.IsTracked(userId: number): boolean
	return sessionStart[userId] ~= nil
end

function DataStoreModule.OnPlayerAdded(player: Player)
	local userId = player.UserId
	if userId <= 0 then return end
	task.spawn(function()
		totalCache[userId]   = loadRaw(userId)
		sessionStart[userId] = os.clock()
	end)
end

function DataStoreModule.OnPlayerRemoving(player: Player)
	local userId = player.UserId
	if userId <= 0 then return end
	local total = DataStoreModule.GetTotalSeconds(userId)
	pendingSaves += 1
	task.spawn(function()
		setRaw(userId, total)
		pendingSaves -= 1
	end)
	sessionStart[userId] = nil
	totalCache[userId]   = nil
end

function DataStoreModule.BindToCloseSaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		if userId > 0 then
			local total = DataStoreModule.GetTotalSeconds(userId)
			pendingSaves += 1
			task.spawn(function()
				setRaw(userId, total)
				pendingSaves -= 1
			end)
		end
	end
	local waited = 0
	while pendingSaves > 0 and waited < 25 do
		task.wait(0.25)
		waited += 0.25
	end
	print("[PlaytimeDataStore] BindToClose selesai, pendingSaves:", pendingSaves)
end

function DataStoreModule.StartAutoSaveLoop()
	task.spawn(function()
		while true do
			task.wait(Config.SAVE_INTERVAL)
			local players = Players:GetPlayers()
			for i, player in ipairs(players) do
				local userId = player.UserId
				if sessionStart[userId] then
					local total = DataStoreModule.GetTotalSeconds(userId)
					totalCache[userId]   = total
					sessionStart[userId] = os.clock()
					task.delay((i - 1) * 0.15, function() -- sebar biar ga throttle
						setRaw(userId, total)
					end)
				end
			end
		end
	end)
end

function DataStoreModule.AddPlaytimeManual(userId: number, addSeconds: number): (boolean, string)
	if addSeconds <= 0 then
		return false, "Jumlah waktu harus lebih dari 0"
	end

	local player = Players:GetPlayerByUserId(userId)
	if player and sessionStart[userId] then
		totalCache[userId] = (totalCache[userId] or 0) + addSeconds
		local flushTotal = DataStoreModule.GetTotalSeconds(userId)
		task.spawn(function()
			setRaw(userId, flushTotal)
		end)
		return true, string.format("+%s ditambahkan ke %s (online)", Utils.formatHM(addSeconds), player.Name)
	end

	local newTotal = addRaw(userId, addSeconds)
	if newTotal == nil then
		return false, "Gagal menyimpan ke DataStore, coba lagi"
	end
	return true, string.format("+%s ditambahkan (offline), total: %s", Utils.formatHM(addSeconds), Utils.formatHM(newTotal))
end

function DataStoreModule.GetSortedTop(count: number): { { UserId: number, Seconds: number } }
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
					local live = DataStoreModule.GetTotalSeconds(uid)
					local best = math.max(stored, live, byUser[uid] or 0)
					byUser[uid] = best
				end
			end
		end
	end

	collectFromStore(ORDERED)
	collectFromStore(ORDERED_STUDIO)

	-- Also ensure all currently tracked online players are reflected even if not yet saved to OrderedDataStore
	for userId, _ in pairs(sessionStart) do
		if userId > 0 then
			local live = DataStoreModule.GetTotalSeconds(userId)
			if live > 0 then
				byUser[userId] = math.max(byUser[userId] or 0, live)
			end
		end
	end

	local result = {}
	for uid, secs in pairs(byUser) do
		table.insert(result, { UserId = uid, Seconds = secs })
	end

	table.sort(result, function(a, b) return a.Seconds > b.Seconds end)
	return result
end

return DataStoreModule
