-- Studio (Edit mode, via Studio MCP or the command bar): line up remodelled enemies for review screenshots.
-- docs/tower-mob-remodel-plan.md §7. Run after tests/studio-enemy-template-prep.luau.
--
-- Builds every enemy of BIOME through EnemyRigFactory (the same path the game uses) on a platform at ORIGIN,
-- posed at SLOT/PHASE from TowerEnemyClips, next to the old part rig for comparison when COMPARE is true.
-- Re-running replaces the lineup; set CLEAR = true to only remove it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Index = require(ReplicatedStorage.Shared.Config.TowerEnemyModelIndex)
local Config = require(ReplicatedStorage.Shared.Config.FirstBiomeCombat)
local Factory = require(ReplicatedStorage.Assets.EnemyRigFactory)
local Rigs = require(ReplicatedStorage.Assets.TowerEnemyRigs)
local Clips = require(ReplicatedStorage.Assets.TowerEnemyClips)

local BIOME = "verdant_ruins"
local ORIGIN = Vector3.new(0, 400, 3200)
local SLOT, PHASE = "Idle", 0.25
local COMPARE = true
local CLEAR = false

local old = workspace:FindFirstChild("EnemyLineup")
if old then old:Destroy() end
if CLEAR then return "cleared" end
local lineup = Instance.new("Model")
lineup.Name = "EnemyLineup"

local ids = {}
for id, entry in Index do if entry.Biome == BIOME then table.insert(ids, id) end end
table.sort(ids, function(a, b) return Index[a].Height < Index[b].Height end)

local function pose(rig: any, enemyId: string)
	local clips = rig.Clips or Clips[enemyId]
	local frames = clips and (clips[SLOT] or clips.Idle)
	if not frames then return end
	local poses = Clips.Sample(frames, PHASE)
	for name, joint in rig.Joints do joint.Motor.C0 = joint.Bind * (poses[name] or CFrame.identity) end
end

local function spawn(enemyId: string, at: Vector3, useFactory: boolean): any
	local spec = Config.Get(enemyId)
	local model = Instance.new("Model")
	model.Name = enemyId .. (if useFactory then "" else "_old")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	-- face the camera side (+Z): the rigs face -Z
	root.CFrame = CFrame.lookAt(at + Vector3.new(0, spec.RootHeight or 3, 0), at + Vector3.new(0, spec.RootHeight or 3, 10))
	root.Parent = model
	model.PrimaryPart = root
	model.Parent = lineup
	local rig = if useFactory then Factory.Build(model, root, enemyId) else Rigs.Build(model, root, enemyId)
	pose(rig, enemyId)
	return rig
end

local x = 0
local report = {}
for _, id in ids do
	local width = math.max(6, (Config.Get(id).Width or 5) * (if Config.Get(id).Alpha then 1.4 else 1)) + 4
	x += width / 2
	local rig = spawn(id, ORIGIN + Vector3.new(x, 0, 0), true)
	if COMPARE then spawn(id, ORIGIN + Vector3.new(x, 0, -width - 6), false) end
	report[id] = { remodel = rig.Remodel == true, joints = (function() local n = 0 for _ in rig.Joints do n += 1 end return n end)() }
	x += width / 2
end
local floor = Instance.new("Part")
floor.Name = "LineupFloor"
floor.Anchored = true
floor.Size = Vector3.new(x + 20, 1, 60)
floor.CFrame = CFrame.new(ORIGIN + Vector3.new(x / 2, -0.5, -12))
floor.Color = Color3.fromRGB(70, 74, 66)
floor.Parent = lineup
lineup.Parent = workspace
return { camera = { position = ORIGIN + Vector3.new(x / 2, 14, 40), lookAt = ORIGIN + Vector3.new(x / 2, 5, -4) }, enemies = report }
