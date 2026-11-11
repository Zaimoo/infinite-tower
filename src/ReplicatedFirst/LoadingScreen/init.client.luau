--!strict
-- ReplicatedFirst/LoadingScreen (LocalScript)
-- The join loading screen. Replaces Roblox's default loader, covers the HUD while the game loads,
-- preloads the critical assets in PreloadManifest, then fades out and sets the LocalPlayer
-- attribute "ClientLoaded" so popups (OfflineRewardModal, OnboardingGuide) wait for it.
-- A slow asset never blocks: Skip appears after SKIP_AFTER seconds and the screen always closes
-- by HARD_CAP. Background assets keep preloading after the fade.
-- While it is up, PreviewWarmup renders every hero and weapon template behind it, so their meshes
-- and textures are decoded before a hero card or artifact card first shows them.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local SKIP_AFTER = 8 -- seconds before the Skip button appears
local HARD_CAP = 20 -- seconds before the screen closes no matter what
local LOADED_GUARD = 15 -- longest wait for game.Loaded
local MIN_VISIBLE = 1.2 -- keep the screen up long enough to read, even on a warm cache
local CHUNK = 20 -- assets per PreloadAsync call, so the bar moves steadily
local FADE_TIME = 0.6
local WARMUP_DISPLAY_ORDER = -1000 -- under the HUD as well as under this screen
local WARMUP_LINGER = 2 -- seconds the warm-up keeps rendering after the critical pass

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LoadingScreenView = require(script:WaitForChild("LoadingScreenView"))
local PreviewWarmup = require(script:WaitForChild("PreviewWarmup"))
local view = LoadingScreenView.new(playerGui)

local startedAt = os.clock()
local target = 0 -- real progress (0..1)
local shown = 0 -- what the bar draws; eases toward target and never goes backwards
local finished = false
local closed = false -- the view is gone; a critical pass still running after Skip stays silent

local barConn = RunService.RenderStepped:Connect(function(dt: number)
	shown = math.max(shown, shown + (target - shown) * math.min(1, dt * 8))
	view:SetProgress(shown)
end)

local function setTarget(alpha: number, status: string?)
	if closed then
		return
	end
	target = math.max(target, math.clamp(alpha, 0, 1))
	if status then
		view:SetStatus(`{status} {math.floor(target * 100 + 0.5)}%`)
	end
end

local function finish()
	finished = true
end

-- 0-5%: the screen's own logo and fonts, so it never sits blank.
pcall(function()
	ContentProvider:PreloadAsync(view.PreloadTargets)
end)
setTarget(0.05, "Opening the gates…")

local failedIds: { string } = {}
-- Preload `list` in chunks. With a status, progress maps onto the bar from `from` to `to`;
-- without one (the background pass) it runs silently.
local function preload(list: { any }, from: number, to: number, status: string?)
	local total = #list
	if total == 0 then
		if status then
			setTarget(to, status)
		end
		return
	end
	local done = 0
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
		done += #chunk
		i += CHUNK
		if status then
			setTarget(from + (to - from) * done / total, status)
		end
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
	if closed then
		result.Shrink() -- skipped while it was being built: nothing covers it any more
	end
end

task.spawn(function()
	-- 5-20%: wait for the DataModel to finish its first replication.
	if not game:IsLoaded() then
		local creep = task.spawn(function()
			while true do
				setTarget(math.min(0.19, target + 0.004), "Reaching the tower…")
				task.wait(0.1)
			end
		end)
		local loadedAt = os.clock()
		while not game:IsLoaded() and os.clock() - loadedAt < LOADED_GUARD do
			task.wait(0.1)
		end
		task.cancel(creep)
	end
	setTarget(0.2, "Reaching the tower…")

	-- 20-100%: the critical manifest.
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared", 10)
	local manifestModule = Shared and Shared:WaitForChild("Util", 10)
	manifestModule = manifestModule and manifestModule:WaitForChild("PreloadManifest", 10)
	if manifestModule and manifestModule:IsA("ModuleScript") then
		local ok, result = pcall(function()
			return require(manifestModule :: ModuleScript).Collect()
		end)
		if ok then
			backgroundTargets = result.Background
			startWarmup() -- after Collect, which has waited for the template folders
			preload(result.Critical, 0.2, 1, "Summoning heroes…")
		else
			warn(`[LoadingScreen] manifest failed: {result}`)
		end
	end
	criticalDone = true
	setTarget(1, "Ready")
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
setTarget(1)
local remaining = MIN_VISIBLE - (os.clock() - startedAt)
task.wait(math.max(remaining, 0.25)) -- let the bar ease to full

view:FadeOut(FADE_TIME)
closed = true
barConn:Disconnect()
view:Destroy()
player:SetAttribute("ClientLoaded", true)

-- Nothing covers the warm-up any more, so shrink it; it goes once the critical pass has fetched
-- everything (which may still be running after a Skip) and it has had a moment to render.
if warmup then
	warmup.Shrink()
end
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
	preload(backgroundTargets, 0, 1, nil)
end)
