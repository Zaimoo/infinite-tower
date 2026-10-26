--!strict
-- StarterPlayerScripts/UI/Settings/SettingsComponents.luau
-- Reusable React Luau Components for Settings UI

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local SettingsConfig = require(script.Parent:WaitForChild("SettingsConfig"))

local e = React.createElement
local useState = React.useState
local useCallback = React.useCallback
local useRef = React.useRef

local SettingsComponents = {}

--------------------------------------------------------------------------------
-- 1. Section Container Card
--------------------------------------------------------------------------------
function SettingsComponents.Section(props: {
	Title: string,
	Subtitle: string?,
	LayoutOrder: number?,
	Children: any?,
})
	local children = props.Children or {}
	local cardChildren: { [string]: any } = {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
		Stroke = e("UIStroke", {
			Thickness = 1.2,
			Color = Color3.fromRGB(38, 48, 76),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
		}),
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Header = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, if props.Subtitle then 36 else 22),
			LayoutOrder = 1,
		}, {
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				Text = props.Title,
				Font = Enum.Font.GothamBlack,
				TextSize = 16,
				TextColor3 = Color3.fromRGB(240, 244, 255),
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 18),
			}),
			Subtitle = props.Subtitle and e("TextLabel", {
				BackgroundTransparency = 1,
				Text = props.Subtitle,
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(135, 150, 180),
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(0, 18),
				Size = UDim2.new(1, 0, 0, 16),
			}),
		}),
	}

	for k, v in pairs(children) do
		cardChildren[tostring(k)] = v
	end

	return e("Frame", {
		Name = "Section_" .. props.Title,
		BackgroundColor3 = Color3.fromRGB(12, 17, 30),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder or 1,
	}, cardChildren)
end

--------------------------------------------------------------------------------
-- 2. Interactive Slider
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
		Size = UDim2.new(1, 0, 0, 52),
		LayoutOrder = props.LayoutOrder or 1,
	}, {
		Header = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
		}, {
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				Text = props.Label,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextColor3 = Color3.fromRGB(230, 235, 250),
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(0.7, 0, 1, 0),
			}),
			Percent = e("TextLabel", {
				BackgroundTransparency = 1,
				Text = string.format("%d%%", math.round(props.Value * 100)),
				Font = Enum.Font.GothamBlack,
				TextSize = 13,
				TextColor3 = props.AccentColor,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(0.7, 0, 0, 0),
				Size = UDim2.new(0.3, 0, 1, 0),
			}),
		}),
		Track = e("Frame", {
			ref = trackRef,
			Name = "Track",
			BackgroundColor3 = Color3.fromRGB(20, 28, 48),
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 0, 12),
			[React.Event.InputBegan] = function(rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setDragging(true)
					updateFromInput(input.Position)
				end
			end,
			[React.Event.InputEnded] = function(rbx, input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					setDragging(false)
				end
			end,
			[React.Event.InputChanged] = function(rbx, input)
				if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					updateFromInput(input.Position)
				end
			end,
		}, {
			TrackCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			TrackStroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(40, 54, 85) }),
			Fill = e("Frame", {
				BackgroundColor3 = props.AccentColor,
				Size = UDim2.new(props.Value, 0, 1, 0),
			}, {
				FillCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Knob = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(props.Value, 0, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			}, {
				KnobCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				KnobStroke = e("UIStroke", { Thickness = 2, Color = props.AccentColor }),
			}),
		}),
	})
end

--------------------------------------------------------------------------------
-- 3. Interactive Toggle Switch
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
		Size = UDim2.new(1, 0, 0, if props.Description then 44 else 34),
		LayoutOrder = props.LayoutOrder or 1,
		[React.Event.Activated] = props.OnToggle,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
	}, {
		TextGroup = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -60, 1, 0),
		}, {
			Title = e("TextLabel", {
				BackgroundTransparency = 1,
				Text = props.Label,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextColor3 = if isHovered then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(225, 230, 245),
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 18),
			}),
			Desc = props.Description and e("TextLabel", {
				BackgroundTransparency = 1,
				Text = props.Description,
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = Color3.fromRGB(130, 145, 175),
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(0, 18),
				Size = UDim2.new(1, 0, 0, 16),
			}),
		}),
		Pill = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(48, 26),
			BackgroundColor3 = if props.Value then props.AccentColor else Color3.fromRGB(24, 32, 54),
		}, {
			PillCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			PillStroke = e("UIStroke", {
				Thickness = 1.2,
				Color = if props.Value then props.AccentColor else Color3.fromRGB(44, 58, 92),
			}),
			Dot = e("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = if props.Value then UDim2.new(1, -22, 0.5, 0) else UDim2.new(0, 4, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = if props.Value then Color3.fromRGB(15, 20, 35) else Color3.fromRGB(140, 155, 185),
			}, {
				DotCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	})
end

--------------------------------------------------------------------------------
-- 4. Sidebar Navigation Tab Button
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
		BackgroundColor3 = if props.IsActive then Color3.fromRGB(22, 34, 60) elseif isHovered then Color3.fromRGB(16, 24, 44) else Color3.fromRGB(10, 15, 28),
		Size = UDim2.new(1, 0, 0, 52),
		Text = "",
		LayoutOrder = props.LayoutOrder or 1,
		[React.Event.Activated] = props.OnClick,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = e("UIStroke", {
			Thickness = if props.IsActive then 1.5 else 1,
			Color = if props.IsActive then props.AccentColor else Color3.fromRGB(30, 42, 68),
		}),
		Indicator = e("Frame", {
			Position = UDim2.new(0, 4, 0.2, 0),
			Size = UDim2.new(0, 4, 0.6, 0),
			BackgroundColor3 = props.AccentColor,
			Visible = props.IsActive,
		}, {
			IndCorner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 12),
		}),
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			Text = props.Name,
			Font = Enum.Font.GothamBlack,
			TextSize = 15,
			TextColor3 = if props.IsActive then props.AccentColor else Color3.fromRGB(230, 235, 248),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 18),
		}),
		Sub = e("TextLabel", {
			BackgroundTransparency = 1,
			Text = props.Subtitle,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = if props.IsActive then Color3.fromRGB(180, 205, 240) else Color3.fromRGB(120, 135, 165),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 16),
		}),
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
	return e("Frame", {
		Name = "StatCard_" .. props.Title,
		BackgroundColor3 = Color3.fromRGB(15, 22, 38),
		Size = UDim2.new(0.31, 0, 0, 84),
		LayoutOrder = props.LayoutOrder or 1,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = e("UIStroke", { Thickness = 1, Color = Color3.fromRGB(36, 48, 78) }),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
		Title = e("TextLabel", {
			BackgroundTransparency = 1,
			Text = props.Title,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(140, 155, 185),
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 14),
		}),
		Value = e("TextLabel", {
			BackgroundTransparency = 1,
			Text = props.Value,
			Font = Enum.Font.GothamBlack,
			TextSize = 22,
			TextColor3 = props.AccentColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(0, 16),
			Size = UDim2.new(1, 0, 0, 26),
		}),
		Sub = e("TextLabel", {
			BackgroundTransparency = 1,
			Text = props.Subtext,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(160, 175, 205),
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 14),
		}),
	})
end

--------------------------------------------------------------------------------
-- 6. Action Button (Reset, Apply, Presets)
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

	return e("TextButton", {
		Name = "Btn_" .. props.Text,
		AutoButtonColor = false,
		BackgroundColor3 = if isPrimary then props.AccentColor elseif isHovered then Color3.fromRGB(28, 40, 68) else Color3.fromRGB(18, 25, 44),
		Size = props.Size or UDim2.new(0, 130, 0, 38),
		Text = props.Text,
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = if isPrimary then Color3.fromRGB(10, 15, 25) else Color3.fromRGB(230, 235, 250),
		LayoutOrder = props.LayoutOrder or 1,
		[React.Event.Activated] = props.OnClick,
		[React.Event.MouseEnter] = function() setHovered(true) end,
		[React.Event.MouseLeave] = function() setHovered(false) end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = e("UIStroke", {
			Thickness = 1.2,
			Color = if isPrimary then props.AccentColor else Color3.fromRGB(45, 60, 95),
		}),
	})
end

return SettingsComponents
