--!strict
-- StarterPlayerScripts/UI/Kit
-- The shared UI kit ("Brighter Grimoire", UI overhaul plan §3–§4). One place for tokens, motion,
-- building blocks and the tooltip / toast / confirmation services, used by imperative screens
-- directly and by React screens through Kit.React.
--
--   local Kit = require(script.Parent:WaitForChild("Kit"))
--   Kit.Button.Create(parent, { Text = "Promote", Intent = "Primary", OnActivate = promote })
--   Kit.Notify.Push("success", "Settings applied.")
--   Kit.Confirm.Ask({ Tier = Kit.Rules.ConfirmTier("SELL", { MaxRarity = 5 }), Title = "Sell 3 weapons?", OnConfirm = sell })
--
-- Pure rules (tooltip placement, toast stack, confirm tiers, deltas) live in
-- Shared/Util/UiKitRules so tests/ui-kit.spec.luau can cover them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return table.freeze({
	Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("UiKitRules")),
	Tokens = require(script:WaitForChild("Tokens")),
	Motion = require(script:WaitForChild("Motion")),
	Button = require(script:WaitForChild("Button")),
	Bar = require(script:WaitForChild("Bar")),
	DeltaStat = require(script:WaitForChild("DeltaStat")),
	CurrencyChip = require(script:WaitForChild("CurrencyChip")),
	Callout = require(script:WaitForChild("Callout")),
	Tooltip = require(script:WaitForChild("Tooltip")),
	Notify = require(script:WaitForChild("Notify")),
	Confirm = require(script:WaitForChild("ConfirmDialog")),
	React = require(script:WaitForChild("React")),
})
