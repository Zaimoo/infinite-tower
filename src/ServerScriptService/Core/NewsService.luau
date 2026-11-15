--!strict
-- ServerScriptService/Core/NewsService.luau
-- Server-wide headlines and the Wanted list (docs/first-session-and-social-plan.md B0 and B1,
-- GDD §4.6.1). Every server-wide moment goes through Post: NewsRules merges bursts, orders by
-- priority and sends at most one headline every NewsRules.MIN_GAP seconds to every client.
-- The Wanted list is every open public bounty (CombatSimulation.PublicBounties), pushed when it
-- changes; a client's Hunt request travels it to the thief's floor through the normal travel checks.
--
-- Remotes (ReplicatedStorage.Remotes.NewsRemotes):
--   NewsFeed (server -> client): one NewsRules.Item
--   Wanted (server -> client): { { ThiefUserId, ThiefName, ItemName, FloorId, EndsAt } }
--   NewsRequest (client -> server): ("HUNT", thiefUserId)
--   Boards (server -> client): this week's { Week, Thieves, Hunters } from NotorietyService (B6)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NewsRules = require(ReplicatedStorage.Shared.Util.NewsRules)

export type Dependencies = {
	SendToast: (Player, string, string?) -> (),
	VisitFloor: (Player, number) -> (),
	IsTransitioning: (Player) -> boolean,
	FloorOf: (Player) -> number,
}

local NewsService = {}
local deps: Dependencies? = nil
local queue: { NewsRules.Item } = {}
local lastSentAt = -math.huge
local feedRemote: RemoteEvent? = nil
local wantedRemote: RemoteEvent? = nil
local lastWantedSignature = ""
local lastWanted: { any } = {}
local boardsRemote: RemoteEvent? = nil
local lastBoards: any = nil
local lastHunt: { [Player]: number } = {}

local HUNT_COOLDOWN = 2

-- Queues a headline. Names should be display names; everything else is chosen by the server.
-- `endsIn`: seconds until a countdown (a bounty) runs out.
function NewsService.Post(item: NewsRules.Item, endsIn: number?)
	if endsIn then item.EndsAt = Workspace:GetServerTimeNow() + endsIn end
	NewsRules.Enqueue(queue, item, os.clock())
end

local function bounties(): { any }
	local combat = _G.CombatSimulation
	return if combat and combat.PublicBounties then combat.PublicBounties() else {}
end

local function pushWanted(force: boolean?)
	local list = bounties()
	local parts = {}
	for _, b in list do table.insert(parts, `{b.ThiefUserId}:{b.FloorId}:{b.ItemName}:{math.floor(b.EndsAt)}`) end
	local signature = table.concat(parts, ",")
	lastWanted = list
	if (force or signature ~= lastWantedSignature) and wantedRemote then
		lastWantedSignature = signature
		wantedRemote:FireAllClients(list)
	end
end

local function hunt(player: Player, thiefUserId: any)
	local d = deps
	if not d or type(thiefUserId) ~= "number" or thiefUserId ~= thiefUserId then return end
	local now = os.clock()
	if now - (lastHunt[player] or -math.huge) < HUNT_COOLDOWN then return end
	lastHunt[player] = now
	if thiefUserId == player.UserId then return end
	local target: any = nil
	for _, b in lastWanted do
		if b.ThiefUserId == thiefUserId then target = b end
	end
	if not target then
		d.SendToast(player, "Bounty closed|That thief is no longer wanted", "INFO")
		return
	end
	if d.IsTransitioning(player) then return end
	if d.FloorOf(player) == target.FloorId then
		d.SendToast(player, string.format("Already here|Find %s on this floor", target.ThiefName), "INFO")
		return
	end
	-- The normal travel checks apply (unlocks, boss lock, carried relics, raid entry...).
	d.VisitFloor(player, target.FloorId)
end

-- The weekly Top Thieves / Top Hunters boards (B6), to everyone now and to each player who joins.
function NewsService.PushBoards(boards: any)
	lastBoards = boards
	if boardsRemote then boardsRemote:FireAllClients(boards) end
end

function NewsService.Init(dependencies: Dependencies)
	deps = dependencies
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local folder = remotes:FindFirstChild("NewsRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "NewsRemotes"
		folder.Parent = remotes
	end
	local function event(name: string): RemoteEvent
		local existing = (folder :: Instance):FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then return existing end
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = folder
		return created
	end
	feedRemote = event("NewsFeed")
	wantedRemote = event("Wanted")
	boardsRemote = event("Boards")
	event("NewsRequest").OnServerEvent:Connect(function(player: Player, action: any, value: any)
		if action == "HUNT" then hunt(player, value) end
	end)
	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			if player.Parent ~= Players then return end
			if wantedRemote then wantedRemote:FireClient(player, lastWanted) end
			if boardsRemote and lastBoards then boardsRemote:FireClient(player, lastBoards) end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player) lastHunt[player] = nil end)

	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.5)
			tick += 1
			local item = NewsRules.Next(queue, lastSentAt, os.clock(), Workspace:GetServerTimeNow())
			if item and feedRemote then
				lastSentAt = os.clock()
				feedRemote:FireAllClients({
					Kind = item.Kind, ActorUserId = item.ActorUserId, ActorName = item.ActorName,
					TargetUserId = item.TargetUserId, TargetName = item.TargetName, ItemName = item.ItemName,
					Tier = item.Tier, FloorId = item.FloorId, EndsAt = item.EndsAt, Count = item.Count,
				})
			end
			if tick % 4 == 0 then pushWanted() end -- every 2 s
		end
	end)
end

return NewsService
