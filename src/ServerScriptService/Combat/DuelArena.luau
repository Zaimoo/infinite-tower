--!strict
-- ServerScriptService/Combat/DuelArena.luau
-- Builds the floating hex-grid arena used by retaliation duels (GDD 6.1). Geometry only:
-- CombatSimulation owns the duel state and places the squads on LootDuel.SlotLocal tiles.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootDuel = require(ReplicatedStorage.Shared.Util.LootDuel)

local DuelArena = {}

local TILE_THICKNESS = 0.6
local TILE_GAP = 0.9 -- tiles are scaled down so the grass shows through as grout lines
local BASE_THICKNESS = 5
local SAND = Color3.fromRGB(222, 201, 160)
local SAND_DARK = Color3.fromRGB(205, 182, 140)
local GRASS = Color3.fromRGB(96, 142, 72)
local ROCK = Color3.fromRGB(110, 106, 98)
local BARK = Color3.fromRGB(92, 66, 44)
local LEAVES = Color3.fromRGB(62, 118, 64)

local function folder(): Folder
	local existing = Workspace:FindFirstChild("DuelArenas")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "DuelArenas"
	f.Parent = Workspace
	return f
end

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- A flat-top hexagon is the union of three s x s*sqrt(3) slabs rotated 60 degrees apart.
local function hexTile(parent: Instance, center: Vector3, color: Color3)
	local s = LootDuel.HEX_SIZE * TILE_GAP
	for i = 0, 2 do
		part(parent, {
			Name = "HexTile",
			Size = Vector3.new(s, TILE_THICKNESS, s * math.sqrt(3)),
			CFrame = CFrame.new(center + Vector3.new(0, TILE_THICKNESS / 2, 0)) * CFrame.Angles(0, math.rad(60 * i), 0),
			Color = color,
			Material = Enum.Material.Sand,
		})
	end
end

local function tree(parent: Instance, base: Vector3, scale: number)
	part(parent, {
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(5 * scale, 1.2 * scale, 1.2 * scale),
		CFrame = CFrame.new(base + Vector3.new(0, 2.5 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = BARK,
		Material = Enum.Material.Wood,
	})
	for i, offset in { Vector3.new(0, 6, 0), Vector3.new(1.2, 4.8, 0.6), Vector3.new(-1.1, 5, -0.7) } do
		local size = (if i == 1 then 5 else 3.6) * scale
		part(parent, {
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = base + offset * scale,
			Color = LEAVES,
			Material = Enum.Material.Grass,
		})
	end
end

local function rock(parent: Instance, base: Vector3, size: number, yaw: number)
	part(parent, {
		Name = "Rock",
		Size = Vector3.new(size * 1.3, size * 0.8, size),
		CFrame = CFrame.new(base + Vector3.new(0, size * 0.3, 0)) * CFrame.Angles(math.rad(8), yaw, math.rad(-6)),
		Color = ROCK,
		Material = Enum.Material.Slate,
	})
end

-- Arena radius in studs from the centre to the outer tile corners.
function DuelArena.Radius(): number
	return LootDuel.HEX_SIZE * (1.5 * LootDuel.ARENA_RINGS + 1)
end

-- `center` is the walkable top of the grass base. Heroes stand at center + SlotLocal + StandHeight.
DuelArena.StandHeight = TILE_THICKNESS

-- Arena-local space: +Z runs along `forward`, the horizontal direction from side A toward side B.
function DuelArena.Frame(center: Vector3, forward: Vector3): CFrame
	return CFrame.lookAt(center, center - forward)
end

function DuelArena.Build(duelId: number, center: Vector3, forward: Vector3): Model
	local model = Instance.new("Model")
	model.Name = string.format("DuelArena_%d", duelId)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local frame = DuelArena.Frame(center, forward)
	local radius = DuelArena.Radius()

	part(model, {
		Name = "GrassBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(BASE_THICKNESS, (radius + 9) * 2, (radius + 9) * 2),
		CFrame = CFrame.new(center - Vector3.new(0, BASE_THICKNESS / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = GRASS,
		Material = Enum.Material.Grass,
	})
	part(model, {
		Name = "IslandRock",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, (radius + 6) * 2, (radius + 6) * 2),
		CFrame = CFrame.new(center - Vector3.new(0, BASE_THICKNESS + 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = ROCK,
		Material = Enum.Material.Slate,
	})

	for _, hex in LootDuel.ArenaTiles() do
		local localPos = LootDuel.HexToLocal(hex.q, hex.r)
		local world = frame:PointToWorldSpace(localPos)
		local color = if (hex.q + hex.r) % 2 == 0 then SAND else SAND_DARK
		hexTile(model, Vector3.new(world.X, center.Y, world.Z), color)
	end

	-- Rim dressing: trees on the flanks, rocks between them, the two ends left open for the camera.
	local rng = Random.new(duelId)
	for i = 0, 15 do
		local angle = (i / 16) * math.pi * 2
		local flank = math.abs(math.cos(angle)) -- 1 on the left/right flanks, 0 toward either squad
		local dist = radius + 4 + rng:NextNumber(0, 3)
		local localPos = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local world = frame:PointToWorldSpace(localPos)
		if flank > 0.5 then
			tree(model, world, rng:NextNumber(0.9, 1.3))
		else
			rock(model, world, rng:NextNumber(1.6, 3), rng:NextNumber(0, math.pi))
		end
	end

	model.Parent = folder()
	return model
end

return DuelArena
