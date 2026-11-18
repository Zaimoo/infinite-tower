--!strict
local Config           = require(script.Parent:WaitForChild("PlaytimeConfig"))
local Utils            = require(script.Parent:WaitForChild("PlaytimeUtils"))
local DataStoreModule  = require(script.Parent:WaitForChild("PlaytimeDataStore"))
local StandBuilder     = require(script.Parent:WaitForChild("PlaytimeStandBuilder"))
local BaseOverhaul     = script.Parent.Parent:WaitForChild("BaseOverhaul")
local RenderHelper     = require(BaseOverhaul:WaitForChild("LeaderboardRenderHelper"))

local Renderer = {}

local nextRefreshAt   = os.clock() + Config.BOARD_REFRESH
local lastUpdateEpoch = os.time()

local function getAllScreenParts(): { BasePart }
	return RenderHelper.ResolveScreenParts("AvxsedPlaytimeWS", "ScreenPlaytime")
end

function Renderer.FullRender()
	local top = DataStoreModule.GetSortedTop(Config.MAX_BOARD_ROWS)

	local ids = table.create(#top)
	local entries: { RenderHelper.CardEntry } = table.create(#top)
	for i, e in ipairs(top) do
		ids[i] = e.UserId
		entries[i] = { UserId = e.UserId, Value = e.Seconds }
	end
	Utils.resolveNamesBulk(ids)

	local screenParts = getAllScreenParts()
	RenderHelper.RenderScreenCards(
		screenParts,
		entries,
		"TotalPlaytimeLabelFrame",
		"TotalPlaytimeLabel",
		Utils.getUsernamePair,
		Utils.getAvatarThumb,
		Utils.formatHM
	)

	local hasRigstand = false
	for _, s in ipairs(screenParts) do
		if s.Parent and s.Parent:FindFirstChild("Rigstand") then
			hasRigstand = true
			break
		end
	end
	if hasRigstand then
		local top3 = { top[1], top[2], top[3] }
		StandBuilder.Update(top3)
	end

	nextRefreshAt   = os.clock() + Config.BOARD_REFRESH
	lastUpdateEpoch = os.time()
end

function Renderer.Tick()
	local secsLeft = math.max(0, math.floor(nextRefreshAt - os.clock()))
	local screenParts = getAllScreenParts()
	RenderHelper.TickFooter(screenParts, secsLeft, lastUpdateEpoch)

	for _, screenPart in ipairs(screenParts) do
		local surfaceGui = screenPart:FindFirstChild("SurfaceGui")
		local holder = surfaceGui and surfaceGui:FindFirstChild("Holder")
		local body = holder and holder:FindFirstChild("Body")
		local scrollFrame = body and body:FindFirstChild("ScrollingFrame") :: ScrollingFrame?
		if scrollFrame then
			for _, child in ipairs(scrollFrame:GetChildren()) do
				if child:IsA("Frame") and child.Name:sub(1, 5) == "Card_" then
					local uid = tonumber(child.Name:sub(6))
					if uid and DataStoreModule.IsTracked(uid) then
						local timeFrame = child:FindFirstChild("TotalPlaytimeLabelFrame")
						local timeLbl   = timeFrame and timeFrame:FindFirstChild("TotalPlaytimeLabel") :: TextLabel?
						if timeLbl then
							timeLbl.Text = Utils.formatHM(DataStoreModule.GetTotalSeconds(uid))
						end
					end
				end
			end
		end
	end
end

function Renderer.Start()
	task.spawn(function()
		task.wait(3)
		Renderer.FullRender()
		while true do
			task.wait(Config.BOARD_REFRESH)
			Renderer.FullRender()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.TICK_INTERVAL)
			Renderer.Tick()
		end
	end)
end

return Renderer
