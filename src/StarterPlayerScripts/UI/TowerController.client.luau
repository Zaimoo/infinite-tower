--!strict
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local PromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local Http = game:GetService("HttpService")

local player = Players.LocalPlayer
local floors = require(RS.Shared.Config.TowerFloorConfig)
local mobs = require(RS.Shared.Config.MobCatalog)
local GothicBoxStyle = require(RS.Shared.Util.GothicBoxStyle)
local remotes = RS:WaitForChild("Remotes"):WaitForChild("TowerRemotes")

local selfState: any = nil
local context: any = nil
local pending: any = nil
local pendingActionName: string? = nil
local lastFeedback: string? = nil
local selected = 1
local presence: any = nil

local gui = Instance.new("ScreenGui")
gui.Name = "TowerTravel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent: Instance, text: string, pos: UDim2, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextColor3 = Color3.fromRGB(235, 228, 220)
	l.Font = Enum.Font.Gotham
	l.TextSize = 13
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, pos: UDim2, size: UDim2, callback: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = Color3.fromRGB(28, 20, 38)
	b.Name = text:gsub("[^%w]", "")
	if b.Name == "" then b.Name = "Close" end
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.AutoButtonColor = true
	b.Parent = parent
	GothicBoxStyle.Apply(b, { Style = "Button", OnClick = callback })
	return b
end

local panel = Instance.new("Frame")
panel.Name = "FloorSelector"
panel.AnchorPoint = Vector2.new(.5, .5)
panel.Position = UDim2.fromScale(.5, .5)
panel.Size = UDim2.fromOffset(540, 500)
panel.BackgroundColor3 = Color3.fromRGB(15, 12, 22)
panel.Active = true
panel.Visible = false
panel.Parent = gui
GothicBoxStyle.Apply(panel, { Style = "Window" })

local scale = Instance.new("UIScale")
scale.Parent = panel
local reflow: any = nil

local function fit()
	local camera = workspace.CurrentCamera
	if camera then
		local width, height = math.min(540, camera.ViewportSize.X - 24), math.min(500, camera.ViewportSize.Y - 84)
		panel.Size = UDim2.fromOffset(width, height)
		scale.Scale = 1
		if reflow then reflow(width, height) end
	end
end
fit()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(fit)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
end

local title = label(panel, "INFINITE TOWER · 50 FLOORS", UDim2.fromOffset(20, 12), UDim2.fromOffset(420, 26))
title.Font = Enum.Font.GothamBold
title.TextSize = 16
local subtitle = label(panel, "10 Biomes · Select any floor to visit or station your squad", UDim2.fromOffset(20, 38), UDim2.fromOffset(480, 22))
subtitle.TextColor3 = Color3.fromRGB(190, 178, 210)
local detail = label(panel, "", UDim2.fromOffset(20, 286), UDim2.fromOffset(500, 88))
local status = label(panel, "Connecting…", UDim2.fromOffset(20, 428), UDim2.fromOffset(500, 54))

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Floors"
scroll.Position = UDim2.fromOffset(20, 66)
scroll.Size = UDim2.fromOffset(500, 212)
scroll.BackgroundColor3 = Color3.fromRGB(26, 22, 34)
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.Parent = panel

local biomeHeaders: { [number]: TextLabel } = {}
local floorButtons: { [number]: TextButton } = {}

local function render()
	local floor = floors.Get(selected)
	if not floor then return end
	local biome = mobs.Biomes[floor.BiomeIndex]
	local info = presence and presence.Floors[selected + 1]
	local squadSummaries = {}
	if info and info.Squads then
		for _, s in info.Squads do
			table.insert(squadSummaries, string.format("%s (%d)", s.DisplayName, s.RosterSize))
		end
	end

	local encounterNames = {}
	for _, enc in ipairs(floor.Encounters) do
		local m = mobs.Get(enc.EnemyId)
		if m then
			table.insert(encounterNames, string.format("%s ×%d", m.DisplayName, enc.Count))
		end
	end
	local bossEntry = floor.BossEnemyId and mobs.Get(floor.BossEnemyId) or nil
	local bossText = if bossEntry then string.format(" · BOSS: %s", bossEntry.DisplayName) else ""

	detail.Text = string.format(
		"Floor %d · %s (%s%s)\nScaling: HP ×%.2f · ATK ×%.2f · Gold/XP ×%.2f | Roster: %s\nVisitors: %d · Stationed Squads: %s",
		selected,
		floor.DisplayName,
		floor.BiomeDisplayName or (biome and biome.DisplayName) or floor.BiomeId,
		bossText,
		floor.Difficulty.HPMultiplier,
		floor.Difficulty.DamageMultiplier,
		floor.Rewards.GoldMultiplier,
		table.concat(encounterNames, ", "),
		info and #info.Visitors or 0,
		#squadSummaries > 0 and table.concat(squadSummaries, ", ") or "none"
	)

	local visitingFloor = if selfState and selfState.PlayerLocation then selfState.PlayerLocation.FloorId else 0
	local assignedFloor = if selfState then selfState.SquadAssignment else nil

	for id = 1, 50 do
		local b = floorButtons[id]
		if b then
			local fInfo = presence and presence.Floors[id + 1]
			local hasVisitors = fInfo and fInfo.Visitors and #fInfo.Visitors > 0
			local hasSquads = fInfo and fInfo.Squads and #fInfo.Squads > 0
			local tag = ""
			if visitingFloor == id and assignedFloor == id then
				tag = " ★"
			elseif visitingFloor == id then
				tag = " ●"
			elseif assignedFloor == id then
				tag = " ▲"
			elseif id % 5 == 0 then
				tag = " ◆"
			elseif hasVisitors or hasSquads then
				tag = " ·"
			end
			b.Text = tostring(id) .. tag
			if id == selected then
				b.TextColor3 = Color3.fromRGB(255, 232, 125)
			elseif visitingFloor == id then
				b.TextColor3 = Color3.fromRGB(125, 240, 175)
			elseif assignedFloor == id then
				b.TextColor3 = Color3.fromRGB(135, 215, 255)
			elseif id % 5 == 0 then
				b.TextColor3 = Color3.fromRGB(245, 165, 255)
			else
				b.TextColor3 = Color3.fromRGB(235, 228, 220)
			end
		end
	end

	if selfState then
		local locStr = if visitingFloor == 0 then "Hub" else string.format("Floor %d (%s)", visitingFloor, floors.Get(visitingFloor).DisplayName)
		local sqStr = if assignedFloor then string.format("Stationed on Floor %d", assignedFloor) else "Following Master"
		local feedbackStr = if pending then string.format("Pending: %s…", pendingActionName or "request")
			elseif lastFeedback then lastFeedback
			else "Ready (● You · ▲ Squad · ◆ Boss)"
		status.Text = string.format("You: %s · Squad: %s\n%s", locStr, sqStr, feedbackStr)
	end
end

local function request(action: string, id: number?)
	if not selfState or pending then return end
	local r = {
		ContractVersion = 1,
		RequestId = Http:GenerateGUID(false),
		Action = action,
		FloorId = id,
		CharacterGeneration = selfState.CharacterGeneration,
		ExpectedLocationRevision = selfState.LocationRevision,
		ExpectedSquadRevision = selfState.SquadRevision,
	}
	pending = r.RequestId
	pendingActionName = if id then string.format("%s Floor %d", action, id) else action
	lastFeedback = nil
	render()
	remotes.Request:FireServer(r)
end

_G.RequestTowerHub = function(): boolean
	if not selfState then
		warn("[TowerController] Cannot travel to Hub: selfState not ready yet")
		return false
	end
	if pending then
		warn("[TowerController] Travel already pending: " .. tostring(pending))
		return false
	end
	request("HUB")
	return true
end

_G.OpenTowerSelector = function()
	if _G.OpenMasterModal then _G.OpenMasterModal("NONE") end
	panel.Visible = true
	render()
end

_G.IsTowerSelectorOpen = function(): boolean
	return panel.Visible
end

_G.CloseTowerSelector = function()
	panel.Visible = false
end

for biomeIndex, biome in ipairs(mobs.Biomes) do
	local firstFloor = (biomeIndex - 1) * 5 + 1
	local lastFloor = biomeIndex * 5
	local hdr = label(
		scroll,
		string.format("BIOME %d · %s (FLOORS %d–%d)", biomeIndex, string.upper(biome.DisplayName), firstFloor, lastFloor),
		UDim2.fromOffset(6, 0),
		UDim2.fromOffset(460, 20)
	)
	hdr.Font = Enum.Font.GothamBold
	hdr.TextSize = 12
	hdr.TextColor3 = Color3.fromRGB(216, 185, 112)
	biomeHeaders[biomeIndex] = hdr

	for indexInBiome = 1, 5 do
		local id = firstFloor + indexInBiome - 1
		local b = button(scroll, tostring(id) .. (id % 5 == 0 and " ◆" or ""), UDim2.fromOffset(0, 0), UDim2.fromOffset(88, 34), function()
			selected = id
			render()
		end)
		b.Name = "Floor_" .. id
		floorButtons[id] = b
	end
end

button(panel, "Visit floor", UDim2.fromOffset(20, 380), UDim2.fromOffset(118, 40), function() request("VISIT", selected) end)
button(panel, "Assign squad", UDim2.fromOffset(146, 380), UDim2.fromOffset(118, 40), function() request("ASSIGN", selected) end)
button(panel, "Recall squad", UDim2.fromOffset(272, 380), UDim2.fromOffset(118, 40), function() request("RECALL") end)
button(panel, "Return to Hub", UDim2.fromOffset(398, 380), UDim2.fromOffset(122, 40), function() request("HUB") end)
button(panel, "×", UDim2.fromOffset(488, 8), UDim2.fromOffset(40, 32), function() panel.Visible = false end)

reflow = function(width: number, height: number)
	local compact = height < 420
	local listY = compact and 50 or 66
	local listH = compact and math.max(64, height - 220) or math.max(150, height - 284)
	local detailY = listY + listH + 6
	local detailH = compact and 56 or 82
	local actionY = detailY + detailH + 6

	title.Size = UDim2.fromOffset(width - 76, 24)
	title.Position = UDim2.fromOffset(20, compact and 4 or 10)
	subtitle.Size = UDim2.fromOffset(width - 40, 20)
	subtitle.Position = UDim2.fromOffset(20, compact and 26 or 36)

	scroll.Position = UDim2.fromOffset(20, listY)
	scroll.Size = UDim2.fromOffset(width - 40, listH)

	local innerWidth = width - 52
	local col = innerWidth / 5
	local blockHeight = 64
	for biomeIndex = 1, 10 do
		local blockTop = (biomeIndex - 1) * blockHeight + 4
		local hdr = biomeHeaders[biomeIndex]
		if hdr then
			hdr.Position = UDim2.fromOffset(4, blockTop)
			hdr.Size = UDim2.fromOffset(innerWidth - 8, 18)
		end
		for indexInBiome = 1, 5 do
			local id = (biomeIndex - 1) * 5 + indexInBiome
			local b = floorButtons[id]
			if b then
				b.Position = UDim2.fromOffset((indexInBiome - 1) * col + 2, blockTop + 20)
				b.Size = UDim2.fromOffset(col - 4, 38)
			end
		end
	end
	scroll.CanvasSize = UDim2.fromOffset(0, 10 * blockHeight + 8)

	detail.Position = UDim2.fromOffset(20, detailY)
	detail.Size = UDim2.fromOffset(width - 40, detailH)

	local actionNames = { "Visitfloor", "Assignsquad", "Recallsquad", "ReturntoHub" }
	local actionWidth = (width - 40 - 24) / 4
	for i, name in ipairs(actionNames) do
		local b = panel:FindFirstChild(name)
		if b and b:IsA("TextButton") then
			b.Position = UDim2.fromOffset(20 + (i - 1) * (actionWidth + 8), actionY)
			b.Size = UDim2.fromOffset(actionWidth, 40)
		end
	end

	status.Position = UDim2.fromOffset(20, actionY + 44)
	status.Size = UDim2.fromOffset(width - 40, math.max(28, height - actionY - 48))

	local close = panel:FindFirstChild("Close")
	if close and close:IsA("TextButton") then
		close.Position = UDim2.fromOffset(width - 48, 4)
		close.Size = UDim2.fromOffset(40, 36)
	end
end
fit()

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if not panel.Visible then return end
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		panel.Visible = false
		return
	end
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.DPadLeft or input.KeyCode == Enum.KeyCode.PageUp then
		selected = math.clamp(selected - 1, 1, 50)
		render()
	elseif input.KeyCode == Enum.KeyCode.DPadRight or input.KeyCode == Enum.KeyCode.PageDown then
		selected = math.clamp(selected + 1, 1, 50)
		render()
	end
end)

remotes.OpenSelector.OnClientEvent:Connect(function()
	if _G.OpenMasterModal then _G.OpenMasterModal("NONE") end
	panel.Visible = true
	render()
end)

PromptService.PromptTriggered:Connect(function(prompt, who)
	if who and who ~= player then return end
	local action = prompt:GetAttribute("TowerAction")
	local curFloor = if context and context.FloorId then context.FloorId elseif selfState and selfState.PlayerLocation then selfState.PlayerLocation.FloorId else 0
	if action == "SELECTOR" or prompt.Name == "TowerSelectorPrompt" then
		if _G.OpenMasterModal then _G.OpenMasterModal("NONE") end
		panel.Visible = true
		render()
	elseif action == "HUB" then
		request("HUB")
	elseif action == "PREVIOUS" and curFloor > 1 then
		request("VISIT", curFloor - 1)
	elseif action == "NEXT" and curFloor > 0 and curFloor < 50 then
		request("VISIT", curFloor + 1)
	end
end)

remotes.Presence.OnClientEvent:Connect(function(p)
	if presence and p.ServerSessionId == presence.ServerSessionId and p.PresenceRevision < presence.PresenceRevision then return end
	presence = p
	selfState = p.Self
	render()
end)

remotes.Response.OnClientEvent:Connect(function(r)
	if r.RequestId ~= pending then return end
	if r.Status ~= "PENDING" then
		local act = pendingActionName or "Action"
		pending = nil
		pendingActionName = nil
		if r.Status == "OK" or not r.ErrorCode then
			lastFeedback = string.format("✓ %s complete", act)
		else
			lastFeedback = string.format("⚠ %s failed: %s", act, tostring(r.ErrorCode))
		end
		render()
	end
end)

remotes.Context.OnClientEvent:Connect(function(c)
	if c.Stage == "PREPARE" then
		task.spawn(function()
			local ok = true
			if workspace.StreamingEnabled then
				ok = pcall(function()
					player:RequestStreamAroundAsync(c.Arrival.Position, math.max(.1, c.ReadyDeadline - workspace:GetServerTimeNow()))
				end)
			end
			remotes.Ready:FireServer({
				ContractVersion = 1,
				RequestId = c.RequestId,
				ReadyToken = c.ReadyToken,
				ViewEpoch = c.ViewEpoch,
				CharacterGeneration = c.CharacterGeneration,
				Result = ok and workspace:GetServerTimeNow() <= c.ReadyDeadline and "READY" or "FAILED",
			})
		end)
	elseif c.Stage == "COMMIT" then
		context = c
		_G.TowerView = c
		if c.FloorId > 0 then selected = c.FloorId end
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		render()
	end
end)

task.defer(function()
	remotes.Request:FireServer({ ContractVersion = 1, RequestId = Http:GenerateGUID(false), Action = "PRESENCE_SUBSCRIBE" })
end)
