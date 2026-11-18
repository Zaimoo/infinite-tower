--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config          = require(script.Parent:WaitForChild("DonatedConfig"))
local DataStoreModule = require(script.Parent:WaitForChild("DonatedDataStore"))
local Renderer        = require(script.Parent:WaitForChild("DonatedBoardRenderer"))

local remotesFolder = ReplicatedStorage:FindFirstChild("DonatedRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "DonatedRemotes"
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

local RE_RequestDonatedRefresh = getOrCreate("RemoteEvent", "RE_RequestDonatedRefresh") :: RemoteEvent
local RE_DonatedNotify         = getOrCreate("RemoteEvent", "RE_DonatedNotify") :: RemoteEvent

local function isAdmin(player: Player): boolean
	return Config.Admin.AdminUserIds[player.UserId] == true or player.UserId == game.CreatorId
end

(_G :: any).DonatedLeaderboard = {
	AddDonated = DataStoreModule.AddDonated,
	SyncFromProfile = DataStoreModule.SyncFromProfile,
	QueueRender = Renderer.QueueRender,
}

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

local refreshCooldown: { [number]: number } = {}

RE_RequestDonatedRefresh.OnServerEvent:Connect(function(player: Player)
	if not isAdmin(player) then return end
	local last = refreshCooldown[player.UserId] or 0
	if os.clock() - last < Config.Admin.RefreshCooldown then
		RE_DonatedNotify:FireClient(player, "Please Wait", "Refresh is still on cooldown", false)
		return
	end
	refreshCooldown[player.UserId] = os.clock()
	Renderer.FullRender()
	RE_DonatedNotify:FireClient(player, "Leaderboard Updated", "Top Robux Donated refreshed", true)
end)
