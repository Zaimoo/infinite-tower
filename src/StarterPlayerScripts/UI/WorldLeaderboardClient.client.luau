--!strict
-- StarterPlayerScripts/UI/WorldLeaderboardClient.client.luau
-- 1. Enables interactive mouse-wheel and touch/drag scrolling on the three world
--    leaderboard SurfaceGuis (ScreenDonated, ScreenPower, ScreenPlaytime) while keeping
--    each SurfaceGui parented on its Workspace BasePart so server replication stays native.
-- 2. Hydrates any EditableMesh Blender monument parts locally on the client if Roblox
--    MeshIds have not been uploaded via File > Import 3D yet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LeaderboardMeshHydrator = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("LeaderboardMeshHydrator"))

local SCREEN_NAMES = {
	ScreenDonated = true,
	ScreenPower = true,
	ScreenPlaytime = true,
}

local MAX_SCROLL_DISTANCE = 140
local WHEEL_STEP_PX = 84

local activeScreens: { BasePart } = {}
local screenLookup: { [BasePart]: boolean } = {}
local activeScrollConns: { [ScrollingFrame]: RBXScriptConnection } = {}

local function getScrollFrame(screenPart: BasePart): ScrollingFrame?
	local gui = screenPart:FindFirstChild("SurfaceGui")
	local holder = gui and gui:FindFirstChild("Holder")
	local body = holder and holder:FindFirstChild("Body")
	local scroll = body and body:FindFirstChild("ScrollingFrame")
	return if scroll and scroll:IsA("ScrollingFrame") then scroll else nil
end

local function clampScrollPosition(scrollFrame: ScrollingFrame, nextY: number?): number
	local maxY = math.max(0, scrollFrame.CanvasSize.Y.Offset - scrollFrame.AbsoluteWindowSize.Y)
	local clamped = math.clamp(nextY or scrollFrame.CanvasPosition.Y, 0, maxY)
	scrollFrame.CanvasPosition = Vector2.new(0, clamped)
	return clamped
end

local function watchScrollBounds(screenPart: BasePart)
	local scroll = getScrollFrame(screenPart)
	if not scroll or activeScrollConns[scroll] then
		return
	end
	activeScrollConns[scroll] = scroll:GetPropertyChangedSignal("CanvasSize"):Connect(function()
		clampScrollPosition(scroll)
	end)
	scroll.Destroying:Connect(function()
		if activeScrollConns[scroll] then
			activeScrollConns[scroll]:Disconnect()
			activeScrollConns[scroll] = nil
		end
	end)
end

local function registerScreen(inst: Instance)
	if inst:IsA("BasePart") and SCREEN_NAMES[inst.Name] and not screenLookup[inst] then
		screenLookup[inst] = true
		table.insert(activeScreens, inst)
		watchScrollBounds(inst)
		inst.ChildAdded:Connect(function()
			task.defer(watchScrollBounds, inst)
		end)
		inst.AncestryChanged:Connect(function(_, parent)
			if not parent then
				screenLookup[inst] = nil
				local idx = table.find(activeScreens, inst)
				if idx then
					table.remove(activeScreens, idx)
				end
			end
		end)
	end
end

local function raycastScreenAt(screenPos: Vector2): BasePart?
	local cam = Workspace.CurrentCamera
	if not cam or #activeScreens == 0 then
		return nil
	end
	local unitRay = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = activeScreens
	params.IgnoreWater = true
	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * MAX_SCROLL_DISTANCE, params)
	if result and result.Instance and screenLookup[result.Instance] then
		return result.Instance
	end
	return nil
end

local function bindPavilion(pavilion: Instance)
	for _, desc in ipairs(pavilion:GetDescendants()) do
		registerScreen(desc)
	end
	LeaderboardMeshHydrator.HydratePendingClientParts(pavilion)

	pavilion.DescendantAdded:Connect(function(desc)
		registerScreen(desc)
		if desc:IsA("BasePart") and desc:GetAttribute("PendingBlenderMesh") == true then
			task.defer(function()
				if desc.Parent then
					LeaderboardMeshHydrator.HydratePendingClientParts(pavilion)
				end
			end)
		end
	end)
end

local function watchHubGeometry()
	local function attachFromGeom(geom: Instance)
		local commons = geom:FindFirstChild("MastersCommons") or geom:WaitForChild("MastersCommons", 15)
		if not commons then return end
		local pavilion = commons:FindFirstChild("LeaderboardPavilion") or commons:WaitForChild("LeaderboardPavilion", 15)
		if pavilion then
			bindPavilion(pavilion)
		end
		commons.ChildAdded:Connect(function(child)
			if child.Name == "LeaderboardPavilion" then
				bindPavilion(child)
			end
		end)
	end

	local existing = Workspace:FindFirstChild("BaseOverhaulGeometry")
	if existing then
		task.spawn(attachFromGeom, existing)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "BaseOverhaulGeometry" then
			task.spawn(attachFromGeom, child)
		end
	end)
end

-- Interactive MouseWheel + touch/drag vertical scroll on world leaderboard screens
local draggingScreen: BasePart? = nil
local lastDragY: number = 0

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local hit = raycastScreenAt(pos)
		if hit then
			draggingScreen = hit
			lastDragY = pos.Y
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		draggingScreen = nil
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
		local mouseLoc = UserInputService:GetMouseLocation()
		local hit = raycastScreenAt(mouseLoc)
		if hit then
			local scroll = getScrollFrame(hit)
			if scroll then
				clampScrollPosition(scroll, scroll.CanvasPosition.Y - input.Position.Z * WHEEL_STEP_PX)
			end
		end
	elseif draggingScreen and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
		local dy = input.Position.Y - lastDragY
		lastDragY = input.Position.Y
		local scroll = getScrollFrame(draggingScreen)
		if scroll then
			clampScrollPosition(scroll, scroll.CanvasPosition.Y - dy * 1.5)
		end
	end
end)

watchHubGeometry()
