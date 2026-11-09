--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local React = require(ReplicatedStorage.Packages.React)
local Config = require(ReplicatedStorage.Shared.Config.GuideConfig)
local Components = require(script.Parent.Components)
local Theme = require(script.Parent.Theme)

local e = React.createElement
local G = Theme.Glass
local lessons = { Config.Ready, Config.Visit, Config.Clear, Config.Return, Config.Bank, Config.Summon, Config.Equip,
	Config.Upgrade, Config.GuardPost, Config.Tree, Config.Market, Config.TrainingGrounds, Config.GodsBlessing,
	Config.Synthesis, Config.Promotion, Config.Raid }

return function(props: { OnClose: () -> (), OnResume: () -> () })
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
		Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for i, lesson in lessons do
		rows[lesson.Id] = e("Frame", { Size = UDim2.new(1, -10, 0, 68), BackgroundTransparency = 1, LayoutOrder = i }, {
			Title = Components.GlassText({ Text = lesson.Title, TextSize = 16, Size = UDim2.new(1, 0, 0, 23), TextColor3 = G.Royal }),
			Copy = Components.GlassText({ Text = lesson.Description, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
				TextSize = 14, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 42) }),
		})
	end
	return e("Frame", { Name = "GuideHelp", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 30 }, {
		Scrim = e("TextButton", { Text = "", AutoButtonColor = false, Selectable = false, Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.35, [React.Event.Activated] = props.OnClose }),
		Window = Components.Glass({
			Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0.86, 0, 0.82, 0), ZIndex = 32,
		}, {
			Limit = e("UISizeConstraint", { MaxSize = Vector2.new(480, 560) }),
			Header = Components.GlassText({ Text = "Fortress Guide", TextSize = 20, TextColor3 = G.Royal,
				Position = UDim2.fromOffset(16, 5), Size = UDim2.new(1, -32, 0, 44) }),
			List = e("ScrollingFrame", { Position = UDim2.fromOffset(16, 49), Size = UDim2.new(1, -32, 1, -111),
				BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(), ScrollBarThickness = 5 }, rows),
			Resume = e("TextButton", { ref = focus, Text = "Resume hints", TextSize = 15, TextColor3 = G.Royal,
				BackgroundColor3 = G.BaseRaised, FontFace = G.Fonts.Number, Selectable = true,
				Position = UDim2.new(0, 16, 1, -52), Size = UDim2.new(0.58, -20, 0, 44), [React.Event.Activated] = props.OnResume }),
			Close = e("TextButton", { Text = "Close", TextSize = 15, TextColor3 = G.Royal,
				BackgroundColor3 = G.BaseRaised, FontFace = G.Fonts.Number, Selectable = true,
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -52), Size = UDim2.new(0.42, -20, 0, 44),
				[React.Event.Activated] = props.OnClose }),
		}),
	})
end
