"""
=============================================================================
Infinite Tower: Become a Master! - 3D Environment Pipeline
Asset: Medieval Gothic Open Forge (`OpenForge`)
Target Engine: Blender 4.x / 5.x -> Roblox Studio (CustomFacilityMeshes.OpenForge)
=============================================================================
Builds the open-air Open Forge terrace (38 x 28 studs) matching
`PlotFacilityArchitecture.BuildBlacksmith`:
  - Open flagstone stone terrace with front step & rear retaining wall
  - Open-sided timber & slate canopy over the rear Smelter bay only
  - Blast Smelter with molten gold pour channel, ingot mold & bellows (X=-10.5, Z=-9.2)
  - Master Anvil on iron-hooped oak block (X=-10.5, Z=+4.8)
  - Rear-right quench barrel, weapon rack & tool workbench
  *(Note: the 6 dynamic Pedestal_1..6 models & prompts are spawned by Luau so
  individual pedestals toggle dynamically with FortressTree unlocks.)*
=============================================================================
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector

COLLECTION_NAME = "OpenForge_Asset"

MATERIAL_SPECS = {
    "SlateStone": ("M_OpenForge_SlateStone", "#484C58", 0.08, 0.85, "#000000", 0.0),
    "AshlarTrim": ("M_OpenForge_AshlarTrim", "#686D7A", 0.10, 0.78, "#000000", 0.0),
    "RoofShingle": ("M_OpenForge_RoofShingle", "#2B303A", 0.15, 0.72, "#000000", 0.0),
    "HeavyTimber": ("M_OpenForge_HeavyTimber", "#4A3221", 0.05, 0.82, "#000000", 0.0),
    "SmelterBrick": ("M_OpenForge_SmelterBrick", "#5C352C", 0.05, 0.88, "#000000", 0.0),
    "WroughtIron": ("M_OpenForge_WroughtIron", "#262930", 0.78, 0.42, "#000000", 0.0),
    "PolishedSteel": ("M_OpenForge_PolishedSteel", "#A2AAB8", 0.88, 0.28, "#000000", 0.0),
    "BronzeTrim": ("M_OpenForge_BronzeTrim", "#BA8A44", 0.82, 0.34, "#000000", 0.0),
    "MoltenGold": ("M_OpenForge_MoltenGold", "#FFC444", 0.0, 0.12, "#FF8C1A", 5.0),
}


def hex_rgb(hex_str: str) -> tuple:
    c = hex_str.lstrip("#")
    return tuple(int(c[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def rbx(rx: float, ry: float, rz: float) -> Vector:
    return Vector((rx, -rz, ry))


def get_material(key: str):
    name, col, met, rough, em_col, em_str = MATERIAL_SPECS[key]
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*hex_rgb(col), 1.0)
        bsdf.inputs["Metallic"].default_value = met
        bsdf.inputs["Roughness"].default_value = rough
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*hex_rgb(em_col), 1.0)
            bsdf.inputs["Emission Strength"].default_value = em_str
    return mat


def add_box(bm: bmesh.types.BMesh, center_rbx: tuple, size_rbx: tuple, mat_index: int = 0):
    sx, sy, sz = size_rbx
    res = bmesh.ops.create_cube(bm, size=1.0)
    verts = res["verts"]
    bmesh.ops.scale(bm, vec=Vector((sx, sz, sy)), verts=verts)
    bmesh.ops.translate(bm, vec=rbx(*center_rbx), verts=verts)
    for f in {f for v in verts for f in v.link_faces}:
        f.material_index = mat_index


def add_cyl(bm: bmesh.types.BMesh, center_rbx: tuple, radius: float, height: float, mat_index: int = 0, segs: int = 16):
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=radius, radius2=radius, depth=height)
    verts = res["verts"]
    bmesh.ops.translate(bm, vec=rbx(*center_rbx), verts=verts)
    for f in {f for v in verts for f in v.link_faces}:
        f.material_index = mat_index


def build_open_forge():
    if COLLECTION_NAME in bpy.data.collections:
        old = bpy.data.collections[COLLECTION_NAME]
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old)

    coll = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(coll)

    mat_keys = list(MATERIAL_SPECS.keys())
    mats = [get_material(k) for k in mat_keys]
    m_idx = {k: i for i, k in enumerate(mat_keys)}

    bm = bmesh.new()

    # 1. Open Stone Terrace & Rear Retaining Parapet
    add_box(bm, (0.0, 0.23, 0.0), (37.0, 0.46, 27.0), m_idx["SlateStone"])
    add_box(bm, (0.0, 0.12, 14.2), (34.0, 0.24, 1.8), m_idx["AshlarTrim"])
    for sx in (-1, 1):
        add_box(bm, (sx * 18.6, 0.31, 0.0), (1.2, 0.62, 27.4), m_idx["AshlarTrim"])
    add_box(bm, (0.0, 1.8, -13.8), (38.0, 3.6, 1.6), m_idx["SlateStone"])
    add_box(bm, (0.0, 3.8, -13.8), (38.4, 0.45, 2.0), m_idx["AshlarTrim"])

    # 2. Rear Smelter Canopy
    for px in (-17.2, -3.4):
        for pz in (-12.6, -5.4):
            add_box(bm, (px, 1.15, pz), (1.7, 1.4, 1.7), m_idx["AshlarTrim"])
            add_box(bm, (px, 6.55, pz), (1.05, 9.4, 1.05), m_idx["HeavyTimber"])
        add_box(bm, (px, 11.4, -9.0), (1.1, 0.95, 8.6), m_idx["HeavyTimber"])
    add_box(bm, (-10.3, 11.4, -5.4), (15.2, 1.05, 1.05), m_idx["HeavyTimber"])
    add_box(bm, (-10.3, 12.65, -9.2), (16.4, 0.55, 10.2), m_idx["RoofShingle"])

    # 3. Blast Smelter (X=-10.5, Z=-9.2)
    sx, sz = -10.5, -9.2
    add_box(bm, (sx, 1.35, sz), (10.8, 1.8, 5.8), m_idx["AshlarTrim"])
    for side in (-1, 1):
        add_box(bm, (sx + side * 3.8, 4.85, sz), (2.5, 5.2, 5.2), m_idx["SmelterBrick"])
    add_box(bm, (sx, 4.85, sz - 1.9), (5.6, 5.2, 1.8), m_idx["SmelterBrick"])
    add_box(bm, (sx, 8.05, sz), (10.6, 1.3, 5.5), m_idx["AshlarTrim"])
    add_box(bm, (sx, 8.05, sz + 2.85), (4.6, 0.55, 0.35), m_idx["BronzeTrim"])
    add_box(bm, (sx, 11.0, sz - 0.2), (8.4, 4.6, 4.4), m_idx["SlateStone"])
    for c_i in range(6):
        r_c = 2.8 * (1.0 - 0.14 * (c_i / 6.0))
        add_cyl(bm, (sx, 13.8 + c_i * 1.35, sz - 0.4), r_c, 1.3, m_idx["AshlarTrim" if c_i % 2 == 0 else "SlateStone"])
    add_box(bm, (sx, 2.35, sz + 3.1), (3.2, 1.2, 1.8), m_idx["WroughtIron"])
    add_box(bm, (sx, 2.98, sz + 2.5), (1.1, 0.25, 2.4), m_idx["MoltenGold"])
    add_box(bm, (sx - 6.1, 2.4, sz + 0.4), (2.6, 2.2, 3.4), m_idx["HeavyTimber"])

    # 4. Master Anvil (X=-10.5, Z=+4.8)
    ax, az = -10.5, 4.8
    add_cyl(bm, (ax, 0.78, az), 2.6, 0.65, m_idx["AshlarTrim"])
    add_cyl(bm, (ax, 1.92, az), 1.75, 1.65, m_idx["HeavyTimber"])
    add_box(bm, (ax, 3.00, az), (2.8, 0.52, 1.7), m_idx["WroughtIron"])
    add_box(bm, (ax, 3.58, az), (1.9, 0.68, 1.2), m_idx["WroughtIron"])
    add_box(bm, (ax, 4.20, az), (3.6, 0.62, 1.52), m_idx["WroughtIron"])
    add_box(bm, (ax, 4.55, az), (3.4, 0.10, 1.42), m_idx["PolishedSteel"])
    add_box(bm, (ax, 3.58, az), (2.0, 0.22, 1.58), m_idx["BronzeTrim"])

    mesh = bpy.data.meshes.new("OpenForge_Shell")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new("OpenForge", mesh)
    for m in mats:
        obj.data.materials.append(m)
    coll.objects.link(obj)

    out_dir = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "models", "open_forge")
    os.makedirs(out_dir, exist_ok=True)
    fbx_path = os.path.abspath(os.path.join(out_dir, "OpenForge.fbx"))
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.fbx(filepath=fbx_path, use_selection=True, axis_up="Y", axis_forward="Z")
    print(f"[OpenForge] Exported {fbx_path}")


if __name__ == "__main__":
    build_open_forge()
