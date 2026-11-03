--!strict
-- StarterPlayerScripts/UI/SummonReveal.luau
-- Per-pull summon reveal (Gilded Grimoire). Plays one beat per summoned item:
--   0. A 10x opens with a rift tease: the orb glows faintly in the batch's best colour, and a line
--      hints when something Legendary+ is inside ("A blinding light answers…").
--   1. A rift orb charges up and takes the item's rarity colour. Superior (4) and higher pulls
--      charge longer, pulse more and spin light rays behind the orb.
--   2. A flash in the rarity colour (jackpots also shake, burst sparkles and rumble the gamepad),
--      then the card flips from its back to its face: portrait, rarity tag, name, stars (popping in
--      one by one), archetype (or weapon type), base stats and a NEW badge for first copies.
--      Superior+ cards keep a foil shimmer and their rays turning behind them.
--   3. Tap anywhere to continue; a tap during a beat fast-forwards it. SKIP jumps to the results.
--      Keyboard/gamepad: Space/Enter/A continue, B/Backspace skip or close.
-- A 10x ends on a results grid that pops in card by card, with SUMMON AGAIN buttons when the caller
-- passes OnAgain. Heroes and artifacts both work. Sounds/images come from UIAssets (all optional).

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeroCard = require(script.Parent:WaitForChild("HeroCard"))
local ModalFit = require(script.Parent:WaitForChild("ModalFit"))
local UIFeel = require(script.Parent:WaitForChild("UIFeel"))
local UIAssets = require(script.Parent:WaitForChild("UIAssets"))
local Theme = require(script.Parent:WaitForChild("Hud"):WaitForChild("Theme"))
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local GrimoireIcons = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local GrimoireSummonButton = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireSummonButton"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))

local SummonReveal = {}
SummonReveal.__index = SummonReveal

local Z = 80
local STAGE_W, STAGE_H = 760, 560
local CARD_W, CARD_H = 270, 380
local TEXT = GildedGrimoire.Text
local INK = GildedGrimoire.Ink
local IMG = UIAssets.Images

-- Weapon type -> the archetype icon that wields it (weapons have no drawn icon of their own yet).
local WEAPON_ICON: { [string]: string } = {}
for archetype, weaponType in pairs(ArtifactCatalog.ArchetypeWeaponType) do
	WEAPON_ICON[weaponType] = archetype
end

-- The artifact banner rolls stars, not rarity (every pull is Common), so its excitement is the star.
local ARTIFACT_STAR_COLOR: { [number]: Color3 } = {
	[3] = Color3.fromRGB(96, 165, 250),
	[4] = Color3.fromRGB(192, 132, 252),
	[5] = Color3.fromRGB(250, 204, 21),
}

export type Options = {
	IsNew: ((raw: any) -> boolean)?, -- shows the NEW badge (first copy of a template)
	OnAgain: ((count: number) -> ())?, -- results screen: SUMMON AGAIN x1 / x10
	Cost1: number?,
	Cost10: number?,
}

type Item = {
	Name: string,
	Color: Color3,
	TierName: string,
	Stars: number,
	Icon: string,
	Kind: string,
	Sub: string,
	Emphasis: number, -- 0 common beat, 1 shiny (Superior+ / 4★ artifact), 2 jackpot (Legendary+ / 5★ artifact)
	New: boolean,
	Hero: any?,
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(className)
	for k, v in pairs(props) do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local function label(parent: Instance, role: string, props: { [string]: any }): TextLabel
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		TextColor3 = TEXT.Parchment,
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

local tween = UIFeel.Tween

local function describe(raw: any, isArtifact: boolean, isNew: boolean): Item
	if isArtifact then
		local info = ArtifactCatalog.GetRarityInfo(raw.Rarity or 1)
		local rarity = info.Index
		local star = math.clamp(raw.Star or 1, 1, 7)
		local starColor = ARTIFACT_STAR_COLOR[math.min(star, 5)]
		local emphasis = math.max(
			if rarity >= 6 then 2 elseif rarity >= 4 then 1 else 0,
			if star >= 5 then 2 elseif star >= 4 then 1 else 0
		)
		return {
			Name = raw.DisplayName or "Artifact",
			Color = if rarity < 4 and starColor then starColor else info.Color,
			TierName = string.upper(info.Name) .. string.format("  ·  %d★", star),
			Stars = star,
			Icon = WEAPON_ICON[raw.Type or ""] or "Forge",
			Kind = (string.gsub(raw.Type or "WEAPON", "_", " & ")),
			Sub = string.format("Weapon  ·  Power %d", math.round((ArtifactCatalog.CalculateEffectiveStats(star, rarity, nil, raw.TemplateId)))),
			Emphasis = emphasis,
			New = isNew,
		}
	end
	local tier = StatFormulas.GetHeroRarity(raw)
	local snap = StatFormulas.GetCombatSnapshot(raw)
	return {
		Name = raw.DisplayName or "Hero",
		Color = Theme.RarityColor(tier),
		TierName = string.upper(HeroCatalog.RarityName(tier)),
		Stars = math.clamp(raw.Stars or 1, 1, 7),
		Icon = raw.Archetype or "Striker",
		Kind = string.upper(raw.Archetype or "Hero"),
		Sub = string.format("HP %d  ·  ATK %d  ·  DPS %.1f", snap.Health, snap.AttackDamage, snap.DPS),
		Emphasis = if tier >= 6 then 2 elseif tier >= 4 then 1 else 0,
		New = isNew,
		Hero = raw,
	}
end

local function clearGui(parent: Instance)
	for _, c in parent:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function newBadge(parent: Instance, z: number, size: number): Frame
	local badge = new("Frame", {
		Name = "NewBadge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -size * 0.7, 0, size * 0.55),
		Size = UDim2.fromOffset(size * 1.9, size), BackgroundColor3 = Color3.fromRGB(239, 68, 68), Rotation = 12, ZIndex = z,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, badge)
	new("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, badge)
	label(badge, "Title", { Size = UDim2.fromScale(1, 1), Text = "NEW!", TextSize = math.floor(size * 0.6), TextColor3 = Color3.new(1, 1, 1), ZIndex = z + 1 })
	return badge
end

--============================================================================
-- CONSTRUCTION
--============================================================================

function SummonReveal.new(gui: ScreenGui)
	local self: any = setmetatable({}, SummonReveal)
	self.Run = 0
	self.Advance = Instance.new("BindableEvent")
	self.WaitingForTap = false
	self.Fast = false -- a tap during a beat fast-forwards the rest of it
	self.Options = {} :: Options

	-- Full-screen catcher: turns any tap into "continue" (no dim: see PHASE_5 §"No dim").
	self.Scrim = new("TextButton", {
		Name = "SummonRevealScrim", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(4, 2, 8),
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = Z,
	}, gui)
	self.Scrim:SetAttribute("NoFeel", true)
	self.Scrim.Activated:Connect(function() self:Tap() end)
	GildedGrimoire.Watch(self.Scrim)

	-- Tinted flash over the whole screen when a card lands.
	self.Flash = new("Frame", {
		Name = "Flash", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), ZIndex = Z + 30,
	}, self.Scrim)

	local stage = new("Frame", {
		Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(STAGE_W, STAGE_H), BackgroundTransparency = 1, ZIndex = Z + 1,
	}, self.Scrim)
	self.Stage = stage
	local stageScale = new("UIScale", {}, stage)

	-- Soft glow behind everything (uploaded radial glow, or a round gradient blob).
	local glow = new(if IMG.RevealGlow ~= "" then "ImageLabel" else "Frame", {
		Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1, ZIndex = Z + 1, Visible = false,
	}, stage)
	if IMG.RevealGlow ~= "" then
		glow.Image = IMG.RevealGlow
	else
		glow.BackgroundTransparency = 0
		glow.BackgroundColor3 = Color3.new(1, 1, 1)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, glow)
		new("UIGradient", { Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 1),
		}) }, glow)
	end
	self.Glow = glow

	-- Light rays: an uploaded sunburst, or thin bars fading out from the centre; spun as one group.
	local rays: GuiObject
	if IMG.RevealRays ~= "" then
		rays = new("ImageLabel", {
			Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
			Size = UDim2.fromOffset(680, 680), BackgroundTransparency = 1, Image = IMG.RevealRays, ImageTransparency = 0.2,
			ZIndex = Z + 2, Visible = false,
		}, stage)
	else
		rays = new("Frame", {
			Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
			Size = UDim2.fromOffset(620, 620), BackgroundTransparency = 1, ZIndex = Z + 2, Visible = false,
		}, stage)
		for i = 0, 11 do
			local ray = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 620),
				Rotation = i * 15, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = Z + 2,
			}, rays)
			new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 0.55),
					NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.58, 0.55), NumberSequenceKeypoint.new(1, 1),
				}),
			}, ray)
		end
	end
	self.Rays = rays

	-- Rift orb: a glowing core with a halo ring (or the uploaded swirl, tinted).
	local orb = new("Frame", {
		Name = "Orb", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(110, 110), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = Z + 4, Visible = false,
	}, stage)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, orb)
	self.OrbHalo = new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 10, Transparency = 0.6 }, orb)
	new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 200)), Rotation = 90,
	}, orb)
	if IMG.RevealRiftOrb ~= "" then
		self.OrbSwirl = new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.6, 1.6),
			BackgroundTransparency = 1, Image = IMG.RevealRiftOrb, ZIndex = Z + 5,
		}, orb)
	end
	self.OrbScale = new("UIScale", {}, orb)
	self.Orb = orb

	self.TeaseLabel = label(stage, "Title", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.47, 90), Size = UDim2.fromOffset(520, 26),
		TextSize = 18, TextColor3 = TEXT.Gold, ZIndex = Z + 20, Visible = false,
	})

	-- Card back (shown for the first half of the flip).
	local back = new(if IMG.CardBack ~= "" then "ImageLabel" else "Frame", {
		Name = "CardBack", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(CARD_W, CARD_H), BorderSizePixel = 0, ZIndex = Z + 6, Visible = false,
	}, stage)
	if IMG.CardBack ~= "" then
		back.Image = IMG.CardBack
		back.BackgroundTransparency = 1
		back.ScaleType = Enum.ScaleType.Fit
	else
		GildedGrimoire.Frame(back, { Class = "Card", Tone = "Violet", ZIndex = Z + 6 })
		self.BackRail = GildedGrimoire.StateStroke(back)
		local sigil = GrimoireIcons.Create("Summon", 120, back, Z + 7)
		sigil.AnchorPoint = Vector2.new(0.5, 0.5)
		sigil.Position = UDim2.fromScale(0.5, 0.5)
	end
	self.CardBack = back

	-- The card.
	local card = new("Frame", {
		Name = "RevealCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(CARD_W, CARD_H), BorderSizePixel = 0, ZIndex = Z + 6, Visible = false,
	}, stage)
	GildedGrimoire.Frame(card, { Class = "Card", Tone = "Deep", ZIndex = Z + 6 })
	self.CardRail = GildedGrimoire.StateStroke(card)
	self.CardScale = new("UIScale", {}, card)
	self.Card = card

	local tag = new("Frame", {
		Name = "RarityTag", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(170, 28), BorderSizePixel = 0, ZIndex = Z + 10,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, tag)
	new("UIStroke", { Color = INK, Thickness = 2.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tag)
	self.TagFrame = tag
	self.TagLabel = label(tag, "Title", { Size = UDim2.fromScale(1, 1), TextSize = 14, TextColor3 = Color3.new(1, 1, 1), ZIndex = Z + 11 })

	local portrait = new("Frame", {
		Name = "PortraitHost", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24),
		Size = UDim2.fromOffset(CARD_W - 30, 206), BackgroundColor3 = Color3.fromRGB(12, 8, 20), ClipsDescendants = true, ZIndex = Z + 7,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 10) }, portrait)
	self.PortraitRing = new("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, portrait)
	new("UIGradient", {
		Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new(0.3, 0),
	}, portrait)
	self.Portrait = portrait

	self.IconHolder = new("Frame", {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 0, 236), Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1, ZIndex = Z + 12,
	}, card)
	self.BadgeHolder = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = Z + 13,
	}, card)

	self.NameLabel = label(card, "Title", {
		Position = UDim2.fromOffset(10, 238), Size = UDim2.new(1, -20, 0, 34), TextSize = 26, TextColor3 = Color3.new(1, 1, 1), ZIndex = Z + 8,
	})
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), TEXT.Gold) }, self.NameLabel)
	-- Stars: one label each so they can pop in one by one.
	local starRow = new("Frame", {
		Name = "Stars", Position = UDim2.fromOffset(10, 272), Size = UDim2.new(1, -20, 0, 26), BackgroundTransparency = 1, ZIndex = Z + 8,
	}, card)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
	}, starRow)
	self.StarRow = starRow
	self.KindLabel = label(card, "Title", {
		Position = UDim2.fromOffset(10, 302), Size = UDim2.new(1, -20, 0, 18), TextSize = 13, TextColor3 = TEXT.Muted, ZIndex = Z + 8,
	})
	self.SubLabel = label(card, "Body", {
		Position = UDim2.fromOffset(10, 326), Size = UDim2.new(1, -20, 0, 40), TextSize = 13, TextWrapped = true, TextColor3 = TEXT.Parchment, ZIndex = Z + 8,
	})

	-- Chrome: counter, hint and skip.
	self.Counter = label(stage, "Number", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(200, 28),
		TextSize = 22, TextColor3 = TEXT.Gold, ZIndex = Z + 20,
	})
	self.Hint = label(stage, "Title", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(360, 22),
		TextSize = 14, TextColor3 = TEXT.Muted, Text = "TAP TO CONTINUE", ZIndex = Z + 20, Visible = false,
	})
	local skip = new("TextButton", {
		Name = "Skip", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 24),
		Size = UDim2.fromOffset(110, 44), BorderSizePixel = 0, ZIndex = Z + 40,
	}, self.Scrim)
	GildedGrimoire.Frame(skip, { Class = "Button", Tone = "Slate", ZIndex = Z + 40 })
	label(skip, "Title", { Size = UDim2.fromScale(1, 1), TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Text = "SKIP  »", ZIndex = Z + 42 })
	skip.Activated:Connect(function() self:Skip() end)
	self.SkipButton = skip

	-- Results grid (10x) and the closing row.
	local results = new("Frame", {
		Name = "Results", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(STAGE_W, STAGE_H - 40), BorderSizePixel = 0, ZIndex = Z + 3, Visible = false,
	}, stage)
	GildedGrimoire.Frame(results, { Class = "Window", Tone = "Violet", ZIndex = Z + 3 })
	self.Results = results
	self.ResultsScale = new("UIScale", {}, results)
	self.ResultsTitle = label(results, "Title", {
		Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 34), TextSize = 28, TextColor3 = Color3.new(1, 1, 1),
		Text = "S U M M O N   R E S U L T S", ZIndex = Z + 5,
	})
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), TEXT.Gold) }, self.ResultsTitle)
	self.ResultsBest = label(results, "Body", {
		Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = TEXT.Muted, ZIndex = Z + 5,
	})
	local grid = new("Frame", {
		Name = "Grid", Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 1, -160), BackgroundTransparency = 1, ZIndex = Z + 4,
	}, results)
	new("UIGridLayout", {
		CellSize = UDim2.fromOffset(132, 176), CellPadding = UDim2.fromOffset(10, 14),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	self.Grid = grid

	local actions = new("Frame", {
		Name = "Actions", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -34),
		Size = UDim2.fromOffset(700, 56), BackgroundTransparency = 1, ZIndex = Z + 40, Visible = false,
	}, stage)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder,
	}, actions)
	self.Actions = actions

	self.Again1 = GrimoireSummonButton.new(actions, {
		Name = "Again1", Title = "AGAIN 1X", Cost = 0, Position = UDim2.new(), Size = UDim2.fromOffset(190, 56), ZIndex = Z + 40,
		OnClick = function() self:Again(1) end,
	})
	self.Again1.Root.LayoutOrder = 1
	local done = new("TextButton", {
		Name = "Continue", Text = "", AutoButtonColor = false, LayoutOrder = 2,
		Size = UDim2.fromOffset(200, 50), BorderSizePixel = 0, ZIndex = Z + 40,
	}, actions)
	GildedGrimoire.Frame(done, { Class = "Button", Tone = "Gold", ZIndex = Z + 40 })
	label(done, "Title", { Size = UDim2.fromScale(1, 1), TextSize = 18, TextColor3 = Color3.new(1, 1, 1), Text = "CONTINUE", ZIndex = Z + 42 })
	done.Activated:Connect(function() self:Close() end)
	self.DoneButton = done
	self.Again10 = GrimoireSummonButton.new(actions, {
		Name = "Again10", Title = "AGAIN 10X", Cost = 0, Position = UDim2.new(), Size = UDim2.fromOffset(190, 56), ZIndex = Z + 40,
		OnClick = function() self:Again(10) end,
	})
	self.Again10.Root.LayoutOrder = 3

	-- Fit the stage inside the safe area (below the top bar, clear of the bottom edge).
	ModalFit.Bind(stage, stageScale, STAGE_W, STAGE_H, { MaxScale = 1.15 })

	-- Keyboard / gamepad: continue and skip without a pointer.
	UserInputService.InputBegan:Connect(function(input, processed)
		if not self.Scrim.Visible then return end
		local key = input.KeyCode
		if key == Enum.KeyCode.ButtonB or key == Enum.KeyCode.Backspace then
			if self.Actions.Visible then self:Close() else self:Skip() end
		elseif not processed and (key == Enum.KeyCode.Space or key == Enum.KeyCode.Return or key == Enum.KeyCode.ButtonA) then
			if self.Actions.Visible then return end -- the selected button handles A
			self:Tap()
		end
	end)

	return self
end

--============================================================================
-- PLAYBACK
--============================================================================

-- Waits `t` seconds (cut short by a fast-forward tap) unless the run was skipped or closed.
function SummonReveal.Wait(self: any, run: number, t: number): boolean
	local finish = os.clock() + t
	while os.clock() < finish and not self.Fast and self.Run == run do
		task.wait()
	end
	return self.Run == run
end

function SummonReveal.Tap(self: any)
	if self.WaitingForTap then
		self.Advance:Fire()
	elseif self.Items and not self.Actions.Visible then
		self.Fast = true
	end
end

function SummonReveal.WaitTap(self: any, run: number): boolean
	self.WaitingForTap = true
	self.Hint.Visible = true
	self.Hint.TextTransparency = 1
	tween(self.Hint, 0.4, { TextTransparency = 0 })
	self.Advance.Event:Wait()
	self.WaitingForTap = false
	self.Hint.Visible = false
	return self.Run == run
end

function SummonReveal.Sfx(self: any, name: string, pitch: number?)
	if self.Fast then return end -- a fast-forwarded beat stays quiet until its card lands
	UIFeel.Sfx(name, pitch)
end

function SummonReveal.StopFx(self: any)
	if self.StopShimmer then
		self.StopShimmer()
		self.StopShimmer = nil
	end
	if self.RaysTween then
		self.RaysTween:Cancel()
		self.RaysTween = nil
	end
end

function SummonReveal.FillCard(self: any, item: Item)
	self.TagFrame.BackgroundColor3 = item.Color
	self.TagLabel.Text = item.TierName
	if self.CardRail then
		self.CardRail.Color = item.Color
		self.CardRail.Thickness = if item.Emphasis > 0 then 3 else 1.6
	end
	self.PortraitRing.Color = item.Color
	self.Portrait.BackgroundColor3 = item.Color:Lerp(Color3.fromRGB(10, 6, 16), 0.78)
	clearGui(self.Portrait)
	if item.Hero then
		HeroCard.Portrait(self.Portrait, item.Hero)
	else
		local icon = GrimoireIcons.Create(item.Icon, 140, self.Portrait, Z + 8)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
	end
	self.IconHolder:ClearAllChildren()
	GrimoireIcons.Create(item.Icon, 44, self.IconHolder, Z + 12)
	clearGui(self.BadgeHolder)
	self.NameLabel.Text = item.Name
	clearGui(self.StarRow)
	for i = 1, item.Stars do
		local star = label(self.StarRow, "Number", {
			Name = "Star" .. i, LayoutOrder = i, Size = UDim2.fromOffset(24, 26), TextSize = 24, Text = "★",
			TextColor3 = item.Color, TextTruncate = Enum.TextTruncate.None, ZIndex = Z + 8,
		})
		new("UIScale", { Scale = 0 }, star)
	end
	self.KindLabel.Text = item.Kind
	self.SubLabel.Text = item.Sub
end

-- Pops the stars in one at a time, each tick a little higher.
function SummonReveal.PopStars(self: any, run: number, item: Item)
	for i = 1, item.Stars do
		local star = self.StarRow:FindFirstChild("Star" .. i)
		local s = star and star:FindFirstChildOfClass("UIScale")
		if s then
			if self.Fast or UIFeel.ReducedMotion() then
				s.Scale = 1
			else
				s.Scale = 1.8
				tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
				UIFeel.Sfx("StarTick", 0.9 + i * 0.07)
				if not self:Wait(run, 0.09) then return end
			end
		end
	end
	if item.New then
		local badge = newBadge(self.BadgeHolder, Z + 14, 26)
		UIFeel.PopIn(badge, 0, 0.3)
		self:Sfx("NewBadge")
	end
end

-- 10x opener: a faint orb in the best colour, plus a line when there is a jackpot inside.
function SummonReveal.Tease(self: any, run: number, items: { Item }): boolean
	local best = items[1]
	for _, item in items do
		if item.Emphasis > best.Emphasis then best = item end
	end
	local orb, scale = self.Orb, self.OrbScale
	orb.Visible = true
	orb.BackgroundTransparency = 0.2
	orb.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(best.Color, 0.35 + 0.25 * best.Emphasis)
	self.OrbHalo.Color = orb.BackgroundColor3
	scale.Scale = 0
	tween(scale, 0.45, { Scale = 0.7 }, Enum.EasingStyle.Back)
	self.TeaseLabel.Text = if best.Emphasis == 2 then "A blinding light answers your call…"
		elseif best.Emphasis == 1 then "The rift shimmers…"
		else "The rift stirs…"
	self.TeaseLabel.Visible = true
	self.TeaseLabel.TextTransparency = 1
	tween(self.TeaseLabel, 0.3, { TextTransparency = 0 })
	self:Sfx("SummonCharge", 0.85)
	if best.Emphasis == 2 then UIFeel.Haptic("Notify") end
	local ok = self:Wait(run, 0.9 + 0.25 * best.Emphasis)
	self.TeaseLabel.Visible = false
	self.Fast = false
	return ok
end

-- One beat: charge the orb, flash, flip the card in.
function SummonReveal.Beat(self: any, run: number, item: Item): boolean
	self:StopFx()
	self.Card.Visible = false
	self.CardBack.Visible = false
	self.Rays.Visible = false
	self.Glow.Visible = false
	local orb, scale = self.Orb, self.OrbScale
	orb.Visible = true
	orb.BackgroundColor3 = Color3.new(1, 1, 1)
	self.OrbHalo.Color = Color3.new(1, 1, 1)
	scale.Scale = 0.15
	orb.BackgroundTransparency = 0

	-- Charge: grow in white, then bleed into the rarity colour.
	self:Sfx("SummonCharge")
	tween(scale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	if not self:Wait(run, 0.28) then return false end
	tween(orb, 0.3, { BackgroundColor3 = item.Color })
	tween(self.OrbHalo, 0.3, { Color = item.Color })
	if self.OrbSwirl then
		self.OrbSwirl.ImageColor3 = item.Color
		tween(self.OrbSwirl, 1.6, { Rotation = self.OrbSwirl.Rotation + 360 }, Enum.EasingStyle.Linear)
	end
	local pulses = if item.Emphasis == 2 then 3 elseif item.Emphasis == 1 then 2 else 1
	if item.Emphasis > 0 then
		self.Rays.Visible = true
		self.Rays.Rotation = 0
		if self.Rays:IsA("ImageLabel") then
			(self.Rays :: ImageLabel).ImageColor3 = item.Color
		else
			for _, ray in self.Rays:GetChildren() do
				if ray:IsA("Frame") then ray.BackgroundColor3 = item.Color end
			end
		end
		tween(self.Rays, 0.4 * pulses + 1.2, { Rotation = 90 }, Enum.EasingStyle.Linear)
	end
	for p = 1, pulses do
		self:Sfx("SummonPulse", 1 + p * 0.12)
		if item.Emphasis > 0 then UIFeel.Haptic("Hover") end
		tween(scale, 0.18, { Scale = 1.3 })
		if not self:Wait(run, 0.18) then return false end
		tween(scale, 0.18, { Scale = 0.95 })
		if not self:Wait(run, 0.2) then return false end
	end

	-- Burst: the orb pops, the screen flashes in the rarity colour.
	tween(scale, 0.14, { Scale = 2.2 })
	tween(orb, 0.14, { BackgroundTransparency = 1 })
	self.Flash.BackgroundColor3 = item.Color:Lerp(Color3.new(1, 1, 1), 0.45)
	self.Flash.BackgroundTransparency = if item.Emphasis > 0 then 0.05 else 0.4
	if UIFeel.ReducedMotion() then self.Flash.BackgroundTransparency = 0.6 end
	tween(self.Flash, 0.5, { BackgroundTransparency = 1 })
	UIFeel.Sfx(if item.Emphasis == 2 then "SummonBurstJackpot" elseif item.Emphasis == 1 then "SummonBurstRare" else "SummonBurstCommon")
	UIFeel.Haptic(if item.Emphasis == 2 then "Impact" elseif item.Emphasis == 1 then "Notify" else "Click")
	self.Fast = false -- the card itself always lands properly
	if not self:Wait(run, 0.12) then return false end
	orb.Visible = false

	-- Glow and sparkles behind the card for shiny pulls.
	if item.Emphasis > 0 then
		self.Glow.Visible = true
		if self.Glow:IsA("ImageLabel") then
			(self.Glow :: ImageLabel).ImageColor3 = item.Color
		else
			self.Glow.BackgroundColor3 = item.Color
		end
		UIFeel.Burst(self.Stage, UDim2.fromScale(0.5, 0.47), item.Color, if item.Emphasis == 2 then 26 else 14, Z + 9, if item.Emphasis == 2 then 300 else 200)
	end

	-- Flip: the back narrows to nothing, then the face opens with an overshoot.
	self:FillCard(item)
	if self.BackRail then self.BackRail.Color = item.Color end
	local reduced = UIFeel.ReducedMotion()
	if not reduced then
		self.CardBack.Visible = true
		self.CardBack.Size = UDim2.fromOffset(CARD_W, CARD_H)
		tween(self.CardBack, 0.13, { Size = UDim2.fromOffset(0, CARD_H) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if not self:Wait(run, 0.13) then return false end
		self.CardBack.Visible = false
	end
	self:Sfx("CardFlip")
	self.Card.Visible = true
	self.Card.Rotation = 0
	if reduced then
		self.Card.Size = UDim2.fromOffset(CARD_W, CARD_H)
		self.CardScale.Scale = 1
	else
		self.Card.Size = UDim2.fromOffset(0, CARD_H)
		self.CardScale.Scale = 0.85
		tween(self.Card, 0.3, { Size = UDim2.fromOffset(CARD_W, CARD_H) }, Enum.EasingStyle.Back)
		tween(self.CardScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if item.Emphasis == 2 then
		task.delay(0.15, function()
			if self.Run == run then UIFeel.Shake(self.Card, 5, 0.45) end
		end)
	end
	if item.Emphasis > 0 then
		-- Rays keep turning slowly behind the landed card, and the face gets a foil sweep.
		self.RaysTween = TweenService:Create(self.Rays, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = self.Rays.Rotation + 360 })
		if not reduced then self.RaysTween:Play() end
		self.StopShimmer = UIFeel.Shimmer(self.Card, Z + 12, true, 1.8)
	end
	if not self:Wait(run, 0.3) then return false end
	self:PopStars(run, item)
	return self.Run == run
end

function SummonReveal.MiniCard(self: any, item: Item, order: number)
	local cell = new("Frame", { Name = "Result_" .. order, LayoutOrder = order, BackgroundTransparency = 1, ZIndex = Z + 5 }, self.Grid)
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0, ZIndex = Z + 5,
	}, cell)
	GildedGrimoire.Frame(card, { Class = "Card", Tone = if item.Emphasis > 0 then "Violet" else "Deep", ZIndex = Z + 5 })
	local rail = GildedGrimoire.StateStroke(card)
	if rail then
		rail.Color = item.Color
		rail.Thickness = if item.Emphasis > 0 then 2.6 else 1.4
	end
	local host = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(110, 104),
		BackgroundColor3 = item.Color:Lerp(Color3.fromRGB(10, 6, 16), 0.8), ClipsDescendants = true, ZIndex = Z + 6,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, host)
	new("UIStroke", { Color = item.Color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, host)
	if item.Hero then
		HeroCard.Portrait(host, item.Hero)
	else
		local icon = GrimoireIcons.Create(item.Icon, 72, host, Z + 7)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
	end
	local name = label(card, "Title", {
		Position = UDim2.fromOffset(4, 116), Size = UDim2.new(1, -8, 0, 20), TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		Text = item.Name, ZIndex = Z + 7,
	})
	new("UITextSizeConstraint", { MaxTextSize = 15 }, name)
	label(card, "Number", {
		Position = UDim2.fromOffset(4, 136), Size = UDim2.new(1, -8, 0, 16), TextSize = 14, TextColor3 = item.Color,
		Text = string.rep("★", item.Stars), ZIndex = Z + 7,
	})
	label(card, "Body", {
		Position = UDim2.fromOffset(4, 152), Size = UDim2.new(1, -8, 0, 16), TextSize = 11, TextColor3 = TEXT.Muted,
		Text = item.TierName, ZIndex = Z + 7,
	})
	if item.New then newBadge(card, Z + 9, 18) end
	local pop = new("UIScale", { Scale = 0 }, card)
	return pop, card
end

function SummonReveal.ShowResults(self: any, items: { Item })
	local run = self.Run
	self:StopFx()
	self.Orb.Visible, self.Rays.Visible, self.Card.Visible, self.CardBack.Visible, self.Glow.Visible = false, false, false, false, false
	self.Counter.Visible, self.Hint.Visible, self.SkipButton.Visible, self.TeaseLabel.Visible = false, false, false, false
	self.WaitingForTap = false
	clearGui(self.Grid)
	local best: Item? = nil
	local cards = {}
	for i, item in items do
		if not best or item.Emphasis > best.Emphasis then best = item end
		local pop, card = self:MiniCard(item, i)
		table.insert(cards, { Pop = pop, Card = card, Item = item })
	end
	self.ResultsBest.Text = if best and best.Emphasis > 0
		then string.format('Best pull: <font color="#%s">%s · %s</font>', best.Color:ToHex(), best.Name, best.TierName)
		else string.format("%d summoned", #items)
	self.Results.Visible = true
	UIFeel.PopIn(self.Results, 0.9, 0.25)
	self:ShowActions()
	task.spawn(function()
		for i, entry in cards do
			if self.Run ~= run then return end
			if UIFeel.ReducedMotion() then
				entry.Pop.Scale = 1
			else
				tween(entry.Pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
				UIFeel.Sfx("ResultsPop", 0.9 + i * 0.04)
				if entry.Item.Emphasis > 0 then
					task.delay(0.2, function()
						if self.Run == run and entry.Card.Parent then UIFeel.Shimmer(entry.Card, Z + 10, true, 2.2 + (i % 3) * 0.4) end
					end)
				end
				task.wait(0.06)
			end
		end
	end)
end

-- CONTINUE always; SUMMON AGAIN x1 / x10 when the caller wired OnAgain.
function SummonReveal.ShowActions(self: any)
	local opts: Options = self.Options
	local canAgain = opts.OnAgain ~= nil
	self.Again1.Root.Visible = canAgain
	self.Again10.Root.Visible = canAgain
	if canAgain then
		self.Again1.SetCost(opts.Cost1 or 100)
		self.Again10.SetCost(opts.Cost10 or 900)
	end
	self.Actions.Visible = true
	UIFeel.PopIn(self.Actions, 0.6, 0.3)
	if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		GuiService.SelectedObject = self.DoneButton
	end
end

function SummonReveal.Again(self: any, count: number)
	local onAgain = self.Options.OnAgain
	if not onAgain then return end
	self:Close()
	onAgain(count)
end

-- Plays the reveal for `list` (hero instances, or artifacts when isArtifact).
function SummonReveal.Play(self: any, list: { any }, isArtifact: boolean?, opts: Options?)
	if #list == 0 then return end
	self.Run += 1
	local run = self.Run
	self.Options = opts or {}
	self.Fast = false
	local isNew = self.Options.IsNew
	local items: { Item } = {}
	for _, raw in list do
		table.insert(items, describe(raw, isArtifact == true, if isNew then isNew(raw) else false))
	end
	self.Items = items

	self.Results.Visible, self.Actions.Visible = false, false
	self.Counter.Visible = #items > 1
	self.SkipButton.Visible = #items > 1
	if #items > 1 then UIFeel.PopIn(self.SkipButton, 0.5) end
	self.Scrim.Visible = true
	self.Scrim.BackgroundTransparency = 1

	task.spawn(function()
		if #items > 1 then
			self.Counter.Text = ""
			if not self:Tease(run, items) then return end
		end
		for i, item in items do
			if self.Run ~= run then return end
			self.Fast = false
			self.Counter.Text = string.format("%d / %d", i, #items)
			UIFeel.Pop(self.Counter, 0.25)
			if not self:Beat(run, item) then return end
			if #items == 1 then
				self:ShowActions()
				return
			end
			if not self:WaitTap(run) then return end
		end
		if self.Run == run then self:ShowResults(items) end
	end)
end

-- SKIP: stop the beats and go straight to the results grid.
function SummonReveal.Skip(self: any)
	if not self.Items or self.Actions.Visible then return end
	self.Run += 1
	self.Advance:Fire()
	self.Flash.BackgroundTransparency = 1
	self:ShowResults(self.Items)
end

function SummonReveal.Close(self: any)
	self.Run += 1
	self.Advance:Fire()
	self:StopFx()
	self.WaitingForTap = false
	self.Fast = false
	self.Items = nil
	self.Scrim.Visible = false
	self.Flash.BackgroundTransparency = 1
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Scrim) then
		GuiService.SelectedObject = nil
	end
	-- Free the viewports.
	clearGui(self.Portrait)
	clearGui(self.Grid)
end

function SummonReveal.IsOpen(self: any): boolean
	return self.Scrim.Visible
end

return SummonReveal
