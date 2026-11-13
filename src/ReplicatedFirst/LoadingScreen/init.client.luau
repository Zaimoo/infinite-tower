--!strict
-- ReplicatedFirst/LoadingScreen (LocalScript)
-- The join loading screen. Replaces Roblox's default loader, covers the HUD while the game loads,
-- preloads the critical assets in PreloadManifest, then executes the diagonal curtain wipe-across
-- reveal and sets the LocalPlayer attribute "ClientLoaded" so popups (OfflineRewardModal,
-- OnboardingGuide) wait for it.
-- A slow asset never blocks: Skip appears after SKIP_AFTER seconds and the screen always closes
-- by HARD_CAP. Background assets keep preloading after the reveal.
-- While it is up, PreviewWarmup renders every hero and weapon template behind it, so their meshes
-- and textures are decoded before a hero card or artifact card first shows them.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local SKIP_AFTER = 8 -- seconds before the Skip button appears
local HARD_CAP = 20 -- seconds before the screen closes no matter what
local LOADED_GUARD = 15 -- longest wait for game.Loaded
local CHARACTER_GUARD = 3 -- brief wait for character / Waiting Room camera to settle
local MIN_VISIBLE = 1.35 -- keep the centered logo up long enough to read cleanly, even on warm cache
local CHUNK = 20 -- assets per PreloadAsync call
local WIPE_TIME = 0.60
local WARMUP_DISPLAY_ORDER = -1000 -- under the HUD as well as under this screen
local WARMUP_LINGER = 2 -- seconds the warm-up keeps rendering after the critical pass

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
