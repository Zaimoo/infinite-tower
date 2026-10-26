local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config          = require(script.Parent:WaitForChild("PlaytimeConfig"))
local DataStoreModule  = require(script.Parent:WaitForChild("PlaytimeDataStore"))
local Renderer         = require(script.Parent:WaitForChild("PlaytimeBoardRenderer"))

local remotesFolder = ReplicatedStorage:FindFirstChild("PlaytimeRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "PlaytimeRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreate(className: string, name: string): Instance
	local existing = remotesFolder:FindFirstChild(name)
	if existing then return existing end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = remotesFolder
	return inst
end

local RF_GetOnlinePlayers = getOrCreate("RemoteFunction", "RF_GetOnlinePlayers") :: RemoteFunction
local RE_AddPlaytime      = getOrCreate("RemoteEvent", "RE_AddPlaytime") :: RemoteEvent
local RE_RequestRefresh   = getOrCreate("RemoteEvent", "RE_RequestRefresh") :: RemoteEvent
local RE_Notify           = getOrCreate("RemoteEvent", "RE_Notify") :: RemoteEvent

local function isAdmin(player: Player): boolean
	return Config.Admin.AdminUserIds[player.UserId] == true or player.UserId == game.CreatorId
end

Players.PlayerAdded:Connect(DataStoreModule.OnPlayerAdded)
Players.PlayerRemoving:Connect(DataStoreModule.OnPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	DataStoreModule.OnPlayerAdded(player)
end

game:BindToClose(function()
	DataStoreModule.BindToCloseSaveAll()
end)

DataStoreModule.StartAutoSaveLoop()

Renderer.Start()

RF_GetOnlinePlayers.OnServerInvoke = function(player: Player)
	if not isAdmin(player) then return {} end
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, {
			UserId      = p.UserId,
			Name        = p.Name,
			DisplayName = p.DisplayName,
		})
	end
	table.sort(list, function(a, b) return a.Name < b.Name end)
	return list
end

local refreshCooldown: { [number]: number } = {}

RE_RequestRefresh.OnServerEvent:Connect(function(player: Player)
	if not isAdmin(player) then return end
	local last = refreshCooldown[player.UserId] or 0
	if os.clock() - last < Config.Admin.RefreshCooldown then
		RE_Notify:FireClient(player, "Tunggu Sebentar", "Refresh masih cooldown", false)
		return
	end
	refreshCooldown[player.UserId] = os.clock()
	Renderer.FullRender()
	RE_Notify:FireClient(player, "Leaderboard Diperbarui", "Playtime leaderboard berhasil di-refresh", true)
end)

RE_AddPlaytime.OnServerEvent:Connect(function(player: Player, targetUserId: number, hours: number, minutes: number)
	if not isAdmin(player) then
		RE_Notify:FireClient(player, "Akses Ditolak", "Kamu tidak punya izin untuk fitur ini", false)
		return
	end
	if typeof(targetUserId) ~= "number" or typeof(hours) ~= "number" or typeof(minutes) ~= "number" then
		return
	end
	hours   = math.clamp(math.floor(hours), 0, 100000)
	minutes = math.clamp(math.floor(minutes), 0, 100000)
	local addSeconds = (hours * 3600) + (minutes * 60)

	local ok, message = DataStoreModule.AddPlaytimeManual(targetUserId, addSeconds)
	RE_Notify:FireClient(player, ok and "Berhasil" or "Gagal", message, ok)

	if ok then
		Renderer.FullRender()
	end
end)
