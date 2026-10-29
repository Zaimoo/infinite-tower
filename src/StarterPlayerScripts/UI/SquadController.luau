--!strict
-- StarterPlayerScripts/UI/SquadController.luau
-- Squad Deploy (Phase 5, Gilded Grimoire). The player picks which heroes fight in the tower.
--
-- How it works:
--   * CHANGE / ASSIGN on a slot puts that slot in "choosing" mode; the roster below then shows
--     which heroes can go there, and clicking one assigns it (a squad hero swaps slots).
--   * Clicking a hero with no slot chosen sends it to the first empty slot. If the squad is full,
--     the hero is held and each slot offers REPLACE.
--   * REMOVE benches a slot's hero. AUTO USE BEST deploys the strongest ready heroes
--     from the squad and bench (facility workers stay at work).
-- The server (AssignHeroRole) validates everything; its reply is shown in the status line.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local Theme = require(script.Parent:WaitForChild("Hud"):WaitForChild("Theme"))
local GothicBoxStyle = require(Shared:WaitForChild("Util"):WaitForChild("GothicBoxStyle"))
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))

local SquadController = {}
SquadController.__index = SquadController

local SQUAD_SLOTS = 5 -- slot cards drawn; how many are open comes from the Fortress Tree
local WIDTH, HEIGHT = 980, 668
local SLOT_W, SLOT_H, SLOT_GAP = 172, 214, 12
local CARD_W, CARD_H = 138, 176
local Z = 32
local INK = GildedGrimoire.Ink
local TEXT = GildedGrimoire.Text

local FACILITY_LABELS: { [string]: string } = {
	FACILITY_GUARD_POST = "Guard Post",
	FACILITY_MARKET = "Market",
	FACILITY_TRAINING = "Training",
	FACILITY_GODS_BLESSING = "Blessing",
}

type Sort = "Power" | "Stars" | "Level"

-- Open slots for the current profile (1 to start, up to 5 through the Command branch).
local function openSlots(profile: any): number
	return FortressTree.SquadSlots(profile and profile.FortressTree)
end

local function slotOf(hero: any): number?
	local n = string.match(hero.Assignment or "", "^SQUAD_SLOT_(%d+)$")
	return n and tonumber(n) or nil
end

local function restingSeconds(hero: any): number
	return math.max(0, (hero.ComaUntilTimestamp or 0) - os.time())
end

local function abbreviate(n: number): string
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= unit[1] then
			return (string.gsub(string.format("%.1f%s", n / unit[1], unit[2]), "%.0(%a)$", "%1"))
		end
	end
	return tostring(math.round(n))
end

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

-- A themed label: "Title" (heavy decorative + ink), "Number" (heavy + ink) or "Body".
local function label(parent: Instance, role: string, props: { [string]: any }): TextLabel
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = TEXT.Parchment,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		RichText = true,
	}, nil)
	for k, v in pairs(props) do
		(l :: any)[k] = v
	end
	l:SetAttribute("Grimoire", true)
	GildedGrimoire.StyleText(l, role)
	l.Parent = parent
	return l
end

-- White-to-gold heading gradient.
local function gold(l: TextLabel)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), TEXT.Gold) }, l)
end

-- A themed button: toned panel with an ink outline and rail; the label is a child so the fill
-- gradient never tints the text. Returns the button and its label.
local function button(parent: Instance, tone: string, text: string, props: { [string]: any }): (TextButton, TextLabel)
	local b = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = Z + 4,
	}, nil)
	for k, v in pairs(props) do
		(b :: any)[k] = v
	end
	b.Parent = parent
	GildedGrimoire.Frame(b, { Class = "Button", Tone = tone, ZIndex = b.ZIndex })
	local l = label(b, "Title", {
		Name = "Label",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 1, -4),
		TextSize = 14,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = Color3.new(1, 1, 1),
		Text = text,
		ZIndex = b.ZIndex + 2,
	})
	local scale = new("UIScale", {}, b)
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	return b, l
end

-- Re-tones a button made with `button` (fill gradient and label colour).
local function retone(b: TextButton, l: TextLabel, tone: string, text: string)
	local t = GildedGrimoire.Tones[tone]
	local fill = b:FindFirstChild("GrimoireFill") :: UIGradient?
	if fill then fill.Color = ColorSequence.new(t.Top, t.Bottom) end
	local rail = GildedGrimoire.StateStroke(b)
	if rail then rail.Color = t.Rail end
	l.Text = text
	l.TextColor3 = Color3.new(1, 1, 1)
end

-- A small rounded status chip; returns the chip and its label.
local function chip(parent: Instance, props: { [string]: any }): (Frame, TextLabel)
	local c = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 14, 30),
		BorderSizePixel = 0,
		ZIndex = Z + 6,
	}, nil)
	for k, v in pairs(props) do
		(c :: any)[k] = v
	end
	c.Parent = parent
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
	new("UIStroke", { Color = INK, Thickness = 1.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, c)
	local l = label(c, "Title", {
		Size = UDim2.new(1, -8, 1, 0),
		Position = UDim2.fromOffset(4, 0),
		TextScaled = true,
		Text = "",
		ZIndex = c.ZIndex + 1,
	})
	new("UITextSizeConstraint", { MaxTextSize = 11 }, l)
	return c, l
end

function SquadController.new(screenGui: ScreenGui, getProfile: () -> any, remotes: Folder, onClose: (() -> ())?)
	local self = setmetatable({}, SquadController) :: any
	self.GetProfile = getProfile
	self.OnClose = onClose
	self.AssignRemote = remotes:WaitForChild("AssignHeroRole") :: RemoteFunction

	self.ChoosingSlot = nil :: number? -- slot waiting for a hero from the roster
	self.HeldHero = nil :: string? -- hero waiting for a slot (squad was full)
	self.Busy = false
	self.Sort = "Power" :: Sort
	self.AvailableOnly = false
	self.RosterCards = {} -- [uuid] = card entry (cached so portraits don't flash)

	-- Scrim
	self.Scrim = new("TextButton", {
		Name = "SquadDeployScrim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(6, 4, 10),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = Z - 2,
	}, screenGui)
	self.Scrim.Activated:Connect(function()
		if os.clock() - (self.OpenTime or 0) < 0.25 then return end
		self:Close()
	end)

	-- Window
	self.Root = new("TextButton", {
		Name = "SquadDeployModal",
		Text = "",
		AutoButtonColor = false,
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = Z - 1,
	}, screenGui)
	self.Root.Activated:Connect(function() end)
	GothicBoxStyle.Apply(self.Root, { Style = "Window" })
	self.Scale = new("UIScale", {}, self.Root)
	local function updateScale()
		local cam = workspace.CurrentCamera
		if cam then
			local vp = cam.ViewportSize
			self.Scale.Scale = math.clamp(math.min((vp.X - 24) / WIDTH, (vp.Y - 24) / HEIGHT), 0.5, 1)
		end
	end
	local camConn: RBXScriptConnection? = nil
	local function bindCamera()
		if camConn then camConn:Disconnect() end
		local cam = workspace.CurrentCamera
		if cam then
			camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
		end
		updateScale()
	end
	bindCamera()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
	GothicBoxStyle.CreateCloseButton(self.Root, function() self:Close() end)

	-- Header: icon, title, subtitle and the Squad Power badge
	local icon = GrimoireIcons.Create("Squad", 52, self.Root, Z + 2)
	icon.Position = UDim2.fromOffset(22, 12)
	local title = label(self.Root, "Title", {
		Position = UDim2.fromOffset(84, 14), Size = UDim2.fromOffset(420, 32),
		TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Text = "SQUAD DEPLOY", TextColor3 = Color3.new(1, 1, 1), ZIndex = Z + 2,
	})
	gold(title)
	label(self.Root, "Body", {
		Position = UDim2.fromOffset(84, 46), Size = UDim2.fromOffset(460, 18),
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT.Muted, ZIndex = Z + 2,
		Text = "Choose who fights in the tower. Benched and resting heroes recover stamina.",
	})
	local badge = new("Frame", {
		Name = "PowerBadge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -70, 0, 16),
		Size = UDim2.fromOffset(220, 46), BorderSizePixel = 0, ZIndex = Z + 2,
	}, self.Root)
	GildedGrimoire.Frame(badge, { Class = "Row", Tone = "Crimson", ZIndex = Z + 2 })
	local powerIcon = GrimoireIcons.Create("Power", 38, badge, Z + 3)
	powerIcon.Position = UDim2.fromOffset(6, 4)
	label(badge, "Body", {
		Position = UDim2.fromOffset(50, 4), Size = UDim2.new(1, -58, 0, 14), TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT.Gold, Text = "SQUAD POWER", ZIndex = Z + 4,
	})
	self.PowerLabel = label(badge, "Number", {
		Position = UDim2.fromOffset(50, 18), Size = UDim2.new(1, -58, 0, 24), TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1), Text = "0", ZIndex = Z + 4,
	})

	-- Active squad panel
	local squadPanel = new("Frame", {
		Name = "SquadPanel", Position = UDim2.fromOffset(20, 76), Size = UDim2.new(1, -40, 0, 268),
		BorderSizePixel = 0, ZIndex = Z,
	}, self.Root)
	GildedGrimoire.Frame(squadPanel, { Class = "Panel", Tone = "Deep", ZIndex = Z })
	self.SquadHeader = label(squadPanel, "Title", {
		Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(260, 22), TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "ACTIVE SQUAD", ZIndex = Z + 2,
	})
	gold(self.SquadHeader)
	self.SquadHint = label(squadPanel, "Body", {
		Position = UDim2.fromOffset(280, 12), Size = UDim2.new(1, -300, 0, 20), TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = TEXT.Muted, ZIndex = Z + 2, Text = "",
	})
	local slotRow = new("Frame", {
		Name = "SlotRow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.fromOffset(SQUAD_SLOTS * SLOT_W + (SQUAD_SLOTS - 1) * SLOT_GAP, SLOT_H),
		BackgroundTransparency = 1, ZIndex = Z + 1,
	}, squadPanel)

	self.SlotCards = {}
	for i = 1, SQUAD_SLOTS do
		self.SlotCards[i] = self:BuildSlot(slotRow, i)
	end

	-- Roster panel
	local rosterPanel = new("Frame", {
		Name = "RosterPanel", Position = UDim2.fromOffset(20, 354), Size = UDim2.new(1, -40, 0, 250),
		BorderSizePixel = 0, ZIndex = Z,
	}, self.Root)
	GildedGrimoire.Frame(rosterPanel, { Class = "Panel", Tone = "Deep", ZIndex = Z })
	self.RosterHeader = label(rosterPanel, "Title", {
		Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(470, 22), TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "HEROES", ZIndex = Z + 2,
	})
	gold(self.RosterHeader)

	-- Sort and filter chips
	local controls = new("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(430, 28),
		BackgroundTransparency = 1, ZIndex = Z + 2,
	}, rosterPanel)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center,
	}, controls)
	self.SortButtons = {}
	for order, key in { "Power", "Stars", "Level" } do
		local b, l = button(controls, "Slate", string.upper(key), { LayoutOrder = order, Size = UDim2.fromOffset(78, 28), ZIndex = Z + 3 })
		b.Activated:Connect(function()
			self.Sort = key :: Sort
			self:Refresh()
		end)
		self.SortButtons[key] = { Button = b, Label = l }
	end
	local fb, fl = button(controls, "Slate", "READY ONLY", { LayoutOrder = 4, Size = UDim2.fromOffset(120, 28), ZIndex = Z + 3 })
	fb.Activated:Connect(function()
		self.AvailableOnly = not self.AvailableOnly
		self:Refresh()
	end)
	self.FilterButton = { Button = fb, Label = fl }

	self.RosterScroll = new("ScrollingFrame", {
		Name = "RosterScroll", Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 1, -50),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110), ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = Z + 2,
	}, rosterPanel)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 18), PaddingBottom = UDim.new(0, 8) }, self.RosterScroll)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H), CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.RosterScroll)
	self.EmptyLabel = label(rosterPanel, "Body", {
		Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -48), TextSize = 15, TextColor3 = TEXT.Muted,
		Text = "No heroes yet. Summon heroes at the Summoning Altar!", Visible = false, ZIndex = Z + 3,
	})

	-- Footer: status line, auto-fill and done
	self.Status = label(self.Root, "Body", {
		Position = UDim2.fromOffset(28, 618), Size = UDim2.new(1, -420, 0, 36), TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = TEXT.Muted, ZIndex = Z + 2, Text = "",
	})
	local auto = button(self.Root, "Teal", "AUTO USE BEST", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -184, 0, 616), Size = UDim2.fromOffset(196, 40), ZIndex = Z + 2,
	})
	auto.Activated:Connect(function()
		self:Assign("AUTO_BEST", "", "Your strongest ready heroes are deployed.")
	end)
	local done = button(self.Root, "Action", "DONE", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 616), Size = UDim2.fromOffset(148, 40), ZIndex = Z + 2,
	})
	done.Activated:Connect(function() self:Close() end)

	return self
end

-- One slot card: tag, portrait, name, rarity, power, status and its buttons.
function SquadController.BuildSlot(self: any, parent: Instance, i: number): any
	local card = new("TextButton", {
		Name = "Slot_" .. i, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		Position = UDim2.fromOffset((i - 1) * (SLOT_W + SLOT_GAP), 0), Size = UDim2.fromOffset(SLOT_W, SLOT_H), ZIndex = Z + 2,
	}, parent)
	GildedGrimoire.Frame(card, { Class = "Card", Tone = "Violet", ZIndex = Z + 2 })
	local rail = GildedGrimoire.StateStroke(card) :: UIStroke

	local _, tagLabel = chip(card, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(74, 20) })
	tagLabel.Text = "SLOT " .. i

	local portrait = new("Frame", {
		Name = "PortraitHost", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Color3.fromRGB(14, 10, 22), ClipsDescendants = true, ZIndex = Z + 3,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, portrait)
	local ring = new("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, portrait)

	local archHolder = new("Frame", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, 50, 0, 106), Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1, ZIndex = Z + 6,
	}, card)

	local name = label(card, "Title", {
		Position = UDim2.fromOffset(6, 104), Size = UDim2.new(1, -12, 0, 20), TextScaled = true, Text = "", ZIndex = Z + 4,
	})
	new("UITextSizeConstraint", { MaxTextSize = 16 }, name)
	local info = label(card, "Body", {
		Position = UDim2.fromOffset(6, 124), Size = UDim2.new(1, -12, 0, 16), TextSize = 12, Text = "", ZIndex = Z + 4,
	})
	local power = label(card, "Number", {
		Position = UDim2.fromOffset(6, 140), Size = UDim2.new(1, -12, 0, 18), TextSize = 15, TextColor3 = TEXT.Gold, Text = "", ZIndex = Z + 4,
	})

	-- Two buttons: main (CHANGE / ASSIGN / REPLACE / UNLOCK / CANCEL) and REMOVE.
	local main, mainLabel = button(card, "Action", "CHANGE", {
		Position = UDim2.fromOffset(8, 166), Size = UDim2.new(1, -16, 0, 36), ZIndex = Z + 4,
	})
	local remove, removeLabel = button(card, "Slate", "REMOVE", {
		Position = UDim2.new(0.55, 2, 0, 166), Size = UDim2.new(0.45, -10, 0, 36), ZIndex = Z + 4,
	})
	removeLabel.TextSize = 12

	local entry = {
		Card = card, Rail = rail, Portrait = portrait, Ring = ring, Arch = archHolder,
		Name = name, Info = info, Power = power,
		Main = main, MainLabel = mainLabel, Remove = remove,
		HeroUUID = nil :: string?, Rendered = "__UNSET__", ArchRendered = "",
	}

	local function pressMain()
		self:PressSlot(i)
	end
	card.Activated:Connect(pressMain)
	main.Activated:Connect(pressMain)
	remove.Activated:Connect(function()
		if entry.HeroUUID then
			self:Assign(entry.HeroUUID, "BENCHED", "Benched.")
		end
	end)
	return entry
end

-- Slot pressed: unlock, cancel, place the held hero, or start choosing a hero for it.
function SquadController.PressSlot(self: any, i: number)
	if self.Busy then return end
	local profile = self.GetProfile()
	if i > openSlots(profile) then
		self:Close()
		if _G.OpenFacilityHUD then _G.OpenFacilityHUD("FortressTree") end
		return
	end
	if not (profile and profile.Unlocks and profile.Unlocks.Squad) then
		self:SetStatus("Summon your first hero to change your squad.", true)
		return
	end
	if self.HeldHero then
		local uuid = self.HeldHero
		self.HeldHero = nil
		self:Assign(uuid, "SQUAD_SLOT_" .. i, "Deployed to Slot " .. i .. ".")
		return
	end
	if self.ChoosingSlot == i then
		self.ChoosingSlot = nil
		self:SetStatus("")
	elseif self.ChoosingSlot ~= nil then
		local bySlot: { [number]: any } = {}
		for _, h in pairs(profile.Heroes) do
			local s = slotOf(h)
			if s and s <= SQUAD_SLOTS then bySlot[s] = h end
		end
		local sourceHero = bySlot[self.ChoosingSlot]
		if sourceHero then
			local fromSlot = self.ChoosingSlot
			self.ChoosingSlot = nil
			local actionWord = if bySlot[i] then "Swapped" else "Moved"
			self:Assign(sourceHero.UUID, "SQUAD_SLOT_" .. i, string.format("%s Slot %d and Slot %d.", actionWord, fromSlot, i))
			return
		else
			self.ChoosingSlot = i
			self:SetStatus("Choose a hero below for Slot " .. i .. ".")
		end
	else
		self.ChoosingSlot = i
		self:SetStatus("Choose a hero below for Slot " .. i .. ".")
	end
	self:Refresh()
end

-- Kept for callers of the old API: selecting a slot starts choosing for it.
function SquadController.SelectSlot(self: any, slotIdx: number)
	self.ChoosingSlot = slotIdx
	self:Refresh()
end

-- Roster hero pressed.
function SquadController.PressHero(self: any, uuid: string)
	if self.Busy then return end
	local profile = self.GetProfile()
	local hero = profile and profile.Heroes and profile.Heroes[uuid]
	if not hero then return end
	if not (profile.Unlocks and profile.Unlocks.Squad) then
		self:SetStatus("Summon your first hero to change your squad.", true)
		return
	end
	if self.HeldHero == uuid then
		self.HeldHero = nil
		self:SetStatus("")
		self:Refresh()
		return
	end
	local resting = restingSeconds(hero)
	if resting > 0 then
		self:SetStatus(string.format("%s is resting for %ds and can't fight yet.", hero.DisplayName, resting), true)
		return
	end
	local current = slotOf(hero)
	if self.ChoosingSlot then
		local target = self.ChoosingSlot
		self.ChoosingSlot = nil
		if current == target then
			self:SetStatus(hero.DisplayName .. " is already in Slot " .. target .. ".")
			self:Refresh()
			return
		end
		self:Assign(uuid, "SQUAD_SLOT_" .. target, string.format("%s deployed to Slot %d.", hero.DisplayName, target))
		return
	end
	if current then
		self:SetStatus(string.format("%s is in Slot %d. Use CHANGE on a slot to swap, or REMOVE to bench.", hero.DisplayName, current))
		return
	end
	-- Not choosing: fill the first empty slot, or hold the hero until a slot is picked.
	local open = openSlots(profile)
	local taken: { [number]: boolean } = {}
	for _, h in pairs(profile.Heroes) do
		local s = slotOf(h)
		if s then taken[s] = true end
	end
	for s = 1, open do
		if not taken[s] then
			self:Assign(uuid, "SQUAD_SLOT_" .. s, string.format("%s deployed to Slot %d.", hero.DisplayName, s))
			return
		end
	end
	self.HeldHero = uuid
	self:SetStatus(string.format("Squad is full. Press REPLACE on the slot %s should take.", hero.DisplayName))
	self:Refresh()
end

function SquadController.SetStatus(self: any, text: string, isError: boolean?)
	self.Status.Text = text
	self.Status.TextColor3 = if isError then TEXT.Bad else TEXT.Muted
end

-- Sends one assignment to the server and shows its answer.
function SquadController.Assign(self: any, uuid: string, target: string, successText: string)
	if self.Busy then return end
	self.Busy = true
	self.ChoosingSlot = nil
	self.HeldHero = nil
	self:SetStatus("Saving…")
	task.spawn(function()
		local ok, okFlag, message = pcall(function()
			return self.AssignRemote:InvokeServer(uuid, target)
		end)
		self.Busy = false
		if not ok then
			self:SetStatus("Couldn't reach the server. Try again.", true)
		elseif okFlag then
			self:SetStatus(successText)
		else
			self:SetStatus(tostring(message or "That change was refused."), true)
		end
		self:Refresh()
	end)
end

function SquadController.Open(self: any)
	self.OpenTime = os.clock()
	self.ChoosingSlot = nil
	self.HeldHero = nil
	self:SetStatus("Press CHANGE on a slot, then pick a hero. Or click a hero to fill the next empty slot.")
	self.Scrim.Visible = true
	self.Root.Visible = true
	self:Refresh()
	self.Scale.Scale = self.Scale.Scale * 0.94
	self.Scrim.BackgroundTransparency = 1
	TweenService:Create(self.Scrim, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.45 }):Play()
	local cam = workspace.CurrentCamera
	local target = 1
	if cam then
		target = math.clamp(math.min((cam.ViewportSize.X - 24) / WIDTH, (cam.ViewportSize.Y - 24) / HEIGHT), 0.5, 1)
	end
	TweenService:Create(self.Scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
end

function SquadController.Close(self: any)
	if not self.Root.Visible then return end
	self.ChoosingSlot = nil
	self.HeldHero = nil
	local tw = TweenService:Create(self.Scrim, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
	tw:Play()
	self.Root.Visible = false
	tw.Completed:Connect(function()
		self.Scrim.Visible = false
		if self.OnClose then self.OnClose() end
	end)
end

function SquadController.IsOpen(self: any): boolean
	return self.Root ~= nil and self.Root.Visible == true
end

function SquadController.Toggle(self: any)
	if self:IsOpen() then self:Close() else self:Open() end
end

-- Hero power with the same Training Grounds multiplier the server used for the squad.
local function powerOf(profile: any, hero: any, mult: number): number
	local known = profile.SquadPowerByHero and profile.SquadPowerByHero[hero.UUID]
	if known then return known end
	return StatFormulas.GetHeroPower(hero, StatFormulas.GetEquippedArtifact(profile, hero), mult)
end

local function setArchetype(holder: Frame, rendered: string, archetype: string?): string
	local key = archetype or ""
	if key == rendered then return rendered end
	holder:ClearAllChildren()
	if archetype then
		GrimoireIcons.Create(archetype, 28, holder, holder.ZIndex)
	end
	return key
end

function SquadController.Refresh(self: any)
	if not self.Root.Visible then return end
	local profile = self.GetProfile()
	if not profile or not profile.Heroes then
		self.EmptyLabel.Visible = true
		self.EmptyLabel.Text = "Loading heroes…"
		return
	end

	-- Training multiplier as the server applied it (ratio of reported to base power).
	local mult = 1
	for uuid, reported in pairs(profile.SquadPowerByHero or {}) do
		local h = profile.Heroes[uuid]
		local base = h and StatFormulas.GetHeroPower(h, StatFormulas.GetEquippedArtifact(profile, h))
		if base and base > 0 then mult = reported / base break end
	end

	local open = openSlots(profile)
	local unlocked = profile.Unlocks and profile.Unlocks.Squad
	local bySlot: { [number]: any } = {}
	local deployed = 0
	for _, h in pairs(profile.Heroes) do
		local s = slotOf(h)
		if s and s <= SQUAD_SLOTS then bySlot[s] = h; deployed += 1 end
	end
	if self.ChoosingSlot and self.ChoosingSlot > open then self.ChoosingSlot = nil end

	self.PowerLabel.Text = abbreviate(profile.SquadPower or 0)
	self.SquadHeader.Text = string.format("ACTIVE SQUAD  %d/%d", deployed, open)
	self.SquadHint.Text = if not unlocked then "Summon your first hero to change your squad."
		elseif self.ChoosingSlot then string.format("Choosing a hero for Slot %d…", self.ChoosingSlot)
		elseif self.HeldHero then "Press REPLACE on a slot."
		else if open < SQUAD_SLOTS then string.format("Slots %d–%d open in Upgrades.", open + 1, SQUAD_SLOTS) else ""

	-- Slots
	for i = 1, SQUAD_SLOTS do
		local e = self.SlotCards[i]
		local locked = i > open
		local hero = if locked then nil else bySlot[i]
		e.HeroUUID = hero and hero.UUID or nil
		local key = if locked then "__LOCKED__" elseif hero then hero.UUID else "__EMPTY__"
		if e.Rendered ~= key then
			e.Rendered = key
			for _, c in e.Portrait:GetChildren() do
				if c:IsA("GuiObject") then c:Destroy() end
			end
			if locked then
				local lock = GrimoireIcons.Create("Lock", 46, e.Portrait, Z + 4)
				lock.AnchorPoint = Vector2.new(0.5, 0.5)
				lock.Position = UDim2.fromScale(0.5, 0.5)
			elseif hero then
				HeroCard.Portrait(e.Portrait, hero)
			else
				local plus = label(e.Portrait, "Title", { Size = UDim2.fromScale(1, 1), TextSize = 40, TextColor3 = TEXT.Muted, Text = "+", ZIndex = Z + 4 })
				plus.Name = "Plus"
			end
		end
		e.ArchRendered = setArchetype(e.Arch, e.ArchRendered, hero and hero.Archetype)

		local choosing = self.ChoosingSlot == i
		local rarity = hero and StatFormulas.GetHeroRarity(hero) or 1
		e.Ring.Color = if hero then Theme.RarityColor(rarity) else INK
		e.Remove.Visible = false
		e.Main.Size = UDim2.new(1, -16, 0, 36)
		if locked then
			e.Name.Text = "LOCKED"
			e.Info.Text = "Open in Upgrades"
			e.Power.Text = ""
			retone(e.Main, e.MainLabel, "Bronze", "UNLOCK")
			e.Rail.Color = Color3.fromRGB(140, 130, 160)
		elseif self.HeldHero then
			e.Name.Text = if hero then hero.DisplayName else "Empty"
			e.Info.Text = if hero then string.format("%s · Lv.%d", string.rep("★", hero.Stars or 1), hero.Level or 1) else "Free slot"
			e.Power.Text = if hero then abbreviate(powerOf(profile, hero, mult)) .. " PWR" else ""
			retone(e.Main, e.MainLabel, "Gold", if hero then "REPLACE" else "PLACE HERE")
			e.Rail.Color = TEXT.Gold
		elseif self.ChoosingSlot ~= nil then
			if choosing then
				e.Name.Text = if hero then hero.DisplayName else "Empty"
				e.Info.Text = if hero then string.format("%s · Lv.%d", string.rep("★", hero.Stars or 1), hero.Level or 1) else "Free slot"
				e.Power.Text = if hero then abbreviate(powerOf(profile, hero, mult)) .. " PWR" else ""
				retone(e.Main, e.MainLabel, "Slate", "CANCEL")
				e.Rail.Color = TEXT.Gold
			else
				local sourceHero = bySlot[self.ChoosingSlot]
				if sourceHero then
					e.Name.Text = if hero then hero.DisplayName else "Empty"
					e.Info.Text = if hero then string.format("%s · Lv.%d", string.rep("★", hero.Stars or 1), hero.Level or 1) else "Free slot"
					e.Power.Text = if hero then abbreviate(powerOf(profile, hero, mult)) .. " PWR" else ""
					retone(e.Main, e.MainLabel, "Teal", if hero then "SWAP" else "MOVE HERE")
					e.Rail.Color = Color3.fromRGB(120, 200, 220)
				else
					e.Name.Text = if hero then hero.DisplayName else "Empty"
					e.Info.Text = if hero then string.format("%s · Lv.%d", string.rep("★", hero.Stars or 1), hero.Level or 1) else "Free slot"
					e.Power.Text = if hero then abbreviate(powerOf(profile, hero, mult)) .. " PWR" else ""
					retone(e.Main, e.MainLabel, "Action", if hero then "CHANGE" else "ASSIGN")
					e.Rail.Color = Color3.fromRGB(150, 138, 176)
				end
			end
		elseif hero then
			local resting = restingSeconds(hero)
			e.Name.Text = hero.DisplayName
			e.Info.Text = if resting > 0 then string.format("<font color=\"#FF6B6B\">Resting %ds</font>", resting)
				else string.format("%s · %s · Lv.%d", HeroCatalog.RarityName(rarity), string.rep("★", hero.Stars or 1), hero.Level or 1)
			e.Power.Text = abbreviate(powerOf(profile, hero, mult)) .. " PWR"
			-- CHANGE and REMOVE side by side.
			e.Main.Size = UDim2.new(0.55, -10, 0, 36)
			retone(e.Main, e.MainLabel, "Action", "CHANGE")
			e.Remove.Visible = unlocked == true
			e.Rail.Color = Color3.fromRGB(240, 196, 110)
		else
			e.Name.Text = "Empty"
			e.Info.Text = "Free slot"
			e.Power.Text = ""
			retone(e.Main, e.MainLabel, "Gold", "ASSIGN")
			e.Rail.Color = Color3.fromRGB(150, 138, 176)
		end
		e.Rail.Thickness = if choosing or self.HeldHero then 3 else 1.4
		e.Rail.Transparency = if choosing then 0 else 0.3
	end

	-- Sort / filter chips
	for key, b in self.SortButtons do
		retone(b.Button, b.Label, if self.Sort == key then "Gold" else "Slate", string.upper(key))
	end
	retone(self.FilterButton.Button, self.FilterButton.Label, if self.AvailableOnly then "Gold" else "Slate", "READY ONLY")

	-- Roster (active squad heroes are excluded; they are displayed and managed in ACTIVE SQUAD above)
	local list = {}
	local power: { [string]: number } = {}
	for _, h in pairs(profile.Heroes) do
		if slotOf(h) then
			continue
		end
		power[h.UUID] = powerOf(profile, h, mult)
		if not self.AvailableOnly or restingSeconds(h) == 0 then
			table.insert(list, h)
		end
	end
	table.sort(list, function(a, b)
		local ka = if self.Sort == "Stars" then (a.Stars or 1) elseif self.Sort == "Level" then (a.Level or 1) else power[a.UUID]
		local kb = if self.Sort == "Stars" then (b.Stars or 1) elseif self.Sort == "Level" then (b.Level or 1) else power[b.UUID]
		if ka ~= kb then return ka > kb end
		return (a.DisplayName or "") < (b.DisplayName or "")
	end)

	self.RosterHeader.Text = if self.ChoosingSlot then string.format("CHOOSE A HERO FOR SLOT %d", self.ChoosingSlot)
		else string.format("HEROES  (%d)", #list)
	self.EmptyLabel.Visible = #list == 0
	self.EmptyLabel.Text = if self.AvailableOnly then "Every ready hero is already deployed."
		elseif deployed > 0 then "All heroes are currently deployed in the active squad."
		else "No heroes yet. Summon heroes at the Summoning Altar!"

	local seen: { [string]: boolean } = {}
	for order, hero in ipairs(list) do
		seen[hero.UUID] = true
		local entry = self.RosterCards[hero.UUID] or self:BuildRosterCard(hero)
		self.RosterCards[hero.UUID] = entry
		entry.Card.LayoutOrder = order
		entry.Card.Visible = true

		local resting = restingSeconds(hero)
		local rarity = StatFormulas.GetHeroRarity(hero)
		entry.Name.Text = hero.DisplayName
		entry.Info.Text = string.format("%s · Lv.%d", string.rep("★", hero.Stars or 1), hero.Level or 1)
		entry.Info.TextColor3 = Theme.RarityColor(rarity)
		entry.Power.Text = abbreviate(power[hero.UUID]) .. " PWR"
		entry.Ring.Color = Theme.RarityColor(rarity)
		entry.ArchRendered = setArchetype(entry.Arch, entry.ArchRendered, hero.Archetype)

		local chipText, chipColor = "", TEXT.Parchment
		if resting > 0 then
			chipText, chipColor = string.format("RESTING %ds", resting), TEXT.Bad
		elseif FACILITY_LABELS[hero.Assignment or ""] then
			chipText, chipColor = string.upper(FACILITY_LABELS[hero.Assignment]), Color3.fromRGB(150, 236, 255)
		end
		entry.Chip.Visible = chipText ~= ""
		entry.ChipLabel.Text = chipText
		entry.ChipLabel.TextColor3 = chipColor

		-- Highlight: the held hero, and who can fill the slot being chosen.
		local selectable = resting == 0
		entry.Shade.Visible = (self.ChoosingSlot ~= nil and not selectable) or resting > 0
		entry.Rail.Color = if self.HeldHero == hero.UUID then TEXT.Gold
			elseif self.ChoosingSlot and selectable then Color3.fromRGB(255, 226, 140)
			else Color3.fromRGB(200, 160, 96)
		entry.Rail.Thickness = if self.HeldHero == hero.UUID or (self.ChoosingSlot and selectable) then 2.6 else 1.4
	end
	for uuid, entry in pairs(self.RosterCards) do
		if not seen[uuid] then
			if profile.Heroes[uuid] then
				entry.Card.Visible = false -- filtered out
			else
				entry.Card:Destroy() -- consumed or sold
				self.RosterCards[uuid] = nil
			end
		end
	end
end

function SquadController.BuildRosterCard(self: any, hero: any): any
	local uuid = hero.UUID
	local card = new("TextButton", {
		Name = "Hero_" .. uuid, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = Z + 3,
	}, self.RosterScroll)
	GildedGrimoire.Frame(card, { Class = "Card", Tone = "Violet", ZIndex = Z + 3 })
	local rail = GildedGrimoire.StateStroke(card) :: UIStroke

	local portrait = new("Frame", {
		Name = "PortraitHost", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Color3.fromRGB(14, 10, 22), ClipsDescendants = true, ZIndex = Z + 4,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, portrait)
	local ring = new("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, portrait)
	HeroCard.Portrait(portrait, hero)

	local arch = new("Frame", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, 50, 0, 98), Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1, ZIndex = Z + 7,
	}, card)
	local chipFrame, chipLabel = chip(card, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(84, 18), Visible = false,
	})
	local name = label(card, "Title", {
		Position = UDim2.fromOffset(4, 102), Size = UDim2.new(1, -8, 0, 18), TextScaled = true, Text = "", ZIndex = Z + 5,
	})
	new("UITextSizeConstraint", { MaxTextSize = 14 }, name)
	local info = label(card, "Body", {
		Position = UDim2.fromOffset(4, 122), Size = UDim2.new(1, -8, 0, 16), TextSize = 12, Text = "", ZIndex = Z + 5,
	})
	local power = label(card, "Number", {
		Position = UDim2.fromOffset(4, 140), Size = UDim2.new(1, -8, 0, 18), TextSize = 14, TextColor3 = TEXT.Gold, Text = "", ZIndex = Z + 5,
	})
	-- Dims heroes that can't take the slot being chosen (or are resting).
	local shade = new("Frame", {
		Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 4, 10), BackgroundTransparency = 0.45,
		BorderSizePixel = 0, Visible = false, ZIndex = Z + 9,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, shade)

	local scale = new("UIScale", {}, card)
	card.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play() end)
	card.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	card.Activated:Connect(function() self:PressHero(uuid) end)

	return {
		Card = card, Rail = rail, Ring = ring, Arch = arch, ArchRendered = "",
		Chip = chipFrame, ChipLabel = chipLabel, Name = name, Info = info, Power = power, Shade = shade,
	}
end

return SquadController
