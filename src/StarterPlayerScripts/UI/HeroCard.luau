--!strict
-- Reusable, updateable hero card. A page owns at most eight static busts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local T = require(script.Parent:WaitForChild("PitDesignTokens"))
local HeroCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("HeroCatalog"))
local StatFormulas = require(ReplicatedStorage.Shared.Util.StatFormulas)
local HeroRig = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HeroRig")
local HeroClips = require(HeroRig:WaitForChild("HeroClips"))
local HeroAnimator = require(HeroRig:WaitForChild("HeroAnimator"))
local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local RunService = game:GetService("RunService")
local HeroCard = {}
local FIELD_OF_VIEW = 32

-- Rig portraits are ViewportFrames holding a posed clone of the hero's rig (~50 parts). Rosters list
-- hundreds of heroes, so a rig is only built while its portrait is on screen (every ancestor
-- visible, and inside or near its ScrollingFrame's view). A portrait scrolled well out of view parks
-- its rig outside the viewport, so it costs nothing to render.
-- Posing a rig and framing its camera happens once per hero and framing: the posed rig is kept as a
-- master (never rendered) and every portrait clones it. So reopening a window, or a list rebuilding
-- its cards, shows each portrait in a frame or two instead of rebuilding it from the template.
-- The checks are cheap on purpose: reading AbsolutePosition right after a layout change forces a
-- full layout pass (~15 ms), so a position is only read when its portrait first shows or after the
-- engine reports it moved (scroll, sort, resize), and the visibility walk is spread over frames.
local BUILD_BUDGET = 12 -- per frame: a clone of a cached master costs 1, posing a new master costs 4
local MASTER_COST = 4
local CHECKS_PER_FRAME = 120
local SETTLE_SECONDS = 0.1 -- let a window's open pop settle before reading layout for a new portrait
local RECHECK_SECONDS = 0.05 -- a built portrait that is moving (scrolling) is re-checked this often
type Lazy = {
	Viewport: ViewportFrame, Template: Model, Hero: any, Model: Model?, Dead: boolean,
	FullBody: boolean?, CloseUp: boolean?,
	Scroll: ScrollingFrame?, Moved: boolean, MovedAt: number, CheckedAt: number, WasVisible: boolean, Queued: boolean, Y: number,
}
type Master = { Model: Model, Camera: CFrame }
local entries: { Lazy } = {}
local cursor = 1
local pending: { Lazy } = {}
-- Posed masters per template instance (weak keys, so a re-replicated template drops its old
-- masters), then per framing ("Bust", "CloseUp", "Full").
local masters: { [Model]: { [string]: Master } } = setmetatable({}, { __mode = "k" }) :: any

local function framingKey(entry: Lazy): string
	return if entry.FullBody then "Full" elseif entry.CloseUp then "CloseUp" else "Bust"
end

local function cachedMaster(entry: Lazy): Master?
	local byFraming = masters[entry.Template]
	return byFraming and byFraming[framingKey(entry)]
end

-- Every ancestor up to the ScreenGui is visible (no layout read).
local function visible(vp: ViewportFrame): boolean
	local node: Instance? = vp
	while node and node:IsA("GuiObject") do
		if not node.Visible then return false end
		node = node.Parent
	end
	return node ~= nil and node:IsA("LayerCollector") and node.Enabled and node:IsDescendantOf(game)
end

-- Inside the scroll's view or within one view's length of it, so rigs are ready before they scroll
-- in and stay put during ordinary scrolling. Reads layout, so call it only when needed.
local function inView(entry: Lazy, scroll: ScrollingFrame): boolean
	local vp = entry.Viewport
	local p, s = vp.AbsolutePosition, vp.AbsoluteSize
	local sp, ss = scroll.AbsolutePosition, scroll.AbsoluteSize
	entry.Y = p.Y
	return p.Y + s.Y >= sp.Y - ss.Y and p.Y <= sp.Y + ss.Y * 2 and p.X + s.X >= sp.X - ss.X and p.X <= sp.X + ss.X * 2
end

local function check(entry: Lazy)
	local vp = entry.Viewport
	local now = os.clock()
	if entry.Model then
		-- Built: only a move can change whether it should render (a hidden window doesn't render
		-- its viewports anyway). The position is already laid out when Moved fires, so a built
		-- portrait re-checks while scrolling instead of waiting for the scroll to stop.
		local scroll = entry.Scroll
		if scroll and entry.Moved and now - entry.CheckedAt >= RECHECK_SECONDS then
			entry.Moved = false
			entry.CheckedAt = now
			local target = if inView(entry, scroll) then vp else nil
			if entry.Model.Parent ~= target then entry.Model.Parent = target end
		end
		return
	end
	if entry.Queued then return end
	local settled = now - entry.MovedAt >= SETTLE_SECONDS
	local shown = visible(vp)
	if shown and not entry.WasVisible then
		-- Just appeared: its window is probably mid-pop, so let it settle first.
		entry.Moved = true
		entry.MovedAt = now
		settled = false
	end
	entry.WasVisible = shown
	if not shown then return end
	if entry.Scroll == nil then
		entry.Scroll = vp:FindFirstAncestorWhichIsA("ScrollingFrame")
	end
	local scroll = entry.Scroll
	if scroll then
		if not entry.Moved or not settled then return end -- unchanged since the last look, or still moving
		entry.Moved = false
		entry.CheckedAt = now
		if not inView(entry, scroll) then return end
	else
		entry.Y = 0
	end
	entry.Queued = true
	table.insert(pending, entry)
end

-- Clone the template, strip scripts, anchor, pose the idle and frame the camera. Done once per
-- template and framing; portraits clone the result.
local function buildMaster(entry: Lazy): Master
	local model = entry.Template:Clone()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end
	-- Viewports never simulate joints: pose the hero's idle by writing part CFrames.
	if model:GetAttribute("HeroRigVersion") ~= nil then
		local idle = HeroClips.Get(entry.Hero.TemplateId, nil, "Idle")
		if idle then
			HeroAnimator.ApplyStaticPose(model, HeroAnimator.Sample(idle, 0))
		end
	end
	local bounds, size = model:GetBoundingBox()
	local forward = bounds.LookVector
	local look: Vector3
	local distance: number
	if entry.FullBody then
		look = bounds.Position
		forward = (forward + bounds.RightVector * 0.16 + Vector3.new(0, 0.06, 0)).Unit
		distance = math.max(size.X, size.Y) * 0.55 / math.tan(math.rad(FIELD_OF_VIEW / 2)) + size.Z * 0.5
	else
		local head = model:FindFirstChild("Head")
		look = if head and head:IsA("BasePart") then head.Position - Vector3.new(0, size.Y * 0.1, 0) else bounds.Position + Vector3.new(0, size.Y * 0.22, 0)
		distance = math.max(4, size.Y * 0.82)
		if entry.CloseUp then
			if head and head:IsA("BasePart") then
				look = head.Position - Vector3.new(0, size.Y * 0.045, 0)
			end
			distance = math.max(2.8, size.Y * 0.65)
		end
	end
	local master: Master = { Model = model, Camera = CFrame.lookAt(look + forward * distance, look) }
	local byFraming = masters[entry.Template]
	if not byFraming then
		byFraming = {}
		masters[entry.Template] = byFraming
	end
	byFraming[framingKey(entry)] = master
	return master
end

local function buildRig(entry: Lazy)
	local vp = entry.Viewport
	local master = cachedMaster(entry) or buildMaster(entry)
	local model = master.Model:Clone()
	model.Parent = vp
	local camera = T.New("Camera", {FieldOfView = FIELD_OF_VIEW, CFrame = master.Camera}, vp)
	vp.CurrentCamera = camera
	entry.Model = model
end

local function stepLazyRigs()
	-- Look at a slice of the portraits each frame, dropping destroyed ones as we pass.
	local n = math.min(CHECKS_PER_FRAME, #entries)
	for _ = 1, n do
		if cursor > #entries then cursor = 1 end
		local entry = entries[cursor]
		if entry.Dead then
			entries[cursor] = entries[#entries]
			entries[#entries] = nil
		else
			check(entry)
			cursor += 1
		end
	end
	-- Build the highest queued portraits first, within the frame's budget.
	local budget = BUILD_BUDGET
	while budget > 0 and #pending > 0 do
		local best = 1
		for i = 2, #pending do
			if pending[i].Y < pending[best].Y then best = i end
		end
		local entry = table.remove(pending, best) :: Lazy
		entry.Queued = false
		if not entry.Dead and not entry.Model and entry.Viewport.Parent then
			budget -= if cachedMaster(entry) then 1 else MASTER_COST
			buildRig(entry)
		end
	end
end
RunService.Heartbeat:Connect(function()
	debug.profilebegin("HeroCard.LazyRigs")
	stepLazyRigs()
	debug.profileend()
end)

local function portraitImage(parent: Instance, image: string): ImageLabel
	return T.New("ImageLabel", {BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1)}, parent)
end

function HeroCard.Portrait(parent: Instance, hero: any, framing: (boolean | "CloseUp")?): GuiObject
	local seed = HeroCatalog.Seeds[hero.TemplateId]
	local portrait = hero.Portrait or (seed and seed.Portrait)
	if framing ~= true and type(portrait) == "string" and portrait ~= "" then
		return portraitImage(parent, portrait)
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
		local entry: Lazy = {
			Viewport = viewport, Template = template, Hero = { TemplateId = hero.TemplateId }, Model = nil, Dead = false,
			FullBody = framing == true, CloseUp = framing == "CloseUp",
			Scroll = nil, Moved = false, MovedAt = 0, CheckedAt = 0, WasVisible = false, Queued = false, Y = 0,
		}
		table.insert(entries, entry)
		-- Fires after layout (scroll, sort, resize, open pop), so listening costs no forced layout.
		viewport:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			entry.Moved = true
			entry.MovedAt = os.clock()
		end)
		viewport.Destroying:Connect(function()
			entry.Dead = true
			if entry.Model then entry.Model:Destroy() end
		end)
		return viewport
	end
	local fallback: GuiObject
	if type(portrait) == "string" and portrait ~= "" then
		fallback = portraitImage(parent, portrait)
	else
		local placeholder = T.Label(parent, string.sub(hero.Archetype or "Hero", 1, 1), 32, T.Rarity[math.clamp(StatFormulas.GetHeroRarity(hero), 1, #T.Rarity)])
		placeholder.Size = UDim2.fromScale(1, 1)
		placeholder.TextXAlignment = Enum.TextXAlignment.Center
		fallback = placeholder
	end

	-- If template is still loading or replicating, re-mount once available
	task.spawn(function()
		local a = ReplicatedStorage:WaitForChild("Assets", 3)
		local h = a and a:WaitForChild("Heroes", 3)
		local t = h and h:WaitForChild(hero.TemplateId or "", 3)
		if t and t:IsA("Model") and parent.Parent and fallback.Parent == parent then
			local view = HeroCard.Portrait(parent, hero, framing)
			view.ZIndex = fallback.ZIndex
			fallback:Destroy()
		end
	end)

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
	-- Top-rarity crest: a drawn Gilded Grimoire spark.
	self.Crest = GrimoireIcons.Create("Spark", 22, self.Root, self.Root.ZIndex + 2)
	self.Crest.Position = UDim2.new(1, -27, 0, 1)
	return setmetatable(self, {__index = HeroCard})
end

function HeroCard.Update(self: any, hero: any, selected: boolean, mode: string, textSize: number?)
	self.Hero = hero
	local stars = math.clamp(hero.Stars or 1, 1, 5)
	local rarity = T.Rarity[math.clamp(StatFormulas.GetHeroRarity(hero), 1, #T.Rarity)]
	self.Root.Visible = true
	self.Root.BackgroundColor3 = selected and Color3.fromRGB(57, 49, 39) or T.Color.Raised
	self.Edge.Color = selected and T.Color.Gold or rarity
	self.Edge.Thickness = selected and 2 or 1
	self.Name.Text = (selected and "» " or "") .. (hero.DisplayName or "Hero")
	self.Name.TextColor3 = rarity
	local stats = hero.Stats or hero.PitStats
	local combat = stats or StatFormulas.GetCombatSnapshot(hero)
	self.Info.Text = string.format("%s  Lv.%d / %d\n%s · DPS %s", T.Stars(stars), hero.Level or 1, StatFormulas.GetMaxLevel(stars), hero.Archetype or "Hero", T.Number(combat.DPS))
	local status = hero.PitStatus or {}
	local reason = status.Reason
	self.Status.Text = (hero.Locked and "[LOCKED] " or "") .. (hero.Favorite and "[FAVORITE] " or "") .. (status.Status or hero.Assignment or "Available")
	if mode == "DONOR" and status.EligibleDonor == false then
		self.Status.Text = reason or "Ineligible"
		self.Status.TextColor3 = T.Color.Danger
	else self.Status.TextColor3 = T.Color.Muted end
	self.Trait.Text = string.format("Damage %s · HP %s\nSpeed %.2f/s · Move %.0f studs/s", T.Number(combat.AttackDamage or combat.ATK), T.Number(combat.Health or combat.HP), combat.AttackSpeed or 1, combat.MovementSpeed or 20)
	self.XPFill.Size = UDim2.fromScale(math.clamp((hero.XP or 0) / StatFormulas.GetXPRequiredForNextLevel(hero.Level or 1, hero.Stars), 0, 1), 1)
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
