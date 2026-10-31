--!strict
local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent:WaitForChild("PowerConfig"))
local Utils  = require(script.Parent:WaitForChild("PowerUtils"))

local DataStoreModule = {}

local ORDERED = DataStoreService:GetOrderedDataStore(Config.DS_ORDERED_NAME, Config.DS_SCOPE)
local MAIN    = DataStoreService:GetDataStore(Config.DS_MAIN_NAME, Config.DS_SCOPE)
local ORDERED_STUDIO = DataStoreService:GetOrderedDataStore(Config.DS_ORDERED_NAME, "STUDIO")
local MAIN_STUDIO    = DataStoreService:GetDataStore(Config.DS_MAIN_NAME, "STUDIO")

local livePower:  { [number]: number } = {}
local lastSaveTime: { [number]: number } = {}
local pendingSaves = 0

local onPowerChangedCallback: ((userId: number, power: number) -> ())? = nil

function DataStoreModule.SetOnPowerChangedCallback(cb: (userId: number, power: number) -> ())
	onPowerChangedCallback = cb
end

local function keyOf(userId: number): string
	return "pwr_" .. userId
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
		warn("[PowerDataStore] Load gagal attempt", attempt, result)
		task.wait(0.5 * attempt)
	end
	return 0
end

local function setRaw(userId: number, totalPower: number)
	if userId <= 0 then return end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			local intVal = math.floor(totalPower)
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
		warn("[PowerDataStore] Save gagal attempt", attempt, err)
		task.wait(0.5 * attempt)
	end
end

function DataStoreModule.RecordPower(userId: number, power: number)
	if userId <= 0 or typeof(power) ~= "number" or power < 0 then return end
	local prev = livePower[userId]
	livePower[userId] = power

	if prev ~= power then
		if onPowerChangedCallback then
			onPowerChangedCallback(userId, power)
		end

		-- Persist immediately if never saved or if more than 15s since last save
		local last = lastSaveTime[userId] or 0
		if os.clock() - last >= 15 then
			lastSaveTime[userId] = os.clock()
			task.spawn(function()
				setRaw(userId, power)
			end)
		end
	end
end

function DataStoreModule.GetPower(userId: number): number
	return livePower[userId] or 0
end

function DataStoreModule.IsTracked(userId: number): boolean
	return livePower[userId] ~= nil
end

function DataStoreModule.OnPlayerAdded(player: Player)
	local userId = player.UserId
	if userId <= 0 then return end
	task.spawn(function()
		local stored = loadRaw(userId)
		if (livePower[userId] or 0) <= 0 and stored > 0 then
			livePower[userId] = stored
		end

		local function bindPowerStat(pwrStat: Instance)
			if pwrStat:IsA("NumberValue") or pwrStat:IsA("IntValue") then
				if pwrStat.Value > 0 then
					DataStoreModule.RecordPower(userId, pwrStat.Value)
				end
				pwrStat:GetPropertyChangedSignal("Value"):Connect(function()
					if pwrStat.Value > 0 then
						DataStoreModule.RecordPower(userId, pwrStat.Value)
					end
				end)
			end
		end

		local function bindLeaderstats(ls: Instance)
			local existing = ls:FindFirstChild("Power")
			if existing then
				bindPowerStat(existing)
			end
			ls.ChildAdded:Connect(function(child)
				if child.Name == "Power" then
					bindPowerStat(child)
				end
			end)
		end

		local ls = player:FindFirstChild("leaderstats")
		if ls then
			bindLeaderstats(ls)
		else
			local conn: RBXScriptConnection? = nil
			conn = player.ChildAdded:Connect(function(child)
				if child.Name == "leaderstats" then
					if conn then
						conn:Disconnect()
						conn = nil
					end
					bindLeaderstats(child)
				end
			end)
		end
	end)
end

function DataStoreModule.OnPlayerRemoving(player: Player)
	local userId = player.UserId
	local pwr = livePower[userId]
	if pwr and pwr > 0 then
		pendingSaves += 1
		task.spawn(function()
			setRaw(userId, pwr)
			pendingSaves -= 1
		end)
	end
	livePower[userId] = nil
	lastSaveTime[userId] = nil
end

function DataStoreModule.BindToCloseSaveAll()
	for _, player in ipairs(Players:GetPlayers()) do
		local userId = player.UserId
		local pwr = livePower[userId]
		if pwr and pwr > 0 then
			pendingSaves += 1
			task.spawn(function()
				setRaw(userId, pwr)
				pendingSaves -= 1
			end)
		end
	end
	local waited = 0
	while pendingSaves > 0 and waited < 25 do
		task.wait(0.25)
		waited += 0.25
	end
	print("[PowerDataStore] BindToClose selesai, pendingSaves:", pendingSaves)
end

function DataStoreModule.StartAutoSaveLoop()
	task.spawn(function()
		while true do
			task.wait(Config.SAVE_INTERVAL)
			local players = Players:GetPlayers()
			for i, player in ipairs(players) do
				local uid = player.UserId
				local pwr = livePower[uid]
				if pwr and pwr > 0 then
					task.delay((i - 1) * 0.15, function()
						setRaw(uid, pwr)
					end)
				end
			end
		end
	end)
end

function DataStoreModule.SetPowerManual(userId: number, power: number): (boolean, string)
	if power < 0 then
		return false, "Power tidak boleh negatif"
	end
	livePower[userId] = power
	task.spawn(function()
		setRaw(userId, power)
	end)
	local player = Players:GetPlayerByUserId(userId)
	local name = player and player.Name or ("User" .. userId)
	return true, string.format("Power %s berhasil diatur ke %s", name, Utils.formatPower(power))
end

function DataStoreModule.GetSortedTop(count: number): { { UserId: number, Power: number } }
	-- Sync current online players before querying
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId > 0 then
			local ls = p:FindFirstChild("leaderstats")
			local pwr = ls and ls:FindFirstChild("Power") :: NumberValue?
			if pwr and pwr.Value > 0 then
				livePower[p.UserId] = math.max(livePower[p.UserId] or 0, pwr.Value)
			end
		end
	end

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
					local live = livePower[uid] or 0
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

	-- Also ensure all currently tracked online players with power > 0 are represented
	for userId, pwr in pairs(livePower) do
		if userId > 0 and pwr and pwr > 0 then
			byUser[userId] = math.max(byUser[userId] or 0, pwr)
		end
	end

	local result = {}
	for uid, pwr in pairs(byUser) do
		table.insert(result, { UserId = uid, Power = pwr })
	end

	table.sort(result, function(a, b) return a.Power > b.Power end)
	return result
end

-- Historical profile backfill: reads existing players from Playtime totals and PlayerProfiles_v1
function DataStoreModule.SyncHistoricalProfiles()
	task.spawn(function()
		task.wait(2)
		local okStatFormulas, StatFormulas = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("StatFormulas"))
		end)
		if not okStatFormulas or not StatFormulas then return end

		local scopesToScan = { Config.DS_SCOPE }
		if Config.DS_SCOPE == "STUDIO" then
			table.insert(scopesToScan, "PROD")
		else
			table.insert(scopesToScan, "STUDIO")
		end

		local userIdsToScan = {}
		for _, sc in ipairs(scopesToScan) do
			pcall(function()
				local ptOrdered = DataStoreService:GetOrderedDataStore("PlaytimeTotals_V1", sc)
				local pages = ptOrdered:GetSortedAsync(false, 50)
				if pages then
					for _, e in ipairs(pages:GetCurrentPage()) do
						local uid = Utils.parseUserId(e.key)
						if uid and not table.find(userIdsToScan, uid) then
							table.insert(userIdsToScan, uid)
						end
					end
				end
			end)
		end

		-- Also include known active players and admins
		local knownUids = { 2300599854, 1002761664, 4675946455, 118832016 }
		for _, uid in ipairs(knownUids) do
			if not table.find(userIdsToScan, uid) then
				table.insert(userIdsToScan, uid)
			end
		end
		for uid, _ in pairs(Config.Admin.AdminUserIds) do
			if not table.find(userIdsToScan, uid) then
				table.insert(userIdsToScan, uid)
			end
		end

		local profileStore = DataStoreService:GetDataStore("PlayerProfiles_v1")
		local anyUpdated = false

		for _, uid in ipairs(userIdsToScan) do
			-- Check if power already recorded
			local curPower = livePower[uid] or loadRaw(uid)
			if curPower <= 0 then
				local okProf, profData = pcall(function()
					return profileStore:GetAsync("User_" .. uid)
				end)
				if okProf and typeof(profData) == "table" then
					local prof = (typeof(profData.Data) == "table") and profData.Data or profData
					local squadPower = 0
					if typeof(prof.SquadPower) == "number" and prof.SquadPower > 0 then
						squadPower = prof.SquadPower
					elseif typeof(profData.SquadPower) == "number" and profData.SquadPower > 0 then
						squadPower = profData.SquadPower
					else
						local calcPower = (StatFormulas :: any).GetSquadPower(prof)
						squadPower = calcPower or 0
					end
					if squadPower > 0 then
						DataStoreModule.RecordPower(uid, squadPower)
						setRaw(uid, squadPower)
						anyUpdated = true
					end
				end
				task.wait(0.2)
			end
		end

		if anyUpdated and onPowerChangedCallback then
			onPowerChangedCallback(0, 0)
		end
	end)
end

return DataStoreModule
