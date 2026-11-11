--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grimoire = require(ReplicatedStorage.Shared.Util.GildedGrimoire)

return table.freeze({
	Theme = Grimoire,
	Text = Grimoire.Text.Parchment,
	Muted = Grimoire.Text.Muted,
	Gold = Grimoire.Text.Gold,
	Good = Grimoire.Text.Good,
	Bad = Grimoire.Text.Bad,
	Equipped = Color3.fromHex("#96ECFF"), -- existing Teal rail
	Selected = Color3.fromHex("#C084FC"),
	Background = Color3.fromHex("#0D0912"),
	Raised = Grimoire.Tones.Deep.Top,
	Gap = 8,
	Padding = 16,
	Touch = 48,
	Body = 16,
	Small = 14,
	Heading = 22,
	CardWidth = 128,
	CardHeight = 188,
	TileSize = 120,
	TileGap = 10,
	GridShare = 0.64,
	DetailShare = 0.36,
	ActionBarHeight = 56,
	Crimson = Grimoire.Tones.Crimson,
	Jade = Grimoire.Tones.Jade,
	Azure = Grimoire.Tones.Azure,
	Amber = Grimoire.Tones.Amber,
	Slate = Grimoire.Tones.Slate,
	Action = Grimoire.Tones.Action,
	PageSize = 24, -- retained for compatibility; the native grid scrolls and bounds its 3D previews
})
