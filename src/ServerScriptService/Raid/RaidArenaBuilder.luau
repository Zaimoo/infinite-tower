--!strict
-- Raid arena (docs/raid-boss-plan.md §7): one shared off-map room per server at RaidConfig.ArenaOrigin,
-- registered with TowerFloorService as floor RaidConfig.FloorId. A circular battle floor with a boss dais
-- in the north half and a CombatSafe staging pad at the south edge, sealed by a barrier until the fight
-- starts. Each boss reskins it with its palette (Retheme).
local RS = game:GetService("ReplicatedStorage")
local RaidConfig = require(RS.Shared.Config.RaidConfig)

local Builder = {}

local STAGING_HALF_WIDTH = 34
local FLOOR_Y = 0

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

-- Local frame: +Z is south (toward the staging pad), the boss dais sits at -Z.
function Builder.StagingCentre(): Vector3
	return Vector3.new(0, FLOOR_Y, RaidConfig.ArenaRadius - RaidConfig.StagingDepth / 2)
end
function Builder.BossHome(): Vector3
	return Vector3.new(0, FLOOR_Y + 2, -RaidConfig.ArenaRadius * 0.35)
end

function Builder.Build(id: number, generation: number): any
	local origin = RaidConfig.ArenaOrigin
	local R = RaidConfig.ArenaRadius
	local folder = workspace:FindFirstChild("TowerRooms") or Instance.new("Folder")
	folder.Name = "TowerRooms"
	folder.Parent = workspace
	local model = Instance.new("Model")
	model.Name = "RaidArena"
	model:SetAttribute("FloorId", id)
	model:SetAttribute("RoomGeneration", generation)

	local at = function(x: number, y: number, z: number): CFrame return CFrame.new(origin + Vector3.new(x, y, z)) end
	local stone, trim = Color3.fromRGB(34, 30, 38), Color3.fromRGB(150, 110, 52)

	-- battle floor: a disc (cylinder on its side), with a darker inner ring and the boss dais
	local ground = part(model, "Ground", Vector3.new(6, R * 2, R * 2), at(0, FLOOR_Y - 3, 0) * CFrame.Angles(0, 0, math.rad(90)), stone, Enum.Material.Slate, Enum.PartType.Cylinder)
	ground:SetAttribute("RaidTheme", "Floor")
	local ring = part(model, "InnerRing", Vector3.new(0.4, R * 1.3, R * 1.3), at(0, FLOOR_Y + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), trim, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.6
	ring.CanCollide = false
	ring:SetAttribute("RaidTheme", "Glow")
	local inner = part(model, "InnerFloor", Vector3.new(0.5, R * 1.26, R * 1.26), at(0, FLOOR_Y + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), stone:Lerp(Color3.new(), 0.3), Enum.Material.Basalt, Enum.PartType.Cylinder)
	inner:SetAttribute("RaidTheme", "Floor")
	local home = Builder.BossHome()
	local dais = part(model, "BossDais", Vector3.new(2, 46, 46), at(home.X, FLOOR_Y + 0.9, home.Z) * CFrame.Angles(0, 0, math.rad(90)), trim, Enum.Material.Marble, Enum.PartType.Cylinder)
	dais:SetAttribute("RaidTheme", "Trim")

	-- rim wall with pillars and an invisible fence (taller than a jump)
	local segments = 32
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * math.pi * 2
		local x, z = math.sin(a) * (R + 2), math.cos(a) * (R + 2)
		if z > R - RaidConfig.StagingDepth - 4 and math.abs(x) < STAGING_HALF_WIDTH + 6 then continue end -- the staging pad's gap
		local cf = CFrame.lookAt(origin + Vector3.new(x, FLOOR_Y + 3, z), origin + Vector3.new(0, FLOOR_Y + 3, 0))
		local wall = part(model, "Rim", Vector3.new(2 * math.pi * (R + 2) / segments + 0.5, 6, 3), cf, stone, Enum.Material.Slate)
		wall:SetAttribute("RaidTheme", "Floor")
		if i % 4 == 0 then
			local pillar = part(model, "Pillar", Vector3.new(5, 26, 5), cf * CFrame.new(0, 10, 0), stone, Enum.Material.Slate)
			pillar:SetAttribute("RaidTheme", "Floor")
			local brazier = part(model, "PillarFlame", Vector3.new(3, 3, 3), cf * CFrame.new(0, 24.5, 0), trim, Enum.Material.Neon, Enum.PartType.Ball)
			brazier:SetAttribute("RaidTheme", "Glow")
			local light = Instance.new("PointLight")
			light.Range = 40
			light.Brightness = 1.5
			light.Parent = brazier
		end
	end
	for i = 0, 23 do
		local a = (i + 0.5) / 24 * math.pi * 2
		local x, z = math.sin(a) * (R + 4), math.cos(a) * (R + 4)
		if z > R - RaidConfig.StagingDepth - 4 and math.abs(x) < STAGING_HALF_WIDTH + 8 then continue end -- staging pad gap (its own walls close it)
		local cf = CFrame.lookAt(origin + Vector3.new(x, FLOOR_Y + 20, z), origin + Vector3.new(0, FLOOR_Y + 20, 0))
		local barrier = part(model, "Barrier", Vector3.new(2 * math.pi * (R + 4) / 24 + 1, 40, 2), cf, stone)
		barrier.Transparency = 1
	end

	-- staging pad (CombatSafe) south of the floor, the return portal, and the gate barrier
	local sc = Builder.StagingCentre()
	local padDepth = RaidConfig.StagingDepth + 16
	local pad = part(model, "StagingPad", Vector3.new(STAGING_HALF_WIDTH * 2, 6, padDepth), at(0, FLOOR_Y - 2.95, R - RaidConfig.StagingDepth / 2 + 8), trim:Lerp(stone, 0.5), Enum.Material.Marble)
	pad:SetAttribute("RaidTheme", "Trim")
	for _, side in { -1, 1 } do
		local wing = part(model, "StagingWall", Vector3.new(3, 22, padDepth), at(side * (STAGING_HALF_WIDTH + 1.5), FLOOR_Y + 11, R - RaidConfig.StagingDepth / 2 + 8), stone)
		wing:SetAttribute("RaidTheme", "Floor")
	end
	local back = part(model, "StagingBack", Vector3.new(STAGING_HALF_WIDTH * 2 + 6, 30, 3), at(0, FLOOR_Y + 15, R + 16), stone)
	back:SetAttribute("RaidTheme", "Floor")
	local gate = part(model, "RaidGate", Vector3.new(STAGING_HALF_WIDTH * 2, 22, 1), at(0, FLOOR_Y + 11, R - RaidConfig.StagingDepth - 1), trim, Enum.Material.ForceField)
	gate.Transparency = 0.35
	gate:SetAttribute("RaidTheme", "Glow")
	gate.CanCollide = true

	model.PrimaryPart = ground
	model.Parent = folder

	local zoneMinZ = R - RaidConfig.StagingDepth
	return {
		FloorId = id,
		RoomGeneration = generation,
		Origin = origin,
		Model = model,
		ArrivalPart = pad,
		Arrival = CFrame.lookAt(origin + Vector3.new(0, FLOOR_Y + 3.2, R - 8), origin + Vector3.new(0, FLOOR_Y + 3.2, 0)),
		Bounds = { Min = Vector3.new(-R - 20, -30, -R - 20), Max = Vector3.new(R + 20, 120, R + 30) },
		Zones = {
			{
				ZoneId = "RAID_STAGING",
				FloorId = id,
				RoomGeneration = generation,
				LocalPolygonXZ = {
					Vector2.new(-STAGING_HALF_WIDTH, zoneMinZ),
					Vector2.new(STAGING_HALF_WIDTH, zoneMinZ),
					Vector2.new(STAGING_HALF_WIDTH, R + 16),
					Vector2.new(-STAGING_HALF_WIDTH, R + 16),
				},
				MinY = -6,
				MaxY = 30,
				CombatSafe = true,
				CanBankCargo = false,
				CanRecoverWipe = false,
			},
		},
		Raid = true,
	}
end

-- Open or close the gate between the staging pad and the battle floor.
function Builder.SetGateOpen(room: any, open: boolean)
	local gate = room and room.Model and room.Model:FindFirstChild("RaidGate")
	if gate and gate:IsA("BasePart") then
		gate.CanCollide = not open
		gate.Transparency = if open then 1 else 0.35
	end
end

-- Repaint the arena for a boss.
function Builder.Retheme(room: any, boss: RaidConfig.Boss)
	if not room or not room.Model then return end
	for _, d in room.Model:GetDescendants() do
		if d:IsA("BasePart") then
			local role = d:GetAttribute("RaidTheme")
			if role == "Floor" then d.Color = boss.Arena.Floor
			elseif role == "Trim" then d.Color = boss.Arena.Trim
			elseif role == "Glow" then d.Color = boss.Accent end
		elseif d:IsA("PointLight") then
			d.Color = boss.Accent
		end
	end
	room.Model:SetAttribute("RaidBossId", boss.Id)
end

return Builder
