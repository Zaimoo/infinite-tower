--!strict
-- ReplicatedFirst/LoadingScreen/LoadingScreenView.luau
-- Builds the join loading screen: a dark violet backdrop with a slowly turning gold rune ring and
-- drifting specks, the studio logo, a "Creekian Studios" label, a loading bar, a status line and a
-- Skip button. ReplicatedFirst runs before ReplicatedStorage arrives, so the Gilded Grimoire tokens
-- this needs are copied here (source: ReplicatedStorage/Shared/Util/GildedGrimoire.luau, Violet/Gold
-- tones and Ink; fonts as in GothicFont.luau).

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Paste the uploaded studio logo here ("rbxassetid://..."). Empty shows the framed "CS" monogram.
local LOGO_IMAGE = ""

local INK = Color3.fromRGB(10, 6, 14)
local VIOLET_TOP = Color3.fromRGB(58, 38, 88)
local VIOLET_BOTTOM = Color3.fromRGB(20, 14, 32)
local GOLD = Color3.fromRGB(240, 196, 110)
local GOLD_TOP = Color3.fromRGB(255, 220, 110)
local GOLD_BOTTOM = Color3.fromRGB(214, 128, 24)
local GOLD_PALE = Color3.fromRGB(255, 248, 200)
local MUTED = Color3.fromRGB(190, 176, 214)

local TITLE_FONT = Font.fromName("CinzelDecorative", Enum.FontWeight.Heavy)
local BODY_FONT = Font.fromName("Cinzel", Enum.FontWeight.Bold)

local SPECK_COUNT = 16
local NARROW_WIDTH = 600

export type View = {
	PreloadTargets: { Instance },
	SetProgress: (self: View, alpha: number) -> (),
	SetStatus: (self: View, text: string) -> (),
	ShowSkip: (self: View, onSkip: () -> ()) -> (),
	FadeOut: (self: View, duration: number) -> (),
	Destroy: (self: View) -> (),
}

local View = {}

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function textStroke(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = INK
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
end

local function screenGui(name: string, displayOrder: number, insets: Enum.ScreenInsets, playerGui: Instance): (ScreenGui, CanvasGroup)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = displayOrder
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = insets
	-- A CanvasGroup root lets the whole screen fade as one; it only lives for the join.
	local root = Instance.new("CanvasGroup")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	gui.Parent = playerGui
	return gui, root
end

-- Background: violet-to-ink gradient, vignette, gold rune ring and drifting specks. Full-bleed.
local function buildBackground(root: CanvasGroup): (Frame, { Frame })
	local fill = Instance.new("Frame")
	fill.Name = "Backdrop"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = root
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, VIOLET_TOP),
		ColorSequenceKeypoint.new(0.55, VIOLET_BOTTOM),
		ColorSequenceKeypoint.new(1, INK),
	})
	g.Rotation = 90
	g.Parent = fill

	-- Vignette: an ink frame that is clear in the middle and dark at the edges.
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = INK
	vignette.BorderSizePixel = 0
	vignette.Parent = root
	local vg = Instance.new("UIGradient")
	vg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	vg.Parent = vignette

	-- Rune ring behind the logo: two thin gold circles with diamond pips, turned slowly.
	local ring = Instance.new("Frame")
	ring.Name = "RuneRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.42)
	ring.Size = UDim2.fromScale(0.62, 0.62)
	ring.SizeConstraint = Enum.SizeConstraint.RelativeYY
	ring.BackgroundTransparency = 1
	ring.Parent = root
	corner(ring, UDim.new(0.5, 0))
	stroke(ring, GOLD, 2, 0.8)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.86, 0.86)
	inner.BackgroundTransparency = 1
	inner.Parent = ring
	corner(inner, UDim.new(0.5, 0))
	stroke(inner, GOLD, 1, 0.88)
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local pip = Instance.new("Frame")
		pip.Name = "Pip"
		pip.AnchorPoint = Vector2.new(0.5, 0.5)
		pip.Position = UDim2.fromScale(0.5 + 0.5 * math.cos(angle), 0.5 + 0.5 * math.sin(angle))
		pip.Size = UDim2.fromScale(0.026, 0.026)
		pip.Rotation = 45
		pip.BackgroundColor3 = GOLD
		pip.BackgroundTransparency = 0.6
		pip.BorderSizePixel = 0
		pip.Parent = ring
	end

	local specks: { Frame } = {}
	local rng = Random.new()
	for i = 1, SPECK_COUNT do
		local speck = Instance.new("Frame")
		speck.Name = "Speck"
		speck.AnchorPoint = Vector2.new(0.5, 0.5)
		speck.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
		local px = rng:NextInteger(2, 4)
		speck.Size = UDim2.fromOffset(px, px)
		speck.BackgroundColor3 = GOLD_PALE
		speck.BackgroundTransparency = rng:NextNumber(0.45, 0.8)
		speck.BorderSizePixel = 0
		speck:SetAttribute("Speed", rng:NextNumber(0.012, 0.035))
		speck:SetAttribute("Sway", rng:NextNumber(0, math.pi * 2))
		speck.Parent = root
		corner(speck, UDim.new(0.5, 0))
		specks[i] = speck
	end

	return ring, specks
end

function View.new(playerGui: Instance): View
	local bgGui, bgRoot = screenGui("LoadingScreen", 1000, Enum.ScreenInsets.None, playerGui)
	local contentGui, contentRoot = screenGui("LoadingScreenContent", 1001, Enum.ScreenInsets.CoreUISafeInsets, playerGui)
	local ring, specks = buildBackground(bgRoot)

	-- Content column, centred inside the safe area.
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.5)
	column.Size = UDim2.fromScale(0.9, 0.9)
	column.BackgroundTransparency = 1
	column.Parent = contentRoot
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.018, 0)
	list.Parent = column
	local columnScale = Instance.new("UIScale")
	columnScale.Parent = column

	-- Logo: the uploaded image, or a Gilded framed box with a "CS" monogram as the placeholder.
	local logo = Instance.new("ImageLabel")
	logo.Name = "Logo"
	logo.LayoutOrder = 1
	logo.Size = UDim2.fromScale(0.22, 0.22)
	logo.SizeConstraint = Enum.SizeConstraint.RelativeYY
	logo.BackgroundTransparency = 1
	logo.Image = LOGO_IMAGE
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Parent = column
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = logo
	local logoSize = Instance.new("UISizeConstraint")
	logoSize.MinSize = Vector2.new(96, 96)
	logoSize.MaxSize = Vector2.new(260, 260)
	logoSize.Parent = logo
	local logoScale = Instance.new("UIScale")
	logoScale.Parent = logo
	if LOGO_IMAGE == "" then
		logo.BackgroundTransparency = 0
		logo.BackgroundColor3 = Color3.new(1, 1, 1)
		gradient(logo, VIOLET_TOP, VIOLET_BOTTOM)
		corner(logo, UDim.new(0.16, 0))
		stroke(logo, INK, 4)
		local rail = Instance.new("Frame")
		rail.Name = "Rail"
		rail.AnchorPoint = Vector2.new(0.5, 0.5)
		rail.Position = UDim2.fromScale(0.5, 0.5)
		rail.Size = UDim2.new(1, -14, 1, -14)
		rail.BackgroundTransparency = 1
		rail.Parent = logo
		corner(rail, UDim.new(0.13, 0))
		stroke(rail, GOLD, 2)
		local monogram = Instance.new("TextLabel")
		monogram.Name = "Monogram"
		monogram.AnchorPoint = Vector2.new(0.5, 0.5)
		monogram.Position = UDim2.fromScale(0.5, 0.5)
		monogram.Size = UDim2.fromScale(0.7, 0.5)
		monogram.BackgroundTransparency = 1
		monogram.FontFace = TITLE_FONT
		monogram.Text = "CS"
		monogram.TextScaled = true
		monogram.TextColor3 = GOLD_TOP
		monogram.Parent = logo
		textStroke(monogram, 3)
	end

	local title = Instance.new("TextLabel")
	title.Name = "StudioName"
	title.LayoutOrder = 2
	title.Size = UDim2.fromScale(0.7, 0.07)
	title.BackgroundTransparency = 1
	title.FontFace = TITLE_FONT
	title.Text = "Creekian Studios"
	title.TextScaled = true
	title.TextColor3 = GOLD_TOP
	title.Parent = column
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MinTextSize = 18
	titleSize.MaxTextSize = 40
	titleSize.Parent = title
	textStroke(title, 2.5)
	gradient(title, GOLD_PALE, GOLD)

	local spacer = Instance.new("Frame")
	spacer.Name = "Spacer"
	spacer.LayoutOrder = 3
	spacer.Size = UDim2.fromScale(1, 0.02)
	spacer.BackgroundTransparency = 1
	spacer.Parent = column

	-- Loading bar: ink-outlined track with a gold gradient fill driven by Size.X.Scale.
	local track = Instance.new("Frame")
	track.Name = "BarTrack"
	track.LayoutOrder = 4
	track.Size = UDim2.new(0.46, 0, 0, 14)
	track.BackgroundColor3 = INK
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = column
	corner(track, UDim.new(0.5, 0))
	stroke(track, GOLD, 1.5, 0.35)
	local trackSize = Instance.new("UISizeConstraint")
	trackSize.MinSize = Vector2.new(200, 14)
	trackSize.MaxSize = Vector2.new(520, 14)
	trackSize.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, UDim.new(0.5, 0))
	gradient(fill, GOLD_TOP, GOLD_BOTTOM)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.LayoutOrder = 5
	status.Size = UDim2.new(0.6, 0, 0, 22)
	status.BackgroundTransparency = 1
	status.FontFace = BODY_FONT
	status.TextSize = 16
	status.TextColor3 = MUTED
	status.Text = "Opening the gates…"
	status.Parent = column
	textStroke(status, 1.5)

	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.LayoutOrder = 6
	skip.Size = UDim2.fromOffset(132, 44)
	skip.BackgroundColor3 = Color3.new(1, 1, 1)
	skip.FontFace = BODY_FONT
	skip.TextSize = 18
	skip.TextColor3 = GOLD_PALE
	skip.Text = "Skip"
	skip.AutoButtonColor = true
	skip.Selectable = true
	skip.Visible = false
	skip.Parent = column
	gradient(skip, VIOLET_TOP, VIOLET_BOTTOM)
	corner(skip, UDim.new(0, 10))
	stroke(skip, GOLD, 2)
	textStroke(skip, 1.5)

	-- Narrow screens (phones in portrait) get a slightly smaller column.
	local function refit()
		columnScale.Scale = if contentGui.AbsoluteSize.X > 0 and contentGui.AbsoluteSize.X < NARROW_WIDTH then 0.85 else 1
	end
	local sizeConn = contentGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()

	local clock = 0
	local fading = false
	local renderConn = RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		ring.Rotation = (clock * 6) % 360
		if not fading then
			logoScale.Scale = 1 + 0.015 * (1 + math.sin(clock * 2.2))
		end
		for _, speck in specks do
			local pos = speck.Position
			local speed = (speck:GetAttribute("Speed") :: number?) or 0.02
			local sway = (speck:GetAttribute("Sway") :: number?) or 0
			local y = pos.Y.Scale - speed * dt
			local x = pos.X.Scale + math.sin(clock * 0.8 + sway) * 0.004 * dt
			if y < -0.02 then
				y = 1.02
			end
			speck.Position = UDim2.fromScale(x, y)
		end
	end)

	local skipConn: RBXScriptConnection? = nil
	local destroyed = false

	local self = {} :: View
	self.PreloadTargets = { logo, title, status }

	function self.SetProgress(_: View, alpha: number)
		fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	end

	function self.SetStatus(_: View, text: string)
		if status.Text ~= text then
			status.Text = text
		end
	end

	function self.ShowSkip(_: View, onSkip: () -> ())
		if skip.Visible or destroyed then
			return
		end
		skip.Visible = true
		skip.TextTransparency = 1
		skip.BackgroundTransparency = 1
		TweenService:Create(skip, TweenInfo.new(0.35), { TextTransparency = 0, BackgroundTransparency = 0 }):Play()
		skipConn = skip.Activated:Connect(onSkip)
		GuiService.SelectedObject = skip
	end

	function self.FadeOut(_: View, duration: number)
		if GuiService.SelectedObject == skip then
			GuiService.SelectedObject = nil
		end
		skip.Active = false
		fading = true
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(logoScale, info, { Scale = 1.08 }):Play()
		TweenService:Create(contentRoot, info, { GroupTransparency = 1 }):Play()
		local bgTween = TweenService:Create(bgRoot, info, { GroupTransparency = 1 })
		bgTween:Play()
		bgTween.Completed:Wait()
	end

	function self.Destroy(_: View)
		if destroyed then
			return
		end
		destroyed = true
		renderConn:Disconnect()
		sizeConn:Disconnect()
		if skipConn then
			skipConn:Disconnect()
		end
		bgGui:Destroy()
		contentGui:Destroy()
	end

	return self
end

return View
