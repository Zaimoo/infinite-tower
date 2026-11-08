--!strict
-- One modal presentation shared by Synthesis and Equip Artifact. No gameplay rules here.
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grimoire = require(ReplicatedStorage.Shared.Util.GildedGrimoire)
local GrimoireIcons = require(ReplicatedStorage.Shared.Util.GrimoireIcons)
local Card = require(script.Parent.HeroPickerCard)
local Drawer = {}
Drawer.__index = Drawer
local nextId = 0
local GOLD = Grimoire.Text.Gold

local function new(kind: string, props: { [string]: any }, parent: Instance): any
	local object = Instance.new(kind)
	for key, value in props do (object :: any)[key] = value end
	object.Parent = parent
	return object
end

function Drawer.new(parent: Instance, z: number, onClose: () -> ())
	nextId += 1
	local self: any = setmetatable({}, Drawer)
	self.ActionName = "HeroSelectionDrawer" .. nextId
	self.Serial = 0
	self.OnClose = onClose
	self.Z = z
	self.Root = new("TextButton", {
		Name = "HeroSelectionDrawer", Text = "", AutoButtonColor = false, Selectable = false,
		Active = true, Modal = true, Visible = false, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 3, 13), BackgroundTransparency = 0.3,
		BorderSizePixel = 0, ZIndex = z, SelectionGroup = true,
		SelectionBehaviorUp = Enum.SelectionBehavior.Stop, SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
		SelectionBehaviorLeft = Enum.SelectionBehavior.Stop, SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
	}, parent)
	self.Panel = new("Frame", {
		Name = "Panel", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -24, 0.88, -10), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Active = true, ZIndex = z + 1,
	}, self.Root)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, self.Panel)
	new("UIStroke", { Color = GOLD, Thickness = 2 }, self.Panel)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(52, 31, 66), Color3.fromRGB(19, 12, 29)), Rotation = 90 }, self.Panel)
	for _, x in { 0, 1 } do
		new("Frame", {
			Name = "CornerGem", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0),
			Size = UDim2.fromOffset(12, 12), Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = z + 3,
		}, self.Panel)
	end
	self.Title = new("TextLabel", {
		Name = "Title", Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -86, 0, 34),
		BackgroundTransparency = 1, Text = "SELECT HERO", TextSize = 24,
		TextColor3 = Color3.new(1, 1, 1), TextScaled = true, ZIndex = z + 2,
	}, self.Panel)
	new("UITextSizeConstraint", { MinTextSize = 16, MaxTextSize = 28 }, self.Title)
	self.Title:SetAttribute("Grimoire", true)
	Grimoire.StyleText(self.Title, "Title")
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), GOLD) }, self.Title)

	self.Subtitle = new("TextLabel", {
		Name = "Subtitle", Position = UDim2.fromOffset(14, 47), Size = UDim2.new(1, -86, 0, 24),
		BackgroundTransparency = 1, Text = "", TextSize = 15,
		TextColor3 = Grimoire.Text.Muted, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = z + 2,
	}, self.Panel)
	self.Subtitle:SetAttribute("Grimoire", true)
	Grimoire.StyleText(self.Subtitle, "Body")

	self.CloseButton = new("TextButton", {
		Name = "Close", Position = UDim2.new(1, -58, 0, 14), Size = UDim2.fromOffset(44, 44),
		Text = "", BackgroundColor3 = Color3.fromRGB(31, 22, 42), BorderSizePixel = 0, ZIndex = z + 3,
	}, self.Panel)
	new("UICorner", { CornerRadius = UDim.new(0, 7) }, self.CloseButton)
	new("UIStroke", { Color = GOLD, Thickness = 1.5 }, self.CloseButton)
	self.CloseButton:SetAttribute("Grimoire", true)
	GrimoireIcons.CloseGlyph(self.CloseButton, 18)
	self.CloseButton.Activated:Connect(function() self:Close() end)

	self.Scroll = new("ScrollingFrame", {
		Name = "Heroes", Position = UDim2.fromOffset(14, 82), Size = UDim2.new(1, -28, 1, -118),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 6, ScrollBarImageColor3 = GOLD, ZIndex = z + 2,
	}, self.Panel)
	self.Grid = new("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 254), CellPadding = UDim2.fromOffset(12, 14),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.Scroll)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12) }, self.Scroll)
	self.Footer = new("TextLabel", {
		Name = "Footer", Position = UDim2.new(0, 18, 1, -30), Size = UDim2.new(1, -36, 0, 24),
		BackgroundTransparency = 1, Text = "", TextSize = 14,
		TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z + 2,
	}, self.Panel)
	self.Footer:SetAttribute("Grimoire", true)
	Grimoire.StyleText(self.Footer, "Body")

	self.Empty = new("TextLabel", {
		Name = "Empty", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
		Text = "No heroes in your roster.", TextSize = 15,
		TextColor3 = Grimoire.Text.Muted, Visible = false, ZIndex = z + 3,
	}, self.Panel)
	self.Empty.Position = UDim2.fromOffset(14, 82)
	self.Empty.Size = UDim2.new(1, -28, 1, -118)
	self.Empty:SetAttribute("Grimoire", true)
	Grimoire.StyleText(self.Empty, "Body")

	local function resize()
		local compact = self.Root.AbsoluteSize.Y < 700
		self.Panel.Size = UDim2.new(1, -24, if compact then 0.98 else 0.94, -10)
		self.Title.Position = UDim2.fromOffset(14, if compact then 0 else 12)
		self.Subtitle.Position = UDim2.fromOffset(14, if compact then 30 else 47)
		self.Subtitle.TextSize = if compact then 13 else 15
		self.CloseButton.Position = UDim2.new(1, -58, 0, if compact then 4 else 14)
		self.Scroll.Position = UDim2.fromOffset(14, if compact then 54 else 82)
		self.Scroll.Size = UDim2.new(1, -28, 1, if compact then -80 else -118)
		self.Footer.Position = UDim2.new(0, 18, 1, if compact then -22 else -30)
		self.Footer.Size = UDim2.new(1, -36, 0, if compact then 18 else 24)
		self.Footer.TextSize = if compact then 12 else 14
		local width = math.max(1, self.Scroll.AbsoluteSize.X - 16)
		local wideCards = compact and width >= 420
		self.WideCards = wideCards
		for _, button in self.Buttons or {} do Card.Resize(button, wideCards) end
		local columnPitch = if wideCards then 212 else 166
		local columns = math.max(1, math.floor((width + 12) / columnPitch))
		self.Columns = columns
		self.Grid.CellSize = UDim2.fromOffset(math.floor((width - (columns - 1) * 12) / columns), if wideCards then Card.WideHeight else Card.TallHeight)
		self:LinkFocus()
	end
	self.Scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	self.Root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	local inputConnection = UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		if self.Opened and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			GuiService.SelectedObject = self.Buttons[1] or self.CloseButton
		end
	end)
	self.Root.Destroying:Connect(function()
		inputConnection:Disconnect()
		self:CancelWork()
		if self.BackContext then self.BackContext:Destroy(); self.BackContext = nil end
	end)
	Grimoire.Watch(self.Root)
	resize()
	return self
end

function Drawer.CancelWork(self: any)
	self.Serial += 1
	if self.Tween then self.Tween:Cancel(); self.Tween = nil end
	if self.Completion then self.Completion:Disconnect(); self.Completion = nil end
	if self.FocusTask then task.cancel(self.FocusTask); self.FocusTask = nil end
end

function Drawer.LinkFocus(self: any)
	local buttons = self.Buttons or {}
	local columns = self.Columns or 1
	self.CloseButton.NextSelectionDown = buttons[1] or self.CloseButton
	for i, button in buttons do
		button.NextSelectionLeft = buttons[i - 1] or button
		button.NextSelectionRight = buttons[i + 1] or button
		button.NextSelectionUp = buttons[i - columns] or self.CloseButton
		button.NextSelectionDown = buttons[i + columns] or button
	end
end

function Drawer.SetContent(self: any, title: string, subtitle: string, entries: { any }, onSelect: (string) -> (), emptyText: string?)
	local selected = GuiService.SelectedObject
	local focusUUID = selected and selected:GetAttribute("HeroUUID")
	local hadFocus = selected and selected:IsDescendantOf(self.Root)
	for _, child in self.Scroll:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	self.Title.Text, self.Subtitle.Text = title, subtitle
	self.Empty.Text = emptyText or "No heroes in your roster."
	self.Empty.Visible = #entries == 0
	self.Footer.Text = string.format("%d heroes  ·  Scroll for more", #entries)
	self.Buttons = {}
	local focus = nil
	for i, entry in entries do
		local button = Card.Create(self.Scroll, entry, i, self.Z + 3, function(uuid)
			if self.Opened and self.Root.Visible then onSelect(uuid) end
		end)
		Card.Resize(button, self.WideCards == true)
		table.insert(self.Buttons, button)
		if entry.UUID == focusUUID or (not focusUUID and entry.Selected) then focus = button end
	end
	self:LinkFocus()
	if hadFocus then GuiService.SelectedObject = focus or self.Buttons[1] or self.CloseButton end
end

function Drawer.Open(self: any, returnFocus: GuiObject?)
	if self.Opened then return end
	self:CancelWork()
	if not self.Root.Visible then self.ReturnFocus = returnFocus or GuiService.SelectedObject end
	self.Opened = true
	GuiService.SelectedObject = nil
	self.Root.Visible = true
	self.Scroll.CanvasPosition = Vector2.zero
	self.Panel.Position = UDim2.new(0.5, 0, 1.9, 0)
	self.Tween = TweenService:Create(self.Panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -10) })
	self.Tween:Play()
	if self.BackContext then self.BackContext:Destroy() end
	local context = Instance.new("InputContext")
	context.Name = self.ActionName
	context.Priority = 4000
	context.Sink = true
	local back = Instance.new("InputAction")
	back.Name = "CloseDrawer"
	back.Type = Enum.InputActionType.Bool
	back.Parent = context
	for _, key in { Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace } do
		local binding = Instance.new("InputBinding")
		binding.KeyCode = key
		binding.Parent = back
	end
	-- Backspace while typing (chat, the search box) edits text; it doesn't close the drawer.
	back.Pressed:Connect(function()
		if UserInputService:GetFocusedTextBox() then return end
		self:Close()
	end)
	context.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
	self.BackContext = context
	local serial = self.Serial
	self.FocusTask = task.delay(0.24, function()
		self.FocusTask = nil
		if serial == self.Serial and self.Opened and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
			GuiService.SelectedObject = self.Buttons[1] or self.CloseButton
		end
	end)
end

function Drawer.Close(self: any, immediate: boolean?)
	if not self.Root.Visible then return end
	self:CancelWork()
	self.Opened = false
	local function finish()
		local selected = GuiService.SelectedObject
		local restore = selected and selected:IsDescendantOf(self.Root)
		self.Root.Visible = false
		if self.BackContext then self.BackContext:Destroy(); self.BackContext = nil end
		self.OnClose() -- re-enable the opener before restoring selection
		if restore then
			local target = self.ReturnFocus
			GuiService.SelectedObject = nil
			local serial = self.Serial
			self.FocusTask = task.defer(function()
				self.FocusTask = nil
				if serial ~= self.Serial or self.Root.Visible or not target or not target.Parent then return end
				local ancestor: Instance? = target
				while ancestor and ancestor:IsA("GuiObject") do
					if not ancestor.Visible then return end
					ancestor = ancestor.Parent
				end
				if target.Visible and target.Selectable and target.Interactable then GuiService.SelectedObject = target end
			end)
		end
		self.ReturnFocus = nil
	end
	if immediate then finish(); return end
	self.Tween = TweenService:Create(self.Panel, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 1.9, 0) })
	self.Completion = self.Tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then finish() end
	end)
	self.Tween:Play()
end

return Drawer
