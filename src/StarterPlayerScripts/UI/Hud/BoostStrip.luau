--!strict
-- StarterPlayerScripts/UI/Hud/BoostStrip.luau
-- Running potion boosts on the HUD (GDD §4.9): one chip per boost with its flask and the time
-- left, beside the currency bar. Each boost's end time is a player attribute set by the server
-- (PotionConfig.Attribute, on the server clock), so the chips count down with no messages.
-- Tapping the strip opens the Backpack, where potions are drunk.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PotionConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionConfig"))
local Grimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Components = require(script.Parent:WaitForChild("Components"))

local e = React.createElement
local Tones = Grimoire.Tones

local BoostStrip = {}

BoostStrip.ChipWidth = 78
BoostStrip.Height = 30

-- Seconds left on an effect's boost for the local player (0 when it is off).
function BoostStrip.Remaining(effect: string): number
	local player = Players.LocalPlayer
	local untilTime = player and player:GetAttribute(PotionConfig.Attribute(effect))
	if type(untilTime) ~= "number" then return 0 end
	return math.max(0, untilTime - workspace:GetServerTimeNow())
end

-- "12:05" under an hour, "1h 05m" above it.
function BoostStrip.Clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	if s >= 3600 then return string.format("%dh %02dm", s // 3600, s % 3600 // 60) end
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Re-renders the caller once a second and whenever a boost attribute changes.
function BoostStrip.useClock()
	local _, setTick = React.useState(0)
	React.useEffect(function()
		local alive = true
		local player = Players.LocalPlayer
		local conns = {}
		for _, id in PotionConfig.Order do
			table.insert(conns, player:GetAttributeChangedSignal(PotionConfig.Attribute(PotionConfig.Potions[id].Effect)):Connect(function()
				setTick(os.clock())
			end))
		end
		task.spawn(function()
			while alive do
				task.wait(1)
				setTick(os.clock())
			end
		end)
		return function()
			alive = false
			for _, c in conns do c:Disconnect() end
		end
	end, {})
end

function BoostStrip.Strip(props: { Left: number, Bottom: number, OnActivated: () -> () })
	BoostStrip.useClock()
	local chips: { [string]: any } = {
		Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center }),
	}
	local count = 0
	for order, id in PotionConfig.Order do
		local potion = PotionConfig.Potions[id]
		local left = BoostStrip.Remaining(potion.Effect)
		if left <= 0 then continue end
		count += 1
		chips[id] = Components.Panel({
			Class = "TextButton", Name = "Boost_" .. potion.Effect, Text = "", AutoButtonColor = false, Selectable = false, LayoutOrder = order,
			Size = UDim2.fromOffset(BoostStrip.ChipWidth, BoostStrip.Height), Radius = 9,
			Top = Tones.Slate.Top, Bottom = Tones.Deep.Bottom, Rail = potion.Tint,
			[React.Event.Activated] = props.OnActivated,
		}, {
			Icon = Components.IconAt(potion.Icon, 22, { Position = UDim2.fromOffset(5, 4), ZIndex = 4 }),
			Time = e("TextLabel", {
				Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -34, 1, 0), BackgroundTransparency = 1, FontFace = Components.NumberFont,
				TextSize = 14, TextColor3 = potion.Tint, TextXAlignment = Enum.TextXAlignment.Left, Text = BoostStrip.Clock(left), ZIndex = 4,
			}),
		})
	end
	if count == 0 then return nil end
	return e("Frame", {
		Name = "BoostStrip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, props.Left, 1, -props.Bottom),
		Size = UDim2.fromOffset(count * BoostStrip.ChipWidth + (count - 1) * 6, BoostStrip.Height), BackgroundTransparency = 1,
	}, chips)
end

return BoostStrip
