--!strict
-- ReplicatedFirst/LoadingScreen (LocalScript)
-- The join loading screen. Replaces Roblox's default loader, covers the HUD while the game loads,
-- preloads the critical assets in PreloadManifest, then executes the diagonal curtain wipe-across
-- reveal and sets the LocalPlayer attribute "ClientLoaded" so popups (OfflineRewardModal,
-- OnboardingGuide) wait for it.
-- The screen stays up until the critical assets and the hub have finished loading. Skip appears after
-- SKIP_AFTER seconds, and HARD_CAP is only a safety net against a stalled connection. Background
-- assets keep preloading after the reveal.
-- While it is up, PreviewWarmup renders every hero and weapon template behind it, so their meshes
-- and textures are decoded before a hero card or artifact card first shows them.
-- It also streams the whole hub in (HubLayout.StreamPreloadPoints), so walking past plots and the tower
-- later does not hitch on streaming bursts; the place keeps it loaded (StreamOutBehavior = LowMemory).
-- A stream request can return before its area has fully arrived, so the hub counts as loaded once every
-- request is done and no hub part has streamed in for HUB_SETTLE_QUIET seconds.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local SKIP_AFTER = 8 -- seconds before the Skip button appears
local HARD_CAP = 90 -- safety net: seconds before the screen closes no matter what
local LOADED_GUARD = 15 -- longest wait for game.Loaded
local CHARACTER_GUARD = 3 -- brief wait for character / Waiting Room camera to settle
local MIN_VISIBLE = 1.35 -- keep the centered logo up long enough to read cleanly, even on warm cache
local CHUNK = 20 -- assets per PreloadAsync call
local WIPE_TIME = 0.60
local WARMUP_DISPLAY_ORDER = -1000 -- under the HUD as well as under this screen
local WARMUP_LINGER = 2 -- seconds the warm-up keeps rendering after the critical pass
local HUB_STREAM_PARALLEL = 6 -- stream requests in flight at once
local HUB_REQUEST_TIMEOUT = 30 -- longest a single stream request may take
local HUB_SETTLE_QUIET = 1 -- seconds with no hub part arriving before the hub counts as loaded
-- Server-built hub geometry; client effects live elsewhere, so arrivals here are streaming.
local HUB_CONTAINERS = { "WaitingRoomPlots", "BaseOverhaulGeometry" }

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LoadingScreenView = require(script:WaitForChild("LoadingScreenView"))
local PreviewWarmup = require(script:WaitForChild("PreviewWarmup"))
local view = LoadingScreenView.new(playerGui)

local startedAt = os.clock()
local finished = false
local closing = false -- true once the diagonal wipe reveal begins; prevents warmup grid peeking

local function finish()
	finished = true
end

-- Preload the loading screen's own stickman cutout logo so it reveals razor-sharp without pop-in.
pcall(function()
	ContentProvider:PreloadAsync(view.PreloadTargets)
end)
view:RevealLogo()

local failedIds: { string } = {}
local function preload(list: { any })
	local total = #list
	if total == 0 then
		return
	end
	local i = 1
	while i <= total do
		local chunk = table.move(list, i, math.min(i + CHUNK - 1, total), 1, {})
		pcall(function()
			ContentProvider:PreloadAsync(chunk, function(contentId: string, fetchStatus: Enum.AssetFetchStatus)
				if fetchStatus == Enum.AssetFetchStatus.Failure or fetchStatus == Enum.AssetFetchStatus.TimedOut then
					table.insert(failedIds, contentId)
				end
			end)
		end)
		i += CHUNK
	end
end

local backgroundTargets: { any } = {}
local warmup: PreviewWarmup.Warmup? = nil
local criticalDone = false

-- Render every hero and weapon template behind the screen (see PreviewWarmup).
local function startWarmup()
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local folders: { Instance } = {}
	for _, name in { "Heroes", "Weapons" } do
		local folder = assets and assets:FindFirstChild(name)
		if folder then
			table.insert(folders, folder)
		end
	end
	local ok, result = pcall(PreviewWarmup.Start, playerGui, WARMUP_DISPLAY_ORDER, folders)
	if not ok then
		warn(`[LoadingScreen] preview warm-up failed: {result}`)
		return
	end
	warmup = result
	if closing then
		result.Shrink() -- reveal started while building: keep it tucked out of sight
	end
end

-- Streams the hub in behind the screen, a few points at a time, and returns once it has all arrived (every
-- request done, then HUB_SETTLE_QUIET seconds without a hub part streaming in) or the player skips.
local function streamHub(configFolder: Instance?)
	local module = configFolder and configFolder:WaitForChild("HubLayout", 10)
	if not (module and module:IsA("ModuleScript")) then
		return
	end
	local ok, result = pcall(function()
		return (require :: any)(module).StreamPreloadPoints()
	end)
	if not ok then
		warn(`[LoadingScreen] hub stream points failed: {result}`)
		return
	end
	local points = result :: { Vector3 }

	local lastArrival = os.clock()
	local connections: { RBXScriptConnection } = {}
	for _, name in HUB_CONTAINERS do
		local container = workspace:FindFirstChild(name)
		if container then
			table.insert(connections, container.DescendantAdded:Connect(function(inst)
				if inst:IsA("BasePart") then
					lastArrival = os.clock()
				end
			end))
		end
	end

	local nextIndex = 1
	local inFlight = 0
	local function worker()
		while nextIndex <= #points and not finished do
			local point = points[nextIndex]
			nextIndex += 1
			local requested, err = pcall(player.RequestStreamAroundAsync, player, point, HUB_REQUEST_TIMEOUT)
			if not requested then
				warn(`[LoadingScreen] hub stream request failed: {err}`)
			end
		end
		inFlight -= 1
	end
	for _ = 1, math.min(HUB_STREAM_PARALLEL, #points) do
		inFlight += 1
		task.spawn(worker)
	end
	while not finished and (inFlight > 0 or os.clock() - lastArrival < HUB_SETTLE_QUIET) do
		task.wait(0.05)
	end
	for _, connection in connections do
		connection:Disconnect()
	end
end

task.spawn(function()
	-- Wait for the DataModel to finish its first replication.
	if not game:IsLoaded() then
		local loadedAt = os.clock()
		while not game:IsLoaded() and os.clock() - loadedAt < LOADED_GUARD do
			task.wait(0.05)
		end
	end

	-- Preload critical assets and warm up hero/weapon ViewportFrames.
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared", 10)
	local utilFolder = Shared and Shared:WaitForChild("Util", 10)
	local manifestModule = utilFolder and utilFolder:WaitForChild("PreloadManifest", 10)
	if manifestModule and manifestModule:IsA("ModuleScript") then
		local ok, result = pcall(function()
			return require(manifestModule :: ModuleScript).Collect()
		end)
		if ok then
			backgroundTargets = result.Background
			startWarmup() -- after Collect, which has waited for the template folders
			preload(result.Critical)
		else
			warn(`[LoadingScreen] manifest failed: {result}`)
		end
	end
	criticalDone = true

	-- Stream every plot, the Commons and the tower in now rather than in bursts while walking.
	streamHub(Shared and Shared:FindFirstChild("Config"))

	-- Give the player character / Waiting Room camera a brief moment to spawn behind the curtain.
	local charWaitStart = os.clock()
	while not finished and not player.Character and os.clock() - charWaitStart < CHARACTER_GUARD do
		task.wait(0.05)
	end

	finish()
end)

-- Skip after SKIP_AFTER seconds; close by HARD_CAP regardless.
task.delay(SKIP_AFTER, function()
	if not finished then
		view:ShowSkip(finish)
	end
end)
while not finished and os.clock() - startedAt < HARD_CAP do
	task.wait(0.05)
end

local remaining = MIN_VISIBLE - (os.clock() - startedAt)
if remaining > 0 then
	task.wait(remaining)
end

-- Shrink PreviewWarmup before the diagonal curtain uncovers the 3D world so no warmup grid peeks through.
closing = true
if warmup then
	warmup.Shrink()
end

view:FadeOut(WIPE_TIME)
view:Destroy()
player:SetAttribute("ClientLoaded", true)

task.spawn(function()
	while not criticalDone do
		task.wait(0.25)
	end
	task.wait(WARMUP_LINGER)
	if warmup then
		warmup.Destroy()
	end
end)

if #failedIds > 0 then
	warn(`[LoadingScreen] {#failedIds} asset(s) failed to preload: {table.concat(failedIds, ", ", 1, math.min(#failedIds, 12))}`)
end

-- Background assets: no UI, no cap. Wait for the critical pass's targets to be known if skipped early.
task.spawn(function()
	local waited = 0
	while #backgroundTargets == 0 and waited < 30 do
		task.wait(0.5)
		waited += 0.5
	end
	preload(backgroundTargets)
end)
