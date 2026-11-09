--!strict
-- StarterPlayerScripts/UI/Kit/Callout.luau
-- A warning that sits next to the action it is about (plan §4.4), replacing footer status text.
-- Severities: "info" (azure), "warn" (amber, slow pulse), "block" (crimson; pair it with a disabled
-- primary button carrying the same reason). An optional fix-it link: "Need 2,400 more Gold · Get Gold".
--
--   local c = Callout.Create(parent, { Severity = "block", Text = "Inventory full", ActionText = "Sell weapons", OnAction = openSell })
--   c.Update({ Text = nil })   -- hides it

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local UIFeel = require(script.Parent.Parent:WaitForChild("UIFeel"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))

local New = Tokens.New

export type Props = {
	Severity: ("info" | "warn" | "block" | "success")?,
	Text: string?, -- nil hides the callout
	ActionText: string?,
	OnAction: (() -> ())?,
	Height: number?, -- default 40
	Name: string?,
	Position: UDim2?,
	Width: UDim?,
	LayoutOrder: number?,
	ZIndex: number?,
}
export type Handle = { Instance: Frame, Update: (Props) -> (), Destroy: () -> () }

local Callout = {}

function Callout.Create(parent: Instance?, initial: Props): Handle
	local props: Props = table.clone(initial)
	local frame: Frame = New("Frame", {})
	local accent = New("Frame", { Name = "Accent", BorderSizePixel = 0, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(0, 4, 1, -12) }, frame)
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, accent)
	local label = Tokens.Label(frame, "", 15, "Body", { Name = "Text", Position = UDim2.fromOffset(46, 0), TextWrapped = true })
	local link: TextButton = New("TextButton", {
		Name = "Fix", AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28),
		FontFace = Tokens.Fonts.Title, TextSize = 15, TextColor3 = Tokens.Text.Gold, TextStrokeColor3 = Tokens.Ink, TextStrokeTransparency = 0.2,
	}, frame)
	link.Activated:Connect(function() if props.OnAction then props.OnAction() end end)
	local icon: Frame? = nil
	local iconName: string? = nil
	local stopPulse: (() -> ())? = nil

	local function pulse(stroke: UIStroke)
		local alive = true
		task.spawn(function()
			while alive and frame.Parent do
				local a = TweenService:Create(stroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { Transparency = 0.6 })
				a:Play()
				a.Completed:Wait()
				if not alive then break end
				local b = TweenService:Create(stroke, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { Transparency = 0 })
				b:Play()
				b.Completed:Wait()
			end
		end)
		return function() alive = false end
	end

	local function render()
		local severity = props.Severity or "info"
		local color = Tokens.Severity[severity] or Tokens.Severity.info
		local z = props.ZIndex or 1
		frame.Name = props.Name or "KitCallout"
		frame.Visible = props.Text ~= nil and props.Text ~= ""
		frame.Position = props.Position or UDim2.new()
		frame.Size = UDim2.new(props.Width or UDim.new(1, 0), UDim.new(0, props.Height or 40))
		frame.LayoutOrder = props.LayoutOrder or 0
		frame.ZIndex = z
		Tokens.Paint(frame, Tokens.Surface.Inset, Tokens.Radius.Tile, 2, 1)
		local ink = frame:FindFirstChild("KitInk") :: UIStroke
		-- The outline carries the severity colour (pulsing for warnings) instead of plain ink.
		ink.Color = color
		ink.Thickness = 2
		accent.BackgroundColor3 = color
		accent.ZIndex = z + 1
		local wantIcon = Tokens.SeverityIcon[severity] or "Warning"
		if wantIcon ~= iconName then
			if icon then icon:Destroy() end
			icon = GrimoireIcons.Create(wantIcon, 24, frame, z + 2)
			local i = icon :: Frame
			i.AnchorPoint = Vector2.new(0, 0.5)
			i.Position = UDim2.new(0, 16, 0.5, 0)
			iconName = wantIcon
		end
		link.Visible = props.ActionText ~= nil
		link.Text = if props.ActionText then props.ActionText .. "  ›" else ""
		link.ZIndex = z + 2
		label.ZIndex = z + 2
		label.Text = props.Text or ""
		label.TextColor3 = if severity == "block" then Tokens.Text.White else Tokens.Text.Parchment
		-- Leave room for the icon on the left and, when present, the fix-it link on the right.
		label.Size = UDim2.new(1, if props.ActionText then -(58 + 170) else -58, 1, 0)
		if stopPulse then stopPulse() stopPulse = nil end
		if severity == "warn" and frame.Visible and not UIFeel.ReducedMotion() then stopPulse = pulse(ink) end
	end

	render()
	if parent then frame.Parent = parent end
	return {
		Instance = frame,
		Update = function(changes: Props)
			for k, v in changes :: any do (props :: any)[k] = v end
			render()
		end,
		Destroy = function()
			if stopPulse then stopPulse() end
			frame:Destroy()
		end,
	}
end

return table.freeze(Callout)
