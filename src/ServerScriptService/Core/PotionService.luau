--!strict
-- ServerScriptService/Core/PotionService.luau
-- Server owner of profile.Potions and profile.Boosts (GDD §4.9). The rules are pure
-- (Shared/Util/PotionRules); this module adds the remote, the rate limit, the countdown and the
-- player attributes the HUD reads.
--
-- Remote (ReplicatedStorage.Remotes.PotionRemotes):
--   PotionRequest (RemoteFunction): action "USE" + potion id. Returns { Ok, Message }.
-- Potion counts and boost time reach the client in the profile sync. Each running boost also sets
-- a player attribute (PotionConfig.Attribute) to its end time on the server clock, so the HUD can
-- count down without a message every second.
--
-- Boost time is counted here, from real elapsed time while the profile is loaded, so it never
-- drains while the player is offline and the device clock has no say.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.PotionConfig)
local PotionRules = require(ReplicatedStorage.Shared.Util.PotionRules)

export type Dependencies = {
	GetProfile: (Player) -> any,
	SendToast: (Player, string, string?) -> (),
	SyncProfile: (Player) -> (), -- progression-only sync: balances changed, the squad did not
}

local PotionService = {}
local deps: Dependencies? = nil

local TICK = 1
local MAX_REQUESTS_PER_SECOND = 4

local recentRequests: { [Player]: { number } } = {}
local lastTick: { [Player]: number } = {}

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

local function writeAttributes(player: Player, profile: any)
	local now = workspace:GetServerTimeNow()
	for _, id in Config.Order do
		local effect = Config.Potions[id].Effect
		local remaining = PotionRules.Remaining(profile, effect)
		player:SetAttribute(Config.Attribute(effect), if remaining > 0 then now + remaining else 0)
	end
end

-- Multiplier a running boost gives (1 when it is off): "Gold", "Gems", "HeroXP" or "PassXP".
function PotionService.Multiplier(player: Player, effect: string): number
	local d = deps
	local profile = d and d.GetProfile(player)
	return if profile then PotionRules.Multiplier(profile, effect) else 1
end

-- Adds the profile's potion and boost tables (old saves) and repairs damaged ones.
function PotionService.EnsureState(profile: any)
	PotionRules.EnsureState(profile)
end

local function handle(player: Player, action: any, arg: any): any
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then return { Ok = false, Message = "Your save is still loading." } end
	if not allowRequest(player) then return { Ok = false, Message = "Slow down." } end
	if action ~= "USE" then return { Ok = false, Message = "Unknown request." } end

	-- The potion is spent and the boost extended in one step (nothing yields between them), so a
	-- repeated request can never drink one potion twice.
	local ok, message = PotionRules.Use(profile, arg)
	if not ok then return { Ok = false, Message = message } end
	writeAttributes(player, profile)
	d.SendToast(player, "Potion|" .. message, "SUCCESS")
	d.SyncProfile(player)
	return { Ok = true, Message = message }
end

function PotionService.Forget(player: Player)
	recentRequests[player] = nil
	lastTick[player] = nil
end

function PotionService.Init(dependencies: Dependencies)
	deps = dependencies

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local folder = remotes:FindFirstChild("PotionRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "PotionRemotes"
		folder.Parent = remotes
	end
	local request = folder:FindFirstChild("PotionRequest") :: RemoteFunction?
	if not request then
		request = Instance.new("RemoteFunction")
		request.Name = "PotionRequest"
		request.Parent = folder
	end
	;(request :: RemoteFunction).OnServerInvoke = handle

	Players.PlayerRemoving:Connect(PotionService.Forget)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local clock = os.clock()
			for _, player in Players:GetPlayers() do
				local profile = dependencies.GetProfile(player)
				if not profile then continue end
				local previous = lastTick[player]
				lastTick[player] = clock
				if not previous then
					-- First tick after the save loaded: start the clock and publish saved boosts.
					writeAttributes(player, profile)
					continue
				end
				if not PotionRules.AnyActive(profile) then continue end
				local expired = PotionRules.Tick(profile, math.min(clock - previous, TICK * 3))
				if #expired == 0 then continue end
				writeAttributes(player, profile)
				for _, effect in expired do
					local potion = Config.ByEffect(effect)
					if potion then dependencies.SendToast(player, "Boost ended|" .. potion.Summary, "INFO") end
				end
				dependencies.SyncProfile(player) -- summon odds and the Backpack follow the profile
			end
		end
	end)
end

return PotionService
