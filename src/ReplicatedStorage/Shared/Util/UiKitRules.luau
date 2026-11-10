--!strict
-- ReplicatedStorage/Shared/Util/UiKitRules.luau
-- Pure rules behind the UI kit (StarterPlayerScripts/UI/Kit), kept free of Instances so the spec
-- suite can test them: tooltip placement, the toast stack, confirmation tiers and stat deltas.
-- See docs/ui/UI_OVERHAUL_PLAN.md §4 and §6.

local UiKitRules = {}

--============================================================================
-- TOOLTIP PLACEMENT
--============================================================================

export type Placement = { X: number, Y: number, Side: "Below" | "Above" | "Right" | "Left" }

-- Where a tooltip of size (tw, th) goes for an anchor at (ax, ay, aw, ah) on a (sw, sh) screen.
-- Prefers below the anchor, flips above when below doesn't fit, and falls back to whichever side
-- has more room. Horizontally it centres on the anchor and is clamped `margin` px inside the screen.
-- `prefer` = "Right"/"Left" places it beside the anchor instead (rails at the screen edge).
function UiKitRules.PlaceTooltip(ax: number, ay: number, aw: number, ah: number, tw: number, th: number,
	sw: number, sh: number, gap: number?, margin: number?, prefer: string?): Placement
	local g = gap or 8
	local m = margin or 8
	local function clamp(v: number, lo: number, hi: number): number
		if hi < lo then return lo end
		return math.clamp(v, lo, hi)
	end
	if prefer == "Right" or prefer == "Left" then
		local rightX = ax + aw + g
		local leftX = ax - g - tw
		local fitsRight = rightX + tw <= sw - m
		local fitsLeft = leftX >= m
		local side: "Right" | "Left" = if prefer == "Right" then (if fitsRight or not fitsLeft then "Right" else "Left")
			else (if fitsLeft or not fitsRight then "Left" else "Right")
		local x = if side == "Right" then rightX else leftX
		local y = clamp(ay + ah / 2 - th / 2, m, sh - m - th)
		return { X = clamp(x, m, sw - m - tw), Y = y, Side = side }
	end
	local belowY = ay + ah + g
	local aboveY = ay - g - th
	local fitsBelow = belowY + th <= sh - m
	local fitsAbove = aboveY >= m
	local side: "Below" | "Above"
	if fitsBelow then side = "Below"
	elseif fitsAbove then side = "Above"
	else side = if (sh - (ay + ah)) >= ay then "Below" else "Above" end
	local y = if side == "Below" then belowY else aboveY
	local x = clamp(ax + aw / 2 - tw / 2, m, sw - m - tw)
	return { X = x, Y = clamp(y, m, sh - m - th), Side = side }
end

--============================================================================
-- TOAST STACK
--============================================================================

export type ToastKind = "info" | "success" | "warn" | "error" | "reward"
export type Toast = { Id: number, Kind: ToastKind, Text: string, Count: number, Amount: number?, ExpiresAt: number, Lines: { string }? }
export type ToastStack = { Items: { Toast }, Max: number, NextId: number }

UiKitRules.ToastHold = table.freeze({ info = 3.5, success = 3.5, warn = 4.5, error = 4.5, reward = 3.5 })

function UiKitRules.NewToastStack(max: number?): ToastStack
	return { Items = {}, Max = max or 3, NextId = 0 }
end

-- Adds a toast, newest first. The same kind and text while still showing coalesces into it
-- ("×3", amounts summed) instead of stacking a duplicate. Returns the toast, whether it is new,
-- and the toasts pushed out because the stack was full.
function UiKitRules.PushToast(stack: ToastStack, kind: ToastKind, text: string, now: number, amount: number?, hold: number?, lines: { string }?): (Toast, boolean, { Toast })
	local duration = hold or UiKitRules.ToastHold[kind] or 3.5
	for _, item in stack.Items do
		if not lines and not item.Lines and item.Kind == kind and item.Text == text and item.ExpiresAt > now then
			item.Count += 1
			if amount then item.Amount = (item.Amount or 0) + amount end
			item.ExpiresAt = now + duration
			return item, false, {}
		end
	end
	stack.NextId += 1
	local toast: Toast = { Id = stack.NextId, Kind = kind, Text = text, Count = 1, Amount = amount, ExpiresAt = now + duration, Lines = lines }
	table.insert(stack.Items, 1, toast)
	local evicted = {}
	while #stack.Items > stack.Max do
		table.insert(evicted, table.remove(stack.Items) :: Toast)
	end
	return toast, true, evicted
end

local function formatInteger(amount: number): string
	local digits = string.format("%.0f", amount)
	local grouped = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	return (string.gsub(grouped, "^,", ""))
end

function UiKitRules.RewardLine(currency: string, amount: number, streakBonus: number?): string
	local line = formatInteger(amount) .. " " .. currency
	if streakBonus and streakBonus > 0 then
		line ..= " · +" .. formatInteger(streakBonus) .. " from streak"
	end
	return line
end

-- Removes and returns the toasts whose time is up.
function UiKitRules.ExpireToasts(stack: ToastStack, now: number): { Toast }
	local removed = {}
	for i = #stack.Items, 1, -1 do
		if stack.Items[i].ExpiresAt <= now then
			table.insert(removed, table.remove(stack.Items, i) :: Toast)
		end
	end
	return removed
end

-- The text a toast shows: "Saved", "Saved ×3", "+1,240 Gold".
function UiKitRules.ToastLabel(toast: Toast): string
	if toast.Count > 1 then return string.format("%s ×%d", toast.Text, toast.Count) end
	return toast.Text
end

--============================================================================
-- CONFIRMATION TIERS (plan §6)
--============================================================================

export type Tier = "None" | "Soft" | "Hard" | "Critical"

-- Artifact rarity tiers: 1 Common, 2 Uncommon, 3 Rare, 4 Superior, 5 Exalted, ... 16 Origin.
UiKitRules.RareTier = 3
UiKitRules.ExaltedTier = 5

-- How strongly to confirm `action`. ctx fields by action:
--   SELL: MaxRarity, MaxStars  ·  UPGRADE: MaxDonorRarity  ·  SYNTHESIS / PROMOTION: RequiresRareConfirmation
--   FORTRESS_NODE: Cost, Balance  ·  VISIT_FLOOR: SquadPower, Recommended
--   SUMMON_10X, UNASSIGN_FACILITY, LEAVE_RAID, LEAVE_DUEL, RESET_SETTINGS, DISCARD_SETTINGS: no fields
function UiKitRules.ConfirmTier(action: string, ctx: { [string]: any }?): Tier
	local c = ctx or {}
	if action == "SELL" then
		local rarity, stars = c.MaxRarity or 1, c.MaxStars or 1
		if rarity >= UiKitRules.ExaltedTier or stars >= 2 then return "Critical" end
		if rarity >= UiKitRules.RareTier then return "Hard" end
		return "None"
	elseif action == "UPGRADE" then
		return if (c.MaxDonorRarity or 1) >= UiKitRules.RareTier then "Hard" else "None"
	elseif action == "SYNTHESIS" or action == "PROMOTION" then
		return if c.RequiresRareConfirmation == true then "Hard" else "None"
	elseif action == "FORTRESS_NODE" then
		local cost, balance = c.Cost or 0, c.Balance or 0
		return if balance > 0 and cost >= balance * 0.25 then "Soft" else "None"
	elseif action == "VISIT_FLOOR" then
		return if (c.SquadPower or 0) < (c.Recommended or 0) then "Soft" else "None"
	elseif action == "SUMMON_10X" or action == "UNASSIGN_FACILITY" or action == "LEAVE_RAID" or action == "LEAVE_DUEL"
		or action == "RESET_SETTINGS" or action == "DISCARD_SETTINGS" then
		return "Soft"
	end
	return "None"
end

-- Whether to show the dialog at all. Only Soft dialogs honour "Don't ask again this session".
function UiKitRules.ShouldAsk(tier: Tier, skipped: { [string]: boolean }?, key: string?): boolean
	if tier == "None" then return false end
	if tier == "Soft" and key and skipped and skipped[key] then return false end
	return true
end

-- Seconds before the Confirm button arms (Hard) or how long it must be held (Critical).
UiKitRules.ArmDelay = table.freeze({ None = 0, Soft = 0, Hard = 1, Critical = 1.2 })

--============================================================================
-- STAT DELTAS
--============================================================================

-- "+130", "-0.5%", "+3.24" for a "×%.2f" multiplier (the × belongs on the values, not the change).
-- Returns the text and the sign (1 up, -1 down, 0 unchanged).
function UiKitRules.FormatDelta(before: number, after: number, fmt: string?): (string, number)
	local delta = after - before
	if math.abs(delta) < 1e-6 then return "=", 0 end
	local body = (string.gsub(string.format(fmt or "%.0f", math.abs(delta)), "^×", ""))
	return (if delta > 0 then "+" else "-") .. body, if delta > 0 then 1 else -1
end

-- 0..1 fill for a bar, safe for zero or missing maximums.
function UiKitRules.Fraction(value: number?, max: number?): number
	local m = max or 0
	if m <= 0 then return 0 end
	return math.clamp((value or 0) / m, 0, 1)
end

return table.freeze(UiKitRules)
