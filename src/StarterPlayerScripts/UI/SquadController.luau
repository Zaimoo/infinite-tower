--!strict
-- StarterPlayerScripts/UI/SquadController.luau
-- Authoritative 5-Hero Squad Deploy & Roster Management modal.
-- Matches visual layout, hierarchy, and gothic tokens from Gemini_Generated_Image_27yazb27yazb27ya.jpg.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local HeroCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HeroCatalog"))

local SquadController = {}
SquadController.__index = SquadController

local SQUAD_SLOTS = 5
local WIDTH, HEIGHT = 840, 640

local C = {
	Scrim = Color3.fromRGB(6, 7, 12),
	Background = Color3.fromRGB(15, 17, 26),
	CardBg = Color3.fromRGB(22, 25, 38),
	PortraitBg = Color3.fromRGB(13, 15, 23),
	BorderDim = Color3.fromRGB(80, 75, 95),
	BorderBronze = Color3.fromRGB(120, 95, 68),
	BorderGoldGlow = Color3.fromRGB(255, 225, 110),
	TextWhite = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(160, 165, 185),
	TextDim = Color3.fromRGB(120, 125, 145),
	StarGold = Color3.fromRGB(255, 215, 80),
	ButtonBg = Color3.fromRGB(26, 30, 46),
	ButtonBorder = Color3.fromRGB(105, 95, 125),
	InSquadBg = Color3.fromRGB(10, 12, 18),
	Divider = Color3.fromRGB(65, 60, 80),
	Green = Color3.fromRGB(45, 160, 95),
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
	}, parent)
end

-- Hollow corner diamonds matching gothic box frame style
local function cornerDiamonds(parent: GuiObject, size: number)
	for _, corner in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
		local diamond = new("Frame", {
			Name = "CornerDiamond",
			AnchorPoint = corner,
			Position = UDim2.new(corner.X, corner.X == 0 and -size * 0.4 or size * 0.4, corner.Y, corner.Y == 0 and -size * 0.4 or size * 0.4),
			Size = UDim2.fromOffset(size, size),
			Rotation = 45,
			BackgroundColor3 = C.Background,
			BorderSizePixel = 0,
			ZIndex = parent.ZIndex + 1,
		}, parent)
		stroke(diamond, C.BorderDim, 1)
	end
end

function SquadController.new(screenGui: ScreenGui, getProfile: () -> any, remotes: Folder)
	local self = setmetatable({}, SquadController)
	self.GetProfile = getProfile
	self.AssignRemote = remotes:WaitForChild("AssignHeroRole") :: RemoteFunction

	self.SelectedSlot = 1 -- 1..5 currently active slot selected for swapping
	self.SelectedRosterUUID = nil :: string?

	-- Root Dimming Scrim
	self.Scrim = new("TextButton", {
		Name = "SquadDeployScrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
	}, screenGui)

	self.Scrim.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Main Modal Frame
	self.Root = new("Frame", {
		Name = "SquadDeployModal",
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = C.Background,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 31,
	}, self.Scrim)

	self.Scale = new("UIScale", {
		Name = "ModalScale",
		Scale = 1,
	}, self.Root)

	local function updateScale()
		local cam = workspace.CurrentCamera
		if cam then
			local vp = cam.ViewportSize
			local sX = (vp.X - 24) / WIDTH
			local sY = (vp.Y - 24) / HEIGHT
			self.Scale.Scale = math.clamp(math.min(sX, sY), 0.52, 1)
		end
	end
	updateScale()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	new("UICorner", { CornerRadius = UDim.new(0, 8) }, self.Root)
	self.MainStroke = stroke(self.Root, C.BorderDim, 1.6)
	cornerDiamonds(self.Root, 10)

	-- Inner decorative outline frame
	local innerFrame = new("Frame", {
		Name = "InnerFrame",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
		ZIndex = 31,
	}, self.Root)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, innerFrame)
	stroke(innerFrame, C.BorderDim, 1, 0.4)

	-- Close Button (X)
	local closeBtn = new("TextButton", {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Text = "✕",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = C.TextMuted,
		ZIndex = 35,
	}, self.Root)

	closeBtn.MouseEnter:Connect(function()
		closeBtn.TextColor3 = C.TextWhite
	end)
	closeBtn.MouseLeave:Connect(function()
		closeBtn.TextColor3 = C.TextMuted
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Header Titles
	self.TitleLabel = new("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.new(1, -80, 0, 28),
		BackgroundTransparency = 1,
		Text = "S Q U A D   D E P L O Y",
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = C.TextWhite,
		ZIndex = 33,
	}, self.Root)

	self.SubtitleLabel1 = new("TextLabel", {
		Name = "Subtitle1",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.new(1, -80, 0, 16),
		BackgroundTransparency = 1,
		Text = "MANAGE YOUR 5-HERO ACTIVE SQUAD",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextColor3 = C.TextMuted,
		ZIndex = 33,
	}, self.Root)

	self.SubtitleLabel2 = new("TextLabel", {
		Name = "Subtitle2",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.new(1, -80, 0, 16),
		BackgroundTransparency = 1,
		Text = "Tap an active slot or hero below to swap",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = C.TextDim,
		ZIndex = 33,
	}, self.Root)

	-- Active Squad Section Header
	self.ActiveSquadHeader = new("TextLabel", {
		Name = "ActiveSquadHeader",
		Position = UDim2.new(0, 28, 0, 92),
		Size = UDim2.new(0, 280, 0, 20),
		BackgroundTransparency = 1,
		Text = "ACTIVE SQUAD (5/5)",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.TextWhite,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 33,
	}, self.Root)

	-- Active Squad 5 Slots Container
	self.SlotsContainer = new("Frame", {
		Name = "SlotsContainer",
		Position = UDim2.new(0, 24, 0, 116),
		Size = UDim2.new(1, -48, 0, 196),
		BackgroundTransparency = 1,
		ZIndex = 33,
	}, self.Root)

	-- Pre-build 5 Slot Columns
	self.SlotCards = {}
	local slotW = 144
	local gap = 18
	for i = 1, SQUAD_SLOTS do
		local col = new("Frame", {
			Name = "SlotColumn_" .. i,
			Position = UDim2.new(0, (i - 1) * (slotW + gap), 0, 0),
			Size = UDim2.new(0, slotW, 1, 0),
			BackgroundTransparency = 1,
			ZIndex = 33,
		}, self.SlotsContainer)

		-- "SLOT X" Label above card
		new("TextLabel", {
			Name = "SlotTag",
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1,
			Text = "SLOT " .. i,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = C.TextDim,
			ZIndex = 34,
		}, col)

		-- Card Box
		local card = new("TextButton", {
			Name = "SlotCard",
			Text = "",
			AutoButtonColor = false,
			Position = UDim2.new(0, 0, 0, 20),
			Size = UDim2.new(1, 0, 0, 140),
			BackgroundColor3 = C.CardBg,
			ZIndex = 34,
		}, col)
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, card)
		local cardStroke = stroke(card, C.BorderBronze, 1.2)

		-- Outer Glow for Selected Slot State
		local glowFrame = new("Frame", {
			Name = "SelectGlow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 8, 1, 8),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 33,
		}, card)
		new("UICorner", { CornerRadius = UDim.new(0, 8) }, glowFrame)
		stroke(glowFrame, C.BorderGoldGlow, 2.5)

		-- Portrait Frame
		local portraitFrame = new("Frame", {
			Name = "PortraitHost",
			Position = UDim2.new(0, 6, 0, 6),
			Size = UDim2.new(1, -12, 0, 84),
			BackgroundColor3 = C.PortraitBg,
			ClipsDescendants = true,
			ZIndex = 35,
		}, card)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, portraitFrame)

		-- Hero Display Name
		local nameLbl = new("TextLabel", {
			Name = "HeroName",
			Position = UDim2.new(0, 4, 0, 94),
			Size = UDim2.new(1, -8, 0, 20),
			BackgroundTransparency = 1,
			Text = "Empty",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = C.TextWhite,
			ZIndex = 35,
		}, card)

		-- Stars & Level
		local infoLbl = new("TextLabel", {
			Name = "HeroInfo",
			Position = UDim2.new(0, 4, 0, 114),
			Size = UDim2.new(1, -8, 0, 18),
			BackgroundTransparency = 1,
			Text = "—",
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = C.StarGold,
			ZIndex = 35,
		}, card)

		-- Action Button below card (SWAP / CHANGE)
		local actionBtn = new("TextButton", {
			Name = "ActionButton",
			Position = UDim2.new(0, 0, 0, 168),
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = C.ButtonBg,
			Text = "CHANGE",
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextColor3 = C.TextWhite,
			AutoButtonColor = true,
			ZIndex = 34,
		}, col)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, actionBtn)
		stroke(actionBtn, C.ButtonBorder, 1)

		card.MouseButton1Click:Connect(function()
			self:SelectSlot(i)
		end)
		actionBtn.MouseButton1Click:Connect(function()
			self:SelectSlot(i)
		end)

		self.SlotCards[i] = {
			Column = col,
			Card = card,
			Stroke = cardStroke,
			Glow = glowFrame,
			Portrait = portraitFrame,
			Name = nameLbl,
			Info = infoLbl,
			Button = actionBtn,
			HeroUUID = nil,
		}
	end

	-- Center Horizontal Divider
	new("Frame", {
		Name = "Divider",
		Position = UDim2.new(0, 24, 0, 324),
		Size = UDim2.new(1, -48, 0, 1),
		BackgroundColor3 = C.Divider,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 33,
	}, self.Root)

	-- Select Hero To Deploy Section Header
	self.RosterHeader = new("TextLabel", {
		Name = "RosterHeader",
		Position = UDim2.new(0, 28, 0, 334),
		Size = UDim2.new(0, 280, 0, 20),
		BackgroundTransparency = 1,
		Text = "SELECT HERO TO DEPLOY",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.TextWhite,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 33,
	}, self.Root)

	-- Horizontal Roster Scrolling Frame
	self.RosterScroll = new("ScrollingFrame", {
		Name = "RosterScroll",
		Position = UDim2.new(0, 24, 0, 360),
		Size = UDim2.new(1, -48, 0, 190),
		BackgroundTransparency = 1,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.BorderBronze,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ZIndex = 33,
	}, self.Root)

	local rosterLayout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 14),
		Parent = self.RosterScroll,
	})

	-- Bottom Action Bar (Confirm Squad & Auto-Swap)
	local bottomBar = new("Frame", {
		Name = "BottomActionGroup",
		Position = UDim2.new(0, 24, 0, 568),
		Size = UDim2.new(1, -48, 0, 50),
		BackgroundTransparency = 1,
		ZIndex = 33,
	}, self.Root)

	-- Auto-Swap Resting Heroes Button
	self.AutoSwapBtn = new("TextButton", {
		Name = "AutoSwapButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, 210, 0, 38),
		BackgroundColor3 = C.ButtonBg,
		Text = "⚡ AUTO-SWAP RESTED",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = C.Green,
		ZIndex = 34,
	}, bottomBar)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, self.AutoSwapBtn)
	stroke(self.AutoSwapBtn, C.Green, 1, 0.3)

	self.AutoSwapBtn.MouseButton1Click:Connect(function()
		self.AssignRemote:InvokeServer("AUTO_SWAP_EXHAUSTED", "")
		task.wait(0.1)
		self:Refresh()
	end)

	-- Large Centered CONFIRM SQUAD Button
	self.ConfirmBtn = new("TextButton", {
		Name = "ConfirmButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 340, 0, 44),
		BackgroundColor3 = C.ButtonBg,
		Text = "CONFIRM SQUAD",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.TextWhite,
		ZIndex = 34,
	}, bottomBar)
	new("UICorner", { CornerRadius = UDim.new(0, 6) }, self.ConfirmBtn)
	local confirmStroke = stroke(self.ConfirmBtn, C.BorderDim, 1.4)
	cornerDiamonds(self.ConfirmBtn, 7)

	self.ConfirmBtn.MouseEnter:Connect(function()
		self.ConfirmBtn.BackgroundColor3 = Color3.fromRGB(38, 44, 68)
		confirmStroke.Color = C.BorderGoldGlow
	end)
	self.ConfirmBtn.MouseLeave:Connect(function()
		self.ConfirmBtn.BackgroundColor3 = C.ButtonBg
		confirmStroke.Color = C.BorderDim
	end)
	self.ConfirmBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Close on ESC key
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and self.Root.Visible then
			self:Close()
		end
	end)

	return self
end

function SquadController.SelectSlot(self: any, slotIdx: number)
	self.SelectedSlot = slotIdx
	for i = 1, SQUAD_SLOTS do
		local slotData = self.SlotCards[i]
		local isSel = (i == slotIdx)
		slotData.Glow.Visible = isSel
		slotData.Stroke.Color = isSel and C.BorderGoldGlow or C.BorderBronze
		slotData.Stroke.Thickness = isSel and 2.2 or 1.2
	end
end

function SquadController.Open(self: any)
	self.Scrim.Visible = true
	self.Root.Visible = true
	self.SelectedSlot = 1
	self:Refresh()

	-- Opening Pop Animation
	self.Root.Size = UDim2.fromOffset(WIDTH * 0.94, HEIGHT * 0.94)
	self.Scrim.BackgroundTransparency = 1
	local tw1 = TweenService:Create(self.Scrim, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.45,
	})
	local tw2 = TweenService:Create(self.Root, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
	})
	tw1:Play()
	tw2:Play()
end

function SquadController.Close(self: any)
	local tw = TweenService:Create(self.Scrim, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	tw:Play()
	tw.Completed:Connect(function()
		self.Scrim.Visible = false
		self.Root.Visible = false
	end)
end

function SquadController.IsOpen(self: any): boolean
	return self.Root ~= nil and self.Root.Visible == true
end

function SquadController.Toggle(self: any)
	if self:IsOpen() then
		self:Close()
	else
		self:Open()
	end
end

function SquadController.Refresh(self: any)
	local profile = self.GetProfile()
	if not profile or not profile.Heroes then
		return
	end

	-- Map active heroes by SQUAD_SLOT_1 .. SQUAD_SLOT_5
	local squadBySlot: { [number]: any } = {}
	local activeCount = 0
	for _, hero in pairs(profile.Heroes) do
		local matchSlot = string.match(hero.Assignment or "", "^SQUAD_SLOT_(%d+)")
		if matchSlot then
			local num = tonumber(matchSlot)
			if num and num >= 1 and num <= SQUAD_SLOTS then
				squadBySlot[num] = hero
				activeCount += 1
			end
		end
	end

	self.ActiveSquadHeader.Text = string.format("ACTIVE SQUAD (%d/%d)", activeCount, SQUAD_SLOTS)

	-- Render 5 Active Slots
	for i = 1, SQUAD_SLOTS do
		local slotData = self.SlotCards[i]
		local hero = squadBySlot[i]
		slotData.HeroUUID = hero and hero.UUID or nil

		-- Clear previous portrait
		for _, c in ipairs(slotData.Portrait:GetChildren()) do
			c:Destroy()
		end

		if hero then
			slotData.Name.Text = hero.DisplayName
			slotData.Info.Text = string.format("%s Lv.%d", string.rep("★", hero.Stars or 1), hero.Level or 1)
			slotData.Button.Text = "CHANGE"
			HeroCard.Portrait(slotData.Portrait, hero)
		else
			slotData.Name.Text = "[EMPTY]"
			slotData.Info.Text = "Select Below"
			slotData.Button.Text = "ASSIGN"

			local emptyIcon = new("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "+",
				Font = Enum.Font.GothamMedium,
				TextSize = 34,
				TextColor3 = C.TextDim,
				Parent = slotData.Portrait,
			})
		end

		local isSel = (self.SelectedSlot == i)
		slotData.Glow.Visible = isSel
		slotData.Stroke.Color = isSel and C.BorderGoldGlow or C.BorderBronze
		slotData.Stroke.Thickness = isSel and 2.2 or 1.2
	end

	-- Render Select Hero To Deploy Roster
	for _, c in ipairs(self.RosterScroll:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end

	local heroList = {}
	for _, h in pairs(profile.Heroes) do
		table.insert(heroList, h)
	end
	table.sort(heroList, function(a, b)
		local aIn = string.find(a.Assignment or "", "^SQUAD_SLOT_") ~= nil
		local bIn = string.find(b.Assignment or "", "^SQUAD_SLOT_") ~= nil
		if aIn ~= bIn then
			return not aIn -- Put benched/available heroes first!
		end
		if a.Stars ~= b.Stars then
			return a.Stars > b.Stars
		end
		return a.Level > b.Level
	end)

	local cardWidth = 136
	for idx, hero in ipairs(heroList) do
		local inSquad = string.find(hero.Assignment or "", "^SQUAD_SLOT_") ~= nil

		local card = new("TextButton", {
			Name = "HeroCard_" .. hero.UUID,
			LayoutOrder = idx,
			Text = "",
			AutoButtonColor = true,
			Size = UDim2.new(0, cardWidth, 0, 172),
			BackgroundColor3 = C.CardBg,
			ZIndex = 34,
			Parent = self.RosterScroll,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 6) }, card)
		local cardStroke = stroke(card, inSquad and C.BorderDim or C.BorderBronze, 1.1)

		-- Portrait
		local portraitFrame = new("Frame", {
			Name = "PortraitHost",
			Position = UDim2.new(0, 6, 0, 6),
			Size = UDim2.new(1, -12, 0, 96),
			BackgroundColor3 = C.PortraitBg,
			ClipsDescendants = true,
			ZIndex = 35,
			Parent = card,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, portraitFrame)
		HeroCard.Portrait(portraitFrame, hero)

		-- "IN SQUAD" Overlay Banner matching reference image
		if inSquad then
			local inSquadBanner = new("Frame", {
				Name = "InSquadBanner",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundColor3 = C.InSquadBg,
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				ZIndex = 36,
				Parent = portraitFrame,
			})
			new("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "IN SQUAD",
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextColor3 = C.TextWhite,
				ZIndex = 37,
				Parent = inSquadBanner,
			})
		end

		-- Hero Display Name
		new("TextLabel", {
			Name = "NameLabel",
			Position = UDim2.new(0, 4, 0, 108),
			Size = UDim2.new(1, -8, 0, 20),
			BackgroundTransparency = 1,
			Text = hero.DisplayName,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = C.TextWhite,
			ZIndex = 35,
			Parent = card,
		})

		-- Star & Level
		new("TextLabel", {
			Name = "InfoLabel",
			Position = UDim2.new(0, 4, 0, 128),
			Size = UDim2.new(1, -8, 0, 18),
			BackgroundTransparency = 1,
			Text = string.format("%s Lv.%d", string.rep("★", hero.Stars or 1), hero.Level or 1),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = C.StarGold,
			ZIndex = 35,
			Parent = card,
		})

		-- Archetype / Subtext
		new("TextLabel", {
			Name = "ArchetypeLabel",
			Position = UDim2.new(0, 4, 0, 148),
			Size = UDim2.new(1, -8, 0, 16),
			BackgroundTransparency = 1,
			Text = string.format("[%s]", string.upper(hero.Archetype or "STRIKER")),
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextColor3 = C.TextMuted,
			ZIndex = 35,
			Parent = card,
		})

		card.MouseButton1Click:Connect(function()
			local targetSlot = self.SelectedSlot or 1
			local targetTag = "SQUAD_SLOT_" .. tostring(targetSlot)

			-- If hero is already in this slot, bench them
			if hero.Assignment == targetTag then
				self.AssignRemote:InvokeServer(hero.UUID, "BENCHED")
			else
				self.AssignRemote:InvokeServer(hero.UUID, targetTag)
			end

			-- Auto-advance selected slot to next slot
			self.SelectedSlot = (targetSlot % SQUAD_SLOTS) + 1
			task.wait(0.1)
			self:Refresh()
		end)
	end

	self.RosterScroll.CanvasSize = UDim2.new(0, #heroList * (cardWidth + 14), 0, 0)
end

return SquadController
