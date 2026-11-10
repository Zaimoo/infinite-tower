--!strict
-- The Guide help panel (Left Rail > Guide): every lesson in order, core chain first, with a way to
-- bring back hints that were put off and a way out of the tutorial.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local React = require(ReplicatedStorage.Packages.React)
local Config = require(ReplicatedStorage.Shared.Config.GuideConfig)
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)
local WindowScale = require(script.Parent.Parent.WindowScale)

local e = React.createElement
local G = Theme.Glass

return function(props: { OnClose: () -> (), OnResume: () -> (), OnSkip: (() -> ())?, Facts: { [string]: boolean }? })
	local focus = React.useRef(nil :: GuiButton?)
	React.useEffect(function()
		if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad and focus.current then
			GuiService.SelectedObject = focus.current
		end
		local input = UserInputService.InputBegan:Connect(function(key)
			if key.KeyCode == Enum.KeyCode.Escape or key.KeyCode == Enum.KeyCode.ButtonB then props.OnClose() end
		end)
		return function() input:Disconnect() end
	end, {})

	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for i, lesson in Config.Ordered do
		local step = if lesson.Core then string.format("%d. ", lesson.Index or i) else ""
		rows[lesson.Id] = e("Frame", { Size = UDim2.new(1, -10, 0, 46), BackgroundTransparency = 1, LayoutOrder = i }, {
			Title = Components.GlassText({ Text = step .. lesson.Title, TextSize = 16, Size = UDim2.new(1, 0, 0, 22), TextColor3 = G.Royal }),
			Copy = Components.GlassText({ Text = lesson.Description, TextSize = 14, Position = UDim2.fromOffset(0, 23), Size = UDim2.new(1, 0, 0, 20) }),
		})
	end
	local function action(name: string, text: string, order: number, onActivated: () -> (), ref: any?)
		return e("TextButton", { ref = ref, Name = name, LayoutOrder = order, Text = text, TextSize = 15, TextColor3 = G.Royal,
			BackgroundColor3 = G.BaseRaised, FontFace = G.Fonts.Number, Selectable = true, Size = UDim2.fromScale(0, 1),
			[React.Event.Activated] = onActivated }, { Grow = e("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) })
	end
	return e("Frame", { Name = "GuideHelp", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 30 }, {
		Scrim = e("TextButton", { Text = "", AutoButtonColor = false, Selectable = false, Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.35, [React.Event.Activated] = props.OnClose }),
		Window = Components.Glass({
			Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0.86, 0, 0.82, 0), ZIndex = 32,
		}, {
			Limit = e("UISizeConstraint", { MaxSize = Vector2.new(480, 560) }),
			Pop = e(WindowScale, {}),
			Header = Components.GlassText({ Text = "Guide", TextSize = 20, TextColor3 = G.Royal,
				Position = UDim2.fromOffset(16, 5), Size = UDim2.new(1, -32, 0, 44) }),
			List = e("ScrollingFrame", { Position = UDim2.fromOffset(16, 49), Size = UDim2.new(1, -32, 1, -111),
				BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(), ScrollBarThickness = 5 }, rows),
			Actions = e("Frame", { Position = UDim2.new(0, 16, 1, -52), Size = UDim2.new(1, -32, 0, 44), BackgroundTransparency = 1 }, {
				Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
				Resume = action("ResumeHints", "Show hints", 1, props.OnResume, focus),
				Skip = if props.OnSkip then action("SkipTutorial", "Skip tutorial", 2, props.OnSkip) else nil,
				Close = action("CloseGuide", "Close", 3, props.OnClose),
			}),
		}),
	})
end
