--!strict
-- Hub Raid Portal (docs/raid-boss-plan.md §6). Built once by RaidService at HubLayout.RaidPortalCFrame():
-- the Blender meshes when RaidPortalAssets has MeshIds, otherwise a part version of the same design.
-- Neon pieces carry a RaidPortalRole attribute so SetState can recolour them for the next boss.
-- The client (RaidPortalController) spins the shards and pulses the vortex; the server owns the prompt.
local RS = game:GetService("ReplicatedStorage")
local Assets = require(RS.Shared.Config.RaidPortalAssets)
local HubLayout = require(RS.Shared.Config.HubLayout)

local Kit = {}

local STONE = Color3.fromRGB(22, 20, 28)
local STONE_MID = Color3.fromRGB(64, 60, 74)
local GOLD = Color3.fromRGB(222, 180, 86)
local BONE = Color3.fromRGB(214, 200, 170)
local DORMANT = Color3.fromRGB(70, 40, 90)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?, role: string?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.CanCollide = role == nil and material ~= Enum.Material.Neon
	p.CastShadow = role == nil
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	if role then p:SetAttribute("RaidPortalRole", role) end
	p.Parent = parent
	return p
end

-- Points on the pointed arch's centreline (portal-local x, y), legs excluded.
local function archPoints(a: number, spring: number, R: number, n: number): { Vector2 }
	local cx = -a + R
	local apexH = math.sqrt(R * R - (R - a) ^ 2)
	local a0, a1 = math.pi, math.atan2(apexH, a - R)
	local left = {}
	for i = 0, n do
		local t = a0 + (a1 - a0) * i / n
		table.insert(left, Vector2.new(cx + R * math.cos(t), spring + R * math.sin(t)))
	end
	local out = table.clone(left)
	for i = #left - 1, 1, -1 do table.insert(out, Vector2.new(-left[i].X, left[i].Y)) end
	return out
end

local function buildParts(model: Model, origin: CFrame, s: number)
	local function at(x: number, y: number, z: number): CFrame return origin * CFrame.new(x * s, y * s, z * s) end
	local up = CFrame.Angles(0, 0, math.rad(90))
	-- dais
	for i, tier in { { 15.5, 0.45, 0.9, STONE }, { 13.6, 1.3, 0.8, STONE_MID }, { 11.8, 2.05, 0.7, STONE } } do
		part(model, "DaisTier" .. i, Vector3.new(tier[3], tier[1] * 2, tier[1] * 2) * s, at(0, tier[2], 0) * up, tier[4], Enum.Material.Slate, Enum.PartType.Cylinder)
	end
	part(model, "RuneRing", Vector3.new(0.12, 21, 21) * s, at(0, Assets.DaisTop + 0.02, 0) * up, DORMANT, Enum.Material.Neon, Enum.PartType.Cylinder, "RUNES")
	part(model, "RuneRingInner", Vector3.new(0.14, 20, 20) * s, at(0, Assets.DaisTop + 0.03, 0) * up, STONE, Enum.Material.Slate, Enum.PartType.Cylinder)
	-- arch legs and capitals
	local a, spring, R = Assets.ArchHalfSpan, Assets.Spring, Assets.ArchRadius
	for _, side in { -1, 1 } do
		part(model, "PillarBase", Vector3.new(5, 2.2, 5.6) * s, at(side * a, Assets.DaisTop + 1.1, 0), STONE_MID)
		part(model, "PillarLeg", Vector3.new(3.5, spring - Assets.DaisTop, 4.2) * s, at(side * a, (spring + Assets.DaisTop) / 2, 0), STONE)
		part(model, "Capital", Vector3.new(5.2, 0.6, 5.8) * s, at(side * a, spring + 0.3, 0), GOLD, Enum.Material.Metal)
		for k, y in { 5.5, 8.0, 10.5 } do
			part(model, "LegRune" .. k, Vector3.new(0.5, 1.1, 0.2) * s, at(side * a, y, -2.15), DORMANT, Enum.Material.Neon, nil, "RUNES")
		end
		-- horns: three tapering segments sweeping up and out
		local hornPts = { Vector3.new(side * (a + 0.8), spring + 7.5, 0), Vector3.new(side * (a + 3.2), spring + 9.5, -0.4),
			Vector3.new(side * (a + 5.4), spring + 13, -1.0), Vector3.new(side * (a + 5.6), spring + 17, -1.2), Vector3.new(side * (a + 4.0), spring + 19.6, -0.8) }
		for k = 1, #hornPts - 1 do
			local p0, p1 = hornPts[k], hornPts[k + 1]
			local mid = (p0 + p1) / 2
			local r = 1.5 - k * 0.3
			local seg = part(model, "Horn" .. k, Vector3.new((p1 - p0).Magnitude + 0.4, r * 2, r * 2) * s, origin * CFrame.lookAt(mid * s, p1 * s) * CFrame.Angles(0, math.rad(90), 0), BONE, Enum.Material.Slate, Enum.PartType.Cylinder)
			seg.CanCollide = false
		end
		-- obelisk with a crystal crown
		part(model, "Obelisk", Vector3.new(2.6, 13, 2.6) * s, at(side * 15.2, Assets.DaisTop + 6.5, 2.0), STONE)
		part(model, "ObeliskCap", Vector3.new(1.4, 1.6, 1.4) * s, at(side * 15.2, Assets.DaisTop + 13.8, 2.0), GOLD, Enum.Material.Metal)
		part(model, "ObeliskCrystal", Vector3.new(1.2, 3.4, 1.2) * s, at(side * 15.2, Assets.DaisTop + 17.8, 2.0) * CFrame.Angles(0, math.rad(45), 0), DORMANT, Enum.Material.Neon, nil, "SHARDS")
		-- brazier
		part(model, "Brazier", Vector3.new(1.1, 3.2, 3.2) * s, at(side * 7.6, Assets.DaisTop + 3.1, -6.4) * up, Color3.fromRGB(70, 70, 80), Enum.Material.Metal, Enum.PartType.Cylinder)
		part(model, "BrazierFire", Vector3.new(1.6, 2.6, 1.6) * s, at(side * 7.6, Assets.DaisTop + 4.6, -6.4), Color3.fromRGB(255, 118, 36), Enum.Material.Neon, Enum.PartType.Ball, "FIRE")
	end
	-- the arch: box segments along the lancet curve, with gold trim and runes on the front face
	local pts = archPoints(a, spring, R, 7)
	for i = 1, #pts - 1 do
		local p0, p1 = pts[i], pts[i + 1]
		local mid = (p0 + p1) / 2
		local len = (p1 - p0).Magnitude + 0.6
		local cf = origin * CFrame.new(mid.X * s, mid.Y * s, 0) * CFrame.Angles(0, 0, math.atan2(p1.Y - p0.Y, p1.X - p0.X))
		part(model, "ArchStone", Vector3.new(len, 3.5, 4.2) * s, cf, STONE)
		part(model, "ArchTrim", Vector3.new(len, 0.4, 4.6) * s, cf * CFrame.new(0, 1.9 * s, 0), GOLD, Enum.Material.Metal)
		part(model, "ArchRune", Vector3.new(0.9, 0.5, 0.2) * s, cf * CFrame.new(0, 0, -2.2 * s), DORMANT, Enum.Material.Neon, nil, "RUNES")
	end
	-- skull keystone with glowing eyes and a gold crown
	local apex = Assets.Apex
	part(model, "Skull", Vector3.new(4.4, 4.6, 4.0) * s, at(0, apex + 1.0, -1.2), BONE, Enum.Material.Slate, Enum.PartType.Ball)
	part(model, "SkullJaw", Vector3.new(2.4, 1.3, 1.6) * s, at(0, apex - 0.9, -2.1), Color3.fromRGB(150, 134, 108))
	for _, side in { -1, 1 } do
		part(model, "SkullEye", Vector3.new(0.65, 0.65, 0.65) * s, at(side * 0.8, apex + 0.65, -3.15), DORMANT, Enum.Material.Neon, Enum.PartType.Ball, "RUNES")
	end
	part(model, "SkullCrown", Vector3.new(0.5, 3.6, 3.6) * s, at(0, apex + 3.2, -1.0) * up, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	-- vortex membrane: a lower panel plus a disc in the arch head
	local inner = a - 1.75
	part(model, "VortexPanel", Vector3.new(inner * 2, spring - Assets.DaisTop + 2, 0.3) * s, at(0, (spring + Assets.DaisTop) / 2 + 1, 0), DORMANT, Enum.Material.Neon, nil, "VORTEX")
	part(model, "VortexHead", Vector3.new(0.3, inner * 2, inner * 2) * s, at(0, spring + 2.5, 0) * CFrame.Angles(0, math.rad(90), 0), DORMANT, Enum.Material.Neon, Enum.PartType.Cylinder, "VORTEX")
	-- floating shards
	local rng = Random.new(7)
	for i = 1, 8 do
		local ang = math.rad(i * 45 + 10)
		local r = 16 + rng:NextNumber(-1, 1.5)
		local p = Vector3.new(math.cos(ang) * r, Assets.ShardPivot.Y + math.sin(ang) * r * 0.85, rng:NextNumber(-3, 3))
		if p.Y < Assets.DaisTop + 3 then p = Vector3.new(p.X, Assets.DaisTop + 3 + rng:NextNumber(0, 2), p.Z) end
		part(model, "Shard", Vector3.new(0.9, rng:NextNumber(1.8, 2.8), 0.9) * s, at(p.X, p.Y, p.Z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), math.rad(45), rng:NextNumber(-0.4, 0.4)), DORMANT, Enum.Material.Neon, nil, "SHARDS")
	end
end

local function buildMeshes(model: Model, origin: CFrame, s: number)
	for _, piece in Assets.Pieces do
		local m = Instance.new("MeshPart")
		m.Name = piece.Name
		m.MeshId = piece.MeshId
		if piece.TextureId and piece.TextureId ~= "" then m.TextureID = piece.TextureId end
		m.Size = piece.Size * s
		m.CFrame = origin * CFrame.new(piece.Offset * s)
		m.Anchored = true
		m.CanCollide = piece.Role == "FRAME"
		if piece.Role ~= "FRAME" then
			m.Material = Enum.Material.Neon
			m.Color = if piece.Role == "FIRE" then Color3.fromRGB(255, 118, 36) else DORMANT
			m.CastShadow = false
			m:SetAttribute("RaidPortalRole", piece.Role)
		end
		m.Parent = model
	end
end

export type Portal = { Model: Model, Trigger: BasePart, Prompt: ProximityPrompt, Title: TextLabel, Status: TextLabel }

function Kit.Build(parent: Instance): Portal
	local old = parent:FindFirstChild("RaidPortal")
	if old then old:Destroy() end
	local s = HubLayout.RaidPortal.Scale
	local origin = HubLayout.RaidPortalCFrame()
	local model = Instance.new("Model")
	model.Name = "RaidPortal"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- the countdown should be visible across the hub
	if Assets.HasMeshes() then buildMeshes(model, origin, s) else buildParts(model, origin, s) end
	model:SetAttribute("ShardPivot", origin * (Assets.ShardPivot * s))

	local trigger = Instance.new("Part")
	trigger.Name = "RaidTrigger"
	trigger.Size = Assets.TriggerSize * s
	trigger.CFrame = origin * CFrame.new(Assets.TriggerOffset * s)
	trigger.Transparency = 1
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.CanTouch = false
	trigger.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterRaid"
	prompt.ActionText = "Enter Raid"
	prompt.ObjectText = "Raid Portal"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = trigger

	local anchor = Instance.new("Attachment")
	anchor.Name = "BillboardAnchor"
	anchor.Position = Vector3.new(0, (Assets.Apex + 9) * s - Assets.TriggerOffset.Y * s, 0)
	anchor.Parent = trigger
	local board = Instance.new("BillboardGui")
	board.Name = "RaidBoard"
	board.Size = UDim2.fromOffset(340, 92)
	board.LightInfluence = 0
	board.MaxDistance = 900
	board.Adornee = anchor
	board.AlwaysOnTop = false
	board.Parent = trigger
	local function label(name: string, y: number, h: number, size: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.new(1, 0, 0, h)
		l.Font = Enum.Font.GothamBlack
		l.TextSize = size
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.35
		l.Parent = board
		return l
	end
	local title = label("Title", 0, 46, 26, Color3.fromRGB(255, 225, 160))
	title.TextWrapped = true
	local status = label("Status", 48, 40, 22, Color3.new(1, 1, 1))
	model.Parent = parent
	return { Model = model, Trigger = trigger, Prompt = prompt, Title = title, Status = status }
end

-- Recolour the glowing pieces: dormant while calm, the boss's accent when the raid opens.
function Kit.SetGlow(portal: Portal, color: Color3, open: boolean)
	for _, d in portal.Model:GetDescendants() do
		if d:IsA("BasePart") then
			local role = d:GetAttribute("RaidPortalRole")
			if role == "RUNES" or role == "SHARDS" then
				d.Color = color
			elseif role == "VORTEX" then
				d.Color = if open then color else DORMANT
				d.Transparency = if open then 0.15 else 0.55
			end
		end
	end
	portal.Model:SetAttribute("RaidOpen", open)
	portal.Model:SetAttribute("RaidAccent", color)
end

return Kit
