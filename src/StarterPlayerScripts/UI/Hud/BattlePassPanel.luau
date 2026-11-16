--!strict
-- StarterPlayerScripts/UI/Hud/BattlePassPanel.luau
-- The Battle Pass window (GDD §4.9), drawn in Gilded Grimoire like Rewards and the Store:
--   * Header: season name and time left, the level, the XP bar and the Premium button.
--   * Tabs: REWARDS and QUESTS.
--   * Rewards: one column per level, the free reward above the gold premium one, opened scrolled
--     to the player's level. A fixed column on the right previews each row's final reward.
--   * Quests: the daily and weekly quests with their progress; a finished quest pays XP on claim.
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
local CARD_HEIGHT = 138
local LABEL_HEIGHT = 26
local ROW_LABEL = 76 -- the fixed FREE / PREMIUM column
local TRACK_HEIGHT = LABEL_HEIGHT + 2 * CARD_HEIGHT + 2 * GAP + 12
local FINAL_COLUMN = 124 -- the fixed final-reward preview on the right
local QUEST_ROW = 62

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
local function rewardCard(order: number, reward: Config.Reward, status: string, premium: boolean, busy: boolean, onClaim: () -> ())
	local tone = if status == "Claimed" then Tones.Jade
		elseif premium then (if status == "Claim" then GILT_READY else GILT)
		elseif status == "Claim" then Tones.Bronze
		else Tones.Deep
	local footer = if status == "Claimed" then "Claimed" elseif status == "Premium" then "Premium" else "Locked"
	return Panel({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, CARD_HEIGHT), Radius = 12, Top = tone.Top,
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

local function rowLabel(order: number, text: string, icon: string, gold: boolean)
	return Panel({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, CARD_HEIGHT), Radius = 12,
		Top = if gold then GILT.Top else Tones.Slate.Top, Bottom = if gold then GILT.Bottom else Tones.Deep.Bottom, Rail = if gold then GOLD_GLOW else Tones.Slate.Rail }, {
		Icon = IconAt(icon, 34, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), ZIndex = 4 }),
		Text = Heavy({ Position = UDim2.fromOffset(4, 70), Size = UDim2.new(1, -8, 0, 20), MaxSize = 13, Outline = 2, Gold = gold, Text = text, ZIndex = 4 }),
	})
end

-- The last level's reward, pinned at the right of the track so the goal is always in view.
-- Tapping it scrolls the track to the end.
local function finalCard(order: number, reward: Config.Reward, status: string, premium: boolean, onActivated: () -> ())
	local tone = if status == "Claimed" then Tones.Jade elseif premium then GILT_READY else Tones.Violet
	local footer = if status == "Claimed" then "Claimed" elseif status == "Claim" then "Ready" elseif status == "Premium" then "Premium" else "Level " .. Config.MaxLevel
	return Panel({ Class = "TextButton", Text = "", AutoButtonColor = false, LayoutOrder = order, Size = UDim2.new(1, 0, 0, CARD_HEIGHT), Radius = 12,
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

-- One quest: icon, goal, progress bar and the XP it pays (a CLAIM button once it is finished).
local function questRow(order: number, quest: Config.Quest, count: number, status: string, busy: boolean, onClaim: () -> ())
	local tone = if status == "Claim" then Tones.Bronze elseif status == "Claimed" then Tones.Jade else Tones.Deep
	local side = 112
	return Panel({ LayoutOrder = order, Size = UDim2.new(1, 0, 0, QUEST_ROW), Radius = 12, Top = tone.Top, Bottom = Tones.Deep.Bottom, Rail = tone.Rail }, {
		Icon = IconAt(quest.Icon, 36, { Position = UDim2.fromOffset(10, 13), ZIndex = 4 }),
		Text = Body({ Position = UDim2.fromOffset(56, 8), Size = UDim2.new(1, -(56 + side + 8), 0, 20), TextSize = 15, RichText = false, Text = quest.Text, ZIndex = 4 }),
		Bar = e("Frame", { Position = UDim2.fromOffset(56, 34), Size = UDim2.new(1, -(56 + side + 8), 0, 16), BackgroundColor3 = Color3.fromRGB(16, 12, 24), BorderSizePixel = 0, ZIndex = 4 }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Ink = e("UIStroke", { Color = Grimoire.Ink, Thickness = 1.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			Fill = if count > 0 then e("Frame", { Size = UDim2.fromScale(math.clamp(count / quest.Goal, 0.04, 1), 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Grad = e("UIGradient", { Color = ColorSequence.new(Tones.Gold.Top, Tones.Gold.Bottom), Rotation = 90 }),
			}) else nil,
			Count = e("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = Components.NumberFont, TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = Grimoire.Ink, TextStrokeTransparency = 0.2, Text = string.format("%d / %d", count, quest.Goal), ZIndex = 6 }),
		}),
		Claim = if status == "Claim" then actionButton({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(side - 8, 40),
			Text = string.format("CLAIM +%d", quest.Xp), Disabled = busy, OnActivated = onClaim }) else nil,
		Xp = if status ~= "Claim" then Heavy({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 10), Size = UDim2.fromOffset(side - 8, 22), MaxSize = 16, Outline = 2,
			Gold = status ~= "Claimed", TextColor3 = if status == "Claimed" then TEXT.Muted else Color3.new(1, 1, 1), Text = string.format("+%d XP", quest.Xp), ZIndex = 4 }) else nil,
		State = if status == "Claimed" then Body({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 34), Size = UDim2.fromOffset(side - 8, 18), TextSize = 13,
			TextXAlignment = CENTER, TextColor3 = TEXT.Good, Text = "Claimed", ZIndex = 4 }) else nil,
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

local function BattlePassPanel(props: { Profile: any, Width: number, OnClose: () -> () })
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
	local body: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		Pad = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 12) }),
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
		body.Header = Panel({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 96), Radius = 14,
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
				Free = rewardCard(2, Config.Free[i], BattlePassRules.Status(state, "Free", i), false, busy, function() send("CLAIM", "Free", i) end),
				Paid = rewardCard(3, Config.Premium[i], BattlePassRules.Status(state, "Premium", i), true, busy, function() send("CLAIM", "Premium", i) end),
			})
		end
		local finalWidth = if narrow then 104 else FINAL_COLUMN
		local canvasWidth = Config.MaxLevel * (COLUMN + GAP) + 12
		local function showFinal()
			local track = trackRef.current
			if track then track.CanvasPosition = Vector2.new(canvasWidth, 0) end
		end
		body.Track = e("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, TRACK_HEIGHT), BackgroundTransparency = 1 }, {
			-- A gold wash behind the whole premium row.
			PremiumGlow = e("Frame", { Position = UDim2.fromOffset(-2, LABEL_HEIGHT + CARD_HEIGHT + 2 * GAP - 2), Size = UDim2.new(1, 4, 0, CARD_HEIGHT + 8),
				BackgroundColor3 = GOLD_GLOW, BackgroundTransparency = 0.84, BorderSizePixel = 0, ZIndex = 0 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 15) }),
				Edge = e("UIStroke", { Color = GOLD_GLOW, Thickness = 1.6, Transparency = 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Fade = e("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.55) }) }),
			}),
			Labels = e("Frame", { Position = UDim2.fromOffset(0, 2), Size = UDim2.new(0, ROW_LABEL, 1, -12), BackgroundTransparency = 1 }, {
				Layout = e("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
				Spacer = e("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, LABEL_HEIGHT), BackgroundTransparency = 1 }),
				Free = rowLabel(2, "FREE", "Gold", false),
				Paid = rowLabel(3, "PREMIUM", "Pass", true),
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
				Free = finalCard(2, Config.Free[Config.MaxLevel], BattlePassRules.Status(state, "Free", Config.MaxLevel), false, showFinal),
				Paid = finalCard(3, Config.Premium[Config.MaxLevel], BattlePassRules.Status(state, "Premium", Config.MaxLevel), true, showFinal),
			}),
		})
		else
		-- Quests ---------------------------------------------------------------------------------
		local now = workspace:GetServerTimeNow()
		local quests = (state :: any).Quests
		local day = if type(quests) == "table" and type(quests.Day) == "number" then quests.Day else BattlePassRules.DayOf(now)
		local week = if type(quests) == "table" and type(quests.Week) == "number" then quests.Week else BattlePassRules.WeekOf(now)
		local function section(order: number, title: string, endsAt: number, list: { Config.Quest })
			local rows: { [string]: any } = {
				Layout = e("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }),
				Head = e("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 }, {
					Title = Heavy({ Position = UDim2.fromOffset(4, 0), Size = UDim2.new(0.55, 0, 1, 0), MaxSize = 17, Outline = 2, TextXAlignment = LEFT, Text = title, ZIndex = 4 }),
					Resets = Body({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), TextSize = 13, RichText = false,
						TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = TEXT.Muted, Text = "Resets in " .. RewardRules.FormatDuration(math.max(0, endsAt - now)), ZIndex = 4 }),
				}),
			}
			for i, quest in list do
				local count, questStatus = BattlePassRules.QuestStatus(state, quest)
				rows[quest.Id] = questRow(i, quest, count, questStatus, busy, function() send("QUEST_CLAIM", quest.Id) end)
			end
			return e("Frame", { LayoutOrder = order, Size = if narrow then UDim2.new(1, 0, 0, 0) else UDim2.new(0.5, -6, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, rows)
		end
		body.Quests = e("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, {
			Layout = e("UIListLayout", { FillDirection = if narrow then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
			Daily = section(1, "DAILY QUESTS", BattlePassRules.DayEndsAt(day), Config.DailyQuests),
			Weekly = section(2, "WEEKLY QUESTS", BattlePassRules.WeekEndsAt(week), Config.WeeklyQuests),
		})
		body.Hint = Body({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 34), TextSize = 13, TextWrapped = true, TextXAlignment = CENTER, TextColor3 = TEXT.Muted,
			TextTruncate = Enum.TextTruncate.None, RichText = false,
			Text = "Quests add to the Battle Pass XP you earn from tower kills, bosses, banked relics, raids and your daily, weekly and playtime rewards.", ZIndex = 4 })
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
				ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
				AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 22,
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
