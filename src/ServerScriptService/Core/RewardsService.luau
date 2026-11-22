--!strict
-- ServerScriptService/Core/RewardsService.luau
-- Server owner of profile.Rewards (GDD §4.8): daily calendar, weekly chest, playtime rewards,
-- promo codes and the friend boost. The rules are pure (Shared/Util/RewardRules); this module adds
-- the clock, the remotes, rate limits, playtime counting and the friend lookups.
--
-- Remotes (ReplicatedStorage.Remotes.RewardsRemotes):
--   RewardsRequest (RemoteFunction): action "GET" | "CLAIM_DAILY" | "CLAIM_WEEKLY" |
--       "CLAIM_PLAYTIME" (tier index) | "REDEEM_CODE" (text) | "CLAIM_GROUP_CHEST". Returns { Ok, Message, State }.
--   RewardsSync (RemoteEvent): the same State, pushed on join, at the UTC day rollover and when the
--       friend boost changes.
-- The client only sends requests; every claim is checked here against the server clock (os.time,
-- UTC), so changing the device clock does nothing.

local CollectionService = game:GetService("CollectionService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.RewardsConfig)
local HubLayout = require(ReplicatedStorage.Shared.Config.HubLayout)
local GroupChestMeshHydrator = require(ReplicatedStorage.Assets.GroupChestMeshHydrator)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)
local RewardCodes = require(script.Parent.RewardCodes)

export type Dependencies = {
	GetProfile: (Player) -> any,
	SendToast: (Player, string, string?) -> (),
	SyncProfile: (Player) -> (), -- progression-only sync: balances changed, the squad did not
	OnClaim: ((Player, string, number?) -> ())?, -- after a paid claim, with its action and tier count (Battle Pass XP)
}

local RewardsService = {}
local deps: Dependencies? = nil
local syncRemote: RemoteEvent? = nil

local PLAYTIME_TICK = 5
local MAX_REQUESTS_PER_SECOND = 4
local CODE_COOLDOWN = 2 -- seconds between code attempts, so codes cannot be guessed in bulk

local recentRequests: { [Player]: { number } } = {}
local lastCodeAttempt: { [Player]: number } = {}
local lastTick: { [Player]: number } = {}
local claimingGroupChest: { [Player]: boolean } = {}

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local kept = {}
	for _, t in recentRequests[player] or {} do
		if now - t < 1 then table.insert(kept, t) end
	end
	local allowed = #kept < MAX_REQUESTS_PER_SECOND
	if allowed then table.insert(kept, now) end
	recentRequests[player] = kept
	return allowed
end

--============================================================================
-- Friend boost
--============================================================================

-- friendPairs["lowUserId:highUserId"] = true for every pair of friends in this server.
local friendPairs: { [string]: boolean } = {}
local friendCounts: { [Player]: number } = {}

local function pairKey(a: number, b: number): string
	return if a < b then a .. ":" .. b else b .. ":" .. a
end

local function areFriends(a: Player, b: Player): boolean
	local ok, result = pcall(function() return (a :: any):IsFriendsWithAsync(b.UserId) end)
	if not ok then
		ok, result = pcall(function() return (a :: any):IsFriendsWith(b.UserId) end)
	end
	return ok and result == true
end

-- Studio test servers use fake accounts with no friends: set the Workspace attribute
-- DebugFriendBoost to a friend count to try the boost there. Ignored outside Studio.
local function debugFriends(): number?
	if not RunService:IsStudio() then return nil end
	local value = workspace:GetAttribute("DebugFriendBoost")
	return if type(value) == "number" then value else nil
end

function RewardsService.GetFriendCount(player: Player): number
	return debugFriends() or friendCounts[player] or 0
end

-- Gold multiplier from friends in this server (1.0 with none).
function RewardsService.GetFriendBoostMultiplier(player: Player): number
	return RewardRules.FriendBoost(RewardsService.GetFriendCount(player))
end

local function buildState(player: Player, profile: any): any
	local state = RewardRules.EnsureState(profile)
	local view: any = RewardRules.View(state, os.time())
	view.FriendCount = RewardsService.GetFriendCount(player)
	view.FriendBoost = RewardsService.GetFriendBoostMultiplier(player)
	return view
end

local function push(player: Player)
	local d = deps
	local profile = d and d.GetProfile(player)
	if profile and syncRemote then syncRemote:FireClient(player, buildState(player, profile)) end
end

local function recountFriends()
	local d = deps
	for _, player in Players:GetPlayers() do
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= player and friendPairs[pairKey(player.UserId, other.UserId)] then count += 1 end
		end
		local before = friendCounts[player] or 0
		friendCounts[player] = count
		player:SetAttribute("FriendBoost", RewardRules.FriendBoost(count))
		if count ~= before then
			if d and d.GetProfile(player) then
				local percent = math.round((RewardRules.FriendBoost(count) - 1) * 100)
				if count > before then
					d.SendToast(player, string.format("Friend boost|+%d%% Gold while your friends are here", percent), "SUCCESS")
				elseif percent > 0 then
					d.SendToast(player, string.format("Friend boost|Now +%d%% Gold", percent), "INFO")
				else
					d.SendToast(player, "Friend boost ended|No friends in this server", "INFO")
				end
			end
			push(player)
		end
	end
end

local function onPlayerAdded(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player and areFriends(player, other) and player.Parent == Players and other.Parent == Players then
			friendPairs[pairKey(player.UserId, other.UserId)] = true
		end
	end
	if player.Parent == Players then recountFriends() end
end

local function onPlayerRemoving(player: Player)
	local id = tostring(player.UserId)
	for key in friendPairs do
		local a, b = string.match(key, "^(%-?%d+):(%-?%d+)$")
		if a == id or b == id then friendPairs[key] = nil end
	end
	friendCounts[player] = nil
	recentRequests[player] = nil
	lastCodeAttempt[player] = nil
	lastTick[player] = nil
	claimingGroupChest[player] = nil
	task.defer(recountFriends) -- after the player has left Players
end

--============================================================================
-- Group membership & claim
--============================================================================

local function isPlayerInGroup(player: Player): boolean
	if RunService:IsStudio() and workspace:GetAttribute("DebugInGroup") ~= nil then
		return workspace:GetAttribute("DebugInGroup") == true
	end

	local idsToCheck: { number } = {}
	local seen: { [number]: boolean } = {}
	local function addId(id: number?)
		if type(id) == "number" and id > 0 and not seen[id] then
			seen[id] = true
			table.insert(idsToCheck, id)
		end
	end
	for _, id in Config.GroupIds do
		addId(id)
	end
	if game.CreatorType == Enum.CreatorType.Group then
		addId(game.CreatorId)
	end

	for _, id in idsToCheck do
		local ok, inGroup = pcall(function()
			return player:IsInGroup(id)
		end)
		if ok and inGroup == true then
			return true
		end
	end

	-- Fallback to GroupService:GetGroupsAsync so mid-session group joins take effect immediately.
	local okGroups, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if okGroups and type(groups) == "table" then
		for _, g in groups do
			if type(g) == "table" and type(g.Id) == "number" and seen[g.Id] then
				return true
			end
		end
	end

	return false
end

--============================================================================
-- Claims
--============================================================================

local function reply(player: Player, profile: any, ok: boolean, message: string?): any
	return { Ok = ok, Message = message, State = buildState(player, profile) }
end

local function handle(player: Player, action: any, arg: any): any
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then return { Ok = false, Message = "Your save is still loading." } end
	if not allowRequest(player) then return { Ok = false, Message = "Slow down." } end
	if type(action) ~= "string" then return { Ok = false, Message = "Unknown request." } end

	local state = RewardRules.EnsureState(profile)
	local now = os.time()
	RewardRules.Touch(state, now)
	if action == "GET" then return reply(player, profile, true, nil) end

	local reward: RewardRules.Reward?, problem: string?, title: string, count: number?
	if action == "CLAIM_DAILY" then
		reward, problem = RewardRules.ClaimDaily(state, now)
		title = "Daily reward"
	elseif action == "CLAIM_WEEKLY" then
		reward, problem = RewardRules.ClaimWeekly(state, now)
		title = "Weekly chest"
	elseif action == "CLAIM_PLAYTIME" then
		reward, problem, count = RewardRules.ClaimPlaytime(state, now, arg)
		title = "Playtime reward"
	elseif action == "REDEEM_CODE" then
		local clock = os.clock()
		if clock - (lastCodeAttempt[player] or -math.huge) < CODE_COOLDOWN then
			return reply(player, profile, false, "Wait a moment before trying another code.")
		end
		lastCodeAttempt[player] = clock
		reward, problem = RewardRules.RedeemCode(state, now, arg, RewardCodes)
		title = "Code redeemed"
	elseif action == "CLAIM_GROUP_CHEST" then
		if state.GroupChest.Claimed then
			return reply(player, profile, false, "You already claimed the Group Chest.")
		end
		if claimingGroupChest[player] then
			return reply(player, profile, false, "Claim already in progress.")
		end
		claimingGroupChest[player] = true
		local okCheck, inGroup = pcall(isPlayerInGroup, player)
		claimingGroupChest[player] = nil
		if d.GetProfile(player) ~= profile or player.Parent ~= Players then
			return { Ok = false, Message = "Your save is no longer active." }
		end
		state = RewardRules.EnsureState(profile)
		reward, problem = RewardRules.ClaimGroupChest(state, okCheck and inGroup == true)
		title = "Group chest"
	else
		return { Ok = false, Message = "Unknown request." }
	end
	if not reward then return reply(player, profile, false, problem or "Not available.") end

	-- The claim was recorded and the reward is granted in the same step (nothing yields between
	-- them), so a repeated request can never pay twice.
	RewardRules.Grant(profile, reward)
	local text = RewardRules.Describe(reward)
	d.SendToast(player, title .. "|" .. text, "SUCCESS")
	if d.OnClaim then d.OnClaim(player, action, count) end
	d.SyncProfile(player)
	return reply(player, profile, true, text)
end

--============================================================================
-- Lifecycle
--============================================================================

-- Old saves gain profile.Rewards here too (ProfileMigrations v8 also adds it).
function RewardsService.EnsureState(profile: any)
	RewardRules.EnsureState(profile)
end

-- Resets playtime progress and claimed tiers when a player joins or leaves the server.
function RewardsService.ResetPlaytime(profile: any)
	local state = RewardRules.EnsureState(profile)
	RewardRules.ResetPlaytime(state, os.time())
end

local function resolvePlotCourtyardOrigin(plotIndex: number): CFrame
	local plotsFolder = Workspace:FindFirstChild("WaitingRoomPlots")
	local plot = plotsFolder and plotsFolder:FindFirstChild("Plot_" .. tostring(plotIndex))
	local island = plot and plot:FindFirstChild("FloatingFortressIsland")
	local top = island and island:FindFirstChild("IslandTopSurface")
	if top and top:IsA("BasePart") then
		local surfaceY = top.Position.Y + top.Size.Y * 0.5
		if top.Size.Z > 200 then
			return CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation * CFrame.new(0, 0, -70)
		end
		return CFrame.new(top.Position.X, surfaceY, top.Position.Z) * top.CFrame.Rotation
	end
	local spawn = plot and plot:FindFirstChild("PlotSpawn")
	if spawn and spawn:IsA("BasePart") then
		local surfaceY = spawn.Position.Y - spawn.Size.Y * 0.5
		return CFrame.new(spawn.Position.X, surfaceY, spawn.Position.Z)
			* spawn.CFrame.Rotation
			* CFrame.Angles(0, math.pi, 0)
			* CFrame.new(0, 0, 38)
	end
	return HubLayout.PlotCourtyardCFrame(plotIndex)
end

local function buildGroupChestModel(parent: Instance, name: string, origin: CFrame, scale: number): (Model, ProximityPrompt)
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	GroupChestMeshHydrator.BuildChest(model, origin, scale)

	local collider = Instance.new("Part")
	collider.Name = "ChestCollider"
	collider.Size = Vector3.new(7.0, 5.4, 4.8) * scale
	collider.CFrame = origin * CFrame.new(0, 2.7 * scale, 0)
	collider.Anchored = true
	collider.CanCollide = true
	collider.Transparency = 1
	collider.CastShadow = false
	collider.TopSurface = Enum.SurfaceType.Smooth
	collider.BottomSurface = Enum.SurfaceType.Smooth
	collider.Parent = model

	local coreLightAnchor = Instance.new("Part")
	coreLightAnchor.Name = "CoreLightAnchor"
	coreLightAnchor.Size = Vector3.new(1, 1, 1)
	coreLightAnchor.CFrame = origin * CFrame.new(0, 2.2 * scale, 0)
	coreLightAnchor.Anchored = true
	coreLightAnchor.CanCollide = false
	coreLightAnchor.CanQuery = false
	coreLightAnchor.CanTouch = false
	coreLightAnchor.Transparency = 1
	coreLightAnchor.CastShadow = false
	coreLightAnchor.Massless = true
	coreLightAnchor.Parent = model

	local light = Instance.new("PointLight")
	light.Name = "ChestGlitchLight"
	light.Color = Color3.fromRGB(56, 189, 248)
	light.Brightness = 1.9
	light.Range = 20
	light.Shadows = false
	light.Parent = coreLightAnchor

	local trigger = Instance.new("Part")
	trigger.Name = "GroupChestTrigger"
	trigger.Size = Vector3.new(8.5, 6.0, 6.5) * scale
	trigger.CFrame = origin * CFrame.new(0, 3.0 * scale, 0)
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.CanTouch = false
	trigger.Transparency = 1
	trigger.CastShadow = false
	trigger.Massless = true
	trigger.Parent = model
	model.PrimaryPart = trigger

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GroupChestPrompt"
	prompt.ActionText = "Claim 50K Gold + 2K Gems"
	prompt.ObjectText = "Group Chest"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = trigger

	local anchor = Instance.new("Attachment")
	anchor.Name = "SignAnchor"
	anchor.Position = Vector3.new(0, 4.4 * scale, 0)
	anchor.Parent = trigger

	local board = Instance.new("BillboardGui")
	board.Name = "GroupChestSign"
	board.Size = UDim2.fromOffset(320, 68)
	board.LightInfluence = 0
	board.MaxDistance = 260
	board.Adornee = anchor
	board.Parent = trigger

	local function addSignLabel(labelName: string, y: number, h: number, textSize: number, text: string, color: Color3)
		local label = Instance.new("TextLabel")
		label.Name = labelName
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, y)
		label.Size = UDim2.new(1, 0, 0, h)
		label.Font = Enum.Font.GothamBlack
		label.TextSize = textSize
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.35
		label.Text = text
		label.Parent = board
	end
	addSignLabel("Title", 0, 38, 28, "GROUP CHEST", Color3.fromRGB(130, 220, 255))
	addSignLabel("Subtitle", 40, 26, 16, "+50,000 GOLD · +2,000 GEMS", Color3.fromRGB(255, 225, 130))

	CollectionService:AddTag(model, "GroupChestStation")
	model.Parent = parent
	return model, prompt
end

-- Spawns Group Chest stations in front of the right front-gate Gothic wall bay on each plot.
-- Plot_1 uses `GroupChestStation` under `parent` for direct lookups; Plots 2..N use `GroupChestStation_Plot_N`.
function RewardsService.BuildGroupChestStation(parent: Instance): (Model, ProximityPrompt)
	for _, child in parent:GetChildren() do
		if child.Name == "GroupChestStation" or string.match(child.Name, "^GroupChestStation_Plot_%d+$") then
			child:Destroy()
		end
	end

	local g = HubLayout.GroupChest
	local scale = g.Scale
	local localChestCF = CFrame.lookAt(Vector3.new(g.X, 0, g.Z), Vector3.new(g.X, 0, 0))

	local origin1 = if parent == Workspace
		then resolvePlotCourtyardOrigin(1) * localChestCF
		else HubLayout.GroupChestCFrame(1)
	local primaryModel, primaryPrompt = buildGroupChestModel(parent, "GroupChestStation", origin1, scale)

	if parent == Workspace then
		for i = 2, HubLayout.PlotCount do
			local plotOrigin = resolvePlotCourtyardOrigin(i) * localChestCF
			buildGroupChestModel(parent, "GroupChestStation_Plot_" .. tostring(i), plotOrigin, scale)
		end
	end

	return primaryModel, primaryPrompt
end

function RewardsService.Init(dependencies: Dependencies)
	deps = dependencies

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local folder = remotes:FindFirstChild("RewardsRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "RewardsRemotes"
		folder.Parent = remotes
	end
	local request = folder:FindFirstChild("RewardsRequest") :: RemoteFunction?
	if not request then
		request = Instance.new("RemoteFunction")
		request.Name = "RewardsRequest"
		request.Parent = folder
	end
	local sync = folder:FindFirstChild("RewardsSync") :: RemoteEvent?
	if not sync then
		sync = Instance.new("RemoteEvent")
		sync.Name = "RewardsSync"
		sync.Parent = folder
	end
	syncRemote = sync
	;(request :: RemoteFunction).OnServerInvoke = handle

	for _, player in Players:GetPlayers() do task.spawn(onPlayerAdded, player) end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Playtime: add the real time since the last tick to every loaded profile. Time before the save
	-- loads is not counted. The autosave persists it with the rest of the profile.
	task.spawn(function()
		while true do
			task.wait(PLAYTIME_TICK)
			local clock = os.clock()
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local profile = dependencies.GetProfile(player)
				if not profile then continue end
				local state = RewardRules.EnsureState(profile)
				local previous = lastTick[player]
				lastTick[player] = clock
				local rolledOver = state.Playtime.Day ~= 0 and state.Playtime.Day ~= RewardRules.DayOf(now)
				-- The first tick after loading only starts the clock (and the day).
				RewardRules.AddPlaytime(state, now, if previous then math.min(clock - previous, PLAYTIME_TICK * 3) else 0)
				if rolledOver or not previous then push(player) end
				-- A player who joins friends hears about the boost once their save is in.
				local friends = RewardsService.GetFriendCount(player)
				if not previous and friends > 0 then
					dependencies.SendToast(player, string.format("Friend boost|+%d%% Gold while your friends are here",
						math.round((RewardRules.FriendBoost(friends) - 1) * 100)), "SUCCESS")
				end
			end
		end
	end)

	RewardsService.BuildGroupChestStation(Workspace)
end

return RewardsService
