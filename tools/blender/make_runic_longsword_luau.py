"""
Generates apply_runic_longsword_to_studio.luau from runic_longsword_mesh.json.
Injects EditableMesh vertices, triangles, Roblox Studio attachments, Trail,
ParticleEmitter, and OffhandShield.
"""
import json
import os

json_path = r"C:\WORK\infinite-tower\assets\models\weapons\runic_longsword_mesh.json"
out_lua_path = r"C:\WORK\infinite-tower\assets\models\weapons\apply_runic_longsword_to_studio.luau"

with open(json_path, "r") as f:
    data = json.load(f)

flat_verts = [round(c, 4) for v in data["verts"] for c in v]
flat_tris = [idx for t in data["tris"] for idx in t]

lua_lines = []
lua_lines.append("--!strict")
lua_lines.append("-- Generated Luau script to create weapon_runic_longsword prefab with VFX in Roblox Studio")
lua_lines.append("local AssetService = game:GetService('AssetService')")
lua_lines.append("local ReplicatedStorage = game:GetService('ReplicatedStorage')")
lua_lines.append("local Workspace = game:GetService('Workspace')")
lua_lines.append("")
lua_lines.append("local em = AssetService:CreateEditableMesh()")
lua_lines.append("local verts_raw = {" + ",".join(map(str, flat_verts)) + "}")
lua_lines.append("local tris_raw = {" + ",".join(map(str, flat_tris)) + "}")
lua_lines.append("""
local v_ids = {}
for i = 1, #verts_raw, 3 do
    table.insert(v_ids, em:AddVertex(Vector3.new(verts_raw[i], verts_raw[i+1], verts_raw[i+2])))
end

for i = 1, #tris_raw, 3 do
    em:AddTriangle(v_ids[tris_raw[i]], v_ids[tris_raw[i+1]], v_ids[tris_raw[i+2]])
end

local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
mp.Name = "RunicLongsword_Mesh"
mp.Color = Color3.fromRGB(203, 232, 247)
mp.Material = Enum.Material.Metal
mp.CanCollide = false
mp.CanTouch = false
mp.CanQuery = false
mp.Massless = true
mp.Anchored = false
mp.CastShadow = true
mp.CollisionFidelity = Enum.CollisionFidelity.Box
mp.RenderFidelity = Enum.RenderFidelity.Precise

-- Assets.Weapons folder setup
local assets = ReplicatedStorage:FindFirstChild("Assets")
if not assets then
    assets = Instance.new("Folder")
    assets.Name = "Assets"
    assets.Parent = ReplicatedStorage
end

local weaponsFolder = assets:FindFirstChild("Weapons") :: Folder?
if not weaponsFolder then
    weaponsFolder = Instance.new("Folder")
    weaponsFolder.Name = "Weapons"
    weaponsFolder.Parent = assets
end

-- Create the Model Prefab: weapon_runic_longsword
local existing = weaponsFolder:FindFirstChild("weapon_runic_longsword")
if existing then
    existing:Destroy()
end

local swordModel = Instance.new("Model")
swordModel.Name = "weapon_runic_longsword"

-- Handle (PrimaryPart) centered at (0, 0, 0)
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.24, 0.80, 0.24)
handle.Transparency = 1
handle.CanCollide = false
handle.CanTouch = false
handle.CanQuery = false
handle.Massless = true
handle.Anchored = false
handle.CFrame = CFrame.new(0, 0, 0)
handle.Parent = swordModel
swordModel.PrimaryPart = handle

-- Socket attachment: Grip (EDGE_PLUS_X: Up = Blade, Look = Edge)
local grip = Instance.new("Attachment")
grip.Name = "Grip"
grip.CFrame = CFrame.Angles(0, math.rad(-90), 0)
grip.Parent = handle

-- Standardized VFX Sockets
local trailBottom = Instance.new("Attachment")
trailBottom.Name = "TrailBottom"
trailBottom.Position = Vector3.new(0, 0.75, 0)
trailBottom.Parent = handle

local trailTop = Instance.new("Attachment")
trailTop.Name = "TrailTop"
trailTop.Position = Vector3.new(0, 4.10, 0)
trailTop.Parent = handle

local vfxCore = Instance.new("Attachment")
vfxCore.Name = "VFXCore"
vfxCore.Position = Vector3.new(0, 2.40, 0)
vfxCore.Parent = handle

-- 1. Swing Trail
local trail = Instance.new("Trail")
trail.Name = "SwingTrail"
trail.Attachment0 = trailBottom
trail.Attachment1 = trailTop
trail.FaceCamera = true
trail.Lifetime = 0.35
trail.LightEmission = 1.0
trail.LightInfluence = 0.0
trail.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 229, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(56, 189, 248)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(30, 64, 175)),
})
trail.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 0.15),
    NumberSequenceKeypoint.new(0.7, 0.40),
    NumberSequenceKeypoint.new(1.0, 1.00),
})
trail.WidthScale = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 1.0),
    NumberSequenceKeypoint.new(0.8, 0.75),
    NumberSequenceKeypoint.new(1.0, 0.0),
})
trail.Enabled = false -- Enabled during swings by EntityRenderer/HeroAnimator
trail.Parent = handle

-- 2. VFXCore ParticleEmitter (Frost runes & ice sparks)
local particles = Instance.new("ParticleEmitter")
particles.Name = "RunicAuraEmitter"
particles.Rate = 12
particles.Lifetime = NumberRange.new(0.6, 1.2)
particles.Speed = NumberRange.new(0.4, 1.2)
particles.Drag = 2.0
particles.SpreadAngle = Vector2.new(35, 35)
particles.EmissionDirection = Enum.NormalId.Top
particles.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(0, 229, 255)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(100, 216, 255)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(15, 30, 90)),
})
particles.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 1.0),
    NumberSequenceKeypoint.new(0.2, 0.1),
    NumberSequenceKeypoint.new(0.8, 0.3),
    NumberSequenceKeypoint.new(1.0, 1.0),
})
particles.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0.0, 0.25),
    NumberSequenceKeypoint.new(0.5, 0.45),
    NumberSequenceKeypoint.new(1.0, 0.05),
})
particles.LightEmission = 1.0
particles.LightInfluence = 0.0
particles.Parent = vfxCore

-- 3. PointLight on VFXCore
local light = Instance.new("PointLight")
light.Name = "RunicGlow"
light.Color = Color3.fromRGB(0, 229, 255)
light.Range = 9.0
light.Brightness = 1.8
light.Shadows = false
light.Parent = vfxCore

-- Parent MeshPart and weld to Handle
mp:PivotTo(handle.CFrame)
local weld = Instance.new("WeldConstraint")
weld.Part0 = handle
weld.Part1 = mp
weld.Parent = handle
mp.Parent = swordModel

-- Vanguard OffhandShield pairing
local shieldModel = Instance.new("Model")
shieldModel.Name = "OffhandShield"
shieldModel.Parent = swordModel

local steel = Color3.fromRGB(180, 210, 230)
local darkIron = Color3.fromRGB(37, 40, 48)

local gripS = Instance.new("Part")
gripS.Name = "HandleS"
gripS.Size = Vector3.new(0.2, 0.6, 0.2)
gripS.Transparency = 1
gripS.CanCollide = false
gripS.CanTouch = false
gripS.CanQuery = false
gripS.Massless = true
gripS.Anchored = false
gripS.CFrame = CFrame.new(0, 0, 0)
gripS.Parent = shieldModel
shieldModel.PrimaryPart = gripS

local mount = Instance.new("Attachment")
mount.Name = "ShieldMount"
mount.CFrame = CFrame.new(-0.18, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
mount.Parent = gripS

-- Heater Shield with Runic Heraldry
local plate = Instance.new("Part")
plate.Name = "ShieldPlate"
plate.Size = Vector3.new(0.14, 2.2, 1.6)
plate.CFrame = gripS.CFrame * CFrame.new(-0.25, 0, 0)
plate.Color = steel
plate.Material = Enum.Material.Metal
plate.CanCollide = false
plate.CanTouch = false
plate.CanQuery = false
plate.Massless = true
plate.Anchored = false
plate.Parent = shieldModel

local wPlate = Instance.new("WeldConstraint")
wPlate.Part0 = gripS
wPlate.Part1 = plate
wPlate.Parent = gripS

local boss = Instance.new("Part")
boss.Name = "ShieldBoss"
boss.Size = Vector3.new(0.18, 0.7, 0.7)
boss.CFrame = plate.CFrame * CFrame.new(-0.08, 0.2, 0)
boss.Color = Color3.fromRGB(0, 229, 255)
boss.Material = Enum.Material.Neon
boss.CanCollide = false
boss.CanTouch = false
boss.CanQuery = false
boss.Massless = true
boss.Anchored = false
boss.Parent = shieldModel

local wBoss = Instance.new("WeldConstraint")
wBoss.Part0 = gripS
wBoss.Part1 = boss
wBoss.Parent = gripS

swordModel.Parent = weaponsFolder

-- Alias lookup
local aliasExisting = weaponsFolder:FindFirstChild("RunicLongsword")
if aliasExisting then
    aliasExisting:Destroy()
end
local alias = swordModel:Clone()
alias.Name = "RunicLongsword"
alias.Parent = weaponsFolder

return "SUCCESS: Created weapon_runic_longsword and RunicLongsword in ReplicatedStorage.Assets.Weapons! MeshPart triangles: " .. tostring(#tris_raw / 3)
""")

with open(out_lua_path, "w") as f:
    f.write("\n".join(lua_lines))

print(f"Generated {out_lua_path} successfully ({len(flat_verts)//3} verts, {len(flat_tris)//3} tris).")
