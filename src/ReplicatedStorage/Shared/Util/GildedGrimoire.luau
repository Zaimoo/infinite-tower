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

-- Frames a GuiObject in the theme: ink outline, gold rail, gradient fill, rounded corners.
-- opts.Class picks InkWidth/Radius ("Panel" default); opts.Tone a key of Tones; opts.Rail overrides
-- the rail colour; opts.Fill = false keeps the object's own background. Safe to call again.
function GildedGrimoire.Frame(frame: GuiObject, opts: { Class: string?, Tone: string?, Rail: Color3?, Fill: boolean?, ZIndex: number? }?)
	local o = opts or {}
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
		-- Wait a frame so builders finish setting Font/TextSize before we inspect them.
		task.defer(retheme, d)
	end)
end

return GildedGrimoire
