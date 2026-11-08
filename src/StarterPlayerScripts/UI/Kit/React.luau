--!strict
-- StarterPlayerScripts/UI/Kit/React.luau
-- React bridges for the kit's building blocks, so React screens and imperative screens draw the
-- same pieces. Each component renders a transparent host Frame and drives the builder through its
-- handle: Create on mount, Update when props change, Destroy on unmount. React never owns the
-- builder's children.
--
--   e(KitReact.Button, { Size = UDim2.new(1, 0, 0, 44), Text = "Promote", Intent = "Primary", OnActivate = promote })
--   e(KitReact.Bar, { Size = UDim2.new(1, 0, 0, 22), Fraction = 0.4, Label = "40%" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local Button = require(script.Parent:WaitForChild("Button"))
local Bar = require(script.Parent:WaitForChild("Bar"))
local DeltaStat = require(script.Parent:WaitForChild("DeltaStat"))
local CurrencyChip = require(script.Parent:WaitForChild("CurrencyChip"))
local Callout = require(script.Parent:WaitForChild("Callout"))

local e = React.createElement

-- Host-frame props React applies itself; everything else goes to the builder.
local HOST_KEYS = { Size = true, Position = true, AnchorPoint = true, LayoutOrder = true, Visible = true, ZIndex = true }

type Builder = { Create: (Instance?, any) -> { Instance: GuiObject, Update: (any) -> (), Destroy: () -> () } }

-- Wraps a builder. `fill` decides how the built piece sits in the host: "Fill" stretches it to the
-- host (buttons, bars, callouts); "Fixed" keeps its own size (chips).
local function wrap(builder: Builder, fill: "Fill" | "Fixed", name: string)
	return function(props: { [string]: any })
		local hostRef = React.useRef(nil)
		local handleRef = React.useRef(nil)
		local builderProps: { [string]: any } = {}
		for k, v in props do
			if not HOST_KEYS[k] and k ~= "children" then builderProps[k] = v end
		end
		if fill == "Fill" then
			builderProps.Width = UDim.new(1, 0)
			builderProps.Position = UDim2.new()
		end
		builderProps.ZIndex = props.ZIndex

		React.useEffect(function()
			local host = hostRef.current
			if not host then return nil end
			local handle = builder.Create(host, builderProps)
			if fill == "Fill" then
				-- Buttons and bars size their height from props; let the host decide instead.
				handle.Instance.Size = UDim2.fromScale(1, 1)
			end
			handleRef.current = handle
			return function()
				handle.Destroy()
				handleRef.current = nil
			end
		end, {})

		React.useEffect(function()
			local handle = handleRef.current
			if handle then
				handle.Update(builderProps)
				if fill == "Fill" then handle.Instance.Size = UDim2.fromScale(1, 1) end
			end
		end)

		return e("Frame", {
			ref = hostRef,
			Name = props.Name and (props.Name .. "Host") or name,
			BackgroundTransparency = 1,
			Size = props.Size or (if fill == "Fixed" then UDim2.new() else UDim2.new(1, 0, 0, 44)),
			AutomaticSize = if fill == "Fixed" and props.Size == nil then Enum.AutomaticSize.XY else nil,
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			LayoutOrder = props.LayoutOrder,
			Visible = props.Visible,
			ZIndex = props.ZIndex,
		})
	end
end

local KitReact = {
	Button = wrap(Button :: any, "Fill", "KitButtonHost"),
	Bar = wrap(Bar :: any, "Fill", "KitBarHost"),
	DeltaStat = wrap(DeltaStat :: any, "Fill", "KitDeltaHost"),
	CurrencyChip = wrap(CurrencyChip :: any, "Fixed", "KitChipHost"),
	Callout = wrap(Callout :: any, "Fill", "KitCalloutHost"),
}

return table.freeze(KitReact)
