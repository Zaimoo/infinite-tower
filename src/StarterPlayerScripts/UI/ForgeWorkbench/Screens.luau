--!strict
-- Focused artifact screens: no competing inventory column during an upgrade.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Stats = require(ReplicatedStorage.Shared.Util.StatFormulas)
local C = require(script.Parent.Components)
local Model = require(script.Parent.Model)
local T = require(script.Parent.Tokens)
local Types = require(script.Parent.Types)
local EquippedHero = require(script.Parent.EquippedHero)
local e = React.createElement
local Screens = {}

function Screens.ItemHeader(props: { Snapshot: Types.Snapshot, Artifact: Types.Artifact, Kept: boolean?, Large: boolean? })
 local artifact = props.Artifact
 local rarity = Catalog.GetRarityInfo(artifact.Rarity)
 local large = props.Large == true
 local owners = Model.ownerIds(props.Snapshot, artifact.UUID)
 local owner = #owners == 1 and props.Snapshot.Heroes[owners[1]] or nil
 local height = if large then 200 else 96
 local previewWidth = if large then 160 else 80
 return e("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height) }, {
  Preview = if owner then e(EquippedHero, { Hero = owner, Artifact = artifact, Size = UDim2.fromOffset(previewWidth, height) }) else e(C.Preview, { Artifact = artifact, Size = UDim2.fromOffset(previewWidth, height) }),
  Name = e(C.Text, { Text = artifact.DisplayName, Position = UDim2.fromOffset(previewWidth + 16, 0), Size = UDim2.new(1, -previewWidth - 16, 0, if large then 64 else 36), TextSize = if large then 24 else 18, FontFace = T.Theme.Fonts.Title }),
  Stars = if large then e(C.Text, { Text = string.rep("★", artifact.Star), Position = UDim2.fromOffset(previewWidth + 16, 66), Size = UDim2.new(1, -previewWidth - 16, 0, 32), TextSize = 26, TextColor3 = T.Gold }) else nil,
  Stats = e(C.Text, { Text = (if props.Kept then "KEPT · " else "") .. string.format("%s · %d★ · %.0f PWR", rarity.Name, artifact.Star, Model.power(artifact)), Position = UDim2.fromOffset(previewWidth + 16, if large then 104 else 36), Size = UDim2.new(1, -previewWidth - 16, 0, 36), TextSize = 14, TextColor3 = rarity.Color }),
  Owner = e(C.Text, { Text = (if owner then owner.DisplayName .. " · Lv." .. owner.Level else Model.ownerText(props.Snapshot, artifact.UUID)) .. (if artifact.Locked then " · Locked" else ""), Position = UDim2.fromOffset(previewWidth + 16, if large then 146 else 66), Size = UDim2.new(1, -previewWidth - 16, 0, if large then 48 else 30), TextSize = 14, TextColor3 = if #Model.ownerIds(props.Snapshot, artifact.UUID) > 0 then T.Equipped else T.Muted }),
 })
end

function Screens.Stats(props: { Before: Types.Artifact?, After: Types.Artifact, Hero: Types.Hero? })
	local old = props.Before
	local before = if old then Catalog.GetStatBreakdown(old.TemplateId, old.Star, old.Rarity) else { Power = 0, DamageMultiplier = 1, ["Attack Speed"] = 0 }
	local after = Catalog.GetStatBreakdown(props.After.TemplateId, props.After.Star, props.After.Rarity)
	local hero = props.Hero
	return e(C.Stack, { Children = {
		Power = e(C.StatRow, { Label = "Weapon power", Before = before.Power, After = after.Power, Order = 1 }),
		Damage = e(C.StatRow, { Label = "Damage multiplier", Before = before.DamageMultiplier, After = after.DamageMultiplier, Format = "×%.2f", Order = 2 }),
		Speed = e(C.StatRow, { Label = "Attack speed", Before = before["Attack Speed"], After = after["Attack Speed"], Format = "%.1f%%", Order = 3 }),
		DPS = if hero and Model.compatible(hero, props.After) then e(C.StatRow, { Label = "Base hero DPS", Before = Stats.GetCombatSnapshot(hero, old).DPS, After = Stats.GetCombatSnapshot(hero, props.After).DPS, Format = "%.1f", Order = 4 }) else nil,
	} })
end

function Screens.MaterialList(props: { Items: { Types.Artifact }, Width: number })
	local columns = math.max(1, math.min(3, math.floor(props.Width / 180)))
	local rows = math.ceil(#props.Items / columns)
	local children: { [string]: any } = {
		Layout = e("UIGridLayout", { CellSize = UDim2.new(1 / columns, -8, 0, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, artifact in props.Items do
		children[artifact.UUID] = e(C.Text, { Text = string.format("%s · %d★", artifact.DisplayName, artifact.Star), TextSize = 14, BackgroundTransparency = 0, BackgroundColor3 = T.Theme.Tones.Deep.Top, LayoutOrder = index })
	end
	return e("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, rows * 52), }, children)
end

return Screens
