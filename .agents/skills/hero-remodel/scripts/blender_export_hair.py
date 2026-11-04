"""Export a hero hair object from the live Blender scene (run inside Blender).

Set HAIR (the object name, e.g. "SolarisHair") and OUT_DIR before exec'ing this file:

    HAIR = "SolarisHair"; OUT_DIR = r"D:\\Programming shi\\infinite-tower\\assets\\hair"
    exec(open(r"...\\blender_export_hair.py", encoding="utf-8").read())

Writes <hero>_hair.fbx (for Studio's Import 3D), <hero>_hair.json (vertices in Roblox
coordinates plus triangles, used to verify the import) and <hero>_hair_ugc.blend, then prints
the vertex and triangle counts and the bounding-box centre and size. The centre and size go
straight into the costume's HairMesh piece.
"""

import json
import os

import bpy

hero = HAIR[: -len("Hair")].lower() if HAIR.endswith("Hair") else HAIR.lower()  # noqa: F821
hair = bpy.data.objects[HAIR]  # noqa: F821
bpy.ops.object.select_all(action="DESELECT")
hair.select_set(True)
bpy.context.view_layer.objects.active = hair

bpy.ops.export_scene.fbx(
    filepath=os.path.join(OUT_DIR, f"{hero}_hair.fbx"),  # noqa: F821
    use_selection=True,
    object_types={"MESH"},
    axis_forward="-Z",
    axis_up="Y",
    apply_unit_scale=True,
    bake_space_transform=True,
)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, f"{hero}_hair_ugc.blend"), copy=True)  # noqa: F821

me = hair.data
# Blender (x, y, z) -> Roblox (x, z, -y): Roblox is Y-up with the front at -Z.
verts = [[round(v.co.x, 4), round(v.co.z, 4), round(-v.co.y, 4)] for v in me.vertices]
me.calc_loop_triangles()
with open(os.path.join(OUT_DIR, f"{hero}_hair.json"), "w") as f:  # noqa: F821
    json.dump({"verts": verts, "tris": [list(t.vertices) for t in me.loop_triangles]}, f, separators=(",", ":"))

centre = [round((min(v[i] for v in verts) + max(v[i] for v in verts)) / 2, 4) for i in range(3)]
size = [round(max(v[i] for v in verts) - min(v[i] for v in verts), 3) for i in range(3)]
print("verts", len(verts), "tris", len(me.loop_triangles), "centre", centre, "size", size)
