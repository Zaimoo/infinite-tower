--!strict
-- Focused building HUDs; all mutations use the existing authoritative remotes.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FacilityConfig = require(ReplicatedStorage.Shared.Config.FacilityConfig)
local Controller = {}
Controller.__index = Controller
local C = {Panel = Color3.fromRGB(17, 24, 38), Row = Color3.fromRGB(25, 36, 54), Text = Color3.fromRGB(237, 231, 213), Muted = Color3.fromRGB(160, 176, 194)}
local DETAILS = {
	Summoning = {Title = "SUMMONING", Description = "Call new heroes through the rift.", Color = Color3.fromRGB(96, 191, 255)},
	Infirmary = {Title = "INFIRMARY", Description = "Rest heroes, restore stamina, and recover from coma.", Color = Color3.fromRGB(100, 232, 175)},
	SquadManagement = {Title = "SQUAD MANAGEMENT", Description = "Deploy rested heroes and bench your current squad.", Color = Color3.fromRGB(245, 128, 99)},
}

local function corner(object: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius, c.Parent = UDim.new(0, radius), object
end
local function label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name, l.Size, l.Position = name, size, position
	l.ZIndex = 24
	l.BackgroundTransparency, l.TextColor3, l.TextSize = 1, color, textSize
	l.Font, l.TextWrapped, l.TextXAlignment = Enum.Font.GothamMedium, true, Enum.TextXAlignment.Left
	l.Text, l.Parent = "", parent
	return l
end

function Controller.new(parent: Instance, getProfile: () -> any, remotes: Instance)
	local self: any = setmetatable({}, Controller)
	self.GetProfile, self.Busy, self.LastSummoned = getProfile, false, {}
	self.Summon = remotes:WaitForChild("RequestSummon")
	self.Assign = remotes:WaitForChild("AssignHeroRole")
	self.Facility = remotes:WaitForChild("FacilityInteract")
	local root = Instance.new("Frame")
	root.Name, root.AnchorPoint, root.Position = "FacilityModal", Vector2.new(.5, .5), UDim2.fromScale(.5, .5)
	root.BackgroundColor3, root.BorderSizePixel, root.Visible = C.Panel, 0, false
	root.Active, root.ZIndex, root.Parent = true, 20, parent
	corner(root, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = C.Muted, 1.5, root
	self.Root, self.Stroke = root, stroke
	self.Title = label(root, "FacilityTitle", UDim2.new(1, -130, 0, 30), UDim2.fromOffset(20, 16), 22, C.Text)
	self.Title.TextScaled, self.Title.TextWrapped = true, false
	local titleSize = Instance.new("UITextSizeConstraint")
	titleSize.MinTextSize, titleSize.MaxTextSize, titleSize.Parent = 12, 22, self.Title
	self.Description = label(root, "Description", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 52), 14, C.Muted)
	self.Summary = label(root, "Summary", UDim2.new(1, -40, 0, 44), UDim2.fromOffset(20, 98), 15, C.Text)
	self.Actions = Instance.new("Frame")
	self.Actions.Name, self.Actions.BackgroundTransparency = "FacilityActions", 1
	self.Actions.ZIndex = 21
	self.Actions.Position, self.Actions.Size, self.Actions.Parent = UDim2.fromOffset(20, 150), UDim2.new(1, -40, 0, 42), root
	self.List = Instance.new("ScrollingFrame")
	self.List.Name, self.List.BackgroundTransparency, self.List.BorderSizePixel = "HeroList", 1, 0
	self.List.ZIndex = 21
	self.List.Position, self.List.Size = UDim2.fromOffset(20, 210), UDim2.new(1, -40, 1, -274)
	self.List.ScrollBarThickness, self.List.AutomaticCanvasSize, self.List.CanvasSize = 5, Enum.AutomaticSize.Y, UDim2.new()
	self.List.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding, layout.SortOrder, layout.Parent = UDim.new(0, 8), Enum.SortOrder.LayoutOrder, self.List
	self.Status = label(root, "Status", UDim2.new(1, -40, 0, 44), UDim2.new(0, 20, 1, -52), 13, C.Muted)
	self:Button(root, "Close", "CLOSE", UDim2.fromOffset(88, 30), UDim2.new(1, -108, 0, 16), function() self:Close() end)
	local function resize()
		local camera = Workspace.CurrentCamera
		if camera then root.Size = UDim2.fromOffset(math.min(850, math.max(280, camera.ViewportSize.X - 32)), math.min(620, math.max(300, camera.ViewportSize.Y - 100))) end
	end
	local cameraConnection: RBXScriptConnection? = nil
	local function trackCamera()
		if cameraConnection then cameraConnection:Disconnect() end
		if Workspace.CurrentCamera then cameraConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
		resize()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(trackCamera)
	trackCamera()
	return self
end

function Controller.Button(self: any, parent: Instance, name: string, text: string, size: UDim2, position: UDim2, action: () -> ())
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Size, b.Position = name, text, size, position
	b.ZIndex = 24
	b.Font, b.TextSize, b.TextWrapped = Enum.Font.GothamBold, 13, true
	b.BackgroundColor3, b.TextColor3, b.BorderSizePixel = Color3.fromRGB(45, 64, 82), C.Text, 0
	b.Parent = parent
	corner(b, 6)
	b.Activated:Connect(action)
	return b
end

function Controller.Close(self: any)
	self.Root.Visible = false
end

function Controller.Open(self: any, facility: string)
	if not DETAILS[facility] then return end
	self.Current, self.Root.Visible = facility, true
	self.Root:SetAttribute("Facility", facility)
	self.Status.Text = ""
	self:Refresh()
end

function Controller.Request(self: any, callback: () -> (boolean, string))
	if self.Busy then return end
	self.Busy, self.Status.Text = true, "Working…"
	task.spawn(function()
		local ok, success, message = pcall(callback)
		self.Busy = false
		self.Status.Text = if ok then message or (success and "Done." or "Unable to complete this action.") else "Connection failed. Please try again."
		self:Refresh()
	end)
end

function Controller.Refresh(self: any)
	if not self.Root.Visible then return end
	local info = DETAILS[self.Current]
	self.Title.Text, self.Description.Text, self.Stroke.Color = info.Title, info.Description, info.Color
	self.Title.TextColor3 = info.Color
	for _, c in self.Actions:GetChildren() do c:Destroy() end
	for _, c in self.List:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
	local profile = self.GetProfile()
	if not profile then self.Summary.Text = "Loading your heroes…"; return end
	local heroes = {}
	for _, h in profile.Heroes or {} do table.insert(heroes, h) end
	table.sort(heroes, function(a, b)
		if self.Current == "SquadManagement" then
			local aSquad, bSquad = a.Assignment:match("^SQUAD_SLOT_") ~= nil, b.Assignment:match("^SQUAD_SLOT_") ~= nil
			if aSquad ~= bSquad then return aSquad end
		elseif self.Current == "Infirmary" then
			local aRest, bRest = a.Assignment == "FACILITY_INFIRMARY", b.Assignment == "FACILITY_INFIRMARY"
			if aRest ~= bRest then return aRest end
		end
		if a.Stars ~= b.Stars then return a.Stars > b.Stars end
		return tostring(a.UUID) < tostring(b.UUID)
	end)
	if self.Current == "Summoning" then
		self.Summary.Text = string.format("%d Gems available  •  %d heroes owned", math.floor(profile.Currencies.Gems), #heroes)
		for i, pull in {1, 10} do
			local cost = pull == 10 and 900 or 100
			self:Button(self.Actions, "Summon" .. pull, string.format("SUMMON %dx  ·  %d GEMS", pull, cost), UDim2.new(.49, -4, 1, 0), UDim2.fromScale((i - 1) * .51, 0), function()
				self:Request(function()
					local result = self.Summon:InvokeServer(pull)
					if result.Success then
						self.LastSummoned = result.Summoned or {}
						local count = #self.LastSummoned
						return true, string.format("Summoned %d %s. New heroes appear below.", count, count == 1 and "hero" or "heroes")
					end
					return false, result.Message or "Summoning failed."
				end)
			end)
		end
		if #self.LastSummoned > 0 then heroes = self.LastSummoned end
	elseif self.Current == "Infirmary" then
		local facility = profile.Facilities.Infirmary
		local resting = 0
		for _, h in heroes do if h.Assignment == "FACILITY_INFIRMARY" then resting += 1 end end
		self.Summary.Text = string.format("Infirmary Lv.%d  •  %d heroes resting  •  Recovery runs while assigned here", facility.Level, resting)
		local nextLevel = FacilityConfig.UpgradeTable.Infirmary[facility.Level + 1]
		local upgrade = nextLevel and string.format("UPGRADE · %d GOLD", nextLevel.Gold) or "MAXIMUM LEVEL"
		self:Button(self.Actions, "Upgrade", upgrade, UDim2.new(1, 0, 1, 0), UDim2.new(), function()
			if nextLevel then self.Facility:FireServer("UPGRADE_FACILITY", "Infirmary") end
		end)
	else
		local deployed = 0
		for _, h in heroes do if h.Assignment:match("^SQUAD_SLOT_") then deployed += 1 end end
		local slots = 5 -- All squad slots are available after removal of research unlocks.
		self.Summary.Text = string.format("%d / %d squad slots occupied  •  Deploy heroes or send them to the bench", deployed, slots)
		self:Button(self.Actions, "RotateSquad", "REST EXHAUSTED & DEPLOY FRESH HEROES", UDim2.new(1, 0, 1, 0), UDim2.new(), function()
			self:Request(function() return self.Assign:InvokeServer("AUTO_SWAP_EXHAUSTED", "") end)
		end)
	end
	if #heroes == 0 then
		local empty = label(self.List, "Empty", UDim2.new(1, -8, 0, 80), UDim2.new(), 16, C.Muted)
		empty.Text = "Your roster is empty. Visit Summoning to call a hero."
	end
	for index, hero in heroes do
		local row = Instance.new("Frame")
		row.Name, row.LayoutOrder, row.Size = "Hero_" .. hero.UUID, index, UDim2.new(1, -10, 0, 92)
		row.ZIndex = 22
		row.BackgroundColor3, row.BorderSizePixel, row.Parent = C.Row, 0, self.List
		corner(row, 8)
		local description = label(row, "HeroDetails", UDim2.new(self.Current == "Summoning" and 1 or .56, -18, 1, -12), UDim2.fromOffset(12, 6), 14, C.Text)
		local coma = math.max(0, (hero.ComaUntilTimestamp or 0) - os.time())
		local status = coma > 0 and string.format("Recovering · %ds", coma) or string.format("Stamina %d%%", math.round(hero.CurrentStamina or 100))
		description.Text = string.format("%s  %s  Lv.%d\n%s  ·  %s", hero.DisplayName, string.rep("★", hero.Stars or 1), hero.Level or 1, hero.Assignment, status)
		if self.Current ~= "Summoning" then
			local rest = self.Current == "Infirmary"
			local uuid = hero.UUID
			local assignment = rest and "FACILITY_INFIRMARY" or "SQUAD_AUTO"
			self:Button(row, "Assign", rest and "REST" or "DEPLOY", UDim2.new(.20, -4, 0, 42), UDim2.new(.57, 0, .5, -21), function()
				self:Request(function() return self.Assign:InvokeServer(uuid, assignment) end)
			end)
			self:Button(row, "Bench", "BENCH", UDim2.new(.20, -4, 0, 42), UDim2.new(.79, 0, .5, -21), function()
				self:Request(function() return self.Assign:InvokeServer(uuid, "BENCHED") end)
			end)
		end
	end
end
return Controller
