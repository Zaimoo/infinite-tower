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

local COMPACT_MARGIN = 10
local COMPACT_BOTTOM_MARGIN = 12

export type Options = {
	Top: number?, -- extra space reserved above the window (e.g. the Pit's tab bar)
	MaxScale: number?,
	Margin: number?, -- overrides ModalFit.Margin
	BottomMargin: number?, -- overrides ModalFit.BottomMargin
	FillWidth: boolean?, -- let flexible columns use spare width on compact viewports
	DesignSize: ((Vector2) -> Vector2)?, -- choose a layout for the available space
}

-- Shared geometry for imperative and React windows.
function ModalFit.Calculate(size: Vector2, topBar: number, width: number, height: number, opts: Options?): (UDim2, number, Vector2)
	local o: Options = opts or {}
	local compact = 1 - math.clamp(math.min((size.X - 960) / 480, (size.Y - 560) / 260), 0, 1)
	local margin = o.Margin or math.round(ModalFit.Margin + (COMPACT_MARGIN - ModalFit.Margin) * compact)
	local bottom = o.BottomMargin or math.round(ModalFit.BottomMargin + (COMPACT_BOTTOM_MARGIN - ModalFit.BottomMargin) * compact)
	local top = topBar + margin + (o.Top or 0)
	local availH = math.max(1, size.Y - top - bottom)
	local availW = math.max(1, size.X - 2 * margin)
	local design = if o.DesignSize then o.DesignSize(Vector2.new(availW, availH)) else Vector2.new(width, height)
	local fit = math.min(availW / design.X, availH / design.Y)
	local scale = math.min(fit, o.MaxScale or 1)
	if o.FillWidth then
		-- Give the columns room without stretching text or changing the layout on large displays.
		local extra = math.clamp(availW / scale - design.X, 0, design.X * 0.2 * compact)
		design = Vector2.new(design.X + extra, design.Y)
	end
	return UDim2.new(0.5, 0, 0, top + availH / 2), scale, design
end

-- Keeps `root` centred in the safe area and `scale` fitted while the screen changes size.
-- Returns `fit`, which re-centres the window and returns the scale it should have (for open tweens).
function ModalFit.Bind(root: GuiObject, scale: UIScale, width: number, height: number, opts: Options?): () -> number
	local o: Options = opts or {}
	local function fit(): number
		local gui = root:FindFirstAncestorOfClass("ScreenGui")
		if not gui then return scale.Scale end
		local size = gui.AbsoluteSize
		local topBar = if gui.IgnoreGuiInset then (GuiService:GetGuiInset()).Y else 0
		local position, fittedScale, design = ModalFit.Calculate(size, topBar, width, height, o)
		if o.DesignSize or o.FillWidth then root.Size = UDim2.fromOffset(design.X, design.Y) end
		root.Position = position
		return fittedScale
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
