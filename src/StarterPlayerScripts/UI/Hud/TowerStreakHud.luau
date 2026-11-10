--!strict

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hardcore = require(Shared.Config.TowerHardcoreConfig)
local TowerRun = require(Shared.Util.TowerRun)
local Icons = require(Shared.Util.GrimoireIcons)
local Kit = require(script.Parent.Parent.Kit)
local UIFeel = require(script.Parent.Parent.UIFeel)
local Tokens = Kit.Tokens
local New = Tokens.New

local TowerStreakHud = {}

function TowerStreakHud.Mount(banner: Frame, title: TextLabel, bar: GuiObject, remotes: Instance)
	local screen = banner.Parent :: ScreenGui
	local content = New("Frame", {
		Name = "FloorBannerContent", BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
	}, banner)
	New("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, content)
	local progress = New("Frame", {
		Name = "Progress", LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58),
	}, content)
	title.Parent = progress
	bar.Parent = progress
	banner.AutomaticSize = Enum.AutomaticSize.Y
	New("UISizeConstraint", { MaxSize = Vector2.new(720, math.huge) }, banner)

	local row = New("Frame", {
		Name = "ClimbStreak", LayoutOrder = 2, Visible = false, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y,
	}, content)
	New("UIPadding", {
		PaddingLeft = UDim.new(0, Tokens.Space.L), PaddingRight = UDim.new(0, Tokens.Space.L),
		PaddingBottom = UDim.new(0, Tokens.Space.S),
	}, row)
	local icon = Icons.Create("Spark", 16, row, 3)
	local badge = Tokens.Label(row, "", Tokens.Type.Caption, "Body", {
		Name = "Bonus", Position = UDim2.fromOffset(16 + Tokens.Space.S, 0),
		Size = UDim2.new(1, -(16 + Tokens.Space.S), 0, 16), AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3,
	})
	local tip = Tokens.Label(content, "Clear the next floor to grow your streak. Bank relics at a sanctuary to collect the bonus.", Tokens.Type.Caption, "Body", {
		Name = "ClimbStreakTip", LayoutOrder = 3, Visible = false, TextWrapped = true,
		Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 3,
	})
	New("UIPadding", {
		PaddingLeft = UDim.new(0, Tokens.Space.L), PaddingRight = UDim.new(0, Tokens.Space.L),
		PaddingBottom = UDim.new(0, Tokens.Space.S),
	}, tip)

	local callout = Kit.Callout.Create(screen, {
		Name = "ClimbStreakPortalHint", Height = 48, Text = "",
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(720, math.huge) }, callout.Instance)
	local function placeOverlays()
		local bottom = banner.Position.Y.Offset + banner.AbsoluteSize.Y
		local hintTop = bottom + Tokens.Space.S
		local compact = screen.AbsoluteSize.Y < 420 and screen.AbsoluteSize.X >= 600
		callout.Instance.AnchorPoint = Vector2.new(if compact then 0 else 0.5, 0)
		callout.Instance.Position = if compact then UDim2.fromOffset(16, hintTop) else UDim2.new(0.5, 0, 0, hintTop)
		callout.Instance.Size = UDim2.new(if compact then 0.5 else 1, -32, 0, 48)
		Kit.Notify.SetTopInset(if not banner.Visible then 0
			elseif callout.Instance.Visible and not compact then hintTop + 48 else bottom, banner.Visible and compact)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeOverlays)
	banner:GetPropertyChangedSignal("Position"):Connect(placeOverlays)
	banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeOverlays)
	banner:GetPropertyChangedSignal("Visible"):Connect(placeOverlays)
	callout.Instance:GetPropertyChangedSignal("Visible"):Connect(placeOverlays)
	placeOverlays()

	local active = false
	local streak = 0
	local multiplier = 1
	local lastClearedFloor: number? = nil
	local celebratedCap = false
	local firstClearSeen = false
	local tipFloor: number? = nil
	local pendingTravel = false
	local prompts: { [ProximityPrompt]: number } = {}
	local promptOrder = 0
	local lastHint = ""
	local narrow = false

	local function setBadgeText()
		local atCap = multiplier >= 1 + Hardcore.StreakBonusCap
		local bonus = math.round((multiplier - 1) * 100)
		badge.Text = string.format("%d-floor streak%s%s+%d%% relic Gold &amp; Gems", streak,
			if narrow then "\n" else " · ", if atCap then "MAX " else "", bonus)
	end
	local function fitBadge()
		local wrap = banner.AbsoluteSize.X < 390
		if wrap == narrow then return end
		narrow = wrap
		setBadgeText()
	end
	banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBadge)
	fitBadge()

	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt:GetAttribute("TowerPortalAction") then
			promptOrder += 1
			prompts[prompt] = promptOrder
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		prompts[prompt] = nil
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		tipFloor = nil
		table.clear(prompts)
	end)
	local presence = remotes:WaitForChild("Presence") :: RemoteEvent
	presence.OnClientEvent:Connect(function(packet)
		pendingTravel = packet.Self ~= nil and packet.Self.PendingRequestId ~= nil
	end)
	local context = remotes:WaitForChild("Context") :: RemoteEvent
	context.OnClientEvent:Connect(function(packet)
		if packet.Stage == "COMMIT" then
			tipFloor = nil
			table.clear(prompts)
		end
	end)
	local runState = remotes:WaitForChild("RunState") :: RemoteEvent
	runState.OnClientEvent:Connect(function(state)
		active = state.Active == true
		lastClearedFloor = state.LastClearedFloor
		if not active then
			celebratedCap = false
			tipFloor = nil
			table.clear(prompts)
		elseif state.CreditedFloor then
			tipFloor = if firstClearSeen then nil else state.CreditedFloor
			firstClearSeen = true
		end

		if streak == state.Streak and multiplier == state.StreakMultiplier then return end
		local increased = state.StreakMultiplier > multiplier
		streak, multiplier = state.Streak, state.StreakMultiplier
		local atCap = multiplier >= 1 + Hardcore.StreakBonusCap
		setBadgeText()
		badge.TextColor3 = if atCap then Tokens.Severity.reward else Tokens.BarTone.Jade.Top
		if increased then UIFeel.Pop(icon, 0.12) end
		if atCap and not celebratedCap then
			celebratedCap = true
			Kit.Motion.Success(row)
		end
	end)

	return function(floor: number, personalFloor: boolean, highestCleared: number)
		if tipFloor and tipFloor ~= floor then tipFloor = nil end
		local show = banner.Visible and active and personalFloor
		row.Visible = show and streak > 0
		tip.Visible = show and tipFloor ~= nil

		local hint = ""
		if show and not pendingTravel and highestCleared >= floor then
			local mostRecent = 0
			for prompt, order in prompts do
				if not prompt:IsDescendantOf(workspace) then
					prompts[prompt] = nil
				elseif prompt.Enabled and order > mostRecent and prompt:GetAttribute("TowerPortalFloorId") == floor then
					local action = prompt:GetAttribute("TowerPortalAction")
					local destination = prompt:GetAttribute("TowerPortalDestination")
					if type(action) == "string" and type(destination) == "number" then
						hint = TowerRun.PortalHint(action, destination, streak, lastClearedFloor)
						mostRecent = order
					end
				end
			end
		end
		if hint ~= lastHint then
			lastHint = hint
			callout.Update({ Text = hint })
			placeOverlays()
		end
	end
end

return table.freeze(TowerStreakHud)
