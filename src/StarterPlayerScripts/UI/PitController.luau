--!strict
-- The Pit is a single mounted interface. Quotes and outcomes always come from PitRequest.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local T = require(script.Parent:WaitForChild("PitDesignTokens"))
local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local StatFormulas = require(ReplicatedStorage.Shared.Util.StatFormulas)

local Pit = {}
local TAB_NAMES = {"Synthesis", "Imprints", "Promotion", "Conversion"}
local ACTIONS = {Synthesis = "SYNTHESIS", Imprints = "IMPRINT", Promotion = "PROMOTION", Conversion = "CONVERSION"}
local ACTION_LABELS = {Synthesis = "Synthesize", Imprints = "Perform imprint", Promotion = "Promote hero", Conversion = "Convert heroes"}
local SUBTITLES = {
	Synthesis = "Pass on experience. Choose every donor with care.",
	Imprints = "Preserve compatible combat knowledge in a surviving hero.",
	Promotion = "A guaranteed ascension, earned through training and crafted stones.",
	Conversion = "Release unwanted heroes into useful Soul Essence.",
}

local function autoLabel(parent: Instance, text: string, color: Color3?, size: number?): TextLabel
	local l = T.Label(parent, text, size or 14, color)
	l.Size = UDim2.new(1, -8, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextYAlignment = Enum.TextYAlignment.Top
	return l
end

local function clearContent(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

local function heroName(hero: any): string
	return string.format("%s · %s · Lv.%d\nID %s", hero.DisplayName or "Hero", T.Stars(hero.Stars), hero.Level or 1, hero.UUID or "unknown")
end

local function profileSignature(profile: any): string
	local parts = {}
	for uuid, hero in profile.Heroes or {} do
		table.insert(parts, table.concat({uuid, tostring(hero.Level), tostring(hero.XP), tostring(hero.Stars), tostring(hero.OverflowXP), tostring(hero.Assignment), tostring(hero.Locked), tostring(hero.Favorite), tostring((hero.ComaUntilTimestamp or 0) > os.time()), tostring((hero.CurrentStamina or 100) <= 0), tostring(hero.Reserved), tostring(hero.ReservedBy), tostring(hero.ReservedOperationId), tostring(hero.InCombat)}, ":"))
	end
	for key, value in profile.Currencies or {} do table.insert(parts, key .. ":" .. tostring(value)) end
	for key, value in profile.PitMaterials or profile.Materials or {} do table.insert(parts, key .. ":" .. tostring(value)) end
	table.sort(parts)
	return table.concat(parts, "|")
end

local function costsText(costs: any, resources: any): string
	local lines = {}
	for _, id in {"Gold", "Gems", "SoulEssence", "PromotionStone", "ImprintCatalyst", "ResearchPoints"} do
		local required = costs and costs[id] or 0
		if required > 0 then
			local name = id:gsub("(%l)(%u)", "%1 %2")
			table.insert(lines, string.format("%s  %s / %s%s", name, T.Number(resources[id]), T.Number(required), (resources[id] or 0) < required and "  • MISSING" or "  ✓"))
		end
	end
	return #lines > 0 and table.concat(lines, "\n") or "No resource payment"
end

function Pit.new(root: Frame, remote: RemoteFunction, facilityRemote: RemoteEvent, onClose: () -> ())
	local self: any = setmetatable({}, {__index = Pit})
	self.Root, self.Remote, self.FacilityRemote, self.OnClose = root, remote, facilityRemote, onClose
	self.State = {Heroes = {}, Resources = {}, Materials = {}, Currencies = {}}
	self.Tab, self.Mode, self.Step = "Synthesis", "RECIPIENT", 1
	self.Donors, self.Cards, self.Tabs, self.Connections, self.Tweens = {}, {}, {}, {}, {}
	self.Recipient, self.Imprint, self.Preview = nil, nil, nil
	self.Page, self.Filter, self.Sort, self.RoleFilter, self.StatusFilter = 1, "ALL", "LEVEL", "ALL", "ALL"
	self.Query, self.Message, self.LastResult = "", "Choose a recipient to begin.", nil
	self.Busy, self.StatePending, self.PreviewSerial = false, false, 0
	self.Phone, self.Tablet, self.Confirming, self.ConfirmRare = false, false, false, false
	self.ReducedMotion, self.LargeText = false, false
	pcall(function() self.ReducedMotion = (GuiService :: any).ReducedMotionEnabled == true end)
	pcall(function() self.LargeText = tostring((GuiService :: any).PreferredTextSize):find("Large") ~= nil end)
	self.TextSize = self.LargeText and 16 or 14
	root:ClearAllChildren()
	root.BackgroundColor3 = T.Color.Obsidian
	root.BackgroundTransparency = 0
	root.Active = true
	root.ClipsDescendants = true
	T.Corner(root, 12)
	T.Stroke(root, T.Color.Bronze, 1.5)
	root:SetAttribute("PitInterfaceVersion", 2)

	local title = T.Label(root, "THE PIT", T.Text.Title, T.Color.Gold)
	self.Title = title
	title.Name, title.Font = "PitTitle", Enum.Font.GothamBold
	title.Position, title.Size = UDim2.fromOffset(18, 10), UDim2.new(1, -98, 0, 30)
	self.Subtitle = T.Label(root, SUBTITLES.Synthesis, 12, T.Color.Muted)
	self.Subtitle.Position, self.Subtitle.Size = UDim2.fromOffset(18, 40), UDim2.new(1, -36, 0, 30)
	self.Close = T.Button(root, "×", function() if not self.Busy then self.OnClose() end end)
	self.Close.Name, self.Close.TextSize = "PitClose", 24
	self.Close.Position, self.Close.Size = UDim2.new(1, -60, 0, 12), UDim2.fromOffset(44, 44)
	self.CompactBack = T.Button(root, "‹", function() self:SetStep(math.max(self.Tab == "Conversion" and 2 or 1, self.Step - 1)) end)
	self.CompactBack.Name = "PitCompactBack"
	self.CompactBack.TextSize = 24
	self.CompactBack.Position, self.CompactBack.Size = UDim2.new(1, -110, 0, 8), UDim2.fromOffset(44, 44)
	self.CompactBack.Visible = false
	self.Resources = T.Label(root, "Loading resources…", 12, T.Color.Gold)
	self.Resources.Name = "PitResources"
	self.Resources.Position, self.Resources.Size = UDim2.fromOffset(18, 72), UDim2.new(1, -36, 0, 30)
	local rule = T.New("Frame", {BackgroundColor3 = T.Color.Bronze, BorderSizePixel = 0, Position = UDim2.fromOffset(18, 106), Size = UDim2.new(1, -36, 0, 1)}, root)
	for i, tab in TAB_NAMES do
		local b = T.Button(root, tab, function() self:SetTab(tab) end)
		b.Name, b.Position, b.Size = "PitTab" .. tab, UDim2.new((i - 1) / 4, 12, 0, 114), UDim2.new(0.25, -18, 0, 44)
		self.Tabs[tab] = b
	end
	for i, name in TAB_NAMES do
		self.Tabs[name].NextSelectionLeft = self.Tabs[TAB_NAMES[(i - 2) % #TAB_NAMES + 1]]
		self.Tabs[name].NextSelectionRight = self.Tabs[TAB_NAMES[i % #TAB_NAMES + 1]]
	end
	self.StepBar = T.New("Frame", {Name = "PitPhoneSteps", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 164), Size = UDim2.new(1, -24, 0, 44)}, root)
	self.StepBack = T.Button(self.StepBar, "‹ Back", function() self:SetStep(math.max(1, self.Step - 1)) end)
	self.StepBack.Size = UDim2.fromOffset(72, 44)
	self.StepLabel = T.Label(self.StepBar, "1 · Recipient", 13, T.Color.Gold)
	self.StepLabel.Position, self.StepLabel.Size = UDim2.fromOffset(80, 0), UDim2.new(1, -80, 1, 0)
	self.Body = T.New("Frame", {Name = "PitWorkspace", BackgroundTransparency = 1}, root)
	self.Roster = T.Panel(self.Body, "PitRoster")
	self.Chamber = T.Panel(self.Body, "PitChamber")
	self.Details = T.Panel(self.Body, "PitDetails")
	self:BuildRoster()
	self.ChamberScroll = T.Scroll(self.Chamber, "ChamberContent")
	self.ChamberScroll.Position, self.ChamberScroll.Size = UDim2.fromOffset(12, 12), UDim2.new(1, -24, 1, -24)
	T.List(self.ChamberScroll, 10)
	self.DetailScroll = T.Scroll(self.Details, "PreviewContent")
	self.DetailScroll.Position, self.DetailScroll.Size = UDim2.fromOffset(12, 12), UDim2.new(1, -24, 1, -24)
	T.List(self.DetailScroll, 10)
	self.Footer = T.Panel(root, "PitActionBar")
	self.Footer.Position, self.Footer.Size = UDim2.new(0, 12, 1, -80), UDim2.new(1, -24, 0, 68)
	self.Status = T.Label(self.Footer, self.Message, 12, T.Color.Muted)
	self.Status.Position, self.Status.Size = UDim2.fromOffset(12, 4), UDim2.new(1, -220, 1, -8)
	self.Action = T.Button(self.Footer, "Choose recipient", function() self:PrimaryAction() end)
	self.Action.Name = "PitPrimaryAction"
	self.Action.Position, self.Action.Size = UDim2.new(1, -204, 0.5, -24), UDim2.fromOffset(192, 48)
	self.Action.BackgroundColor3 = Color3.fromRGB(105, 78, 46)
	self:BuildConfirmation()
	table.insert(self.Connections, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local phone, tablet = self.Phone, self.Tablet
		self:Layout()
		if phone ~= self.Phone or tablet ~= self.Tablet then self:Render() end
	end))
	pcall(function()
		table.insert(self.Connections, GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
			self.ReducedMotion = (GuiService :: any).ReducedMotionEnabled
			self:CancelAnimations()
			self:RenderDetails()
		end))
		table.insert(self.Connections, GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(function()
			self.LargeText = tostring((GuiService :: any).PreferredTextSize):find("Large") ~= nil
			self.TextSize = self.LargeText and 16 or 14
			self:Render()
		end))
	end)
	table.insert(self.Connections, root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			self.PreviousFocus = GuiService.SelectedObject
			if UserInputService.GamepadEnabled then GuiService.SelectedObject = self.Tabs[self.Tab] end
			self:Refresh()
		else
			self:CancelAnimations()
			self.Confirming = false
			self.ConfirmOverlay.Visible = false
			if self.PreviousFocus and self.PreviousFocus.Parent then GuiService.SelectedObject = self.PreviousFocus else GuiService.SelectedObject = nil end
		end
	end))
	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, processed)
		if root.Visible and input.KeyCode == Enum.KeyCode.ButtonB and not self.Busy then
			if self.Confirming then self:CancelConfirmation() elseif self.Phone and self.Step > 1 then self:SetStep(self.Step - 1) else self.OnClose() end
		elseif root.Visible and input.KeyCode == Enum.KeyCode.Escape and not processed and self.Confirming then self:CancelConfirmation() end
	end))
	self:Layout()
	self:Render()
	return self
end

function Pit.Request(self: any, action: string, data: any?): any
	local ok, response = pcall(function() return self.Remote:InvokeServer(action, data) end)
	if not ok or type(response) ~= "table" then return {Success = false, Message = "The Pit could not respond. Please try again."} end
	return response
end

function Pit.BuildRoster(self: any)
	local title = T.Label(self.Roster, "HERO ROSTER", 14, T.Color.Gold)
	title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 24)
	self.RecipientMode = T.Button(self.Roster, "Recipient", function() self.Mode = "RECIPIENT"; self:RenderRoster() end)
	self.RecipientMode.Position, self.RecipientMode.Size = UDim2.fromOffset(10, 36), UDim2.new(0.5, -14, 0, 44)
	self.DonorMode = T.Button(self.Roster, "Donors · 0 / 6", function() self.Mode = "DONOR"; self:RenderRoster() end)
	self.DonorMode.Position, self.DonorMode.Size = UDim2.new(0.5, 4, 0, 36), UDim2.new(0.5, -14, 0, 44)
	self.Search = T.New("TextBox", {
		Name = "HeroSearch", PlaceholderText = "Search name, class, or ID…", Text = "", ClearTextOnFocus = false,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = T.Color.Text, PlaceholderColor3 = T.Color.Muted,
		BackgroundColor3 = T.Color.Obsidian, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 86), Size = UDim2.new(1, -20, 0, 44),
	}, self.Roster)
	T.Corner(self.Search, 6)
	self.Search:GetPropertyChangedSignal("Text"):Connect(function() self.Query = self.Search.Text:lower(); self.Page = 1; self:RenderRoster() end)
	self.FilterButton = T.Button(self.Roster, "Show: All", function()
		local filters = {"ALL", "AVAILABLE", "LOCKED", "1★", "2★", "3★", "4★", "5★"}
		local index = table.find(filters, self.Filter) or 1
		self.Filter = filters[index % #filters + 1]; self.Page = 1; self:RenderRoster()
	end)
	self.FilterButton.Position, self.FilterButton.Size = UDim2.fromOffset(10, 136), UDim2.new(0.54, -14, 0, 44)
	self.SortButton = T.Button(self.Roster, "Sort: Level", function()
		local sorts = {"LEVEL", "RARITY", "NAME", "POWER", "SYNTHESIS EXP"}
		self.Sort = sorts[(table.find(sorts, self.Sort) or 1) % #sorts + 1]
		self:RenderRoster()
	end)
	self.SortButton.Position, self.SortButton.Size = UDim2.new(0.54, 4, 0, 136), UDim2.new(0.46, -14, 0, 44)
	self.RoleButton = T.Button(self.Roster, "Class: All", function()
		local roles = {"ALL", "Vanguard", "Striker", "Marksman", "Miner", "Healer", "Scholar"}
		self.RoleFilter = roles[(table.find(roles, self.RoleFilter) or 1) % #roles + 1]
		self.Page = 1; self:RenderRoster()
	end)
	self.RoleButton.Position, self.RoleButton.Size = UDim2.fromOffset(10, 186), UDim2.new(0.54, -14, 0, 44)
	self.StatusButton = T.Button(self.Roster, "Status: All", function()
		local statuses = {"ALL", "Available", "Deployed", "Facility Worker", "Recovering", "Locked", "Protected", "Reserved"}
		self.StatusFilter = statuses[(table.find(statuses, self.StatusFilter) or 1) % #statuses + 1]
		self.Page = 1; self:RenderRoster()
	end)
	self.StatusButton.Position, self.StatusButton.Size = UDim2.new(0.54, 4, 0, 186), UDim2.new(0.46, -14, 0, 44)
	self.RosterScroll = T.Scroll(self.Roster, "HeroCards")
	self.RosterScroll.Position, self.RosterScroll.Size = UDim2.fromOffset(10, 236), UDim2.new(1, -20, 1, -292)
	T.List(self.RosterScroll, 8)
	self.RosterControls = T.New("Frame", {Name = "RosterControls", BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 194), LayoutOrder = 0}, self.RosterScroll)
	for _, control in {self.RecipientMode, self.DonorMode, self.Search, self.FilterButton, self.SortButton, self.RoleButton, self.StatusButton} do control.Parent = self.RosterControls end
	for i = 1, T.PageSize do
		local card = HeroCard.new(self.RosterScroll, function(uuid) self:SelectHero(uuid) end)
		card.Root.LayoutOrder = i
		self.Cards[i] = card
	end
	self.EmptyRoster = autoLabel(self.RosterScroll, "No heroes yet. Summon heroes in the Waiting Room.", T.Color.Muted)
	self.EmptyRoster.LayoutOrder = 10
	self.PreviousPage = T.Button(self.Roster, "‹", function() self.Page = math.max(1, self.Page - 1); self.RosterScroll.CanvasPosition = Vector2.new(); self:RenderRoster() end)
	self.PreviousPage.Position, self.PreviousPage.Size = UDim2.new(0, 10, 1, -50), UDim2.fromOffset(44, 44)
	self.PageLabel = T.Label(self.Roster, "1 / 1", 12, T.Color.Muted)
	self.PageLabel.Position, self.PageLabel.Size = UDim2.new(0, 60, 1, -50), UDim2.new(1, -120, 0, 44)
	self.PageLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.NextPage = T.Button(self.Roster, "›", function() self.Page = math.min(self.PageCount or 1, self.Page + 1); self.RosterScroll.CanvasPosition = Vector2.new(); self:RenderRoster() end)
	self.NextPage.Position, self.NextPage.Size = UDim2.new(1, -54, 1, -50), UDim2.fromOffset(44, 44)
	local pager = T.New("Frame", {Name = "RosterPages", BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 44), LayoutOrder = 20}, self.RosterScroll)
	self.PreviousPage.Parent, self.PageLabel.Parent, self.NextPage.Parent = pager, pager, pager
	self.PreviousPage.Position, self.PageLabel.Position, self.NextPage.Position = UDim2.new(), UDim2.fromOffset(50, 0), UDim2.new(1, -44, 0, 0)
end

function Pit.BuildConfirmation(self: any)
	self.ConfirmOverlay = T.New("Frame", {Name = "PitConfirmation", Visible = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.15, ZIndex = 70, Active = true}, self.Root)
	self.ConfirmPanel = T.Panel(self.ConfirmOverlay, "ConfirmPanel")
	self.ConfirmPanel.AnchorPoint, self.ConfirmPanel.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	self.ConfirmPanel.Size, self.ConfirmPanel.ZIndex = UDim2.new(0.92, 0, 0.9, 0), 71
	self.ConfirmScroll = T.Scroll(self.ConfirmPanel, "ExactTransaction")
	self.ConfirmScroll.Position, self.ConfirmScroll.Size, self.ConfirmScroll.ZIndex = UDim2.fromOffset(16, 16), UDim2.new(1, -32, 1, -132), 72
	self.ConfirmScroll.Selectable = true
	T.List(self.ConfirmScroll, 10)
	self.RareButton = T.Button(self.ConfirmPanel, "I understand these rare heroes will be lost", function() self.ConfirmRare = not self.ConfirmRare; self:RenderConfirmation() end)
	self.RareButton.Position, self.RareButton.Size, self.RareButton.ZIndex = UDim2.new(0, 16, 1, -112), UDim2.new(1, -32, 0, 44), 72
	self.Cancel = T.Button(self.ConfirmPanel, "Cancel", function() self:CancelConfirmation() end)
	self.Cancel.Position, self.Cancel.Size, self.Cancel.ZIndex = UDim2.new(0, 16, 1, -60), UDim2.new(0.4, -22, 0, 44), 72
	self.Confirm = T.Button(self.ConfirmPanel, "Confirm irreversible action", function() self:Commit() end)
	self.Confirm.Position, self.Confirm.Size, self.Confirm.ZIndex = UDim2.new(0.4, 6, 1, -60), UDim2.new(0.6, -22, 0, 44), 72
	self.Confirm.BackgroundColor3 = Color3.fromRGB(119, 68, 48)
	self.Cancel.NextSelectionLeft, self.Cancel.NextSelectionRight, self.Cancel.NextSelectionDown = self.Cancel, self.Confirm, self.Cancel
	self.Confirm.NextSelectionLeft, self.Confirm.NextSelectionRight, self.Confirm.NextSelectionDown = self.Cancel, self.Confirm, self.Confirm
	self.ConfirmScroll.NextSelectionUp, self.ConfirmScroll.NextSelectionLeft, self.ConfirmScroll.NextSelectionRight = self.ConfirmScroll, self.ConfirmScroll, self.ConfirmScroll
	self.RareButton.NextSelectionUp, self.RareButton.NextSelectionDown = self.ConfirmScroll, self.Confirm
	self.RareButton.NextSelectionLeft, self.RareButton.NextSelectionRight = self.RareButton, self.RareButton
end

function Pit.Layout(self: any)
	local width = self.Root.AbsoluteSize.X
	local short = self.Root.AbsoluteSize.Y < 560
	self.Tiny = self.Root.AbsoluteSize.Y < 450
	self.Phone, self.Tablet = width < 650, width < 1040
	self.Subtitle.Visible = not short
	self.Resources.Position = UDim2.fromOffset(18, self.Tiny and 34 or short and 40 or 72)
	self.Resources.Size = UDim2.new(1, -36, 0, self.Tiny and 24 or 30)
	for i, name in TAB_NAMES do self.Tabs[name].Position = UDim2.new((i - 1) / 4, 12, 0, self.Tiny and 64 or short and 76 or 114) end
	self.StepBar.Position = UDim2.fromOffset(12, short and 126 or 164)
	self.StepBar.Visible = self.Phone and not self.Tiny
	self.CompactBack.Visible = self.Tiny and self.Phone and self.Step > (self.Tab == "Conversion" and 2 or 1)
	self.Title.Text = self.Tiny and self.Phone and ("THE PIT · " .. self.Step .. " / 4") or "THE PIT"
	self.Title.Size = UDim2.new(1, self.CompactBack.Visible and -156 or -98, 0, 30)
	local top = self.Tiny and 116 or self.Phone and (short and 176 or 214) or (short and 128 or 168)
	self.Body.Position = UDim2.fromOffset(12, top)
	self.Body.Size = UDim2.new(1, -24, 1, -(top + (self.Tiny and 68 or 88)))
	self.Footer.Position, self.Footer.Size = UDim2.new(0, 12, 1, self.Tiny and -60 or -80), UDim2.new(1, -24, 0, self.Tiny and 48 or 68)
	if self.Phone then
		for _, panel in {self.Roster, self.Chamber, self.Details} do panel.Position, panel.Size = UDim2.new(), UDim2.fromScale(1, 1) end
		self.Roster.Visible = self.Step <= 2
		self.Chamber.Visible = false
		self.Details.Visible = self.Step >= 3
		self.Mode = self.Step == 1 and self.Tab ~= "Conversion" and "RECIPIENT" or "DONOR"
		self.RecipientMode.Visible, self.DonorMode.Visible = false, false
		self.Search.Position = UDim2.new()
		self.FilterButton.Position, self.SortButton.Position = UDim2.fromOffset(0, 50), UDim2.new(0.54, 4, 0, 50)
		self.RoleButton.Position, self.StatusButton.Position = UDim2.fromOffset(0, 100), UDim2.new(0.54, 4, 0, 100)
		self.RosterControls.Size = UDim2.new(1, -6, 0, 144)
		self.Status.Size, self.Status.TextSize = UDim2.new(0.48, -16, 1, -8), 11
		self.Action.Position, self.Action.Size = UDim2.new(0.48, 0, 0.5, self.Tiny and -22 or -24), UDim2.new(0.52, -10, 0, self.Tiny and 44 or 48)
	elseif self.Tablet then
		self.Roster.Position, self.Roster.Size = UDim2.new(), UDim2.new(0.45, -6, 1, 0)
		self.Details.Position, self.Details.Size = UDim2.new(0.45, 6, 0, 0), UDim2.new(0.55, -6, 1, 0)
		self.Roster.Visible, self.Details.Visible, self.Chamber.Visible = true, true, false
	else
		self.Roster.Position, self.Roster.Size = UDim2.new(), UDim2.new(0.32, -8, 1, 0)
		self.Chamber.Position, self.Chamber.Size = UDim2.new(0.32, 4, 0, 0), UDim2.new(0.34, -8, 1, 0)
		self.Details.Position, self.Details.Size = UDim2.new(0.66, 8, 0, 0), UDim2.new(0.34, -8, 1, 0)
		self.Roster.Visible, self.Chamber.Visible, self.Details.Visible = true, true, true
	end
	if not self.Phone then
		self.RecipientMode.Visible, self.DonorMode.Visible = self.Tab ~= "Conversion", self.Tab ~= "Promotion"
		self.RecipientMode.Position, self.DonorMode.Position = UDim2.new(), UDim2.new(0.5, 4, 0, 0)
		self.Search.Position = UDim2.fromOffset(0, 50)
		self.FilterButton.Position, self.SortButton.Position = UDim2.fromOffset(0, 100), UDim2.new(0.54, 4, 0, 100)
		self.RoleButton.Position, self.StatusButton.Position = UDim2.fromOffset(0, 150), UDim2.new(0.54, 4, 0, 150)
		self.RosterControls.Size = UDim2.new(1, -6, 0, 194)
		self.Status.Size, self.Status.TextSize = UDim2.new(1, -220, 1, -8), 12
		self.Action.Position, self.Action.Size = UDim2.new(1, -204, 0.5, self.Tiny and -22 or -24), UDim2.fromOffset(192, self.Tiny and 44 or 48)
	end
	self.RosterScroll.Position, self.RosterScroll.Size = UDim2.fromOffset(10, 36), UDim2.new(1, -20, 1, -48)
	self.Search.Size = UDim2.new(1, 0, 0, 44)
	self:UpdateAction()
end

function Pit.SetStep(self: any, step: number)
	if self.Busy then return end
	self.Step = step
	self:Layout()
	self:RenderRoster()
	if step >= 3 then self:RenderDetails() end
end

function Pit.SetTab(self: any, tab: string)
	if self.Busy then return end
	self:CancelAnimations()
	self:CancelConfirmation()
	self.Tab, self.Imprint, self.Recipe, self.LastResult = tab, nil, nil, nil
	if tab == "Promotion" then self.Donors = {}; self.Mode = "RECIPIENT"
	elseif tab == "Conversion" then self.Mode = "DONOR"
	elseif tab == "Imprints" and #self.Donors > 1 then self.Donors = {self.Donors[1]} end
	self.Step = tab == "Conversion" and 2 or 1
	self.Message = tab == "Conversion" and "Choose heroes to convert. Each selection is explicit." or "Choose a recipient and review the ritual."
	self:Layout()
	self:Render()
	self:QueuePreview()
end

function Pit.Invalidate(self: any)
	self:CancelAnimations()
	self.Preview = nil
	self.PreviewSerial += 1
	if self.Confirming then self:CancelConfirmation() end
end

function Pit.SelectHero(self: any, uuid: string)
	if self.Busy then return end
	local hero = self.State.Heroes[uuid]
	if not hero then return end
	self.LastResult, self.Recipe = nil, nil
	if self.Mode == "RECIPIENT" and self.Tab ~= "Conversion" then
		self.Recipient = uuid
		local index = table.find(self.Donors, uuid)
		if index then table.remove(self.Donors, index) end
		self.Imprint = nil
		self.Message = "Recipient selected. Choose each material hero explicitly."
	else
		local index = table.find(self.Donors, uuid)
		if index then table.remove(self.Donors, index)
		elseif uuid == self.Recipient and self.Tab ~= "Conversion" then self.Message = "The recipient cannot also be a donor."; self:UpdateAction(); return
		elseif hero.PitStatus and not hero.PitStatus.EligibleDonor then self.Message = (hero.PitStatus.Reason or "This hero is unavailable.") .. ((hero.Locked or hero.Favorite or hero.Favorited) and " Choose this hero as recipient to unlock its protection." or ""); self:UpdateAction(); return
		elseif #self.Donors >= (self.Tab == "Imprints" and 1 or self.State.MaxDonors or 6) then self.Message = self.Tab == "Imprints" and "Focused imprints use exactly one donor. Remove it before choosing another." or "The altar holds six donors. Remove one before adding another."; self:UpdateAction(); return
		else table.insert(self.Donors, uuid) end
		self.Message = string.format("%d material hero%s selected. Review exact identities before confirming.", #self.Donors, #self.Donors == 1 and "" or "es")
		self.Imprint = nil
	end
	self:Invalidate()
	self:Render()
	self:QueuePreview()
end

function Pit.RemoveDonor(self: any, uuid: string)
	if self.Busy then return end
	local index = table.find(self.Donors, uuid)
	if not index then return end
	table.remove(self.Donors, index)
	self.Imprint, self.LastResult = nil, nil
	self:Invalidate()
	self:Render()
	self:QueuePreview()
end

function Pit.RenderRoster(self: any)
	local heroes = {}
	for _, hero in self.State.Heroes do
		local status = hero.PitStatus or {}
		local haystack = ((hero.DisplayName or "") .. " " .. (hero.Archetype or "") .. " " .. (hero.UUID or "")):lower()
		local matches = self.Query == "" or haystack:find(self.Query, 1, true) ~= nil
		local filter = self.Filter == "ALL" or (self.Filter == "AVAILABLE" and status.EligibleDonor == true) or (self.Filter == "LOCKED" and (hero.Locked or hero.Favorite)) or self.Filter == tostring(hero.Stars) .. "★"
		local roleMatch = self.RoleFilter == "ALL" or hero.Archetype == self.RoleFilter
		local statusMatch = self.StatusFilter == "ALL" or status.Status == self.StatusFilter
		if matches and filter and roleMatch and statusMatch then table.insert(heroes, hero) end
	end
	table.sort(heroes, function(a, b)
		if self.Sort == "RARITY" and a.Stars ~= b.Stars then return a.Stars > b.Stars end
		if self.Sort == "LEVEL" and a.Level ~= b.Level then return a.Level > b.Level end
		if self.Sort == "POWER" then
			local aPower = a.Stats and a.Stats.DPS or 0
			local bPower = b.Stats and b.Stats.DPS or 0
			if aPower ~= bPower then return aPower > bPower end
		end
		if self.Sort == "SYNTHESIS EXP" and a.SynthesisXPValue ~= b.SynthesisXPValue then return (a.SynthesisXPValue or 0) > (b.SynthesisXPValue or 0) end
		if a.DisplayName ~= b.DisplayName then return a.DisplayName < b.DisplayName end
		return a.UUID < b.UUID
	end)
	self.PageCount = math.max(1, math.ceil(#heroes / T.PageSize))
	self.Page = math.clamp(self.Page, 1, self.PageCount)
	for i, card in self.Cards do
		local hero = heroes[(self.Page - 1) * T.PageSize + i]
		if hero then card:Update(hero, self.Mode == "RECIPIENT" and hero.UUID == self.Recipient or self.Mode == "DONOR" and table.find(self.Donors, hero.UUID) ~= nil, self.Mode, self.TextSize)
		else card.Root.Visible = false end
	end
	self.EmptyRoster.Visible = #heroes == 0
	self.EmptyRoster.Text = next(self.State.Heroes) == nil and "Your roster is empty. Summon heroes in the Waiting Room." or "No matching heroes. Change the filter or search."
	self.PageLabel.Text = string.format("%d / %d · %d heroes", self.Page, self.PageCount, #heroes)
	self.FilterButton.Text, self.SortButton.Text = "Show: " .. self.Filter, "Sort: " .. self.Sort:lower()
	self.RoleButton.Text, self.StatusButton.Text = "Class: " .. self.RoleFilter, "Status: " .. self.StatusFilter
	self.RecipientMode.BackgroundColor3 = self.Mode == "RECIPIENT" and Color3.fromRGB(85, 67, 45) or T.Color.Raised
	self.DonorMode.BackgroundColor3 = self.Mode == "DONOR" and Color3.fromRGB(85, 67, 45) or T.Color.Raised
	self.DonorMode.Text = string.format("%s · %d / %d", self.Tab == "Conversion" and "Convert" or "Donors", #self.Donors, self.Tab == "Imprints" and 1 or self.State.MaxDonors or 6)
end

function Pit.RenderChamber(self: any)
	clearContent(self.ChamberScroll)
	autoLabel(self.ChamberScroll, self.Tab == "Conversion" and "THE ESSENCE CRUCIBLE" or "THE MEMORY ALTAR", T.Color.Gold, 15)
	local altar = T.New("Frame", {Name = "RitualAltar", BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 190)}, self.ChamberScroll)
	for i = 1, 3 do
		local diameter = 176 - i * 22
		local ring = T.New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(diameter, diameter), BackgroundTransparency = 1, Rotation = i * 17}, altar)
		T.Corner(ring, diameter)
		T.Stroke(ring, i == 3 and T.Color.Gold or T.Color.Bronze, i == 3 and 2 or 1)
	end
	for i = 0, 7 do
		local theta = math.rad(i * 45)
		T.New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(theta) * 84, 0.5, math.sin(theta) * 84), Size = UDim2.fromOffset(4, 10), Rotation = i * 45, BackgroundColor3 = T.Color.Bronze, BorderSizePixel = 0}, altar)
	end
	local hero = self.Recipient and self.State.Heroes[self.Recipient]
	if hero and self.Tab ~= "Conversion" then
		local host = T.New("Frame", {Name = "RecipientPortrait", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(102, 116), BackgroundTransparency = 1}, altar)
		HeroCard.Portrait(host, hero)
		autoLabel(self.ChamberScroll, heroName(hero), T.Rarity[hero.Stars], 16)
		if hero.PitStatus and hero.PitStatus.Status == "Protected" then
			autoLabel(self.ChamberScroll, "Unique hero · permanently protected", T.Color.Gold, 12)
		else
			local protected = hero.Locked or hero.Favorite or hero.Favorited
			local lock = T.Button(self.ChamberScroll, protected and "Unlock hero protection" or "Lock hero against consumption", function() self:LockHero(hero.UUID, not protected) end)
			lock.TextSize = 12
		end
	else
		local glyph = T.Label(altar, self.Tab == "Conversion" and "◇" or "+", 48, T.Color.Bronze)
		glyph.Size, glyph.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
		autoLabel(self.ChamberScroll, self.Tab == "Conversion" and "Select heroes to release into Soul Essence." or "Select a surviving recipient from the roster.", T.Color.Muted)
	end
	if self.Tab ~= "Promotion" then
		autoLabel(self.ChamberScroll, self.Tab == "Conversion" and "HEROES TO CONVERT" or "SELECTED DONORS", T.Color.Gold, 12)
		for i = 1, (self.Tab == "Imprints" and 1 or self.State.MaxDonors or 6) do
			local uuid = self.Donors[i]
			local donor = uuid and self.State.Heroes[uuid]
			local slot = T.Button(self.ChamberScroll, donor and ("− " .. donor.DisplayName .. " · " .. T.Stars(donor.Stars) .. "\n" .. uuid) or ("+ Empty slot " .. i), function()
				if self.Busy then return end
				if uuid then self:RemoveDonor(uuid) else self.Mode = "DONOR"; if self.Phone then self:SetStep(2) else self:RenderRoster() end end
			end)
			slot.Name = "DonorSlot" .. i
			slot.TextSize = 12
			if donor then slot.TextColor3 = T.Rarity[donor.Stars] end
		end
	end
	autoLabel(self.ChamberScroll, "Heroes marked unavailable stay visible. Bench assigned heroes in the Waiting Room; recover resting heroes before sacrifice.", T.Color.Muted, 12)
	T.Button(self.ChamberScroll, "Open Waiting Room assignments", function() if not self.Busy then _G.OpenMasterModal("WAITING_ROOM") end end)
end

function Pit.RenderDetails(self: any)
	clearContent(self.DetailScroll)
	local preview = self.Preview
	local hero = self.Recipient and self.State.Heroes[self.Recipient]
	autoLabel(self.DetailScroll, self.LastResult and "RITUAL COMPLETE" or "RITUAL PREVIEW", T.Color.Gold, 15)
	if self.LastResult then
		autoLabel(self.DetailScroll, self.LastResult, T.Color.Good, self.TextSize)
		local skip = T.Button(self.DetailScroll, "Skip celebration", function() self:CancelAnimations() end)
		skip.Visible = not self.ReducedMotion
	end
	if not self.Chamber.Visible then
		if hero and self.Tab ~= "Conversion" then
			autoLabel(self.DetailScroll, "RECIPIENT\n" .. heroName(hero), T.Rarity[hero.Stars], self.TextSize)
			if hero.PitStatus and hero.PitStatus.Status == "Protected" then autoLabel(self.DetailScroll, "Unique hero · permanently protected", T.Color.Gold, 12)
			else
				local protected = hero.Locked or hero.Favorite or hero.Favorited
				T.Button(self.DetailScroll, protected and "Unlock hero protection" or "Lock hero against consumption", function() self:LockHero(hero.UUID, not protected) end)
			end
		end
		if #self.Donors > 0 then
			autoLabel(self.DetailScroll, "EXACT MATERIAL HEROES", T.Color.Gold, 12)
			for _, uuid in self.Donors do
				local donor = self.State.Heroes[uuid]
				if donor then T.Button(self.DetailScroll, "Remove · " .. heroName(donor), function() self:RemoveDonor(uuid) end).TextSize = self.TextSize end
			end
		end
	end
	local hasSelection = self.Recipe or (self.Tab == "Conversion" and #self.Donors > 0) or (self.Tab ~= "Conversion" and hero ~= nil)
	if preview and hasSelection then
		if preview.Before and preview.After then
			local before, after = preview.Before, preview.After
			autoLabel(self.DetailScroll, string.format("%s → %s\nLEVEL %s → %s   /   CAP %s → %s", T.Stars(before.Stars), T.Stars(after.Stars), T.Number(before.Level), T.Number(after.Level), T.Number(before.MaxLevel), T.Number(after.MaxLevel)), T.Color.Text, self.TextSize)
			local statLines = {}
			for _, key in {"HP", "ATK", "DPS", "Labor"} do
				if before[key] ~= nil then table.insert(statLines, string.format("%s   %s → %s  (%+.1f)", key == "Labor" and "Labor / min" or key, T.Number(before[key]), T.Number(after[key]), (after[key] or 0) - (before[key] or 0))) end
			end
			autoLabel(self.DetailScroll, table.concat(statLines, "\n"), T.Color.Good, self.TextSize)
			if preview.XP then
				local xp = preview.XP
				local nextLevel = after.Level >= after.MaxLevel and (after.Stars >= 5 and "Maximum level reached · pursue compatible Imprints" or "At level cap · promotion releases reserved EXP") or (T.Number(math.max(0, StatFormulas.GetXPRequiredForNextLevel(after.Level or 1) - (after.XP or 0))) .. " EXP to next level")
				autoLabel(self.DetailScroll, string.format("EXP %s → %s\n%s\nBase +%s · Efficiency %s%%\nFinal +%s EXP", T.Number(before.XP), T.Number(after.XP), nextLevel, T.Number(xp.Base), T.Number((xp.Efficiency or 1) * 100), T.Number(xp.Final)), T.Color.Text, self.TextSize)
				local track = T.New("Frame", {Name = "PreviewXPTrack", BackgroundColor3 = T.Color.Obsidian, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 8)}, self.DetailScroll)
				T.Corner(track, 4)
				local startRatio = math.clamp((before.XP or 0) / StatFormulas.GetXPRequiredForNextLevel(before.Level or 1), 0, 1)
				local finalRatio = math.clamp((after.XP or 0) / StatFormulas.GetXPRequiredForNextLevel(after.Level or 1), 0, 1)
				if after.Level >= after.MaxLevel then finalRatio = 1 end
				local fill = T.New("Frame", {BackgroundColor3 = T.Color.Gold, BorderSizePixel = 0, Size = UDim2.fromScale(self.ReducedMotion and finalRatio or startRatio, 1)}, track)
				T.Corner(fill, 4)
				if not self.ReducedMotion then local tween = TweenService:Create(fill, TweenInfo.new(T.Duration.Preview), {Size = UDim2.fromScale(finalRatio, 1)}); table.insert(self.Tweens, tween); tween:Play() end
				for _, entry in xp.Breakdown or {} do
					if type(entry) == "table" then autoLabel(self.DetailScroll, string.format("%s · +%s EXP", entry.Name or entry.DisplayName or entry.UUID or "Donor", T.Number(entry.Final or entry.XP)), T.Color.Muted, 12) end
				end
			end
		end
		if preview.Overflow then autoLabel(self.DetailScroll, string.format("Overflow reserve: %s / %s EXP\nRejected excess: %s EXP", T.Number(preview.Overflow.Stored), T.Number(preview.Overflow.Capacity), T.Number(preview.Overflow.Rejected)), (preview.Overflow.Rejected or 0) > 0 and T.Color.Danger or T.Color.Muted, 12) end
		if preview.Costs then autoLabel(self.DetailScroll, "COSTS · owned / required\n" .. costsText(preview.Costs, self.State.Resources or {}), T.Color.Gold, self.TextSize) end
		if preview.Before and preview.After then
			autoLabel(self.DetailScroll, string.format("Inherited memory slots: %s → %s", T.Number(preview.Before.ImprintCapacity), T.Number(preview.After.ImprintCapacity)), T.Color.Memory, self.TextSize)
		end
		for key, value in preview.Rewards or {} do if type(value) == "number" then autoLabel(self.DetailScroll, "+" .. T.Number(value) .. " " .. tostring(key):gsub("(%l)(%u)", "%1 %2"), T.Color.Good, self.TextSize) end end
		for _, requirement in preview.Requirements or {} do
			if type(requirement) == "table" then autoLabel(self.DetailScroll, (requirement.Met and "✓ " or "○ ") .. (requirement.Label or requirement.Name or requirement.Reason or "Requirement") .. (requirement.Current ~= nil and string.format("  %s / %s", T.Number(requirement.Current), T.Number(requirement.Required)) or ""), requirement.Met and T.Color.Good or T.Color.Danger, self.TextSize)
			else autoLabel(self.DetailScroll, tostring(requirement), T.Color.Muted, self.TextSize) end
		end
		if self.Tab == "Imprints" then self:RenderImprints(preview) end
		if self.Tab == "Synthesis" and preview.Before and preview.Before.Level >= preview.Before.MaxLevel then
			T.Button(self.DetailScroll, preview.Before.Stars >= 5 and "Maximum level · Explore imprints" or "At level cap · Review promotion", function() self:SetTab(preview.Before.Stars >= 5 and "Imprints" or "Promotion") end)
		end
		if self.Tab == "Synthesis" and #(preview.Imprints or {}) > 0 then
			autoLabel(self.DetailScroll, "MEMORY OPPORTUNITIES · use the Imprints tab to inherit; normal synthesis grants EXP only.", T.Color.Memory, 12)
			for _, option in preview.Imprints do autoLabel(self.DetailScroll, string.format("%s · %s\n%s", option.DonorName or "Donor", option.Name, option.Compatible and "Compatible memory available" or option.Reason or "Incompatible"), T.Color.Muted, 12) end
		end
		for _, warning in preview.Warnings or {} do autoLabel(self.DetailScroll, "! " .. tostring(warning), T.Color.Gold, self.TextSize) end
		local needsMaterials = not self.Recipe and (self.Tab == "Synthesis" or self.Tab == "Imprints") and #self.Donors == 0
		if needsMaterials then autoLabel(self.DetailScroll, "Choose material heroes from the roster to calculate this ritual.", T.Color.Muted, self.TextSize)
		else
			local seen = {}
			for _, issue in preview.Errors or {} do
				if not seen[issue] then autoLabel(self.DetailScroll, tostring(issue), T.Color.Danger, self.TextSize); seen[issue] = true end
			end
			if not preview.CanCommit and preview.Reason ~= "" and not seen[preview.Reason] then autoLabel(self.DetailScroll, preview.Reason or "Complete the ritual requirements above.", T.Color.Danger, self.TextSize) end
		end
	else
		autoLabel(self.DetailScroll, self.PreviewLoading and "Calculating your authoritative ritual preview…" or "Choose a recipient, then explicitly select material heroes. Your real EXP, stats and costs appear here before any hero is consumed.", T.Color.Muted, self.TextSize)
	end
	if self.Tab == "Promotion" then
		autoLabel(self.DetailScroll, "PROMOTION WORKSHOP", T.Color.Gold, 13)
		autoLabel(self.DetailScroll, "Conversion supplies Soul Essence. Craft stones with Essence, Gold and Gems. Promotion guarantees exactly one star, up to 5★.", T.Color.Muted, 12)
		self:RenderRecipes("PromotionStone")
	elseif self.Tab == "Imprints" then
		autoLabel(self.DetailScroll, "IMPRINT WORKSHOP", T.Color.Gold, 13)
		self:RenderRecipes("ImprintCatalyst")
	elseif self.Tab == "Conversion" then
		autoLabel(self.DetailScroll, "Conversion consumes only your checked heroes. Rewards are deterministic. Locked, assigned and protected heroes cannot be converted.", T.Color.Muted, 12)
	end
	self:RenderResearch()
	autoLabel(self.DetailScroll, "Train in combat too: recently commanded heroes earn combat EXP after meaningful damage. The Pit remains a deliberate choice for faster progression.", T.Color.Muted, 12)
	T.Button(self.DetailScroll, self.ReducedMotion and "Motion: Reduced ✓" or "Motion: Standard", function() self.ReducedMotion = not self.ReducedMotion; self:CancelAnimations(); self:RenderDetails() end)
	T.Button(self.DetailScroll, self.LargeText and "Text: Large ✓" or "Text: Standard", function() self.LargeText = not self.LargeText; self.TextSize = self.LargeText and 16 or 14; self:Render() end)
	T.Button(self.DetailScroll, "Manage assignments in Waiting Room", function() if not self.Busy then _G.OpenMasterModal("WAITING_ROOM") end end)
	for _, descendant in self.DetailScroll:GetDescendants() do if descendant:IsA("GuiObject") then descendant.ZIndex = 22 end end
end

function Pit.RenderImprints(self: any, preview: any)
	autoLabel(self.DetailScroll, "CHOOSE A COMPATIBLE MEMORY", T.Color.Memory, 13)
	autoLabel(self.DetailScroll, "Focused imprint: guaranteed compatible inheritance, reduced synthesis EXP, one sacrificed donor. Signature traits remain intact.", T.Color.Muted, 12)
	local options = preview.Imprints or {}
	if #options == 0 then autoLabel(self.DetailScroll, "Select one donor to reveal compatible memories. A different class may offer a different memory.", T.Color.Muted, 12) end
	for _, option in options do
		local b = T.Button(self.DetailScroll, (self.Imprint == option.Id and "✓ " or "") .. option.Name .. "\n" .. option.Description .. "\n" .. (option.Compatible and string.format("Compatible · %s%% success · rank %d / %d", T.Number((option.SuccessChance or 1) * 100), option.CurrentRank or 0, option.MaxRank or 3) or (option.Reason or "Incompatible")), function()
			if self.Busy then return end
			if not option.Compatible then self.Message = option.Reason or "This memory is incompatible."; self:UpdateAction(); return end
			self.Imprint = option.Id; self.Recipe = nil; self:Invalidate(); self:QueuePreview(); self:RenderDetails()
		end)
		b.Size, b.TextSize = UDim2.new(1, -8, 0, 104), 12
		b.Name = "MemoryOption_" .. option.Id
		b.TextColor3 = option.Compatible and T.Color.Memory or T.Color.Muted
	end
end

function Pit.RenderRecipes(self: any, recipeId: string)
	local recipes = self.State.Recipes or {}
	local recipe = recipes[recipeId]
	if not recipe then for _, entry in recipes do if type(entry) == "table" and (entry.Id == recipeId or entry.Recipe == recipeId) then recipe = entry end end end
	local name = recipeId:gsub("(%l)(%u)", "%1 %2")
	if recipe then autoLabel(self.DetailScroll, name .. " · " .. costsText(recipe.Costs or recipe, self.State.Resources or {}), T.Color.Muted, 12) end
	local craft = T.Button(self.DetailScroll, "Craft 1 " .. name .. " · Review costs", function()
		if self.Busy then return end
		self.Recipe = recipeId
		self:Invalidate()
		self:QueuePreview()
	end)
	craft.Name = "Craft" .. recipeId
	if self.Recipe then T.Button(self.DetailScroll, "Return to hero ritual", function() self.Recipe = nil; self:Invalidate(); self:QueuePreview() end) end
end

function Pit.RenderResearch(self: any)
	local research = self.State.Research or {}
	if next(research) == nil then return end
	T.Button(self.DetailScroll, self.ShowResearch and "Hide Dimensional Lab research ▴" or "Dimensional Lab research ▾", function() self.ShowResearch = not self.ShowResearch; self:RenderDetails() end)
	if not self.ShowResearch then return end
	for key, node in research do
		if type(node) == "table" then
			local unlocked = node.Unlocked or (self.State.UnlockedResearch and self.State.UnlockedResearch[node.ResearchKey or node.Key or key])
			if not unlocked and node.ResearchKey then
				autoLabel(self.DetailScroll, "RESEARCH · " .. (node.Name or node.Label or tostring(key)) .. "\n" .. (node.Description or "") .. "\nLab level " .. T.Number(node.ReqLabLevel) .. " required\n" .. costsText(node.Costs or {ResearchPoints = node.RPCost or node.Cost or 0, Gold = node.GoldCost or 0}, self.State.Resources or {}), T.Color.Muted, self.TextSize)
				T.Button(self.DetailScroll, "Unlock " .. (node.Name or node.Label or "research"), function()
					if self.Busy then return end
					self.FacilityRemote:FireServer("UNLOCK_TECH", node.Id or node.TechId or key)
					self.Message = "Research requested. The server will validate your prerequisites."
				self:UpdateAction()
					task.delay(0.4, function() if self.Root.Parent and self.Root.Visible then self:Refresh() end end)
				end)
			end
		end
	end
end

function Pit.Render(self: any)
	self.Subtitle.Text = SUBTITLES[self.Tab]
	local resources = self.State.Resources or {}
	self.Resources.Text = string.format("GOLD %s   ·   ESSENCE %s   ·   STONES %s   ·   CATALYSTS %s", T.Number(resources.Gold), T.Number(resources.SoulEssence), T.Number(resources.PromotionStone), T.Number(resources.ImprintCatalyst))
	for name, button in self.Tabs do button.BackgroundColor3 = name == self.Tab and Color3.fromRGB(89, 68, 44) or T.Color.Panel; button.TextColor3 = name == self.Tab and T.Color.Gold or T.Color.Muted end
	self:RenderRoster()
	self:RenderChamber()
	self:RenderDetails()
	self:UpdateAction()
	for _, descendant in self.Body:GetDescendants() do if descendant:IsA("GuiObject") then descendant.ZIndex = 22 end end
end

function Pit.UpdateAction(self: any)
	local labels = {"1 / 4 · Select recipient", "2 / 4 · Select materials", "3 / 4 · Review ritual", "4 / 4 · Confirm"}
	self.StepLabel.Text = labels[self.Step] or labels[1]
	self.Status.Text = self.Message
	if self.Busy then self.Action.Text = "Processing…"; self.Action.Active = false; return end
	self.Action.Active = true
	if self.Phone and self.Step < 3 and not self.Recipe then
		self.Action.Text = self.Step == 1 and "Next · Materials" or "Next · Review"
		return
	end
	local ready = self.Preview and self.Preview.CanCommit and not self.PreviewLoading
	self.Action.Text = self.Recipe and "Review crafting" or ACTION_LABELS[self.Tab]
	self.Action.BackgroundColor3 = ready and Color3.fromRGB(113, 85, 48) or T.Color.Raised
	if not ready then
		self.Action.Text = self.PreviewLoading and "Calculating…" or "Complete requirements"
		if self.Preview and self.Preview.Reason then self.Status.Text = self.Preview.Reason end
	end
end

function Pit.QueuePreview(self: any)
	self.PreviewSerial += 1
	local serial = self.PreviewSerial
	self.PreviewLoading = true
	self:UpdateAction()
	task.delay(T.Duration.Debounce, function()
		if serial ~= self.PreviewSerial or not self.Root.Parent or not self.Root.Visible then return end
		local action = self.Recipe and "CRAFT" or ACTIONS[self.Tab]
		local request: any = {Action = action, Donors = self.Recipe and {} or table.clone(self.Donors), Imprint = self.Imprint, Recipe = self.Recipe}
		if action ~= "CRAFT" and action ~= "CONVERSION" then request.Recipient = self.Recipient end
		local response = self:Request("PREVIEW", request)
		if serial ~= self.PreviewSerial or not self.Root.Parent then return end
		self.PreviewLoading = false
		self.Preview = response.Preview
		if not response.Success then self.Message = response.Message or "The ritual preview is unavailable." end
		self:RenderDetails()
		self:UpdateAction()
	end)
end

function Pit.Refresh(self: any)
	if self.StatePending or self.Busy or not self.Root.Visible then return end
	self.StatePending = true
	task.spawn(function()
		local response = self:Request("STATE")
		self.StatePending = false
		if not self.Root.Parent then return end
		if response.Success and response.State then
			self.State = response.State
			self.State.Resources = self.State.Resources or {}
			for key, value in self.State.Currencies or {} do self.State.Resources[key] = value end
			for key, value in self.State.Materials or {} do self.State.Resources[key] = value end
			self.Signature = profileSignature(self.State)
			if self.Recipient and not self.State.Heroes[self.Recipient] then self.Recipient = nil end
			for i = #self.Donors, 1, -1 do if not self.State.Heroes[self.Donors[i]] then table.remove(self.Donors, i) end end
			self:Render()
			if not self.Confirming then self:QueuePreview() end
		else self.Message = response.Message or "The roster could not be loaded."; self:UpdateAction() end
	end)
end

function Pit.ApplyDelta(self: any, delta: any)
	if not delta then return end
	for uuid, hero in delta.Heroes or {} do self.State.Heroes[uuid] = hero end
	for _, uuid in delta.Removed or {} do self.State.Heroes[uuid] = nil end
	for _, key in {"Currencies", "Materials", "Resources", "UnlockedResearch", "Revision"} do
		if delta[key] ~= nil then self.State[key] = delta[key] end
	end
	self.State.Resources = self.State.Resources or {}
	for key, value in self.State.Currencies or {} do self.State.Resources[key] = value end
	for key, value in self.State.Materials or {} do self.State.Resources[key] = value end
end

function Pit.ProfileChanged(self: any, profile: any?)
	if self.RefreshQueued or not self.Root.Visible or self.Busy or self.Confirming then return end
	if profile and profileSignature(profile) == self.Signature then return end
	self.RefreshQueued = true
	task.delay(0.7, function()
		self.RefreshQueued = false
		if self.Root.Parent and self.Root.Visible and not self.Confirming then self:Refresh() end
	end)
end

function Pit.LockHero(self: any, uuid: string, locked: boolean)
	if self.Busy then return end
	self:Invalidate()
	self.Busy = true; self:UpdateAction()
	task.spawn(function()
		local response = self:Request("LOCK", {Hero = uuid, Locked = locked})
		self.Busy = false; self.Message = response.Message or (response.Success and "Hero protection updated." or "Protection could not be updated.")
		self:ApplyDelta(response.Delta)
		self:Render()
		self:Refresh()
	end)
end

function Pit.PrimaryAction(self: any)
	if self.Busy or self.PreviewLoading then return end
	if self.Phone and self.Step < 3 and not self.Recipe then
		if self.Step == 1 and not self.Recipient then self.Message = "Select the hero who will survive the ritual."; self:UpdateAction(); return end
		if self.Step == 2 and self.Tab ~= "Promotion" and #self.Donors == 0 then self.Message = "Choose at least one material hero explicitly."; self:UpdateAction(); return end
		self:SetStep(self.Tab == "Promotion" and 3 or self.Step + 1)
		return
	end
	if not self.Preview or not self.Preview.CanCommit then self.Message = self.Preview and self.Preview.Reason or "Choose valid heroes and complete the requirements."; self:UpdateAction(); return end
	self.Confirming, self.ConfirmRare = true, false
	self.FocusBeforeConfirm = GuiService.SelectedObject
	self.ConfirmOverlay.Visible = true
	self:RenderConfirmation()
	GuiService.SelectedObject = self.Cancel
end

function Pit.RenderConfirmation(self: any)
	if not self.Preview then return end
	clearContent(self.ConfirmScroll)
	local preview = self.Preview
	autoLabel(self.ConfirmScroll, preview.Action == "CRAFT" and "CONFIRM CRAFTING" or "CONFIRM IRREVERSIBLE RITUAL", T.Color.Gold, 20)
	if preview.Recipient then autoLabel(self.ConfirmScroll, "SURVIVING HERO\n" .. heroName(preview.Recipient), T.Color.Text, self.TextSize) end
	local donors = preview.Donors or {}
	if #donors > 0 then
		autoLabel(self.ConfirmScroll, string.format("These %d heroes will be permanently consumed:", #donors), T.Color.Danger, self.TextSize)
		for _, donor in donors do autoLabel(self.ConfirmScroll, heroName(donor), T.Rarity[donor.Stars or 1], self.TextSize) end
		autoLabel(self.ConfirmScroll, "This cannot be undone. Cancel now to keep every hero and resource.", T.Color.Danger, self.TextSize)
	end
	autoLabel(self.ConfirmScroll, "PAYMENT\n" .. costsText(preview.Costs, self.State.Resources), T.Color.Gold, self.TextSize)
	for key, value in preview.Rewards or {} do if type(value) == "number" then autoLabel(self.ConfirmScroll, "+" .. T.Number(value) .. " " .. key, T.Color.Good, self.TextSize) end end
	if preview.SuccessChance then autoLabel(self.ConfirmScroll, "Success chance: " .. T.Number(preview.SuccessChance * 100) .. "%", T.Color.Good, self.TextSize) end
	for _, warning in preview.Warnings or {} do autoLabel(self.ConfirmScroll, tostring(warning), T.Color.Gold, self.TextSize) end
	self.RareButton.Visible = preview.RequiresRareConfirmation == true
	local above = self.RareButton.Visible and self.RareButton or self.ConfirmScroll
	self.Cancel.NextSelectionUp, self.Confirm.NextSelectionUp = above, above
	self.ConfirmScroll.NextSelectionDown = self.RareButton.Visible and self.RareButton or self.Cancel
	self.RareButton.Text = (self.ConfirmRare and "✓ " or "○ ") .. "I understand the selected rare heroes will be lost"
	self.RareButton.TextColor3 = self.ConfirmRare and T.Color.Good or T.Color.Danger
	self.Confirm.Active = not self.Busy and (not preview.RequiresRareConfirmation or self.ConfirmRare)
	self.Confirm.Text = self.Busy and "Committing…" or preview.RequiresRareConfirmation and not self.ConfirmRare and "Acknowledge rare hero loss" or "Confirm transaction"
	for _, descendant in self.ConfirmPanel:GetDescendants() do if descendant:IsA("GuiObject") then descendant.ZIndex = 72 end end
end

function Pit.CancelConfirmation(self: any)
	if self.Busy then return end
	self.Confirming, self.ConfirmOverlay.Visible = false, false
	if self.FocusBeforeConfirm and self.FocusBeforeConfirm.Parent then GuiService.SelectedObject = self.FocusBeforeConfirm end
end

function Pit.CancelAnimations(self: any)
	for _, tween in self.Tweens do tween:Cancel() end
	table.clear(self.Tweens)
	if self.ResultFlash then self.ResultFlash:Destroy(); self.ResultFlash = nil end
end

function Pit.Celebrate(self: any, result: any)
	self:CancelAnimations()
	if self.ReducedMotion or not self.Root.Visible then return end
	local flash = T.New("Frame", {Name = "ServerConfirmedRitual", BackgroundColor3 = T.Color.Gold, BackgroundTransparency = 0.94, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = T.Layer.Ritual, Active = false}, self.Body)
	self.ResultFlash = flash
	local ring = T.New("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(48, 48), BackgroundTransparency = 1, ZIndex = T.Layer.Ritual + 1}, flash)
	T.Corner(ring, 100)
	local ringStroke = T.Stroke(ring, T.Color.Gold, 2)
	local ringTween = TweenService:Create(ring, TweenInfo.new(T.Duration.Ritual, Enum.EasingStyle.Quad), {Size = UDim2.fromOffset(190, 190), Rotation = 45})
	table.insert(self.Tweens, ringTween); ringTween:Play()
	local edgeTween = TweenService:Create(ringStroke, TweenInfo.new(T.Duration.Ritual), {Transparency = 1})
	table.insert(self.Tweens, edgeTween); edgeTween:Play()
	if result.Action == "PROMOTION" then
		local stars = T.Label(flash, T.Stars(result.After and result.After.Stars), 32, T.Color.Gold)
		stars.Size, stars.Position, stars.TextXAlignment, stars.ZIndex = UDim2.new(1, 0, 0, 50), UDim2.fromScale(0, 0.3), Enum.TextXAlignment.Center, T.Layer.Ritual + 2
		local starTween = TweenService:Create(stars, TweenInfo.new(T.Duration.Ritual), {TextTransparency = 1, Position = UDim2.fromScale(0, 0.18)})
		table.insert(self.Tweens, starTween); starTween:Play()
	elseif result.Action == "IMPRINT" then
		local memory = T.Label(flash, "◇", 46, T.Color.Memory)
		memory.Position, memory.Size, memory.ZIndex, memory.TextXAlignment = UDim2.fromScale(0.15, 0.55), UDim2.fromOffset(54, 54), T.Layer.Ritual + 2, Enum.TextXAlignment.Center
		local memoryTween = TweenService:Create(memory, TweenInfo.new(T.Duration.Ritual, Enum.EasingStyle.Quad), {Position = UDim2.fromScale(0.5, 0.25), TextTransparency = 1, Rotation = 90})
		table.insert(self.Tweens, memoryTween); memoryTween:Play()
	end
	local tween = TweenService:Create(flash, TweenInfo.new(T.Duration.Ritual, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
	table.insert(self.Tweens, tween); tween:Play()
	task.delay(T.Duration.Ritual + 0.1, function() if flash.Parent then flash:Destroy() end; if self.ResultFlash == flash then self.ResultFlash = nil end end)
end

function Pit.Commit(self: any)
	local preview = self.Preview
	if self.Busy or not self.Confirming or not preview or not preview.CanCommit then return end
	if preview.RequiresRareConfirmation and not self.ConfirmRare then return end
	self.Busy = true; self:UpdateAction(); self:RenderConfirmation()
	task.spawn(function()
		local response = self:Request("COMMIT", {Token = preview.Token, ConfirmRare = self.ConfirmRare})
		self.Busy, self.Confirming, self.ConfirmOverlay.Visible = false, false, false
		self.Message = response.Message or (response.Success and "Ritual complete." or "The server rejected this ritual. Review the updated requirements.")
		self.Preview = nil
		if response.State then self.State = response.State end
		self:ApplyDelta(response.Delta)
		if response.Success then
			local result = response.Result or {}
			local lines = {self.Message}
			local actual = result.Preview or result
			if actual.XP and actual.XP.Final then table.insert(lines, "+" .. T.Number(actual.XP.Final) .. " EXP granted") end
			if actual.Before and actual.After then
				table.insert(lines, string.format("Level %s → %s · %s → %s", T.Number(actual.Before.Level), T.Number(actual.After.Level), T.Stars(actual.Before.Stars), T.Stars(actual.After.Stars)))
				for _, key in {"HP", "ATK", "DPS", "Labor"} do table.insert(lines, string.format("%s  %s → %s", key, T.Number(actual.Before[key]), T.Number(actual.After[key]))) end
			end
			for key, value in actual.Rewards or {} do if type(value) == "number" then table.insert(lines, "+" .. T.Number(value) .. " " .. key) end end
			self.LastResult = table.concat(lines, "\n")
			if actual.Action ~= "CRAFT" then self.Donors, self.Imprint = {}, nil end
			self.Recipe = nil
			self:Celebrate(actual)
		else self.LastResult = nil end
		self:Render()
		if UserInputService.GamepadEnabled then GuiService.SelectedObject = self.Action end
		self:Refresh()
	end)
end

function Pit.Destroy(self: any)
	self:CancelAnimations()
	self.PreviewSerial += 1
	for _, connection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
end

return Pit
