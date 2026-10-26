local Workspace = game:GetService("Workspace")

local Config          = require(script.Parent:WaitForChild("PlaytimeConfig"))
local Utils           = require(script.Parent:WaitForChild("PlaytimeUtils"))
local DataStoreModule  = require(script.Parent:WaitForChild("PlaytimeDataStore"))
local StandBuilder     = require(script.Parent:WaitForChild("PlaytimeStandBuilder"))

local Renderer = {}

local nextRefreshAt   = os.clock() + Config.BOARD_REFRESH
local lastUpdateEpoch = os.time()

local function getAllScreenParts(): { BasePart }
	local parts = {}
	local plots = Workspace:FindFirstChild("WaitingRoomPlots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			local s = plot:FindFirstChild("ScreenPlaytime", true)
			if s and s:IsA("BasePart") then
				table.insert(parts, s)
			end
		end
	end
	if #parts == 0 then
		local fallback = Utils.resolvePath(Config.Paths.ScreenPlaytimePart, Workspace, 2)
		if fallback and fallback:IsA("BasePart") then
			table.insert(parts, fallback)
		end
	end
	return parts
end

local function setCardData(card: Frame, userId: number, seconds: number)
	local avatarFrame = card:FindFirstChild("AvatarIconFrame")
	local avatarIcon  = avatarFrame and avatarFrame:FindFirstChild("AvatarIcon") :: ImageLabel?
	local infoLabel   = card:FindFirstChild("InfoLabel")
	local nameLbl     = infoLabel and infoLabel:FindFirstChild("DisplayNameLabel") :: TextLabel?
	local userLbl     = infoLabel and infoLabel:FindFirstChild("UsernameLabel") :: TextLabel?
	local timeFrame   = card:FindFirstChild("TotalPlaytimeLabelFrame")
	local timeLbl     = timeFrame and timeFrame:FindFirstChild("TotalPlaytimeLabel") :: TextLabel?

	local uname, dname = Utils.getUsernamePair(userId)
	if nameLbl then nameLbl.Text = dname end
	if userLbl then userLbl.Text = "@" .. uname end
	if timeLbl then timeLbl.Text = Utils.formatHM(seconds) end
	if avatarIcon then avatarIcon.Image = Utils.getAvatarThumb(userId, "AvatarBust", 150, 150) end
end

function Renderer.FullRender()
	local top = DataStoreModule.GetSortedTop(Config.MAX_BOARD_ROWS)

	local ids = {}
	for _, e in ipairs(top) do table.insert(ids, e.UserId) end
	Utils.resolveNamesBulk(ids)

	local screenParts = getAllScreenParts()
	for _, screenPart in ipairs(screenParts) do
		local surfaceGui = screenPart:FindFirstChild("SurfaceGui")
		local holder = surfaceGui and surfaceGui:FindFirstChild("Holder")
		local body = holder and holder:FindFirstChild("Body")
		local scrollFrame = body and body:FindFirstChild("ScrollingFrame") :: ScrollingFrame?
		local template = scrollFrame and scrollFrame:FindFirstChild("TemplateCardFrame") :: Frame?
		if not scrollFrame or not template then continue end

		template.Visible = false

		-- Remove old generated cards
		for _, child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("Frame") and child.Name:sub(1, 5) == "Card_" then
				child:Destroy()
			end
		end

		for i, entry in ipairs(top) do
			local card = template:Clone()
			card.Name        = "Card_" .. entry.UserId
			card.Visible     = true
			card.LayoutOrder = i
			card.Parent      = scrollFrame
			setCardData(card, entry.UserId, entry.Seconds)
		end
	end

	local top3 = { top[1], top[2], top[3] }
	StandBuilder.Update(top3)

	nextRefreshAt   = os.clock() + Config.BOARD_REFRESH
	lastUpdateEpoch = os.time()
end

function Renderer.Tick()
	local secsLeft = math.max(0, math.floor(nextRefreshAt - os.clock()))
	local lastUpdateStr = os.date("%I:%M %p", lastUpdateEpoch)

	local screenParts = getAllScreenParts()
	for _, screenPart in ipairs(screenParts) do
		local surfaceGui = screenPart:FindFirstChild("SurfaceGui")
		local holder = surfaceGui and surfaceGui:FindFirstChild("Holder")
		local footer = holder and holder:FindFirstChild("Footer")
		local updateLabel = footer and footer:FindFirstChild("LabelFrame") and footer.LabelFrame:FindFirstChild("UpdateLabel") :: TextLabel?
		if updateLabel then
			updateLabel.Text = string.format("Update In %d sec, Last Update %s", secsLeft, lastUpdateStr)
		end

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
