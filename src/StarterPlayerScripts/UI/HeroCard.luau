--!strict
-- Reusable, updateable hero card. A page owns at most eight static busts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local T = require(script.Parent:WaitForChild("PitDesignTokens"))
local HeroCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HeroCatalog"))
local StatFormulas = require(ReplicatedStorage.Shared.Util.StatFormulas)
local HeroCard = {}

function HeroCard.Portrait(parent: Instance, hero: any): GuiObject
	local seed = HeroCatalog.Seeds[hero.TemplateId]
	local portrait = hero.Portrait or (seed and seed.Portrait)
	if type(portrait) == "string" and portrait ~= "" then
		return T.New("ImageLabel", {BackgroundTransparency = 1, Image = portrait, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1)}, parent)
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Heroes")
	local template = folder and folder:FindFirstChild(hero.TemplateId or "")
	if template and template:IsA("Model") then
		local viewport = T.New("ViewportFrame", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
			Ambient = Color3.fromRGB(195, 185, 168), LightColor = Color3.fromRGB(255, 238, 212),
			LightDirection = Vector3.new(-1, -1, -2),
		}, parent)
		local model = template:Clone()
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BaseScript") then descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
			end
		end
		model.Parent = viewport
		local bounds, size = model:GetBoundingBox()
		local head = model:FindFirstChild("Head")
		local look = if head and head:IsA("BasePart") then head.Position - Vector3.new(0, size.Y * 0.1, 0) else bounds.Position + Vector3.new(0, size.Y * 0.22, 0)
		local forward = bounds.LookVector
		local camera = T.New("Camera", {FieldOfView = 32, CFrame = CFrame.lookAt(look + forward * math.max(4, size.Y * 0.82), look)}, viewport)
		viewport.CurrentCamera = camera
		return viewport
	end
	local fallback = T.Label(parent, string.sub(hero.Archetype or "Hero", 1, 1), 32, T.Rarity[hero.Stars or 1])
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.TextXAlignment = Enum.TextXAlignment.Center
	return fallback
end

function HeroCard.new(parent: Instance, onSelect: (string) -> ())
	local self: any = {Hero = nil, PortraitId = nil}
	self.Root = T.Button(parent, "", function() if self.Hero then onSelect(self.Hero.UUID) end end)
	self.Root.Name = "HeroCard"
	self.Root.Size = UDim2.new(1, -6, 0, 150)
	self.Root.ClipsDescendants = true
	self.Edge = self.Root:FindFirstChildOfClass("UIStroke")
	self.PortraitHost = T.New("Frame", {BackgroundColor3 = T.Color.Obsidian, BorderSizePixel = 0, Size = UDim2.fromOffset(64, 82), Position = UDim2.fromOffset(8, 9)}, self.Root)
	T.Corner(self.PortraitHost, 5)
	self.Name = T.Label(self.Root, "", 15)
	self.Name.Font = Enum.Font.GothamBold
	self.Name.Position = UDim2.fromOffset(81, 8)
	self.Name.Size = UDim2.new(1, -90, 0, 23)
	self.Info = T.Label(self.Root, "", 14, T.Color.Muted)
	self.Info.Position = UDim2.fromOffset(81, 32)
	self.Info.Size = UDim2.new(1, -90, 0, 42)
	self.Status = T.Label(self.Root, "", 13, T.Color.Muted)
	self.Status.Position = UDim2.fromOffset(81, 76)
	self.Status.Size = UDim2.new(1, -90, 0, 30)
	self.Trait = T.Label(self.Root, "", 13, T.Color.Muted)
	self.Trait.Position = UDim2.fromOffset(9, 111)
	self.Trait.Size = UDim2.new(1, -18, 0, 34)
	local track = T.New("Frame", {BackgroundColor3 = T.Color.Obsidian, BorderSizePixel = 0, Position = UDim2.fromOffset(81, 106), Size = UDim2.new(1, -91, 0, 3)}, self.Root)
	self.XPFill = T.New("Frame", {BackgroundColor3 = T.Color.Bronze, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1)}, track)
	self.Inset = T.New("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8)}, self.Root)
	T.Corner(self.Inset, 5)
	self.InsetStroke = T.Stroke(self.Inset)
	self.Ornaments = {}
	for _, offset in {0, 1} do
		local ornament = T.New("Frame", {AnchorPoint = Vector2.new(offset, 0), Position = UDim2.new(offset, offset == 0 and 3 or -3, 0, 3), Size = UDim2.fromOffset(7, 7), Rotation = 45, BorderSizePixel = 0, BackgroundColor3 = T.Color.Gold}, self.Root)
		table.insert(self.Ornaments, ornament)
	end
	self.Crest = T.Label(self.Root, "◇", 18, T.Color.Gold)
	self.Crest.Size, self.Crest.Position, self.Crest.TextXAlignment = UDim2.fromOffset(24, 24), UDim2.new(1, -28, 0, -2), Enum.TextXAlignment.Center
	return setmetatable(self, {__index = HeroCard})
end

function HeroCard.Update(self: any, hero: any, selected: boolean, mode: string, textSize: number?)
	self.Hero = hero
	local stars = math.clamp(hero.Stars or 1, 1, 5)
	local rarity = T.Rarity[stars]
	self.Root.Visible = true
	self.Root.BackgroundColor3 = selected and Color3.fromRGB(57, 49, 39) or T.Color.Raised
	self.Edge.Color = selected and T.Color.Gold or rarity
	self.Edge.Thickness = selected and 2 or 1
	self.Name.Text = (selected and "✓ " or "") .. (hero.DisplayName or "Hero")
	self.Name.TextColor3 = rarity
	local stats = hero.Stats or hero.PitStats
	local _, _, dps = StatFormulas.GetEffectiveCombatStats(hero, false, false)
	self.Info.Text = string.format("%s  Lv.%d / %d\n%s · DPS %s", T.Stars(stars), hero.Level or 1, stars * 10, hero.Archetype or "Hero", T.Number(stats and stats.DPS or dps))
	local status = hero.PitStatus or {}
	local reason = status.Reason
	self.Status.Text = (hero.Locked and "[LOCKED] " or "") .. (hero.Favorite and "[FAVORITE] " or "") .. (status.Status or hero.Assignment or "Available")
	if mode == "DONOR" and status.EligibleDonor == false then
		self.Status.Text = reason or "Ineligible"
		self.Status.TextColor3 = T.Color.Danger
	else self.Status.TextColor3 = T.Color.Muted end
	self.Trait.Text = hero.PassiveTrait or "No signature trait recorded"
	self.XPFill.Size = UDim2.fromScale(math.clamp((hero.XP or 0) / StatFormulas.GetXPRequiredForNextLevel(hero.Level or 1), 0, 1), 1)
	self.XPFill.BackgroundColor3 = rarity
	self.Name.TextSize = (textSize or 14) + 1
	self.Info.TextSize = textSize or 14
	self.Status.TextSize = math.max(13, (textSize or 14) - 1)
	self.Trait.TextSize = math.max(13, (textSize or 14) - 1)
	self.Inset.Visible = stars >= 4
	self.InsetStroke.Color = rarity
	self.Crest.Visible = stars == 5
	for _, ornament in self.Ornaments do ornament.Visible = stars >= 3; ornament.BackgroundColor3 = rarity end
	if self.PortraitId ~= hero.TemplateId then
		self.PortraitId = hero.TemplateId
		self.PortraitHost:ClearAllChildren()
		T.Corner(self.PortraitHost, 5)
		HeroCard.Portrait(self.PortraitHost, hero)
	end
end

return HeroCard
