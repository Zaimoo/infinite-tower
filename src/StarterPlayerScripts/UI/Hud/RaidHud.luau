--!strict
-- StarterPlayerScripts/UI/Hud/RaidHud.luau
-- Raid Boss HUD (docs/raid-boss-plan.md §8):
--   Leaderboard  replaces the Right Rail inside the raid arena: rank, name, damage, share bar; your row is
--                highlighted, and pinned under a divider when you are outside the top rows.
--   LeaveButton  bottom centre, just above the Squad Status card (HudApp passes the drawer's top).
--   ResultsCard  centred card when the raid ends: rank, damage, share, Gems and Gold, return countdown.
--   HubChip      bottom right above the event badge while the Raid Portal is open, outside the arena.
-- Phase and timers come from ReplicatedStorage attributes (RaidService); the board, roster and result
-- come from RaidRemotes. The server stays authoritative: this only draws what it sends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RaidConfig = require(Shared:WaitForChild("Config"):WaitForChild("RaidConfig"))
local RaidRules = require(Shared:WaitForChild("Util"):WaitForChild("RaidRules"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Store = require(script.Parent:WaitForChild("Store"))
local Components = require(script.Parent:WaitForChild("Components"))

local e = React.createElement
local G = Theme.Glass
local L = Theme.Layout
local LocalPlayer = Players.LocalPlayer
local GOLD = G.Royal

local RaidHud = {}

RaidHud.Width = 240
RaidHud.LeaveSize = Vector2.new(168, 40)

-- Remote state -----------------------------------------------------------------------------------
local changed = Instance.new("BindableEvent")
local board: any = nil
local roster: { [number]: { UserId: number, Name: string } } = {}
local rosterRaid = -1
local result: any = nil
local leaveRemote: RemoteEvent? = nil

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RaidRemotes", 60)
	if not folder then return end
	leaveRemote = folder:WaitForChild("Leave", 10) :: RemoteEvent?
	local boardRemote = folder:WaitForChild("Board", 10) :: UnreliableRemoteEvent?
	if boardRemote then
		boardRemote.OnClientEvent:Connect(function(buf: any)
			if typeof(buf) ~= "buffer" then return end
			local decoded = RaidRules.DecodeBoard(buf)
			if decoded then board = decoded; changed:Fire() end
		end)
	end
	local rosterRemote = folder:WaitForChild("Roster", 10) :: RemoteEvent?
	if rosterRemote then
		rosterRemote.OnClientEvent:Connect(function(raidNumber: any, list: any)
			if type(list) ~= "table" or type(raidNumber) ~= "number" then return end
			if raidNumber ~= rosterRaid then board = nil end
			rosterRaid = raidNumber
			roster = {}
			for slot, who in list do
				local n = tonumber(slot)
				if n and type(who) == "table" and type(who.Name) == "string" then roster[n] = { UserId = tonumber(who.UserId) or 0, Name = who.Name } end
			end
			changed:Fire()
		end)
	end
	local resultRemote = folder:WaitForChild("Result", 10) :: RemoteEvent?
	if resultRemote then
		resultRemote.OnClientEvent:Connect(function(r: any)
			if type(r) == "table" then result = r; changed:Fire() end
		end)
	end
end)

export type Phase = { Phase: string, Boss: RaidConfig.Boss, StartsAt: number, EndsAt: number, Now: number, InRaid: boolean }

local function readPhase(): Phase
	return {
		Phase = ReplicatedStorage:GetAttribute("RaidPhase") or "CALM",
		Boss = RaidConfig.Get(ReplicatedStorage:GetAttribute("RaidBossId") or "") or RaidConfig.Bosses[1],
		StartsAt = ReplicatedStorage:GetAttribute("RaidStartsAt") or 0,
		EndsAt = ReplicatedStorage:GetAttribute("RaidEndsAt") or 0,
		Now = Workspace:GetServerTimeNow(),
		InRaid = Store.PlayerFloorId == RaidConfig.FloorId,
	}
end

function RaidHud.InRaid(): boolean
	return Store.PlayerFloorId == RaidConfig.FloorId
end

-- Phase state, refreshed on attribute changes, remote updates and twice a second for timers.
function RaidHud.useRaid(): Phase
	local state, setState = React.useState(readPhase)
	React.useEffect(function()
		local alive = true
		local conns = { changed.Event:Connect(function() setState(readPhase()) end) }
		for _, name in { "RaidPhase", "RaidBossId", "RaidStartsAt", "RaidEndsAt" } do
			table.insert(conns, ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function() setState(readPhase()) end))
		end
		task.spawn(function()
			while alive do
				task.wait(0.5)
				if alive then setState(readPhase()) end
			end
		end)
		return function()
			alive = false
			for _, c in conns do c:Disconnect() end
		end
	end, {})
	return state
end

local function title(props: { [string]: any })
	local base: { [string]: any } = { BackgroundTransparency = 1, FontFace = G.Fonts.Display, TextColor3 = G.Text, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }
	for k, v in props do base[k] = v end
	return e("TextLabel", base)
end

-- Leaderboard ------------------------------------------------------------------------------------
local ROW_H = 30

local function row(order: number, rank: number, name: string, damage: number, share: number, accent: Color3, isSelf: boolean)
	local rankColor = if rank == 1 then GOLD elseif rank == 2 then Color3.fromRGB(214, 220, 232) elseif rank == 3 then Color3.fromRGB(222, 150, 96) else G.Text
	return e("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_H),
		BackgroundColor3 = if isSelf then GOLD else G.BaseRaised,
		BackgroundTransparency = if isSelf then 0.78 else 0.55,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, G.TileRadius) }),
		Stroke = if isSelf then e("UIStroke", { Color = GOLD, Transparency = 0.25, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) else nil,
		Rank = title({ Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0, 26, 1, -6), TextSize = 15, TextColor3 = rankColor,
			Text = if rank == 1 then "♛" elseif rank > 0 then tostring(rank) else "–", TextXAlignment = Enum.TextXAlignment.Center }),
		Name = Components.GlassText({ Position = UDim2.fromOffset(36, 1), Size = UDim2.new(1, -100, 0, 16), TextSize = 12,
			Text = if isSelf then "<b>" .. name .. "</b>" else name, TextColor3 = if isSelf then GOLD else G.Text }),
		Damage = title({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 1), Size = UDim2.fromOffset(62, 16), TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right, Text = RaidRules.Abbrev(damage), TextColor3 = if isSelf then GOLD else G.Text }),
		Track = e("Frame", { Position = UDim2.new(0, 36, 1, -9), Size = UDim2.new(1, -44, 0, 4), BackgroundColor3 = G.Base,
			BackgroundTransparency = 0.3, BorderSizePixel = 0 }, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = if share > 0 then e("Frame", { Size = UDim2.fromScale(math.clamp(share, 0.02, 1), 1), BackgroundColor3 = if isSelf then GOLD else accent,
				BorderSizePixel = 0 }, { Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }) }) else nil,
		}),
	})
end

-- props.Top / props.Bottom: the Right Rail's vertical span in the HUD root.
function RaidHud.Leaderboard(props: { Top: number, Bottom: number, Compact: boolean })
	local raid = RaidHud.useRaid()
	local accent = raid.Boss.Accent
	local width = if props.Compact then 190 else RaidHud.Width
	local rows: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		Padding = e("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	}
	local left = if raid.Phase == "WARNING" then raid.StartsAt - raid.Now elseif raid.Phase == "ACTIVE" then raid.EndsAt - raid.Now else 0
	rows.Head = e("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 }, {
		Title = title({ Size = UDim2.new(1, -60, 1, 0), TextSize = 15, Text = "DAMAGE", TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.35) }),
		Timer = title({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(60, 24), TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right, Text = RaidRules.Clock(left),
			TextColor3 = if raid.Phase == "ACTIVE" and left <= 30 then G.Danger else GOLD }),
	})
	rows.Boss = Components.GlassText({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextTransparency = G.MutedTransparency,
		Text = if raid.Phase == "WARNING" then RaidConfig.FullName(raid.Boss) .. " · awakens soon" else RaidConfig.FullName(raid.Boss) })
	local data = board
	local maxDamage = 0
	if data then
		for _, r in data.Rows do maxDamage = math.max(maxDamage, r.Damage) end
	end
	local shown = 0
	local selfShown = false
	if data then
		for i, r in data.Rows do
			local who = roster[r.Slot]
			local isSelf = who ~= nil and who.UserId == LocalPlayer.UserId
			selfShown = selfShown or isSelf
			rows["R" .. i] = row(10 + i, i, if who then who.Name else "Master", r.Damage, if maxDamage > 0 then r.Damage / maxDamage else 0, accent, isSelf)
			shown += 1
		end
	end
	if shown == 0 then
		rows.Empty = Components.GlassText({ LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 34), TextWrapped = true, TextSize = 12,
			TextTransparency = G.MutedTransparency, Text = if raid.Phase == "WARNING" then "Wait on the staging pad. The gate opens when the boss wakes." else "No damage yet: send your squad in!" })
	end
	if data and not selfShown and data.SelfRank > 0 then
		rows.Divider = e("Frame", { LayoutOrder = 90, Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = G.Hairline, BackgroundTransparency = 0.6, BorderSizePixel = 0 })
		rows.Self = row(91, data.SelfRank, LocalPlayer.DisplayName, data.SelfDamage, if maxDamage > 0 then data.SelfDamage / maxDamage else 0, accent, true)
	end
	if data and data.MaxHP > 0 then
		rows.Foot = Components.GlassText({ LayoutOrder = 99, Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextTransparency = G.MutedTransparency,
			Text = string.format("Boss %d%% · %s dealt", math.round(math.clamp(data.CurrentHP / data.MaxHP, 0, 1) * 100), RaidRules.Abbrev(data.Total)) })
	end
	local maxHeight = math.max(120, props.Bottom - props.Top)
	return Components.Glass({
		Name = "RaidLeaderboard",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -L.Edge, 0, props.Top),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
	}, {
		Max = e("UISizeConstraint", { MaxSize = Vector2.new(width, maxHeight) }),
		Accent = e("Frame", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 2 }),
		List = e("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, rows),
	})
end

-- Leave button -----------------------------------------------------------------------------------
-- props.Bottom: offset from the screen bottom to the Squad Status card's top edge.
function RaidHud.LeaveButton(props: { Bottom: number })
	local confirm, setConfirm = React.useState(false)
	React.useEffect(function()
		if not confirm then return nil end
		local thread = task.delay(4, function() setConfirm(false) end)
		return function() task.cancel(thread) end
	end, { confirm })
	return e("TextButton", {
		Name = "RaidLeave",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -props.Bottom),
		Size = UDim2.fromOffset(if confirm then 236 else RaidHud.LeaveSize.X, RaidHud.LeaveSize.Y),
		BackgroundColor3 = if confirm then Color3.fromRGB(150, 28, 40) else G.Base,
		BackgroundTransparency = if confirm then 0.1 else G.BaseTransparency,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		FontFace = G.Fonts.Display,
		TextSize = 15,
		TextColor3 = G.Text,
		Text = if confirm then "Leave? Damage still counts" else "⟵  LEAVE RAID",
		[React.Event.Activated] = function()
			if not confirm then
				setConfirm(true)
				return
			end
			setConfirm(false)
			if leaveRemote then leaveRemote:FireServer() end
		end,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, G.Radius) }),
		Stroke = e("UIStroke", { Color = if confirm then Color3.fromRGB(255, 140, 140) else G.Hairline, Transparency = if confirm then 0 else G.HairlineTransparency,
			Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
end

-- Results card -----------------------------------------------------------------------------------
function RaidHud.ResultsCard(props: { Blocked: boolean })
	local raid = RaidHud.useRaid()
	local r = result
	if not r or props.Blocked or raid.Now > (r.ReturnAt or 0) + 4 then return nil end
	local boss = RaidConfig.Get(r.BossId) or raid.Boss
	local lines: { [string]: any } = {
		Layout = e("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		Padding = e("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		Head = title({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center,
			Text = if r.Killed then "VICTORY" else "THE RAID IS OVER", TextColor3 = if r.Killed then GOLD else G.Text }),
		Boss = Components.GlassText({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13,
			Text = RaidConfig.FullName(boss) .. (if r.Killed then " has fallen" else " retreats"), TextColor3 = boss.Accent:Lerp(Color3.new(1, 1, 1), 0.4) }),
		Rank = title({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 40), TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center,
			Text = if r.Rank > 0 then "#" .. r.Rank else "—", TextColor3 = GOLD }),
		Detail = Components.GlassText({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13,
			Text = string.format("%s damage · %d%% of the top · %d raider%s", RaidRules.Abbrev(r.Damage), math.round((r.Share or 0) * 100), r.Participants or 0,
				if (r.Participants or 0) == 1 then "" else "s") }),
		Reward = title({ LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 26), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
			Text = if r.Qualified then string.format("+%d Gems   +%s Gold", r.Gems, RaidRules.Abbrev(r.Gold)) else "Deal more damage to earn rewards",
			TextColor3 = if r.Qualified then G.Text else G.Danger }),
		Return = Components.GlassText({ LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 11,
			TextTransparency = G.MutedTransparency,
			Text = if raid.InRaid then "Returning to the Commons in " .. math.max(0, math.ceil((r.ReturnAt or 0) - raid.Now)) .. "…" else "Rewards added to your Fortress" }),
	}
	return Components.Glass({
		Name = "RaidResults",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(320, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.12,
		ZIndex = 20,
	}, {
		Accent = e("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = boss.Accent, BorderSizePixel = 0 }),
		List = e("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, lines),
	})
end

-- Hub chip ---------------------------------------------------------------------------------------
RaidHud.ChipHeight = 40

function RaidHud.ChipVisible(phase: string, inRaid: boolean): boolean
	return not inRaid and (phase == "WARNING" or phase == "ACTIVE")
end

function RaidHud.HubChip(props: { Bottom: number, Compact: boolean })
	local raid = RaidHud.useRaid()
	if not RaidHud.ChipVisible(raid.Phase, raid.InRaid) then return nil end
	local left = if raid.Phase == "WARNING" then raid.StartsAt - raid.Now else raid.EndsAt - raid.Now
	return Components.Glass({
		Name = "RaidChip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -L.Edge, 1, -props.Bottom),
		Size = UDim2.fromOffset(if props.Compact then 130 else L.PowerBadgeWidth, RaidHud.ChipHeight),
	}, {
		Accent = e("Frame", { Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = raid.Boss.Accent, BorderSizePixel = 0 }),
		Label = Components.GlassText({ Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -76, 0, 16), TextSize = 12, FontFace = G.Fonts.Display,
			Text = "RAID OPEN", TextColor3 = raid.Boss.Accent:Lerp(Color3.new(1, 1, 1), 0.3) }),
		Name = if not props.Compact then Components.GlassText({ Position = UDim2.fromOffset(12, 20), Size = UDim2.new(1, -76, 0, 14), TextSize = 11,
			TextTransparency = G.MutedTransparency, Text = "Portal · north Commons" }) else nil,
		Timer = title({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(60, 20), TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right, Text = RaidRules.Clock(left), TextColor3 = GOLD }),
	})
end

return RaidHud
