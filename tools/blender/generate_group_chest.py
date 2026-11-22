"""
Infinite Tower: Become a Master! - Group Chest 3D Model & Asset Exporter
========================================================================
Sculpts the Group Chest in Blender using clean BMesh geometry matching the
reference concept (ornate antique-gold & silver chest with low-poly faceted
ice-blue crystal vault panels, glowing inner neon core, brilliant-cut diamond
gems, apex crown & diamond capstone, and 6 orbiting light-blue glitch shards).

Hierarchy under root collection `GroupChest`:
  1. `ChestBase` (Static Lower Vault & Frame)
     - `Base_GoldPlinth`
     - `Base_CornerPillars`
     - `Base_CrystalWalls`
     - `Base_InnerGlitchCore`
     - `Base_LockEscutcheon`
     - `Base_DiamondGems`
  2. `ChestLid` (Hinged Upper Barrel Dome, pivot at (0, 2.85, 2.15))
     - `Lid_GoldArches`
     - `Lid_CrystalDome`
     - `Lid_InnerCore`
     - `Lid_CrownMount`
     - `Lid_ApexDiamond`
     - `Lid_FrontClasp`
  3. `ChestGlitch` (6 Individual Floating Glitch Shards, Collidable = false)
     - `Glitch_Shard_1` .. `Glitch_Shard_6`

Coordinate Convention (1 Blender meter = 1 Roblox stud):
  - Authored in Roblox Y-up space: +X east/right, +Y up, -Z front toward viewer,
    origin (0, 0, 0) at bottom-center ground plane y = 0.
  - Converted to Blender Z-up via `r2b(rx, ry, rz) = Vector((rx, -rz, ry))`.
  - Exported to FBX with `axis_forward="-Z", axis_up="Y", bake_space_transform=True`.

Outputs:
  - assets/models/group_chest/group_chest.blend
  - assets/models/group_chest/group_chest.fbx
  - assets/models/group_chest/manifest.json
  - assets/models/group_chest/group_chest_workbench_preview.png
  - assets/models/group_chest/group_chest_eevee_preview.png
  - src/ReplicatedStorage/Assets/GroupChestMeshes/group_chest.luau
  - src/ReplicatedStorage/Assets/GroupChestMeshData.luau

Usage:
  "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b --factory-startup --python tools/blender/generate_group_chest.py
"""

from __future__ import annotations

import base64
import json
import math
import os
import random
import re
import struct

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(REPO, "assets", "models", "group_chest")
LUAU_DATA_PATH = os.path.join(REPO, "src", "ReplicatedStorage", "Assets", "GroupChestMeshData.luau")
SHARDS_DIR = os.path.join(REPO, "src", "ReplicatedStorage", "Assets", "GroupChestMeshes")

HINGE_PIVOT = (0.0, 2.85, 2.15)
MAX_TRIS_PER_PART = 9500

# Core chest spatial constants (Roblox studs)
BASE_HALF_W = 3.04          # corner column center X
BASE_HALF_D = 1.96          # corner column center Z
BASE_TOP_Y = 2.85
ARCH_CENTER_X = 2.98        # outer lid arch rib center X
INNER_ARCH_X = 1.04         # intermediate rib/arch X
ARCH_HALF_D = 2.15          # barrel vault half-depth (matches HingePivot Z = 2.15)
ARCH_RISE = 1.80            # apex Y = 2.85 + 1.80 = 4.65


# ---------------------------------------------------------------------------
# Coordinate conversion & scene helpers
# ---------------------------------------------------------------------------

def r2b(p) -> Vector:
    """Roblox Y-up (rx, ry, rz) -> Blender Z-up (rx, -rz, ry)."""
    return Vector((p[0], -p[2], p[1]))


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def get_or_create_collection(name: str, parent: bpy.types.Collection | None = None) -> bpy.types.Collection:
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        if parent is None:
            bpy.context.scene.collection.children.link(col)
        else:
            parent.children.link(col)
    return col


def make_material(
    name: str,
    rgb: tuple[int, int, int],
    material_enum: str = "Metal",
    metallic: float = 0.72,
    roughness: float = 0.28,
    emit_rgb: tuple[int, int, int] | None = None,
    emit_strength: float = 0.0,
    transparency: float = 0.0,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")

    lin = tuple((c / 255.0) ** 2.2 for c in rgb)
    alpha = max(0.0, min(1.0, 1.0 - transparency))
    mat.diffuse_color = (lin[0], lin[1], lin[2], alpha)
    mat.metallic = metallic
    mat.roughness = roughness

    bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = roughness
    if "Alpha" in bsdf.inputs:
        bsdf.inputs["Alpha"].default_value = alpha
    if transparency > 0.0:
        if "IOR" in bsdf.inputs:
            bsdf.inputs["IOR"].default_value = 1.52
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.90
        mat.use_backface_culling = True
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
        elif hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"

    if emit_rgb and emit_strength > 0.0 and "Emission Color" in bsdf.inputs:
        elin = tuple((c / 255.0) ** 2.2 for c in emit_rgb)
        bsdf.inputs["Emission Color"].default_value = (elin[0], elin[1], elin[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit_strength

    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    mat["rbx_material"] = material_enum
    mat["rbx_color"] = list(rgb)
    mat["rbx_transparency"] = float(transparency)
    return mat


def create_materials() -> dict[str, bpy.types.Material]:
    return {
        "gold_plinth": make_material(
            "M_GoldPlinth", (228, 175, 68), "Metal", metallic=0.86, roughness=0.25
        ),
        "gold_frame": make_material(
            "M_GoldFrame", (238, 186, 78), "Metal", metallic=0.88, roughness=0.22
        ),
        "gold_crown": make_material(
            "M_GoldCrown", (232, 182, 76), "Metal", metallic=0.88, roughness=0.22
        ),
        "silver_base": make_material(
            "M_SilverLock", (226, 234, 248), "Metal", metallic=0.90, roughness=0.18
        ),
        "silver_clasp": make_material(
            "M_SilverClasp", (228, 236, 250), "Metal", metallic=0.90, roughness=0.18
        ),
        "crystal_base": make_material(
            "M_CrystalBase",
            (88, 205, 255),
            "Glass",
            metallic=0.10,
            roughness=0.04,
            emit_rgb=None,
            emit_strength=0.0,
            transparency=0.22,
        ),
        "crystal_lid": make_material(
            "M_CrystalLid",
            (96, 214, 255),
            "Glass",
            metallic=0.10,
            roughness=0.04,
            emit_rgb=None,
            emit_strength=0.0,
            transparency=0.22,
        ),
        "core_base": make_material(
            "M_CoreBase",
            (46, 148, 255),
            "Neon",
            metallic=0.0,
            roughness=0.12,
            emit_rgb=(20, 102, 255),
            emit_strength=1.8,
        ),
        "core_lid": make_material(
            "M_CoreLid",
            (56, 165, 255),
            "Neon",
            metallic=0.0,
            roughness=0.12,
            emit_rgb=(28, 125, 255),
            emit_strength=2.0,
        ),
        "diamond_gem": make_material(
            "M_DiamondGem",
            (210, 240, 255),
            "Neon",
            metallic=0.05,
            roughness=0.06,
            emit_rgb=(175, 224, 255),
            emit_strength=1.5,
        ),
        "apex_diamond": make_material(
            "M_ApexDiamond",
            (140, 225, 255),
            "Neon",
            metallic=0.05,
            roughness=0.06,
            emit_rgb=(70, 175, 255),
            emit_strength=1.4,
        ),
        "glitch_blue": make_material(
            "M_GlitchBlue",
            (46, 128, 255),
            "Neon",
            metallic=0.0,
            roughness=0.10,
            emit_rgb=(46, 128, 255),
            emit_strength=2.2,
        ),
        "glitch_cyan": make_material(
            "M_GlitchCyan",
            (150, 225, 255),
            "Neon",
            metallic=0.0,
            roughness=0.10,
            emit_rgb=(120, 210, 255),
            emit_strength=1.8,
        ),
    }


# ---------------------------------------------------------------------------
# BMesh sculptural primitives (authored in Roblox Y-up, converted on merge)
# ---------------------------------------------------------------------------

def merge_bmesh_rbx(dst: bmesh.types.BMesh, src: bmesh.types.BMesh) -> None:
    """Converts vertices of `src` from Roblox Y-up to Blender Z-up and merges into `dst`."""
    bmesh.ops.recalc_face_normals(src, faces=src.faces)
    vmap = {}
    for v in src.verts:
        vmap[v.index] = dst.verts.new(r2b(v.co))
    for f in src.faces:
        try:
            dst.faces.new([vmap[v.index] for v in f.verts])
        except ValueError:
            pass


def add_box(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: tuple[float, float, float],
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.04,
    segments: int = 1,
) -> None:
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.transform(tmp, matrix=Matrix.Diagonal((size[0], size[1], size[2], 1.0)), verts=tmp.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(
            tmp,
            geom=list(tmp.edges),
            offset=min(bevel, min(size) * 0.38),
            segments=segments,
            affect="EDGES",
            clamp_overlap=True,
        )
    rot = Euler([math.radians(a) for a in rot_deg], "XYZ").to_matrix().to_4x4()
    trans = Matrix.Translation(Vector(center))
    bmesh.ops.transform(tmp, matrix=trans @ rot, verts=tmp.verts)
    merge_bmesh_rbx(bm, tmp)
    tmp.free()


def add_prism_xz(
    bm: bmesh.types.BMesh,
    pts_xz: list[tuple[float, float]],
    y0: float,
    y1: float,
    bevel: float = 0.03,
    segments: int = 1,
) -> None:
    """Extrudes a 2D polygon in Roblox (X, Z) from y0 to y1."""
    tmp = bmesh.new()
    vb = [tmp.verts.new((x, y0, z)) for (x, z) in pts_xz]
    vt = [tmp.verts.new((x, y1, z)) for (x, z) in pts_xz]
    n = len(pts_xz)
    tmp.faces.new(list(reversed(vb)))
    tmp.faces.new(vt)
    for i in range(n):
        ni = (i + 1) % n
        tmp.faces.new((vb[i], vb[ni], vt[ni], vt[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    if bevel > 0.0:
        bmesh.ops.bevel(
            tmp,
            geom=list(tmp.edges),
            offset=bevel,
            segments=segments,
            affect="EDGES",
            clamp_overlap=True,
        )
    merge_bmesh_rbx(bm, tmp)
    tmp.free()


def add_prism_xy(
    bm: bmesh.types.BMesh,
    pts_xy: list[tuple[float, float]],
    z0: float,
    z1: float,
    bevel: float = 0.03,
    segments: int = 1,
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    pivot: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    """Extrudes a 2D polygon in Roblox (X, Y) from z0 to z1 with optional rotation."""
    tmp = bmesh.new()
    vf = [tmp.verts.new((x, y, z0)) for (x, y) in pts_xy]
    vb = [tmp.verts.new((x, y, z1)) for (x, y) in pts_xy]
    n = len(pts_xy)
    tmp.faces.new(list(reversed(vf)))
    tmp.faces.new(vb)
    for i in range(n):
        ni = (i + 1) % n
        tmp.faces.new((vf[i], vf[ni], vb[ni], vb[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    if bevel > 0.0:
        bmesh.ops.bevel(
            tmp,
            geom=list(tmp.edges),
            offset=bevel,
            segments=segments,
            affect="EDGES",
            clamp_overlap=True,
        )
    if any(abs(a) > 1e-5 for a in rot_deg):
        p = Vector(pivot)
        rot = Euler([math.radians(a) for a in rot_deg], "XYZ").to_matrix().to_4x4()
        mat = Matrix.Translation(p) @ rot @ Matrix.Translation(-p)
        bmesh.ops.transform(tmp, matrix=mat, verts=tmp.verts)
    merge_bmesh_rbx(bm, tmp)
    tmp.free()


def add_loft(bm: bmesh.types.BMesh, rings: list[list[Vector]], cap_ends: bool = True) -> None:
    """Lofts a watertight tube through a sequence of equal-length 3D vertex rings in Roblox space."""
    if len(rings) < 2:
        return
    n = len(rings[0])
    tmp = bmesh.new()
    v_rings = [[tmp.verts.new(p) for p in ring] for ring in rings]
    for r_idx in range(len(v_rings) - 1):
        r0, r1 = v_rings[r_idx], v_rings[r_idx + 1]
        for i in range(n):
            ni = (i + 1) % n
            tmp.faces.new((r0[i], r0[ni], r1[ni], r1[i]))
    if cap_ends:
        tmp.faces.new(list(reversed(v_rings[0])))
        tmp.faces.new(v_rings[-1])
    merge_bmesh_rbx(bm, tmp)
    tmp.free()


def _basis_from_normal(normal_dir: tuple[float, float, float]) -> tuple[Vector, Vector, Vector]:
    nz = Vector(normal_dir).normalized()
    hint = Vector((0.0, 1.0, 0.0)) if abs(nz.y) < 0.92 else Vector((0.0, 0.0, 1.0))
    nx = hint.cross(nz).normalized()
    ny = nz.cross(nx).normalized()
    return nx, ny, nz


def add_rivet(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius: float = 0.056,
    height: float = 0.046,
    normal_dir: tuple[float, float, float] = (0.0, 0.0, -1.0),
    sides: int = 8,
) -> None:
    """Adds a compact, faceted-beveled dome stud rivet oriented along `normal_dir`."""
    nx, ny, nz = _basis_from_normal(normal_dir)
    c = Vector(center)
    tmp = bmesh.new()

    ring_base = []
    ring_mid = []
    for i in range(sides):
        ang = (2.0 * math.pi * i) / sides
        dx = math.cos(ang)
        dy = math.sin(ang)
        p_base = c + (nx * dx + ny * dy) * radius - nz * (height * 0.25)
        p_mid = c + (nx * dx + ny * dy) * (radius * 0.68) + nz * (height * 0.62)
        ring_base.append(tmp.verts.new(p_base))
        ring_mid.append(tmp.verts.new(p_mid))
    v_tip = tmp.verts.new(c + nz * height)

    tmp.faces.new(list(reversed(ring_base)))
    for i in range(sides):
        ni = (i + 1) % sides
        tmp.faces.new((ring_base[i], ring_base[ni], ring_mid[ni], ring_mid[i]))
        tmp.faces.new((ring_mid[i], ring_mid[ni], v_tip))

    merge_bmesh_rbx(bm, tmp)
    tmp.free()


def add_diamond_gem(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius: float = 0.14,
    height: float = 0.10,
    normal_dir: tuple[float, float, float] = (0.0, 0.0, -1.0),
    sides: int = 8,
    pavilion_depth: float = 0.05,
    aspect_y: float = 1.0,
) -> None:
    """Creates a brilliant-cut low-poly faceted diamond gem oriented along `normal_dir`."""
    nx, ny, nz = _basis_from_normal(normal_dir)
    c = Vector(center)
    tmp = bmesh.new()

    v_pav = tmp.verts.new(c - nz * pavilion_depth)
    ring_girdle = []
    ring_crown = []
    for i in range(sides):
        ang = (2.0 * math.pi * i) / sides + math.pi / sides
        dx = math.cos(ang) * radius
        dy = math.sin(ang) * radius * aspect_y
        ring_girdle.append(tmp.verts.new(c + nx * dx + ny * dy))
        ring_crown.append(tmp.verts.new(c + (nx * dx + ny * dy) * 0.54 + nz * height))

    for i in range(sides):
        ni = (i + 1) % sides
        tmp.faces.new((v_pav, ring_girdle[ni], ring_girdle[i]))
        tmp.faces.new((ring_girdle[i], ring_girdle[ni], ring_crown[ni], ring_crown[i]))
    tmp.faces.new(ring_crown)

    merge_bmesh_rbx(bm, tmp)
    tmp.free()


def add_bezel_ring(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    outer_r: float,
    inner_r: float,
    depth: float,
    normal_dir: tuple[float, float, float] = (0.0, 0.0, -1.0),
    sides: int = 8,
    aspect_y: float = 1.0,
) -> None:
    """Creates a clean beveled octagonal/polygonal metal bezel ring."""
    nx, ny, nz = _basis_from_normal(normal_dir)
    c = Vector(center)
    tmp = bmesh.new()

    back_out, front_out, front_in, back_in = [], [], [], []
    bev_r = inner_r + (outer_r - inner_r) * 0.35
    for i in range(sides):
        ang = (2.0 * math.pi * i) / sides + math.pi / sides
        ux = math.cos(ang)
        uy = math.sin(ang) * aspect_y
        dir_xy = nx * ux + ny * uy
        back_out.append(tmp.verts.new(c + dir_xy * outer_r - nz * (depth * 0.45)))
        front_out.append(tmp.verts.new(c + dir_xy * (outer_r * 0.90) + nz * (depth * 0.38)))
        front_in.append(tmp.verts.new(c + dir_xy * bev_r + nz * (depth * 0.55)))
        back_in.append(tmp.verts.new(c + dir_xy * inner_r - nz * (depth * 0.45)))

    for i in range(sides):
        ni = (i + 1) % sides
        tmp.faces.new((back_out[i], back_out[ni], front_out[ni], front_out[i]))
        tmp.faces.new((front_out[i], front_out[ni], front_in[ni], front_in[i]))
        tmp.faces.new((front_in[i], front_in[ni], back_in[ni], back_in[i]))
        tmp.faces.new((back_in[i], back_in[ni], back_out[ni], back_out[i]))

    merge_bmesh_rbx(bm, tmp)
    tmp.free()


def add_faceted_crystal_panel(
    bm: bmesh.types.BMesh,
    u0: float,
    u1: float,
    v0: float,
    v1: float,
    w_back: float,
    w_front: float,
    nu: int,
    nv: int,
    amp: float = 0.085,
    seed: int = 1,
    axis: str = "Z",
    sign: float = -1.0,
) -> None:
    """
    Creates a closed watertight low-poly jewel-faceted crystal slab.
    axis='Z': u -> X, v -> Y, w -> Z (sign=-1 faces -Z front, sign=+1 faces +Z back).
    axis='X': u -> Z, v -> Y, w -> X (sign=-1 faces -X left, sign=+1 faces +X right).
    """
    rng = random.Random(seed)
    tmp = bmesh.new()

    def pt_at(u: float, v: float, depth_val: float) -> tuple[float, float, float]:
        if axis == "Z":
            return (u, v, depth_val)
        return (depth_val, v, u)

    w0 = w_back
    w1 = w_front

    front_grid = []
    back_grid = []
    for iv in range(nv + 1):
        tv = iv / nv
        v_base = v0 + (v1 - v0) * tv
        row_f, row_b = [], []
        for iu in range(nu + 1):
            tu = iu / nu
            u_base = u0 + (u1 - u0) * tu
            is_border = iu == 0 or iu == nu or iv == 0 or iv == nv
            du = 0.0 if (iu == 0 or iu == nu) else rng.uniform(-0.22, 0.22) * ((u1 - u0) / nu)
            dv = 0.0 if (iv == 0 or iv == nv) else rng.uniform(-0.22, 0.22) * ((v1 - v0) / nv)
            dw = 0.0 if is_border else rng.uniform(-amp * 0.40, amp)
            row_f.append(tmp.verts.new(pt_at(u_base + du, v_base + dv, w1 + sign * dw)))
            row_b.append(tmp.verts.new(pt_at(u_base, v_base, w0)))
        front_grid.append(row_f)
        back_grid.append(row_b)

    for iv in range(nv):
        for iu in range(nu):
            a = front_grid[iv][iu]
            b = front_grid[iv][iu + 1]
            c = front_grid[iv + 1][iu + 1]
            d = front_grid[iv + 1][iu]
            if (iu + iv) % 2 == 0:
                tmp.faces.new((a, b, c))
                tmp.faces.new((a, c, d))
            else:
                tmp.faces.new((a, b, d))
                tmp.faces.new((b, c, d))

            ba = back_grid[iv][iu]
            bb = back_grid[iv][iu + 1]
            bc = back_grid[iv + 1][iu + 1]
            bd = back_grid[iv + 1][iu]
            tmp.faces.new((ba, bd, bc, bb))

    for iu in range(nu):
        tmp.faces.new((back_grid[0][iu], back_grid[0][iu + 1], front_grid[0][iu + 1], front_grid[0][iu]))
        tmp.faces.new((front_grid[nv][iu], front_grid[nv][iu + 1], back_grid[nv][iu + 1], back_grid[nv][iu]))
    for iv in range(nv):
        tmp.faces.new((front_grid[iv][0], front_grid[iv + 1][0], back_grid[iv + 1][0], back_grid[iv][0]))
        tmp.faces.new((back_grid[iv][nu], back_grid[iv + 1][nu], front_grid[iv + 1][nu], front_grid[iv][nu]))

    merge_bmesh_rbx(bm, tmp)
    tmp.free()


def finalize_mesh(
    name: str,
    bm: bmesh.types.BMesh,
    col: bpy.types.Collection,
    mat: bpy.types.Material,
    collidable: bool = True,
    split_angle_deg: float = 30.0,
) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    sharp_edges = [
        e
        for e in bm.edges
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(split_angle_deg)
    ]
    if sharp_edges:
        bmesh.ops.split_edges(bm, edges=sharp_edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))

    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(mat)
    obj["rbx_collidable"] = collidable
    col.objects.link(obj)

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return obj


# ---------------------------------------------------------------------------
# Sub-collection 1: ChestBase (Static Lower Vault & Frame)
# ---------------------------------------------------------------------------

def _build_corner_foot(bm_plinth: bmesh.types.BMesh, sx: float, sz: float) -> None:
    """Sculpts a flared, multi-faceted golden corner foot with winged buttresses framing a clean gem socket."""
    cx, cz = sx * 3.04, sz * 1.96
    # Solid lower foot pad touching y = 0.0..0.14, flaring out to (+/-3.40, +/-2.30)
    pts_pad = [
        (sx * 2.66, sz * 1.72),
        (sx * 3.40, sz * 1.88),
        (sx * 3.40, sz * 2.30),
        (sx * 2.86, sz * 2.30),
        (sx * 2.66, sz * 2.04),
    ]
    add_prism_xz(bm_plinth, pts_pad, y0=0.00, y1=0.14, bevel=0.03)

    # Tapered corner pyramidal core rising behind the recessed gem pocket
    ring_bot = [
        Vector((sx * 2.74, 0.12, sz * 1.76)),
        Vector((sx * 3.30, 0.12, sz * 1.90)),
        Vector((sx * 3.24, 0.12, sz * 2.16)),
        Vector((sx * 2.88, 0.12, sz * 2.22)),
        Vector((sx * 2.74, 0.12, sz * 2.00)),
    ]
    ring_mid = [
        Vector((sx * 2.80, 0.40, sz * 1.80)),
        Vector((sx * 3.22, 0.40, sz * 1.92)),
        Vector((sx * 3.16, 0.40, sz * 2.10)),
        Vector((sx * 2.94, 0.40, sz * 2.14)),
        Vector((sx * 2.80, 0.40, sz * 1.98)),
    ]
    ring_top = [
        Vector((sx * 2.84, 0.70, sz * 1.82)),
        Vector((sx * 3.18, 0.70, sz * 1.90)),
        Vector((sx * 3.15, 0.70, sz * 2.07)),
        Vector((sx * 2.98, 0.70, sz * 2.10)),
        Vector((sx * 2.84, 0.70, sz * 1.96)),
    ]
    add_loft(bm_plinth, [ring_bot, ring_mid, ring_top], cap_ends=True)

    # Flanking winged buttress fins clearly spaced outside the diagonal gem socket
    add_box(bm_plinth, (cx + sx * 0.25, 0.36, cz - sz * 0.08), (0.16, 0.52, 0.14), rot_deg=(0, 0, -sx * 16), bevel=0.025)
    add_box(bm_plinth, (cx - sx * 0.08, 0.36, cz + sz * 0.25), (0.14, 0.52, 0.16), rot_deg=(sz * 16, 0, 0), bevel=0.025)
    # Upper stepped collar flange atop the foot
    add_box(bm_plinth, (sx * 3.06, 0.64, sz * 1.98), (0.58, 0.20, 0.58), bevel=0.04)


def _build_corner_shield_capital(bm_pillars: bmesh.types.BMesh, sx: float, sz: float) -> None:
    """
    Sculpts the ornate 2-tier corner diamond-shield capital overlapping the waist seam (y = 2.18..3.08).
    Kept strictly clear of the side lid arch above y = 2.85 and clean around the 3 corner gem pockets.
    """
    # Lower corner collar backing behind the two side-facing/front-facing silver jewel bezels
    add_box(bm_pillars, (sx * 3.05, 2.48, sz * 1.97), (0.60, 0.54, 0.60), bevel=0.05)

    # Pointed gold shield crest at the outer corner above the two lower gems (y = 2.66..3.12)
    shield_cx = sx * 3.24
    shield_cz = sz * 2.08
    r_bot = [
        Vector((shield_cx - sx * 0.10, 2.60, shield_cz - sz * 0.16)),
        Vector((shield_cx + sx * 0.05, 2.60, shield_cz - sz * 0.16)),
        Vector((shield_cx + sx * 0.14, 2.60, shield_cz + sz * 0.02)),
        Vector((shield_cx + sx * 0.08, 2.60, shield_cz + sz * 0.16)),
        Vector((shield_cx - sx * 0.10, 2.60, shield_cz + sz * 0.12)),
    ]
    r_mid = [
        Vector((shield_cx - sx * 0.08, 2.84, shield_cz - sz * 0.20)),
        Vector((shield_cx + sx * 0.08, 2.84, shield_cz - sz * 0.20)),
        Vector((shield_cx + sx * 0.18, 2.84, shield_cz + sz * 0.04)),
        Vector((shield_cx + sx * 0.10, 2.84, shield_cz + sz * 0.20)),
        Vector((shield_cx - sx * 0.08, 2.84, shield_cz + sz * 0.14)),
    ]
    r_top = [
        Vector((shield_cx - sx * 0.04, 3.04, shield_cz - sz * 0.09)),
        Vector((shield_cx + sx * 0.06, 3.04, shield_cz - sz * 0.09)),
        Vector((shield_cx + sx * 0.10, 3.04, shield_cz + sz * 0.02)),
        Vector((shield_cx + sx * 0.07, 3.04, shield_cz + sz * 0.10)),
        Vector((shield_cx - sx * 0.04, 3.04, shield_cz + sz * 0.08)),
    ]
    r_peak = [
        Vector((shield_cx + sx * 0.01, 3.16, shield_cz - sz * 0.02)),
        Vector((shield_cx + sx * 0.04, 3.16, shield_cz - sz * 0.02)),
        Vector((shield_cx + sx * 0.06, 3.16, shield_cz + sz * 0.01)),
        Vector((shield_cx + sx * 0.04, 3.16, shield_cz + sz * 0.03)),
        Vector((shield_cx + sx * 0.01, 3.16, shield_cz + sz * 0.02)),
    ]
    add_loft(bm_pillars, [r_bot, r_mid, r_top, r_peak], cap_ends=True)

    # Lower pointed shield pendant below the corner bezels (y = 2.02..2.30)
    add_box(bm_pillars, (sx * 3.16, 2.18, sz * 2.04), (0.30, 0.30, 0.30), rot_deg=(0, 45, 0), bevel=0.035)


def build_chest_base(root_col: bpy.types.Collection, pal: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    col = get_or_create_collection("ChestBase", root_col)

    # 1. Base_GoldPlinth
    bm_plinth = bmesh.new()
    add_box(bm_plinth, (0.0, 0.08, 0.0), (6.34, 0.16, 4.14), bevel=0.04)
    add_box(bm_plinth, (0.0, 0.24, 0.0), (6.44, 0.24, 4.24), bevel=0.06)
    add_box(bm_plinth, (0.0, 0.44, 0.0), (6.16, 0.24, 3.96), bevel=0.06)
    add_box(bm_plinth, (0.0, 0.57, 0.0), (5.92, 0.14, 3.74), bevel=0.03)

    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            _build_corner_foot(bm_plinth, sx, sz)

    for rx in (-2.38, -1.78, -0.56, 0.56, 1.78, 2.38):
        add_rivet(bm_plinth, (rx, 0.42, -2.01), radius=0.055, height=0.045, normal_dir=(0, 0.15, -1))
        add_rivet(bm_plinth, (rx, 0.42, 2.01), radius=0.055, height=0.045, normal_dir=(0, 0.15, 1))
    for rz in (-1.28, -0.64, 0.0, 0.64, 1.28):
        add_rivet(bm_plinth, (-3.11, 0.42, rz), radius=0.055, height=0.045, normal_dir=(-1, 0.15, 0))
        add_rivet(bm_plinth, (3.11, 0.42, rz), radius=0.055, height=0.045, normal_dir=(1, 0.15, 0))
    finalize_mesh("Base_GoldPlinth", bm_plinth, col, pal["gold_plinth"], collidable=True, split_angle_deg=32.0)

    # 2. Base_CornerPillars
    bm_pillars = bmesh.new()
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            px, pz = sx * BASE_HALF_W, sz * BASE_HALF_D
            add_box(bm_pillars, (px, 1.66, pz), (0.56, 2.16, 0.56), bevel=0.06)
            add_box(bm_pillars, (px + sx * 0.12, 1.62, pz + sz * 0.12), (0.42, 2.04, 0.42), bevel=0.05)
            for ry in (0.98, 1.44, 1.88):
                add_rivet(bm_pillars, (px, ry, pz + sz * 0.29), radius=0.05, height=0.04, normal_dir=(0, 0, sz))
                add_rivet(bm_pillars, (px + sx * 0.29, ry, pz), radius=0.05, height=0.04, normal_dir=(sx, 0, 0))
            _build_corner_shield_capital(bm_pillars, sx, sz)

    # Hollow horizontal waist band (4 perimeter beams at y = 2.60..2.85)
    add_box(bm_pillars, (0.0, 2.725, -2.02), (6.16, 0.25, 0.28), bevel=0.04)
    add_box(bm_pillars, (0.0, 2.725, 2.02), (6.16, 0.25, 0.28), bevel=0.04)
    add_box(bm_pillars, (-3.04, 2.725, 0.0), (0.28, 0.25, 4.10), bevel=0.04)
    add_box(bm_pillars, (3.04, 2.725, 0.0), (0.28, 0.25, 4.10), bevel=0.04)
    # Inner stepped sill inside waist
    add_box(bm_pillars, (0.0, 2.58, -1.86), (5.76, 0.14, 0.16), bevel=0.02)
    add_box(bm_pillars, (0.0, 2.58, 1.86), (5.76, 0.14, 0.16), bevel=0.02)
    add_box(bm_pillars, (-2.86, 2.58, 0.0), (0.16, 0.14, 3.72), bevel=0.02)
    add_box(bm_pillars, (2.86, 2.58, 0.0), (0.16, 0.14, 3.72), bevel=0.02)

    for rx in (-2.42, -1.68, -0.58, 0.58, 1.68, 2.42):
        add_rivet(bm_pillars, (rx, 2.73, -2.17), radius=0.058, height=0.05, normal_dir=(0, 0, -1))
        add_rivet(bm_pillars, (rx, 2.73, 2.17), radius=0.058, height=0.05, normal_dir=(0, 0, 1))
    for rz in (-1.34, -0.68, 0.68, 1.34):
        add_rivet(bm_pillars, (-3.19, 2.73, rz), radius=0.058, height=0.05, normal_dir=(-1, 0, 0))
        add_rivet(bm_pillars, (3.19, 2.73, rz), radius=0.058, height=0.05, normal_dir=(1, 0, 0))

    # 2 vertical intermediate gold ribs on front and back faces (x = +/-1.04)
    for rx in (-INNER_ARCH_X, INNER_ARCH_X):
        for sz in (-1.0, 1.0):
            add_box(bm_pillars, (rx, 1.62, sz * 1.98), (0.28, 2.08, 0.24), bevel=0.045)
            add_box(bm_pillars, (rx, 1.62, sz * 2.08), (0.14, 1.98, 0.10), bevel=0.025)
            for ry in (0.94, 1.62, 2.30):
                add_rivet(bm_pillars, (rx, ry, sz * 2.13), radius=0.044, height=0.036, normal_dir=(0, 0, sz))

    finalize_mesh("Base_CornerPillars", bm_pillars, col, pal["gold_frame"], collidable=True, split_angle_deg=32.0)

    # 3. Base_CrystalWalls (Individual jewel-faceted bays framed cleanly between gold ribs & columns)
    bm_crys = bmesh.new()
    front_back_bays = [(-2.82, -1.14), (-0.94, 0.94), (1.14, 2.82)]
    for b_idx, (bx0, bx1) in enumerate(front_back_bays):
        add_faceted_crystal_panel(
            bm_crys, u0=bx0, u1=bx1, v0=0.58, v1=2.66, w_back=-1.78, w_front=-1.92, nu=3, nv=3, amp=0.080, seed=110 + b_idx, axis="Z", sign=-1.0
        )
        add_faceted_crystal_panel(
            bm_crys, u0=bx0, u1=bx1, v0=0.58, v1=2.66, w_back=1.78, w_front=1.92, nu=3, nv=3, amp=0.080, seed=120 + b_idx, axis="Z", sign=1.0
        )
    add_faceted_crystal_panel(
        bm_crys, u0=-1.74, u1=1.74, v0=0.58, v1=2.66, w_back=-2.82, w_front=-2.96, nu=5, nv=3, amp=0.085, seed=130, axis="X", sign=-1.0
    )
    add_faceted_crystal_panel(
        bm_crys, u0=-1.74, u1=1.74, v0=0.58, v1=2.66, w_back=2.82, w_front=2.96, nu=5, nv=3, amp=0.085, seed=131, axis="X", sign=1.0
    )
    finalize_mesh("Base_CrystalWalls", bm_crys, col, pal["crystal_base"], collidable=True, split_angle_deg=1.5)

    # 4. Base_InnerGlitchCore
    bm_core = bmesh.new()
    add_box(bm_core, (0.0, 1.54, 0.0), (5.52, 1.88, 3.42), bevel=0.14, segments=1)
    core_clusters = [
        (0.0, 2.48, 0.0, 0.55, 0.50),
        (-1.45, 2.42, -0.45, 0.36, 0.40),
        (1.45, 2.42, 0.45, 0.36, 0.40),
        (-1.10, 2.40, 0.65, 0.32, 0.34),
        (1.10, 2.40, -0.65, 0.32, 0.34),
    ]
    for cx, cy, cz, cr, ch in core_clusters:
        add_diamond_gem(bm_core, (cx, cy, cz), radius=cr, height=ch, normal_dir=(0, 1, 0), sides=6, pavilion_depth=0.18)
    finalize_mesh("Base_InnerGlitchCore", bm_core, col, pal["core_base"], collidable=False, split_angle_deg=1.5)

    # 5. Base_LockEscutcheon
    bm_silver = bmesh.new()
    lock_poly = [
        (-0.42, 2.78),
        (0.42, 2.78),
        (0.46, 2.38),
        (0.36, 2.02),
        (0.22, 1.72),
        (0.00, 1.50),
        (-0.22, 1.72),
        (-0.36, 2.02),
        (-0.46, 2.38),
    ]
    add_prism_xy(bm_silver, lock_poly, z0=-2.30, z1=-2.10, bevel=0.04)
    for sx in (-1.0, 1.0):
        add_box(bm_silver, (sx * 0.45, 2.26, -2.23), (0.18, 0.34, 0.16), rot_deg=(0, 0, sx * 12), bevel=0.03)
        add_rivet(bm_silver, (sx * 0.30, 2.58, -2.31), radius=0.035, height=0.028, normal_dir=(0, 0, -1))
    add_bezel_ring(bm_silver, (0.0, 2.24, -2.31), outer_r=0.33, inner_r=0.19, depth=0.13, normal_dir=(0, 0, -1), sides=8)
    add_bezel_ring(bm_silver, (0.0, 1.80, -2.29), outer_r=0.16, inner_r=0.09, depth=0.08, normal_dir=(0, 0, -1), sides=8)

    # Silver corner jewel mount plates & bezels cleanly nested on the 4 corners & 4 feet
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            # Front/back corner shield lower silver mount + bezel
            add_box(bm_silver, (sx * 3.12, 2.40, sz * 2.22), (0.32, 0.30, 0.14), bevel=0.03)
            add_bezel_ring(bm_silver, (sx * 3.12, 2.40, sz * 2.30), outer_r=0.16, inner_r=0.095, depth=0.08, normal_dir=(0, 0, sz), sides=8)
            # Left/right side corner shield silver mount + bezel
            add_box(bm_silver, (sx * 3.30, 2.40, sz * 2.00), (0.14, 0.30, 0.32), bevel=0.03)
            add_bezel_ring(bm_silver, (sx * 3.38, 2.40, sz * 2.00), outer_r=0.16, inner_r=0.095, depth=0.08, normal_dir=(sx, 0, 0), sides=8)
            # Upper corner shield diagonal silver bezel seated neatly in front of the gold crest
            diag_n = Vector((sx * 0.72, 0.12, sz * 0.72)).normalized()
            add_bezel_ring(
                bm_silver,
                (sx * 3.38, 2.78, sz * 2.24),
                outer_r=0.145,
                inner_r=0.085,
                depth=0.075,
                normal_dir=(diag_n.x, diag_n.y, diag_n.z),
                sides=8,
            )
            # Base foot diagonal silver bezel mount cleanly centered in pocket
            foot_n = Vector((sx * 0.70, 0.38, sz * 0.70)).normalized()
            add_bezel_ring(
                bm_silver,
                (sx * 3.30, 0.33, sz * 2.22),
                outer_r=0.175,
                inner_r=0.105,
                depth=0.085,
                normal_dir=(foot_n.x, foot_n.y, foot_n.z),
                sides=8,
            )

    # Side lower silver clasp shields seated flush on left/right side walls
    for sx in (-1.0, 1.0):
        side_pts = [(-0.22, 2.84), (0.22, 2.84), (0.24, 2.46), (0.14, 2.14), (0.0, 1.94), (-0.14, 2.14), (-0.24, 2.46)]
        tmp_s = bmesh.new()
        vf = [tmp_s.verts.new((sx * 2.94, y, z)) for (z, y) in side_pts]
        vb = [tmp_s.verts.new((sx * 3.12, y, z)) for (z, y) in side_pts]
        n = len(side_pts)
        tmp_s.faces.new(list(reversed(vf)))
        tmp_s.faces.new(vb)
        for i in range(n):
            ni = (i + 1) % n
            tmp_s.faces.new((vf[i], vf[ni], vb[ni], vb[i]))
        bmesh.ops.recalc_face_normals(tmp_s, faces=tmp_s.faces)
        bmesh.ops.bevel(tmp_s, geom=list(tmp_s.edges), offset=0.025, segments=1, affect="EDGES", clamp_overlap=True)
        merge_bmesh_rbx(bm_silver, tmp_s)
        tmp_s.free()
        add_bezel_ring(bm_silver, (sx * 3.13, 2.42, 0.0), outer_r=0.145, inner_r=0.085, depth=0.07, normal_dir=(sx, 0, 0), sides=8)

    finalize_mesh("Base_LockEscutcheon", bm_silver, col, pal["silver_base"], collidable=True, split_angle_deg=30.0)

    # 6. Base_DiamondGems
    bm_gems = bmesh.new()
    add_diamond_gem(bm_gems, (0.0, 2.24, -2.35), radius=0.20, height=0.12, normal_dir=(0, 0, -1), sides=8, aspect_y=1.08)
    add_diamond_gem(bm_gems, (0.0, 1.80, -2.31), radius=0.10, height=0.07, normal_dir=(0, 0, -1), sides=8)

    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            add_diamond_gem(bm_gems, (sx * 3.12, 2.40, sz * 2.32), radius=0.105, height=0.07, normal_dir=(0, 0, sz), sides=8)
            add_diamond_gem(bm_gems, (sx * 3.40, 2.40, sz * 2.00), radius=0.105, height=0.07, normal_dir=(sx, 0, 0), sides=8)
            diag_n = Vector((sx * 0.72, 0.12, sz * 0.72)).normalized()
            add_diamond_gem(
                bm_gems,
                (sx * 3.40, 2.79, sz * 2.26),
                radius=0.095,
                height=0.07,
                normal_dir=(diag_n.x, diag_n.y, diag_n.z),
                sides=8,
            )
            foot_n = Vector((sx * 0.70, 0.38, sz * 0.70)).normalized()
            add_diamond_gem(
                bm_gems,
                (sx * 3.32, 0.35, sz * 2.24),
                radius=0.115,
                height=0.08,
                normal_dir=(foot_n.x, foot_n.y, foot_n.z),
                sides=8,
            )
        add_diamond_gem(bm_gems, (sx * 3.15, 2.42, 0.0), radius=0.095, height=0.065, normal_dir=(sx, 0, 0), sides=8)

    finalize_mesh("Base_DiamondGems", bm_gems, col, pal["diamond_gem"], collidable=False, split_angle_deg=1.5)
    return col


# ---------------------------------------------------------------------------
# Sub-collection 2: ChestLid (Hinged Upper Barrel Dome)
# ---------------------------------------------------------------------------

def _arch_point_yz(theta_deg: float, z_rad: float = ARCH_HALF_D, y_rise: float = ARCH_RISE) -> tuple[float, float]:
    rad = math.radians(theta_deg)
    return (BASE_TOP_Y + math.cos(rad) * y_rise, math.sin(rad) * z_rad)


def _arch_normal_yz(theta_deg: float, z_rad: float = ARCH_HALF_D, y_rise: float = ARCH_RISE) -> Vector:
    rad = math.radians(theta_deg)
    ny = math.cos(rad) / max(1e-4, y_rise)
    nz = math.sin(rad) / max(1e-4, z_rad)
    return Vector((0.0, ny, nz)).normalized()


def _add_barrel_arch_rib(
    bm: bmesh.types.BMesh,
    x_center: float,
    half_w: float,
    z_outer: float,
    y_outer: float,
    thickness: float,
    steps: int = 16,
) -> None:
    """Lofts a smoothly beveled rectangular golden arch band spanning theta in [-90, +90] deg."""
    rings = []
    chamfer = min(half_w, thickness) * 0.22
    for i in range(steps + 1):
        t = -90.0 + (180.0 * i) / steps
        yo, zo = _arch_point_yz(t, z_outer, y_outer)
        n = _arch_normal_yz(t, z_outer, y_outer)
        p_out = Vector((x_center, yo, zo))
        p_in = p_out - n * thickness
        hw = half_w
        hw_i = half_w - chamfer
        ring = [
            p_in + Vector((-hw_i, 0.0, 0.0)),
            p_in + Vector((hw_i, 0.0, 0.0)),
            p_in + Vector((hw, 0.0, 0.0)) + n * chamfer,
            p_out + Vector((hw, 0.0, 0.0)) - n * chamfer,
            p_out + Vector((hw_i, 0.0, 0.0)),
            p_out + Vector((-hw_i, 0.0, 0.0)),
            p_out + Vector((-hw, 0.0, 0.0)) - n * chamfer,
            p_in + Vector((-hw, 0.0, 0.0)) + n * chamfer,
        ]
        rings.append(ring)
    add_loft(bm, rings, cap_ends=True)


def _add_side_arch_crest(bm: bmesh.types.BMesh, sx: float) -> None:
    """Sculpts a bold winged fleur-de-lis / diamond crest medallion at the apex of each outer side arch."""
    cx = sx * (ARCH_CENTER_X + 0.17)
    cy = BASE_TOP_Y + ARCH_RISE - 0.14
    add_box(bm, (cx, cy, 0.0), (0.14, 0.40, 0.40), rot_deg=(45, 0, 0), bevel=0.03)
    add_box(bm, (cx + sx * 0.03, cy + 0.24, 0.0), (0.12, 0.28, 0.22), rot_deg=(45, 0, 0), bevel=0.025)
    add_box(bm, (cx + sx * 0.03, cy - 0.26, 0.0), (0.12, 0.24, 0.18), rot_deg=(45, 0, 0), bevel=0.025)
    for sz in (-1.0, 1.0):
        add_box(bm, (cx, cy + 0.06, sz * 0.30), (0.12, 0.18, 0.28), rot_deg=(sz * 24, 0, 0), bevel=0.025)
    add_rivet(bm, (cx + sx * 0.08, cy, 0.0), radius=0.075, height=0.055, normal_dir=(sx, 0, 0))


def build_chest_lid(root_col: bpy.types.Collection, pal: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    col = get_or_create_collection("ChestLid", root_col)

    # 1. Lid_GoldArches
    bm_arches = bmesh.new()
    add_box(bm_arches, (0.0, 2.98, -2.02), (6.12, 0.26, 0.26), bevel=0.035)
    add_box(bm_arches, (0.0, 2.98, 2.02), (6.12, 0.26, 0.26), bevel=0.035)
    add_box(bm_arches, (-ARCH_CENTER_X, 2.98, 0.0), (0.32, 0.26, 4.18), bevel=0.035)
    add_box(bm_arches, (ARCH_CENTER_X, 2.98, 0.0), (0.32, 0.26, 4.18), bevel=0.035)

    for sx in (-1.0, 1.0):
        _add_barrel_arch_rib(bm_arches, sx * ARCH_CENTER_X, half_w=0.17, z_outer=2.15, y_outer=1.80, thickness=0.22, steps=18)
        _add_barrel_arch_rib(bm_arches, sx * INNER_ARCH_X, half_w=0.12, z_outer=2.12, y_outer=1.77, thickness=0.17, steps=18)
        _add_side_arch_crest(bm_arches, sx)

    for t in (-74.0, -56.0, -38.0, -20.0, 20.0, 38.0, 56.0, 74.0):
        yo, zo = _arch_point_yz(t, 2.15, 1.80)
        n = _arch_normal_yz(t, 2.15, 1.80)
        for ax in (-ARCH_CENTER_X, -INNER_ARCH_X, INNER_ARCH_X, ARCH_CENTER_X):
            pos = Vector((ax, yo, zo)) + n * 0.015
            add_rivet(bm_arches, (pos.x, pos.y, pos.z), radius=0.046, height=0.040, normal_dir=(n.x, n.y, n.z))
    for t in (-68.0, -45.0, -22.0, 22.0, 45.0, 68.0):
        yo, zo = _arch_point_yz(t, 2.04, 1.69)
        for sx in (-1.0, 1.0):
            add_rivet(bm_arches, (sx * (ARCH_CENTER_X + 0.17), yo, zo), radius=0.046, height=0.038, normal_dir=(sx, 0, 0))
    for rx in (-2.42, -1.68, -0.58, 0.58, 1.68, 2.42):
        add_rivet(bm_arches, (rx, 2.99, -2.16), radius=0.052, height=0.042, normal_dir=(0, 0, -1))
        add_rivet(bm_arches, (rx, 2.99, 2.16), radius=0.052, height=0.042, normal_dir=(0, 0, 1))
    for rz in (-1.34, -0.68, 0.68, 1.34):
        add_rivet(bm_arches, (-ARCH_CENTER_X - 0.17, 2.99, rz), radius=0.052, height=0.042, normal_dir=(-1, 0, 0))
        add_rivet(bm_arches, (ARCH_CENTER_X + 0.17, 2.99, rz), radius=0.052, height=0.042, normal_dir=(1, 0, 0))

    finalize_mesh("Lid_GoldArches", bm_arches, col, pal["gold_frame"], collidable=True, split_angle_deg=32.0)

    # 2. Lid_CrystalDome (Bolder faceted crystal planes across 3 dome bays + end lunettes)
    bm_dome = bmesh.new()
    rng_dome = random.Random(205)
    bays = [(-2.88, -1.14), (-0.94, 0.94), (1.14, 2.88)]
    nx_bay = 3
    nt_bay = 8
    z_out, y_out = 2.01, 1.68
    z_in, y_in = 1.82, 1.50

    for b_idx, (bx0, bx1) in enumerate(bays):
        tmp = bmesh.new()
        out_grid, in_grid = [], []
        for it in range(nt_bay + 1):
            theta = -86.0 + (172.0 * it) / nt_bay
            yo, zo = _arch_point_yz(theta, z_out, y_out)
            yi, zi = _arch_point_yz(theta, z_in, y_in)
            n = _arch_normal_yz(theta, z_out, y_out)
            row_o, row_i = [], []
            for ix in range(nx_bay + 1):
                tx = ix / nx_bay
                xb = bx0 + (bx1 - bx0) * tx
                is_edge = ix == 0 or ix == nx_bay or it == 0 or it == nt_bay
                dx = 0.0 if (ix == 0 or ix == nx_bay) else rng_dome.uniform(-0.18, 0.18) * ((bx1 - bx0) / nx_bay)
                dn = 0.0 if is_edge else rng_dome.uniform(-0.035, 0.088)
                p_o = Vector((xb + dx, yo, zo)) + n * dn
                p_i = Vector((xb, yi, zi))
                row_o.append(tmp.verts.new(p_o))
                row_i.append(tmp.verts.new(p_i))
            out_grid.append(row_o)
            in_grid.append(row_i)

        for it in range(nt_bay):
            for ix in range(nx_bay):
                a, b = out_grid[it][ix], out_grid[it][ix + 1]
                c, d = out_grid[it + 1][ix + 1], out_grid[it + 1][ix]
                if (ix + it + b_idx) % 2 == 0:
                    tmp.faces.new((a, b, c))
                    tmp.faces.new((a, c, d))
                else:
                    tmp.faces.new((a, b, d))
                    tmp.faces.new((b, c, d))
                ia, ib = in_grid[it][ix], in_grid[it][ix + 1]
                ic, id_ = in_grid[it + 1][ix + 1], in_grid[it + 1][ix]
                tmp.faces.new((ia, id_, ic, ib))

        for ix in range(nx_bay):
            tmp.faces.new((in_grid[0][ix], in_grid[0][ix + 1], out_grid[0][ix + 1], out_grid[0][ix]))
            tmp.faces.new((out_grid[nt_bay][ix], out_grid[nt_bay][ix + 1], in_grid[nt_bay][ix + 1], in_grid[nt_bay][ix]))
        for it in range(nt_bay):
            tmp.faces.new((out_grid[it][0], out_grid[it + 1][0], in_grid[it + 1][0], in_grid[it][0]))
            tmp.faces.new((in_grid[it][nx_bay], in_grid[it + 1][nx_bay], out_grid[it + 1][nx_bay], out_grid[it][nx_bay]))

        merge_bmesh_rbx(bm_dome, tmp)
        tmp.free()

    # End-cap semi-circular faceted crystal lunettes under outer arches
    for sx in (-1.0, 1.0):
        rng_lun = random.Random(305 + int(sx))
        tmp = bmesh.new()
        x_out = sx * 2.92
        x_in = sx * 2.74
        n_rings, n_segs = 2, 8
        center_o = tmp.verts.new((x_out + sx * 0.06, BASE_TOP_Y + 0.08, 0.0))
        center_i = tmp.verts.new((x_in, BASE_TOP_Y + 0.08, 0.0))
        rings_o, rings_i = [], []
        for ir in range(1, n_rings + 1):
            frac = ir / n_rings
            ro, ri = [], []
            for iseg in range(n_segs + 1):
                ang = -90.0 + (180.0 * iseg) / n_segs
                yy = BASE_TOP_Y + 0.04 + math.cos(math.radians(ang)) * (1.58 * frac)
                zz = math.sin(math.radians(ang)) * (1.94 * frac)
                dx = 0.0 if (ir == n_rings or iseg == 0 or iseg == n_segs) else rng_lun.uniform(-0.025, 0.085)
                ro.append(tmp.verts.new((x_out + sx * dx, yy, zz)))
                ri.append(tmp.verts.new((x_in, yy, zz)))
            rings_o.append(ro)
            rings_i.append(ri)

        for iseg in range(n_segs):
            tmp.faces.new((center_o, rings_o[0][iseg], rings_o[0][iseg + 1]))
            tmp.faces.new((center_i, rings_i[0][iseg + 1], rings_i[0][iseg]))
        for ir in range(n_rings - 1):
            for iseg in range(n_segs):
                a, b = rings_o[ir][iseg], rings_o[ir][iseg + 1]
                c, d = rings_o[ir + 1][iseg + 1], rings_o[ir + 1][iseg]
                if (ir + iseg) % 2 == 0:
                    tmp.faces.new((a, b, c))
                    tmp.faces.new((a, c, d))
                else:
                    tmp.faces.new((a, b, d))
                    tmp.faces.new((b, c, d))
                ia, ib = rings_i[ir][iseg], rings_i[ir][iseg + 1]
                ic, id_ = rings_i[ir + 1][iseg + 1], rings_i[ir + 1][iseg]
                tmp.faces.new((ia, id_, ic, ib))
        for iseg in range(n_segs):
            tmp.faces.new((rings_o[-1][iseg], rings_i[-1][iseg], rings_i[-1][iseg + 1], rings_o[-1][iseg + 1]))
        chord_o = [rings_o[-1][0], rings_o[0][0], center_o, rings_o[0][-1], rings_o[-1][-1]]
        chord_i = [rings_i[-1][0], rings_i[0][0], center_i, rings_i[0][-1], rings_i[-1][-1]]
        for k in range(len(chord_o) - 1):
            tmp.faces.new((chord_o[k], chord_o[k + 1], chord_i[k + 1], chord_i[k]))

        merge_bmesh_rbx(bm_dome, tmp)
        tmp.free()

    finalize_mesh("Lid_CrystalDome", bm_dome, col, pal["crystal_lid"], collidable=True, split_angle_deg=1.5)

    # 3. Lid_InnerCore
    bm_lcore = bmesh.new()
    tmp_lc = bmesh.new()
    n_c = 12
    x0_c, x1_c = -2.68, 2.68
    grid_lo, grid_li = [], []
    for it in range(n_c + 1):
        theta = -86.0 + (172.0 * it) / n_c
        yo, zo = _arch_point_yz(theta, 1.76, 1.44)
        yi, zi = _arch_point_yz(theta, 1.46, 1.16)
        grid_lo.append((tmp_lc.verts.new((x0_c, yo, zo)), tmp_lc.verts.new((x1_c, yo, zo))))
        grid_li.append((tmp_lc.verts.new((x0_c, yi, zi)), tmp_lc.verts.new((x1_c, yi, zi))))

    for it in range(n_c):
        tmp_lc.faces.new((grid_lo[it][0], grid_lo[it][1], grid_lo[it + 1][1], grid_lo[it + 1][0]))
        tmp_lc.faces.new((grid_li[it][0], grid_li[it + 1][0], grid_li[it + 1][1], grid_li[it][1]))
        tmp_lc.faces.new((grid_lo[it][0], grid_lo[it + 1][0], grid_li[it + 1][0], grid_li[it][0]))
        tmp_lc.faces.new((grid_lo[it][1], grid_li[it][1], grid_li[it + 1][1], grid_lo[it + 1][1]))
    tmp_lc.faces.new((grid_li[0][0], grid_li[0][1], grid_lo[0][1], grid_lo[0][0]))
    tmp_lc.faces.new((grid_lo[n_c][0], grid_lo[n_c][1], grid_li[n_c][1], grid_li[n_c][0]))
    merge_bmesh_rbx(bm_lcore, tmp_lc)
    tmp_lc.free()
    finalize_mesh("Lid_InnerCore", bm_lcore, col, pal["core_lid"], collidable=False, split_angle_deg=1.5)

    # 4. Lid_CrownMount
    bm_crown = bmesh.new()
    def oct_pts(rx: float, rz: float) -> list[tuple[float, float]]:
        return [
            (math.cos(math.pi / 8.0 + k * math.pi / 4.0) * rx, math.sin(math.pi / 8.0 + k * math.pi / 4.0) * rz)
            for k in range(8)
        ]
    add_prism_xz(bm_crown, oct_pts(0.74, 0.66), y0=4.48, y1=4.74, bevel=0.04)
    add_prism_xz(bm_crown, oct_pts(0.64, 0.56), y0=4.72, y1=4.88, bevel=0.03)
    add_prism_xz(bm_crown, oct_pts(0.54, 0.46), y0=4.85, y1=4.95, bevel=0.02)
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            add_box(bm_crown, (sx * 0.44, 4.94, sz * 0.36), (0.14, 0.20, 0.14), rot_deg=(sz * -14, 0, sx * 14), bevel=0.025)
    for sz in (-1.0, 1.0):
        add_box(bm_crown, (0.0, 4.82, sz * 0.55), (0.34, 0.24, 0.10), bevel=0.02)
    finalize_mesh("Lid_CrownMount", bm_crown, col, pal["gold_crown"], collidable=True, split_angle_deg=30.0)

    # 5. Lid_ApexDiamond
    bm_apex = bmesh.new()
    tmp_d = bmesh.new()
    sides_d = 10
    r_girdle_x, r_girdle_z = 0.52, 0.43
    r_table_x, r_table_z = 0.30, 0.24
    y_bot, y_mid, y_top, y_peak = 4.86, 5.05, 5.30, 5.40
    r0, r1, r2 = [], [], []
    for i in range(sides_d):
        ang = (2.0 * math.pi * i) / sides_d + math.pi / sides_d
        cx, cz = math.cos(ang), math.sin(ang)
        r0.append(tmp_d.verts.new((cx * r_girdle_x * 0.85, y_bot, cz * r_girdle_z * 0.85)))
        r1.append(tmp_d.verts.new((cx * r_girdle_x, y_mid, cz * r_girdle_z)))
        r2.append(tmp_d.verts.new((cx * r_table_x, y_top, cz * r_table_z)))
    v_peak = tmp_d.verts.new((0.0, y_peak, 0.0))
    tmp_d.faces.new(list(reversed(r0)))
    for i in range(sides_d):
        ni = (i + 1) % sides_d
        tmp_d.faces.new((r0[i], r0[ni], r1[ni], r1[i]))
        tmp_d.faces.new((r1[i], r1[ni], r2[ni], r2[i]))
        tmp_d.faces.new((r2[i], r2[ni], v_peak))
    merge_bmesh_rbx(bm_apex, tmp_d)
    tmp_d.free()

    add_diamond_gem(bm_apex, (0.0, 4.84, -0.61), radius=0.085, height=0.055, normal_dir=(0, 0.15, -1), sides=8)
    add_diamond_gem(bm_apex, (0.0, 4.84, 0.61), radius=0.085, height=0.055, normal_dir=(0, 0.15, 1), sides=8)
    add_diamond_gem(bm_apex, (0.0, 3.26, -2.18), radius=0.105, height=0.065, normal_dir=(0, 0.35, -1), sides=8)
    for sx in (-1.0, 1.0):
        add_diamond_gem(bm_apex, (sx * 3.12, 3.16, 0.0), radius=0.085, height=0.055, normal_dir=(sx, 0.15, 0), sides=8)

    finalize_mesh("Lid_ApexDiamond", bm_apex, col, pal["apex_diamond"], collidable=False, split_angle_deg=1.5)

    # 6. Lid_FrontClasp
    bm_clasp = bmesh.new()
    add_box(bm_clasp, (0.0, 2.82, -2.26), (0.88, 0.24, 0.20), bevel=0.04)
    add_box(bm_clasp, (0.0, 2.74, -2.30), (0.64, 0.16, 0.14), bevel=0.03)
    for sx in (-1.0, 1.0):
        add_box(bm_clasp, (sx * 0.42, 2.84, -2.29), (0.14, 0.14, 0.14), rot_deg=(0, 0, 45), bevel=0.02)

    clasp_steps = [
        (2.88, -2.22, 0.38),
        (3.04, -2.18, 0.42),
        (3.22, -2.11, 0.36),
        (3.40, -2.01, 0.24),
        (3.58, -1.89, 0.08),
    ]
    c_rings = []
    for cy, cz, hw in clasp_steps:
        c_rings.append([
            Vector((-hw, cy, cz + 0.08)),
            Vector((hw, cy, cz + 0.08)),
            Vector((hw * 0.84, cy, cz - 0.06)),
            Vector((-hw * 0.84, cy, cz - 0.06)),
        ])
    add_loft(bm_clasp, c_rings, cap_ends=True)
    add_bezel_ring(bm_clasp, (0.0, 3.25, -2.15), outer_r=0.16, inner_r=0.095, depth=0.07, normal_dir=(0, 0.35, -1), sides=8)
    for sx in (-1.0, 1.0):
        add_rivet(bm_clasp, (sx * 0.26, 3.04, -2.24), radius=0.036, height=0.03, normal_dir=(0, 0.25, -1))
        add_rivet(bm_clasp, (sx * 0.16, 3.44, -2.04), radius=0.032, height=0.026, normal_dir=(0, 0.4, -1))

    # Side upper silver spade clasps flush with Base_LockEscutcheon's side shields
    for sx in (-1.0, 1.0):
        add_box(bm_clasp, (sx * 3.03, 3.14, 0.0), (0.16, 0.56, 0.38), rot_deg=(0, 0, sx * 8), bevel=0.03)
        add_box(bm_clasp, (sx * 2.98, 3.44, 0.0), (0.14, 0.20, 0.20), rot_deg=(45, 0, sx * 12), bevel=0.025)
        add_bezel_ring(bm_clasp, (sx * 3.11, 3.15, 0.0), outer_r=0.13, inner_r=0.08, depth=0.06, normal_dir=(sx, 0.15, 0), sides=8)

    finalize_mesh("Lid_FrontClasp", bm_clasp, col, pal["silver_clasp"], collidable=True, split_angle_deg=30.0)
    return col


# ---------------------------------------------------------------------------
# Sub-collection 3: ChestGlitch (6 Individual Floating Glitch Shards)
# ---------------------------------------------------------------------------

def _add_glitch_shard_geom(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    length: float,
    radius: float,
    rot_deg: tuple[float, float, float],
    seed: int,
) -> None:
    """Sculpts a jagged faceted low-poly crystal/glitch prism shard with stepped glitch wings."""
    rng = random.Random(seed)
    tmp = bmesh.new()

    def build_prism_blade(offset: Vector, blen: float, brad: float, tilt_deg: tuple[float, float, float]) -> None:
        sub = bmesh.new()
        sides = 5
        v_bot = sub.verts.new((0.0, -blen * 0.52, 0.0))
        v_top = sub.verts.new((0.0, blen * 0.56, 0.0))
        r_low, r_hi = [], []
        for i in range(sides):
            ang = (2.0 * math.pi * i) / sides + rng.uniform(-0.18, 0.18)
            rad_l = brad * rng.uniform(0.75, 1.15)
            rad_h = brad * rng.uniform(0.55, 0.92)
            r_low.append(sub.verts.new((math.cos(ang) * rad_l, -blen * 0.18, math.sin(ang) * rad_l)))
            r_hi.append(sub.verts.new((math.cos(ang) * rad_h, blen * 0.22, math.sin(ang) * rad_h)))
        for i in range(sides):
            ni = (i + 1) % sides
            sub.faces.new((v_bot, r_low[ni], r_low[i]))
            sub.faces.new((r_low[i], r_low[ni], r_hi[ni], r_hi[i]))
            sub.faces.new((r_hi[i], r_hi[ni], v_top))
        bmesh.ops.recalc_face_normals(sub, faces=sub.faces)
        rot_m = Euler([math.radians(a) for a in tilt_deg], "XYZ").to_matrix().to_4x4()
        bmesh.ops.transform(sub, matrix=Matrix.Translation(offset) @ rot_m, verts=sub.verts)
        vmap = {v.index: tmp.verts.new(v.co) for v in sub.verts}
        for f in sub.faces:
            tmp.faces.new([vmap[v.index] for v in f.verts])
        sub.free()

    build_prism_blade(Vector((0.0, 0.0, 0.0)), length, radius, (0.0, 0.0, 0.0))
    build_prism_blade(
        Vector((radius * 0.65, -length * 0.12, radius * 0.25)),
        length * 0.58,
        radius * 0.56,
        (rng.uniform(-16, 16), rng.uniform(-25, 25), rng.uniform(-18, 18)),
    )
    build_prism_blade(
        Vector((-radius * 0.55, length * 0.10, -radius * 0.30)),
        length * 0.48,
        radius * 0.48,
        (rng.uniform(-16, 16), rng.uniform(-25, 25), rng.uniform(-18, 18)),
    )

    rot = Euler([math.radians(a) for a in rot_deg], "XYZ").to_matrix().to_4x4()
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(Vector(center)) @ rot, verts=tmp.verts)
    merge_bmesh_rbx(bm, tmp)
    tmp.free()


def build_chest_glitch(root_col: bpy.types.Collection, pal: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    col = get_or_create_collection("ChestGlitch", root_col)
    # 6 shards orbiting around radii 3.8..4.6, heights y = 1.4..5.2, cleanly framing chest silhouette
    shard_specs = [
        ("Glitch_Shard_1", (3.20, 4.05, 2.75), 0.96, 0.19, (22.0, -18.0, 28.0), "glitch_blue", 401),
        ("Glitch_Shard_2", (4.15, 1.75, 0.65), 0.86, 0.18, (-18.0, 24.0, -26.0), "glitch_cyan", 402),
        ("Glitch_Shard_3", (1.15, 5.10, 3.95), 0.92, 0.18, (15.0, 42.0, -19.0), "glitch_blue", 403),
        ("Glitch_Shard_4", (-3.75, 4.85, 2.05), 0.88, 0.17, (-24.0, -35.0, 20.0), "glitch_cyan", 404),
        ("Glitch_Shard_5", (-4.15, 3.25, -1.85), 0.84, 0.17, (16.0, 12.0, -32.0), "glitch_blue", 405),
        ("Glitch_Shard_6", (-2.65, 1.65, -3.25), 0.86, 0.17, (-28.0, 15.0, 14.0), "glitch_cyan", 406),
    ]
    for name, pos, slen, srad, rot_deg, mat_key, seed in shard_specs:
        bm = bmesh.new()
        _add_glitch_shard_geom(bm, pos, slen, srad, rot_deg, seed)
        finalize_mesh(name, bm, col, pal[mat_key], collidable=False, split_angle_deg=1.5)
    return col


# ---------------------------------------------------------------------------
# Export (FBX + Manifest + Packed BMesh Luau Shards + Previews)
# ---------------------------------------------------------------------------

def extract_part_geometry(obj: bpy.types.Object, sub_col_name: str) -> dict:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.verts.ensure_lookup_table()

    # Convert Blender Z-up back to Roblox Y-up: (bx, by, bz) -> (bx, bz, -by)
    pts = [(v.co.x, v.co.z, -v.co.y) for v in bm.verts]
    xs, ys, zs = [p[0] for p in pts], [p[1] for p in pts], [p[2] for p in pts]
    cx, cy, cz = (min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5
    sx, sy, sz = max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)

    flat_verts = []
    for px, py, pz in pts:
        flat_verts.extend([round(px - cx, 4), round(py - cy, 4), round(pz - cz, 4)])
    flat_tris = []
    for f in bm.faces:
        if len(f.verts) == 3:
            flat_tris.extend([f.verts[0].index + 1, f.verts[1].index + 1, f.verts[2].index + 1])
    bm.free()

    tri_count = len(flat_tris) // 3
    if tri_count > MAX_TRIS_PER_PART:
        raise RuntimeError(f"Part {obj.name} exceeded {MAX_TRIS_PER_PART} triangles ({tri_count})")
    if sx <= 1e-4 or sy <= 1e-4 or sz <= 1e-4:
        raise RuntimeError(f"Part {obj.name} has degenerate bounding box ({sx}, {sy}, {sz})")

    mat = obj.data.materials[0] if obj.data.materials else None
    clean_name = re.sub(r"\.\d+$", "", obj.name)
    return {
        "Name": clean_name,
        "SubCollection": sub_col_name,
        "Offset": [round(cx, 4), round(cy, 4), round(cz, 4)],
        "Size": [round(sx, 4), round(sy, 4), round(sz, 4)],
        "Material": mat.get("rbx_material", "Metal") if mat else "Metal",
        "Color": list(mat.get("rbx_color", [238, 186, 78])) if mat else [238, 186, 78],
        "Transparency": round(float(mat.get("rbx_transparency", 0.0)), 4) if mat else 0.0,
        "Collidable": bool(obj.get("rbx_collidable", True)),
        "MeshId": "",
        "Triangles": tri_count,
        "VertCount": len(pts),
        "Verts": flat_verts,
        "Tris": flat_tris,
    }


def load_uploaded_mesh_ids() -> dict:
    path = os.path.join(OUT_DIR, "mesh_ids.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def export_group_chest(root_col: bpy.types.Collection) -> tuple[dict, list[dict]]:
    os.makedirs(OUT_DIR, exist_ok=True)
    sub_cols = list(root_col.children)
    objs = []
    obj_sub_pairs = []
    for sub_col in sub_cols:
        for obj in sub_col.objects:
            if obj.type == "MESH":
                objs.append(obj)
                obj_sub_pairs.append((obj, sub_col.name))

    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active = objs[0]

    fbx_path = os.path.join(OUT_DIR, "group_chest.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="EDGE",
        add_leaf_bones=False,
        bake_anim=False,
        use_mesh_modifiers=True,
        bake_space_transform=True,
    )

    uploaded = load_uploaded_mesh_ids().get("group_chest", {})
    parts_full, parts_summary, tri_count = [], [], 0
    for obj, sub_name in obj_sub_pairs:
        pinfo = extract_part_geometry(obj, sub_name)
        pinfo["MeshId"] = uploaded.get(pinfo["Name"], "")
        tri_count += pinfo["Triangles"]
        parts_full.append(pinfo)
        parts_summary.append({k: v for k, v in pinfo.items() if k not in ("Verts", "Tris")})

    summary = {
        "TemplateId": "group_chest",
        "FBX": os.path.basename(fbx_path),
        "HingePivot": list(HINGE_PIVOT),
        "Triangles": tri_count,
        "PartCount": len(parts_summary),
        "Parts": parts_summary,
    }
    return summary, parts_full


def _wrap_b64(s: str, width: int = 120) -> str:
    return "\n".join(s[i:i + width] for i in range(0, len(s), width))


def _encode_part_buffers(p: dict) -> tuple[str, str]:
    verts, tris = p["Verts"], p["Tris"]
    sx, sy, sz = p["Size"]
    hx, hy, hz = max(1e-5, sx * 0.5), max(1e-5, sy * 0.5), max(1e-5, sz * 0.5)
    vmap: dict[tuple[int, int, int], int] = {}
    remap = [0] * (len(verts) // 3 + 1)
    vbuf = bytearray()
    uniq_idx = 0
    for idx, i in enumerate(range(0, len(verts), 3), start=1):
        qx = max(-32767, min(32767, round((verts[i] / hx) * 32767.0)))
        qy = max(-32767, min(32767, round((verts[i + 1] / hy) * 32767.0)))
        qz = max(-32767, min(32767, round((verts[i + 2] / hz) * 32767.0)))
        key = (qx, qy, qz)
        mapped = vmap.get(key)
        if mapped is None:
            uniq_idx += 1
            mapped = uniq_idx
            vmap[key] = mapped
            vbuf.extend(struct.pack("<hhh", qx, qy, qz))
        remap[idx] = mapped
    tbuf = bytearray()
    prev = 0
    for ti in tris:
        cur = remap[ti]
        d = cur - prev
        prev = cur
        zz = (d << 1) if d >= 0 else ((-d) << 1) - 1
        while zz >= 128:
            tbuf.append((zz & 127) | 128)
            zz >>= 7
        tbuf.append(zz)
    return base64.b64encode(bytes(vbuf)).decode("ascii"), base64.b64encode(bytes(tbuf)).decode("ascii")


def write_luau_mesh_modules(parts_full: list[dict]) -> None:
    os.makedirs(SHARDS_DIR, exist_ok=True)
    shard_path = os.path.join(SHARDS_DIR, "group_chest.luau")
    lines = [
        "--!nocheck",
        "-- ReplicatedStorage/Assets/GroupChestMeshes/group_chest.luau",
        "-- Generated directly from Blender geometry (tools/blender/generate_group_chest.py).",
        "",
        "return {",
    ]
    for p in parts_full:
        c, o, s = p["Color"], p["Offset"], p["Size"]
        vb, tb = _encode_part_buffers(p)
        col_lit = "true" if p["Collidable"] else "false"
        mesh_lit = f'"{p.get("MeshId", "")}"'
        lines.extend([
            "\t{",
            f'\t\tName = "{p["Name"]}", SubCollection = "{p["SubCollection"]}",',
            f"\t\tOffset = Vector3.new({o[0]}, {o[1]}, {o[2]}), Size = Vector3.new({s[0]}, {s[1]}, {s[2]}),",
            f'\t\tMaterial = Enum.Material.{p["Material"]}, Color = Color3.fromRGB({c[0]}, {c[1]}, {c[2]}), Transparency = {p["Transparency"]},',
            f"\t\tCollidable = {col_lit}, MeshId = {mesh_lit},",
            f"\t\tVB = [[\n{_wrap_b64(vb)}\n]],",
            f"\t\tTB = [[\n{_wrap_b64(tb)}\n]],",
            "\t},",
        ])
    lines.append("}")
    with open(shard_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Wrote group chest shard: {shard_path} ({os.path.getsize(shard_path)} bytes)")

    hp = HINGE_PIVOT
    loader_src = f"""--!strict
-- ReplicatedStorage/Assets/GroupChestMeshData.luau
-- Decodes Blender-authored Group Chest geometry shards from ReplicatedStorage.Assets.GroupChestMeshes.

local GroupChestMeshData = {{}}

GroupChestMeshData.HingePivot = Vector3.new({hp[0]}, {hp[1]}, {hp[2]})

export type PartMeshSpec = {{
\tName: string,
\tSubCollection: string,
\tOffset: Vector3,
\tSize: Vector3,
\tMaterial: Enum.Material,
\tColor: Color3,
\tTransparency: number,
\tCollidable: boolean,
\tMeshId: string,
\tVB: string?,
\tTB: string?,
\tVerts: {{ number }}?,
\tTris: {{ number }}?,
}}

local B64_LOOKUP = table.create(256, -1)
do
\tlocal alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
\tfor i = 1, #alphabet do
\t\tB64_LOOKUP[string.byte(alphabet, i)] = i - 1
\tend
end

local function decodeBase64(str: string): buffer
\tstr = string.gsub(str, "%s+", "")
\tlocal len = #str
\tif len == 0 then
\t\treturn buffer.create(0)
\tend
\tlocal pad = if len >= 2 and string.sub(str, len - 1, len) == "==" then 2 elseif len >= 1 and string.sub(str, len, len) == "=" then 1 else 0
\tlocal outLen = (len // 4) * 3 - pad
\tlocal buf = buffer.create(outLen)
\tlocal outPos = 0
\tfor i = 1, len, 4 do
\t\tlocal a = B64_LOOKUP[string.byte(str, i)] or 0
\t\tlocal b = B64_LOOKUP[string.byte(str, i + 1)] or 0
\t\tlocal c = B64_LOOKUP[string.byte(str, i + 2)]
\t\tlocal d = B64_LOOKUP[string.byte(str, i + 3)]
\t\tlocal bits = bit32.lshift(a, 18) + bit32.lshift(b, 12) + bit32.lshift(if c and c >= 0 then c else 0, 6) + (if d and d >= 0 then d else 0)
\t\tif outPos < outLen then
\t\t\tbuffer.writeu8(buf, outPos, bit32.band(bit32.rshift(bits, 16), 255))
\t\t\toutPos += 1
\t\tend
\t\tif outPos < outLen then
\t\t\tbuffer.writeu8(buf, outPos, bit32.band(bit32.rshift(bits, 8), 255))
\t\t\toutPos += 1
\t\tend
\t\tif outPos < outLen then
\t\t\tbuffer.writeu8(buf, outPos, bit32.band(bits, 255))
\t\t\toutPos += 1
\t\tend
\tend
\treturn buf
end

local function unpackVerts(vb: string, size: Vector3): {{ number }}
\tlocal buf = decodeBase64(vb)
\tlocal nBytes = buffer.len(buf)
\tlocal verts = table.create(nBytes // 2)
\tlocal hx = math.max(1e-5, size.X * 0.5) / 32767
\tlocal hy = math.max(1e-5, size.Y * 0.5) / 32767
\tlocal hz = math.max(1e-5, size.Z * 0.5) / 32767
\tfor off = 0, nBytes - 6, 6 do
\t\tverts[#verts + 1] = buffer.readi16(buf, off) * hx
\t\tverts[#verts + 1] = buffer.readi16(buf, off + 2) * hy
\t\tverts[#verts + 1] = buffer.readi16(buf, off + 4) * hz
\tend
\treturn verts
end

local function unpackTris(tb: string): {{ number }}
\tlocal buf = decodeBase64(tb)
\tlocal nBytes = buffer.len(buf)
\tlocal tris = {{}}
\tlocal prev = 0
\tlocal pos = 0
\twhile pos < nBytes do
\t\tlocal zz = 0
\t\tlocal shift = 0
\t\twhile pos < nBytes do
\t\t\tlocal b = buffer.readu8(buf, pos)
\t\t\tpos += 1
\t\t\tzz += bit32.lshift(bit32.band(b, 127), shift)
\t\t\tif b < 128 then
\t\t\t\tbreak
\t\t\tend
\t\t\tshift += 7
\t\tend
\t\tlocal d = if bit32.band(zz, 1) == 0 then bit32.rshift(zz, 1) else -bit32.rshift(zz + 1, 1)
\t\tprev += d
\t\ttris[#tris + 1] = prev
\tend
\treturn tris
end

local function unpackModel(shardModule: Instance): {{ PartMeshSpec }}
\tlocal rawList = require(shardModule :: ModuleScript) :: {{ any }}
\tlocal unpacked = table.create(#rawList)
\tfor _, raw in ipairs(rawList) do
\t\tunpacked[#unpacked + 1] = {{
\t\t\tName = raw.Name,
\t\t\tSubCollection = raw.SubCollection,
\t\t\tOffset = raw.Offset,
\t\t\tSize = raw.Size,
\t\t\tMaterial = raw.Material,
\t\t\tColor = raw.Color,
\t\t\tTransparency = raw.Transparency or 0,
\t\t\tCollidable = raw.Collidable,
\t\t\tMeshId = raw.MeshId or "",
\t\t\tVB = raw.VB,
\t\t\tTB = raw.TB,
\t\t\tVerts = raw.Verts,
\t\t\tTris = raw.Tris,
\t\t}}
\tend
\treturn unpacked
end

function GroupChestMeshData.GetGeometry(spec: PartMeshSpec): ({{ number }}, {{ number }})
\tif not spec.Verts then
\t\tspec.Verts = if spec.VB then unpackVerts(spec.VB, spec.Size) else {{}}
\tend
\tif not spec.Tris then
\t\tspec.Tris = if spec.TB then unpackTris(spec.TB) else {{}}
\tend
\treturn spec.Verts :: {{ number }}, spec.Tris :: {{ number }}
end

local MeshesFolder = (script.Parent :: Instance):WaitForChild("GroupChestMeshes")

GroupChestMeshData.Models = {{
\tgroup_chest = unpackModel(MeshesFolder:WaitForChild("group_chest")),
}} :: {{ [string]: {{ PartMeshSpec }} }}

return GroupChestMeshData
"""
    os.makedirs(os.path.dirname(LUAU_DATA_PATH), exist_ok=True)
    with open(LUAU_DATA_PATH, "w", encoding="utf-8") as f:
        f.write(loader_src)
    print(f"Wrote Luau mesh data loader: {LUAU_DATA_PATH}")


def setup_preview_and_save() -> None:
    blend_path = os.path.join(OUT_DIR, "group_chest.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"Saved Blender file: {blend_path}")

    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 38
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    # 3/4 heroic front-right camera matching reference image perspective (side arch left, front lock right)
    cam.location = r2b((7.6, 5.2, -10.4))
    target = r2b((0.0, 2.60, 0.0))
    cam.rotation_euler = (target - cam.location).normalized().to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam

    # 1. Workbench Cavity Preview
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 1120
    world = bpy.data.worlds.new("ChestPreviewWorld")
    scene.world = world
    world.color = (0.07, 0.08, 0.11)
    wb_png = os.path.join(OUT_DIR, "group_chest_workbench_preview.png")
    scene.render.filepath = wb_png
    bpy.ops.render.render(write_still=True)
    print(f"Rendered Workbench preview: {wb_png}")

    # 2. EEVEE Emission & Studio Lighting Preview
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.03, 0.035, 0.055, 1.0)
        bg.inputs[1].default_value = 0.70

    for lname, rpos, energy, col_rgb, lsize in [
        ("KeyLight", (7.5, 9.2, -9.5), 2100, (1.0, 0.96, 0.90), 5.0),
        ("FillLight", (-8.0, 5.5, -7.5), 1100, (0.72, 0.88, 1.0), 6.0),
        ("BlueRim", (-1.0, 8.5, 8.5), 1700, (0.35, 0.68, 1.0), 5.5),
        ("UnderBounce", (0.0, -1.5, -5.0), 420, (0.40, 0.72, 1.0), 6.0),
    ]:
        ld = bpy.data.lights.new(lname, type="AREA")
        ld.energy = energy
        ld.color = col_rgb
        ld.size = lsize
        lo = bpy.data.objects.new(lname, ld)
        lo.location = r2b(rpos)
        lo.rotation_euler = (target - lo.location).normalized().to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo)

    eevee_png = os.path.join(OUT_DIR, "group_chest_eevee_preview.png")
    scene.render.filepath = eevee_png
    bpy.ops.render.render(write_still=True)
    print(f"Rendered EEVEE preview: {eevee_png}")


def main() -> None:
    clear_scene()
    root_col = get_or_create_collection("GroupChest")
    pal = create_materials()

    build_chest_base(root_col, pal)
    build_chest_lid(root_col, pal)
    build_chest_glitch(root_col, pal)

    summary, parts_full = export_group_chest(root_col)
    for p in summary["Parts"]:
        print(
            f"[group_chest] {p['SubCollection']:12s} / {p['Name']:22s} "
            f"tris={p['Triangles']:4d} size={p['Size']} mat={p['Material']}"
        )
    print(f"[group_chest] TOTAL tris={summary['Triangles']} parts={summary['PartCount']}")

    manifest = {"group_chest": summary}
    manifest_path = os.path.join(OUT_DIR, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(f"Wrote manifest: {manifest_path}")

    write_luau_mesh_modules(parts_full)
    setup_preview_and_save()


if __name__ == "__main__":
    main()
