--!strict
local Rigs = require(script.Parent.TowerEnemyRigs)
local Clips = require(script.Parent.TowerEnemyClips)
local EnemyAnimator = require(script.Parent.EnemyAnimator)
local RaidRigs = require(script.Parent.RaidBossRigs)
local RigFactory = require(script.Parent.EnemyRigFactory)
local Config = require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat)
local Controller = {}
local effects: { [string]: any } = {}
local MAX_EFFECTS = 12
-- Support kits (Phase D) draw in their own calm colours, never the orange/red of a danger telegraph.
local KIT_COLORS = {
	MEND = Color3.fromRGB(120, 245, 150),
	WARD = Color3.fromRGB(110, 210, 255),
	ROUSE = Color3.fromRGB(255, 196, 80),
}
local SHIELD_FLAG, ROUSE_FLAG, AFFIX_FLAG = 8, 16, 32
local AFFIX_COLOR = Color3.fromRGB(255, 120, 70)

local function clearEffect(key: string)
	local effect = effects[key]
	if effect then
		effect.Model:Destroy()
		effects[key] = nil
	end
end

local function groundPart(parent: Instance, size: Vector3, cf: CFrame, color: Color3, alpha: number): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = alpha
	p.CastShadow = false
	p.Parent = parent
	return p
end

function Controller.Clear()
	for key in pairs(effects) do
		clearEffect(key)
	end
end

function Controller.Attach(model: Model, root: BasePart, enemyId: string)
	local clips = assert(Clips[enemyId], "Missing enemy clips: " .. enemyId)
	for _, slot in Config.Get(enemyId).RequiredSlots do
		assert(clips[slot], "Missing enemy clip " .. enemyId .. "/" .. slot)
	end
	-- Raid bosses use their Blender meshes once uploaded (RaidBossAssets); until then the stand-in rig.
	if RaidRigs.BossFor(enemyId) then
		return RaidRigs.Build(model, root, enemyId)
	end
	return RigFactory.Build(model, root, enemyId) -- remodelled template, else the part rig
end

function Controller.Action(node: any, action: any, origin: Vector3, now: number)
	if not node.EnemyRig or node.DeathAt then return end
	node.EnemyAction = action
	local due = action.StartServerTime + action.ImpactOffsetSeconds
	local key = tostring(node.NetId) .. ":" .. action.ActionSequence
	node.EnemyEffectKey = key
	if now >= due then return end -- late observers seek pose without a fresh warning or impact burst
	local n = 0
	for _ in pairs(effects) do n += 1 end
	if n >= MAX_EFFECTS then return end

	local model = Instance.new("Model")
	model.Name = "EnemyWarning_" .. key
	local worldOrigin = origin + action.Origin + Vector3.new(0, .13, 0)
	local worldAim = origin + action.Aim + Vector3.new(0, .13, 0)
	local spec = Config.Get(action.EnemyId)
	local kitColor = spec and spec.Support and KIT_COLORS[spec.Support]
	local color = if kitColor then kitColor
		elseif action.Shape == "PROJECTILE" then Color3.fromRGB(168, 120, 255)
		elseif action.Shape == "SELF_DISC" then Color3.fromRGB(255, 92, 68)
		else Color3.fromRGB(240, 136, 56)

	local progressDisc: Part? = nil
	local projectileOrb: Part? = nil

	if action.Shape == "ALLY_BEAM" then
		-- A thin rising beam from the caster to the ally it is mending or warding, and a ring under the ally.
		local from, to = worldOrigin + Vector3.new(0, 3, 0), worldAim + Vector3.new(0, 3, 0)
		local length = math.max(.5, (to - from).Magnitude)
		groundPart(model, Vector3.new(.3, .3, length), CFrame.lookAt((from + to) / 2, to), color, .25)
		for i = 0, 11 do
			local a = i * math.pi / 6
			groundPart(model, Vector3.new(1.4, .08, .2), CFrame.new(worldAim + Vector3.new(math.sin(a) * 3, 0, math.cos(a) * 3)) * CFrame.Angles(0, a, 0), color, .2)
		end
	elseif action.Shape == "ALLY_AURA" then
		-- A ring at the aura's edge: allies inside it are roused.
		local radius = action.Radius or 18
		for i = 0, 23 do
			local a = i * math.pi / 12
			groundPart(model, Vector3.new(radius * .27, .08, .22), CFrame.new(worldOrigin + Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)) * CFrame.Angles(0, a, 0), color, .25)
		end
	elseif action.Shape == "ARC" then
		local cf = CFrame.new(worldOrigin) * CFrame.Angles(0, action.Yaw, 0)
		for i = 0, 10 do
			local a = -math.pi * .47 + i * math.pi * .94 / 10
			local pos = Vector3.new(math.sin(a) * action.Range, 0, -math.cos(a) * action.Range)
			groundPart(model, Vector3.new(action.Range * .27, .09, .24), cf * CFrame.new(pos) * CFrame.Angles(0, -a, 0), color, .12)
		end
		for _, side in { -1, 1 } do
			groundPart(model, Vector3.new(.18, .09, action.Range), cf * CFrame.Angles(0, side * math.pi * .47, 0) * CFrame.new(0, 0, -action.Range / 2), color, .3)
		end
	elseif action.Shape == "PROJECTILE" then
		local delta = Vector3.new(worldAim.X - worldOrigin.X, 0, worldAim.Z - worldOrigin.Z)
		local len = math.max(.5, delta.Magnitude)
		local mid = worldOrigin:Lerp(worldAim, .5)
		local dirCF = CFrame.lookAt(mid, mid + (delta.Magnitude > .01 and delta.Unit or Vector3.new(0, 0, -1)))
		local radius = math.max(1.5, action.Radius or 2.4)
		groundPart(model, Vector3.new(radius * 1.4, .06, len), dirCF, color, .78)
		for _, side in { -1, 1 } do
			groundPart(model, Vector3.new(.16, .09, len), dirCF * CFrame.new(side * radius * .7, 0, 0), color, .22)
		end
		local aimDisc = groundPart(model, Vector3.new(.08, radius * 2, radius * 2), CFrame.new(worldAim) * CFrame.Angles(0, 0, math.pi / 2), color, .65)
		aimDisc.Shape = Enum.PartType.Cylinder
		local orb = groundPart(model, Vector3.new(1.3, 1.3, 1.3), CFrame.new(worldOrigin + Vector3.new(0, 3.1, 0)), color, .08)
		orb.Shape = Enum.PartType.Ball
		projectileOrb = orb
	else
		local radius = action.Radius
		local disc = groundPart(model, Vector3.new(.07, radius * 2, radius * 2), CFrame.new(worldAim) * CFrame.Angles(0, 0, math.pi / 2), color, .86)
		disc.Shape = Enum.PartType.Cylinder
		local fill = groundPart(model, Vector3.new(.09, .4, .4), CFrame.new(worldAim) * CFrame.Angles(0, 0, math.pi / 2), color, .58)
		fill.Shape = Enum.PartType.Cylinder
		progressDisc = fill
		for i = 0, 11 do
			local a = i * math.pi / 6
			groundPart(model, Vector3.new(radius * .51, .1, .22), CFrame.new(worldAim + Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)) * CFrame.Angles(0, a, 0), color, .14)
		end
	end

	model.Parent = workspace.ClientVisualEntities
	effects[key] = {
		Model = model,
		EndAt = due,
		Started = action.StartServerTime,
		ReleaseAt = action.StartServerTime + (action.WindupSeconds or (action.ImpactOffsetSeconds * .65)),
		Due = due,
		Radius = action.Radius or 2.4,
		ProgressDisc = progressDisc,
		ProjectileOrb = projectileOrb,
		StartPos = worldOrigin + Vector3.new(0, 3.1, 0),
		EndPos = worldAim + Vector3.new(0, 2.2, 0),
	}
end

function Controller.Cancel(node: any)
	if node.EnemyEffectKey then clearEffect(node.EnemyEffectKey) end
	node.EnemyAction = nil
end

function Controller.Contact(node: any, action: any, origin: Vector3, now: number)
	local key = tostring(node.NetId) .. ":" .. action.ActionSequence
	clearEffect(key)
	if now - (action.StartServerTime + action.ImpactOffsetSeconds) > .4 then return end
	local burstColor = if action.Shape == "PROJECTILE" then Color3.fromRGB(190, 145, 255) else Color3.fromRGB(174, 239, 109)
	local p = groundPart(workspace.ClientVisualEntities, Vector3.new(.2, 2, 2), CFrame.new(origin + action.Aim + Vector3.new(0, .2, 0)) * CFrame.Angles(0, 0, math.pi / 2), burstColor, .25)
	p.Shape = Enum.PartType.Cylinder
	local diameter = math.max(4, (action.Radius or 2) * 2)
	game:GetService("TweenService"):Create(p, TweenInfo.new(.3), { Size = Vector3.new(.1, diameter, diameter), Transparency = 1 }):Play()
	game:GetService("Debris"):AddItem(p, .35)
end

function Controller.Hit(node: any, now: number)
	if node and node.EnemyRig and not node.DeathAt then node.HitAt = now end
end

function Controller.Death(node: any, at: number)
	Controller.Cancel(node)
	node.DeathAt = at
	node.DeathEnd = at + 1.6
	if node.RootPart then
		local bb = node.RootPart:FindFirstChild("UnitBillboard")
		if bb and bb:IsA("BillboardGui") then bb.Enabled = false end
	end
	for _, p in node.EnemyRig.Parts do p.CanQuery = false end
end

-- A WARD shield bubble and a ROUSE glow, shown while the snapshot flags say so (Phase D).
local function supportGlow(node: any, rig: any)
	local flags = node.Flags or 0
	local shielded = bit32.band(flags, SHIELD_FLAG) ~= 0 and not node.DeathAt
	local roused = bit32.band(flags, ROUSE_FLAG) ~= 0 and not node.DeathAt
	if (shielded or roused) and not rig.SupportBubble then
		local size = math.max(rig.Spec.Width or 5, rig.Spec.Height or 6) + 2
		local bubble = Instance.new("Part")
		bubble.Name = "SupportBubble"
		bubble.Shape = Enum.PartType.Ball
		bubble.Size = Vector3.new(size, size, size)
		bubble.Material = Enum.Material.ForceField
		bubble.CanCollide, bubble.CanTouch, bubble.CanQuery, bubble.CastShadow = false, false, false, false
		bubble.Massless = true
		bubble.CFrame = rig.Root.CFrame * CFrame.new(0, (rig.Spec.Height or 6) / 2 - (rig.Spec.RootHeight or 3), 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = rig.Root, bubble
		weld.Parent = bubble
		local glow = Instance.new("PointLight")
		glow.Range, glow.Brightness = 10, 1.2
		glow.Parent = bubble
		bubble.Parent = rig.Model
		rig.SupportBubble = bubble
	end
	local bubble = rig.SupportBubble
	if bubble then
		bubble.Transparency = if shielded or roused then .35 else 1
		bubble.Color = if shielded then KIT_COLORS.WARD else KIT_COLORS.ROUSE
		local light = bubble:FindFirstChildWhichIsA("PointLight")
		if light then
			light.Enabled = shielded or roused
			light.Color = bubble.Color
		end
	end
end

-- An affixed Elite (Phase F) stands in a slowly turning crimson-gold ring, so it reads at a distance.
local function affixGlow(node: any, rig: any, now: number)
	local affixed = bit32.band(node.Flags or 0, AFFIX_FLAG) ~= 0 and not node.DeathAt
	if affixed and not rig.AffixRing then
		local radius = math.max(rig.Spec.Width or 5, rig.Spec.Depth or 5) * 0.8 + 1.5
		local ring = Instance.new("Part")
		ring.Name = "AffixRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.15, radius * 2, radius * 2)
		ring.Material = Enum.Material.Neon
		ring.Color = AFFIX_COLOR
		ring.CanCollide, ring.CanTouch, ring.CanQuery, ring.CastShadow = false, false, false, false
		ring.Massless = true
		local weld = Instance.new("WeldConstraint")
		ring.CFrame = rig.Root.CFrame * CFrame.new(0, 0.1 - (rig.Spec.RootHeight or 3), 0) * CFrame.Angles(0, 0, math.pi / 2)
		weld.Part0, weld.Part1 = rig.Root, ring
		weld.Parent = ring
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = AFFIX_COLOR, 14, 1.6
		light.Parent = ring
		ring.Parent = rig.Model
		rig.AffixRing = ring
	end
	if rig.AffixRing then
		rig.AffixRing.Transparency = if affixed then 0.55 + 0.2 * math.sin(now * 3) else 1
		local light = rig.AffixRing:FindFirstChildWhichIsA("PointLight")
		if light then light.Enabled = affixed end
	end
end

function Controller.Step(node: any, dt: number, now: number)
	local rig = node.EnemyRig
	if not rig then return end
	supportGlow(node, rig)
	affixGlow(node, rig, now)
	local anim = rig.Animator
	if not anim then
		anim = EnemyAnimator.new(rig, node.NetId)
		rig.Animator = anim
	end
	local action = node.EnemyAction
	if action and not node.DeathAt and now - action.StartServerTime >= action.ImpactOffsetSeconds + action.RecoverySeconds then
		Controller.Cancel(node)
		action = nil
	end
	local input = rig.AnimInput
	if not input then
		input = {}
		rig.AnimInput = input
	end
	input.Moved = (node.CurrentPos - (rig.LastPos or node.CurrentPos)).Magnitude
	-- Walk/idle follows the snapshot glide speed (EntityRenderer moves enemies at a constant speed between
	-- 5 Hz snapshots), held through the segment plus EnemyAnimator.MOVE_GRACE, so late snapshots do not drop to idle.
	local segStart = node.SegStart
	input.Speed = if segStart and os.clock() - segStart <= (node.SegDuration or 0.2) then node.SegSpeed or 0 else 0
	rig.LastPos = node.CurrentPos
	input.Action = action
	input.HitAt = node.HitAt
	input.DeathAt = node.DeathAt
	input.BornAt = node.BornAt
	input.AwakenSeconds = 2.2
	input.Far = node.AnimFar == true
	anim:Step(now, input)
	if node.HitAt and now - node.HitAt < .15 then
		if node.Highlight then
			node.Highlight.FillColor = Color3.fromRGB(235, 255, 190)
			node.Highlight.FillTransparency = .45
		end
	elseif node.Highlight then
		node.Highlight.FillTransparency = 1
	end
	if node.DeathAt then
		local alpha = math.clamp((now - node.DeathAt - 1.1) / .5, 0, 1)
		for _, p in rig.Parts do p.Transparency = alpha end
	end
end

function Controller.StepEffects(now: number)
	for key, effect in pairs(effects) do
		if now >= effect.EndAt then
			clearEffect(key)
		else
			local total = math.max(.05, effect.Due - effect.Started)
			local progress = math.clamp((now - effect.Started) / total, 0, 1)
			if effect.ProgressDisc then
				local d = math.max(.4, effect.Radius * 2 * progress)
				effect.ProgressDisc.Size = Vector3.new(.09, d, d)
			end
			if effect.ProjectileOrb then
				if now < effect.ReleaseAt then
					local charge = math.clamp((now - effect.Started) / math.max(.05, effect.ReleaseAt - effect.Started), .25, 1)
					local s = 1.3 * charge
					effect.ProjectileOrb.Size = Vector3.new(s, s, s)
					effect.ProjectileOrb.CFrame = CFrame.new(effect.StartPos)
				else
					local flightAlpha = math.clamp((now - effect.ReleaseAt) / math.max(.05, effect.Due - effect.ReleaseAt), 0, 1)
					effect.ProjectileOrb.Size = Vector3.new(1.4, 1.4, 1.4)
					effect.ProjectileOrb.CFrame = CFrame.new(effect.StartPos:Lerp(effect.EndPos, flightAlpha))
				end
			end
		end
	end
end

return Controller
