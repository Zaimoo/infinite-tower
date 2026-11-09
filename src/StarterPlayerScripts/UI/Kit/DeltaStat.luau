--!strict
-- StarterPlayerScripts/UI/Kit/DeltaStat.luau
-- A before → after stat row (plan §2.5): label, old value, arrow, new value and a signed change in
-- green or red. Used by Promotion, Synthesis EXP, Forge upgrade, Equip Best and Upgrades nodes.
--
--   DeltaStat.Create(parent, { Label = "Damage multiplier", Before = 6.4, After = 9.64, Format = "×%.2f" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("UiKitRules"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))

local New = Tokens.New

export type Props = {
	Label: string,
	Before: number,
	After: number,
	Format: string?, -- string.format pattern for both values, default "%.0f"
	Formatter: ((number) -> string)?, -- overrides Format, e.g. StatBalance.Format for big numbers
	Height: number?,
	Name: string?,
	LayoutOrder: number?,
	ZIndex: number?,
}
export type Handle = { Instance: Frame, Update: (Props) -> (), Destroy: () -> () }

local DeltaStat = {}

function DeltaStat.Create(parent: Instance?, initial: Props): Handle
	local props: Props = table.clone(initial)
	local row: Frame = New("Frame", { BackgroundTransparency = 1 })
	local label = Tokens.Label(row, "", 14, "Body", { Name = "Label", Size = UDim2.fromScale(0.38, 1), TextColor3 = Tokens.Text.Muted })
	local before = Tokens.Label(row, "", 15, "Number", {
		Name = "Before", Position = UDim2.fromScale(0.38, 0), Size = UDim2.fromScale(0.2, 1), TextXAlignment = Enum.TextXAlignment.Right,
	})
	local arrow = Tokens.Label(row, "→", 15, "Number", {
		Name = "Arrow", Position = UDim2.fromScale(0.58, 0), Size = UDim2.fromScale(0.06, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Tokens.Text.Gold,
	})
	local after = Tokens.Label(row, "", 15, "Number", { Name = "After", Position = UDim2.fromScale(0.64, 0), Size = UDim2.fromScale(0.2, 1) })
	local change = Tokens.Label(row, "", 13, "Number", {
		Name = "Change", Position = UDim2.fromScale(0.84, 0), Size = UDim2.fromScale(0.16, 1), TextXAlignment = Enum.TextXAlignment.Right,
	})

	local function render()
		local fmt = props.Format or "%.0f"
		local show = props.Formatter or function(n: number) return string.format(fmt, n) end
		local text, sign = Rules.FormatDelta(props.Before, props.After, fmt)
		if props.Formatter and sign ~= 0 then
			text = (if sign > 0 then "+" else "-") .. props.Formatter(math.abs(props.After - props.Before))
		end
		local color = if sign > 0 then Tokens.Severity.success elseif sign < 0 then Tokens.Severity.error else Tokens.Text.Muted
		local z = props.ZIndex or 1
		row.Name = props.Name or Tokens.Name("KitDelta", props.Label)
		row.Size = UDim2.new(1, 0, 0, props.Height or 28)
		row.LayoutOrder = props.LayoutOrder or 0
		row.ZIndex = z
		for _, l in { label, before, arrow, after, change } do l.ZIndex = z + 1 end
		label.Text = props.Label
		before.Text = show(props.Before)
		after.Text = show(props.After)
		after.TextColor3 = if sign ~= 0 then color else Tokens.Text.Parchment
		change.Text = if sign == 0 then "=" else text
		change.TextColor3 = color
	end

	render()
	if parent then row.Parent = parent end
	return {
		Instance = row,
		Update = function(changes: Props)
			for k, v in changes :: any do (props :: any)[k] = v end
			render()
		end,
		Destroy = function() row:Destroy() end,
	}
end

return table.freeze(DeltaStat)
