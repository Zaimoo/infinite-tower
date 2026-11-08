--!strict
-- StarterPlayerScripts/UI/Kit/Button.luau
-- The one button (UI overhaul plan §3.3). The intent sets its colour: Primary (gold, the window's main
-- action), Confirm (jade), Travel (azure), Secondary (violet), Danger (crimson). A disabled button is
-- slate with a lock, never gold, and always carries a Reason: shown on hover and after a tap.
--
--   local b = Button.Create(parent, { Text = "Promote", Intent = "Primary", OnActivate = promote })
--   b.Update({ Disabled = true, Reason = "Need 3 more Promotion Stones" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local UIFeel = require(script.Parent.Parent:WaitForChild("UIFeel"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Tooltip = require(script.Parent:WaitForChild("Tooltip"))

local New = Tokens.New

export type Props = {
	Text: string?,
	Intent: Tokens.Intent?,
	Size: ("L" | "M" | "S")?, -- height 56 / 44 / 36
	Width: UDim?, -- default: fill the parent's width
	Icon: string?, -- GrimoireIcons name, drawn left of the text
	Disabled: boolean?,
	Reason: string?, -- why it's disabled (or a hint when enabled)
	Subtitle: string?, -- small second line, e.g. "+4.28M power"
	OnActivate: (() -> ())?,
	Name: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
}
export type Handle = { Instance: TextButton, Update: (Props) -> (), Destroy: () -> () }

local Button = {}

function Button.Create(parent: Instance?, initial: Props): Handle
	local props: Props = table.clone(initial)
	local button: TextButton = New("TextButton", { Text = "", AutoButtonColor = false, Selectable = true })
	local content = New("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Active = false }, button)
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, content)
	local textCol = New("Frame", { Name = "TextColumn", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, Active = false }, content)
	New("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, textCol)
	local label = Tokens.Label(textCol, "", 18, "Title", {
		Name = "Label", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Center,
	})
	local subtitle = Tokens.Label(textCol, "", 13, "Body", {
		Name = "Subtitle", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Center,
	})
	local icon: Frame? = nil
	local iconName: string? = nil
	local unbindTip = Tooltip.Bind(button, function()
		return if props.Reason then { Reason = if props.Disabled then props.Reason else nil, Body = if props.Disabled then nil else props.Reason } else nil
	end)

	local function render()
		local size = props.Size or "M"
		local height = Tokens.ButtonHeight[size]
		local disabled = props.Disabled == true
		local intent = if disabled then "Disabled" else (props.Intent or "Secondary")
		local tone = Tokens.Intent[intent]
		button.Name = props.Name or Tokens.Name("KitButton", props.Text)
		button.Size = UDim2.new(props.Width or UDim.new(1, 0), UDim.new(0, height))
		button.Position = props.Position or UDim2.new()
		button.AnchorPoint = props.AnchorPoint or Vector2.zero
		button.LayoutOrder = props.LayoutOrder or 0
		button.ZIndex = props.ZIndex or 1
		button.Active = true
		Tokens.Paint(button, tone, Tokens.Radius.Button, if size == "S" then 2 else 2.5, if disabled then 0.6 else 0.1)
		label.Text = props.Text or ""
		label.TextSize = if size == "L" then 22 elseif size == "M" then 18 else 15
		label.TextColor3 = if disabled then Tokens.Text.Muted else Tokens.Text.White
		label.TextStrokeTransparency = if disabled then 0.7 else 0
		label.ZIndex = button.ZIndex + 2
		subtitle.Visible = props.Subtitle ~= nil
		subtitle.Text = props.Subtitle or ""
		subtitle.TextColor3 = if disabled then Tokens.Text.Muted else Tokens.Text.Parchment
		subtitle.ZIndex = button.ZIndex + 2
		-- Icon: the requested one, or a lock while disabled.
		local wanted = if disabled and props.Reason then "Lock" else props.Icon
		if wanted ~= iconName then
			if icon then icon:Destroy() end
			icon = if wanted then GrimoireIcons.Create(wanted, if size == "S" then 18 else 24, content, button.ZIndex + 2) else nil
			if icon then icon.LayoutOrder = 1 end
			iconName = wanted
		end
		content.ZIndex = button.ZIndex + 1
	end

	button.Activated:Connect(function()
		if props.Disabled then
			UIFeel.Deny(button)
			if props.Reason then Tooltip.Flash(button, { Reason = props.Reason }) end
			return
		end
		if props.OnActivate then props.OnActivate() end
	end)

	render()
	if parent then button.Parent = parent end

	local handle: Handle = {
		Instance = button,
		Update = function(changes: Props)
			for k, v in changes :: any do (props :: any)[k] = v end
			render()
		end,
		Destroy = function()
			unbindTip()
			button:Destroy()
		end,
	}
	return handle
end

return table.freeze(Button)
