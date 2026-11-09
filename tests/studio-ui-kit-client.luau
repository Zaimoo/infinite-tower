-- tests/studio-ui-kit-client.luau
-- Studio playtest showcase for the UI kit (StarterPlayerScripts/UI/Kit). Run it in the Client
-- (Studio MCP execute_luau, or the command bar during Play). It builds a preview window with every
-- building block, stacks a few toasts and opens a Hard confirmation. Run again to rebuild; set
-- `_G.KitShowcaseClose()` to remove it.

local Players = game:GetService("Players")

local Kit = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("UI"):WaitForChild("Kit"))
local New = Kit.Tokens.New

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("KitShowcase")
if old then old:Destroy() end

local gui = New("ScreenGui", { Name = "KitShowcase", DisplayOrder = 250, ResetOnSpawn = false, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets })
local window = New("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(720, 520) }, gui)
Kit.Tokens.Paint(window, Kit.Tokens.Surface.Window, Kit.Tokens.Radius.Window, 3.5)
local header = New("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 60), ZIndex = 2 }, window)
Kit.Tokens.Paint(header, Kit.Tokens.Domain.Forge, Kit.Tokens.Radius.Window, 0, 0.4)
Kit.Tokens.Label(header, "UI KIT SHOWCASE", 26, "Title", { Position = UDim2.fromOffset(20, 0), Size = UDim2.new(0.5, 0, 1, 0), ZIndex = 3 })
Kit.CurrencyChip.Create(header, { Currency = "Gold", Amount = 549094, Position = UDim2.new(1, -330, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Width = 160, ZIndex = 3 })
local gems = Kit.CurrencyChip.Create(header, { Currency = "Gems", Amount = 133, Need = 200, Position = UDim2.new(1, -160, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Width = 140, ZIndex = 3 })

local body = New("Frame", { Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 76), Size = UDim2.new(1, -40, 1, -92) }, window)
New("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, body)

local row = New("Frame", { Name = "Buttons", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 1 }, body)
New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, row)
for i, spec in {
	{ "Promote", "Primary" }, { "Equip", "Confirm" }, { "Recall", "Travel" }, { "Filters", "Secondary" }, { "Sell", "Danger" },
} do
	Kit.Button.Create(row, { Text = spec[1], Intent = spec[2], Width = UDim.new(0.2, -7), LayoutOrder = i, OnActivate = function() Kit.Notify.Push("success", spec[1] .. " pressed") end })
end
Kit.Button.Create(body, { Text = "Review Upgrade", Intent = "Primary", Size = "L", Disabled = true, Reason = "Choose 1 more weapon to consume", LayoutOrder = 2 })

Kit.Bar.Create(body, { Fraction = 0.35, Preview = 0.62, Label = "1,167 / 3,305 EXP  (+890)", Tone = "Gold", LayoutOrder = 3 })
Kit.Bar.Create(body, { Fraction = 1, Label = "Full", Tone = "Jade", Height = 16, LayoutOrder = 4 })
Kit.DeltaStat.Create(body, { Label = "Weapon power", Before = 216, After = 346, LayoutOrder = 5 })
Kit.DeltaStat.Create(body, { Label = "Damage multiplier", Before = 6.4, After = 9.64, Format = "×%.2f", LayoutOrder = 6 })
Kit.DeltaStat.Create(body, { Label = "Attack speed", Before = 12, After = 12, Format = "%.1f%%", LayoutOrder = 7 })
Kit.Callout.Create(body, { Severity = "warn", Text = "You're 8.3M under the recommended power", LayoutOrder = 8 })
Kit.Callout.Create(body, { Severity = "block", Text = "Need 67 more Gems", ActionText = "Get Gems", OnAction = function() Kit.Notify.Push("info", "Store would open") end, LayoutOrder = 9 })

Kit.Tooltip.Bind(header, function()
	return { Title = "Holy Claymore", Tag = "Exalted · 2★ · Equipped by Ignis", Lines = { { Label = "Power", Before = 1680, After = 2240 }, { Label = "Speed", Value = "+13.0%" } }, Key = "F" }
end)

Kit.Notify.Push("info", "Welcome to the kit showcase")
Kit.Notify.Push("reward", "Gold", { Amount = 472, Icon = "Gold" })
Kit.Notify.Push("reward", "Gold", { Amount = 100, Icon = "Gold" })
Kit.Notify.Push("warn", "Inventory almost full (95/100)")

task.delay(1.5, function() gems.Update({ Amount = 233 }) end)

gui.Parent = playerGui
_G.KitShowcaseClose = function() gui:Destroy() end

task.delay(2.5, function()
	Kit.Confirm.Ask({
		Tier = Kit.Rules.ConfirmTier("SELL", { MaxRarity = 3 }),
		Title = "Sell 3 weapons?",
		Body = "They're gone for good. You get 1,240 Gold.",
		Items = { "Vanguard Warden Bastion · Rare 1★", "Crystal Greatbow · Rare 1★", "Frostweaver Scepter · Rare 1★" },
		ConfirmText = "Sell",
		OnConfirm = function() Kit.Notify.Reward("Gold", 1240) end,
		OnCancel = function() Kit.Notify.Push("info", "Sale cancelled") end,
	})
end)

return "showcase built"
