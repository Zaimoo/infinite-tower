--!strict
-- StarterPlayerScripts/UI/Kit/CurrencyChip.luau
-- The one currency display (plan §4.2): a pill with the drawn currency icon and a big number. Changes
-- count up with a green/red flash and a small "+87" floater. `Need` turns the number red when the
-- player can't afford it (e.g. a cost chip on a Summon button).
--
--   local gold = CurrencyChip.Create(header, { Currency = "Gold", Amount = 549094 })
--   gold.Update({ Amount = 551200 })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StatBalance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StatBalance"))
local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local UIFeel = require(script.Parent.Parent:WaitForChild("UIFeel"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Motion = require(script.Parent:WaitForChild("Motion"))

local New = Tokens.New

export type Props = {
	Currency: string, -- GrimoireIcons name: "Gold", "Gems", "Backpack", ...
	Amount: number,
	Max: number?, -- shows "Amount/Max" (capacity chips)
	Need: number?, -- red when Amount < Need
	Short: boolean?, -- abbreviate (549.09K) instead of full digits
	Width: number?, -- default 150
	Name: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
}
export type Handle = { Instance: Frame, Update: (Props) -> (), Destroy: () -> () }

local CurrencyChip = {}

local function formatAmount(n: number, short: boolean?): string
	if short then return StatBalance.Format(n) end
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function CurrencyChip.Create(parent: Instance?, initial: Props): Handle
	local props: Props = table.clone(initial)
	local chip: Frame = New("Frame", {})
	local icon: Frame? = nil
	local iconName: string? = nil
	local value = Tokens.Label(chip, "", 18, "Number", { Name = "Amount", Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -46, 1, 0) })
	local shown: number? = nil

	local function text(n: number): string
		local body = formatAmount(n, props.Short)
		if props.Max then body ..= "/" .. formatAmount(props.Max, props.Short) end
		return body
	end

	local function floater(delta: number)
		if UIFeel.ReducedMotion() then return end
		local f = Tokens.Label(chip, (if delta > 0 then "+" else "-") .. formatAmount(math.abs(delta), true), 14, "Number", {
			Name = "Floater", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.fromOffset(80, 18),
			TextXAlignment = Enum.TextXAlignment.Right, ZIndex = chip.ZIndex + 5,
			TextColor3 = if delta > 0 then Tokens.Severity.success else Tokens.Severity.error,
		})
		TweenService:Create(f, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, -6, 0, -18), TextTransparency = 1, TextStrokeTransparency = 1,
		}):Play()
		task.delay(1, function() f:Destroy() end)
	end

	local function render()
		local z = props.ZIndex or 1
		local tone = if props.Need and props.Amount < props.Need then Tokens.Intent.Danger else Tokens.Surface.Inset
		chip.Name = props.Name or (props.Currency .. "Chip")
		chip.Size = UDim2.fromOffset(props.Width or 150, 36)
		chip.Position = props.Position or UDim2.new()
		chip.AnchorPoint = props.AnchorPoint or Vector2.zero
		chip.LayoutOrder = props.LayoutOrder or 0
		chip.ZIndex = z
		Tokens.Paint(chip, tone, Tokens.Radius.Pill, 2.5, 0.35)
		if iconName ~= props.Currency then
			if icon then icon:Destroy() end
			icon = GrimoireIcons.Create(props.Currency, 28, chip, z + 2)
			local i = icon :: Frame
			i.AnchorPoint = Vector2.new(0, 0.5)
			i.Position = UDim2.new(0, 6, 0.5, 0)
			iconName = props.Currency
		end
		value.ZIndex = z + 2
		value.TextColor3 = if props.Need and props.Amount < props.Need then Tokens.Text.White else Tokens.Text.Gold
		if shown ~= nil and shown ~= props.Amount and not props.Max then
			floater(props.Amount - shown)
			Motion.NumberTick(value, shown, props.Amount, text)
		else
			value.Text = text(props.Amount)
		end
		shown = props.Amount
	end

	render()
	if parent then chip.Parent = parent end
	return {
		Instance = chip,
		Update = function(changes: Props)
			for k, v in changes :: any do (props :: any)[k] = v end
			render()
		end,
		Destroy = function() chip:Destroy() end,
	}
end

return table.freeze(CurrencyChip)
