--!strict
-- Focused Synthesis HUD opened from the Synthesis chamber's [F] prompt.
-- Layout: one recipient slot, a level preview bar, five material slots and a
-- confirm button. Every quote and outcome comes from the authoritative
-- PitRequest remote (STATE -> PREVIEW -> COMMIT); the client never decides EXP.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local StatFormulas = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("StatFormulas"))
local GothicBoxStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GothicBoxStyle"))

local Synth = {}
Synth.__index = Synth

local DONOR_SLOTS = 5
local WIDTH, HEIGHT = 700, 610
local C = {
	Scrim = Color3.fromRGB(6, 6, 10),
	Panel = Color3.fromRGB(19, 18, 26),
	Slot = Color3.fromRGB(23, 22, 30),
	Line = Color3.fromRGB(228, 208, 236),
	LineDim = Color3.fromRGB(86, 80, 100),
	Text = Color3.fromRGB(246, 244, 255),
	Muted = Color3.fromRGB(150, 146, 162),
	Plus = Color3.fromRGB(128, 124, 140),
	Blue = Color3.fromRGB(16, 132, 214),
	Green = Color3.fromRGB(57, 232, 30),
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

local function glow(parent: GuiObject, pad: number, transparency: number)
	local g = new("Frame", {
		Name = "Glow", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, pad, 1, pad), ZIndex = parent.ZIndex,
	}, parent)
	stroke(g, C.Line, 3, transparency)
end

local function applyGothicStyle(container: GuiObject, style: "Window" | "Card" | "Button" | "Compact")
	return GothicBoxStyle.Apply(container, { Style = style })
end

-- Small hollow diamonds pinned to each corner, matching the reference frame.
local function cornerDiamonds(parent: GuiObject, size: number)
	-- Styled automatically by GothicBoxStyle
end

local function label(parent: Instance, text: string, size: number, color: Color3, font: Enum.Font?): TextLabel
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color,
		Font = font or GothicBoxStyle.Font.LegacyFont or Enum.Font.GothamBold, TextWrapped = true, RichText = true,
	}, parent)
	GothicBoxStyle.Font.Apply(lbl, {
		Role = if size >= 20 then "Title" else if size >= 15 then "Header" else "Body",
		Color = color,
		Size = size,
	})
	return lbl
end

local function spaced(text: string): string
	return (text:gsub("(.)", "%1 "):sub(1, -2))
end

local function stars(n: number?): string
	return string.rep("★", math.clamp(n or 1, 1, 5))
end

local function xpRatio(level: number?, xp: number?): number
	return math.clamp((xp or 0) / StatFormulas.GetXPRequiredForNextLevel(level or 1), 0, 1)
end

--============================================================================
-- CONSTRUCTION
--============================================================================

function Synth.new(gui: ScreenGui, remote: RemoteFunction)
	local self: any = setmetatable({}, Synth)
	self.Remote = remote
	self.State = { Heroes = {} }
	self.Recipient, self.Donors, self.Preview = nil, {}, nil
	self.Busy, self.ArmedRare, self.PreviewSerial = false, false, 0
	self.Message = ""
	self.Tweens = {}

	self.Scrim = new("TextButton", {
		Name = "SynthesisScrim", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.3, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 39,
	}, gui)
	self.Scrim.Activated:Connect(function() if not self.Busy then self:Close() end end)

	local root = new("Frame", {
		Name = "SynthesisModal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundColor3 = C.Panel, BorderSizePixel = 0,
		Visible = false, Active = true, ZIndex = 40,
	}, gui)
	self.Root = root
	applyGothicStyle(root, "Window")
	self.Scale = new("UIScale", {}, root)

	local title = label(root, spaced("SYNTHESIS"), 26, C.Text, Enum.Font.GothamBlack)
	title.Name, title.Position, title.Size, title.ZIndex = "Title", UDim2.fromOffset(0, 44), UDim2.new(1, 0, 0, 40), 42

	local close = GothicBoxStyle.CreateCloseButton(root, function() if not self.Busy then self:Close() end end)

	-- Recipient (the hero being synthesized)
	self.RecipientSlot = self:BuildSlot(root, "RecipientSlot", 130, UDim2.fromOffset((WIDTH - 130) / 2, 108), true)
	self.RecipientSlot.Button.Activated:Connect(function() self:OpenPicker("RECIPIENT") end)

	self.RecipientName = label(root, "", 14, C.Muted, Enum.Font.GothamMedium)
	self.RecipientName.Position, self.RecipientName.Size, self.RecipientName.ZIndex = UDim2.fromOffset(0, 246), UDim2.new(1, 0, 0, 18), 42

	self.LevelLabel = label(root, "", 18, C.Text)
	self.LevelLabel.Position, self.LevelLabel.Size, self.LevelLabel.ZIndex = UDim2.fromOffset(0, 268), UDim2.new(1, 0, 0, 24), 42

	local bar = new("Frame", {
		Name = "XPBar", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ClipsDescendants = true,
		Position = UDim2.fromOffset((WIDTH - 444) / 2, 298), Size = UDim2.fromOffset(444, 13), ZIndex = 42,
	}, root)
	stroke(bar, C.Line, 1, 0.15)
	self.GainFill = new("Frame", { Name = "Gain", BackgroundColor3 = C.Green, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 43 }, bar)
	self.CurrentFill = new("Frame", { Name = "Current", BackgroundColor3 = C.Blue, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 44 }, bar)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(10, 110, 190), Color3.fromRGB(30, 150, 235)) }, self.CurrentFill)

	-- Material heroes
	self.DonorSlots = {}
	local slotSize, gap = 80, 24
	local startX = (WIDTH - (slotSize * DONOR_SLOTS + gap * (DONOR_SLOTS - 1))) / 2
	for i = 1, DONOR_SLOTS do
		local slot = self:BuildSlot(root, "DonorSlot" .. i, slotSize, UDim2.fromOffset(startX + (i - 1) * (slotSize + gap), 352), false)
		slot.Button.Activated:Connect(function()
			if self.Busy then return end
			local uuid = self.Donors[i]
			if uuid then self:RemoveDonor(uuid) else self:OpenPicker("DONOR") end
		end)
		self.DonorSlots[i] = slot
	end

	-- Confirm button
	local confirm = new("TextButton", {
		Name = "ConfirmSynthesize", Text = "CONFIRM SYNTHESIZE", TextSize = 17, Font = Enum.Font.GothamBlack,
		TextColor3 = C.Text, BackgroundColor3 = Color3.fromRGB(15, 14, 20), BorderSizePixel = 0, AutoButtonColor = false,
		Position = UDim2.fromOffset((WIDTH - 506) / 2, 480), Size = UDim2.fromOffset(506, 60), ZIndex = 42,
	}, root)
	applyGothicStyle(confirm, "Button")
	confirm.Activated:Connect(function() self:Confirm() end)
	self.ConfirmButton = confirm
	self.ConfirmStroke = confirm:FindFirstChildOfClass("UIStroke")

	self.Status = label(root, "", 13, C.Muted, Enum.Font.GothamMedium)
	self.Status.Position, self.Status.Size, self.Status.ZIndex = UDim2.fromOffset(40, 550), UDim2.new(1, -80, 0, 40), 42

	self:BuildPicker()

	local function resize()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local v = cam.ViewportSize
		self.Scale.Scale = math.clamp(math.min((v.X - 24) / WIDTH, (v.Y - 60) / HEIGHT), 0.45, 1)
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

function Synth.BuildSlot(self: any, parent: Instance, name: string, size: number, position: UDim2, primary: boolean): any
	local button = new("TextButton", {
		Name = name, Text = "", AutoButtonColor = false, BackgroundColor3 = C.Slot, BorderSizePixel = 0,
		Position = position, Size = UDim2.fromOffset(size, size), ZIndex = 42,
	}, parent)
	local slot: any = { Button = button, HeroId = nil }
	applyGothicStyle(button, "Card")
	slot.Stroke = button:FindFirstChildOfClass("UIStroke")
	slot.Portrait = new("Frame", {
		Name = "Portrait", BackgroundTransparency = 1, ClipsDescendants = true,
		Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 43,
	}, button)
	slot.Plus = label(button, "+", primary and 64 or 30, primary and C.Text or C.Plus, Enum.Font.GothamMedium)
	slot.Plus.Size, slot.Plus.ZIndex = UDim2.fromScale(1, 1), 44
	slot.Caption = label(button, "", primary and 12 or 10, C.Text)
	slot.Caption.AnchorPoint, slot.Caption.Position = Vector2.new(0, 1), UDim2.new(0, 0, 1, -2)
	slot.Caption.Size, slot.Caption.ZIndex = UDim2.new(1, 0, 0, primary and 16 or 13), 45
	slot.Caption.TextStrokeTransparency = 0.3
	return slot
end

function Synth.BuildPicker(self: any)
	local picker = new("Frame", {
		Name = "HeroPicker", BackgroundColor3 = C.Panel, BorderSizePixel = 0, Visible = false, Active = true,
		Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28), ZIndex = 60,
	}, self.Root)
	applyGothicStyle(picker, "Window")
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
		ScrollBarImageColor3 = C.LineDim, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 61,
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

function Synth.Request(self: any, command: string, payload: any?): any
	local ok, response = pcall(function() return self.Remote:InvokeServer(command, payload) end)
	if not ok or type(response) ~= "table" then return { Success = false, Message = "The Synthesis chamber could not respond. Please try again." } end
	return response
end

function Synth.Refresh(self: any, attempt: number?)
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

function Synth.QueuePreview(self: any)
	self.PreviewSerial += 1
	local serial = self.PreviewSerial
	self.Preview, self.ArmedRare = nil, false
	if not self.Recipient or #self.Donors == 0 then self:Render(); return end
	self.Loading = true
	self:Render()
	task.delay(0.2, function()
		if serial ~= self.PreviewSerial or not self.Root.Visible then return end
		local response = self:Request("PREVIEW", { Action = "SYNTHESIS", Recipient = self.Recipient, Donors = table.clone(self.Donors) })
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

function Synth.Confirm(self: any)
	if self.Busy or self.Loading then return end
	local preview = self.Preview
	if not self.Recipient then self.Message = "Tap the large slot to choose the hero to synthesize."; self:Render(); return end
	if #self.Donors == 0 then self.Message = "Add at least one material hero."; self:Render(); return end
	if not preview or not preview.CanCommit then
		self.Message = preview and preview.Reason or "Complete the synthesis requirements."
		self:Render()
		return
	end
	if preview.RequiresRareConfirmation and not self.ArmedRare then
		self.ArmedRare = true
		self.Message = "Rare heroes are selected and will be permanently consumed. Press again to confirm."
		self:Render()
		return
	end
	self.Busy = true
	self:Render()
	task.spawn(function()
		local response = self:Request("COMMIT", { Token = preview.Token, ConfirmRare = true })
		self.Busy, self.ArmedRare, self.Preview = false, false, nil
		if response.Success then
			local result = response.Result or {}
			local gained = result.XP and result.XP.Final or 0
			local before, after = result.Before, result.After
			self.Message = string.format("Synthesis complete! +%d EXP%s", gained,
				(before and after and after.Level > before.Level) and string.format("  ·  Lv. %d → Lv. %d", before.Level, after.Level) or "")
			local delta = response.Delta
			if delta then
				for uuid, hero in delta.Heroes or {} do self.State.Heroes[uuid] = hero end
				for _, uuid in delta.Removed or {} do self.State.Heroes[uuid] = nil end
			end
			self.Donors = {}
			self:Celebrate()
		else
			self.Message = response.Message or "The synthesis was rejected. Review your selection."
		end
		self:Render()
		task.delay(0.5, function() if self.Root.Visible and not self.Busy then self:Refresh() end end)
	end)
end

--============================================================================
-- SELECTION
--============================================================================

function Synth.RemoveDonor(self: any, uuid: string)
	local index = table.find(self.Donors, uuid)
	if index then table.remove(self.Donors, index) end
	self.Message = ""
	self:QueuePreview()
end

function Synth.OpenPicker(self: any, mode: string)
	if self.Busy then return end
	if mode == "DONOR" and not self.Recipient then
		mode = "RECIPIENT"
		self.PickerMessage = "Choose the hero to synthesize first."
	else
		self.PickerMessage = mode == "DONOR" and "Material heroes are permanently consumed. Bench deployed or working heroes to use them." or "Choose the hero who will receive the EXP."
	end
	self.PickerMode = mode
	self.Picker.Visible = true
	self:RenderPicker()
end

function Synth.Pick(self: any, uuid: string)
	local hero = self.State.Heroes[uuid]
	if not hero then return end
	if self.PickerMode == "RECIPIENT" then
		self.Recipient = uuid
		local index = table.find(self.Donors, uuid)
		if index then table.remove(self.Donors, index) end
	else
		local status = hero.PitStatus or {}
		if status.EligibleDonor == false then
			self.PickerStatus.Text = status.Reason or "This hero cannot be used as material."
			self.PickerStatus.TextColor3 = C.Danger
			return
		end
		if #self.Donors >= DONOR_SLOTS then return end
		table.insert(self.Donors, uuid)
	end
	self.Message = ""
	self.Picker.Visible = false
	self:QueuePreview()
end

function Synth.RenderPicker(self: any)
	for _, child in self.PickerList:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local donorMode = self.PickerMode == "DONOR"
	self.PickerTitle.Text = spaced(donorMode and "SELECT MATERIAL" or "SELECT HERO")
	self.PickerStatus.Text, self.PickerStatus.TextColor3 = self.PickerMessage or "", C.Muted
	local heroes = {}
	for uuid, hero in self.State.Heroes do
		if not (donorMode and (uuid == self.Recipient or table.find(self.Donors, uuid))) then table.insert(heroes, hero) end
	end
	table.sort(heroes, function(a, b)
		local aOk = not donorMode or (a.PitStatus and a.PitStatus.EligibleDonor) or false
		local bOk = not donorMode or (b.PitStatus and b.PitStatus.EligibleDonor) or false
		if aOk ~= bOk then return aOk end
		if (a.Stars or 1) ~= (b.Stars or 1) then return (a.Stars or 1) > (b.Stars or 1) end
		if (a.Level or 1) ~= (b.Level or 1) then return (a.Level or 1) > (b.Level or 1) end
		return tostring(a.UUID) < tostring(b.UUID)
	end)
	if #heroes == 0 then
		local empty = label(self.PickerList, donorMode and "No other heroes available. Summon more heroes first." or "Your roster is empty.", 14, C.Muted, Enum.Font.GothamMedium)
		empty.Size, empty.ZIndex = UDim2.fromOffset(400, 40), 62
	end
	for i, hero in heroes do
		local eligible = not donorMode or not hero.PitStatus or hero.PitStatus.EligibleDonor ~= false
		local rarity = RARITY[math.clamp(hero.Stars or 1, 1, 5)]
		local tile = new("TextButton", {
			Name = "Hero_" .. tostring(hero.UUID), Text = "", LayoutOrder = i, AutoButtonColor = true,
			BackgroundColor3 = C.Slot, BorderSizePixel = 0, ZIndex = 62,
		}, self.PickerList)
		stroke(tile, eligible and rarity or C.LineDim, 1, eligible and 0.1 or 0.5)
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
		if not eligible then
			local shade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 64 }, tile)
			local tag = label(shade, (hero.PitStatus and hero.PitStatus.Status or "Unavailable"):upper(), 10, C.Danger)
			tag.Size, tag.Position, tag.ZIndex = UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 36), 65
		end
		local uuid = hero.UUID
		tile.Activated:Connect(function() self:Pick(uuid) end)
	end
end

--============================================================================
-- RENDERING
--============================================================================

function Synth.RenderSlot(self: any, slot: any, hero: any?, primary: boolean)
	local id = hero and hero.UUID or nil
	slot.Plus.Visible = hero == nil
	if slot.HeroId ~= id then
		slot.HeroId = id
		slot.Portrait:ClearAllChildren()
		if hero then
			local p = HeroCard.Portrait(slot.Portrait, hero)
			p.ZIndex = 43
		end
	end
	if hero then
		local rarity = RARITY[math.clamp(hero.Stars or 1, 1, 5)]
		slot.Caption.Text = primary and stars(hero.Stars) or string.format("Lv.%d", hero.Level or 1)
		slot.Caption.TextColor3 = primary and rarity or C.Text
		if slot.Stroke then
			slot.Stroke.Color = primary and C.Line or rarity
		end
	else
		slot.Caption.Text = ""
		if slot.Stroke then
			slot.Stroke.Color = primary and C.Line or C.LineDim
		end
	end
end

function Synth.Render(self: any)
	local heroes = self.State.Heroes or {}
	local recipient = self.Recipient and heroes[self.Recipient]
	self:RenderSlot(self.RecipientSlot, recipient, true)
	for i, slot in self.DonorSlots do
		local uuid = self.Donors[i]
		self:RenderSlot(slot, uuid and heroes[uuid], false)
	end

	local preview = self.Preview
	local before = preview and preview.Before
	local after = preview and preview.After
	for _, t in self.Tweens do t:Cancel() end
	table.clear(self.Tweens)
	if recipient then
		self.RecipientName.Text = string.format("%s  ·  %s", recipient.DisplayName or "Hero", recipient.Archetype or "")
		local level, xp = recipient.Level or 1, recipient.XP or 0
		local currentRatio = xpRatio(level, xp)
		local gainRatio = currentRatio
		if before and after then
			if after.Level > before.Level then
				currentRatio = 0
				gainRatio = after.Level >= (after.MaxLevel or math.huge) and 1 or xpRatio(after.Level, after.XP)
			else
				gainRatio = math.max(currentRatio, xpRatio(after.Level, after.XP))
			end
			self.LevelLabel.Text = string.format('Lv. %d <font color="#39E81E">→ Lv. %d</font>', before.Level, after.Level)
		else
			self.LevelLabel.Text = string.format("Lv. %d", level)
		end
		self.CurrentFill.Size = UDim2.fromScale(currentRatio, 1)
		local tween = TweenService:Create(self.GainFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(gainRatio, 1) })
		table.insert(self.Tweens, tween)
		tween:Play()
	else
		self.RecipientName.Text = "Tap the slot above to choose a hero"
		self.LevelLabel.Text = '<font color="#96929F">Lv. —  →  Lv. —</font>'
		self.CurrentFill.Size = UDim2.fromScale(0, 1)
		self.GainFill.Size = UDim2.fromScale(0, 1)
	end

	local ready = preview ~= nil and preview.CanCommit and not self.Loading and not self.Busy
	local button = self.ConfirmButton
	if self.Busy then button.Text = "SYNTHESIZING…"
	elseif self.ArmedRare then button.Text = "CONFIRM — RARE HEROES WILL BE LOST"
	else button.Text = "CONFIRM SYNTHESIZE" end
	button.TextColor3 = (ready or self.Busy) and C.Text or C.Muted
	if self.ConfirmStroke then
		self.ConfirmStroke.Color = self.ArmedRare and C.Danger or C.Line
	end

	local status, color = self.Message, C.Muted
	if status == "" then
		if self.Loading then status = "Calculating synthesis preview…"
		elseif preview and not preview.CanCommit then status, color = preview.Reason or "Requirements not met.", C.Danger
		elseif preview and preview.XP then
			status, color = string.format("+%d EXP from %d material hero%s", preview.XP.Final or 0, #self.Donors, #self.Donors == 1 and "" or "es"), C.Good
			if preview.Warnings and preview.Warnings[1] then status ..= "\n" .. tostring(preview.Warnings[1]) end
		elseif recipient then status = "Add material heroes to the slots below."
		end
	elseif status:find("complete") then color = C.Good
	elseif self.ArmedRare then color = C.Danger end
	self.Status.Text, self.Status.TextColor3 = status, color
end

function Synth.Celebrate(self: any)
	local flash = new("Frame", {
		BackgroundColor3 = C.Line, BackgroundTransparency = 0.2, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = 46,
	}, self.RecipientSlot.Button)
	local tween = TweenService:Create(flash, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function() flash:Destroy() end)
end

--============================================================================
-- VISIBILITY
--============================================================================

function Synth.Open(self: any)
	self.Root.Visible, self.Scrim.Visible = true, true
	self.Picker.Visible = false
	self.Message = ""
	self:Render()
	self:Refresh()
end

function Synth.Close(self: any)
	if self.Busy then return end
	self.Root.Visible, self.Scrim.Visible, self.Picker.Visible = false, false, false
	self.PreviewSerial += 1
	self.Loading = false
end

function Synth.IsOpen(self: any): boolean
	return self.Root.Visible
end

return Synth
