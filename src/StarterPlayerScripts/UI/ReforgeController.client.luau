--!strict
-- StarterPlayerScripts/UI/ReforgeController.client.luau
-- The Runesmith's Anvil window (Weapon Reforge, GDD §7.6). Opened by the station's prompt on the Cloister
-- Commons. Pick a weapon, pay Gold to roll an enchantment, then keep the new enchantment or the old one. Every action goes
-- through ReforgeRemotes.ReforgeRequest; the balance, enchantments and the pending roll come back in the profile sync.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local RunesmithMeshHydrator = require(Assets:WaitForChild("RunesmithMeshHydrator"))
local Config = require(Shared:WaitForChild("Config"):WaitForChild("ReforgeConfig"))
local ArtifactCatalog = require(Shared.Config:WaitForChild("ArtifactCatalog"))
local Balance = require(Shared.Config:WaitForChild("StatBalance"))
local Rules = require(Shared:WaitForChild("Util"):WaitForChild("ReforgeRules"))
local GildedGrimoire = require(Shared.Util:WaitForChild("GildedGrimoire"))

local UI = script.Parent
local UIFeel = require(UI:WaitForChild("UIFeel"))
local ModalFit = require(UI:WaitForChild("ModalFit"))
local WindowManager = require(UI:WaitForChild("WindowManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local syndicate = remotes:WaitForChild("SyndicateRemotes")
local profileSync = syndicate:WaitForChild("ProfileDeltaSync") :: RemoteEvent

local G = GildedGrimoire.Glass
local T = GildedGrimoire.Text
local WIDTH, HEIGHT = 760, 500

local function profile(): any
	return (_G :: any).CurrentProfile
end

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local obj = Instance.new(class)
	for key, value in props do (obj :: any)[key] = value end
	if parent then obj.Parent = parent end
	return obj
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = T.Parchment,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, RichText = true }
	for key, value in props do defaults[key] = value end
	return new("TextLabel", defaults, parent)
end

local function button(parent: Instance, label: string, primary: boolean, props: { [string]: any }): TextButton
	local b = new("TextButton", { Text = label, Font = Enum.Font.GothamBlack, TextSize = 15, AutoButtonColor = false }, parent)
	for key, value in props do (b :: any)[key] = value end
	GildedGrimoire.GlassFrame(b, { Raised = not primary })
	if primary then
		b.BackgroundColor3 = G.Royal
		b.BackgroundTransparency = 0
		b.TextColor3 = G.Base
	else
		b.TextColor3 = T.Parchment
	end
	UIFeel.Attach(b)
	return b
end

--------------------------------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "ReforgeWindow", ResetOnSpawn = false, DisplayOrder = 40, Enabled = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local root = new("Frame", { Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIDTH, HEIGHT) }, gui)
GildedGrimoire.GlassFrame(root, { Transparency = 0.06 })
local scale = new("UIScale", {}, root)
local fit = ModalFit.Bind(root, scale, WIDTH, HEIGHT)

local title = text(root, { Position = UDim2.fromOffset(24, 16), Size = UDim2.new(1, -96, 0, 32), Font = Enum.Font.GothamBlack, TextSize = 24,
	Text = "RUNESMITH'S ANVIL", TextColor3 = T.Gold })
GildedGrimoire.GlassText(title, "Title")
text(root, { Position = UDim2.fromOffset(24, 48), Size = UDim2.new(1, -96, 0, 20), TextSize = 13, TextColor3 = T.Muted,
	Text = "Weapon Reforge · pay Gold to roll one enchantment onto a weapon, then keep the new enchantment or the old one" })
local close = button(root, "X", false, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.fromOffset(40, 40) })

-- Left: the weapon list.
local listFrame = new("ScrollingFrame", { Name = "Weapons", Position = UDim2.fromOffset(20, 84), Size = UDim2.fromOffset(300, HEIGHT - 104),
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, root)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, listFrame)
new("UIPadding", { PaddingRight = UDim.new(0, 10) }, listFrame)

-- Right: the selected weapon.
local detail = new("Frame", { Name = "Detail", Position = UDim2.fromOffset(336, 84), Size = UDim2.new(1, -356, 1, -104) }, root)
GildedGrimoire.GlassFrame(detail, { Raised = true })
local weaponLabel = text(detail, { Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 26), Font = Enum.Font.GothamBlack, TextSize = 19 })
local currentLabel = text(detail, { Position = UDim2.fromOffset(18, 44), Size = UDim2.new(1, -36, 0, 22), TextSize = 14 })
local resultCard = new("Frame", { Name = "Result", Position = UDim2.fromOffset(18, 76), Size = UDim2.new(1, -36, 0, 96) }, detail)
GildedGrimoire.GlassFrame(resultCard, {})
local resultGrade = text(resultCard, { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 24), Font = Enum.Font.GothamBlack, TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center })
local resultText = text(resultCard, { Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -28, 0, 48), TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Center })
local costLabel = text(detail, { Position = UDim2.fromOffset(18, 182), Size = UDim2.new(1, -36, 0, 22), TextSize = 15, TextColor3 = T.Gold })
local rollButton = button(detail, "ROLL", true, { Position = UDim2.fromOffset(18, 210), Size = UDim2.new(1, -36, 0, 46) })
local keepNew = button(detail, "KEEP NEW", false, { Position = UDim2.fromOffset(18, 264), Size = UDim2.new(0.5, -22, 0, 40) })
local keepOld = button(detail, "KEEP OLD", false, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 264), Size = UDim2.new(0.5, -22, 0, 40) })
local statusLabel = text(detail, { Position = UDim2.fromOffset(18, 310), Size = UDim2.new(1, -36, 0, 20), TextSize = 13, TextColor3 = T.Muted })
local pityLabel = text(detail, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -40), Size = UDim2.new(1, -36, 0, 20), TextSize = 13, TextColor3 = T.Muted })
local oddsLabel = text(detail, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -10), Size = UDim2.new(1, -36, 0, 30), TextSize = 11, TextColor3 = T.Muted })
GildedGrimoire.GlassTexts(root)

do -- The odds never change, so write them once (the odds are disclosed before any roll).
	local parts = {}
	for i, chance in Rules.GradeChances() do
		local grade = Config.Grades[i]
		table.insert(parts, string.format('<font color="#%s">%s</font> %s%%', grade.Color:ToHex(), grade.Name, tostring(math.round(chance * 1000) / 10)))
	end
	oddsLabel.Text = "Odds per roll: " .. table.concat(parts, " · ")
end

--------------------------------------------------------------------------------------------------------
-- State and rendering
--------------------------------------------------------------------------------------------------------
local selected: string? = nil
local busy = false
local lastMessage = ""

local function gradeColor(enchantment: any): Color3
	return if Rules.IsEnchantment(enchantment) then Config.Grades[enchantment.Grade].Color else T.Muted
end

local function sortedWeapons(p: any): { any }
	local list = {}
	for uuid, artifact in p and p.Artifacts or {} do
		if type(artifact) == "table" then table.insert(list, { UUID = uuid, Artifact = artifact }) end
	end
	table.sort(list, function(a, b)
		local ea, eb = a.Artifact.EquippedHeroUUID ~= nil, b.Artifact.EquippedHeroUUID ~= nil
		if ea ~= eb then return ea end
		if (a.Artifact.Rarity or 1) ~= (b.Artifact.Rarity or 1) then return (a.Artifact.Rarity or 1) > (b.Artifact.Rarity or 1) end
		if (a.Artifact.Star or 1) ~= (b.Artifact.Star or 1) then return (a.Artifact.Star or 1) > (b.Artifact.Star or 1) end
		return a.UUID < b.UUID
	end)
	return list
end

local render: () -> ()

local function weaponRow(order: number, uuid: string, artifact: any)
	local rarity = ArtifactCatalog.GetRarityInfo(artifact.Rarity or 1)
	local row = new("TextButton", { Name = uuid, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 54), Text = "", AutoButtonColor = false }, listFrame)
	GildedGrimoire.GlassFrame(row, { Raised = uuid == selected, Accent = rarity.Color })
	if uuid == selected then row.BackgroundColor3 = G.Arcane; row.BackgroundTransparency = 0.55 end
	text(row, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 20), TextSize = 14, TextColor3 = rarity.Color, TextTruncate = Enum.TextTruncate.AtEnd,
		Text = string.format("%s %s%s", artifact.DisplayName or "Weapon", string.rep("★", artifact.Star or 1), if artifact.EquippedHeroUUID then "  <font color=\"#4ADE80\">E</font>" else "") })
	text(row, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 18), TextSize = 12, TextColor3 = gradeColor(artifact.Enchantment),
		TextTruncate = Enum.TextTruncate.AtEnd, Text = Rules.Describe(artifact.Enchantment) })
	row.Activated:Connect(function()
		if busy then return end
		selected = uuid
		lastMessage = ""
		render()
	end)
end

render = function()
	local p = profile()
	for _, child in listFrame:GetChildren() do
		if child:IsA("GuiButton") then child:Destroy() end
	end
	local state: any = if p and type(p.Reforge) == "table" then p.Reforge else {}
	local pending = if type(state.Pending) == "table" and Rules.IsEnchantment(state.Pending.Enchantment) then state.Pending else nil
	if pending and p.Artifacts and p.Artifacts[pending.UUID] then selected = pending.UUID end
	local weapons = sortedWeapons(p)
	if (not selected or not (p and p.Artifacts and p.Artifacts[selected])) and weapons[1] then selected = weapons[1].UUID end
	for i, entry in weapons do weaponRow(i, entry.UUID, entry.Artifact) end

	local artifact = selected and p and p.Artifacts and p.Artifacts[selected]
	if not artifact then
		weaponLabel.Text = "No weapons"
		currentLabel.Text = "Summon weapons at the Blacksmith Forge first."
		resultGrade.Text, resultText.Text, costLabel.Text = "", "", ""
		rollButton.Visible, keepNew.Visible, keepOld.Visible = false, false, false
		return
	end
	local rarity = ArtifactCatalog.GetRarityInfo(artifact.Rarity or 1)
	weaponLabel.Text = string.format('<font color="#%s">%s</font> %s', rarity.Color:ToHex(), artifact.DisplayName or "Weapon", string.rep("★", artifact.Star or 1))
	currentLabel.Text = "Current: " .. Rules.Describe(artifact.Enchantment)
	currentLabel.TextColor3 = gradeColor(artifact.Enchantment)

	local mine = pending and pending.UUID == selected
	if mine then
		local grade = Config.Grades[pending.Enchantment.Grade]
		resultGrade.Text = string.upper(grade.Name)
		resultGrade.TextColor3 = grade.Color
		resultText.Text = Rules.Describe(pending.Enchantment)
	else
		resultGrade.Text = ""
		resultText.Text = if pending then "Keep or discard your roll on your other weapon first." else "Roll to see a new enchantment."
	end
	local cost = Rules.Cost(artifact)
	local gold = p and p.Currencies and p.Currencies.Gold or 0
	costLabel.Text = string.format("Roll cost: %s Gold  ·  You have %s", Balance.Format(cost), Balance.Format(gold))
	costLabel.TextColor3 = if gold >= cost then T.Gold else T.Bad
	rollButton.Visible = true
	rollButton.Text = if mine then "ROLL AGAIN (discard this roll)" else "ROLL"
	rollButton.Active = not busy and (not pending or mine)
	keepNew.Visible, keepOld.Visible = mine, mine
	local pity = if type(state.Pity) == "number" then state.Pity else 0
	pityLabel.Text = if Rules.PityReady(pity) then "Next roll: Epic or better guaranteed"
		else string.format("Epic or better guaranteed within %d rolls", Config.PityRolls - pity)
	statusLabel.Text = lastMessage
end

local remote: RemoteFunction? = nil
local function request(action: string, ...: any): any
	if not remote then
		local folder = remotes:FindFirstChild("ReforgeRemotes")
		remote = folder and folder:FindFirstChild("ReforgeRequest") :: RemoteFunction?
	end
	if not remote then return { Ok = false, Message = "The anvil is not ready yet." } end
	local ok, result = pcall((remote :: RemoteFunction).InvokeServer, remote, action, ...)
	if not ok or type(result) ~= "table" then return { Ok = false, Message = "The anvil did not answer. Try again." } end
	return result
end

local function act(action: string, choice: string?)
	if busy or not selected then return end
	busy = true
	render()
	local uuid = selected :: string
	local result = request(action, uuid, choice)
	busy = false
	lastMessage = tostring(result.Message or "")
	if result.Ok and action == "ROLL" and type(result.Enchantment) == "table" and Rules.IsEnchantment(result.Enchantment) then
		-- Show the roll at once; the profile sync that follows confirms it.
		local p = profile()
		if p then
			p.Reforge = p.Reforge or {}
			p.Reforge.Pending = { UUID = uuid, Enchantment = result.Enchantment }
		end
		UIFeel.Pop(resultCard, if result.Enchantment.Grade >= Config.PityGrade then 0.25 else 0.12)
		UIFeel.Sfx(if result.Enchantment.Grade >= Config.PityGrade then "UpgradeSuccess" else "StarTick")
		if result.Enchantment.Grade >= Config.PityGrade then
			UIFeel.Burst(resultCard, UDim2.fromScale(0.5, 0.5), Config.Grades[result.Enchantment.Grade].Color, 14, resultCard.ZIndex + 2, 140)
		end
	elseif result.Ok and action == "CHOOSE" then
		local p = profile()
		if p and p.Reforge then p.Reforge.Pending = nil end
		UIFeel.Sfx("Click")
	elseif not result.Ok then
		UIFeel.Deny(rollButton)
	end
	render()
end

rollButton.Activated:Connect(function() act("ROLL") end)
keepNew.Activated:Connect(function() act("CHOOSE", "NEW") end)
keepOld.Activated:Connect(function() act("CHOOSE", "OLD") end)

local function isOpen(): boolean return gui.Enabled end
local function closeWindow()
	gui.Enabled = false
end
local function openWindow()
	if gui.Enabled then return end
	WindowManager.CloseAll()
	lastMessage = ""
	gui.Enabled = true
	render()
	UIFeel.WindowIn(scale, fit())
	WindowManager.Opened("Reforge")
end
close.Activated:Connect(function() WindowManager.Close("Reforge") end)

WindowManager.Register("Reforge", {
	Open = openWindow,
	Close = closeWindow,
	IsOpen = isOpen,
	Root = function() return root end,
	HudCurrency = true,
})

ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
	if who ~= player or prompt.Name ~= Config.PromptName then return end
	if WindowManager.IsOpen("Reforge") then WindowManager.Close("Reforge") else openWindow() end
end)

profileSync.OnClientEvent:Connect(function()
	-- HUDController patches _G.CurrentProfile on the same event; read it after that.
	if gui.Enabled then task.defer(render) end
end)

-- Hydrate any EditableMesh Runesmith Sanctuary parts locally on the client before Roblox MeshIds are uploaded.
local function bindStationHydration(station: Instance)
	RunesmithMeshHydrator.HydratePendingClientParts(station)
	station.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") and desc:GetAttribute("PendingBlenderRunesmithMesh") == true then
			task.defer(function()
				if desc.Parent then
					RunesmithMeshHydrator.HydratePendingClientParts(station)
				end
			end)
		end
	end)
end

task.spawn(function()
	local existing = Workspace:FindFirstChild("ReforgeStation")
	if existing then
		bindStationHydration(existing)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "ReforgeStation" then
			bindStationHydration(child)
		end
	end)
end)
