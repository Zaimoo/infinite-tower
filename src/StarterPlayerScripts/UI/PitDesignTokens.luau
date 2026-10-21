--!strict
-- Local visual vocabulary for The Pit. No global HUD restyling.
local T = {}
T.Color = {
	Obsidian = Color3.fromRGB(18, 19, 23), Panel = Color3.fromRGB(27, 28, 32),
	Raised = Color3.fromRGB(36, 36, 40), Bronze = Color3.fromRGB(155, 119, 76),
	Gold = Color3.fromRGB(220, 190, 133), Text = Color3.fromRGB(240, 235, 225),
	Muted = Color3.fromRGB(181, 179, 175), Edge = Color3.fromRGB(77, 72, 64),
	Good = Color3.fromRGB(150, 212, 169), Danger = Color3.fromRGB(239, 158, 145),
	Memory = Color3.fromRGB(169, 187, 226),
}
T.Rarity = {
	Color3.fromRGB(160, 128, 100), Color3.fromRGB(181, 193, 201),
	Color3.fromRGB(115, 165, 218), Color3.fromRGB(180, 142, 218), Color3.fromRGB(228, 193, 111),
}
T.Gap = 12
T.PageSize = 8
T.Text = {Title = 24, Heading = 15, Body = 14, Caption = 12, Large = 16}
T.Radius = {Window = 12, Panel = 10, Control = 7}
T.Duration = {Preview = 0.3, Ritual = 1.1, Debounce = 0.16}
T.Layer = {Modal = 20, Content = 22, Ritual = 60, Confirmation = 70}

function T.New(className: string, props: any, parent: Instance?): any
	local node = Instance.new(className)
	for key, value in props do (node :: any)[key] = value end
	node.Parent = parent
	return node
end

function T.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return T.New("UIStroke", {Color = color or T.Color.Edge, Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, parent)
end

function T.Corner(parent: Instance, radius: number?)
	T.New("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end

function T.Panel(parent: Instance, name: string): Frame
	local f = T.New("Frame", {Name = name, BorderSizePixel = 0, BackgroundColor3 = T.Color.Panel}, parent)
	T.Corner(f, T.Radius.Panel)
	T.Stroke(f)
	return f
end

function T.Label(parent: Instance, text: string, size: number?, color: Color3?): TextLabel
	return T.New("TextLabel", {
		BackgroundTransparency = 1, BorderSizePixel = 0, Text = text,
		TextColor3 = color or T.Color.Text, Font = Enum.Font.Gotham,
		TextSize = size or T.Text.Body, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.new(1, 0, 0, 24),
	}, parent)
end

function T.Button(parent: Instance, text: string, callback: (() -> ())?): TextButton
	local b = T.New("TextButton", {
		Text = text, TextColor3 = T.Color.Text, Font = Enum.Font.GothamMedium, TextSize = T.Text.Body,
		TextWrapped = true, AutoButtonColor = true, BackgroundColor3 = T.Color.Raised,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 44), Selectable = true,
	}, parent)
	T.Corner(b, T.Radius.Control)
	T.Stroke(b)
	if callback then b.Activated:Connect(callback) end
	return b
end

function T.Scroll(parent: Instance, name: string): ScrollingFrame
	return T.New("ScrollingFrame", {
		Name = name, BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.Color.Bronze, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
end

function T.List(parent: Instance, padding: number?)
	T.New("UIListLayout", {Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder}, parent)
end

function T.Number(value: any): string
 return require(game:GetService("ReplicatedStorage").Shared.Config.StatBalance).Format(tonumber(value) or 0)
end

function T.Stars(stars: number?): string
	return string.rep("★", math.clamp(stars or 1, 1, 5))
end

return T
