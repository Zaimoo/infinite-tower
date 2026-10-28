--!strict
-- StarterPlayerScripts/UI/Hud/Gothic.luau
-- React bridges to the shared gothic UI kit (GothicBoxStyle / GothicFont), so Phase 5 screens use
-- the same obsidian fill, white rails and diamond corners as the Synthesis and Promotion screens.
-- The kit decorates an instance imperatively; these components apply it through a ref after mount
-- and whenever the style inputs change. React never owns the decoration children it adds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Util = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util")
local GothicBoxStyle = require(Util:WaitForChild("GothicBoxStyle"))
local GothicFont = require(Util:WaitForChild("GothicFont"))

local e = React.createElement

local Gothic = {}

Gothic.Palette = GothicBoxStyle.Palette

local STYLE_KEYS = { GothicStyle = true, Variant = true, Disabled = true, Accent = true }

-- A Frame or TextButton decorated with a gothic box style.
-- props.Class: "Frame" | "TextButton" (default Frame); props.GothicStyle: Window/Card/Panel/Row/Slot/
-- ButtonPrimary/ButtonSecondary/Button/Compact; props.Variant (e.g. "Gold", "Violet"); props.Disabled.
function Gothic.Box(props: { [any]: any })
	local ref = React.useRef(nil)
	React.useEffect(function()
		local inst = ref.current
		if inst then
			GothicBoxStyle.Apply(inst, {
				Style = props.GothicStyle or "Panel",
				Variant = props.Variant,
				Disabled = props.Disabled,
				AccentColor = props.Accent,
				ZIndex = props.ZIndex,
			})
		end
	end, { props.GothicStyle, props.Variant, props.Disabled, props.Accent })
	local inst: { [any]: any } = { ref = ref, BorderSizePixel = 0 }
	for k, v in props do
		if not STYLE_KEYS[k] and k ~= "Class" then inst[k] = v end
	end
	if (props.Class or "Frame") == "TextButton" then
		inst.Text = inst.Text or ""
		inst.AutoButtonColor = if inst.AutoButtonColor == nil then false else inst.AutoButtonColor
	end
	-- Children arrive as props.children (copied into `inst` above). Passing a third argument here,
	-- even nil, would replace them, so the box would render empty.
	return e(props.Class or "Frame", inst)
end

-- A TextLabel in the gothic typography. props.Role: Title/Header/SubHeader/Body/Button/Nav;
-- props.Spaced spaces the letters like the screen titles ("S Y N T H E S I S").
function Gothic.Label(props: { [string]: any })
	local ref = React.useRef(nil)
	React.useEffect(function()
		local inst = ref.current
		if inst then
			GothicFont.Apply(inst, {
				Role = props.Role or "Body",
				Color = props.Color,
				Size = props.TextSize,
				Spaced = props.Spaced,
				Uppercase = props.Uppercase,
			})
		end
	end, { props.Role, props.Color, props.TextSize, props.Spaced, props.Uppercase, props.Text })
	local inst: { [string]: any } = { ref = ref, BackgroundTransparency = 1, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd }
	for k, v in props do
		if k ~= "Role" and k ~= "Color" and k ~= "Spaced" and k ~= "Uppercase" then inst[k] = v end
	end
	inst.TextColor3 = props.Color or inst.TextColor3
	return e("TextLabel", inst)
end

Gothic.Spaced = GothicFont.FormatSpaced

return Gothic
