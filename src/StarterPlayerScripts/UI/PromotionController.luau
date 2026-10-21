--!strict
-- Focused Hero Promotion HUD matching the dedicated ascension mockup.
-- Layout:
--   Header: "HERO PROMOTION"
--   Main Slot: Centered hero slot with "?" placeholder, purple glow, and "MAX LVL" pill badge
--   Star progression: ★★★  →  ★★★★ (with glowing new star)
--   Subheader: "- SACRIFICE MATERIALS (SAME RANK) -"
--   Material slots: Dynamic/3 slots for same-rank sacrifice heroes
--   Action button: "PROMOTE" with corner diamonds and purple glow
-- Authoritative RemoteFunction: PitRequest (STATE -> PREVIEW -> COMMIT).
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local StatFormulas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("StatFormulas"))

local Promo = {}
Promo.__index = Promo

local WIDTH, HEIGHT = 580, 580
local C = {
	Scrim = Color3.fromRGB(6, 6, 10),
	Panel = Color3.fromRGB(15, 14, 22),
	Slot = Color3.fromRGB(20, 18, 28),
	SlotBorder = Color3.fromRGB(75, 68, 92),
	Border = Color3.fromRGB(205, 160, 225),
	BorderGlow = Color3.fromRGB(175, 115, 210),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(185, 175, 205),
	MutedDim = Color3.fromRGB(115, 105, 130),
	Gold = Color3.fromRGB(255, 204, 0),
	Orange = Color3.fromRGB(235, 60, 25),
	OrangeLight = Color3.fromRGB(255, 85, 35),
	Arrow = Color3.fromRGB(185, 155, 215),
	Danger = Color3.fromRGB(239, 128, 120),
	Good = Color3.fromRGB(150, 230, 160),
}
local RARITY = {
	Color3.fromRGB(160, 128, 100), Color3.fromRGB(181, 193, 201),
	Color3.fromRGB(115, 165, 218), Color3.fromRGB(180, 142, 218), Color3.fromRGB(228, 193, 111),
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in props do (o :: any)[k] = v end
	o.Parent = parent
	return o
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = color,
		Thickness = thickness or 1, Transparency = transparency or 0,
	}, parent)
end

local function glow(parent: GuiObject, pad: number, color: Color3?, transparency: number?)
	local g = new("Frame", {
		Name = "Glow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, pad, 1, pad), ZIndex = parent.ZIndex,
	}, parent)
	stroke(g, color or C.BorderGlow, 3, transparency or 0.78)
end

local function cornerDiamonds(parent: GuiObject, size: number)
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		local d = new("Frame", {
			Name = "CornerDiamond", AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45,
			Position = UDim2.fromScale(corner.X, corner.Y), Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = C.Panel, BorderSizePixel = 0, ZIndex = parent.ZIndex + 2,
		}, parent)
		stroke(d, C.Border, 1)
	end
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
		Font = font or Enum.Font.GothamBold, TextWrapped = true, RichText = true,
	}, parent)
end

local function spaced(text: string): string
	return (text:gsub("(.)", "%1 "):sub(1, -2))
end

local function stars(n: number?): string
	return string.rep("★", math.clamp(n or 1, 1, 5))
end

--============================================================================
-- CONSTRUCTION
--============================================================================

function Promo.new(gui: ScreenGui, remote: RemoteFunction)
	local self: any = setmetatable({}, Promo)
	self.Remote = remote
	self.State = { Heroes = {}, Resources = {}, Currencies = {}, Materials = {} }
	self.Recipient = nil
	self.Donors = {}
	self.Preview = nil
	self.Busy = false
	self.Loading = false
	self.PreviewSerial = 0
	self.Message = ""

	self.Scrim = new("TextButton", {
		Name = "PromotionScrim", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 39,
	}, gui)
	self.Scrim.Activated:Connect(function() if not self.Busy then self:Close() end end)

	local root = new("Frame", {
		Name = "HeroPromotionModal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundColor3 = C.Panel, BorderSizePixel = 0,
		Visible = false, Active = true, ZIndex = 40,
	}, gui)
	self.Root = root
	stroke(root, C.Border, 1, 0.05)
	glow(root, 8, C.BorderGlow, 0.78)
	local inner = new("Frame", {
		Name = "InnerBorder", BackgroundTransparency = 1, Position = UDim2.fromOffset(5, 5),
		Size = UDim2.new(1, -10, 1, -10), ZIndex = 41,
	}, root)
	stroke(inner, Color3.fromRGB(65, 55, 80), 1, 0.3)
	cornerDiamonds(root, 8)
	self.Scale = new("UIScale", {}, root)

	-- Header Title
	local title = label(root, spaced("HERO PROMOTION"), 24, C.Text, Enum.Font.GothamBlack)
	title.Name, title.Position, title.Size, title.ZIndex = "Title", UDim2.fromOffset(0, 42), UDim2.new(1, 0, 0, 36), 42
	self.Title = title

	-- Close Button
	local close = new("TextButton", {
		Name = "Close", Text = "×", TextSize = 26, Font = Enum.Font.GothamBold, TextColor3 = C.Muted,
		BackgroundTransparency = 1, Position = UDim2.new(1, -48, 0, 12), Size = UDim2.fromOffset(36, 36), ZIndex = 42,
	}, root)
	close.Activated:Connect(function() if not self.Busy then self:Close() end end)

	-- Main Recipient Slot (Square with Purple Glow)
	local slotSize = 136
	local slotBtn = new("TextButton", {
		Name = "RecipientSlot", Text = "", AutoButtonColor = true, BackgroundColor3 = C.Slot, BorderSizePixel = 0,
		Position = UDim2.fromOffset((WIDTH - slotSize) / 2, 98), Size = UDim2.fromOffset(slotSize, slotSize), ZIndex = 42,
	}, root)
	self.RecipientButton = slotBtn
	self.RecipientStroke = stroke(slotBtn, Color3.fromRGB(235, 225, 250), 1)
	glow(slotBtn, 10, C.BorderGlow, 0.65)
	local slotInset = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = 42 }, slotBtn)
	stroke(slotInset, Color3.fromRGB(75, 68, 92), 1, 0.5)

	self.RecipientPortrait = new("Frame", {
		Name = "PortraitHost", BackgroundTransparency = 1, ClipsDescendants = true,
		Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 43,
	}, slotBtn)

	self.QuestionLabel = label(slotBtn, "?", 52, C.Text, Enum.Font.GothamBlack)
	self.QuestionLabel.Size, self.QuestionLabel.ZIndex = UDim2.fromScale(1, 1), 44

	-- "MAX LVL" Pill Badge (pinned to bottom edge of recipient slot)
	local badge = new("Frame", {
		Name = "MaxLvlBadge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(92, 26), BackgroundColor3 = C.Orange, BorderSizePixel = 0, ZIndex = 46,
	}, slotBtn)
	new("UICorner", { CornerRadius = UDim.new(0, 13) }, badge)
	new("UIGradient", { Color = ColorSequence.new(C.OrangeLight, C.Orange) }, badge)
	stroke(badge, Color3.fromRGB(255, 255, 255), 1)
	self.MaxLvlBadge = badge

	local badgeText = label(badge, "MAX LVL", 11, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
	badgeText.Size, badgeText.ZIndex = UDim2.fromScale(1, 1), 47
	self.MaxLvlText = badgeText

	slotBtn.Activated:Connect(function() self:OpenPicker("RECIPIENT") end)

	-- Star Progression Row (e.g. ★★★  →  ★★★★)
	self.StarLabel = label(root, "", 22, C.Text, Enum.Font.GothamBold)
	self.StarLabel.Position, self.StarLabel.Size, self.StarLabel.ZIndex = UDim2.fromOffset(0, 250), UDim2.new(1, 0, 0, 28), 42

	-- Subtitle "- SACRIFICE MATERIALS (SAME RANK) -"
	local subheader = label(root, "- SACRIFICE MATERIALS (SAME RANK) -", 12, C.Muted, Enum.Font.GothamBold)
	subheader.Position, subheader.Size, subheader.ZIndex = UDim2.fromOffset(0, 292), UDim2.new(1, 0, 0, 20), 42

	-- Container for sacrifice material slots
	self.MaterialContainer = new("Frame", {
		Name = "MaterialContainer", BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 326), Size = UDim2.new(1, 0, 0, 86), ZIndex = 42,
	}, root)

	-- Confirm Button ("PROMOTE")
	local btnWidth, btnHeight = 440, 56
	local confirm = new("TextButton", {
		Name = "PromoteButton", Text = "PROMOTE", TextSize = 17, Font = Enum.Font.GothamBlack,
		TextColor3 = C.Text, BackgroundColor3 = Color3.fromRGB(16, 14, 22), BorderSizePixel = 0, AutoButtonColor = true,
		Position = UDim2.fromOffset((WIDTH - btnWidth) / 2, 442), Size = UDim2.fromOffset(btnWidth, btnHeight), ZIndex = 42,
	}, root)
	self.ConfirmButton = confirm
	self.ConfirmStroke = stroke(confirm, C.Border, 1, 0.1)
	glow(confirm, 6, C.BorderGlow, 0.8)
	local confirmInner = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 42 }, confirm)
	stroke(confirmInner, Color3.fromRGB(65, 55, 80), 1, 0.3)
	cornerDiamonds(confirm, 7)
	confirm.Activated:Connect(function() self:Confirm() end)

	-- Status Feedback
	self.Status = label(root, "", 13, C.Muted, Enum.Font.GothamMedium)
	self.Status.Position, self.Status.Size, self.Status.ZIndex = UDim2.fromOffset(30, 514), UDim2.new(1, -60, 0, 44), 42

	self:BuildPicker()

	local function resize()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local v = cam.ViewportSize
		self.Scale.Scale = math.clamp(math.min((v.X - 20) / WIDTH, (v.Y - 40) / HEIGHT), 0.45, 1)
	end
	local camConn: RBXScriptConnection? = nil
	local function track()
		if camConn then camConn:Disconnect() end
		if Workspace.CurrentCamera then camConn = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
		resize()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(track)
	track()

	self:Render()
	return self
end

function Promo.BuildPicker(self: any)
	local picker = new("Frame", {
		Name = "HeroPicker", BackgroundColor3 = C.Panel, BorderSizePixel = 0, Visible = false, Active = true,
		Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28), ZIndex = 60,
	}, self.Root)
	stroke(picker, Color3.fromRGB(80, 70, 95), 1)
	self.Picker = picker
	self.PickerTitle = label(picker, "", 18, C.Text, Enum.Font.GothamBlack)
	self.PickerTitle.Position, self.PickerTitle.Size, self.PickerTitle.ZIndex = UDim2.fromOffset(0, 18), UDim2.new(1, 0, 0, 28), 61
	local back = new("TextButton", {
		Text = "×", TextSize = 28, Font = Enum.Font.GothamBold, TextColor3 = C.Muted, BackgroundTransparency = 1,
		Position = UDim2.new(1, -50, 0, 10), Size = UDim2.fromOffset(40, 40), ZIndex = 61,
	}, picker)
	back.Activated:Connect(function() picker.Visible = false end)
	self.PickerStatus = label(picker, "", 13, C.Muted, Enum.Font.GothamMedium)
	self.PickerStatus.Position, self.PickerStatus.Size, self.PickerStatus.ZIndex = UDim2.new(0, 20, 1, -44), UDim2.new(1, -40, 0, 34), 61
	self.PickerList = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(20, 58), Size = UDim2.new(1, -40, 1, -112),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(80, 70, 95), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 61,
	}, picker)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(104, 136), CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.PickerList)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, self.PickerList)
end

--============================================================================
-- SERVER REQUESTS
--============================================================================

function Promo.Request(self: any, command: string, payload: any?): any
	local ok, response = pcall(function() return self.Remote:InvokeServer(command, payload) end)
	if not ok or type(response) ~= "table" then
		return { Success = false, Message = "The Promotion chamber could not respond. Please try again." }
	end
	return response
end

function Promo.Refresh(self: any, attempt: number?)
	task.spawn(function()
		local response = self:Request("STATE")
		if not self.Root.Visible then return end
		if not response.Success then
			if (attempt or 0) < 3 then task.delay(0.5, function() self:Refresh((attempt or 0) + 1) end) end
			return
		end
		self.State = response.State or { Heroes = {} }
		if self.Recipient and not self.State.Heroes[self.Recipient] then self.Recipient = nil end
		for i = #self.Donors, 1, -1 do
			if not self.State.Heroes[self.Donors[i]] then table.remove(self.Donors, i) end
		end
		self:Render()
		if self.Picker.Visible then self:RenderPicker() end
		self:QueuePreview()
	end)
end

function Promo.QueuePreview(self: any)
	self.PreviewSerial += 1
	local serial = self.PreviewSerial
	self.Preview = nil
	if not self.Recipient then self:Render(); return end

	self.Loading = true
	self:Render()
	task.delay(0.2, function()
		if serial ~= self.PreviewSerial or not self.Root.Visible then return end
		local response = self:Request("PREVIEW", {
			Action = "PROMOTION",
			Recipient = self.Recipient,
			Donors = table.clone(self.Donors),
		})
		if serial ~= self.PreviewSerial then return end
		if not response.Success and tostring(response.Message):find("wait") then
			task.delay(0.3, function() if serial == self.PreviewSerial then self:QueuePreview() end end)
			return
		end
		self.Loading = false
		self.Preview = response.Preview
		if not response.Success then self.Message = response.Message or "Preview unavailable." end
		self:Render()
	end)
end

function Promo.Confirm(self: any)
	if self.Busy or self.Loading then return end
	local preview = self.Preview
	if not self.Recipient then
		self.Message = "Tap the slot above to select a hero to promote."
		self:Render()
		return
	end
	local recipient = self.State.Heroes[self.Recipient]
	local reqDonors = recipient and (recipient.Stars or 1) or 3
	if #self.Donors < reqDonors then
		self.Message = string.format("Select %d sacrifice material%s of rank %s.", reqDonors, reqDonors == 1 and "" or "s", stars(recipient and recipient.Stars or 1))
		self:Render()
		return
	end
	if not preview or not preview.CanCommit then
		self.Message = preview and preview.Reason or "Promotion requirements not met."
		self:Render()
		return
	end

	self.Busy = true
	self:Render()
	task.spawn(function()
		local response = self:Request("COMMIT", { Token = preview.Token, ConfirmRare = true })
		self.Busy, self.Preview = false, nil
		if response.Success then
			local result = response.Result or {}
			local after = result.After
			local hero = self.State.Heroes[self.Recipient]
			local newStars = after and after.Stars or ((hero and hero.Stars or 1) + 1)
			self.Message = string.format("Promotion complete! %s has ascended to %s rank!", hero and hero.DisplayName or "Hero", stars(newStars))
			local delta = response.Delta
			if delta then
				for uuid, h in delta.Heroes or {} do self.State.Heroes[uuid] = h end
				for _, uuid in delta.Removed or {} do self.State.Heroes[uuid] = nil end
			end
			self.Donors = {}
			self:Celebrate()
		else
			self.Message = response.Message or "The promotion was rejected. Review your selection."
		end
		self:Render()
		task.delay(0.5, function() if self.Root.Visible and not self.Busy then self:Refresh() end end)
	end)
end

--============================================================================
-- SELECTION
--============================================================================

function Promo.RemoveDonor(self: any, uuid: string)
	local index = table.find(self.Donors, uuid)
	if index then table.remove(self.Donors, index) end
	self.Message = ""
	self:QueuePreview()
end

function Promo.OpenPicker(self: any, mode: string)
	if self.Busy then return end
	self.PickerMode = mode
	if mode == "RECIPIENT" then
		self.PickerMessage = "Choose a hero at maximum level to promote."
	else
		local recipient = self.Recipient and self.State.Heroes[self.Recipient]
		local rank = recipient and recipient.Stars or 1
		self.PickerMessage = string.format("Sacrifice materials must be rank %s and will be consumed.", stars(rank))
	end
	self.Picker.Visible = true
	self:RenderPicker()
end

function Promo.Pick(self: any, uuid: string)
	local hero = self.State.Heroes[uuid]
	if not hero then return end
	if self.PickerMode == "RECIPIENT" then
		self.Recipient = uuid
		self.Donors = {}
	else
		if table.find(self.Donors, uuid) then return end
		table.insert(self.Donors, uuid)
	end
	self.Message = ""
	self.Picker.Visible = false
	self:QueuePreview()
end

function Promo.RenderPicker(self: any)
	for _, child in self.PickerList:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local isDonorMode = self.PickerMode == "DONOR"
	local recipient = self.Recipient and self.State.Heroes[self.Recipient]

	if isDonorMode then
		self.PickerTitle.Text = spaced("SELECT SACRIFICE MATERIAL")
	else
		self.PickerTitle.Text = spaced("SELECT HERO TO PROMOTE")
	end
	self.PickerStatus.Text, self.PickerStatus.TextColor3 = self.PickerMessage or "", C.Muted

	local heroes = {}
	for uuid, hero in self.State.Heroes do
		if isDonorMode then
			if uuid ~= self.Recipient and not table.find(self.Donors, uuid) then
				table.insert(heroes, hero)
			end
		else
			table.insert(heroes, hero)
		end
	end

	if isDonorMode then
		local targetRank = recipient and (recipient.Stars or 1) or 1
		table.sort(heroes, function(a, b)
			local aMatch = (a.Stars or 1) == targetRank
			local bMatch = (b.Stars or 1) == targetRank
			if aMatch ~= bMatch then return aMatch end
			local aOk = not a.PitStatus or a.PitStatus.EligibleDonor ~= false
			local bOk = not b.PitStatus or b.PitStatus.EligibleDonor ~= false
			if aOk ~= bOk then return aOk end
			return tostring(a.UUID) < tostring(b.UUID)
		end)
	else
		table.sort(heroes, function(a, b)
			local aMax = (a.Stars or 1) >= 5
			local bMax = (b.Stars or 1) >= 5
			if aMax ~= bMax then return not aMax end
			local aCap = (a.Level or 1) >= (a.Stars or 1) * 10
			local bCap = (b.Level or 1) >= (b.Stars or 1) * 10
			if aCap ~= bCap then return aCap end
			if (a.Stars or 1) ~= (b.Stars or 1) then return (a.Stars or 1) > (b.Stars or 1) end
			if (a.Level or 1) ~= (b.Level or 1) then return (a.Level or 1) > (b.Level or 1) end
			return tostring(a.UUID) < tostring(b.UUID)
		end)
	end

	if #heroes == 0 then
		local empty = label(self.PickerList, isDonorMode and "No matching sacrifice materials available." or "Your roster is empty.", 14, C.Muted, Enum.Font.GothamMedium)
		empty.Size, empty.ZIndex = UDim2.fromOffset(400, 40), 62
	end

	for i, hero in heroes do
		local eligible = true
		local tagText: string? = nil
		if isDonorMode then
			local targetRank = recipient and (recipient.Stars or 1) or 1
			if (hero.Stars or 1) ~= targetRank then
				eligible = false
				tagText = "WRONG RANK"
			elseif hero.PitStatus and hero.PitStatus.EligibleDonor == false then
				eligible = false
				tagText = (hero.PitStatus.Status or "UNAVAILABLE"):upper()
			end
		else
			local isMax = (hero.Stars or 1) >= 5
			local isCapped = (hero.Level or 1) >= (hero.Stars or 1) * 10
			if isMax then
				eligible = false
				tagText = "MAX RANK"
			elseif not isCapped then
				eligible = false
				tagText = "NEED LV." .. ((hero.Stars or 1) * 10)
			end
		end

		local rarity = RARITY[math.clamp(hero.Stars or 1, 1, 5)]
		local tile = new("TextButton", {
			Name = "Hero_" .. tostring(hero.UUID), Text = "", LayoutOrder = i, AutoButtonColor = true,
			BackgroundColor3 = C.Slot, BorderSizePixel = 0, ZIndex = 62,
		}, self.PickerList)
		stroke(tile, eligible and rarity or Color3.fromRGB(75, 68, 92), 1, eligible and 0.1 or 0.6)
		local host = new("Frame", {
			BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(8, 6),
			Size = UDim2.fromOffset(88, 82), ZIndex = 63,
		}, tile)
		local portrait = HeroCard.Portrait(host, hero)
		portrait.ZIndex = 63
		local name = label(tile, hero.DisplayName or "Hero", 13, eligible and rarity or C.Muted)
		name.Position, name.Size, name.ZIndex = UDim2.fromOffset(4, 90), UDim2.new(1, -8, 0, 18), 63
		local info = label(tile, string.format("%s  Lv.%d", stars(hero.Stars), hero.Level or 1), 11, eligible and C.Text or C.Muted, Enum.Font.GothamMedium)
		info.Position, info.Size, info.ZIndex = UDim2.fromOffset(4, 108), UDim2.new(1, -8, 0, 16), 63
		if tagText then
			local shade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 64 }, tile)
			local tag = label(shade, tagText, 10, C.Danger)
			tag.Size, tag.Position, tag.ZIndex = UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 36), 65
		end
		local uuid = hero.UUID
		tile.Activated:Connect(function()
			if isDonorMode and not eligible then return end
			self:Pick(uuid)
		end)
	end
end

--============================================================================
-- RENDERING
--============================================================================

function Promo.RenderMaterialSlots(self: any, count: number)
	self.MaterialContainer:ClearAllChildren()
	local slotSize = 82
	local gap = 16
	local totalWidth = count * slotSize + (count - 1) * gap
	local startX = (WIDTH - totalWidth) / 2

	local heroes = self.State.Heroes or {}
	for i = 1, count do
		local uuid = self.Donors[i]
		local hero = uuid and heroes[uuid]

		local btn = new("TextButton", {
			Name = "MaterialSlot_" .. i, Text = "", AutoButtonColor = true, BackgroundColor3 = C.Slot, BorderSizePixel = 0,
			Position = UDim2.fromOffset(startX + (i - 1) * (slotSize + gap), 2), Size = UDim2.fromOffset(slotSize, slotSize), ZIndex = 43,
		}, self.MaterialContainer)
		stroke(btn, hero and RARITY[math.clamp(hero.Stars or 1, 1, 5)] or C.SlotBorder, 1)

		if hero then
			local host = new("Frame", {
				BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(4, 4),
				Size = UDim2.new(1, -8, 1, -8), ZIndex = 44,
			}, btn)
			local p = HeroCard.Portrait(host, hero)
			p.ZIndex = 44
			local cap = label(btn, string.format("Lv.%d", hero.Level or 1), 10, C.Text)
			cap.AnchorPoint, cap.Position = Vector2.new(0, 1), UDim2.new(0, 0, 1, -2)
			cap.Size, cap.ZIndex = UDim2.new(1, 0, 0, 14), 45
			cap.TextStrokeTransparency = 0.3
			btn.Activated:Connect(function() self:RemoveDonor(uuid) end)
		else
			local plus = label(btn, "+", 28, C.MutedDim, Enum.Font.GothamMedium)
			plus.Size, plus.ZIndex = UDim2.fromScale(1, 1), 44
			btn.Activated:Connect(function()
				if not self.Recipient then
					self.Message = "Tap the slot above to select a hero first."
					self:Render()
				else
					self:OpenPicker("DONOR")
				end
			end)
		end
	end
end

function Promo.Render(self: any)
	local heroes = self.State.Heroes or {}
	local recipient = self.Recipient and heroes[self.Recipient]
	local reqCount = recipient and (recipient.Stars or 1) or 3

	-- Recipient Slot Rendering
	self.RecipientPortrait:ClearAllChildren()
	if recipient then
		self.QuestionLabel.Visible = false
		local p = HeroCard.Portrait(self.RecipientPortrait, recipient)
		p.ZIndex = 43
		local rarity = RARITY[math.clamp(recipient.Stars or 1, 1, 5)]
		self.RecipientStroke.Color = rarity
	else
		self.QuestionLabel.Visible = true
		self.RecipientStroke.Color = Color3.fromRGB(235, 225, 250)
	end

	-- Badge state
	if recipient then
		local maxLevel = (recipient.Stars or 1) * 10
		local isCapped = (recipient.Level or 1) >= maxLevel
		self.MaxLvlText.Text = isCapped and "MAX LVL" or string.format("LV. %d/%d", recipient.Level or 1, maxLevel)
	else
		self.MaxLvlText.Text = "MAX LVL"
	end

	-- Star Progression Display
	if recipient then
		local s = math.clamp(recipient.Stars or 1, 1, 4)
		local currentGold = string.rep("★", s)
		self.StarLabel.Text = string.format(
			'<font color="#FFCC00">%s</font>  <font color="#B99BD7">→</font>  <font color="#FFCC00">%s</font><font color="#FFFFFF">★</font>',
			currentGold, currentGold
		)
	else
		-- Default matching the mockup: 3 yellow -> 3 yellow + 1 white glowing
		self.StarLabel.Text = '<font color="#FFCC00">★★★</font>  <font color="#B99BD7">→</font>  <font color="#FFCC00">★★★</font><font color="#FFFFFF">★</font>'
	end

	-- Material Slots Rendering
	self:RenderMaterialSlots(reqCount)

	-- Ready / Commit State
	local preview = self.Preview
	local hasAllDonors = #self.Donors >= reqCount
	local ready = preview ~= nil and preview.CanCommit and hasAllDonors and not self.Loading and not self.Busy
	local button = self.ConfirmButton
	if self.Busy then
		button.Text = "PROMOTING…"
	else
		button.Text = "PROMOTE"
	end
	button.TextColor3 = (ready or self.Busy) and C.Text or Color3.fromRGB(120, 115, 135)
	self.ConfirmStroke.Color = ready and C.Border or Color3.fromRGB(80, 70, 95)

	-- Status Message
	local status, color = self.Message, C.Muted
	if status == "" then
		if not recipient then
			status = "Tap the slot above to select a hero for promotion."
		elseif self.Loading then
			status = "Evaluating ascension requirements…"
		elseif not hasAllDonors then
			status, color = string.format("Select %d sacrifice material%s of rank %s to promote.", reqCount - #self.Donors, (reqCount - #self.Donors) == 1 and "" or "s", stars(recipient.Stars)), C.Muted
		elseif preview and not preview.CanCommit then
			status, color = preview.Reason or "Promotion requirements not met.", C.Danger
		elseif preview and preview.CanCommit then
			status, color = string.format("Ascension ready! Confirmed promotion will promote %s to %s rank.", recipient.DisplayName or "Hero", stars((recipient.Stars or 1) + 1)), C.Good
		end
	elseif status:find("complete") then
		color = C.Good
	end
	self.Status.Text, self.Status.TextColor3 = status, color
end

function Promo.Celebrate(self: any)
	local flash = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.2, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 48,
	}, self.RecipientButton)
	local tween = TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function() flash:Destroy() end)
end

--============================================================================
-- VISIBILITY
--============================================================================

function Promo.Open(self: any)
	self.Root.Visible, self.Scrim.Visible = true, true
	self.Picker.Visible = false
	self.Recipient = nil
	self.Donors = {}
	self.Preview = nil
	self.Message = ""
	self.Busy = false
	self.Loading = false
	self:Render()
	self:Refresh()
end

function Promo.Close(self: any)
	if self.Busy then return end
	self.Root.Visible, self.Scrim.Visible, self.Picker.Visible = false, false, false
	self.PreviewSerial += 1
	self.Loading = false
end

function Promo.IsOpen(self: any): boolean
	return self.Root.Visible
end

return Promo
