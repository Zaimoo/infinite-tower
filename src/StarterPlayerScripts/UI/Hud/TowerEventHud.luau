--!strict
-- StarterPlayerScripts/UI/Hud/TowerEventHud.luau
-- Timed tower events on the HUD (Phase G; mockup: docs/ui/tower-event-hud-mockup.html):
--   Badge  bottom right, above Squad Power: icon, name, timer and a gilded bar, with a hover/tap tooltip.
--   Popup  centred card when an event starts (never blocks input; waits while a full-screen panel is open).
-- Event state comes from ReplicatedStorage attributes (TowerEventService); names, icons and text come
-- from Shared/Config/TowerEventConfig, so nothing else crosses the network.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared:WaitForChild("Config"):WaitForChild("TowerEventConfig"))
local MobCatalog = require(Shared:WaitForChild("Config"):WaitForChild("MobCatalog"))
local EventRules = require(Shared:WaitForChild("Util"):WaitForChild("TowerEventRules"))
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Components = require(script.Parent:WaitForChild("Components"))

local e = React.createElement
local G = Theme.Glass
local L = Theme.Layout

local TowerEventHud = {}

local MOB_RED = Color3.fromRGB(255, 138, 138)
local GOLD = G.Royal

export type State = {
	Phase: string,
	Event: EventConfig.Event?,
	Biome: number,
	BiomeName: string?,
	SecondsLeft: number,
	Fraction: number,
	StartsAt: number,
}

local function read(): State
	local phase = ReplicatedStorage:GetAttribute("TowerEventPhase") or "CALM"
	local startsAt = ReplicatedStorage:GetAttribute("TowerEventStartsAt") or 0
	local endsAt = ReplicatedStorage:GetAttribute("TowerEventEndsAt") or 0
	local biome = ReplicatedStorage:GetAttribute("TowerEventBiome") or 0
	local left, fraction = EventRules.Timer(phase, Workspace:GetServerTimeNow(), startsAt, endsAt, EventConfig.WarningSeconds)
	local biomeEntry = biome > 0 and MobCatalog.Biomes[biome] or nil
	return {
		Phase = phase,
		Event = if phase ~= "CALM" then EventConfig.Get(ReplicatedStorage:GetAttribute("TowerEventId")) else nil,
		Biome = biome,
		BiomeName = biomeEntry and biomeEntry.DisplayName or nil,
		SecondsLeft = left,
		Fraction = fraction,
		StartsAt = startsAt,
	}
end

-- Current event state, refreshed when an attribute changes and once a second for the timer.
function TowerEventHud.useTowerEvent(): State
	local state, setState = React.useState(read)
	React.useEffect(function()
		local alive = true
		local connections = {}
		for _, name in { "TowerEventPhase", "TowerEventId", "TowerEventStartsAt", "TowerEventEndsAt", "TowerEventBiome" } do
			table.insert(connections, ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function()
				setState(read())
			end))
		end
		task.spawn(function()
			while alive do
				task.wait(1)
				if alive then setState(read()) end
			end
		end)
		return function()
			alive = false
			for _, c in connections do c:Disconnect() end
		end
	end, {})
	return state
end

local function scopeText(state: State): string
	local event = state.Event
	if not event then return "" end
	if event.Scope == "BIOME" then
		return "Featured biome: " .. (state.BiomeName or "?")
	end
	return if event.MinFloor > 1 then string.format("Whole tower · floors %d–50", event.MinFloor) else "Whole tower"
end

local function goldTitle(props: { [string]: any })
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = GildedGrimoire.Fonts.Title,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
	}
	for k, v in props do base[k] = v end
	return e("TextLabel", base, {
		Gradient = e("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), GildedGrimoire.Text.Gold) }),
	})
end

-- The tooltip: title, scope, description, effect lines and the stamping footnote.
local function tooltip(state: State)
	local event = state.Event
	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
		Head = e("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1 }, {
			Icon = Components.IconAt(if event then event.Icon else "EventHourglass", 36, { Position = UDim2.fromOffset(0, 0), Flat = true }),
			Title = goldTitle({ Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -44, 1, 0), TextSize = 17,
				Text = if event then event.DisplayName else "The tower is calm" }),
		}),
	}
	local order = 2
	local function line(key: string, text: string, color: Color3?, italic: boolean?)
		rows[key] = Components.GlassText({
			LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
			TextSize = 12, Text = text, TextColor3 = color or G.Text,
			FontFace = if italic then Font.new(G.Fonts.Label.Family, Enum.FontWeight.Medium, Enum.FontStyle.Italic) else G.Fonts.Label,
		})
		order += 1
	end
	if not event then
		line("Calm", string.format("Next event in %s. Events are announced 60 seconds before they begin.", EventRules.Format(state.SecondsLeft)))
	else
		line("Scope", scopeText(state), Color3.fromRGB(205, 200, 220))
		if state.Phase == "WARNING" then line("Begins", "Begins in " .. EventRules.Format(state.SecondsLeft), GOLD) end
		line("Description", event.Description, nil, true)
		for i, text in event.MobEffects do line("Mob" .. i, "◆ " .. text, MOB_RED) end
		for i, text in event.RewardEffects do line("Reward" .. i, "◆ " .. text, GOLD) end
		line("Foot", "Monsters that appear during the event keep its bonus until defeated.", Color3.fromRGB(170, 160, 190))
	end
	return Components.Glass({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -8),
		Size = UDim2.fromOffset(270, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.15,
		ZIndex = 5,
	}, rows)
end

-- Bottom-right badge, directly above the Squad Power badge (props.Bottom: its bottom offset).
function TowerEventHud.Badge(props: { Compact: boolean, Bottom: number })
	local state = TowerEventHud.useTowerEvent()
	local hover, setHover = React.useState(false)
	local strokeRef = React.useRef(nil)
	local event = state.Event
	local width = if props.Compact then 130 else L.PowerBadgeWidth
	local height = if props.Compact then 40 else L.EventBadgeHeight

	-- Stroke: event accent while active, a gold pulse during the warning, the plain hairline while calm.
	React.useEffect(function()
		local stroke = strokeRef.current :: UIStroke?
		if not stroke then return end
		if state.Phase == "ACTIVE" and event then
			stroke.Color, stroke.Transparency, stroke.Thickness = event.Accent, 0, 1.5
		elseif state.Phase == "WARNING" then
			stroke.Color, stroke.Transparency, stroke.Thickness = GOLD, if math.floor(state.SecondsLeft) % 2 == 0 then 0 else 0.7, 1.5
		else
			stroke.Color, stroke.Transparency, stroke.Thickness = G.Hairline, G.HairlineTransparency, 1
		end
		return nil
	end, { state.Phase, state.SecondsLeft, event and event.Id or "" } :: { any })

	local iconName = if event then event.Icon else "EventHourglass"
	local name = if state.Phase == "CALM" then "Next event"
		elseif state.Phase == "WARNING" and event then event.DisplayName .. " in"
		elseif event then event.DisplayName else ""
	local label = if event and event.Scope == "BIOME" and state.BiomeName then state.BiomeName else "Tower event"
	local barColor = if state.Phase == "WARNING" then GOLD elseif event then event.Accent else G.Hairline

	return e("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -L.Edge, 1, -props.Bottom),
		Size = UDim2.fromOffset(width, height),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		[React.Event.MouseEnter] = function() setHover(true) end,
		[React.Event.MouseLeave] = function() setHover(false) end,
		[React.Event.Activated] = function() setHover(not hover) end,
	}, {
		Body = Components.Glass({ Size = UDim2.fromScale(1, 1), StrokeRef = strokeRef }, {
			Icon = Components.IconAt(iconName, if props.Compact then 24 else 30, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Flat = true }),
			Label = if not props.Compact then Components.SectionLabel(label, { Position = UDim2.fromOffset(48, 6), Size = UDim2.new(1, -100, 0, 14) }) else nil,
			Timer = Components.GlassText({
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, if props.Compact then 0 else 4),
				Size = UDim2.fromOffset(60, if props.Compact then height else 18), TextXAlignment = Enum.TextXAlignment.Right,
				FontFace = G.Fonts.Display, TextSize = if props.Compact then 18 else 14,
				TextColor3 = if state.Phase == "CALM" then G.TextMuted else GOLD, Text = EventRules.Format(state.SecondsLeft),
			}),
			Name = if not props.Compact then Components.GlassText({
				Position = UDim2.fromOffset(48, 22), Size = UDim2.new(1, -58, 0, 20), FontFace = G.Fonts.Display,
				TextSize = 15, Text = name, TextColor3 = if state.Phase == "CALM" then G.TextMuted else G.Text,
			}) else nil,
			Bar = if not props.Compact and state.Phase ~= "CALM" then e("Frame", {
				Position = UDim2.new(0, 10, 1, -7), Size = UDim2.new(1, -20, 0, 3), BackgroundTransparency = 1,
			}, { Fill = Components.GlassBar(state.Fraction, barColor, 1, 3) }) else nil,
		}),
		Tooltip = if hover then tooltip(state) else nil,
	})
end

-- Centre pop-up when an event starts (WARNING -> ACTIVE while this client is running). It never takes
-- input, waits while props.Blocked (a full-screen panel is open) and is dropped after 20 s of waiting.
function TowerEventHud.Popup(props: { Blocked: boolean })
	local state = TowerEventHud.useTowerEvent()
	local pending, setPending = React.useState(nil :: { Event: EventConfig.Event, At: number, Scope: string }?)
	local showing, setShowing = React.useState(nil :: { Event: EventConfig.Event, Scope: string }?)
	local previous = React.useRef({ Phase = state.Phase, StartsAt = state.StartsAt })
	local groupRef = React.useRef(nil)
	local scaleRef = React.useRef(nil)
	local raysRef = React.useRef(nil)

	React.useEffect(function()
		local before = previous.current
		if before.Phase == "WARNING" and state.Phase == "ACTIVE" and state.Event then
			setPending({ Event = state.Event, At = os.clock(), Scope = scopeText(state) })
		end
		previous.current = { Phase = state.Phase, StartsAt = state.StartsAt }
		return nil
	end, { state.Phase, state.StartsAt } :: { any })

	React.useEffect(function()
		if not pending or showing then return nil end
		if os.clock() - pending.At > 20 then setPending(nil); return nil end
		if props.Blocked then return nil end
		setShowing({ Event = pending.Event, Scope = pending.Scope })
		setPending(nil)
		return nil
	end, { pending, props.Blocked, showing, state.SecondsLeft } :: { any })

	React.useEffect(function()
		local group = groupRef.current :: CanvasGroup?
		local scale = scaleRef.current :: UIScale?
		if not showing or not group or not scale then return nil end
		group.GroupTransparency, scale.Scale = 1, 0.85
		local popIn = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(group, popIn, { GroupTransparency = 0 }):Play()
		TweenService:Create(scale, popIn, { Scale = 1 }):Play()
		local rays = raysRef.current :: Frame?
		local spin: Tween? = nil
		if rays then
			spin = TweenService:Create(rays, TweenInfo.new(12, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
			spin:Play()
		end
		local alive = true
		task.delay(3.85, function()
			if not alive then return end
			TweenService:Create(group, TweenInfo.new(0.4), { GroupTransparency = 1 }):Play()
			task.delay(0.45, function() if alive then setShowing(nil) end end)
		end)
		return function()
			alive = false
			if spin then spin:Cancel() end
		end
	end, { showing })

	if not showing then return nil end
	local event = showing.Event
	local rays: { [string]: any } = {}
	for i = 1, 8 do
		rays["Ray" .. i] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 52),
			Rotation = i * 45, BackgroundColor3 = GildedGrimoire.Text.Gold, BackgroundTransparency = 0.45, BorderSizePixel = 0,
		})
	end
	return e("CanvasGroup", {
		ref = groupRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(440, 160),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Active = false,
		ZIndex = 40,
	}, {
		Scale = e("UIScale", { ref = scaleRef, Scale = 0.85 }),
		Card = Components.Glass({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.22, Radius = 12, Active = false }, {
			Accent = e("UIStroke", { Color = event.Accent, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
			IconWrap = e("Frame", { Position = UDim2.fromOffset(22, 32), Size = UDim2.fromOffset(96, 96), BackgroundTransparency = 1 }, {
				Rays = e("Frame", { ref = raysRef, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, rays),
				Icon = Components.IconAt(event.Icon, 76, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }),
			}),
			Eyebrow = Components.GlassText({ Position = UDim2.fromOffset(136, 30), Size = UDim2.new(1, -150, 0, 14), TextSize = 10,
				Text = "TOWER EVENT BEGINS", TextTransparency = G.MutedTransparency }),
			Title = goldTitle({ Position = UDim2.fromOffset(136, 46), Size = UDim2.new(1, -150, 0, 32), TextSize = 24,
				Text = string.upper(event.DisplayName) }),
			Description = Components.GlassText({ Position = UDim2.fromOffset(136, 82), Size = UDim2.new(1, -150, 0, 34), TextSize = 12,
				TextWrapped = true, Text = event.Description }),
			Scope = Components.GlassText({ Position = UDim2.fromOffset(136, 118), Size = UDim2.new(1, -150, 0, 14), TextSize = 11,
				TextTransparency = G.MutedTransparency, Text = showing.Scope .. " · " .. EventRules.Format(EventConfig.ActiveSeconds) }),
		}),
	})
end

return TowerEventHud
