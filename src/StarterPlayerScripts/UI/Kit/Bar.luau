--!strict
-- StarterPlayerScripts/UI/Kit/Bar.luau
-- Pill progress bar with its numbers inside (plan §2.7, §4.7): ink track, gradient fill with a top
-- shine, an optional ghost Preview (e.g. EXP you are about to gain) and a gold glow when full.
--
--   local exp = Bar.Create(parent, { Fraction = 0.35, Preview = 0.6, Label = "1,167 / 3,305 EXP", Tone = "Gold" })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("UiKitRules"))
local Tokens = require(script.Parent:WaitForChild("Tokens"))
local Motion = require(script.Parent:WaitForChild("Motion"))

local New = Tokens.New

export type Props = {
	Fraction: number?, -- 0..1 (or give Value + Max)
	Value: number?,
	Max: number?,
	Preview: number?, -- 0..1 ghost fill ahead of the real one
	Label: string?,
	Tone: string?, -- Tokens.BarTone key: Gold (default), Jade, Azure, Crimson, Arcane
	Height: number?, -- default 22
	Name: string?,
	Position: UDim2?,
	Width: UDim?,
	LayoutOrder: number?,
	ZIndex: number?,
}
export type Handle = { Instance: Frame, Update: (Props) -> (), Destroy: () -> () }

local Bar = {}

local function fillFrame(name: string, parent: Instance, z: number): Frame
	local f = New("Frame", { Name = name, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = z }, parent)
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	return f
end

function Bar.Create(parent: Instance?, initial: Props): Handle
	local props: Props = table.clone(initial)
	local track: Frame = New("Frame", { BackgroundColor3 = Color3.fromRGB(22, 16, 32), BorderSizePixel = 0 })
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local ink = New("UIStroke", { Color = Tokens.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, track)
	local preview = fillFrame("Preview", track, 2)
	local fill = fillFrame("Fill", track, 3)
	local fillGrad = New("UIGradient", { Rotation = 90 }, fill)
	local previewGrad = New("UIGradient", { Rotation = 90 }, preview)
	local shine = New("Frame", {
		Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0,
		Position = UDim2.new(0, 4, 0, 2), Size = UDim2.new(1, -8, 0.3, 0), ZIndex = 4,
	}, fill)
	New("UICorner", { CornerRadius = UDim.new(1, 0) }, shine)
	local label = Tokens.Label(track, "", 13, "Number", {
		Name = "Label", Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Tokens.Text.White, ZIndex = 6,
	})
	local lastFraction: number? = nil

	local function render()
		local tone = Tokens.BarTone[props.Tone or "Gold"] or Tokens.BarTone.Gold
		local fraction = props.Fraction or Rules.Fraction(props.Value, props.Max)
		local z = props.ZIndex or 1
		track.Name = props.Name or "KitBar"
		track.Position = props.Position or UDim2.new()
		track.Size = UDim2.new(props.Width or UDim.new(1, 0), UDim.new(0, props.Height or 22))
		track.LayoutOrder = props.LayoutOrder or 0
		track.ZIndex = z
		preview.ZIndex, fill.ZIndex, shine.ZIndex, label.ZIndex = z + 1, z + 2, z + 3, z + 4
		fillGrad.Color = ColorSequence.new(tone.Top, tone.Bottom)
		previewGrad.Color = ColorSequence.new(tone.Top, tone.Bottom)
		preview.BackgroundTransparency = 0.55
		preview.Size = UDim2.fromScale(math.clamp(math.max(props.Preview or 0, fraction), 0, 1), 1)
		preview.Visible = (props.Preview or 0) > fraction
		if lastFraction == nil then fill.Size = UDim2.fromScale(fraction, 1) else Motion.BarFill(fill, fraction) end
		lastFraction = fraction
		fill.Visible = fraction > 0
		-- Full: a gold glow on the outline.
		ink.Color = if fraction >= 1 then Tokens.Severity.reward else Tokens.Ink
		ink.Thickness = if fraction >= 1 then 2.5 else 2
		label.Text = props.Label or ""
		label.Visible = props.Label ~= nil
	end

	render()
	if parent then track.Parent = parent end
	return {
		Instance = track,
		Update = function(changes: Props)
			for k, v in changes :: any do (props :: any)[k] = v end
			render()
		end,
		Destroy = function() track:Destroy() end,
	}
end

return table.freeze(Bar)
