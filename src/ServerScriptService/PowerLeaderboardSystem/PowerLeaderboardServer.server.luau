--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config          = require(script.Parent:WaitForChild("PowerConfig"))
local DataStoreModule  = require(script.Parent:WaitForChild("PowerDataStore"))
local Renderer         = require(script.Parent:WaitForChild("PowerBoardRenderer"))

local remotesFolder = ReplicatedStorage:FindFirstChild("PowerRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "PowerRemotes"
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

local RE_RequestPowerRefresh = getOrCreate("RemoteEvent", "RE_RequestPowerRefresh") :: RemoteEvent
local RE_PowerNotify         = getOrCreate("RemoteEvent", "RE_PowerNotify") :: RemoteEvent

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
DataStoreModule.SyncHistoricalProfiles()
Renderer.Start()

local refreshCooldown: { [number]: number } = {}

RE_RequestPowerRefresh.OnServerEvent:Connect(function(player: Player)
	if not isAdmin(player) then return end
	local last = refreshCooldown[player.UserId] or 0
	if os.clock() - last < Config.Admin.RefreshCooldown then
		RE_PowerNotify:FireClient(player, "Tunggu Sebentar", "Refresh masih cooldown", false)
		return
	end
	refreshCooldown[player.UserId] = os.clock()
	Renderer.FullRender()
	RE_PowerNotify:FireClient(player, "Leaderboard Diperbarui", "Power leaderboard berhasil di-refresh", true)
end)
