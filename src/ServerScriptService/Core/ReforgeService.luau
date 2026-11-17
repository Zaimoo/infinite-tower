--!strict
-- ServerScriptService/Core/ReforgeService.luau
-- Server owner of the Weapon Reforge (GDD §7.6): the Runesmith's Anvil on the Cloister Commons, its remote,
-- and the random rolls. The rules are pure (Shared/Util/ReforgeRules).
--
-- Remote (ReplicatedStorage.Remotes.ReforgeRemotes):
--   ReforgeRequest (RemoteFunction): ("ROLL", artifactUUID) or ("CHOOSE", artifactUUID, "NEW" | "OLD").
--   Returns { Ok, Message, Enchantment? }. The new balance, enchantment and pending roll reach the client in the profile sync.
-- The station's ProximityPrompt (ReforgeConfig.PromptName) only opens the client window; every action goes
-- through the remote and is validated here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.ReforgeConfig)
local HubLayout = require(ReplicatedStorage.Shared.Config.HubLayout)
local Rules = require(ReplicatedStorage.Shared.Util.ReforgeRules)

export type Dependencies = {
	GetProfile: (Player) -> any,
	-- Sync that refreshes the deployed heroes' stats (an enchantment changes ATK, HP or attack speed).
	SyncProfile: (Player) -> (),
}

local ReforgeService = {}
local deps: Dependencies? = nil
local rng = Random.new()
local recentRequests: { [Player]: { number } } = {}

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local kept = {}
	for _, t in recentRequests[player] or {} do
		if now - t < 1 then table.insert(kept, t) end
	end
	local allowed = #kept < Config.MaxRequestsPerSecond
	if allowed then table.insert(kept, now) end
	recentRequests[player] = kept
	return allowed
end

-- Adds profile.Reforge (old saves) and drops damaged enchantments. Run on load.
function ReforgeService.EnsureState(profile: any)
	Rules.EnsureState(profile)
end

local function handle(player: Player, action: any, uuid: any, choice: any): any
	local d = deps
	local profile = d and d.GetProfile(player)
	if not d or not profile then return { Ok = false, Message = "Your save is still loading." } end
	if not allowRequest(player) then return { Ok = false, Message = "Slow down." } end
	if type(uuid) ~= "string" or #uuid == 0 or #uuid > 64 then return { Ok = false, Message = "Choose a weapon." } end

	if action == "ROLL" then
		local ok, message, enchantment = Rules.Roll(profile, uuid, rng:NextNumber(), rng:NextNumber())
		if ok then d.SyncProfile(player) end
		return { Ok = ok, Message = message, Enchantment = enchantment }
	elseif action == "CHOOSE" then
		if choice ~= "NEW" and choice ~= "OLD" then return { Ok = false, Message = "Invalid choice." } end
		local ok, message = Rules.Choose(profile, uuid, choice == "NEW")
		d.SyncProfile(player) -- a refused choice may still have cleared a stale pending roll
		return { Ok = ok, Message = message }
	end
	return { Ok = false, Message = "Unknown request." }
end

--------------------------------------------------------------------------------------------------------
-- The station: a stone dais with an anvil, a rune brazier and two standing stones, built at
-- HubLayout.ReforgeStationCFrame(). Plain parts, so it needs no uploaded assets and no hub rebake.
--------------------------------------------------------------------------------------------------------
local STONE = Color3.fromRGB(92, 88, 98)
local DARK_STONE = Color3.fromRGB(58, 54, 64)
local IRON = Color3.fromRGB(46, 46, 52)
local RUNE = Color3.fromRGB(255, 170, 70)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

local function decor(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

function ReforgeService.BuildStation(parent: Instance): (Model, ProximityPrompt)
	local old = parent:FindFirstChild("ReforgeStation")
	if old then old:Destroy() end
	local s = HubLayout.ReforgeStation.Scale
	local origin = HubLayout.ReforgeStationCFrame()
	local model = Instance.new("Model")
	model.Name = "ReforgeStation"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- the prompt and its effects arrive together

	-- Two-step round dais (cylinders lie along X, so turn them upright).
	local upright = CFrame.Angles(0, 0, math.rad(90))
	part(model, "DaisBase", Vector3.new(1.2 * s, 32 * s, 32 * s), origin * CFrame.new(0, 0.6 * s, 0) * upright, DARK_STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
	part(model, "DaisTop", Vector3.new(1.2 * s, 24 * s, 24 * s), origin * CFrame.new(0, 1.8 * s, 0) * upright, STONE, Enum.Material.Cobblestone, Enum.PartType.Cylinder)
	local ring = decor(part(model, "RuneRing", Vector3.new(0.2 * s, 22 * s, 22 * s), origin * CFrame.new(0, 2.45 * s, 0) * upright, RUNE, Enum.Material.Neon, Enum.PartType.Cylinder))
	ring.Transparency = 0.55
	part(model, "RuneRingInset", Vector3.new(0.25 * s, 20.5 * s, 20.5 * s), origin * CFrame.new(0, 2.5 * s, 0) * upright, STONE, Enum.Material.Cobblestone, Enum.PartType.Cylinder)

	-- The anvil: stump, waist, face and horn.
	local top = origin * CFrame.new(0, 2.4 * s, 0)
	part(model, "AnvilStump", Vector3.new(4.6 * s, 2.4 * s, 4.6 * s), top * CFrame.new(0, 1.2 * s, 0), Color3.fromRGB(96, 66, 42), Enum.Material.Wood)
	part(model, "AnvilWaist", Vector3.new(2.4 * s, 1.6 * s, 1.8 * s), top * CFrame.new(0, 3.2 * s, 0), IRON, Enum.Material.Metal)
	local face = part(model, "AnvilFace", Vector3.new(5.6 * s, 1.2 * s, 2.4 * s), top * CFrame.new(0, 4.6 * s, 0), IRON, Enum.Material.Metal)
	local horn = part(model, "AnvilHorn", Vector3.new(2.6 * s, 0.9 * s, 0.9 * s), top * CFrame.new(-3.9 * s, 4.7 * s, 0) * CFrame.Angles(0, 0, math.rad(-8)), IRON, Enum.Material.Metal)
	horn.Shape = Enum.PartType.Cylinder
	local glow = decor(part(model, "AnvilGlow", Vector3.new(4.8 * s, 0.1 * s, 1.6 * s), face.CFrame * CFrame.new(0, 0.62 * s, 0), RUNE, Enum.Material.Neon))
	glow.Transparency = 0.35

	-- A hammer resting on the face.
	part(model, "HammerHandle", Vector3.new(0.35 * s, 0.35 * s, 3.4 * s), face.CFrame * CFrame.new(1.2 * s, 0.8 * s, 0.4 * s) * CFrame.Angles(0, math.rad(25), 0), Color3.fromRGB(110, 76, 48), Enum.Material.Wood)
	part(model, "HammerHead", Vector3.new(1.4 * s, 0.8 * s, 0.8 * s), face.CFrame * CFrame.new(1.9 * s, 0.85 * s, -1.0 * s) * CFrame.Angles(0, math.rad(25), 0), IRON, Enum.Material.Metal)

	-- The rune brazier behind the anvil.
	local brazier = origin * CFrame.new(0, 2.4 * s, 7.5 * s)
	part(model, "BrazierLeg", Vector3.new(1.2 * s, 3.6 * s, 1.2 * s), brazier * CFrame.new(0, 1.8 * s, 0), IRON, Enum.Material.Metal)
	local bowl = part(model, "BrazierBowl", Vector3.new(1.4 * s, 4.2 * s, 4.2 * s), brazier * CFrame.new(0, 4.1 * s, 0) * upright, IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	local coals = decor(part(model, "BrazierCoals", Vector3.new(0.3 * s, 3.4 * s, 3.4 * s), bowl.CFrame * CFrame.new(0.6 * s, 0, 0), RUNE, Enum.Material.Neon, Enum.PartType.Cylinder))
	local fire = Instance.new("Fire")
	fire.Heat = 9
	fire.Size = 5 * s
	fire.Color = RUNE
	fire.SecondaryColor = Color3.fromRGB(255, 90, 40)
	fire.Parent = coals
	local light = Instance.new("PointLight")
	light.Color = RUNE
	light.Range = 22 * s
	light.Brightness = 1.6
	light.Shadows = false
	light.Parent = coals

	-- Two rune stones flanking the dais.
	for side = -1, 1, 2 do
		local stoneCf = origin * CFrame.new(side * 11 * s, 2.4 * s, 4 * s)
		part(model, "RuneStone", Vector3.new(2.2 * s, 7 * s, 1.4 * s), stoneCf * CFrame.new(0, 3.5 * s, 0) * CFrame.Angles(0, math.rad(side * 12), math.rad(side * 3)), DARK_STONE, Enum.Material.Slate)
		local mark = decor(part(model, "RuneMark", Vector3.new(0.8 * s, 3.4 * s, 0.1 * s), stoneCf * CFrame.new(0, 4.2 * s, -0.72 * s) * CFrame.Angles(0, math.rad(side * 12), math.rad(side * 3)), RUNE, Enum.Material.Neon))
		mark.Transparency = 0.2
	end

	-- Invisible trigger with the prompt, and the floating sign above it.
	local trigger = decor(part(model, "ReforgeTrigger", Vector3.new(8 * s, 6 * s, 8 * s), top * CFrame.new(0, 3 * s, 0), RUNE, Enum.Material.SmoothPlastic))
	trigger.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Config.PromptName
	prompt.ActionText = "Reforge"
	prompt.ObjectText = "Runesmith's Anvil"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = trigger

	local anchor = Instance.new("Attachment")
	anchor.Name = "SignAnchor"
	anchor.Position = Vector3.new(0, 9 * s, 0)
	anchor.Parent = trigger
	local board = Instance.new("BillboardGui")
	board.Name = "ReforgeSign"
	board.Size = UDim2.fromOffset(320, 64)
	board.LightInfluence = 0
	board.MaxDistance = 260
	board.Adornee = anchor
	board.Parent = trigger
	local function label(name: string, y: number, h: number, size: number, text: string, color: Color3)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.new(1, 0, 0, h)
		l.Font = Enum.Font.GothamBlack
		l.TextSize = size
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.35
		l.Text = text
		l.Parent = board
	end
	label("Title", 0, 36, 28, "RUNESMITH'S ANVIL", Color3.fromRGB(255, 214, 120))
	label("Subtitle", 36, 24, 16, "Weapon Reforge", Color3.fromRGB(255, 240, 210))

	model.PrimaryPart = trigger
	model.Parent = parent
	return model, prompt
end

function ReforgeService.Forget(player: Player)
	recentRequests[player] = nil
end

function ReforgeService.Init(dependencies: Dependencies)
	deps = dependencies

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local folder = remotes:FindFirstChild("ReforgeRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ReforgeRemotes"
		folder.Parent = remotes
	end
	local request = folder:FindFirstChild("ReforgeRequest") :: RemoteFunction?
	if not request then
		request = Instance.new("RemoteFunction")
		request.Name = "ReforgeRequest"
		request.Parent = folder
	end
	;(request :: RemoteFunction).OnServerInvoke = handle

	Players.PlayerRemoving:Connect(ReforgeService.Forget)
	ReforgeService.BuildStation(Workspace)
end

return ReforgeService
