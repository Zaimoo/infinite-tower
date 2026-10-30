--!strict
-- StarterPlayerScripts/UI/SynthesisController.luau
-- Focused Synthesis HUD opened from the Synthesis chamber's [F] prompt.
-- Layout:
--   * Top: Recipient hero card, name, level preview, live animated XP bar.
--   * Center: Heroes roster panel (Image 2 style) with sorting (Power/Stars/Level),
--     "READY ONLY" filter, and cards displaying power, archetype, stars, and facility chips.
--   * Multi-select materials with no 5-hero limit.
--   * Deployed, facility-assigned, equipped, locked, coma, and recipient heroes are protected.
-- Authoritative PitRequest remote: STATE -> PREVIEW -> COMMIT.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local Theme = require(script.Parent:WaitForChild("Hud"):WaitForChild("Theme"))
local GothicBoxStyle = require(Shared:WaitForChild("Util"):WaitForChild("GothicBoxStyle"))
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local PitBalanceConfig = require(Shared:WaitForChild("Config"):WaitForChild("PitBalanceConfig"))

local Synth = {}
Synth.__index = Synth

local WIDTH, HEIGHT = 980, 668
local CARD_W, CARD_H = 138, 176
local Z = 40
local INK = GildedGrimoire.Ink
local TEXT = GildedGrimoire.Text

local C = {
	Scrim = Color3.fromRGB(6, 4, 10),
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

local FACILITY_LABELS: { [string]: string } = {
	FACILITY_GUARD_POST = "Guard Post",
	FACILITY_MARKET = "Market",
	FACILITY_TRAINING = "Training",
	FACILITY_GODS_BLESSING = "Blessing",
}

type Sort = "Power" | "Stars" | "Level"

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

local function gold(l: TextLabel)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), TEXT.Gold) }, l)
end

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

local function retone(b: TextButton, l: TextLabel, tone: string, text: string)
	local t = GildedGrimoire.Tones[tone]
	if not t then return end
	local fill = b:FindFirstChild("GrimoireFill") :: UIGradient?
	if fill then fill.Color = ColorSequence.new(t.Top, t.Bottom) end
	local rail = GildedGrimoire.StateStroke(b)
	if rail then rail.Color = t.Rail end
	l.Text = text
	l.TextColor3 = Color3.new(1, 1, 1)
end

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

local function abbreviate(n: number): string
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= unit[1] then
			return (string.gsub(string.format("%.1f%s", n / unit[1], unit[2]), "%.0(%a)$", "%1"))
		end
	end
	return tostring(math.round(n))
end

local function powerOf(profile: any, hero: any, mult: number): number
	local known = profile and profile.SquadPowerByHero and profile.SquadPowerByHero[hero.UUID]
	if known then return known end
	return StatFormulas.GetHeroPower(hero, StatFormulas.GetEquippedArtifact(profile, hero), mult)
end

local function setArchetype(holder: Frame, rendered: string, archetype: string?): string
	local key = archetype or ""
	if key == rendered then return rendered end
	holder:ClearAllChildren()
	if archetype then
		GrimoireIcons.Create(archetype, 26, holder, holder.ZIndex)
	end
	return key
end

local function stars(n: number?): string
	return string.rep("★", math.clamp(n or 1, 1, 5))
end

local function xpRatio(level: number?, xp: number?): number
	return math.clamp((xp or 0) / StatFormulas.GetXPRequiredForNextLevel(level or 1), 0, 1)
end

local function restingSeconds(hero: any): number
	return math.max(0, (hero.ComaUntilTimestamp or 0) - os.time())
end

local function checkDonorEligibility(hero: any, recipientUUID: string?): (boolean, string, string)
	local uuid = hero and hero.UUID
	if not hero or not uuid then
		return false, "Invalid hero.", "Unavailable"
	end
	if recipientUUID and uuid == recipientUUID then
		return false, "A hero cannot be its own material.", "Recipient"
	end

	local profile: any = _G.CurrentProfile
	local profileHero = profile and profile.Heroes and profile.Heroes[uuid]
	local effectiveHero = profileHero or hero

	-- 1. Artifact equipment check
	if (effectiveHero.EquippedArtifactUUID and effectiveHero.EquippedArtifactUUID ~= "")
		or (hero.EquippedArtifactUUID and hero.EquippedArtifactUUID ~= "") then
		return false, "This hero has an artifact equipped. Unequip it before using as material.", "Equipped"
	end

	-- 2. Squad deployment check
	local assignment = effectiveHero.Assignment or hero.Assignment or ""
	if string.find(assignment, "^SQUAD") then
		return false, "This hero is deployed in your squad. Bench it before using as material.", "Deployed"
	end
	if profile and profile.DeployedSquadOrder and table.find(profile.DeployedSquadOrder, uuid) then
		return false, "This hero is deployed in your squad. Bench it before using as material.", "Deployed"
	end
	if effectiveHero.InCombat or effectiveHero.IsInCombat or effectiveHero.ActiveCombat
		or hero.InCombat or hero.IsInCombat or hero.ActiveCombat then
		return false, "This hero is currently deployed in combat.", "Deployed"
	end

	-- 3. Building / facility check
	if string.find(assignment, "^FACILITY") then
		return false, "This hero is stationed in a building. Unassign it before using as material.", "Stationed"
	end
	if profile and profile.Facilities then
		for _, facility in pairs(profile.Facilities) do
			if facility.AssignedHeroUUIDs and table.find(facility.AssignedHeroUUIDs, uuid) then
				return false, "This hero is stationed in a building. Unassign it before using as material.", "Stationed"
			end
		end
	end

	-- 4. Any other non-benched assignment
	if assignment ~= "" and assignment ~= "BENCHED" then
		return false, "This hero is currently assigned (" .. assignment .. "). Bench it first.", "Assigned"
	end

	-- 5. Locked / Favorited
	if effectiveHero.Locked or effectiveHero.Favorite or effectiveHero.Favorited
		or hero.Locked or hero.Favorite or hero.Favorited then
		return false, "This hero is protected. Unlock it deliberately before using it.", "Locked"
	end

	-- 6. Coma / Recovering
	local coma = math.max(effectiveHero.ComaUntilTimestamp or 0, hero.ComaUntilTimestamp or 0)
	if coma > os.time() or effectiveHero.IsHardAuditComa or hero.IsHardAuditComa then
		return false, "This hero must recover from Coma first.", "Recovering"
	end

	-- 7. Unique / Protected
	if effectiveHero.Unique or effectiveHero.IsUnique or effectiveHero.Protected
		or hero.Unique or hero.IsUnique or hero.Protected
		or effectiveHero.TemplateId == "hero_archon" or hero.TemplateId == "hero_archon" then
		return false, "This unique hero is protected from consumption.", "Protected"
	end

	-- 8. Authoritative PitStatus check from server
	if hero.PitStatus and hero.PitStatus.EligibleDonor == false then
		local st = hero.PitStatus.Status or "Unavailable"
		if st == "Facility Worker" then st = "Stationed" end
		return false, hero.PitStatus.Reason or "This hero cannot be used as material.", st
	end

	return true, "", "Ready"
end

--============================================================================
-- CONSTRUCTION
--============================================================================

function Synth.new(gui: ScreenGui, remote: RemoteFunction)
	local self: any = setmetatable({}, Synth)
	self.Remote = remote
	self.State = { Heroes = {} }
	self.Recipient = nil :: string?
	self.Donors = {} :: { string }
	self.Preview = nil
	self.Busy = false
	self.ArmedRare = false
	self.PreviewSerial = 0
	self.Message = ""
	self.Tweens = {}
	self.Sort = "Power" :: Sort
	self.ReadyOnly = false
	self.RosterCards = {}

	self.Scrim = new("TextButton", {
		Name = "SynthesisScrim", Text = "", AutoButtonColor = false, BackgroundColor3 = C.Scrim,
		BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = Z - 2,
	}, gui)

	local root = new("TextButton", {
		Name = "SynthesisModal", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIDTH, HEIGHT), BackgroundColor3 = C.Panel, BorderSizePixel = 0,
		Text = "", AutoButtonColor = false,
		Visible = false, Active = true, ZIndex = Z - 1,
	}, gui)
	root.Activated:Connect(function() end)
	self.Root = root

	GildedGrimoire.Watch(root)
	GothicBoxStyle.Apply(root, { Style = "Window" })
	self.Scale = new("UIScale", {}, root)

	-- Header
	local icon = GrimoireIcons.Create("Summon", 46, root, Z + 2)
	icon.Position = UDim2.fromOffset(22, 10)
	local title = label(root, "Title", {
		Position = UDim2.fromOffset(76, 12), Size = UDim2.fromOffset(360, 28),
		TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Text = "SYNTHESIS", TextColor3 = Color3.new(1, 1, 1), ZIndex = Z + 2,
	})
	gold(title)
	label(root, "Body", {
		Position = UDim2.fromOffset(76, 40), Size = UDim2.fromOffset(460, 16),
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT.Muted, ZIndex = Z + 2,
		Text = "Feed duplicate and spare heroes to grant EXP and level up your heroes.",
	})

	GothicBoxStyle.CreateCloseButton(root, function() if not self.Busy then self:Close() end end)

	-- Top Recipient Hero Panel
	local recipientPanel = new("Frame", {
		Name = "RecipientPanel", Position = UDim2.fromOffset(20, 62), Size = UDim2.new(1, -40, 0, 126),
		BorderSizePixel = 0, ZIndex = Z,
	}, root)
	GildedGrimoire.Frame(recipientPanel, { Class = "Panel", Tone = "Deep", ZIndex = Z })
	self.RecipientPanel = recipientPanel

	-- Recipient Slot Card
	local recipCard = new("TextButton", {
		Name = "RecipientSlot", Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(88, 106), ZIndex = Z + 2,
	}, recipientPanel)
	GildedGrimoire.Frame(recipCard, { Class = "Card", Tone = "Violet", ZIndex = Z + 2 })
	local recipRail = GildedGrimoire.StateStroke(recipCard) :: UIStroke

	local recipPortrait = new("Frame", {
		Name = "PortraitHost", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(68, 68),
		BackgroundColor3 = Color3.fromRGB(14, 10, 22), ClipsDescendants = true, ZIndex = Z + 3,
	}, recipCard)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, recipPortrait)
	local recipRing = new("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, recipPortrait)

	local recipPlus = label(recipPortrait, "Title", {
		Size = UDim2.fromScale(1, 1), TextSize = 34, TextColor3 = TEXT.Muted, Text = "+", ZIndex = Z + 4,
	})

	local recipArch = new("Frame", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, 40, 0, 80), Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1, ZIndex = Z + 6,
	}, recipCard)

	local recipBtnLabel = label(recipCard, "Title", {
		Position = UDim2.fromOffset(4, 82), Size = UDim2.new(1, -8, 0, 18), TextSize = 11, TextColor3 = TEXT.Parchment, Text = "SELECT", ZIndex = Z + 4,
	})

	recipCard.Activated:Connect(function()
		if self.Busy then return end
		self:OpenPicker("RECIPIENT")
	end)

	self.RecipientSlot = {
		Card = recipCard, Rail = recipRail, Portrait = recipPortrait, Ring = recipRing,
		Plus = recipPlus, Arch = recipArch, ArchRendered = "", BtnLabel = recipBtnLabel,
		HeroUUID = nil :: string?, Rendered = "__UNSET__",
	}

	-- Recipient Details & Stats
	self.RecipientName = label(recipientPanel, "Title", {
		Position = UDim2.fromOffset(116, 12), Size = UDim2.fromOffset(400, 22),
		TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT.Parchment, Text = "No Recipient Selected", ZIndex = Z + 2,
	})
	gold(self.RecipientName)

	self.RecipientInfo = label(recipientPanel, "Body", {
		Position = UDim2.fromOffset(116, 36), Size = UDim2.fromOffset(400, 16),
		TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT.Muted, Text = "Tap slot to choose a hero to level up", ZIndex = Z + 2,
	})

	self.LevelLabel = label(recipientPanel, "Title", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 12), Size = UDim2.fromOffset(360, 22),
		TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = TEXT.Parchment, Text = "Lv. —", ZIndex = Z + 2,
	})

	-- Live XP Bar
	local bar = new("Frame", {
		Name = "XPBar", BackgroundColor3 = Color3.fromRGB(12, 10, 18), BorderSizePixel = 0, ClipsDescendants = true,
		Position = UDim2.fromOffset(116, 58), Size = UDim2.new(1, -134, 0, 18), ZIndex = Z + 2,
	}, recipientPanel)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, bar)
	new("UIStroke", { Color = INK, Thickness = 1.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, bar)

	self.GainFill = new("Frame", { Name = "Gain", BackgroundColor3 = C.Green, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = Z + 3 }, bar)
	self.CurrentFill = new("Frame", { Name = "Current", BackgroundColor3 = C.Blue, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = Z + 4 }, bar)
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(10, 110, 190), Color3.fromRGB(30, 150, 235)) }, self.CurrentFill)

	self.XPText = label(bar, "Body", {
		Position = UDim2.new(0, 0, 0, 0), Size = UDim2.fromScale(1, 1),
		TextSize = 11, TextColor3 = Color3.new(1, 1, 1), Text = "", ZIndex = Z + 5,
	})

	self.SummaryLine = label(recipientPanel, "Body", {
		Position = UDim2.fromOffset(116, 82), Size = UDim2.new(1, -134, 0, 36),
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT.Muted,
		Text = "Tap heroes below to select materials for EXP.", ZIndex = Z + 2,
	})

	-- Center Roster Panel (Image 2 style)
	local rosterPanel = new("Frame", {
		Name = "RosterPanel", Position = UDim2.fromOffset(20, 196), Size = UDim2.new(1, -40, 0, 400),
		BorderSizePixel = 0, ZIndex = Z,
	}, root)
	GildedGrimoire.Frame(rosterPanel, { Class = "Panel", Tone = "Deep", ZIndex = Z })
	self.RosterPanel = rosterPanel

	self.RosterHeader = label(rosterPanel, "Title", {
		Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(470, 24), TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left, Text = "HEROES", ZIndex = Z + 2,
	})
	gold(self.RosterHeader)

	-- Sort and filter chips (Power, Stars, Level, Ready Only)
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
			self:Render()
		end)
		self.SortButtons[key] = { Button = b, Label = l }
	end

	local fb, fl = button(controls, "Slate", "READY ONLY", { LayoutOrder = 4, Size = UDim2.fromOffset(120, 28), ZIndex = Z + 3 })
	fb.Activated:Connect(function()
		self.ReadyOnly = not self.ReadyOnly
		self:Render()
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
		Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 1, -68), TextSize = 15, TextColor3 = TEXT.Muted,
		Text = "No material heroes available.", Visible = false, ZIndex = Z + 3,
	})

	-- Footer: Status message, Clear selection, Confirm Synthesize button
	self.Status = label(root, "Body", {
		Position = UDim2.fromOffset(24, 608), Size = UDim2.new(1, -420, 0, 48), TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = TEXT.Muted, ZIndex = Z + 2, Text = "",
	})

	local clearBtn, clearLabel = button(root, "Slate", "CLEAR", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -236, 0, 608), Size = UDim2.fromOffset(130, 44), ZIndex = Z + 2,
	})
	clearBtn.Activated:Connect(function()
		if self.Busy then return end
		if #self.Donors > 0 then
			self.Donors = {}
			self.Message = ""
			self.ArmedRare = false
			self:Render()
			self:QueuePreview()
		end
	end)
	self.ClearButton = { Button = clearBtn, Label = clearLabel }

	local confirmBtn, confirmLabel = button(root, "Action", "CONFIRM SYNTHESIZE", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 608), Size = UDim2.fromOffset(210, 44), ZIndex = Z + 2,
	})
	confirmBtn.Activated:Connect(function() self:Confirm() end)
	self.ConfirmButton = { Button = confirmBtn, Label = confirmLabel }

	self:BuildPicker()

	local function resize()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local v = cam.ViewportSize
		self.Scale.Scale = math.clamp(math.min((v.X - 24) / WIDTH, (v.Y - 60 - 64) / HEIGHT), 0.45, 1)
		root.Position = UDim2.new(0.5, 0, 0.5, 32)
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

--============================================================================
-- HERO PICKER (Overlay used to pick the Recipient Hero)
--============================================================================

function Synth.BuildPicker(self: any)
	local picker = new("TextButton", {
		Name = "HeroPicker", BackgroundColor3 = C.Panel, BorderSizePixel = 0, Visible = false, Active = true,
		Position = UDim2.fromOffset(14, 14), Size = UDim2.new(1, -28, 1, -28), ZIndex = Z + 20,
		Text = "", AutoButtonColor = false,
	}, self.Root)
	picker.Activated:Connect(function() end)
	GothicBoxStyle.Apply(picker, { Style = "Window" })
	self.Picker = picker

	self.PickerTitle = label(picker, "Title", {
		Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 28),
		TextSize = 20, Text = "SELECT RECIPIENT HERO", ZIndex = Z + 21,
	})
	gold(self.PickerTitle)

	local back = new("TextButton", {
		Text = "×", TextSize = 28, Font = Enum.Font.GothamBold, TextColor3 = C.Muted, BackgroundTransparency = 1,
		Position = UDim2.new(1, -50, 0, 10), Size = UDim2.fromOffset(40, 40), ZIndex = Z + 22,
	}, picker)
	back.Activated:Connect(function()
		picker.Visible = false
		self:Render()
	end)
	GrimoireIcons.CloseGlyph(back, 18)

	self.PickerStatus = label(picker, "Body", {
		Position = UDim2.new(0, 24, 1, -44), Size = UDim2.new(1, -48, 0, 36),
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = TEXT.Muted,
		Text = "Choose the hero who will receive the EXP.", ZIndex = Z + 21,
	})

	self.PickerList = new("ScrollingFrame", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(20, 52), Size = UDim2.new(1, -40, 1, -104),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = Z + 21,
	}, picker)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(110, 144), CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.PickerList)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, self.PickerList)
end

function Synth.OpenPicker(self: any, mode: string)
	if self.Busy then return end
	self.PickerMode = mode
	self.Picker.Visible = true
	self:RenderPicker()
end

function Synth.Pick(self: any, uuid: string)
	local hero = self.State.Heroes[uuid] or (_G.CurrentProfile and _G.CurrentProfile.Heroes and _G.CurrentProfile.Heroes[uuid])
	if not hero then return end
	if self.PickerMode == "RECIPIENT" then
		self.Recipient = uuid
		local index = table.find(self.Donors, uuid)
		if index then table.remove(self.Donors, index) end
		self.Message = ""
		self.Picker.Visible = false
		self:QueuePreview()
		self:Render()
	end
end

function Synth.RenderPicker(self: any)
	for _, child in self.PickerList:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local heroMap = self.State.Heroes
	if (not heroMap or next(heroMap) == nil) and _G.CurrentProfile and _G.CurrentProfile.Heroes then
		heroMap = _G.CurrentProfile.Heroes
	end

	local heroes = {}
	for _, hero in heroMap do
		table.insert(heroes, hero)
	end
	table.sort(heroes, function(a, b)
		if (a.Stars or 1) ~= (b.Stars or 1) then return (a.Stars or 1) > (b.Stars or 1) end
		if (a.Level or 1) ~= (b.Level or 1) then return (a.Level or 1) > (b.Level or 1) end
		return tostring(a.DisplayName or "") < tostring(b.DisplayName or "")
	end)

	for i, hero in heroes do
		local isCurrent = hero.UUID == self.Recipient
		local rarity = Theme.RarityColor(hero.Stars or 1)

		local tile = new("TextButton", {
			Name = "Hero_" .. tostring(hero.UUID), Text = "", LayoutOrder = i, AutoButtonColor = true,
			BackgroundColor3 = C.Slot, BorderSizePixel = 0, ZIndex = Z + 22,
		}, self.PickerList)
		GildedGrimoire.Frame(tile, { Class = "Card", Tone = "Violet", ZIndex = Z + 22 })
		local rail = GildedGrimoire.StateStroke(tile)
		if rail then
			rail.Color = if isCurrent then TEXT.Gold else rarity
			rail.Thickness = if isCurrent then 2.4 else 1.2
		end

		local host = new("Frame", {
			BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(12, 8),
			Size = UDim2.fromOffset(86, 82), ZIndex = Z + 23,
		}, tile)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, host)
		HeroCard.Portrait(host, hero)

		local name = label(tile, "Title", {
			Position = UDim2.fromOffset(4, 94), Size = UDim2.new(1, -8, 0, 18), TextScaled = true,
			TextColor3 = isCurrent and TEXT.Gold or TEXT.Parchment, Text = hero.DisplayName or "Hero", ZIndex = Z + 24,
		})
		new("UITextSizeConstraint", { MaxTextSize = 13 }, name)

		label(tile, "Body", {
			Position = UDim2.fromOffset(4, 114), Size = UDim2.new(1, -8, 0, 16), TextSize = 11,
			TextColor3 = rarity, Text = string.format("%s · Lv.%d", stars(hero.Stars), hero.Level or 1), ZIndex = Z + 24,
		})

		local uuid = hero.UUID
		tile.Activated:Connect(function() self:Pick(uuid) end)
	end
end

--============================================================================
-- ROSTER CARD (Center Panel Cards, Image 2 style)
--============================================================================

function Synth.BuildRosterCard(self: any, hero: any): any
	local uuid = hero.UUID
	local card = new("TextButton", {
		Name = "Hero_" .. uuid, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = Z + 2,
	}, self.RosterScroll)
	GildedGrimoire.Frame(card, { Class = "Card", Tone = "Violet", ZIndex = Z + 2 })
	local rail = GildedGrimoire.StateStroke(card) :: UIStroke

	local portraitHost = new("Frame", {
		Name = "PortraitHost", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Color3.fromRGB(14, 10, 22), ClipsDescendants = true, ZIndex = Z + 3,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, portraitHost)
	local ring = new("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, portraitHost)
	HeroCard.Portrait(portraitHost, hero)

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

	-- Dims heroes that cannot be used as materials
	local shade = new("Frame", {
		Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 4, 10), BackgroundTransparency = 0.45,
		BorderSizePixel = 0, Visible = false, ZIndex = Z + 8,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, shade)

	-- Golden tint when selected as material
	local selectedTint = new("Frame", {
		Name = "SelectedTint", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 215, 80),
		BackgroundTransparency = 0.88, BorderSizePixel = 0, Visible = false, ZIndex = Z + 8,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 12) }, selectedTint)

	-- Green checkmark badge when selected as material
	local selectedBadge = new("Frame", {
		Name = "SelectedBadge", BackgroundColor3 = Color3.fromRGB(46, 175, 75),
		BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(22, 22),
		ZIndex = Z + 9, Visible = false,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, selectedBadge)
	stroke(selectedBadge, Color3.fromRGB(240, 255, 240), 1.5, 0)

	local stem1 = new("Frame", {
		Name = "CheckStem1", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(8, 12),
		Size = UDim2.fromOffset(3, 8), Rotation = -45, ZIndex = Z + 10,
	}, selectedBadge)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, stem1)

	local stem2 = new("Frame", {
		Name = "CheckStem2", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(13, 10),
		Size = UDim2.fromOffset(3, 14), Rotation = 45, ZIndex = Z + 10,
	}, selectedBadge)
	new("UICorner", { CornerRadius = UDim.new(0, 1) }, stem2)

	local scale = new("UIScale", {}, card)
	card.MouseEnter:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play() end)
	card.MouseLeave:Connect(function() TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play() end)
	card.Activated:Connect(function() self:PressRosterHero(uuid) end)

	return {
		Card = card, Rail = rail, Ring = ring, Arch = arch, ArchRendered = "",
		Chip = chipFrame, ChipLabel = chipLabel, Name = name, Info = info, Power = power,
		Shade = shade, SelectedTint = selectedTint, SelectedBadge = selectedBadge,
	}
end

function Synth.PressRosterHero(self: any, uuid: string)
	if self.Busy then return end
	local hero = self.State.Heroes[uuid] or (_G.CurrentProfile and _G.CurrentProfile.Heroes and _G.CurrentProfile.Heroes[uuid])
	if not hero then return end

	-- 1. If no recipient has been chosen yet:
	if not self.Recipient then
		self.Recipient = uuid
		self.Message = string.format("Selected %s as recipient. Choose materials below to synthesize EXP.", hero.DisplayName or "Hero")
		self:Render()
		self:QueuePreview()
		return
	end

	-- 2. If this hero is the recipient:
	if uuid == self.Recipient then
		self.Message = "This hero is the recipient and cannot be used as its own material."
		self:Render()
		return
	end

	-- 3. If already selected as a material: deselect it!
	local donorIdx = table.find(self.Donors, uuid)
	if donorIdx then
		table.remove(self.Donors, donorIdx)
		self.Message = ""
		self.ArmedRare = false
		self:Render()
		self:QueuePreview()
		return
	end

	-- 4. Check eligibility as a donor material:
	local eligible, reason, _ = checkDonorEligibility(hero, self.Recipient)
	if not eligible then
		self.Message = reason or "This hero cannot be used as material."
		self:Render()
		return
	end

	-- 5. Check against server limit
	local maxLimit = PitBalanceConfig.MaxDonors or 100
	if #self.Donors >= maxLimit then
		self.Message = string.format("Maximum material limit (%d) reached.", maxLimit)
		self:Render()
		return
	end

	-- 6. Add to materials!
	table.insert(self.Donors, uuid)
	self.Message = ""
	self.ArmedRare = false
	self:Render()
	self:QueuePreview()
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
			local uuid = self.Donors[i]
			local hero = self.State.Heroes[uuid]
			if not hero or not checkDonorEligibility(hero, self.Recipient) then
				table.remove(self.Donors, i)
			end
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
	if not self.Recipient then self.Message = "Choose the hero who will receive the EXP."; self:Render(); return end
	if #self.Donors == 0 then self.Message = "Select at least one material hero from the roster below."; self:Render(); return end
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
-- RENDERING
--============================================================================

function Synth.Render(self: any)
	local profile: any = _G.CurrentProfile
	local heroes = self.State.Heroes or {}
	if (not heroes or next(heroes) == nil) and profile and profile.Heroes then
		heroes = profile.Heroes
	end

	-- Prune any donors that have become ineligible
	for i = #self.Donors, 1, -1 do
		local uuid = self.Donors[i]
		local hero = heroes[uuid] or (profile and profile.Heroes and profile.Heroes[uuid])
		local eligible = hero and checkDonorEligibility(hero, self.Recipient)
		if not eligible then
			table.remove(self.Donors, i)
		end
	end

	-- Training multiplier for hero power calculation
	local mult = 1
	for uuid, reported in pairs(profile and profile.SquadPowerByHero or {}) do
		local h = heroes[uuid] or (profile and profile.Heroes and profile.Heroes[uuid])
		local base = h and StatFormulas.GetHeroPower(h, StatFormulas.GetEquippedArtifact(profile, h))
		if base and base > 0 then mult = reported / base break end
	end

	local recipient = self.Recipient and (heroes[self.Recipient] or (profile and profile.Heroes and profile.Heroes[self.Recipient]))

	-- 1. Render Top Recipient Slot & Details
	local recipSlot = self.RecipientSlot
	local recipId = recipient and recipient.UUID or nil
	recipSlot.Plus.Visible = recipient == nil

	local recipKey = if recipient then recipient.UUID else "__EMPTY__"
	if recipSlot.Rendered ~= recipKey then
		recipSlot.Rendered = recipKey
		for _, c in recipSlot.Portrait:GetChildren() do
			if c:IsA("GuiObject") and c ~= recipSlot.Plus then c:Destroy() end
		end
		if recipient then
			HeroCard.Portrait(recipSlot.Portrait, recipient)
		end
	end
	recipSlot.ArchRendered = setArchetype(recipSlot.Arch, recipSlot.ArchRendered, recipient and recipient.Archetype)

	local recipRarity = recipient and Theme.RarityColor(recipient.Stars or 1) or INK
	recipSlot.Ring.Color = if recipient then recipRarity else INK
	recipSlot.BtnLabel.Text = if recipient then "CHANGE" else "SELECT"
	recipSlot.Rail.Color = if recipient then TEXT.Gold else Color3.fromRGB(150, 138, 176)

	local preview = self.Preview
	local before = preview and preview.Before
	local after = preview and preview.After

	for _, t in self.Tweens do t:Cancel() end
	table.clear(self.Tweens)

	if recipient then
		self.RecipientName.Text = recipient.DisplayName or "Hero"
		self.RecipientInfo.Text = string.format("%s  ·  %s  ·  %s", stars(recipient.Stars), recipient.Archetype or "", abbreviate(powerOf(profile, recipient, mult)) .. " PWR")
		self.RecipientInfo.TextColor3 = Theme.RarityColor(recipient.Stars or 1)

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
			self.LevelLabel.Text = string.format('Lv. %d  <font color="#39E81E">→  Lv. %d</font>%s', before.Level, after.Level,
				if after.Level > before.Level then string.format(" (+%d Lvls)", after.Level - before.Level) else "")
			self.XPText.Text = string.format("%d / %d EXP (+%d EXP)", after.XP or 0, StatFormulas.GetXPRequiredForNextLevel(after.Level), preview.XP and preview.XP.Final or 0)
		else
			self.LevelLabel.Text = string.format("Lv. %d  (Cap: Lv. %d)", level, (recipient.Stars or 1) * 10)
			self.XPText.Text = string.format("%d / %d EXP", xp, StatFormulas.GetXPRequiredForNextLevel(level))
		end

		self.CurrentFill.Size = UDim2.fromScale(currentRatio, 1)
		local tween = TweenService:Create(self.GainFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(gainRatio, 1) })
		table.insert(self.Tweens, tween)
		tween:Play()

		if #self.Donors > 0 and preview and preview.XP then
			self.SummaryLine.Text = string.format('<b><font color="#4ADE80">+%s EXP</font></b> from %d material%s  ·  Efficiency: %d%%',
				abbreviate(preview.XP.Final or 0), #self.Donors, if #self.Donors == 1 then "" else "s", math.floor((preview.XP.Efficiency or 1) * 100 + 0.5))
		elseif #self.Donors > 0 then
			self.SummaryLine.Text = string.format("Selected %d material%s. Calculating preview…", #self.Donors, if #self.Donors == 1 then "" else "s")
		else
			self.SummaryLine.Text = '<font color="#A59BB9">Select material heroes from the roster below to level up.</font>'
		end
	else
		self.RecipientName.Text = "No Recipient Selected"
		self.RecipientInfo.Text = "Tap the slot on the left to choose who receives EXP"
		self.RecipientInfo.TextColor3 = TEXT.Muted
		self.LevelLabel.Text = '<font color="#96929F">Lv. —</font>'
		self.CurrentFill.Size = UDim2.fromScale(0, 1)
		self.GainFill.Size = UDim2.fromScale(0, 1)
		self.XPText.Text = ""
		self.SummaryLine.Text = '<font color="#A59BB9">Tap the card above or click any hero below to select recipient.</font>'
	end

	-- 2. Sort / filter buttons
	for key, b in self.SortButtons do
		retone(b.Button, b.Label, if self.Sort == key then "Gold" else "Slate", string.upper(key))
	end
	retone(self.FilterButton.Button, self.FilterButton.Label, if self.ReadyOnly then "Gold" else "Slate", "READY ONLY")

	-- 3. Center Roster Panel (Hero cards)
	local heroList = {}
	local heroPower: { [string]: number } = {}
	for _, h in pairs(heroes) do
		heroPower[h.UUID] = powerOf(profile, h, mult)
		if self.ReadyOnly then
			local eligible = (h.UUID ~= self.Recipient) and checkDonorEligibility(h, self.Recipient)
			if not eligible then
				continue
			end
		end
		table.insert(heroList, h)
	end

	table.sort(heroList, function(a, b)
		-- Selected donors stay at the very top for clarity
		local aSelected = table.find(self.Donors, a.UUID) ~= nil
		local bSelected = table.find(self.Donors, b.UUID) ~= nil
		if aSelected ~= bSelected then
			return aSelected
		end

		local ka = if self.Sort == "Stars" then (a.Stars or 1) elseif self.Sort == "Level" then (a.Level or 1) else heroPower[a.UUID]
		local kb = if self.Sort == "Stars" then (b.Stars or 1) elseif self.Sort == "Level" then (b.Level or 1) else heroPower[b.UUID]
		if ka ~= kb then return ka > kb end
		return (a.DisplayName or "") < (b.DisplayName or "")
	end)

	local selectedCount = #self.Donors
	self.RosterHeader.Text = string.format("HEROES  (%d)%s", #heroList,
		if selectedCount > 0 then string.format("  ·  %d SELECTED", selectedCount) else "")

	self.EmptyLabel.Visible = #heroList == 0
	self.EmptyLabel.Text = if self.ReadyOnly then "No eligible material heroes available. Unassign, unlock or bench heroes first." else "Your roster is empty."

	local seen: { [string]: boolean } = {}
	for order, hero in ipairs(heroList) do
		seen[hero.UUID] = true
		local entry = self.RosterCards[hero.UUID] or self:BuildRosterCard(hero)
		self.RosterCards[hero.UUID] = entry
		entry.Card.LayoutOrder = order
		entry.Card.Visible = true

		local isRecipient = (hero.UUID == self.Recipient)
		local isSelected = (table.find(self.Donors, hero.UUID) ~= nil)
		local eligible, reason, tagText = checkDonorEligibility(hero, self.Recipient)
		local resting = restingSeconds(hero)
		local rarity = Theme.RarityColor(hero.Stars or 1)

		entry.Name.Text = hero.DisplayName or "Hero"
		entry.Info.Text = string.format("%s · Lv.%d", stars(hero.Stars), hero.Level or 1)
		entry.Info.TextColor3 = rarity
		entry.Power.Text = abbreviate(heroPower[hero.UUID] or 0) .. " PWR"
		entry.Ring.Color = rarity
		entry.ArchRendered = setArchetype(entry.Arch, entry.ArchRendered, hero.Archetype)

		-- Status chip badge (matching Image 2)
		local chipText, chipColor = "", TEXT.Parchment
		if isRecipient then
			chipText, chipColor = "RECIPIENT", TEXT.Gold
		elseif resting > 0 then
			chipText, chipColor = string.format("RESTING %ds", resting), TEXT.Bad
		elseif FACILITY_LABELS[hero.Assignment or ""] then
			chipText, chipColor = string.upper(FACILITY_LABELS[hero.Assignment]), Color3.fromRGB(150, 236, 255)
		elseif tagText == "Deployed" then
			chipText, chipColor = "DEPLOYED", TEXT.Bad
		elseif tagText == "Equipped" then
			chipText, chipColor = "EQUIPPED", Color3.fromRGB(255, 226, 140)
		elseif tagText == "Locked" then
			chipText, chipColor = "LOCKED", Color3.fromRGB(224, 208, 255)
		elseif tagText ~= "Ready" and tagText ~= "" then
			chipText, chipColor = string.upper(tagText), TEXT.Bad
		end

		entry.Chip.Visible = (chipText ~= "")
		entry.ChipLabel.Text = chipText
		entry.ChipLabel.TextColor3 = chipColor

		-- Ineligible or Recipient heroes are shaded
		entry.Shade.Visible = isRecipient or not eligible

		-- Selection visual (Gold highlighted rail & check badge, matching Image 2's Sovereign Archon highlight)
		entry.SelectedTint.Visible = isSelected
		entry.SelectedBadge.Visible = isSelected
		if isSelected then
			entry.Rail.Color = TEXT.Gold
			entry.Rail.Thickness = 2.6
			entry.Rail.Transparency = 0
		else
			entry.Rail.Color = if eligible then Color3.fromRGB(200, 160, 96) else Color3.fromRGB(86, 80, 100)
			entry.Rail.Thickness = 1.4
			entry.Rail.Transparency = if eligible then 0.2 else 0.6
		end
	end

	for uuid, entry in pairs(self.RosterCards) do
		if not seen[uuid] then
			if heroes[uuid] then
				entry.Card.Visible = false
			else
				entry.Card:Destroy()
				self.RosterCards[uuid] = nil
			end
		end
	end

	-- 4. Bottom Footer (Clear & Confirm Synthesize buttons)
	local ready = self.Recipient ~= nil and #self.Donors > 0 and preview ~= nil and preview.CanCommit and not self.Loading and not self.Busy

	self.ClearButton.Button.Visible = #self.Donors > 0
	self.ClearButton.Label.Text = string.format("CLEAR (%d)", #self.Donors)

	if self.Busy then
		retone(self.ConfirmButton.Button, self.ConfirmButton.Label, "Slate", "SYNTHESIZING…")
	elseif self.ArmedRare then
		retone(self.ConfirmButton.Button, self.ConfirmButton.Label, "Danger", "CONFIRM — RARE HEROES")
	elseif ready then
		retone(self.ConfirmButton.Button, self.ConfirmButton.Label, "Action", "CONFIRM SYNTHESIZE")
	else
		retone(self.ConfirmButton.Button, self.ConfirmButton.Label, "Slate", "CONFIRM SYNTHESIZE")
	end

	-- Status line
	local status, color = self.Message, TEXT.Muted
	if status == "" then
		if self.Loading then
			status = "Calculating synthesis preview…"
		elseif preview and not preview.CanCommit then
			status, color = preview.Reason or "Requirements not met.", TEXT.Bad
		elseif preview and preview.Warnings and preview.Warnings[1] then
			status, color = tostring(preview.Warnings[1]), Color3.fromRGB(255, 204, 100)
		end
	elseif status:find("complete") then
		color = C.Good
	elseif self.ArmedRare or status:find("reject") or status:find("cannot") or status:find("protected") then
		color = TEXT.Bad
	end
	self.Status.Text, self.Status.TextColor3 = status, color
end

function Synth.Celebrate(self: any)
	local flash = new("Frame", {
		BackgroundColor3 = C.Line, BackgroundTransparency = 0.2, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = Z + 15,
	}, self.RecipientSlot.Card)
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
	self.Recipient = nil
	self.Donors = {}
	self.Preview = nil
	self.ArmedRare = false
	self.Message = ""
	self.Loading = false
	self:Render()
	self:Refresh()
end

function Synth.Close(self: any)
	if self.Busy then return end
	self.Root.Visible, self.Scrim.Visible, self.Picker.Visible = false, false, false
	self.PreviewSerial += 1
	self.Loading = false
	self.Recipient = nil
	self.Donors = {}
	self.Preview = nil
	self.ArmedRare = false
	self.Message = ""
	self:Render()
end

function Synth.IsOpen(self: any): boolean
	return self.Root.Visible
end

return Synth