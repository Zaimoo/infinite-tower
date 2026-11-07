--!strict
-- StarterPlayerScripts/UI/Settings/SettingsComponents.luau
-- Clean Clear Glass UI Components for Settings UI.
-- Translucent frosted dark crystal cards, gold/amber luminous accents, and 0%-100% exact edge-snap sliders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local Grimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Hud = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Components"))

local e = React.createElement
local useState = React.useState
local useCallback = React.useCallback
local useEffect = React.useEffect
local useRef = React.useRef

local HeavyLabel = Hud.HeavyLabel
local Body = Hud.Body
local INK = Grimoire.Ink

local SettingsComponents = {}

SettingsComponents.HeavyLabel = HeavyLabel
SettingsComponents.Body = Body

local function numberLabel(props: { [string]: any })
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Grimoire.Fonts.Number,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props) do base[k] = v end
	return e("TextLabel", base, {
		Ink = e("UIStroke", { Color = INK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round }),
	})
end
SettingsComponents.Number = numberLabel

--------------------------------------------------------------------------------
-- 1. Section Container Card (Clear Frosted Glass Panel)
--------------------------------------------------------------------------------
function SettingsComponents.Section(props: {
	Title: string,
	Subtitle: string?,
	LayoutOrder: number?,
	Children: any?,
})
	local content: { [string]: any } = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		GlassStroke = e("UIStroke", {
			Thickness = 1,
			Color = Color3.fromRGB(255, 255, 255),
			Transparency = 0.78,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 14),
		}),
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Header = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, if props.Subtitle then 42 else 24),
			LayoutOrder = 0,
		}, {
			Title = HeavyLabel({
				Size = UDim2.new(1, 0, 0, 22),
				MaxSize = 19,
				Outline = 2.2,
				TextXAlignment = Enum.TextXAlignment.Left,
				Text = props.Title,
			}),
			Subtitle = if props.Subtitle then Body({
				Position = UDim2.fromOffset(0, 24),
				Size = UDim2.new(1, 0, 0, 16),
				TextSize = 13,
				TextColor3 = Grimoire.Text.Muted,
				Text = props.Subtitle,
			}) else nil,
		}),
	}

	for k, v in pairs(props.Children or {}) do
		content[tostring(k)] = v
	end

	return e("Frame", {
		Name = "Section_" .. props.Title,
		BackgroundColor3 = Color3.fromRGB(22, 18, 34),
		BackgroundTransparency = 0.55,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder or 1,
	}, content)
end

--------------------------------------------------------------------------------
-- 2. Interactive Slider (Clear Glass Track + Gold-Amber Fill + 0% Edge-Snap)
--------------------------------------------------------------------------------
function SettingsComponents.Slider(props: {
	Label: string,
	Description: string?,
	Value: number, -- 0 to 1
	DisplayValue: string?,
	AccentColor: Color3,
	LayoutOrder: number?,
	OnChange: (number) -> (),
})
	local isDragging, setDragging = useState(false)
	local trackRef = useRef(nil :: Frame?)

	local updateFromPos = useCallback(function(inputX: number)
		local track = trackRef.current
		if not track then return end
		local absPos = track.AbsolutePosition.X
		local absSize = track.AbsoluteSize.X
		if absSize <= 0 then return end

		local rawAlpha = (inputX - absPos) / math.max(absSize, 1)
		-- Exact Edge-Snap Deadzone (guarantees exact 0% and 100%)
		if rawAlpha <= 0.015 then
			rawAlpha = 0
		elseif rawAlpha >= 0.985 then
			rawAlpha = 1
		end

		local percent = math.round(math.clamp(rawAlpha, 0, 1) * 100)
		props.OnChange(percent / 100)
	end, { props.OnChange })

	-- Global mouse movement listener while dragging to ensure smooth dragging across screen
	useEffect(function()
		if not isDragging then return end

		local moveConn = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				updateFromPos(input.Position.X)
			end
		end)

		local endConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				setDragging(false)
			end
		end)

		return function()
			moveConn:Disconnect()
			endConn:Disconnect()
		end
	end, { isDragging, updateFromPos })

	local clampedValue = math.clamp(props.Value, 0, 1)
	local display = props.DisplayValue or string.format("%d%%", math.round(clampedValue * 100))

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
			Label = Body({
				Size = UDim2.new(0.65, 0, 1, 0),
				TextSize = 15,
				TextColor3 = Grimoire.Text.Parchment,
				Text = props.Label,
			}),
			Percent = numberLabel({
				Text = display,
				TextSize = 16,
				TextColor3 = props.AccentColor,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(0.65, 0, 0, 0),
				Size = UDim2.new(0.35, 0, 1, 0),
			}),
		}),
		Track = e("Frame", {
			ref = trackRef,
			Name = "Track",
			BackgroundColor3 = Color3.fromRGB(8, 6, 14),
			BackgroundTransparency = 0.45,
			Position = UDim2.new(0, 2, 0, 30),
			Size = UDim2.new(1, -4, 0, 14),
			[React.Event.InputBegan] = function(_rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setDragging(true)
					updateFromPos(input.Position.X)
				end
			end,
		}, {
			TrackCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			TrackStroke = e("UIStroke", {
				Thickness = 1,
				Color = Color3.fromRGB(255, 255, 255),
				Transparency = 0.82,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Fill = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(253, 224, 71),
				BackgroundTransparency = 0.12,
				Size = UDim2.new(clampedValue, 0, 1, 0),
			}, {
				FillCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				FillGradient = e("UIGradient", {
					Rotation = 0,
					Color = ColorSequence.new(Color3.fromRGB(253, 224, 71), Color3.fromRGB(217, 119, 6)),
				}),
			}),
			Knob = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(clampedValue, 0, 0.5, 0),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = Color3.fromRGB(250, 204, 21),
				ZIndex = 4,
			}, {
				KnobCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				KnobStroke = e("UIStroke", {
					Thickness = 1.5,
					Color = Color3.fromRGB(255, 255, 255),
					Transparency = 0.3,
				}),
				KnobGradient = e("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(217, 119, 6)),
				}),
			}),
		}),
	})
end

--------------------------------------------------------------------------------
-- 3. Interactive Toggle Switch (Clear Glass Pill + Gold Indicator)
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
		Size = UDim2.new(1, 0, 0, if props.Description then 40 else 32),
		LayoutOrder = props.LayoutOrder or 1,
		[React.Event.Activated] = props.OnToggle,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
	}, {
		TextGroup = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -70, 1, 0),
		}, {
			Title = Body({
				Size = UDim2.new(1, 0, 0, 20),
				TextSize = 15,
				TextColor3 = if isHovered then Color3.new(1, 1, 1) else Grimoire.Text.Parchment,
				Text = props.Label,
			}),
			Desc = if props.Description then Body({
				Position = UDim2.fromOffset(0, 21),
				Size = UDim2.new(1, 0, 0, 16),
				TextSize = 12,
				TextColor3 = Grimoire.Text.Muted,
				Text = props.Description,
			}) else nil,
		}),
		Pill = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(52, 28),
			BackgroundColor3 = if props.Value then Color3.fromRGB(228, 186, 115) else Color3.fromRGB(18, 14, 26),
			BackgroundTransparency = if props.Value then 0.20 else 0.50,
		}, {
			PillCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			PillStroke = e("UIStroke", {
				Thickness = 1.2,
				Color = if props.Value then Color3.fromRGB(254, 240, 138) else Color3.fromRGB(255, 255, 255),
				Transparency = if props.Value then 0.20 else 0.78,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			Dot = e("Frame", {
				AnchorPoint = if props.Value then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
				Position = if props.Value then UDim2.new(1, -3, 0.5, 0) else UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = if props.Value then Color3.fromRGB(255, 250, 235) else Color3.fromRGB(120, 115, 135),
			}, {
				DotCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				DotStroke = e("UIStroke", {
					Thickness = 1,
					Color = if props.Value then Color3.fromRGB(250, 204, 21) else Color3.fromRGB(255, 255, 255),
					Transparency = if props.Value then 0.3 else 0.7,
				}),
				DotGradient = if props.Value then e("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(240, 196, 110)),
				}) else nil,
			}),
		}),
	})
end

--------------------------------------------------------------------------------
-- 4. Sidebar Navigation Tab Button (Clear Glass Card + Gold Accent Rim)
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

	return e("TextButton", {
		Name = "Tab_" .. props.Name,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 56),
		Text = "",
		BackgroundColor3 = if props.IsActive then Color3.fromRGB(38, 28, 58) else Color3.fromRGB(22, 18, 34),
		BackgroundTransparency = if props.IsActive then 0.35 elseif isHovered then 0.38 else 0.55,
		LayoutOrder = props.LayoutOrder or 1,
		[React.Event.Activated] = props.OnClick,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = if props.IsActive then 1.2 else 1,
			Color = if props.IsActive then Color3.fromRGB(250, 204, 21) elseif isHovered then Color3.fromRGB(250, 204, 21) else Color3.fromRGB(255, 255, 255),
			Transparency = if props.IsActive then 0.25 elseif isHovered then 0.50 else 0.78,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Title = HeavyLabel({
			Position = UDim2.fromOffset(16, 8),
			Size = UDim2.new(1, -28, 0, 20),
			MaxSize = 17,
			Outline = 2,
			Gold = props.IsActive,
			TextColor3 = if props.IsActive then Color3.fromRGB(254, 240, 138) else Grimoire.Text.Parchment,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = props.Name,
			ZIndex = 3,
		}),
		Sub = Body({
			Position = UDim2.fromOffset(16, 30),
			Size = UDim2.new(1, -28, 0, 16),
			TextSize = 12,
			ZIndex = 3,
			TextColor3 = if props.IsActive then Color3.fromRGB(228, 186, 115) else Grimoire.Text.Muted,
			Text = props.Subtitle,
		}),
	})
end

--------------------------------------------------------------------------------
-- 5. Stat Card (For Overview: Clear Glass Metric Box)
--------------------------------------------------------------------------------
function SettingsComponents.StatCard(props: {
	Title: string,
	Value: string,
	Subtext: string,
	AccentColor: Color3,
	LayoutOrder: number?,
})
	return e("Frame", {
		Name = "StatCard_" .. props.Title,
		Size = UDim2.new(0.31, 0, 0, 88),
		BackgroundColor3 = Color3.fromRGB(22, 18, 34),
		BackgroundTransparency = 0.55,
		LayoutOrder = props.LayoutOrder or 1,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = 1,
			Color = Color3.fromRGB(255, 255, 255),
			Transparency = 0.78,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Title = Body({
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -28, 0, 15),
			TextSize = 12,
			TextColor3 = Grimoire.Text.Muted,
			Text = props.Title,
			ZIndex = 3,
		}),
		Value = numberLabel({
			Position = UDim2.fromOffset(14, 28),
			Size = UDim2.new(1, -28, 0, 28),
			TextSize = 24,
			TextColor3 = Color3.fromRGB(250, 204, 21),
			Text = props.Value,
			ZIndex = 3,
		}),
		Sub = Body({
			Position = UDim2.fromOffset(14, 60),
			Size = UDim2.new(1, -28, 0, 15),
			TextSize = 12,
			TextColor3 = Grimoire.Text.Parchment,
			Text = props.Subtext,
			ZIndex = 3,
		}),
	})
end

--------------------------------------------------------------------------------
-- 6. Action Button (Reset, Apply, Presets: Clear Glass with Gold/Amethyst glow)
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

	local bgColor = if isPrimary then Color3.fromRGB(112, 64, 180) else Color3.fromRGB(22, 18, 34)
	local bgTrans = if isPrimary then (if isHovered then 0.15 else 0.25) else (if isHovered then 0.35 else 0.50)
	local strokeColor = if isPrimary then Color3.fromRGB(250, 204, 21) elseif isHovered then Color3.fromRGB(250, 204, 21) else Color3.fromRGB(255, 255, 255)
	local strokeTrans = if isPrimary then 0.20 elseif isHovered then 0.30 else 0.75

	return e("TextButton", {
		Name = "Btn_" .. props.Text,
		AutoButtonColor = false,
		Size = props.Size or UDim2.new(0, 130, 0, 38),
		Text = "",
		BackgroundColor3 = bgColor,
		BackgroundTransparency = bgTrans,
		LayoutOrder = props.LayoutOrder or 1,
		[React.Event.Activated] = props.OnClick,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = if isPrimary or isHovered then 1.2 else 1,
			Color = strokeColor,
			Transparency = strokeTrans,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Label = HeavyLabel({
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 1, -8),
			MaxSize = 15,
			Outline = 2,
			Gold = false,
			TextColor3 = if isPrimary or isHovered then Color3.new(1, 1, 1) else Grimoire.Text.Parchment,
			Text = props.Text,
			ZIndex = 3,
		}),
	})
end

return SettingsComponents
