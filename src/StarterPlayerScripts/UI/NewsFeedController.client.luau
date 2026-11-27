--!strict
-- StarterPlayerScripts/UI/NewsFeedController.client.luau
-- Server-wide headlines and the Wanted list (docs/first-session-and-social-plan.md B0, B1, B3).
--   NewsFeed: one headline at a time (the server paces them, NewsRules.MIN_GAP), shown for
--     NewsRules.SHOW_SECONDS under the toast band, with the Master's headshot. A bounty headline
--     counts down and offers Hunt. Settings > Server News (Settings_ShowNews) hides the banner.
--     A big pull also raises a light column over that Master's Summoning Altar.
--   Wanted: every open public bounty. A WANTED chip (top left) opens the list; Hunt asks the server
--     to travel to the thief's floor (it checks everything, NewsService).
--   Boards (B6): this week's Top Thieves and Top Hunters, as tabs on the same panel. With no open
--     bounty the chip reads NOTORIETY and opens the boards; the footer shows this Master's week.
-- Decorative only: the server decides everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local NewsRules = require(ReplicatedStorage.Shared.Util:WaitForChild("NewsRules"))
local UIFeel = require(script.Parent:WaitForChild("UIFeel"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NewsRemotes")
local feedRemote = remotes:WaitForChild("NewsFeed") :: RemoteEvent
local wantedRemote = remotes:WaitForChild("Wanted") :: RemoteEvent
local requestRemote = remotes:WaitForChild("NewsRequest") :: RemoteEvent
local boardsRemote = remotes:WaitForChild("Boards") :: RemoteEvent

local GOLD = Color3.fromRGB(255, 214, 120)
local BLOOD = Color3.fromRGB(235, 80, 80)
local INK = Color3.fromRGB(6, 10, 16)
local PANEL = Color3.fromRGB(11, 16, 24)

local gui = Instance.new("ScreenGui")
gui.Name = "NewsFeed"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30 -- under first-session moments (40) and windows
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, font: Font, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = color
	b.FontFace = GildedGrimoire.Fonts.Title
	b.Text = text
	b.TextSize = 14
	b.TextColor3 = INK
	b.Parent = parent
	corner(b, 6)
	return b
end

-- Headshots, fetched once per Master (never for server-run rivals, whose ids are negative).
local headshots: { [number]: string } = {}
local function headshot(userId: number?): string
	if not userId or userId <= 0 then return "" end
	local cached = headshots[userId]
	if cached then return cached end
	local ok, url = pcall(function()
		return (Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60))
	end)
	headshots[userId] = if ok and url then url else ""
	return headshots[userId]
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function hunt(thiefUserId: number?)
	if thiefUserId then requestRemote:FireServer("HUNT", thiefUserId) end
end

--== Headline banner ==========================================================================

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0.18, 36) -- under the toast band and the floor bar
banner.Size = UDim2.fromOffset(440, 64)
banner.BackgroundColor3 = PANEL
banner.BackgroundTransparency = 0.12
banner.Visible = false
banner.Parent = gui
corner(banner, 10)
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = GOLD
bannerStroke.Thickness = 1.5
bannerStroke.Transparency = 0.2
bannerStroke.Parent = banner
local bannerScale = Instance.new("UISizeConstraint")
bannerScale.MaxSize = Vector2.new(440, 64)
bannerScale.Parent = banner

local avatar = Instance.new("ImageLabel")
avatar.Name = "Avatar"
avatar.BackgroundColor3 = INK
avatar.Position = UDim2.fromOffset(8, 8)
avatar.Size = UDim2.fromOffset(48, 48)
avatar.Parent = banner
corner(avatar, 24)

local headlineLabel = label(banner, GildedGrimoire.Fonts.Title, 17, GOLD)
headlineLabel.Name = "Headline"
headlineLabel.Position = UDim2.fromOffset(66, 9)
headlineLabel.Size = UDim2.new(1, -150, 0, 24)
local detailLabel = label(banner, GildedGrimoire.Fonts.Body, 13, Color3.fromRGB(238, 244, 251))
detailLabel.Name = "Detail"
detailLabel.Position = UDim2.fromOffset(66, 35)
detailLabel.Size = UDim2.new(1, -150, 0, 20)

local huntButton = button(banner, "HUNT", BLOOD)
huntButton.Name = "Hunt"
huntButton.AnchorPoint = Vector2.new(1, 0.5)
huntButton.Position = UDim2.new(1, -10, 0.5, 0)
huntButton.Size = UDim2.fromOffset(72, 32)
huntButton.Visible = false

local current: any = nil
local shownUntil = 0
local function showHeadline(item: any)
	if player:GetAttribute("Settings_ShowNews") == false then return end
	current = item
	local headline, detail = NewsRules.Format(item)
	headlineLabel.Text = headline
	detailLabel.Text = detail
	avatar.Image = headshot(item.ActorUserId)
	local spec = NewsRules.Kinds[item.Kind]
	local canHunt = spec ~= nil and spec.Hunt == true and item.ActorUserId ~= player.UserId
	huntButton.Visible = canHunt
	bannerStroke.Color = if spec and spec.Hunt then BLOOD else GOLD
	shownUntil = os.clock() + NewsRules.SHOW_SECONDS + (if canHunt then 3 else 0)
	banner.Visible = true
	if UIFeel.ReducedMotion() then
		banner.Position = UDim2.new(0.5, 0, 0.18, 36)
	else
		banner.Position = UDim2.new(0.5, 0, 0.18, 16)
		TweenService:Create(banner, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0.18, 36) }):Play()
	end
end
huntButton.Activated:Connect(function()
	if current then hunt(current.ActorUserId) end
end)

-- A big pull lights a column over the puller's Summoning Altar for everyone in the hub to see.
local function lightColumn(userId: number?)
	if not userId or userId <= 0 then return end
	local plots = Workspace:FindFirstChild("WaitingRoomPlots")
	if not plots then return end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == userId then
			local altar = plot:FindFirstChild("Building_Summoning", true)
			if altar and altar:IsA("Model") then
				local base = altar:GetPivot().Position
				local column = Instance.new("Part")
				column.Name = "NewsLightColumn"
				column.Anchored, column.CanCollide, column.CanQuery, column.CanTouch, column.CastShadow = true, false, false, false, false
				column.Shape = Enum.PartType.Cylinder
				column.Material = Enum.Material.Neon
				column.Color = GOLD
				column.Transparency = 0.25
				column.Size = Vector3.new(220, 4, 4)
				column.CFrame = CFrame.new(base + Vector3.new(0, 110, 0)) * CFrame.Angles(0, 0, math.rad(90))
				local glow = Instance.new("PointLight")
				glow.Color, glow.Brightness, glow.Range = GOLD, 3, 30
				glow.Parent = column
				column.Parent = Workspace
				TweenService:Create(column, TweenInfo.new(7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Transparency = 1, Size = Vector3.new(220, 1, 1) }):Play()
				task.delay(7.2, function() column:Destroy() end)
			end
			return
		end
	end
end

feedRemote.OnClientEvent:Connect(function(item: any)
	if type(item) ~= "table" or type(item.Kind) ~= "string" then return end
	showHeadline(item)
	if item.Kind == "BIG_PULL" then lightColumn(item.ActorUserId) end
end)

--== Wanted list ==============================================================================

local wanted: { any } = {}
local listOpen = false

local chip = button(gui, "WANTED", BLOOD)
chip.Name = "WantedChip"
chip.Position = UDim2.fromOffset(150, 14)
chip.Size = UDim2.fromOffset(112, 30)
chip.Visible = false

local list = Instance.new("Frame")
list.Name = "WantedList"
list.Position = UDim2.fromOffset(150, 50)
list.Size = UDim2.fromOffset(340, 0)
list.AutomaticSize = Enum.AutomaticSize.Y
list.BackgroundColor3 = PANEL
list.BackgroundTransparency = 0.08
list.Visible = false
list.Parent = gui
corner(list, 10)
local listPad = Instance.new("UIPadding")
listPad.PaddingTop, listPad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
listPad.PaddingLeft, listPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
listPad.Parent = list
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

local rows: { { Frame: Frame, Bounty: any } } = {}
local extras: { Instance } = {} -- board rows and empty-state lines, rebuilt on every render

-- The weekly boards (B6): this week's Top Thieves (thefts and escapes) and Top Hunters (bounties
-- claimed), read by the server every 60 s. They share the Wanted panel as tabs.
local boards: any = { Week = "", Thieves = {}, Hunters = {} }
local tab = "WANTED" -- "WANTED" | "THIEVES" | "HUNTERS"
local TABS = { { Key = "WANTED", Text = "Wanted" }, { Key = "THIEVES", Text = "Top Thieves" }, { Key = "HUNTERS", Text = "Top Hunters" } }
local MUTED = Color3.fromRGB(148, 163, 184)

local tabsRow = Instance.new("Frame")
tabsRow.Name = "Tabs"
tabsRow.LayoutOrder = 0
tabsRow.BackgroundTransparency = 1
tabsRow.Size = UDim2.new(1, 0, 0, 26)
tabsRow.Parent = list
local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding = UDim.new(0, 6)
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Parent = tabsRow
local tabButtons: { [string]: TextButton } = {}

local footer = label(list, GildedGrimoire.Fonts.Body, 12, MUTED)
footer.Name = "Footer"
footer.LayoutOrder = 10000
footer.Size = UDim2.new(1, 0, 0, 16)

local function wantedCount(): number
	local n = 0
	for _, b in wanted do
		if b.ThiefUserId ~= player.UserId then n += 1 end
	end
	return n
end

local function boardsHaveRows(): boolean
	return #boards.Thieves > 0 or #boards.Hunters > 0
end

local function emptyLine(text: string)
	local l = label(list, GildedGrimoire.Fonts.Body, 13, MUTED)
	l.LayoutOrder = 1
	l.Size = UDim2.new(1, 0, 0, 24)
	l.Text = text
	table.insert(extras, l)
end

local function boardRow(entry: any, order: number, unit: string)
	local row = Instance.new("Frame")
	row.Name = "Rank_" .. tostring(entry.Rank)
	row.LayoutOrder = order
	row.BackgroundColor3 = GOLD
	row.BackgroundTransparency = if entry.UserId == player.UserId then 0.85 else 1
	row.Size = UDim2.new(1, 0, 0, 34)
	row.Parent = list
	corner(row, 6)
	local rank = label(row, GildedGrimoire.Fonts.Title, 15, if (entry.Rank or 99) <= 3 then GOLD else MUTED)
	rank.Size = UDim2.fromOffset(26, 34)
	rank.TextXAlignment = Enum.TextXAlignment.Center
	rank.Text = tostring(entry.Rank)
	local face = Instance.new("ImageLabel")
	face.BackgroundColor3 = INK
	face.Size = UDim2.fromOffset(28, 28)
	face.Position = UDim2.fromOffset(30, 3)
	face.Image = headshot(entry.UserId)
	face.Parent = row
	corner(face, 14)
	local who = label(row, GildedGrimoire.Fonts.Title, 14, Color3.fromRGB(240, 232, 220))
	who.Position = UDim2.fromOffset(66, 0)
	who.Size = UDim2.new(1, -150, 1, 0)
	who.Text = tostring(entry.Name)
	local value = label(row, GildedGrimoire.Fonts.Title, 14, GOLD)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.new(1, -4, 0, 0)
	value.Size = UDim2.fromOffset(80, 34)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Text = string.format("%d %s", tonumber(entry.Value) or 0, unit)
	table.insert(extras, row)
end

local function wantedRow(b: any, order: number, serverNow: number)
	local row = Instance.new("Frame")
	row.Name = "Bounty_" .. tostring(b.ThiefUserId)
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 40)
	row.Parent = list
	local face = Instance.new("ImageLabel")
	face.BackgroundColor3 = INK
	face.Size = UDim2.fromOffset(36, 36)
	face.Position = UDim2.fromOffset(0, 2)
	face.Image = headshot(b.ThiefUserId)
	face.Parent = row
	corner(face, 18)
	local who = label(row, GildedGrimoire.Fonts.Title, 14, GOLD)
	who.Position = UDim2.fromOffset(44, 2)
	who.Size = UDim2.new(1, -124, 0, 18)
	who.Text = tostring(b.ThiefName)
	local what = label(row, GildedGrimoire.Fonts.Body, 12, Color3.fromRGB(203, 213, 225))
	what.Name = "Detail"
	what.Position = UDim2.fromOffset(44, 21)
	what.Size = UDim2.new(1, -124, 0, 16)
	what.Text = string.format("%s · Floor %d · %s", tostring(b.ItemName), b.FloorId or 0, clock((b.EndsAt or serverNow) - serverNow))
	local go = button(row, "HUNT", BLOOD)
	go.AnchorPoint = Vector2.new(1, 0.5)
	go.Position = UDim2.new(1, 0, 0.5, 0)
	go.Size = UDim2.fromOffset(68, 28)
	return row, go
end

local render: () -> ()

-- The chip reads WANTED while someone can be hunted, NOTORIETY otherwise (the boards).
render = function()
	local mine = wantedCount()
	chip.Text = if mine > 0 then string.format("WANTED · %d", mine) else "NOTORIETY"
	chip.BackgroundColor3 = if mine > 0 then BLOOD else GOLD
	chip.Visible = mine > 0 or boardsHaveRows()
	list.Visible = listOpen and chip.Visible
	for key, b in tabButtons do
		local on = key == tab
		b.BackgroundColor3 = if on then (if key == "WANTED" then BLOOD else GOLD) else INK
		b.TextColor3 = if on then INK else GOLD
	end
	for _, row in rows do row.Frame:Destroy() end
	table.clear(rows)
	for _, extra in extras do extra:Destroy() end
	table.clear(extras)
	if tab == "WANTED" then
		if mine == 0 then emptyLine("No open bounties right now") end
		local serverNow = Workspace:GetServerTimeNow()
		for i, b in wanted do
			if b.ThiefUserId == player.UserId then continue end
			local row, go = wantedRow(b, i, serverNow)
			go.Activated:Connect(function()
				hunt(b.ThiefUserId)
				listOpen = false
				render()
			end)
			table.insert(rows, { Frame = row, Bounty = b })
		end
	else
		local entries = if tab == "THIEVES" then boards.Thieves else boards.Hunters
		if #entries == 0 then emptyLine("No one on the board yet this week") end
		for i, entry in entries do boardRow(entry, i, if tab == "THIEVES" then "stolen" else "claimed") end
	end
	local thefts = tonumber(player:GetAttribute("NotorietyWeekThefts")) or 0
	local hunts = tonumber(player:GetAttribute("NotorietyWeekHunts")) or 0
	local title = player:GetAttribute("NotorietyTitle")
	footer.Text = string.format("%sYour week: %d stolen · %d claimed",
		if type(title) == "string" and title ~= "" then title .. " · " else "", thefts, hunts)
end

for i, spec in TABS do
	local b = button(tabsRow, spec.Text, INK)
	b.Name = "Tab_" .. spec.Key
	b.LayoutOrder = i
	b.TextSize = 13
	b.Size = UDim2.new(1 / #TABS, -4, 1, 0)
	b.Activated:Connect(function()
		tab = spec.Key
		render()
	end)
	tabButtons[spec.Key] = b
end

chip.Activated:Connect(function()
	listOpen = not listOpen
	if listOpen then tab = if wantedCount() > 0 then "WANTED" elseif tab == "WANTED" then "THIEVES" else tab end
	render()
end)

wantedRemote.OnClientEvent:Connect(function(incoming: any)
	if type(incoming) ~= "table" then return end
	wanted = incoming
	render()
end)

local function rowsOf(value: any): { any }
	local out = {}
	if type(value) ~= "table" then return out end
	for _, entry in value do
		if type(entry) == "table" and type(entry.UserId) == "number" then table.insert(out, entry) end
	end
	return out
end

boardsRemote.OnClientEvent:Connect(function(incoming: any)
	if type(incoming) ~= "table" then return end
	boards = { Week = tostring(incoming.Week or ""), Thieves = rowsOf(incoming.Thieves), Hunters = rowsOf(incoming.Hunters) }
	render()
end)

for _, attribute in { "NotorietyWeekThefts", "NotorietyWeekHunts", "NotorietyTitle" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if listOpen then render() end
	end)
end
render()

--== Clocks ===================================================================================

task.spawn(function()
	while true do
		task.wait(0.5)
		local now, serverNow = os.clock(), Workspace:GetServerTimeNow()
		if banner.Visible then
			if now >= shownUntil or player:GetAttribute("Settings_ShowNews") == false then
				banner.Visible = false
				current = nil
			elseif current and current.EndsAt then
				local _, detail = NewsRules.Format(current)
				detailLabel.Text = string.format("%s · %s", detail, clock(current.EndsAt - serverNow))
			end
		end
		if listOpen then
			for _, row in rows do
				local b = row.Bounty
				local detail = row.Frame:FindFirstChild("Detail") :: TextLabel?
				if b and detail and b.EndsAt then
					detail.Text = string.format("%s · Floor %d · %s", tostring(b.ItemName), b.FloorId or 0, clock(b.EndsAt - serverNow))
				end
			end
		end
	end
end)
