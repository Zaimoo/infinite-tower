--!strict
-- ReplicatedStorage/Shared/Util/GildedGrimoire.luau
-- "Gilded Grimoire": the Infinite Tower UI theme (Phase 5). Gothic palette and studs, drawn in a
-- chunky cartoon way: every panel and button has a thick black INK outline, an inset gold RAIL,
-- a top-lit gradient fill and rounded corners; titles use heavy Cinzel Decorative with an ink
-- outline; body text uses Cinzel Bold. Use these tokens and helpers for every new screen.
--
-- Imperative code: GothicBoxStyle.Apply / GothicFont.Apply already render in this theme;
--   GildedGrimoire.Frame(frame, opts) frames any GuiObject directly, and
--   GildedGrimoire.Watch(root) re-fonts legacy Gotham text inside a screen (and anything added later).
-- React code: StarterPlayerScripts/UI/Hud (Components.Panel, HeavyLabel, Body, Icons) uses the same tokens.

local GildedGrimoire = {}

GildedGrimoire.Name = "Gilded Grimoire"

GildedGrimoire.Ink = Color3.fromRGB(10, 6, 14)

-- Panel tones (top, bottom, rail). Violet is the default; the others mark meaning.
GildedGrimoire.Tones = table.freeze({
	Violet = table.freeze({ Top = Color3.fromRGB(58, 38, 88), Bottom = Color3.fromRGB(20, 14, 32), Rail = Color3.fromRGB(240, 196, 110) }),
	Deep = table.freeze({ Top = Color3.fromRGB(38, 26, 58), Bottom = Color3.fromRGB(14, 10, 22), Rail = Color3.fromRGB(200, 160, 96) }),
	Bronze = table.freeze({ Top = Color3.fromRGB(96, 64, 24), Bottom = Color3.fromRGB(34, 20, 10), Rail = Color3.fromRGB(255, 214, 110) }),
	Teal = table.freeze({ Top = Color3.fromRGB(28, 70, 104), Bottom = Color3.fromRGB(10, 20, 40), Rail = Color3.fromRGB(150, 236, 255) }),
	Crimson = table.freeze({ Top = Color3.fromRGB(96, 30, 40), Bottom = Color3.fromRGB(30, 10, 18), Rail = Color3.fromRGB(255, 214, 110) }),
	Slate = table.freeze({ Top = Color3.fromRGB(34, 28, 46), Bottom = Color3.fromRGB(16, 12, 24), Rail = Color3.fromRGB(140, 130, 160) }),
	Gold = table.freeze({ Top = Color3.fromRGB(255, 220, 110), Bottom = Color3.fromRGB(214, 128, 24), Rail = Color3.fromRGB(255, 248, 200) }),
	-- Tier tones for world billboards (Config/BillboardThemes): relic rarity and mob tier.
	Jade = table.freeze({ Top = Color3.fromRGB(26, 84, 40), Bottom = Color3.fromRGB(8, 28, 14), Rail = Color3.fromRGB(120, 230, 120) }),
	Azure = table.freeze({ Top = Color3.fromRGB(24, 66, 104), Bottom = Color3.fromRGB(8, 18, 38), Rail = Color3.fromRGB(120, 220, 255) }),
	Amber = table.freeze({ Top = Color3.fromRGB(112, 66, 16), Bottom = Color3.fromRGB(38, 18, 6), Rail = Color3.fromRGB(255, 196, 90) }),
	Void = table.freeze({ Top = Color3.fromRGB(72, 28, 112), Bottom = Color3.fromRGB(20, 8, 38), Rail = Color3.fromRGB(210, 130, 255) }),
	Gilded = table.freeze({ Top = Color3.fromRGB(100, 76, 22), Bottom = Color3.fromRGB(34, 22, 6), Rail = Color3.fromRGB(255, 226, 130) }),
	Blood = table.freeze({ Top = Color3.fromRGB(116, 14, 32), Bottom = Color3.fromRGB(34, 4, 12), Rail = Color3.fromRGB(255, 214, 110) }),
	-- Bright amethyst for generic action buttons (confirm, initiate), so they stand out from panels.
	Action = table.freeze({ Top = Color3.fromRGB(134, 86, 204), Bottom = Color3.fromRGB(62, 36, 112), Rail = Color3.fromRGB(255, 226, 140) }),
})

GildedGrimoire.Text = table.freeze({
	White = Color3.fromRGB(255, 255, 255),
	Parchment = Color3.fromRGB(236, 228, 246),
	Muted = Color3.fromRGB(196, 186, 214),
	Gold = Color3.fromRGB(255, 214, 120),
	Good = Color3.fromRGB(120, 255, 140),
	Bad = Color3.fromRGB(255, 100, 100),
})

-- Ink outline width and corner radius by box size class.
GildedGrimoire.InkWidth = table.freeze({ Window = 3.5, Panel = 3, Card = 3, Row = 2.5, Slot = 2.5, Button = 2.5, Compact = 2 })
GildedGrimoire.Radius = table.freeze({ Window = 16, Panel = 12, Card = 12, Row = 10, Slot = 10, Button = 10, Compact = 8 })
GildedGrimoire.RailInset = 3

local function font(family: string, weight: Enum.FontWeight, fallback: Enum.Font): Font
	local ok, face = pcall(function() return Font.fromName(family, weight) end)
	return if ok and face then face else Font.fromEnum(fallback)
end

GildedGrimoire.Fonts = {
	Title = font("CinzelDecorative", Enum.FontWeight.Heavy, Enum.Font.GothamBlack), -- titles, labels, buttons
	Number = font("Cinzel", Enum.FontWeight.Heavy, Enum.Font.GothamBlack), -- big numbers, counters
	Body = font("Cinzel", Enum.FontWeight.Bold, Enum.Font.GothamBold), -- sentences, details
}

-- HUD card tokens. Historically "Clear Glass" (thin white hairlines over a see-through near-black
-- body); since the 2026-11-09 decision the HUD is fully gothic (UI overhaul plan §3.1 "HudCard"),
-- so the same keys now draw a lifted plum card with an ink outline and a gold inset rail, in Cinzel.
-- The React HUD reads these as Hud/Theme.Glass; imperative HUD pieces use GlassFrame / GlassText below.
GildedGrimoire.Glass = table.freeze({
	Base = Color3.fromRGB(44, 30, 68), -- card body (lifted plum)
	BaseRaised = Color3.fromRGB(66, 46, 98), -- header strip, tile background
	Hairline = Color3.fromRGB(10, 6, 14), -- the ink outline (was a 1px white hairline)
	Rail = Color3.fromRGB(240, 196, 110), -- inset gold rail
	Text = Color3.fromHex("#F6F4FF"),
	TextMuted = Color3.fromHex("#F6F4FF"), -- at MutedTransparency
	Arcane = Color3.fromHex("#C084FC"), -- active, selected, focused; skill gauge
	Royal = Color3.fromHex("#FACC15"), -- currency, primary action, full gauge, local player
	Danger = Color3.fromHex("#EF4444"), -- down, badges, boss HP, loot stolen
	Vital = Color3.fromHex("#4ADE80"), -- HP, positive deltas
	-- Mostly opaque so text keeps contrast over a bright sky; a little of the world shows through.
	BaseTransparency = 0.1,
	RaisedTransparency = 0.05,
	BackplateTransparency = 0.5, -- empty or decorative backplates only
	HairlineTransparency = 0,
	StrokeThickness = 2.5,
	RailTransparency = 0.3,
	MutedTransparency = 0.15,
	HoverDrop = 0.05, -- body transparency drop on hover
	Radius = 10,
	TileRadius = 6,
	Tween = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Fonts = table.freeze({
		Label = font("Cinzel", Enum.FontWeight.Bold, Enum.Font.GothamMedium), -- UI chrome
		Number = font("Cinzel", Enum.FontWeight.Heavy, Enum.Font.GothamBold), -- numbers, headlines
		Display = font("Cinzel", Enum.FontWeight.Bold, Enum.Font.GothamBold), -- hero names, Squad Power
	}),
})

-- Frames a GuiObject in the theme: ink outline, gold rail, gradient fill, rounded corners.
-- opts.Class picks InkWidth/Radius ("Panel" default); opts.Tone a key of Tones; opts.Rail overrides
-- the rail colour; opts.Fill = false keeps the object's own background. Safe to call again.
function GildedGrimoire.Frame(frame: GuiObject, opts: { Class: string?, Tone: string?, Rail: Color3?, Fill: boolean?, ZIndex: number? }?)
	local o = opts or {}
	if o.Tone == "Glass" then
		-- Clear Glass: opts.Rail becomes the accent bar's colour.
		GildedGrimoire.GlassFrame(frame, { Accent = o.Rail })
		return frame :: any
	end
	local class = o.Class or "Panel"
	local tone = GildedGrimoire.Tones[o.Tone or "Violet"] or GildedGrimoire.Tones.Violet
	local radius = GildedGrimoire.Radius[class] or 12
	for _, name in { "GrimoireCorner", "GrimoireFill", "GrimoireInk", "GrimoireRail" } do
		local old = frame:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local corner = Instance.new("UICorner")
	corner.Name = "GrimoireCorner"
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
	if o.Fill ~= false then
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BackgroundTransparency = 0
		local grad = Instance.new("UIGradient")
		grad.Name = "GrimoireFill"
		grad.Color = ColorSequence.new(tone.Top, tone.Bottom)
		grad.Rotation = 90
		grad.Parent = frame
	end
	local ink = Instance.new("UIStroke")
	ink.Name = "GrimoireInk"
	ink.Color = GildedGrimoire.Ink
	ink.Thickness = GildedGrimoire.InkWidth[class] or 3
	ink.LineJoinMode = Enum.LineJoinMode.Round
	ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ink.Parent = frame
	local rail = GildedGrimoire.Rail(frame, o.Rail or tone.Rail, radius, o.ZIndex)
	return rail
end

-- The inset rail frame (returns it so callers can move an existing UIStroke into it).
function GildedGrimoire.Rail(frame: GuiObject, color: Color3?, radius: number, zIndex: number?): Frame
	local old = frame:FindFirstChild("GrimoireRail")
	if old then old:Destroy() end
	local inset = GildedGrimoire.RailInset
	local rail = Instance.new("Frame")
	rail.Name = "GrimoireRail"
	rail.BackgroundTransparency = 1
	rail.Position = UDim2.fromOffset(inset, inset)
	rail.Size = UDim2.new(1, -inset * 2, 1, -inset * 2)
	rail.ZIndex = zIndex or frame.ZIndex
	rail.Active = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.max(2, radius - inset))
	corner.Parent = rail
	if color then
		local stroke = Instance.new("UIStroke")
		stroke.Name = "GrimoireRailStroke"
		stroke.Color = color
		stroke.Thickness = 1.4
		stroke.Transparency = 0.3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = rail
	end
	rail.Parent = frame
	return rail
end

-- Strips a legacy frame's own UICorner / Border UIStroke, then frames it in the theme. Use this on
-- old screens: only one Border stroke can apply per object, so the old outline must go first.
function GildedGrimoire.Reframe(frame: GuiObject, opts: { Class: string?, Tone: string?, Rail: Color3?, Fill: boolean?, ZIndex: number? }?)
	for _, child in frame:GetChildren() do
		if child:IsA("UICorner") or (child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border) then
			child:Destroy()
		end
	end
	return GildedGrimoire.Frame(frame, opts)
end

-- Clear Glass panel: removes any Grimoire or legacy framing (corner, outline, gradient fill, rail),
-- then gives `frame` the glass body, a 6 px corner and one hairline stroke. opts.Accent adds a 2px
-- meaning bar down the left edge; opts.Raised uses the header/tile body; opts.Transparency
-- overrides the body (0.1–0.15 for tooltips and modals that must read on their own). Safe to call again.
function GildedGrimoire.GlassFrame(frame: GuiObject, opts: { Accent: Color3?, Raised: boolean?, Transparency: number?, Radius: number? }?)
	local o = opts or {}
	local g = GildedGrimoire.Glass
	for _, child in frame:GetChildren() do
		local legacyStroke = child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border
		local legacyFill = child:IsA("UIGradient")
		local ours = child.Name == "GrimoireRail" or child.Name == "GlassAccent"
		if child:IsA("UICorner") or legacyStroke or legacyFill or ours then
			child:Destroy()
		end
	end
	frame.BackgroundColor3 = if o.Raised then g.BaseRaised else g.Base
	frame.BackgroundTransparency = o.Transparency or (if o.Raised then g.RaisedTransparency else g.BaseTransparency)
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.Name = "GlassCorner"
	corner.CornerRadius = UDim.new(0, o.Radius or g.Radius)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Name = "GlassStroke"
	stroke.Color = g.Hairline
	stroke.Transparency = g.HairlineTransparency
	stroke.Thickness = g.StrokeThickness
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	-- Gothic HUD card: the inset gold rail inside the ink outline.
	local rail = GildedGrimoire.Rail(frame, g.Rail, o.Radius or g.Radius, frame.ZIndex)
	local railStroke = rail:FindFirstChildOfClass("UIStroke")
	if railStroke then railStroke.Transparency = g.RailTransparency end
	if o.Accent then
		local accent = Instance.new("Frame")
		accent.Name = "GlassAccent"
		accent.BackgroundColor3 = o.Accent
		accent.BorderSizePixel = 0
		accent.Position = UDim2.fromOffset(0, 6)
		accent.Size = UDim2.new(0, 2, 1, -12)
		accent.ZIndex = frame.ZIndex + 1
		accent.Active = false
		accent.Parent = frame
	end
end

-- Clear Glass text: Montserrat (Bold for "Title"/"Number", SemiBold for "Body"), no ink outline,
-- a soft dark stroke for legibility, and no gradient tint. Marks it so Watch leaves it alone.
function GildedGrimoire.GlassText(obj: TextLabel | TextButton | TextBox, role: string?)
	local g = GildedGrimoire.Glass
	obj:SetAttribute("Grimoire", true)
	pcall(function()
		(obj :: any).FontFace = if role == "Title" or role == "Number" then g.Fonts.Number else g.Fonts.Label
	end)
	for _, child in obj:GetChildren() do
		if child.Name == "GrimoireTextInk" or child:IsA("UIGradient") then child:Destroy() end
	end
	obj.TextStrokeColor3 = g.Base
	obj.TextStrokeTransparency = 0.6
end

-- GlassText for `root` and every text object inside it: big or scaled text becomes "Title".
function GildedGrimoire.GlassTexts(root: Instance)
	for _, d in { root, table.unpack(root:GetDescendants()) } do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			GildedGrimoire.GlassText(d, if d.TextScaled or d.TextSize >= 18 then "Title" else "Body")
		end
	end
end

-- Flattens a GildedGrimoire.Bar track for glass: dark track, hairline edge, flat fill, no shine.
function GildedGrimoire.GlassBar(track: Frame)
	local g = GildedGrimoire.Glass
	track.BackgroundColor3 = g.Base
	track.BackgroundTransparency = 0.2
	local ink = track:FindFirstChild("GrimoireInk") :: UIStroke?
	if ink then
		ink.Color = g.Hairline
		ink.Thickness = 1
		ink.Transparency = 0.6
	end
	local fill = track:FindFirstChild("Fill")
	if fill then
		for _, child in fill:GetChildren() do
			if child:IsA("UIGradient") or child.Name == "Shine" then child:Destroy() end
		end
	end
end

-- A pill-shaped gauge: ink-outlined dark track, a fill shaded top to bottom (its BackgroundColor3
-- stays the meaning colour, so callers can recolour it) and a white shine. Returns (track, fill);
-- size the fill with UDim2.fromScale(fraction, 1).
function GildedGrimoire.Bar(parent: Instance, color: Color3, inkWidth: number?): (Frame, Frame)
	local track = Instance.new("Frame")
	track.Name = "GrimoireBar"
	track.BackgroundColor3 = Color3.fromRGB(26, 20, 36)
	track.BorderSizePixel = 0
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(1, 0)
	tc.Parent = track
	local ink = Instance.new("UIStroke")
	ink.Name = "GrimoireInk"
	ink.Color = GildedGrimoire.Ink
	ink.Thickness = inkWidth or 1.8
	ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ink.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165))
	shade.Parent = fill
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Position = UDim2.new(0, 3, 0, 1)
	shine.Size = UDim2.new(1, -6, 0.35, 0)
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(1, 0)
	sc.Parent = shine
	shine.Parent = fill
	fill.Parent = track
	track.Parent = parent
	return track, fill
end

-- The stroke a screen should recolour for state (selected, ready, danger): the inner gold rail.
-- Recolouring the object's first UIStroke would tint the black ink outline instead.
function GildedGrimoire.StateStroke(obj: Instance): UIStroke?
	local rail = obj:FindFirstChild("GrimoireRail")
	local stroke = rail and rail:FindFirstChildWhichIsA("UIStroke")
	if stroke then return stroke end
	return obj:FindFirstChildOfClass("UIStroke")
end

-- Text roles: "Title" (heavy decorative + ink), "Number" (heavy + ink), "Body" (bold, light ink).
function GildedGrimoire.StyleText(obj: TextLabel | TextButton | TextBox, role: string?)
	local r = role or "Body"
	pcall(function()
		(obj :: any).FontFace = if r == "Title" then GildedGrimoire.Fonts.Title elseif r == "Number" then GildedGrimoire.Fonts.Number else GildedGrimoire.Fonts.Body
	end)
	-- A TextButton that already has a Border stroke (its box outline) cannot also outline its text.
	local existing = obj:FindFirstChildWhichIsA("UIStroke")
	if existing and existing.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
		return
	end
	if r == "Body" then
		obj.TextStrokeColor3 = GildedGrimoire.Ink
		obj.TextStrokeTransparency = math.min(obj.TextStrokeTransparency, 0.5)
		return
	end
	local ink = obj:FindFirstChild("GrimoireTextInk") :: UIStroke?
	if not ink then
		ink = Instance.new("UIStroke")
		ink.Name = "GrimoireTextInk"
		ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		ink.LineJoinMode = Enum.LineJoinMode.Round
		ink.Parent = obj
	end
	local size = obj.TextSize
	;(ink :: UIStroke).Color = GildedGrimoire.Ink
	;(ink :: UIStroke).Thickness = if obj.TextScaled then 2 else math.clamp(size * 0.11, 1.2, 3)
	;(ink :: UIStroke).Transparency = 0
end

-- Legacy fonts that the theme replaces, and which role each becomes.
local HEAVY_FONTS: { [Enum.Font]: boolean } = {
	[Enum.Font.GothamBlack] = true, [Enum.Font.FredokaOne] = true, [Enum.Font.LuckiestGuy] = true,
}
local BODY_FONTS: { [Enum.Font]: boolean } = {
	[Enum.Font.Gotham] = true, [Enum.Font.GothamMedium] = true, [Enum.Font.GothamBold] = true,
	[Enum.Font.GothamSemibold] = true, [Enum.Font.SourceSans] = true, [Enum.Font.SourceSansBold] = true,
	[Enum.Font.SourceSansSemibold] = true, [Enum.Font.Arial] = true, [Enum.Font.ArialBold] = true,
}

local function retheme(obj: Instance)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
	if obj:GetAttribute("Grimoire") then return end
	local legacy = obj.Font
	local family = string.lower(obj.FontFace.Family)
	local isCinzel = string.find(family, "cinzel") ~= nil
	local role: string? = nil
	if HEAVY_FONTS[legacy] then
		role = "Title"
	elseif BODY_FONTS[legacy] then
		role = if obj.TextSize >= 20 or (legacy == Enum.Font.GothamBold and obj.TextSize >= 16) then "Title" else "Body"
	elseif isCinzel then
		role = if obj.TextSize >= 16 then "Title" else "Body"
	end
	if not role then return end -- custom fonts (numbers on cards, emoji glyphs) are left alone
	obj:SetAttribute("Grimoire", true)
	GildedGrimoire.StyleText(obj :: any, role)
end

-- Re-fonts every legacy text object inside `root` now and whenever new ones are added.
function GildedGrimoire.Watch(root: Instance): RBXScriptConnection
	retheme(root)
	for _, d in root:GetDescendants() do
		retheme(d)
	end
	return root.DescendantAdded:Connect(function(d)
		if not (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) then return end
		if d:GetAttribute("Grimoire") then return end
		-- Wait a frame so builders finish setting Font/TextSize before we inspect them.
		task.defer(retheme, d)
	end)
end

return GildedGrimoire
