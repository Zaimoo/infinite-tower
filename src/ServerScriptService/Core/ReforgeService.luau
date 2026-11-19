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
local RunesmithMeshHydrator = require(ReplicatedStorage.Assets.RunesmithMeshHydrator)

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
-- The station: Blender-authored Runesmith Sanctuary built at HubLayout.ReforgeStationCFrame()
-- (chasm rim, mossy-stone & iron-lattice arch bridge, elevated floating platform, concentric
-- rune rings + chains, and the Runesmith's Anvil), paired with smooth walkable colliders.
--------------------------------------------------------------------------------------------------------
local RUNE = Color3.fromRGB(255, 148, 32)
local GOLD_GLOW = Color3.fromRGB(255, 210, 100)
local ARCANE_BLUE = Color3.fromRGB(80, 200, 255)

local HOLE_RADIUS = 22.0
local PLAT_RADIUS = 13.5
local PLAT_TOP_Y = 4.55
local BRIDGE_Z_HUB_END = -27.6
local BRIDGE_Z_HUB_PIER = -23.8
local BRIDGE_Z_PLAT_PIER = -12.4
local BRIDGE_Z_PLAT_END = -9.6

local function bridgeDeckY(z: number): number
	if z <= BRIDGE_Z_HUB_PIER then
		local tIn = math.clamp((z - BRIDGE_Z_HUB_END) / (BRIDGE_Z_HUB_PIER - BRIDGE_Z_HUB_END), 0, 1)
		return 0.08 + 0.92 * tIn
	end
	if z >= BRIDGE_Z_PLAT_PIER then
		return PLAT_TOP_Y
	end
	local t = (z - BRIDGE_Z_HUB_PIER) / (BRIDGE_Z_PLAT_PIER - BRIDGE_Z_HUB_PIER)
	return 1.00 + (PLAT_TOP_Y - 1.00) * t + 1.05 * math.sin(math.pi * t)
end

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

local function collider(parent: Instance, name: string, size: Vector3, cf: CFrame, shape: Enum.PartType?): Part
	local p = part(parent, name, size, cf, Color3.new(0.5, 0.5, 0.5), Enum.Material.SmoothPlastic, shape)
	p.Transparency = 1
	p.CastShadow = false
	return p
end

local function decor(p: Part): Part
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
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

	-- 1. Visual Blender sanctuary meshes (imported MeshParts -> MeshId -> EditableMesh fallback)
	local visualFolder = Instance.new("Folder")
	visualFolder.Name = "SanctuaryMeshes"
	visualFolder.Parent = model
	RunesmithMeshHydrator.BuildSanctuary(visualFolder, origin, s)

	-- 2. Smooth walkable & safety colliders matching the Blender geometry
	local colFolder = Instance.new("Folder")
	colFolder.Name = "SanctuaryColliders"
	colFolder.Parent = model

	local upright = CFrame.Angles(0, 0, math.rad(90))
	local deckHeight = 1.6 * s
	collider(colFolder, "PlatformDeckCollider", Vector3.new(deckHeight, PLAT_RADIUS * 2 * s, PLAT_RADIUS * 2 * s), origin * CFrame.new(0, (PLAT_TOP_Y - 0.8) * s, 0) * upright, Enum.PartType.Cylinder)
	collider(colFolder, "AnvilCollider", Vector3.new(6.8 * s, 4.4 * s, 4.6 * s), origin * CFrame.new(-0.3 * s, (PLAT_TOP_Y + 2.2) * s, 0))

	local bridgeSteps = 14
	for i = 1, bridgeSteps do
		local z0 = BRIDGE_Z_HUB_END + (BRIDGE_Z_PLAT_END - BRIDGE_Z_HUB_END) * ((i - 1) / bridgeSteps)
		local z1 = BRIDGE_Z_HUB_END + (BRIDGE_Z_PLAT_END - BRIDGE_Z_HUB_END) * (i / bridgeSteps)
		local y0, y1 = bridgeDeckY(z0), bridgeDeckY(z1)
		local dz, dy = z1 - z0, y1 - y0
		local segLen = math.sqrt(dz * dz + dy * dy) + 0.14
		local pitch = math.atan2(dy, dz)
		local deckCf = origin * CFrame.new(0, ((y0 + y1) * 0.5 - 0.31) * s, ((z0 + z1) * 0.5) * s) * CFrame.Angles(-pitch, 0, 0)
		collider(colFolder, "BridgeRampCollider_" .. i, Vector3.new(5.6 * s, 0.62 * s, segLen * s), deckCf)
		for _, side in { -1, 1 } do
			collider(colFolder, "BridgeRailCollider_" .. i .. "_" .. (if side < 0 then "L" else "R"), Vector3.new(0.6 * s, 3.6 * s, segLen * s), deckCf * CFrame.new(side * 3.15 * s, 1.9 * s, 0))
		end
	end

	-- Ring of chasm wall colliders around the R = 22 hole (leaving the -Z bridge throat open)
	local rimSegments = 16
	local rimStepAngle = math.tau / rimSegments
	local rimChord = 2 * HOLE_RADIUS * math.tan(rimStepAngle * 0.5) + 1.0
	for i = 0, rimSegments - 1 do
		local ang = i * rimStepAngle
		local rx = math.sin(ang) * (HOLE_RADIUS + 0.5)
		local rz = -math.cos(ang) * (HOLE_RADIUS + 0.5)
		if not (rz < -HOLE_RADIUS * 0.72 and math.abs(rx) < 3.6) then
			local wallCf = CFrame.lookAt((origin * CFrame.new(rx * s, -8.5 * s, rz * s)).Position, (origin * CFrame.new(0, -8.5 * s, 0)).Position)
			collider(colFolder, "ChasmWallCollider_" .. i, Vector3.new(rimChord * s, 17 * s, 1.4 * s), wallCf)
		end
	end

	-- 3. Ambient forge & arcane rune lights + anvil molten ember particles
	local forgeAnchor = decor(part(model, "ForgeEmberAnchor", Vector3.new(1.5 * s, 0.5 * s, 1.5 * s), origin * CFrame.new(0, (PLAT_TOP_Y + 2.0) * s, -1.6 * s), RUNE, Enum.Material.SmoothPlastic))
	forgeAnchor.Transparency = 1
	local forgeLight = Instance.new("PointLight")
	forgeLight.Color = RUNE
	forgeLight.Range = 24 * s
	forgeLight.Brightness = 1.8
	forgeLight.Shadows = false
	forgeLight.Parent = forgeAnchor

	local embers = Instance.new("ParticleEmitter")
	embers.Name = "AnvilForgeEmbers"
	embers.Texture = "rbxassetid://243660364"
	embers.Color = ColorSequence.new(GOLD_GLOW, RUNE)
	embers.LightEmission = 1
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18 * s),
		NumberSequenceKeypoint.new(0.6, 0.12 * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	embers.Lifetime = NumberRange.new(1.0, 2.2)
	embers.Rate = 10
	embers.Speed = NumberRange.new(1.2, 3.0)
	embers.SpreadAngle = Vector2.new(45, 45)
	embers.Acceleration = Vector3.new(0, 2.2, 0)
	embers.Parent = forgeAnchor

	local ringAnchor = decor(part(model, "RingGlowAnchor", Vector3.new(1, 1, 1), origin * CFrame.new(0, 24.5 * s, 0), ARCANE_BLUE, Enum.Material.SmoothPlastic))
	ringAnchor.Transparency = 1
	local ringLight = Instance.new("PointLight")
	ringLight.Color = ARCANE_BLUE
	ringLight.Range = 36 * s
	ringLight.Brightness = 1.6
	ringLight.Shadows = false
	ringLight.Parent = ringAnchor

	-- 4. Invisible trigger with the [F] prompt and floating sign over the elevated anvil
	local trigger = decor(part(model, "ReforgeTrigger", Vector3.new(9 * s, 6 * s, 9 * s), origin * CFrame.new(0, (PLAT_TOP_Y + 3.2) * s, 0), RUNE, Enum.Material.SmoothPlastic))
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
	anchor.Position = Vector3.new(0, 6.2 * s, 0)
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
