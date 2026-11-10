--!strict
-- StarterPlayerScripts/UI/WindowScale.luau
-- The UIScale of a React window. It gives React windows the same motion as the imperative ones
-- (ModalFit + WindowManager): a pop from 94% when the window mounts, and, when `Window` names its
-- WindowManager id, the shared shrink before it unmounts.
--
--   Window = Panel({ ... }, { Scale = e(WindowScale, { Scale = fit, Window = "FacilityPanel" }), ... })
--
-- Put it directly under the window frame. `Scale` is the fitted resting scale (default 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local UIFeel = require(script.Parent:WaitForChild("UIFeel"))
local WindowManager = require(script.Parent:WaitForChild("WindowManager"))

local function WindowScale(props: { Scale: number?, Window: string? })
	local ref = React.useRef(nil :: UIScale?)
	local mounted = React.useRef(false)
	local rest = props.Scale or 1

	-- Layout effect: the scale is set before the first paint, so the window never flashes at 100%.
	React.useLayoutEffect(function()
		local scale = ref.current
		if not scale then return nil end
		local root = scale.Parent
		local id = props.Window
		-- A remount of the same window (a tab switch re-keys it) is not a fresh open: no second pop.
		if id and WindowManager.RecentlyClosed(id) then
			scale.Scale = rest
		else
			UIFeel.WindowIn(scale, rest)
		end
		if id and root and root:IsA("GuiObject") then
			WindowManager.SetRoot(id, root)
			return function() WindowManager.ClearRoot(id, root) end
		end
		return nil
	end, {})

	-- The fitted scale changes when the screen is resized while the window is open.
	React.useEffect(function()
		if not mounted.current then
			mounted.current = true
			return
		end
		if ref.current then ref.current.Scale = rest end
	end, { rest })

	return React.createElement("UIScale", { ref = ref })
end

return WindowScale
