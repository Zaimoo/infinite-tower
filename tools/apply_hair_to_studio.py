import json
import os

with open("assets/hair/aaron_hair.json", "r") as f:
    data = json.load(f)

flat_verts = [round(coord, 4) for v in data["verts"] for coord in v]
flat_tris = [idx for t in data["tris"] for idx in t]

lua_code = []
lua_code.append('local AssetService = game:GetService("AssetService")')
lua_code.append("local em = AssetService:CreateEditableMesh()")
lua_code.append("local verts_raw = {" + ",".join(map(str, flat_verts)) + "}")
lua_code.append("local tris_raw = {" + ",".join(map(str, flat_tris)) + "}")
lua_code.append("""
for i = 1, #verts_raw, 3 do
    em:AddVertex(Vector3.new(verts_raw[i], verts_raw[i+1], verts_raw[i+2]))
end
for i = 1, #tris_raw, 3 do
    em:AddTriangle(tris_raw[i] + 1, tris_raw[i+1] + 1, tris_raw[i+2] + 1)
end

local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
mp.Name = "NewAaronHair"
mp.Color = Color3.fromRGB(222, 192, 133)
mp.Material = Enum.Material.SmoothPlastic
mp.CanCollide = false
mp.CastShadow = true

local viewer = workspace:FindFirstChild("HeroModelViewer")
local aaron = viewer and viewer:FindFirstChild("hero_aaron")
local head = aaron and aaron:FindFirstChild("Head")

if head then
    for _, ch in ipairs(head:GetChildren()) do
        if ch.Name:find("Hair") then ch:Destroy() end
    end
    for _, ch in ipairs(aaron:GetChildren()) do
        if ch.Name:find("Hair") then ch:Destroy() end
    end
    
    mp.CFrame = head.CFrame * CFrame.new(0.0125, 0.2968, -0.0784)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = head
    weld.Part1 = mp
    weld.Parent = mp
    mp.Parent = head
    return "SUCCESS: Attached NewAaronHair to Aaron's head in workspace.HeroModelViewer!"
else
    mp.Position = Vector3.new(0, 5, 0)
    mp.Anchored = true
    mp.Parent = workspace
    return "SUCCESS: Created NewAaronHair in Workspace at (0, 5, 0)"
end
""")

with open("assets/hair/apply_hair_to_studio.luau", "w", encoding="utf-8") as out:
    out.write("\n".join(lua_code))

print("Wrote assets/hair/apply_hair_to_studio.luau successfully!")
