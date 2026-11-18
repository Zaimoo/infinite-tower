--!strict
local Config           = require(script.Parent:WaitForChild("DonatedConfig"))
local Utils            = require(script.Parent:WaitForChild("DonatedUtils"))
local DataStoreModule  = require(script.Parent:WaitForChild("DonatedDataStore"))
local BaseOverhaul     = script.Parent.Parent:WaitForChild("BaseOverhaul")
local RenderHelper     = require(BaseOverhaul:WaitForChild("LeaderboardRenderHelper"))

local Renderer = {}

local nextRefreshAt   = os.clock() + Config.BOARD_REFRESH
local lastUpdateEpoch = os.time()
local renderQueued    = false

local function getAllScreenParts(): { BasePart }
	return RenderHelper.ResolveScreenParts("AvxsedDonatedWS", "ScreenDonated")
end

function Renderer.FullRender()
	local top = DataStoreModule.GetSortedTop(Config.MAX_BOARD_ROWS)

	local ids = table.create(#top)
	local entries: { RenderHelper.CardEntry } = table.create(#top)
	for i, e in ipairs(top) do
		ids[i] = e.UserId
		entries[i] = { UserId = e.UserId, Value = e.Donated }
	end
	Utils.resolveNamesBulk(ids)

	local screenParts = getAllScreenParts()
	RenderHelper.RenderScreenCards(
		screenParts,
		entries,
		"TotalDonatedLabelFrame",
		"TotalDonatedLabel",
		Utils.getUsernamePair,
		Utils.getAvatarThumb,
		Utils.formatRobux
	)

	nextRefreshAt   = os.clock() + Config.BOARD_REFRESH
	lastUpdateEpoch = os.time()
end

function Renderer.QueueRender()
	if renderQueued then return end
	renderQueued = true
	task.delay(0.5, function()
		renderQueued = false
		Renderer.FullRender()
	end)
end

function Renderer.Tick()
	local secsLeft = math.max(0, math.floor(nextRefreshAt - os.clock()))
	local screenParts = getAllScreenParts()
	RenderHelper.TickFooter(screenParts, secsLeft, lastUpdateEpoch)
end

function Renderer.Start()
	DataStoreModule.SetOnChangedCallback(function(_uid, _amt)
		Renderer.QueueRender()
	end)

	task.spawn(function()
		task.wait(1)
		Renderer.FullRender()
		task.wait(2)
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
