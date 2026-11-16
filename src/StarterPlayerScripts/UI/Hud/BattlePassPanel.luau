--!strict
-- StarterPlayerScripts/UI/Hud/BattlePassPanel.luau
-- The Battle Pass window (GDD §4.9), drawn in Gilded Grimoire like Rewards and the Store:
--   * Header: season name and time left, the level, the XP bar and the Premium button.
--   * Tabs: REWARDS and QUESTS.
--   * Rewards: one column per level, the free reward above the gold premium one, opened scrolled
--     to the player's level. A fixed column on the right previews each row's final reward.
--   * Quests: a daily board and a weekly board side by side, each quest with its progress; a
--     finished quest pays XP on claim.
--   * Footer: CLAIM ALL (rewards or quest XP, by tab) and the result of the last request.
-- Everything shown comes from the synced profile (profile.BattlePass). Buttons only send requests;
-- Premium is bought through Roblox's checkout and granted by the server's receipt handler.

local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("BattlePassConfig"))
local PotionConfig = require(Shared:WaitForChild("Config"):WaitForChild("PotionConfig"))
local ShopConfig = require(Shared:WaitForChild("Config"):WaitForChild("ShopConfig"))
local BattlePassRules = require(Shared:WaitForChild("Util"):WaitForChild("BattlePassRules"))
local RewardRules = require(Shared:WaitForChild("Util"):WaitForChild("RewardRules"))
local Grimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Components = require(script.Parent:WaitForChild("Components"))
local PassRemotes = require(script.Parent:WaitForChild("PassRemotes"))
local WindowScale = require(script.Parent.Parent:WaitForChild("WindowScale"))

local e = React.createElement
local Panel = Components.Panel
local Heavy = Components.HeavyLabel
local Body = Components.Body
local IconAt = Components.IconAt
local Tones = Grimoire.Tones
local TEXT = Grimoire.Text
local LocalPlayer = Players.LocalPlayer

local CLOSE_ACTION = "BattlePassClose"
local CENTER = Enum.TextXAlignment.Center
local LEFT = Enum.TextXAlignment.Left
local COLUMN = 132 -- one level column
local GAP = 8
local LABEL_HEIGHT = 26
local ROW_LABEL = 76 -- the fixed FREE / PREMIUM column
local FINAL_COLUMN = 124 -- the fixed final-reward preview on the right
local HEADER_HEIGHT = 96
-- The window never scrolls up and down when it has room: the track and the quest rows are sized
-- to the height left under the header, inside these limits. Only a very short screen scrolls.
local WINDOW_MAX_HEIGHT = 640
local WINDOW_CHROME = 158 -- title, tabs and footer around the body
local BODY_TOP, BODY_BOTTOM, BODY_GAP = 8, 12, 12
local CARD_MIN, CARD_MAX = 132, 150
local QUEST_GAP = 6
local QUEST_HEAD = 38 -- a quest board's title band
local QUEST_CHROME = QUEST_HEAD + 12 -- the band plus the board's padding
local QUEST_MIN, QUEST_MAX = 44, 60
local ROW_FILL = Color3.fromRGB(24, 17, 38)

-- The premium row's gold: dark gilt at rest, bright when a reward is ready.
local GILT = Tones.Gilded
local GILT_READY = { Top = Color3.fromRGB(214, 160, 48), Bottom = Color3.fromRGB(92, 54, 10), Rail = Tones.Gold.Rail }
local GOLD_GLOW = Color3.fromRGB(255, 204, 92)

local PREMIUM_OFFER = ShopConfig.ById("pass_premium")

local function rewardIcon(reward: Config.Reward): string
	if reward.Potions then
		for _, id in PotionConfig.Order do
			if reward.Potions[id] then return PotionConfig.Potions[id].Icon end
		end
	end
	return if reward.Gems then "Gems" elseif reward.Gold then "Gold" else "Spark"
end

local function rewardLines(reward: Config.Reward): string
	return (string.gsub(RewardRules.Describe(reward, false), " · ", "\n"))
end

local function actionButton(props: { Size: UDim2, Position: UDim2?, AnchorPoint: Vector2?, Text: string, Tone: string?, Disabled: boolean?, OnActivated: () -> () })
	local tone = if props.Disabled then Tones.Slate else (Tones :: any)[props.Tone or "Gold"]
	return Panel({
		Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = not props.Disabled, Active = not props.Disabled,
		Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, Radius = 10,
		Top = tone.Top, Bottom = tone.Bottom, Rail = tone.Rail, ZIndex = 6,
		[React.Event.Activated] = function()
			if not props.Disabled then props.OnActivated() end
		end,
	}, {
		Label = Heavy({ Position = UDim2.fromOffset(6, 2), Size = UDim2.new(1, -12, 1, -4), MaxSize = 16, Outline = 2, Gold = false, Text = props.Text, ZIndex = 8 }),
	})
end

-- One reward on the track. `status` is BattlePassRules.Status: "Claim", "Claimed", "Locked" or
-- "Premium" (level reached, premium row not unlocked).
local function rewardCard(order: number, height: number, reward: Config.Reward, status: string, premium: boolean, busy: boolean, onClaim: () -> ())
	local tone = if status == "Claimed" then Tones.Jade
		elseif premium then (if status == "Claim" then GILT_READY else GILT)
		elseif status == "Claim" then Tones.Bronze
		else Tones.Deep
	local footer = if status == "Claimed" then "Claimed" elseif status == "Premium" then "Premium" else "Locked"
	return Panel({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), Radius = 12, Top = tone.Top,
		Bottom = if premium and status ~= "Claimed" then tone.Bottom else Tones.Deep.Bottom, Rail = if premium then GOLD_GLOW else tone.Rail }, {
		Art = IconAt(rewardIcon(reward), 42, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), ZIndex = 4 }),
		Reward = Body({ Position = UDim2.fromOffset(6, 52), Size = UDim2.new(1, -12, 0, 46), TextSize = 13, TextWrapped = true, TextXAlignment = CENTER,
			TextTruncate = Enum.TextTruncate.None, RichText = false, Text = rewardLines(reward), ZIndex = 4 }),
		Claim = if status == "Claim" then actionButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 30),
			Text = "CLAIM", Disabled = busy, OnActivated = onClaim }) else nil,
		Footer = if status ~= "Claim" then Body({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -12, 0, 18), TextSize = 13,
			TextXAlignment = CENTER, TextColor3 = if status == "Claimed" then TEXT.Good elseif premium then TEXT.Gold else TEXT.Muted, Text = footer, ZIndex = 4 }) else nil,
		Done = if status == "Claimed" then IconAt("Check", 20, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), ZIndex = 6 }) else nil,
		Lock = if status == "Premium" or (status == "Locked" and premium) then IconAt("Lock", 18, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), ZIndex = 6 }) else nil,
	})
end

local function rowLabel(order: number, height: number, text: string, icon: string, gold: boolean)
	return Panel({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), Radius = 12,
		Top = if gold then GILT.Top else Tones.Slate.Top, Bottom = if gold then GILT.Bottom else Tones.Deep.Bottom, Rail = if gold then GOLD_GLOW else Tones.Slate.Rail }, {
		Icon = IconAt(icon, 34, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), ZIndex = 4 }),
		Text = Heavy({ Position = UDim2.fromOffset(4, 70), Size = UDim2.new(1, -8, 0, 20), MaxSize = 13, Outline = 2, Gold = gold, Text = text, ZIndex = 4 }),
	})
end

-- The last level's reward, pinned at the right of the track so the goal is always in view.
-- Tapping it scrolls the track to the end.
local function finalCard(order: number, height: number, reward: Config.Reward, status: string, premium: boolean, onActivated: () -> ())
	local tone = if status == "Claimed" then Tones.Jade elseif premium then GILT_READY else Tones.Violet
	local footer = if status == "Claimed" then "Claimed" elseif status == "Claim" then "Ready" elseif status == "Premium" then "Premium" else "Level " .. Config.MaxLevel
	return Panel({ Class = "TextButton", Text = "", AutoButtonColor = false, LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), Radius = 12,
		Top = tone.Top, Bottom = if premium and status ~= "Claimed" then GILT.Bottom else Tones.Deep.Bottom, Rail = if premium then Tones.Gold.Rail else tone.Rail,
		[React.Event.Activated] = onActivated }, {
		Art = IconAt(rewardIcon(reward), 46, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), ZIndex = 4 }),
		Reward = Body({ Position = UDim2.fromOffset(6, 56), Size = UDim2.new(1, -12, 0, 54), TextSize = 13, TextWrapped = true, TextXAlignment = CENTER,
			TextTruncate = Enum.TextTruncate.None, RichText = false, Text = rewardLines(reward), ZIndex = 4 }),
		Footer = Body({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -12, 0, 18), TextSize = 13, TextXAlignment = CENTER,
			TextColor3 = if status == "Claimed" or status == "Claim" then TEXT.Good elseif premium then TEXT.Gold else TEXT.Muted, Text = footer, ZIndex = 4 }),
		Done = if status == "Claimed" then IconAt("Check", 20, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), ZIndex = 6 }) else nil,
	})
end

-- One quest on a board: a medallion with the quest's icon, the goal, a slim progress bar with
-- the count beside it, and on the right the XP it pays: a gold pill while it is in progress, a
-- CLAIM button once it is finished, a tick when it is claimed (the row then dims).
-- `height` is the row's height (QUEST_MIN to QUEST_MAX); `side` the width kept for the XP side.
local function questRow(order: number, height: number, side: number, accent: Color3, quest: Config.Quest, count: number, status: string, busy: boolean, onClaim: () -> ())
	local ready, claimed = status == "Claim", status == "Claimed"
	local edge = if ready then GOLD_GLOW elseif claimed then Tones.Jade.Rail else accent
	local textLeft = 52
	local textRight = side + 14
	return e("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = if ready then Color3.fromRGB(58, 40, 14) else ROW_FILL,
		BackgroundTransparency = if claimed then 0.45 else 0, BorderSizePixel = 0, ZIndex = 3 }, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Edge = e("UIStroke", { Color = edge, Thickness = if ready then 2 else 1.4, Transparency = if ready then 0 elseif claimed then 0.5 else 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		Medal = e("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = if claimed then 0.5 else 0, BorderSizePixel = 0, ZIndex = 4 }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("UIGradient", { Color = ColorSequence.new(edge:Lerp(Color3.new(0, 0, 0), 0.45), Color3.fromRGB(14, 10, 22)), Rotation = 90 }),
			Ring = e("UIStroke", { Color = edge, Thickness = 1.6, Transparency = if claimed then 0.4 else 0.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Icon = IconAt(if claimed then "Check" else quest.Icon, 24, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }),
		}),
		Text = Body({ Position = UDim2.fromOffset(textLeft, 4), Size = UDim2.new(1, -(textLeft + textRight), 0, 18), TextSize = 14, RichText = false,
			TextColor3 = if claimed then TEXT.Muted else TEXT.Parchment, Text = quest.Text, ZIndex = 4 }),
		Bar = e("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, textLeft, 1, -8), Size = UDim2.new(1, -(textLeft + textRight + 58), 0, 8),
			BackgroundColor3 = Color3.fromRGB(12, 9, 20), BorderSizePixel = 0, ZIndex = 4 }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Ink = e("UIStroke", { Color = Grimoire.Ink, Thickness = 1.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Fill = if count > 0 then e("Frame", { Size = UDim2.fromScale(math.clamp(count / quest.Goal, 0.05, 1), 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Grad = if claimed then e("UIGradient", { Color = ColorSequence.new(Tones.Jade.Rail, Tones.Jade.Top), Rotation = 90 })
					else e("UIGradient", { Color = ColorSequence.new(Tones.Gold.Top, Tones.Gold.Bottom), Rotation = 90 }),
			}) else nil,
		}),
		Count = e("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -textRight, 1, -3), Size = UDim2.fromOffset(54, 18), BackgroundTransparency = 1,
			FontFace = Components.NumberFont, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if ready then TEXT.Gold else TEXT.Muted,
			Text = string.format("%d / %d", count, quest.Goal), ZIndex = 4 }),
		Claim = if ready then actionButton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(side, math.min(38, height - 10)),
			Text = string.format("CLAIM +%d", quest.Xp), Disabled = busy, OnActivated = onClaim }) else nil,
		-- The XP the quest pays: a gold-edged pill, greyed once it has been claimed.
		Xp = if not ready then e("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(side, 26),
			BackgroundColor3 = Color3.fromRGB(14, 10, 22), BackgroundTransparency = if claimed then 0.6 else 0.1, BorderSizePixel = 0, ZIndex = 4 }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Edge = e("UIStroke", { Color = if claimed then Tones.Slate.Rail else GOLD_GLOW, Thickness = 1.4, Transparency = if claimed then 0.5 else 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Text = Heavy({ Position = UDim2.fromOffset(4, 1), Size = UDim2.new(1, -8, 1, -2), MaxSize = 14, Outline = 1.8, Gold = not claimed,
				TextColor3 = if claimed then TEXT.Muted else Color3.new(1, 1, 1), Text = if claimed then "CLAIMED" else string.format("+%d XP", quest.Xp), ZIndex = 5 }),
		}) else nil,
	})
end

local function grouped(n: number): string
	local s = tostring(math.floor(n))
	while true do
		local replaced, count = string.gsub(s, "^(%d+)(%d%d%d)", "%1,%2")
		s = replaced
		if count == 0 then break end
	end
	return s
end

local function BattlePassPanel(props: { Profile: any, Width: number, Height: number?, OnClose: () -> () })
	local _, setTick = React.useState(0)
	local busy, setBusy = React.useState(false)
	local status, setStatus = React.useState("")
	local price, setPrice = React.useState(if PREMIUM_OFFER then PREMIUM_OFFER.RobuxPrice else 0)
	local tab, setTab = React.useState("Rewards")
	local trackRef = React.useRef(nil :: ScrollingFrame?)

	local state = BattlePassRules.Read(props.Profile)
	local level = if state then BattlePassRules.LevelOf(state.Xp) else 0

	React.useEffect(function()
		local alive = true
		ContextActionService:BindAction(CLOSE_ACTION, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then props.OnClose() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonB)
		-- The season countdown ticks once a second.
		task.spawn(function()
			while alive do
				task.wait(1)
				setTick(os.clock())
			end
		end)
		-- Live Robux price (regional pricing can differ from the fallback label).
		local offer = PREMIUM_OFFER
		if offer and offer.ProductId ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function() return MarketplaceService:GetProductInfo(offer.ProductId, Enum.InfoType.Product) end)
				if alive and ok and info and (info :: any).PriceInRobux then setPrice((info :: any).PriceInRobux) end
			end)
		end
		local conn = MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
			if userId == LocalPlayer.UserId and offer and productId == offer.ProductId then
				setStatus(if purchased then "Thank you! Your Premium Pass is on its way." else "Purchase cancelled.")
			end
		end)
		return function()
			alive = false
			ContextActionService:UnbindAction(CLOSE_ACTION)
			conn:Disconnect()
		end
	end, {})

	-- Open on the player's level: scroll its column near the left edge, once the state is in
	-- (and again when the Rewards tab comes back).
	React.useEffect(function()
		local track = trackRef.current
		if track and state then
			track.CanvasPosition = Vector2.new(math.max(0, (level - 1) * (COLUMN + GAP)), 0)
		end
	end, { state ~= nil, tab } :: { any })

	local function send(action: string, track: string?, claimLevel: number?)
		if busy then return end
		setBusy(true)
		task.spawn(function()
			local ok, message = PassRemotes.Pass(action, track, claimLevel)
			setStatus(if ok then (if action == "DEV_UNLOCK" then "" else "Claimed: ") .. (message or "") else (message or "Not available."))
			setBusy(false)
		end)
	end

	local function buyPremium()
		local offer = PREMIUM_OFFER
		if not offer then return end
		if offer.ProductId == 0 then
			-- No product yet: Studio can still unlock the row to test it (the server refuses this outside Studio).
			if RunService:IsStudio() then send("DEV_UNLOCK") else setStatus("The Premium Pass isn't on sale yet.") end
			return
		end
		setStatus("Opening Roblox checkout…")
		MarketplaceService:PromptProductPurchase(LocalPlayer, offer.ProductId)
	end

	local narrow = props.Width < 760
	-- Height of the body area, and what is left in it under the header for the track or the quests.
	local bodyHeight = math.min((props.Height or 720) - 24, WINDOW_MAX_HEIGHT) - WINDOW_CHROME
	local room = bodyHeight - BODY_TOP - BODY_BOTTOM - HEADER_HEIGHT - BODY_GAP
	local contentHeight = 0 -- what the body needs; it scrolls only when this is more than bodyHeight
	local body: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, BODY_GAP), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		Pad = e("UIPadding", { PaddingTop = UDim.new(0, BODY_TOP), PaddingBottom = UDim.new(0, BODY_BOTTOM), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 12) }),
	}
	local claimable = 0
	local questClaimable = 0

	if not state then
		body.Loading = Body({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 60), TextSize = 16, TextXAlignment = CENTER, TextColor3 = TEXT.Muted, Text = "Loading your Battle Pass…", ZIndex = 4 })
	else
		claimable = BattlePassRules.ClaimableCount(state)
		questClaimable = BattlePassRules.QuestClaimableCount(state)
		local into, needed = BattlePassRules.Progress(state.Xp)
		local maxed = level >= Config.MaxLevel
		local endsIn = BattlePassRules.SeasonEndsAt(state.Season) - os.time()
		local offer = PREMIUM_OFFER
		local onSale = offer ~= nil and offer.ProductId ~= 0
		local premiumText = if onSale then string.format("PREMIUM · R$ %s", grouped(price))
			elseif RunService:IsStudio() then "UNLOCK (STUDIO)"
			else "COMING SOON"
		local buttonWidth = if narrow then 150 else 210

		-- Header ---------------------------------------------------------------------------------
		body.Header = Panel({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, HEADER_HEIGHT), Radius = 14,
			Top = if state.Premium then GILT.Top else Tones.Violet.Top, Bottom = if state.Premium then GILT.Bottom else Tones.Deep.Bottom,
			Rail = if state.Premium then GOLD_GLOW else Tones.Violet.Rail }, {
			Badge = Panel({ Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(72, 72), Radius = 14,
				Top = Tones.Gold.Top, Bottom = Tones.Gold.Bottom, Rail = Tones.Gold.Rail, ZIndex = 4 }, {
				Caption = Heavy({ Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 16), MaxSize = 12, Outline = 2, Gold = false, Text = "LEVEL", ZIndex = 6 }),
				Value = Heavy({ Position = UDim2.fromOffset(4, 22), Size = UDim2.new(1, -8, 0, 42), MaxSize = 38, Outline = 2.6, Gold = false, Text = tostring(level), ZIndex = 6 }),
			}),
			Season = Heavy({ Position = UDim2.fromOffset(96, 10), Size = UDim2.new(1, -(108 + buttonWidth + 16), 0, 24), MaxSize = 20, TextXAlignment = LEFT,
				Text = string.upper(BattlePassRules.SeasonName(state.Season)), ZIndex = 4 }),
			Ends = Body({ Position = UDim2.fromOffset(96, 36), Size = UDim2.new(1, -(108 + buttonWidth + 16), 0, 16), TextSize = 13, TextColor3 = TEXT.Muted, RichText = false,
				Text = "Ends in " .. RewardRules.FormatDuration(endsIn) .. " · unclaimed rewards are delivered", ZIndex = 4 }),
			Track = e("Frame", { Position = UDim2.fromOffset(96, 58), Size = UDim2.new(1, -(108 + buttonWidth + 16), 0, 16), BackgroundColor3 = Color3.fromRGB(16, 12, 24),
				BorderSizePixel = 0, ZIndex = 4 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Ink = e("UIStroke", { Color = Grimoire.Ink, Thickness = 1.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Fill = e("Frame", { Size = UDim2.fromScale(math.clamp(into / needed, 0.02, 1), 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5 }, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Grad = e("UIGradient", { Color = ColorSequence.new(Tones.Gold.Top, Tones.Gold.Bottom), Rotation = 90 }),
				}),
			}),
			Xp = Body({ Position = UDim2.fromOffset(96, 76), Size = UDim2.new(1, -(108 + buttonWidth + 16), 0, 14), TextSize = 12, RichText = false,
				Text = if maxed then "Max level reached" else string.format("%s / %s XP to level %d", grouped(into), grouped(needed), level + 1), ZIndex = 4 }),
			Premium = if state.Premium then Heavy({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(buttonWidth, 30),
					MaxSize = 18, TextXAlignment = Enum.TextXAlignment.Right, Text = "PREMIUM ACTIVE", ZIndex = 4 })
				else actionButton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(buttonWidth, 46),
					Text = premiumText, Tone = "Action", Disabled = busy or (not onSale and not RunService:IsStudio()), OnActivated = buyPremium }),
		})

		if tab == "Rewards" then
		-- Track ----------------------------------------------------------------------------------
		local trackChrome = LABEL_HEIGHT + 2 * GAP + 12
		local cardHeight = math.clamp(math.floor((room - trackChrome) / 2), CARD_MIN, CARD_MAX)
		local trackHeight = 2 * cardHeight + trackChrome
		contentHeight = BODY_TOP + HEADER_HEIGHT + BODY_GAP + trackHeight + BODY_BOTTOM
		local columns: { [string]: any } = {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }),
		}
		for i = 1, Config.MaxLevel do
			local reached = i <= level
			columns["L" .. i] = e("Frame", { LayoutOrder = i, Size = UDim2.new(0, COLUMN, 1, -12), BackgroundTransparency = 1 }, {
				Layout = e("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
				Level = Heavy({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, LABEL_HEIGHT), MaxSize = 16, Outline = 2, Gold = reached,
					TextColor3 = if reached then Color3.new(1, 1, 1) else TEXT.Muted, Text = "LEVEL " .. i, ZIndex = 4 }),
				Free = rewardCard(2, cardHeight, Config.Free[i], BattlePassRules.Status(state, "Free", i), false, busy, function() send("CLAIM", "Free", i) end),
				Paid = rewardCard(3, cardHeight, Config.Premium[i], BattlePassRules.Status(state, "Premium", i), true, busy, function() send("CLAIM", "Premium", i) end),
			})
		end
		local finalWidth = if narrow then 104 else FINAL_COLUMN
		local canvasWidth = Config.MaxLevel * (COLUMN + GAP) + 12
		local function showFinal()
			local track = trackRef.current
			if track then track.CanvasPosition = Vector2.new(canvasWidth, 0) end
		end
		body.Track = e("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, trackHeight), BackgroundTransparency = 1 }, {
			-- A gold wash behind the whole premium row.
			PremiumGlow = e("Frame", { Position = UDim2.fromOffset(-2, LABEL_HEIGHT + cardHeight + 2 * GAP - 2), Size = UDim2.new(1, 4, 0, cardHeight + 8),
				BackgroundColor3 = GOLD_GLOW, BackgroundTransparency = 0.84, BorderSizePixel = 0, ZIndex = 0 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 15) }),
				Edge = e("UIStroke", { Color = GOLD_GLOW, Thickness = 1.6, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Fade = e("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.55) }) }),
			}),
			Labels = e("Frame", { Position = UDim2.fromOffset(0, 2), Size = UDim2.new(0, ROW_LABEL, 1, -12), BackgroundTransparency = 1 }, {
				Layout = e("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
				Spacer = e("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, LABEL_HEIGHT), BackgroundTransparency = 1 }),
				Free = rowLabel(2, cardHeight, "FREE", "Gold", false),
				Paid = rowLabel(3, cardHeight, "PREMIUM", "Pass", true),
			}),
			Scroll = e("ScrollingFrame", {
				ref = trackRef, Position = UDim2.fromOffset(ROW_LABEL + GAP, 0), Size = UDim2.new(1, -(ROW_LABEL + GAP + finalWidth + GAP), 1, 0),
				BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.X,
				CanvasSize = UDim2.fromOffset(canvasWidth, 0), ScrollBarThickness = 6,
				ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110), ZIndex = 3,
			}, columns),
			Final = e("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.new(0, finalWidth, 1, -12), BackgroundTransparency = 1 }, {
				Layout = e("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
				Title = Heavy({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, LABEL_HEIGHT), MaxSize = 14, Outline = 2, Text = "FINAL REWARD", ZIndex = 4 }),
				Free = finalCard(2, cardHeight, Config.Free[Config.MaxLevel], BattlePassRules.Status(state, "Free", Config.MaxLevel), false, showFinal),
				Paid = finalCard(3, cardHeight, Config.Premium[Config.MaxLevel], BattlePassRules.Status(state, "Premium", Config.MaxLevel), true, showFinal),
			}),
		})
		else
		-- Quests ---------------------------------------------------------------------------------
		local now = workspace:GetServerTimeNow()
		local quests = (state :: any).Quests
		local day = if type(quests) == "table" and type(quests.Day) == "number" then quests.Day else BattlePassRules.DayOf(now)
		local week = if type(quests) == "table" and type(quests.Week) == "number" then quests.Week else BattlePassRules.WeekOf(now)
		-- Daily and weekly sit side by side at every width, with rows sized to the room, so the
		-- whole list is in view without scrolling.
		local rowCount = math.max(#Config.DailyQuests, #Config.WeeklyQuests)
		local rowHeight = math.clamp(math.floor((room - QUEST_CHROME) / rowCount) - QUEST_GAP, QUEST_MIN, QUEST_MAX)
		local questsHeight = QUEST_CHROME + rowCount * (rowHeight + QUEST_GAP)
		local side = if narrow then 86 else 104
		contentHeight = BODY_TOP + HEADER_HEIGHT + BODY_GAP + questsHeight + BODY_BOTTOM
		-- A quest board: a framed panel in its own tone with a title band (icon, title, how many
		-- are done, time to the reset) over its rows.
		local function board(order: number, title: string, icon: string, tone: any, endsAt: number, list: { Config.Quest })
			local rows: { [string]: any } = {
				Layout = e("UIListLayout", { Padding = UDim.new(0, QUEST_GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
			}
			local done = 0
			for i, quest in list do
				local count, questStatus = BattlePassRules.QuestStatus(state, quest)
				if questStatus ~= "Progress" then done += 1 end
				rows[quest.Id] = questRow(i, rowHeight, side, tone.Rail, quest, count, questStatus, busy, function() send("QUEST_CLAIM", quest.Id) end)
			end
			local allDone = done == #list
			return Panel({ LayoutOrder = order, Size = UDim2.new(0.5, -6, 1, 0), Radius = 14, Top = tone.Top, Bottom = Tones.Deep.Bottom, Rail = tone.Rail }, {
				Icon = IconAt(icon, 26, { Position = UDim2.fromOffset(10, 7), ZIndex = 4 }),
				Title = Heavy({ Position = UDim2.fromOffset(42, 6), Size = UDim2.new(0.5, -46, 0, 26), MaxSize = if narrow then 15 else 19, Outline = 2, TextXAlignment = LEFT, Text = title, ZIndex = 4 }),
				Done = e("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(50, 22),
					BackgroundColor3 = if allDone then Tones.Jade.Top else Color3.fromRGB(14, 10, 22), BorderSizePixel = 0, ZIndex = 4 }, {
					Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Edge = e("UIStroke", { Color = if allDone then Tones.Jade.Rail else tone.Rail, Thickness = 1.4, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					Text = e("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = Components.NumberFont, TextSize = 13,
						TextColor3 = if allDone then TEXT.Good else TEXT.Parchment, Text = string.format("%d / %d", done, #list), ZIndex = 5 }),
				}),
				Resets = Body({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -68, 0, 8), Size = UDim2.new(0.5, -72, 0, 22), TextSize = if narrow then 11 else 13, RichText = false,
					TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = TEXT.Muted, Text = "Resets in " .. RewardRules.FormatDuration(math.max(0, endsAt - now)), ZIndex = 4 }),
				Rows = e("Frame", { Position = UDim2.fromOffset(8, QUEST_HEAD), Size = UDim2.new(1, -16, 1, -(QUEST_HEAD + 8)), BackgroundTransparency = 1, ZIndex = 2 }, rows),
			})
		end
		body.Quests = e("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, questsHeight), BackgroundTransparency = 1 }, {
			Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
			Daily = board(1, "DAILY QUESTS", "EventHourglass", Tones.Violet, BattlePassRules.DayEndsAt(day), Config.DailyQuests),
			Weekly = board(2, "WEEKLY QUESTS", "Banner", Tones.Azure, BattlePassRules.WeekEndsAt(week), Config.WeeklyQuests),
		})
		end
	end

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 5, 10), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 20,
		[React.Event.Activated] = function() props.OnClose() end,
	}, {
		Window = Panel({
			Class = "TextButton", Text = "", AutoButtonColor = false, -- swallows clicks so they don't reach the scrim
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 1, -24), Radius = 16, ZIndex = 21,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(1040, 640) }),
			Pop = e(WindowScale, { Window = "Index" }),
			Icon = IconAt("Pass", 60, { Position = UDim2.fromOffset(18, -12), ZIndex = 26 }),
			Title = Heavy({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(340, 48), MaxSize = 40, Text = "BATTLE PASS", ZIndex = 25 }),
			Close = Panel({
				Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 14),
				Size = UDim2.fromOffset(48, 44), Radius = 10, Top = Tones.Crimson.Top, Bottom = Tones.Crimson.Bottom, Rail = Tones.Crimson.Rail, ZIndex = 25,
				[React.Event.Activated] = function() props.OnClose() end,
			}, {
				X = IconAt("Close", 20, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 27 }),
			}),
			Tabs = e("Frame", { Position = UDim2.fromOffset(20, 62), Size = UDim2.fromOffset(320, 34), BackgroundTransparency = 1, ZIndex = 24 }, {
				Rewards = actionButton({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(154, 34), Tone = if tab == "Rewards" then "Gold" else "Deep",
					Text = if claimable > 0 then string.format("REWARDS (%d)", claimable) else "REWARDS", OnActivated = function() setTab("Rewards") end }),
				Quests = actionButton({ Position = UDim2.fromOffset(162, 0), Size = UDim2.fromOffset(154, 34), Tone = if tab == "Quests" then "Gold" else "Deep",
					Text = if questClaimable > 0 then string.format("QUESTS (%d)", questClaimable) else "QUESTS", OnActivated = function() setTab("Quests") end }),
			}),
			Scroll = e("ScrollingFrame", {
				Position = UDim2.fromOffset(16, 102), Size = UDim2.new(1, -32, 1, -158), BackgroundTransparency = 1, BorderSizePixel = 0,
				-- The body is sized to fit, so this only scrolls on a screen too short for the minimum sizes.
				ScrollingDirection = Enum.ScrollingDirection.Y, ScrollingEnabled = contentHeight > bodyHeight,
				ScrollBarThickness = if contentHeight > bodyHeight then 6 else 0, ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
				CanvasSize = if contentHeight > bodyHeight then UDim2.fromOffset(0, contentHeight) else UDim2.new(), ZIndex = 22,
			}, body),
			Status = Body({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -18), Size = UDim2.new(1, -230, 0, 20), TextSize = 14,
				TextColor3 = TEXT.Muted, RichText = false, Text = status, ZIndex = 25 }),
			ClaimAll = actionButton({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -10), Size = UDim2.fromOffset(180, 40),
				Text = if tab == "Quests" then (if questClaimable > 0 then string.format("CLAIM ALL (%d)", questClaimable) else "CLAIM ALL")
					elseif claimable > 0 then string.format("CLAIM ALL (%d)", claimable) else "CLAIM ALL",
				Disabled = busy or (if tab == "Quests" then questClaimable == 0 else claimable == 0),
				OnActivated = function() send(if tab == "Quests" then "QUEST_CLAIM_ALL" else "CLAIM_ALL") end }),
		}),
	})
end

return BattlePassPanel
