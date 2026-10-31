import json

with open(r"C:\WORK\infinite-tower\assets\models\weapons\iron_broadsword_mesh.json", "r") as f:
    data = json.load(f)

flat_verts = [round(c, 4) for v in data["verts"] for c in v]
flat_tris = [idx for t in data["tris"] for idx in t]

lua_lines = []
lua_lines.append("--!strict")
lua_lines.append("-- Generated Luau script to create IronBroadsword prefab in Roblox Studio")
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
mp.Name = "IronBroadsword_Mesh"
mp.Color = Color3.fromRGB(180, 185, 195)
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

-- Create the Model Prefab: weapon_iron_broadsword
local existing = weaponsFolder:FindFirstChild("weapon_iron_broadsword")
if existing then
    existing:Destroy()
end

local swordModel = Instance.new("Model")
swordModel.Name = "weapon_iron_broadsword"

-- Handle (PrimaryPart) centered at (0, 0, 0)
local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.24, 0.75, 0.24)
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

-- Parent MeshPart and weld to Handle
mp.CFrame = handle.CFrame
local weld = Instance.new("WeldConstraint")
weld.Part0 = handle
weld.Part1 = mp
weld.Parent = handle
mp.Parent = swordModel

-- Vanguard OffhandShield pairing
local shieldModel = Instance.new("Model")
shieldModel.Name = "OffhandShield"
shieldModel.Parent = swordModel

local steel = Color3.fromRGB(150, 158, 172)
local darkIron = Color3.fromRGB(60, 65, 75)

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

-- Buckler shield plate
local plate = Instance.new("Part")
plate.Name = "ShieldPlate"
plate.Size = Vector3.new(0.12, 1.8, 1.8)
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

-- Shield boss / center stud
local boss = Instance.new("Part")
boss.Name = "ShieldBoss"
boss.Size = Vector3.new(0.15, 0.6, 0.6)
boss.CFrame = plate.CFrame * CFrame.new(-0.08, 0, 0)
boss.Color = darkIron
boss.Material = Enum.Material.Metal
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

-- Also clone as "IronBroadsword" for alternative asset lookup
local aliasExisting = weaponsFolder:FindFirstChild("IronBroadsword")
if aliasExisting then
    aliasExisting:Destroy()
end
local alias = swordModel:Clone()
alias.Name = "IronBroadsword"
alias.Parent = weaponsFolder

return "SUCCESS: Created weapon_iron_broadsword and IronBroadsword in ReplicatedStorage.Assets.Weapons! MeshPart triangles: " .. tostring(#tris_raw / 3)
""")

with open(r"C:\WORK\infinite-tower\assets\models\weapons\apply_iron_broadsword_to_studio.luau", "w") as f:
    f.write("\n".join(lua_lines))

print("Regenerated apply_iron_broadsword_to_studio.luau successfully.")
