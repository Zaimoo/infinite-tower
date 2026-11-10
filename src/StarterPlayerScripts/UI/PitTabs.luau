--!strict
-- StarterPlayerScripts/UI/PitTabs.luau
-- The Pit's Synthesis | Promotion tabs, built into each window's header (like the Forge's
-- Artifacts | Summon tabs). They used to float in Roblox's top bar, where they covered the window on
-- large screens. Both windows build the same pair, so the tabs sit in the same place on either.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GildedGrimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))

export type Tab = "Synthesis" | "Promotion"

local PitTabs = {}

PitTabs.TabWidth = 128
PitTabs.Height = 40
PitTabs.Gap = 8
PitTabs.Width = PitTabs.TabWidth * 2 + PitTabs.Gap

local TABS: { Tab } = { "Synthesis", "Promotion" }

-- Builds the pair under `parent`. `active` is the window the tabs live in; pressing the other tab
-- calls `onSelect` (which may refuse, e.g. while a commit is in flight).
function PitTabs.Create(parent: GuiObject, active: Tab, zIndex: number, onSelect: (Tab) -> ()): Frame
	local holder = Instance.new("Frame")
	holder.Name = "PitTabs"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(PitTabs.Width, PitTabs.Height)
	holder.ZIndex = zIndex

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, PitTabs.Gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	for order, tab in TABS do
		local selected = tab == active
		local button = Instance.new("TextButton")
		button.Name = tab .. "Tab"
		button.LayoutOrder = order
		button.Size = UDim2.fromOffset(PitTabs.TabWidth, PitTabs.Height)
		button.Text = ""
		button.AutoButtonColor = false
		button.BorderSizePixel = 0
		button.Selectable = true
		button.ZIndex = zIndex
		button.Parent = holder
		GildedGrimoire.Frame(button, { Class = "Button", Tone = if selected then "Gold" else "Slate", ZIndex = zIndex })

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(4, 2)
		label.Size = UDim2.new(1, -8, 1, -4)
		label.Text = string.upper(tab)
		label.TextSize = 14
		label.TextColor3 = if selected then Color3.new(1, 1, 1) else GildedGrimoire.Text.Muted
		label.ZIndex = zIndex + 2
		label:SetAttribute("Grimoire", true)
		GildedGrimoire.StyleText(label, "Title")
		label.Parent = button

		button.Activated:Connect(function()
			if not selected then onSelect(tab) end
		end)
	end

	holder.Parent = parent
	return holder
end

return PitTabs
