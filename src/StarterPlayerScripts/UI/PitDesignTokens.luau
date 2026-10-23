--!strict
-- StarterPlayerScripts/UI/PitDesignTokens.luau
-- Visual vocabulary and design tokens featuring Gothic Box Container styling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GothicBoxStyle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GothicBoxStyle"))

local T = {}
T.Color = {
	Obsidian = Color3.fromRGB(14, 11, 22),
	Panel = Color3.fromRGB(18, 14, 28),
	Raised = Color3.fromRGB(26, 20, 38),
	Bronze = Color3.fromRGB(155, 119, 76),
	Gold = Color3.fromRGB(250, 204, 21),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(165, 155, 185),
	Edge = Color3.fromRGB(255, 255, 255),
	Purple = Color3.fromRGB(192, 132, 252),
	Good = Color3.fromRGB(74, 222, 128),
	Danger = Color3.fromRGB(239, 68, 68),
	Memory = Color3.fromRGB(169, 187, 226),
}

T.Rarity = {
	Color3.fromRGB(160, 128, 100),
	Color3.fromRGB(181, 193, 201),
	Color3.fromRGB(115, 165, 218),
	Color3.fromRGB(180, 142, 218),
	Color3.fromRGB(228, 193, 111),
}

T.Gap = 12
T.PageSize = 8
T.Text = { Title = 24, Heading = 15, Body = 14, Caption = 12, Large = 16 }
T.Radius = { Window = 8, Panel = 6, Control = 5 }
T.Duration = { Preview = 0.3, Ritual = 1.1, Debounce = 0.16 }
T.Layer = { Modal = 20, Content = 22, Ritual = 60, Confirmation = 70 }

function T.New(className: string, props: any, parent: Instance?): any
	local node = Instance.new(className)
	for key, value in props do
		(node :: any)[key] = value
	end
	node.Parent = parent
	return node
end

function T.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return T.New("UIStroke", {
		Color = color or T.Color.Edge,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function T.Corner(parent: Instance, radius: number?)
	T.New("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

-- Creates an Ornate Gothic Window Container Modal
function T.Window(parent: Instance, name: string): Frame
	local f = T.New("Frame", {
		Name = name,
		BorderSizePixel = 0,
		BackgroundColor3 = T.Color.Obsidian,
	}, parent)
	GothicBoxStyle.Apply(f, { Style = "Window" })
	return f
end

-- Creates an Ornate Gothic Card Container
function T.Panel(parent: Instance, name: string): Frame
	local f = T.New("Frame", {
		Name = name,
		BorderSizePixel = 0,
		BackgroundColor3 = T.Color.Obsidian,
	}, parent)
	GothicBoxStyle.Apply(f, { Style = "Card" })
	return f
end

function T.Label(parent: Instance, text: string, size: number?, color: Color3?): TextLabel
	local lbl = T.New("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = color or T.Color.Text,
		Font = GothicBoxStyle.Font.LegacyFont or Enum.Font.GothamBold,
		TextSize = size or T.Text.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24),
	}, parent)
	GothicBoxStyle.Font.Apply(lbl, {
		Role = if (size and size >= 18) then "Title" else "Body",
		Color = color or T.Color.Text,
		Size = size or T.Text.Body,
	})
	return lbl
end

-- Creates an Ornate Gothic Action Button
function T.Button(parent: Instance, text: string, callback: (() -> ())?): TextButton
	local b = T.New("TextButton", {
		Text = text,
		TextColor3 = T.Color.Text,
		Font = GothicBoxStyle.Font.LegacyFont or Enum.Font.GothamBold,
		TextSize = T.Text.Body,
		TextWrapped = true,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 44),
		Selectable = true,
	}, parent)
	GothicBoxStyle.Font.Apply(b, {
		Role = "Button",
		Color = T.Color.Text,
		Size = T.Text.Body,
		Uppercase = true,
	})
	GothicBoxStyle.Apply(b, { Style = "Button", OnClick = callback })
	return b
end

function T.Scroll(parent: Instance, name: string): ScrollingFrame
	return T.New("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.Color.Purple,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
end

function T.List(parent: Instance, padding: number?)
	T.New("UIListLayout", { Padding = UDim.new(0, padding or 8), SortOrder = Enum.SortOrder.LayoutOrder }, parent)
end

function T.Number(value: any): string
	return require(game:GetService("ReplicatedStorage").Shared.Config.StatBalance).Format(tonumber(value) or 0)
end

function T.Stars(stars: number?): string
	return string.rep("★", math.clamp(stars or 1, 1, 5))
end

return T
