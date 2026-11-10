--!strict
-- tests/ui-kit.spec.luau
-- Pure rules behind the UI kit: tooltip placement, the toast stack, confirmation tiers, deltas.

local Rules = require(nodes["ReplicatedStorage.Shared.Util.UiKitRules"])

local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

test("tooltip sits centred below its anchor when there is room", function()
	local p = Rules.PlaceTooltip(400, 100, 80, 40, 200, 60, 1280, 720)
	assert(p.Side == "Below", p.Side)
	assert(p.X == 340, "centred x " .. p.X)
	assert(p.Y == 148, "below y " .. p.Y)
end)

test("tooltip flips above an anchor near the bottom edge", function()
	local p = Rules.PlaceTooltip(400, 660, 80, 40, 200, 60, 1280, 720)
	assert(p.Side == "Above", p.Side)
	assert(p.Y == 592, "above y " .. p.Y)
end)

test("tooltip is clamped inside the left and right edges", function()
	local left = Rules.PlaceTooltip(0, 100, 40, 40, 200, 60, 1280, 720)
	assert(left.X == 8, "left clamp " .. left.X)
	local right = Rules.PlaceTooltip(1260, 100, 20, 40, 200, 60, 1280, 720)
	assert(right.X == 1280 - 8 - 200, "right clamp " .. right.X)
end)

test("tooltip beside a rail flips to the other side at the screen edge", function()
	local p = Rules.PlaceTooltip(1200, 300, 72, 72, 220, 40, 1280, 720, 8, 8, "Right")
	assert(p.Side == "Left", p.Side)
	assert(p.X == 1200 - 8 - 220, "left of anchor " .. p.X)
	local q = Rules.PlaceTooltip(12, 300, 72, 72, 220, 40, 1280, 720, 8, 8, "Right")
	assert(q.Side == "Right" and q.X == 92, "right of anchor " .. q.X)
end)

test("toasts stack newest first and evict past the maximum", function()
	local stack = Rules.NewToastStack(3)
	for i = 1, 4 do Rules.PushToast(stack, "info", "Message " .. i, 0) end
	assert(#stack.Items == 3, "kept " .. #stack.Items)
	assert(stack.Items[1].Text == "Message 4", "newest first")
	assert(stack.Items[3].Text == "Message 2", "oldest evicted")
end)

test("the same toast coalesces into a counter and sums amounts", function()
	local stack = Rules.NewToastStack(3)
	local first, isNew = Rules.PushToast(stack, "reward", "Gold", 0, 100)
	assert(isNew)
	local again, isNew2 = Rules.PushToast(stack, "reward", "Gold", 1, 50)
	assert(not isNew2 and again.Id == first.Id)
	assert(again.Count == 2 and again.Amount == 150)
	assert(#stack.Items == 1)
	assert(Rules.ToastLabel(again) == "Gold ×2")
	-- A different kind with the same text is a separate toast.
	Rules.PushToast(stack, "warn", "Gold", 1)
	assert(#stack.Items == 2)
end)

test("expired toasts are removed and no longer coalesce", function()
	local stack = Rules.NewToastStack(3)
	Rules.PushToast(stack, "info", "Saved", 0, nil, 2)
	assert(#Rules.ExpireToasts(stack, 1) == 0)
	assert(#Rules.ExpireToasts(stack, 2) == 1)
	local _, isNew = Rules.PushToast(stack, "info", "Saved", 3)
	assert(isNew, "a toast after expiry starts fresh")
end)

test("each relic receipt keeps its own lines and stack entry alongside regular notifications", function()
	local stack = Rules.NewToastStack(3)
	local clear = Rules.PushToast(stack, "success", "Floor cleared", 0)
	local lines = { Rules.RewardLine("Gems", 9685, 2235), Rules.RewardLine("Gold", 1000000, 0) }
	assert(lines[1] == "9,685 Gems · +2,235 from streak" and lines[2] == "1,000,000 Gold")
	local first = Rules.PushToast(stack, "reward", "Banked Apex Core", 1, nil, 5, lines)
	local second, isNew = Rules.PushToast(stack, "reward", "Banked Apex Core", 1, nil, 5, lines)
	assert(isNew and first.Id ~= second.Id and first.Count == 1 and second.Count == 1)
	assert(stack.Items[1] == second and stack.Items[2] == first and stack.Items[3] == clear)
	local drop, _, evicted = Rules.PushToast(stack, "reward", "Relic dropped", 1.5)
	assert(#evicted == 1 and evicted[1] == clear and stack.Items[1] == drop)
	assert(stack.Items[2].Lines[1] == "9,685 Gems · +2,235 from streak")
end)

test("sell confirmation follows the plan's risk table", function()
	assert(Rules.ConfirmTier("SELL", { MaxRarity = 2, MaxStars = 1 }) == "None")
	assert(Rules.ConfirmTier("SELL", { MaxRarity = 3, MaxStars = 1 }) == "Hard")
	assert(Rules.ConfirmTier("SELL", { MaxRarity = 4, MaxStars = 1 }) == "Hard")
	assert(Rules.ConfirmTier("SELL", { MaxRarity = 5, MaxStars = 1 }) == "Critical")
	assert(Rules.ConfirmTier("SELL", { MaxRarity = 1, MaxStars = 2 }) == "Critical")
end)

test("other actions map to their tiers", function()
	assert(Rules.ConfirmTier("UPGRADE", { MaxDonorRarity = 2 }) == "None")
	assert(Rules.ConfirmTier("UPGRADE", { MaxDonorRarity = 3 }) == "Hard")
	assert(Rules.ConfirmTier("SYNTHESIS", { RequiresRareConfirmation = true }) == "Hard")
	assert(Rules.ConfirmTier("PROMOTION", {}) == "None")
	assert(Rules.ConfirmTier("FORTRESS_NODE", { Cost = 25, Balance = 100 }) == "Soft")
	assert(Rules.ConfirmTier("FORTRESS_NODE", { Cost = 24, Balance = 100 }) == "None")
	assert(Rules.ConfirmTier("VISIT_FLOOR", { SquadPower = 9, Recommended = 18 }) == "Soft")
	assert(Rules.ConfirmTier("VISIT_FLOOR", { SquadPower = 18, Recommended = 18 }) == "None")
	for _, action in { "SUMMON_10X", "UNASSIGN_FACILITY", "LEAVE_RAID", "LEAVE_DUEL", "RESET_SETTINGS", "DISCARD_SETTINGS" } do
		assert(Rules.ConfirmTier(action) == "Soft", action)
	end
	assert(Rules.ConfirmTier("UNKNOWN") == "None")
end)

test("only soft confirmations can be skipped for the session", function()
	local skipped = { SUMMON_10X = true, SELL = true }
	assert(not Rules.ShouldAsk("Soft", skipped, "SUMMON_10X"))
	assert(Rules.ShouldAsk("Hard", skipped, "SELL"))
	assert(Rules.ShouldAsk("Critical", skipped, "SELL"))
	assert(not Rules.ShouldAsk("None", nil, nil))
	assert(Rules.ShouldAsk("Soft", nil, "SUMMON_10X"))
end)

test("deltas carry a sign and drop the multiplier symbol", function()
	local text, sign = Rules.FormatDelta(216, 346)
	assert(text == "+130" and sign == 1, text)
	text, sign = Rules.FormatDelta(6.4, 9.64, "×%.2f")
	assert(text == "+3.24" and sign == 1, text)
	text, sign = Rules.FormatDelta(12, 12, "%.1f%%")
	assert(text == "=" and sign == 0, text)
	text, sign = Rules.FormatDelta(10, 7.5, "%.1f")
	assert(text == "-2.5" and sign == -1, text)
end)

test("bar fractions are clamped and safe for zero maximums", function()
	assert(Rules.Fraction(5, 10) == 0.5)
	assert(Rules.Fraction(15, 10) == 1)
	assert(Rules.Fraction(5, 0) == 0)
	assert(Rules.Fraction(nil, nil) == 0)
end)

print(string.format("ui-kit: %d passed", passed))
