--!strict
-- Tower portals (Phase H): the Sanctuary travel portals and the boss Ascend / Rerun portals share one
-- design, modelled in Blender (Shared/Config/TowerPortalAssets). Each biome tints it: stone from the
-- biome's trim colour, gold warmed by its accent, runes and vortex in the portal's own glow colour.
-- Until the meshes' MeshIds are filled in, the same design is built from parts.
local CollectionService = game:GetService("CollectionService")
local Assets = require(game.ReplicatedStorage.Shared.Config.TowerPortalAssets)

local Kit = {}

export type Options = {
	Name: string, -- model name
	TriggerName: string?, -- the trigger part's name (travel portals keep PREVIOUS / NEXT / SELECTOR / HUB)
	Scale: number?,
	Glow: Color3, -- runes, vortex and light
	Stone: Color3,
	Gold: Color3,
	StoneMaterial: Enum.Material?,
	Dormant: boolean?, -- frame only: dark centre, no light (Previous on floor 1, Next on floor 50)
}

local GOLD = Color3.fromRGB(218, 178, 88)

-- The palette a biome theme (TowerRoomBuilder) gives a portal.
function Kit.Palette(theme: any, glow: Color3?): (Color3, Color3, Color3)
	local stone = (theme.TrimColor :: Color3):Lerp(Color3.fromRGB(150, 146, 160), 0.25)
	local gold = GOLD:Lerp(theme.AccentColor, 0.25)
	return stone, gold, glow or theme.LightColor
end

local function basePart(parent: Instance, name: string, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function roleStyle(role: string, o: Options): (Color3, Enum.Material, number)
	if role == "STONE" then return o.Stone, o.StoneMaterial or Enum.Material.Slate, 0 end
	if role == "GOLD" then return o.Gold, Enum.Material.Metal, 0 end
	if role == "RUNES" then
		return if o.Dormant then o.Glow:Lerp(Color3.new(0, 0, 0), 0.7) else o.Glow, if o.Dormant then Enum.Material.SmoothPlastic else Enum.Material.Neon, 0
	end
	return o.Glow, Enum.Material.Neon, if o.Dormant then 1 else 0.35
end

-- The Blender meshes, one SpecialMesh part per material.
local function buildMeshes(model: Model, base: CFrame, s: number, o: Options)
	for _, piece in Assets.Pieces do
		local color, material, transparency = roleStyle(piece.Role, o)
		local p = basePart(model, piece.Name, color, material)
		p.Size = piece.Size * s
		p.CFrame = base * CFrame.new(piece.Offset * s)
		p.Transparency = transparency
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = piece.MeshId
		-- A flat mesh (the vortex disc) has no depth to scale; keep that axis at 1.
		local native = piece.MeshSize :: Vector3
		local function axis(want: number, have: number): number
			return if have > 0.01 then want / have else 1
		end
		mesh.Scale = Vector3.new(axis(piece.Size.X * s, native.X), axis(piece.Size.Y * s, native.Y), axis(piece.Size.Z * s, native.Z))
		mesh.Parent = p
		if piece.Role == "VORTEX" then
			-- The disc is a single-sided plane: a mirrored copy shows it from behind too.
			local back = p:Clone()
			back.Name = piece.Name .. "Back"
			back.CFrame = p.CFrame * CFrame.Angles(0, math.pi, 0)
			back.Parent = model
		end
	end
end

-- The same design from parts: segmented stone ring with a keystone, gold rims, runes, a stepped
-- plinth with pillars and a translucent vortex disc.
local function buildParts(model: Model, base: CFrame, s: number, o: Options)
	local r, cy, n = Assets.RingRadius * s, Assets.RingCentreY * s, 18
	local stoneColor, stoneMat = roleStyle("STONE", o)
	local runeColor, runeMat = roleStyle("RUNES", o)
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local key = i == math.floor(n / 4)
		local block = basePart(model, if key then "PortalKeystone" else "PortalVoussoir", stoneColor, stoneMat)
		block.Size = Vector3.new((if key then 1.9 else 1.25) * s, 2 * r * math.sin(math.pi / n) * 0.94, (if key then 1.75 else 1.4) * s)
		block.CFrame = base * CFrame.new(math.cos(a) * r, cy + math.sin(a) * r, 0) * CFrame.Angles(0, 0, a)
		if not key and i % 2 == 0 then
			for _, side in { -1, 1 } do
				local rune = basePart(model, "PortalRune", runeColor, runeMat)
				rune.Size = Vector3.new(0.6 * s, 0.12 * s, 0.05)
				rune.CFrame = block.CFrame * CFrame.new(0, 0, side * (0.72 * s))
			end
		end
	end
	for _, rimRadius in { r - 0.72 * s, r + 0.72 * s } do
		local segments = 24
		for i = 0, segments - 1 do
			local a = (i + 0.5) / segments * math.pi * 2
			local rim = basePart(model, "PortalGoldRim", o.Gold, Enum.Material.Metal)
			rim.Size = Vector3.new(0.16 * s, 2 * rimRadius * math.sin(math.pi / segments) * 1.05, 1.5 * s)
			rim.CFrame = base * CFrame.new(math.cos(a) * rimRadius, cy + math.sin(a) * rimRadius, 0) * CFrame.Angles(0, 0, a)
		end
	end
	local crest = basePart(model, "PortalCrest", o.Gold, Enum.Material.Metal)
	crest.Size = Vector3.new(0.9, 0.9, 1.9) * s
	crest.CFrame = base * CFrame.new(0, cy + r + 1.35 * s, 0) * CFrame.Angles(0, 0, math.rad(45))
	for _, step in { { 10.5, 0.9, 3.4, 0.45 }, { 8.6, 0.7, 2.8, 1.25 } } do
		local plinth = basePart(model, "PortalPlinth", stoneColor, stoneMat)
		plinth.Size = Vector3.new(step[1], step[2], step[3]) * s
		plinth.CFrame = base * CFrame.new(0, step[4] * s, 0)
		plinth.CanCollide = true
	end
	for _, side in { -1, 1 } do
		local pillar = basePart(model, "PortalPillar", stoneColor, stoneMat)
		pillar.Size = Vector3.new(1.5, 2, 1.9) * s
		pillar.CFrame = base * CFrame.new(side * 5.6 * s, 2.6 * s, 0)
		local orb = basePart(model, "PortalFinial", o.Gold, Enum.Material.Metal)
		orb.Shape = Enum.PartType.Ball
		orb.Size = Vector3.new(0.9, 0.9, 0.9) * s
		orb.CFrame = base * CFrame.new(side * 5.6 * s, 4.1 * s, 0)
	end
	local vortexColor, vortexMat, vortexAlpha = roleStyle("VORTEX", o)
	local vortex = basePart(model, "PortalVortex", vortexColor, vortexMat)
	vortex.Shape = Enum.PartType.Cylinder
	vortex.Size = Vector3.new(0.2, (r - 0.8 * s) * 2, (r - 0.8 * s) * 2)
	vortex.CFrame = base * CFrame.new(0, cy, 0) * CFrame.Angles(0, math.pi / 2, 0)
	vortex.Transparency = vortexAlpha
end

-- Builds a portal standing on `base` (its plinth's base centre; the ring faces the base's -Z and +Z).
-- Returns the model and its trigger part (invisible, holds prompts and labels).
function Kit.Build(parent: Instance, base: CFrame, o: Options): (Model, BasePart)
	local s = o.Scale or 1
	local model = Instance.new("Model")
	model.Name = o.Name
	model:SetAttribute("PortalDormant", o.Dormant == true)
	if Assets.HasMeshes() then buildMeshes(model, base, s, o) else buildParts(model, base, s, o) end

	local trigger = basePart(model, o.TriggerName or "PortalTrigger", o.Glow, Enum.Material.SmoothPlastic)
	trigger.Transparency = 1
	trigger.Size = Vector3.new(Assets.RingRadius * 1.6 * s, Assets.RingRadius * 1.8 * s, 4 * s)
	trigger.CFrame = base * CFrame.new(0, Assets.RingCentreY * s, 0)
	model.PrimaryPart = trigger

	if not o.Dormant then
		local glow = Instance.new("PointLight")
		glow.Color = o.Glow
		glow.Range = 22 * s
		glow.Brightness = 1.6
		glow.Parent = trigger
		local motes = Instance.new("ParticleEmitter")
		motes.Name = "PortalMotes"
		motes.Color = ColorSequence.new(o.Glow, Color3.new(1, 1, 1))
		motes.LightEmission = 1
		motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * s), NumberSequenceKeypoint.new(1, 0) })
		motes.Transparency = NumberSequence.new(0.2, 1)
		motes.Rate = 18
		motes.Lifetime = NumberRange.new(1, 2)
		motes.Speed = NumberRange.new(0.5, 2)
		motes.SpreadAngle = Vector2.new(180, 180)
		motes.Parent = trigger
	end
	CollectionService:AddTag(model, "TowerPortal")
	model.Parent = parent
	return model, trigger
end

return table.freeze(Kit)
