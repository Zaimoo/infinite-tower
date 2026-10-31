"""
Exports IronBroadsword_Mesh from Blender to a Luau script that creates
the MeshPart in Roblox Studio via AssetService:CreateEditableMesh.
"""
import bpy
import json
import os

def export_sword_data():
    obj = bpy.data.objects.get("IronBroadsword_Mesh")
    if not obj:
        print("Error: IronBroadsword_Mesh not found in Blender!")
        return None
        
    mesh = obj.data
    mesh.calc_loop_triangles()
    
    verts = [[round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)] for v in mesh.vertices]
    tris = [[lt.vertices[0] + 1, lt.vertices[1] + 1, lt.vertices[2] + 1] for lt in mesh.loop_triangles]
    
    data = {
        "verts": verts,
        "tris": tris,
        "tri_count": len(tris),
        "vert_count": len(verts),
    }
    
    out_dir = r"C:\WORK\infinite-tower\assets\models\weapons"
    os.makedirs(out_dir, exist_ok=True)
    json_path = os.path.join(out_dir, "iron_broadsword_mesh.json")
    with open(json_path, "w") as f:
        json.dump(data, f)
        
    print(f"Exported mesh data to {json_path} (Verts: {len(verts)}, Tris: {len(tris)})")
    return data

if __name__ == "__main__":
    export_sword_data()
