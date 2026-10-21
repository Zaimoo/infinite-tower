--!strict
-- StarterPlayerScripts/Rendering/PlotBeaconController.client.luau
-- Client floating avatar beacon rendering above claimed Fortress Plots,
-- distance-to-home marker for local player, distance & range limits for other owners,
-- and client-side gate collision / prompt access enforcement.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GothicBoxStyle = require(Shared:WaitForChild("Util"):WaitForChild("GothicBoxStyle"))
local Palette = GothicBoxStyle.Palette

local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")

--------------------------------------------------------------------------------
-- TUNABLE RANGE CONSTANTS
--------------------------------------------------------------------------------
-- Other players' beacons are only visible to nearby island neighbors (left and right).
-- Radius 540 ring with 60 deg spacing has neighbors ~540 studs apart, next ~935 studs apart.
local OTHER_BEACON_MAX_DISTANCE = 700
local LOCAL_BEACON_MAX_DISTANCE = 1500
local FADE_PERCENT_RANGE = 0.15 -- Smooth fade over the last 15% (595 to 700 studs)

local OTHER_BEACON_FADE_START = OTHER_BEACON_MAX_DISTANCE * (1 - FADE_PERCENT_RANGE) -- 595 studs
local OTHER_BEACON_FADE_SPAN = OTHER_BEACON_MAX_DISTANCE - OTHER_BEACON_FADE_START -- 105 studs

local HEADSHOT_PLACEHOLDER = "rbxasset://textures/ui/PlayerList/NewEmptyHeadShot.png"

--------------------------------------------------------------------------------
-- STATE & TYPES
--------------------------------------------------------------------------------
type BeaconData = {
	PlotModel: Model,
	Billboard: BillboardGui,
	RootGroup: CanvasGroup,
	DistanceLabel: TextLabel,
	IsLocal: boolean,
	CenterPosition: Vector3,
	UserId: number,
}

local activeBeacons: { [Model]: BeaconData } = {}
local thumbnailCache: { [number]: string } = {}
local pendingThumbnailCallbacks: { [number]: { (string) -> () } } = {}

-- Cached thumbnail loader to ensure 0 per-frame thumbnail calls
local function getAvatarThumbnail(userId: number, onLoaded: (string) -> ())
	if userId <= 0 then
		onLoaded(HEADSHOT_PLACEHOLDER)
		return
	end

	if thumbnailCache[userId] then
		onLoaded(thumbnailCache[userId])
		return
	end

	if pendingThumbnailCallbacks[userId] then
		table.insert(pendingThumbnailCallbacks[userId], onLoaded)
		return
	end

	pendingThumbnailCallbacks[userId] = { onLoaded }

	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size150x150
			)
		end)

		local finalUrl = (ok and content and content ~= "") and content or HEADSHOT_PLACEHOLDER
		if ok and content and content ~= "" then
			thumbnailCache[userId] = finalUrl
		end

		local callbacks = pendingThumbnailCallbacks[userId]
		pendingThumbnailCallbacks[userId] = nil
		if callbacks then
			for _, cb in ipairs(callbacks) do
				task.spawn(cb, finalUrl)
			end
		end
	end)
end

-- Finds the center anchor part of the plot island to serve as Adornee.
-- Prioritizes PlotBeaconAnchor (ModelStreamingMode = Persistent) which never streams out.
local function getPlotAnchor(plotModel: Model): BasePart?
	local anchorModel = plotModel:FindFirstChild("PlotBeaconAnchor")
	if anchorModel then
		local part = anchorModel:FindFirstChild("AnchorPart")
		if part and part:IsA("BasePart") then
			return part
		end
		if anchorModel:IsA("BasePart") then
			return anchorModel
		end
	end

	local island = plotModel:FindFirstChild("FloatingFortressIsland")
	if island then
		local surface = island:FindFirstChild("IslandTopSurface")
		if surface and surface:IsA("BasePart") then
			return surface
		end
	end

	local spawn = plotModel:FindFirstChild("PlotSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn
	end

	local pad = plotModel:FindFirstChild("PrivateExtractionPad")
	if pad and pad:IsA("BasePart") then
		return pad
	end

	return plotModel:FindFirstChildWhichIsA("BasePart", true)
end

local function destroyBeacon(plotModel: Model)
	local data = activeBeacons[plotModel]
	if data then
		if data.Billboard and data.Billboard.Parent then
			data.Billboard:Destroy()
		end
		activeBeacons[plotModel] = nil
	end

	local existing = PlayerGui:FindFirstChild("PlotBeacon_" .. plotModel.Name)
	if existing then
		existing:Destroy()
	end
end

local function buildBeacon(plotModel: Model)
	local ownerUserId = plotModel:GetAttribute("OwnerUserId") :: number?
	local ownerName = plotModel:GetAttribute("OwnerName") :: string?

	-- Fallback check on PlotBeaconAnchor if plotModel attributes are still replicating
	if not ownerUserId or ownerUserId <= 0 then
		local anchor = plotModel:FindFirstChild("PlotBeaconAnchor")
		if anchor then
			ownerUserId = anchor:GetAttribute("OwnerUserId") :: number?
			ownerName = anchor:GetAttribute("OwnerName") :: string?
		end
	end

	-- Unclaimed plots show no beacon
	if not ownerUserId or ownerUserId <= 0 then
		destroyBeacon(plotModel)
		return
	end

	-- If already built for this exact user, do not recreate
	local existing = activeBeacons[plotModel]
	if existing and existing.UserId == ownerUserId and existing.Billboard and existing.Billboard.Parent then
		return
	end

	destroyBeacon(plotModel)

	local adornee = getPlotAnchor(plotModel)
	if not adornee then
		-- Retry asynchronously when parts replicate
		task.spawn(function()
			local retries = 0
			while retries < 15 and not adornee do
				task.wait(0.2)
				retries += 1
				adornee = getPlotAnchor(plotModel)
			end
			if adornee and (plotModel:GetAttribute("OwnerUserId") == ownerUserId or (plotModel:FindFirstChild("PlotBeaconAnchor") and plotModel.PlotBeaconAnchor:GetAttribute("OwnerUserId") == ownerUserId)) then
				buildBeacon(plotModel)
			end
		end)
		return
	end

	local isLocal = (ownerUserId == LocalPlayer.UserId)
	local displayName = (ownerName and ownerName ~= "Unclaimed") and ownerName or ("Player " .. tostring(ownerUserId))

	-- 1. Fixed Pixel Size BillboardGui (AlwaysOnTop)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlotBeacon_" .. plotModel.Name
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = isLocal and LOCAL_BEACON_MAX_DISTANCE or OTHER_BEACON_MAX_DISTANCE
	billboard.Size = UDim2.new(0, 136, 0, 136)
	billboard.StudsOffset = Vector3.new(0, 50, 0)
	billboard.ResetOnSpawn = false
	billboard.Active = false
	billboard.Adornee = adornee

	-- CanvasGroup root allows smooth group transparency fading over the last 15% range
	local rootGroup = Instance.new("CanvasGroup")
	rootGroup.Name = "RootGroup"
	rootGroup.Size = UDim2.new(1, 0, 1, 0)
	rootGroup.BackgroundTransparency = 1
	rootGroup.GroupTransparency = 0
	rootGroup.Parent = billboard

	-- 2. Circular Avatar Frame with Gothic border
	local avatarSize = 84
	local avatarFrame = Instance.new("Frame")
	avatarFrame.Name = "AvatarFrame"
	avatarFrame.AnchorPoint = Vector2.new(0.5, 0)
	avatarFrame.Position = UDim2.new(0.5, 0, 0, 0)
	avatarFrame.Size = UDim2.new(0, avatarSize, 0, avatarSize)
	avatarFrame.BackgroundColor3 = Palette.ObsidianDark
	avatarFrame.BorderSizePixel = 0
	avatarFrame.Parent = rootGroup

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0) -- Circular profile
	avatarCorner.Parent = avatarFrame

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = isLocal and Color3.fromRGB(255, 215, 0) or Palette.FiligreeWhite
	stroke.Thickness = isLocal and 3.5 or 2.0
	stroke.Parent = avatarFrame

	if isLocal then
		-- Gold glow outer ring for local player's home beacon
		local glowRing = Instance.new("Frame")
		glowRing.Name = "GoldGlowRing"
		glowRing.AnchorPoint = Vector2.new(0.5, 0.5)
		glowRing.Position = UDim2.new(0.5, 0, 0.5, 0)
		glowRing.Size = UDim2.new(1, 8, 1, 8)
		glowRing.BackgroundTransparency = 1
		glowRing.Parent = avatarFrame

		local glowCorner = Instance.new("UICorner")
		glowCorner.CornerRadius = UDim.new(1, 0)
		glowCorner.Parent = glowRing

		local glowStroke = Instance.new("UIStroke")
		glowStroke.Color = Color3.fromRGB(255, 230, 90)
		glowStroke.Thickness = 1.5
		glowStroke.Transparency = 0.35
		glowStroke.Parent = glowRing
	end

	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Name = "AvatarHeadshot"
	imageLabel.Size = UDim2.new(1, 0, 1, 0)
	imageLabel.BackgroundTransparency = 1
	imageLabel.BorderSizePixel = 0
	imageLabel.Image = HEADSHOT_PLACEHOLDER
	imageLabel.Parent = avatarFrame

	local imgCorner = Instance.new("UICorner")
	imgCorner.CornerRadius = UDim.new(1, 0)
	imgCorner.Parent = imageLabel

	getAvatarThumbnail(ownerUserId, function(thumbnailUrl)
		if imageLabel and imageLabel.Parent then
			imageLabel.Image = thumbnailUrl
		end
	end)

	-- 3. Name & Distance Pill Container (Gothic Obsidian Style)
	local pillHeight = 38
	local pillWidth = 132
	local pill = Instance.new("Frame")
	pill.Name = "InfoPill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, avatarSize + 6)
	pill.Size = UDim2.new(0, pillWidth, 0, pillHeight)
	pill.BackgroundColor3 = Palette.ObsidianDark
	pill.BackgroundTransparency = 0.15
	pill.BorderSizePixel = 0
	pill.Parent = rootGroup

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 5)
	pillCorner.Parent = pill

	local pillStroke = Instance.new("UIStroke")
	pillStroke.Color = isLocal and Color3.fromRGB(240, 195, 60) or Palette.InnerLineMuted
	pillStroke.Thickness = isLocal and 1.5 or 1.0
	pillStroke.Parent = pill

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "OwnerNameLabel"
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.Position = UDim2.new(0.5, 0, 0, 2)
	nameLabel.Size = UDim2.new(1, -8, 0, 18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = displayName
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeColor3 = Color3.fromRGB(15, 10, 20)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = pill

	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "DistanceLabel"
	distLabel.AnchorPoint = Vector2.new(0.5, 0)
	distLabel.Position = UDim2.new(0.5, 0, 0, 20)
	distLabel.Size = UDim2.new(1, -8, 0, 16)
	distLabel.BackgroundTransparency = 1
	distLabel.Font = Enum.Font.GothamBold
	distLabel.Text = isLocal and "⌂ HOME • calculating..." or "calculating..."
	distLabel.TextSize = 11
	distLabel.TextColor3 = isLocal and Palette.GoldText or Color3.fromRGB(200, 210, 225)
	distLabel.TextStrokeColor3 = Color3.fromRGB(20, 14, 25)
	distLabel.TextStrokeTransparency = 0.2
	distLabel.Parent = pill

	billboard.Parent = PlayerGui

	activeBeacons[plotModel] = {
		PlotModel = plotModel,
		Billboard = billboard,
		RootGroup = rootGroup,
		DistanceLabel = distLabel,
		IsLocal = isLocal,
		CenterPosition = adornee.Position,
		UserId = ownerUserId,
	}
end

-- Synchronize gate barriers and building proximity prompts based on plot ownership
local function syncPlotAccess(plotModel: Model)
	local ownerUserId = plotModel:GetAttribute("OwnerUserId") :: number?
	local isOwner = (ownerUserId ~= nil and ownerUserId > 0 and ownerUserId == LocalPlayer.UserId)

	-- 1. Gate Barrier Collision (pushback / physical blocker for non-owners)
	local barrier = plotModel:FindFirstChild("GateBarrier", true) :: BasePart?
	if barrier then
		barrier.CanCollide = not isOwner
		barrier.Transparency = isOwner and 1 or 0.82
	end

	-- 2. Building ProximityPrompts (disabled for non-owners)
	for _, desc in ipairs(plotModel:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			desc.Enabled = isOwner
		end
	end
end

local function hookPlot(plotModel: Model)
	local function onAttributeChanged()
		buildBeacon(plotModel)
		syncPlotAccess(plotModel)
	end

	plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(onAttributeChanged)
	plotModel:GetAttributeChangedSignal("OwnerName"):Connect(onAttributeChanged)

	local anchor = plotModel:FindFirstChild("PlotBeaconAnchor")
	if anchor then
		anchor:GetAttributeChangedSignal("OwnerUserId"):Connect(onAttributeChanged)
		anchor:GetAttributeChangedSignal("OwnerName"):Connect(onAttributeChanged)
	end

	plotModel.ChildAdded:Connect(function(child)
		if child.Name == "PlotBeaconAnchor" then
			child:GetAttributeChangedSignal("OwnerUserId"):Connect(onAttributeChanged)
			child:GetAttributeChangedSignal("OwnerName"):Connect(onAttributeChanged)
			onAttributeChanged()
		end
	end)

	onAttributeChanged()
end

for _, plot in ipairs(PlotsFolder:GetChildren()) do
	if plot:IsA("Model") then
		task.spawn(hookPlot, plot)
	end
end

PlotsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		task.wait(0.2)
		hookPlot(child)
	end
end)

-- Re-check plot access whenever character respawns
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.5)
	for _, plot in ipairs(PlotsFolder:GetChildren()) do
		if plot:IsA("Model") then
			syncPlotAccess(plot)
		end
	end
end)

-- Single Heartbeat loop: gentle bobbing animation, real-time distance updates, and smooth fade
local lastPeriodicSync = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local bobOffset = math.sin(now * 1.8) * 2.5
	local currentYOffset = 50 + bobOffset

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local playerPos = hrp and hrp.Position or nil

	local cam = Workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or playerPos

	for _, beacon in pairs(activeBeacons) do
		if beacon.Billboard and beacon.Billboard.Parent then
			beacon.Billboard.StudsOffset = Vector3.new(0, currentYOffset, 0)
		end

		if beacon.DistanceLabel and playerPos then
			local dist = (playerPos - beacon.CenterPosition).Magnitude
			if beacon.IsLocal then
				beacon.DistanceLabel.Text = string.format("⌂ HOME • %d studs", math.round(dist))
			else
				beacon.DistanceLabel.Text = string.format("%d studs", math.round(dist))
			end
		end

		-- Smooth fade out for other players' beacons over the last 15% (595 to 700 studs from camera)
		if not beacon.IsLocal and beacon.RootGroup and camPos then
			local camDist = (camPos - beacon.CenterPosition).Magnitude
			if camDist >= OTHER_BEACON_MAX_DISTANCE then
				beacon.RootGroup.GroupTransparency = 1
			elseif camDist > OTHER_BEACON_FADE_START then
				local alpha = (camDist - OTHER_BEACON_FADE_START) / OTHER_BEACON_FADE_SPAN
				beacon.RootGroup.GroupTransparency = math.clamp(alpha, 0, 1)
			else
				beacon.RootGroup.GroupTransparency = 0
			end
		end
	end

	-- Low frequency check (every 1 second) to keep barriers & prompts synced
	if now - lastPeriodicSync > 1.0 then
		lastPeriodicSync = now
		for _, plot in ipairs(PlotsFolder:GetChildren()) do
			if plot:IsA("Model") then
				syncPlotAccess(plot)
				local uid = plot:GetAttribute("OwnerUserId")
				if (uid and uid > 0) and not activeBeacons[plot] then
					buildBeacon(plot)
				end
			end
		end
	end
end)
