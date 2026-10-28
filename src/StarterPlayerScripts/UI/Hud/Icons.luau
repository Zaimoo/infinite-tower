--!strict
-- StarterPlayerScripts/UI/Hud/Icons.luau
-- Custom gothic HUD icons drawn from GUI shapes, in the chunky "toy" style of the rail reference:
-- every shape has a top-lit gradient, a thick black outline and a soft highlight. Icons are designed
-- on a 64 x 64 grid and scaled with UIScale (outlines scale with it). No image assets needed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local e = React.createElement

local Icons = {}

-- The drawings are shared with imperative screens (ReplicatedStorage/Shared/Util/GrimoireIcons).
local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local OUTLINE = GrimoireIcons.Ink

type ShapeSpec = GrimoireIcons.ShapeSpec

local function shape(s: ShapeSpec, z: number)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(s.X, s.Y),
		Size = UDim2.fromOffset(s.W, s.H),
		Rotation = s.Rot or 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z,
	}, {
		Corner = e("UICorner", { CornerRadius = if s.Round then UDim.new(1, 0) else UDim.new(0, s.Radius or 3) }),
		Gradient = e("UIGradient", { Color = ColorSequence.new(s.Hi, s.Lo), Rotation = 90 }),
		Outline = e("UIStroke", { Color = OUTLINE, Thickness = s.Outline or 2.6, LineJoinMode = Enum.LineJoinMode.Round }),
		Sheen = if s.Sheen ~= false then e("Frame", {
			Position = UDim2.new(0.14, 0, 0.1, 0),
			Size = UDim2.new(0.42, 0, 0.18, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = z,
		}, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }) else nil,
	})
end

-- `name` is a GrimoireIcons drawing (or alias); `size` is the rendered icon size in pixels.
function Icons.Icon(props: { Name: string, Size: number, Dim: boolean? })
	local drawing = GrimoireIcons.Resolve(props.Name)
	local children: { [string]: any } = {
		Scale = e("UIScale", { Scale = props.Size / 64 }),
	}
	if drawing then
		for i, spec in drawing do
			children["S" .. i] = shape(spec, i)
		end
	end
	-- A CanvasGroup lets a cooling-down or locked icon dim and desaturate as one piece.
	return e("CanvasGroup", {
		Size = UDim2.fromOffset(props.Size, props.Size),
		BackgroundTransparency = 1,
		GroupTransparency = if props.Dim then 0.35 else 0,
		GroupColor3 = if props.Dim then Color3.fromRGB(150, 150, 160) else Color3.new(1, 1, 1),
	}, {
		Canvas = e("Frame", { Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1 }, children),
	})
end

Icons.Names = { "Summon", "Squad", "Forge", "Fortress", "Index", "Overdrive", "Recall", "Tower" }

return Icons
