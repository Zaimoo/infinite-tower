--!strict
-- StarterPlayerScripts/UI/Settings/SettingsComponents.luau
-- Reusable React Luau Components for Settings UI, drawn in the Gilded Grimoire theme: ink-outlined
-- panels with an inset gold rail, heavy inked titles, Cinzel body text and pill gauges. The player's
-- accent colour (SettingsConfig.THEMES) tints rails, fills and highlights.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local Grimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Hud = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Components"))

local e = React.createElement
local useState = React.useState
local useCallback = React.useCallback
local useRef = React.useRef

local Panel = Hud.Panel
local HeavyLabel = Hud.HeavyLabel
local Body = Hud.Body
local INK = Grimoire.Ink
local T = Grimoire.Tones

local SettingsComponents = {}

-- Shared look for the whole Settings screen.
SettingsComponents.Panel = Panel
SettingsComponents.HeavyLabel = HeavyLabel
SettingsComponents.Body = Body

local function numberLabel(props: { [string]: any })
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Grimoire.Fonts.Number,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in props do base[k] = v end
	return e("TextLabel", base, {
		Ink = e("UIStroke", { Color = INK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round }),
	})
end
SettingsComponents.Number = numberLabel

--------------------------------------------------------------------------------
-- 1. Section Container Card (Deep panel; content sits in an inner frame so the rail is not laid out)
--------------------------------------------------------------------------------
function SettingsComponents.Section(props: {
	Title: string,
	Subtitle: string?,
	LayoutOrder: number?,
	Children: any?,
})
	local content: { [string]: any } = {
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 16),
		}),
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Header = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, if props.Subtitle then 42 else 24),
			LayoutOrder = 1,
		}, {
			Title = HeavyLabel({ Size = UDim2.new(1, 0, 0, 22), MaxSize = 19, Outline = 2.2, TextXAlignment = Enum.TextXAlignment.Left, Text = props.Title }),
			Subtitle = if props.Subtitle then Body({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16), TextSize = 13,
				TextColor3 = Grimoire.Text.Muted, Text = props.Subtitle }) else nil,
		}),
	}
	for k, v in pairs(props.Children or {}) do
		content[tostring(k)] = v
	end

	return Panel({
		Name = "Section_" .. props.Title,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder or 1,
		Top = T.Deep.Top, Bottom = T.Deep.Bottom, Rail = T.Deep.Rail,
	}, {
		Content = e("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 2 }, content),
	})
end

--------------------------------------------------------------------------------
-- 2. Interactive Slider (pill gauge with an ink outline and a gold knob)
--------------------------------------------------------------------------------
function SettingsComponents.Slider(props: {
	Label: string,
	Description: string?,
	Value: number, -- 0 to 1
	AccentColor: Color3,
	LayoutOrder: number?,
	OnChange: (number) -> (),
})
	local isDragging, setDragging = useState(false)
	local trackRef = useRef(nil :: Frame?)

	local updateFromInput = useCallback(function(inputPos: Vector3)
		local track = trackRef.current
		if not track then return end
		local absPos = track.AbsolutePosition.X
		local absSize = track.AbsoluteSize.X
		if absSize <= 0 then return end
		local ratio = math.clamp((inputPos.X - absPos) / absSize, 0, 1)
		props.OnChange(ratio)
	end, { props.OnChange })

	return e("Frame", {
		Name = "Slider_" .. props.Label,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		LayoutOrder = props.LayoutOrder or 1,
	}, {
		Header = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
		}, {
			Label = Body({ Size = UDim2.new(0.7, 0, 1, 0), TextSize = 15, TextColor3 = Grimoire.Text.Parchment, Text = props.Label }),
			Percent = numberLabel({
				Text = string.format("%d%%", math.round(props.Value * 100)),
				TextSize = 17,
				TextColor3 = props.AccentColor,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(0.7, 0, 0, 0),
				Size = UDim2.new(0.3, 0, 1, 0),
			}),
		}),
		Track = e("Frame", {
			ref = trackRef,
			Name = "Track",
			BackgroundColor3 = Color3.fromRGB(26, 20, 36),
			Position = UDim2.new(0, 2, 0, 30),
			Size = UDim2.new(1, -4, 0, 14),
			[React.Event.InputBegan] = function(_rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setDragging(true)
					updateFromInput(input.Position)
				end
			end,
			[React.Event.InputEnded] = function(_rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setDragging(false)
				end
			end,
			[React.Event.InputChanged] = function(_rbx, input)
				if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					updateFromInput(input.Position)
				end
			end,
		}, {
			TrackCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			TrackInk = e("UIStroke", { Thickness = 2, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Fill = e("Frame", {
				BackgroundColor3 = props.AccentColor,
				Size = UDim2.new(props.Value, 0, 1, 0),
			}, {
				FillCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Shade = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165)) }),
				Shine = e("Frame", { Position = UDim2.new(0, 3, 0, 1), Size = UDim2.new(1, -6, 0.35, 0), BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.6, BorderSizePixel = 0 }, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
			}),
			Knob = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(props.Value, 0, 0.5, 0),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ZIndex = 3,
			}, {
				KnobCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				KnobFill = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.Gold.Top, T.Gold.Bottom) }),
				KnobInk = e("UIStroke", { Thickness = 2.4, Color = INK }),
			}),
		}),
	})
end

--------------------------------------------------------------------------------
-- 3. Interactive Toggle Switch (ink-outlined pill; the gold knob slides right when on)
--------------------------------------------------------------------------------
function SettingsComponents.Toggle(props: {
	Label: string,
	Description: string?,
	Value: boolean,
	AccentColor: Color3,
	LayoutOrder: number?,
	OnToggle: () -> (),
})
	local isHovered, setHovered = useState(false)

	return e("TextButton", {
		Name = "Toggle_" .. props.Label,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, if props.Description then 46 else 34),
		LayoutOrder = props.LayoutOrder or 1,
		[React.Event.Activated] = props.OnToggle,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
	}, {
		TextGroup = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -70, 1, 0),
		}, {
			Title = Body({ Size = UDim2.new(1, 0, 0, 20), TextSize = 15,
				TextColor3 = if isHovered then Color3.new(1, 1, 1) else Grimoire.Text.Parchment, Text = props.Label }),
			Desc = if props.Description then Body({ Position = UDim2.fromOffset(0, 21), Size = UDim2.new(1, 0, 0, 16), TextSize = 12,
				TextColor3 = Grimoire.Text.Muted, Text = props.Description }) else nil,
		}),
		Pill = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(54, 28),
			BackgroundColor3 = if props.Value then props.AccentColor else Color3.fromRGB(34, 28, 46),
		}, {
			PillCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			PillShade = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 165)) }),
			PillInk = e("UIStroke", { Thickness = 2.4, Color = INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Dot = e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = if props.Value then UDim2.new(1, -24, 0.5, 0) else UDim2.new(0, 4, 0.5, 0),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Color3.new(1, 1, 1),
			}, {
				DotCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				DotFill = e("UIGradient", { Rotation = 90, Color = if props.Value then ColorSequence.new(T.Gold.Top, T.Gold.Bottom)
					else ColorSequence.new(Color3.fromRGB(196, 190, 206), Color3.fromRGB(104, 96, 118)) }),
				DotInk = e("UIStroke", { Thickness = 2, Color = INK }),
			}),
		}),
	})
end

--------------------------------------------------------------------------------
-- 4. Sidebar Navigation Tab Button (active: violet panel with an accent rail and gold title)
--------------------------------------------------------------------------------
function SettingsComponents.TabButton(props: {
	Name: string,
	Subtitle: string,
	IsActive: boolean,
	AccentColor: Color3,
	LayoutOrder: number?,
	OnClick: () -> (),
})
	local isHovered, setHovered = useState(false)
	local tone = if props.IsActive then T.Violet else T.Deep

	return Panel({
		Class = "TextButton",
		Name = "Tab_" .. props.Name,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 56),
		Text = "",
		Radius = 10,
		Top = tone.Top, Bottom = tone.Bottom,
		Rail = if props.IsActive then props.AccentColor elseif isHovered then Grimoire.Text.Muted else Color3.fromRGB(110, 96, 140),
		LayoutOrder = props.LayoutOrder or 1,
		[React.Event.Activated] = props.OnClick,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
	}, {
		Title = HeavyLabel({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -28, 0, 20), MaxSize = 17, Outline = 2,
			Gold = props.IsActive, TextColor3 = if props.IsActive then Color3.new(1, 1, 1) else Grimoire.Text.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left, Text = props.Name, ZIndex = 3 }),
		Sub = Body({ Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -28, 0, 16), TextSize = 12, ZIndex = 3,
			TextColor3 = if props.IsActive then Grimoire.Text.Gold else Grimoire.Text.Muted, Text = props.Subtitle }),
	})
end

--------------------------------------------------------------------------------
-- 5. Stat Card (For Overview)
--------------------------------------------------------------------------------
function SettingsComponents.StatCard(props: {
	Title: string,
	Value: string,
	Subtext: string,
	AccentColor: Color3,
	LayoutOrder: number?,
})
	return Panel({
		Name = "StatCard_" .. props.Title,
		Size = UDim2.new(0.31, 0, 0, 88),
		LayoutOrder = props.LayoutOrder or 1,
		Radius = 12,
		Top = T.Deep.Top, Bottom = T.Deep.Bottom, Rail = T.Deep.Rail,
	}, {
		Title = Body({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 15), TextSize = 12, TextColor3 = Grimoire.Text.Muted, Text = props.Title, ZIndex = 3 }),
		Value = numberLabel({ Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 28), TextSize = 26,
			TextColor3 = props.AccentColor, Text = props.Value, ZIndex = 3 }),
		Sub = Body({ Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -28, 0, 15), TextSize = 12, Text = props.Subtext, ZIndex = 3 }),
	})
end

--------------------------------------------------------------------------------
-- 6. Action Button (Reset, Apply, Presets): Action amethyst when primary, slate otherwise.
-- The label is a child (a gradient on the button itself would tint its text).
--------------------------------------------------------------------------------
function SettingsComponents.ActionButton(props: {
	Text: string,
	Primary: boolean?,
	AccentColor: Color3,
	Size: UDim2?,
	LayoutOrder: number?,
	OnClick: () -> (),
})
	local isHovered, setHovered = useState(false)
	local isPrimary = props.Primary == true
	local tone = if isPrimary then T.Action else T.Slate

	return Panel({
		Class = "TextButton",
		Name = "Btn_" .. props.Text,
		AutoButtonColor = false,
		Size = props.Size or UDim2.new(0, 130, 0, 38),
		Text = "",
		Radius = 10,
		Top = tone.Top, Bottom = tone.Bottom,
		Rail = if isHovered then Color3.fromRGB(255, 240, 190) elseif isPrimary then T.Action.Rail else props.AccentColor,
		LayoutOrder = props.LayoutOrder or 1,
		[React.Event.Activated] = props.OnClick,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
	}, {
		Label = HeavyLabel({ Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 1, -8), MaxSize = 15, Outline = 2,
			Gold = false, Text = props.Text, ZIndex = 3 }),
	})
end

return SettingsComponents
