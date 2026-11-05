--!strict
-- Uses the actual Pit navigator, with two Forge labels. Lives above either Forge window.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local React = require(ReplicatedStorage.Packages.React)
local Hud = require(script.Parent.Parent.Hud.Components)
local e = React.createElement

local function Navigation(props: { Active: string, OnSelect: (string) -> (), Busy: boolean? })
	local camera = workspace.CurrentCamera
	local screen, setScreen = React.useState(if camera then camera.ViewportSize else Vector2.new(1280, 720))
	local _, setTick = React.useState(0)
	React.useEffect(function()
		local connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function() setTick(function(n) return n + 1 end) end)
		return function() connection:Disconnect() end
	end, {})
	local bar = GuiService.TopbarInset
	local width = math.min(420, screen.X - 24)
	local fitsTopbar = bar.Height >= 44 and bar.Width >= width + 16
	local center = if fitsTopbar then Vector2.new(math.clamp(screen.X / 2, bar.Min.X + width / 2 + 8, bar.Max.X - width / 2 - 8), bar.Min.Y + bar.Height / 2)
		else Vector2.new(screen.X / 2, (GuiService:GetGuiInset()).Y + 36)
	return e("ScreenGui", {
		Name = "ForgeNavigation", IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None,
		DisplayOrder = 81, ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		[React.Change.AbsoluteSize] = function(gui) setScreen(gui.AbsoluteSize) end,
	}, {
		Tabs = e(Hud.PitTabs, {
			Name = "ForgeTabs", Active = props.Active, Tabs = { "Artifacts", "Upgrade", "Summon" }, Size = Vector2.new(width, 56), Center = center,
			OnSelect = function(tab) if not props.Busy then props.OnSelect(tab) end end,
		}),
	})
end

return Navigation
