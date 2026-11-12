--!strict
-- StarterPlayerScripts/UI/Hud/RewardsPanel.luau
-- The Rewards window (GDD §4.8), drawn in Gilded Grimoire like the Store:
--   * Friend boost strip: friends in this server and the Gold bonus they give.
--   * Daily login: the 7-day calendar; today's entry has the CLAIM button.
--   * Weekly chest: one claim per UTC week.
--   * Playtime: up to 7 tiers within the first hour played today, each with a countdown.
--   * Codes: a text box; the server holds the code list and answers valid / used / expired.
-- Everything shown comes from RewardsStore (the server's State). Buttons only send requests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardsConfig = require(Shared:WaitForChild("Config"):WaitForChild("RewardsConfig"))
local RewardRules = require(Shared:WaitForChild("Util"):WaitForChild("RewardRules"))
local Grimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Components = require(script.Parent:WaitForChild("Components"))
local RewardsStore = require(script.Parent:WaitForChild("RewardsStore"))
local WindowScale = require(script.Parent.Parent:WaitForChild("WindowScale"))

local e = React.createElement
local Panel = Components.Panel
local Heavy = Components.HeavyLabel
local Body = Components.Body
local IconAt = Components.IconAt
local Tones = Grimoire.Tones
local TEXT = Grimoire.Text

local CARD = Vector2.new(128, 168)
local CENTER = Enum.TextXAlignment.Center

local function rewardIcon(reward: RewardsConfig.Reward): string
	return if reward.Gems then "Gems" elseif reward.Gold then "Gold" else "Spark"
end

local function rewardLines(reward: RewardsConfig.Reward): string
	return (string.gsub(RewardRules.Describe(reward, false), " · ", "\n"))
end

local function claimButton(props: { Size: UDim2, Position: UDim2?, AnchorPoint: Vector2?, Text: string?, Disabled: boolean?, OnClaim: () -> () })
	local t = if props.Disabled then Tones.Slate else Tones.Gold
	return Panel({
		Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = not props.Disabled, Active = not props.Disabled,
		Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, Radius = 10,
		Top = t.Top, Bottom = t.Bottom, Rail = t.Rail, ZIndex = 6,
		[React.Event.Activated] = function()
			if not props.Disabled then props.OnClaim() end
		end,
	}, {
		Label = Heavy({ Size = UDim2.fromScale(1, 1), MaxSize = 16, Outline = 2, Gold = false, Text = props.Text or "CLAIM", ZIndex = 8 }),
	})
end

-- One calendar / playtime card. `status` is "Claim", "Claimed" or "Locked".
local function rewardCard(order: number, title: string, reward: RewardsConfig.Reward, status: string, footer: string, busy: boolean, onClaim: () -> ())
	local tone = if status == "Claim" then Tones.Bronze elseif status == "Claimed" then Tones.Jade else Tones.Deep
	return Panel({ LayoutOrder = order, Size = UDim2.fromOffset(CARD.X, CARD.Y), Radius = 12, Top = tone.Top, Bottom = Tones.Deep.Bottom, Rail = tone.Rail }, {
		Title = Heavy({ Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 20), MaxSize = 16, Outline = 2, Gold = status ~= "Locked", Text = title, ZIndex = 4 }),
		Art = IconAt(rewardIcon(reward), 46, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 32), ZIndex = 4 }),
		Reward = Body({ Position = UDim2.fromOffset(6, 82), Size = UDim2.new(1, -12, 0, 40), TextSize = 13, TextWrapped = true, TextXAlignment = CENTER,
			TextTruncate = Enum.TextTruncate.None, Text = rewardLines(reward), ZIndex = 4 }),
		Claim = if status == "Claim" then claimButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 32),
			Disabled = busy, OnClaim = onClaim }) else nil,
		Footer = if status ~= "Claim" then Body({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -12, 0, 20), TextSize = 13,
			TextXAlignment = CENTER, TextColor3 = if status == "Claimed" then TEXT.Good else TEXT.Muted, Text = footer, ZIndex = 4 }) else nil,
		Done = if status == "Claimed" then IconAt("Check", 22, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), ZIndex = 6 }) else nil,
	})
end

local function sectionHeader(order: number, icon: string, title: string, subtitle: string)
	return e("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, {
		Icon = IconAt(icon, 40, { Position = UDim2.fromOffset(0, 2), ZIndex = 4 }),
		Title = Heavy({ Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -50, 0, 26), MaxSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Text = title, ZIndex = 4 }),
		Sub = Body({ Position = UDim2.fromOffset(50, 26), Size = UDim2.new(1, -50, 0, 16), TextSize = 13, TextColor3 = TEXT.Muted, Text = subtitle, ZIndex = 4 }),
	})
end

local function cardRow(order: number, cards: { [string]: any })
	cards.Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Wraps = true })
	return e("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, cards)
end

local function RewardsPanel(props: { Width: number, OnClose: () -> () })
	local _, setTick = React.useState(0)
	local busy, setBusy = React.useState(false)
	local status, setStatus = React.useState("")
	local code, setCode = React.useState("")

	React.useEffect(function()
		local alive = true
		local conn = RewardsStore.Changed:Connect(function() setTick(os.clock()) end)
		task.spawn(function()
			while alive do
				task.wait(1)
				setTick(os.clock())
			end
		end)
		RewardsStore.Refresh()
		return function()
			alive = false
			conn:Disconnect()
		end
	end, {})

	local function send(action: string, arg: any?)
		if busy then return end
		setBusy(true)
		task.spawn(function()
			local ok, message = RewardsStore.Request(action, arg)
			setStatus(if ok then "Claimed: " .. (message or "") else (message or "Not available."))
			if ok and action == "REDEEM_CODE" then setCode("") end
			setBusy(false)
		end)
	end

	local state = RewardsStore.State
	local narrow = props.Width < 820
	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		Pad = e("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 20), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 14) }),
	}

	if not state then
		rows.Loading = Body({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 60), TextSize = 16, TextXAlignment = CENTER, TextColor3 = TEXT.Muted, Text = "Loading your rewards…", ZIndex = 4 })
	else
		local elapsed = RewardsStore.Elapsed()
		local dayLeft = state.DayResetsIn - elapsed
		local weekLeft = state.WeekResetsIn - elapsed
		if dayLeft <= 0 then RewardsStore.Refresh() end
		local lastTier = RewardsConfig.Playtime[#RewardsConfig.Playtime]
		local played = math.min(lastTier.Minutes * 60, state.Playtime.Seconds + elapsed)

		-- Friend boost ---------------------------------------------------------------------------
		local boost = RewardsConfig.FriendBoost
		local friends = state.FriendCount or 0
		local percent = math.round(((state.FriendBoost or 1) - 1) * 100)
		local active = percent > 0
		rows.Friends = Panel({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 64), Radius = 14,
			Top = if active then Tones.Jade.Top else Tones.Slate.Top, Bottom = Tones.Deep.Bottom, Rail = if active then Tones.Jade.Rail else Tones.Slate.Rail }, {
			Icon = IconAt("Squad", 44, { Position = UDim2.fromOffset(12, 10), ZIndex = 4 }),
			Title = Heavy({ Position = UDim2.fromOffset(66, 8), Size = UDim2.new(1, -200, 0, 24), MaxSize = 20, TextXAlignment = Enum.TextXAlignment.Left,
				Text = "FRIEND BOOST", ZIndex = 4 }),
			Sub = Body({ Position = UDim2.fromOffset(66, 34), Size = UDim2.new(1, -200, 0, 18), TextSize = 13, TextColor3 = if active then TEXT.Parchment else TEXT.Muted,
				Text = if active
					then string.format("%d friend%s in this server. Kills, floor bosses and relics pay more Gold.", friends, if friends == 1 then "" else "s")
					else string.format("Play in a server with friends: +%d%% Gold each, up to +%d%%.", math.round(boost.PerFriend * 100), math.round(boost.PerFriend * boost.MaxFriends * 100)),
				ZIndex = 4 }),
			Value = Heavy({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(120, 36), MaxSize = 28,
				TextXAlignment = Enum.TextXAlignment.Right, Gold = active, TextColor3 = if active then Color3.new(1, 1, 1) else TEXT.Muted,
				Text = string.format("+%d%%", percent), ZIndex = 4 }),
		})

		-- Daily login ----------------------------------------------------------------------------
		rows.DailyHeader = sectionHeader(2, "Goal", "DAILY LOGIN",
			string.format("Streak: %d day%s · %s", state.Daily.Streak, if state.Daily.Streak == 1 then "" else "s",
				if state.Daily.CanClaim then "today's reward is ready" else "next reward in " .. RewardRules.FormatDuration(dayLeft)))
		local daily: { [string]: any } = {}
		for i, reward in RewardsConfig.Daily do
			-- Entries before the current one are done; the current one is claimable or just claimed.
			local cardStatus = if i < state.Daily.Index then "Claimed"
				elseif i == state.Daily.Index then (if state.Daily.CanClaim then "Claim" else "Claimed")
				else "Locked"
			daily["D" .. i] = rewardCard(i, "DAY " .. i, reward, cardStatus, if cardStatus == "Claimed" then "Claimed" else "Day " .. i, busy,
				function() send("CLAIM_DAILY") end)
		end
		rows.Daily = cardRow(3, daily)

		-- Weekly chest ---------------------------------------------------------------------------
		local weeklyReady = state.Weekly.CanClaim
		rows.Weekly = Panel({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 84), Radius = 14,
			Top = if weeklyReady then Tones.Void.Top else Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = if weeklyReady then Tones.Void.Rail else Tones.Deep.Rail }, {
			Icon = IconAt("Shop", 56, { Position = UDim2.fromOffset(12, 14), ZIndex = 4 }),
			Title = Heavy({ Position = UDim2.fromOffset(80, 12), Size = UDim2.new(1, -260, 0, 26), MaxSize = 22, TextXAlignment = Enum.TextXAlignment.Left,
				Text = "WEEKLY CHEST", ZIndex = 4 }),
			Reward = Body({ Position = UDim2.fromOffset(80, 40), Size = UDim2.new(1, -260, 0, 18), TextSize = 14, Text = RewardRules.Describe(RewardsConfig.Weekly, false), ZIndex = 4 }),
			Reset = Body({ Position = UDim2.fromOffset(80, 58), Size = UDim2.new(1, -260, 0, 16), TextSize = 12, TextColor3 = TEXT.Muted,
				Text = "New chest every Monday · resets in " .. RewardRules.FormatDuration(weekLeft), ZIndex = 4 }),
			Claim = if weeklyReady then claimButton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(150, 44),
				Disabled = busy, OnClaim = function() send("CLAIM_WEEKLY") end }) else nil,
			Done = if not weeklyReady then Body({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(150, 20), TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = TEXT.Good, Text = "Claimed", ZIndex = 4 }) else nil,
		})

		-- Playtime -------------------------------------------------------------------------------
		rows.PlayHeader = sectionHeader(5, "EventHourglass", "PLAYTIME REWARDS",
			string.format("Played today: %s of %d min · resets in %s", RewardRules.FormatDuration(played), lastTier.Minutes, RewardRules.FormatDuration(dayLeft)))
		local playtime: { [string]: any } = {}
		for i, tier in RewardsConfig.Playtime do
			local left = tier.Minutes * 60 - played
			local cardStatus = if state.Playtime.Claimed[i] then "Claimed" elseif left <= 0 then "Claim" else "Locked"
			playtime["P" .. i] = rewardCard(i, tier.Minutes .. " MIN", tier.Reward, cardStatus,
				if cardStatus == "Claimed" then "Claimed" else "in " .. RewardRules.FormatDuration(left), busy,
				function() send("CLAIM_PLAYTIME", i) end)
		end
		rows.Playtime = cardRow(6, playtime)

		-- Codes ----------------------------------------------------------------------------------
		rows.CodeHeader = sectionHeader(7, "Spark", "CODES", "Enter a code from the community for a one-time reward")
		rows.Codes = e("Frame", { LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			Field = Panel({ LayoutOrder = 1, Size = UDim2.fromOffset(if narrow then 200 else 320, 44), Radius = 10, Top = Tones.Slate.Top, Bottom = Tones.Slate.Bottom, Rail = Tones.Slate.Rail }, {
				Box = e("TextBox", {
					Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, ClearTextOnFocus = false,
					FontFace = Components.BodyFont, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), PlaceholderColor3 = TEXT.Muted, PlaceholderText = "ENTER CODE",
					TextXAlignment = Enum.TextXAlignment.Left, Text = code, ZIndex = 6,
					[React.Change.Text] = function(rbx: TextBox)
						-- Codes are letters and digits; keep the box within the server's limit.
						local text = string.sub(rbx.Text, 1, RewardsConfig.MaxCodeLength)
						if text ~= code then setCode(text) end
					end,
					[React.Event.FocusLost] = function(rbx: TextBox, enterPressed: boolean)
						if enterPressed and rbx.Text ~= "" then send("REDEEM_CODE", rbx.Text) end
					end,
				}),
			}),
			Redeem = e("Frame", { LayoutOrder = 2, Size = UDim2.fromOffset(140, 44), BackgroundTransparency = 1 }, {
				Button = claimButton({ Size = UDim2.fromScale(1, 1), Text = "REDEEM", Disabled = busy or code == "", OnClaim = function() send("REDEEM_CODE", code) end }),
			}),
		})
	end

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 5, 10), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 20,
		[React.Event.Activated] = function() props.OnClose() end,
	}, {
		Window = Panel({
			Class = "TextButton", Text = "", AutoButtonColor = false, -- swallows clicks so they don't reach the scrim
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 1, -24), Radius = 16, ZIndex = 21,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(1040, 760) }),
			Pop = e(WindowScale, { Window = "Index" }),
			Icon = IconAt("Gems", 60, { Position = UDim2.fromOffset(18, -12), ZIndex = 26 }),
			Title = Heavy({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(300, 48), MaxSize = 44, Text = "REWARDS", ZIndex = 25 }),
			Close = Panel({
				Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 14),
				Size = UDim2.fromOffset(48, 44), Radius = 10, Top = Tones.Crimson.Top, Bottom = Tones.Crimson.Bottom, Rail = Tones.Crimson.Rail, ZIndex = 25,
				[React.Event.Activated] = function() props.OnClose() end,
			}, {
				X = IconAt("Close", 20, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 27 }),
			}),
			Scroll = e("ScrollingFrame", {
				Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 1, -112), BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110), AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22,
			}, rows),
			Status = Body({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -40, 0, 20), TextSize = 14,
				TextXAlignment = CENTER, TextColor3 = TEXT.Muted, Text = status, ZIndex = 25 }),
		}),
	})
end

return RewardsPanel
