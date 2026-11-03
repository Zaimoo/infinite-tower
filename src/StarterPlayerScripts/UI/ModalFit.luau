--!strict
-- StarterPlayerScripts/UI/ModalFit.luau
-- Fits a centred modal window into the screen's safe area: below Roblox's top bar, with a margin on
-- every side (a larger one at the bottom, where the HUD drawer and touch controls sit), scaled down
-- when it does not fit. The window must use AnchorPoint (0.5, 0.5) and carry a UIScale.

local GuiService = game:GetService("GuiService")

local UIFeel = require(script.Parent:WaitForChild("UIFeel"))

local ModalFit = {}

ModalFit.Margin = 24 -- left, right and below the top bar
ModalFit.BottomMargin = 56

export type Options = {
	Top: number?, -- extra space reserved above the window (e.g. the Pit's tab bar)
	MinScale: number?,
	MaxScale: number?,
	Margin: number?, -- overrides ModalFit.Margin
	BottomMargin: number?, -- overrides ModalFit.BottomMargin
}

-- Keeps `root` centred in the safe area and `scale` fitted while the screen changes size.
-- Returns `fit`, which re-centres the window and returns the scale it should have (for open tweens).
function ModalFit.Bind(root: GuiObject, scale: UIScale, width: number, height: number, opts: Options?): () -> number
	local o: Options = opts or {}
	local function fit(): number
		local gui = root:FindFirstAncestorOfClass("ScreenGui")
		if not gui then return scale.Scale end
		local size = gui.AbsoluteSize
		local topBar = if gui.IgnoreGuiInset then (GuiService:GetGuiInset()).Y else 0
		local margin = o.Margin or ModalFit.Margin
		local top = topBar + margin + (o.Top or 0)
		local availH = math.max(1, size.Y - top - (o.BottomMargin or ModalFit.BottomMargin))
		local availW = math.max(1, size.X - 2 * margin)
		root.Position = UDim2.new(0.5, 0, 0, top + availH / 2)
		return math.clamp(math.min(availW / width, availH / height), o.MinScale or 0.45, o.MaxScale or 1)
	end
	local function apply()
		scale.Scale = fit()
	end
	local gui = root:FindFirstAncestorOfClass("ScreenGui")
	if gui then
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
		gui:GetPropertyChangedSignal("IgnoreGuiInset"):Connect(apply)
	end
	apply()
	-- Every fitted window pops in when it opens (instant under Reduce Motion).
	UIFeel.BindOpen(root, scale, fit)
	return fit
end

return ModalFit
