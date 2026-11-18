--!strict
-- ServerScriptService/BaseOverhaul/LeaderboardRenderHelper.luau
-- Shared rendering and tick helpers for all three world leaderboards
-- (Top Robux Donated, Top Power, Top Playtime), eliminating duplicate card/footer loops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LeaderboardRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("LeaderboardRules"))
local SharedLeaderboards = require(script.Parent:WaitForChild("SharedLeaderboards"))

local LeaderboardRenderHelper = {}

export type CardEntry = {
	UserId: number,
	Value: number,
}

function LeaderboardRenderHelper.ResolveScreenParts(boardName: string, screenName: string): { BasePart }
	local parts = {}
	local host = SharedLeaderboards.Host()
	local board = host and host:FindFirstChild(boardName)
	local s = board and board:FindFirstChild(screenName)
	if s and s:IsA("BasePart") then
		table.insert(parts, s)
		return parts
	end
	local fallbackBoard = Workspace:FindFirstChild(boardName)
	local fallbackScreen = fallbackBoard and fallbackBoard:FindFirstChild(screenName)
	if fallbackScreen and fallbackScreen:IsA("BasePart") then
		table.insert(parts, fallbackScreen)
	end
	return parts
end

local function setCardRow(
	card: Frame,
	rank: number,
	userId: number,
	value: number,
	valueFrameName: string,
	valueLabelName: string,
	getUsernamePair: (number) -> (string, string),
	getAvatarThumb: (number, string?, number?, number?) -> string,
	formatValue: (number) -> string
)
	local rankLbl = card:FindFirstChild("RankLabel") :: TextLabel?
	if rankLbl and rankLbl:IsA("TextLabel") then
		rankLbl.Text = "#" .. tostring(rank)
		rankLbl.TextColor3 = LeaderboardRules.RankColor(rank)
	end

	local avatarFrame = card:FindFirstChild("AvatarIconFrame")
	local avatarIcon = avatarFrame and avatarFrame:FindFirstChild("AvatarIcon") :: ImageLabel?
	local infoLabel = card:FindFirstChild("InfoLabel")
	local nameLbl = infoLabel and infoLabel:FindFirstChild("DisplayNameLabel") :: TextLabel?
	local userLbl = infoLabel and infoLabel:FindFirstChild("UsernameLabel") :: TextLabel?

	local valueFrame = card:FindFirstChild(valueFrameName)
		or card:FindFirstChild("TotalPowerLabelFrame")
		or card:FindFirstChild("TotalPlaytimeLabelFrame")
		or card:FindFirstChild("TotalDonatedLabelFrame")
	if valueFrame then
		valueFrame.Name = valueFrameName
	end

	local valueLbl = valueFrame
		and (
			valueFrame:FindFirstChild(valueLabelName)
			or valueFrame:FindFirstChild("TotalPowerLabel")
			or valueFrame:FindFirstChild("TotalPlaytimeLabel")
			or valueFrame:FindFirstChild("TotalDonatedLabel")
		) :: TextLabel?
	if valueLbl then
		valueLbl.Name = valueLabelName
	end

	local uname, dname = getUsernamePair(userId)
	if nameLbl then
		nameLbl.Text = dname
	end
	if userLbl then
		userLbl.Text = "@" .. uname
	end
	if valueLbl then
		valueLbl.Text = formatValue(value)
	end
	if avatarIcon then
		avatarIcon.Image = getAvatarThumb(userId, "AvatarBust", 150, 150)
	end
end

function LeaderboardRenderHelper.ApplyCanvasSize(scrollFrame: ScrollingFrame, rowCount: number)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
	scrollFrame.CanvasSize = UDim2.fromOffset(0, LeaderboardRules.CanvasHeight(rowCount))
end

function LeaderboardRenderHelper.RenderScreenCards(
	screenParts: { BasePart },
	entries: { CardEntry },
	valueFrameName: string,
	valueLabelName: string,
	getUsernamePair: (number) -> (string, string),
	getAvatarThumb: (number, string?, number?, number?) -> string,
	formatValue: (number) -> string
)
	local clamped = LeaderboardRules.ClampSorted(entries, LeaderboardRules.MAX_ROWS)
	for _, screenPart in ipairs(screenParts) do
		local surfaceGui = screenPart:FindFirstChild("SurfaceGui")
		local holder = surfaceGui and surfaceGui:FindFirstChild("Holder")
		local body = holder and holder:FindFirstChild("Body")
		local scrollFrame = body and body:FindFirstChild("ScrollingFrame") :: ScrollingFrame?
		local template = scrollFrame and scrollFrame:FindFirstChild("TemplateCardFrame") :: Frame?
		if not scrollFrame or not template then
			continue
		end

		template.Visible = false
		for _, child in ipairs(scrollFrame:GetChildren()) do
			if child:IsA("Frame") and child.Name:sub(1, 5) == "Card_" then
				child:Destroy()
			end
		end

		for i, entry in ipairs(clamped) do
			local card = template:Clone()
			card.Name = "Card_" .. entry.UserId
			card.Visible = true
			card.LayoutOrder = i
			card.Parent = scrollFrame
			setCardRow(
				card,
				i,
				entry.UserId,
				entry.Value,
				valueFrameName,
				valueLabelName,
				getUsernamePair,
				getAvatarThumb,
				formatValue
			)
		end

		LeaderboardRenderHelper.ApplyCanvasSize(scrollFrame, #clamped)
	end
end

function LeaderboardRenderHelper.TickFooter(screenParts: { BasePart }, secsLeft: number, lastUpdateEpoch: number)
	local lastUpdateStr = os.date("%I:%M %p", lastUpdateEpoch)
	local text = string.format("Update In %d sec, Last Update %s", secsLeft, lastUpdateStr)
	for _, screenPart in ipairs(screenParts) do
		local surfaceGui = screenPart:FindFirstChild("SurfaceGui")
		local holder = surfaceGui and surfaceGui:FindFirstChild("Holder")
		local footer = holder and holder:FindFirstChild("Footer")
		local labelFrame = footer and footer:FindFirstChild("LabelFrame")
		local updateLabel = labelFrame and labelFrame:FindFirstChild("UpdateLabel") :: TextLabel?
		if updateLabel then
			updateLabel.Text = text
		end
	end
end

return LeaderboardRenderHelper
