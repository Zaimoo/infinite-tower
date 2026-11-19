"""
Infinite Tower: Become a Master! - Runesmith's Anvil Sanctuary Blender Pipeline
================================================================================
Generates and exports the remodeled Runesmith's Anvil sanctuary for Roblox Studio:
  1. `assets/models/runesmith_sanctuary/RunesmithSanctuary.fbx`
     - `RunesmithAnvil/*` (BasePlate, Body, MoltenCore, SideRunes, TopSigil)
     - `FloatingPlatform/*` (TopFlagstones, RimShelves, RockSpire)
     - `FloatingRingsAndChains/*` (LowerStone, LowerRunes, UpperStone, UpperRunes,
       Chains_Iron_Front, Chains_Iron_Back, Chains_Iron_Upper)
     - `SanctuaryBridge/*` (WalkwayDeck, StoneAbutments, StoneMoss, IronLattice, CanopyRings)
     - `ChasmRim/*` (Hub_ChasmWall)
  2. `assets/models/runesmith_sanctuary/runesmith_sanctuary.blend`
  3. `assets/models/runesmith_sanctuary/manifest.json`
  4. Packed BMesh geometry shards:
     - `src/ReplicatedStorage/Assets/RunesmithMeshData.luau`
     - `src/ReplicatedStorage/Assets/RunesmithMeshes/runesmith_sanctuary.luau`

Coordinate Convention (1 Blender meter = 1 Roblox stud):
  - Authored in Roblox Y-up space: +X east, +Y up, -Z forward toward Wayfinder Dais,
    origin at Hub ground center of HubLayout.ReforgeStation (y = 0 is Hub lawn).
  - Converted to Blender Z-up via `r2b(rx, ry, rz) = Vector((rx, -rz, ry))`.
  - Exported to FBX with `axis_forward="Z", axis_up="Y", bake_space_transform=False`
    (matching HubCommonsGround.fbx / BlacksmithForge.fbx / SynthesisChamber.fbx)
    for exact 1:1 Roblox Studio 3D import without axis inversion.

Usage:
  "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b --factory-startup --python tools/blender/generate_runesmith_sanctuary.py
"""

from __future__ import annotations

import argparse
import base64
import json
import math
import os
import random
import re
import struct
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

REPO_ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = REPO_ROOT / "assets" / "models" / "runesmith_sanctuary"
FBX_PATH = OUT_DIR / "RunesmithSanctuary.fbx"
MANIFEST_PATH = OUT_DIR / "manifest.json"
MESH_IDS_PATH = OUT_DIR / "mesh_ids.json"
LUAU_DATA_PATH = REPO_ROOT / "src" / "ReplicatedStorage" / "Assets" / "RunesmithMeshData.luau"
SHARDS_DIR = REPO_ROOT / "src" / "ReplicatedStorage" / "Assets" / "RunesmithMeshes"
PREVIEW_DIR = Path(
    r"C:\Users\enter\.gemini\antigravity\brain\c9997dc4-7e41-4640-81ca-9aab0b72471e"
)

MAX_TRIS_PER_PART = 9500

# Spatial layout constants (1 Blender meter = 1 Roblox stud)
HOLE_RADIUS = 22.0
PLAT_RADIUS = 13.5
PLAT_TOP_Y = 4.55
ANVIL_PLINTH_TOP_Y = 4.72

LOWER_RING_Y = 21.5
LOWER_RING_R = 10.6
UPPER_RING_Y = 28.6
UPPER_RING_R = 15.4

BRIDGE_Z_HUB_END = -27.6
BRIDGE_Z_HUB_PIER = -23.8
BRIDGE_Z_PLAT_PIER = -12.4
BRIDGE_Z_PLAT_END = -9.6
BRIDGE_HALF_W = 2.85


def r2b(p: tuple[float, float, float] | Vector) -> Vector:
    """Roblox Y-up (rx, ry, rz) -> Blender Z-up (rx, -rz, ry)."""
    return Vector((p[0], -p[2], p[1]))


def clear_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def get_col(name: str, parent: bpy.types.Collection | None = None) -> bpy.types.Collection:
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        if parent is None:
            bpy.context.scene.collection.children.link(col)
        else:
            parent.children.link(col)
    return col


def make_mat(
    name: str,
    rgb: tuple[int, int, int],
    rbx_material: str,
    metallic: float = 0.05,
    roughness: float = 0.78,
    emit_rgb: tuple[int, int, int] | None = None,
    emit_strength: float = 0.0,
    specular: float = 0.35,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")

    lin = tuple((c / 255.0) ** 2.2 for c in rgb)
    bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = specular

    if emit_rgb is not None and emit_strength > 0.0:
        elin = tuple((c / 255.0) ** 2.2 for c in emit_rgb)
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (elin[0], elin[1], elin[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = emit_strength
        elif "Emission" in bsdf.inputs:
            bsdf.inputs["Emission"].default_value = (elin[0], elin[1], elin[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = emit_strength

    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat["rbx_material"] = rbx_material
    mat["rbx_color"] = list(rgb)
    return mat


def create_palette() -> dict[str, bpy.types.Material]:
    return {
        # Anvil materials
        "anvil_metal": make_mat("M_AnvilForgedIron", (70, 76, 88), "Metal", metallic=0.80, roughness=0.32, specular=0.68),
        "anvil_dark": make_mat("M_AnvilDarkBase", (50, 56, 66), "Metal", metallic=0.76, roughness=0.38, specular=0.60),
        "anvil_molten": make_mat(
            "M_AnvilMoltenCore", (255, 110, 18), "Neon", metallic=0.0, roughness=0.22,
            emit_rgb=(255, 96, 12), emit_strength=3.6
        ),
        "anvil_rune": make_mat(
            "M_AnvilSideRunes", (255, 148, 32), "Neon", metallic=0.08, roughness=0.25,
            emit_rgb=(255, 134, 24), emit_strength=3.2
        ),
        "anvil_gold_sigil": make_mat(
            "M_AnvilTopSigil", (250, 184, 52), "Neon", metallic=0.25, roughness=0.24,
            emit_rgb=(245, 174, 44), emit_strength=2.8
        ),
        # Platform & rocks
        "plat_slab": make_mat("M_PlatformFlagstone", (104, 100, 94), "Slate", metallic=0.04, roughness=0.84),
        "plat_slab_dark": make_mat("M_PlatformFlagstoneDark", (76, 74, 72), "Slate", metallic=0.05, roughness=0.86),
        "rock_upper": make_mat("M_ChasmRockUpper", (68, 66, 70), "Slate", metallic=0.04, roughness=0.88),
        "rock_deep": make_mat("M_ChasmRockDeep", (44, 44, 50), "Basalt", metallic=0.04, roughness=0.92),
        # Floating rune rings & chains
        "ring_stone": make_mat("M_RuneRingStone", (94, 98, 108), "Slate", metallic=0.06, roughness=0.80),
        "ring_rune_blue": make_mat(
            "M_RingBlueRunes", (74, 204, 255), "Neon", metallic=0.0, roughness=0.18,
            emit_rgb=(64, 196, 255), emit_strength=4.5
        ),
        "chain_iron": make_mat("M_ChainDarkIron", (56, 60, 68), "Metal", metallic=0.84, roughness=0.38),
        # Bridge materials (Image 4)
        "bridge_stone": make_mat("M_BridgeWeatheredStone", (128, 122, 106), "Slate", metallic=0.03, roughness=0.86),
        "bridge_moss": make_mat("M_BridgeMossStone", (86, 104, 52), "Grass", metallic=0.0, roughness=0.92),
        "bridge_deck": make_mat("M_BridgeDeckCobble", (116, 112, 98), "Cobblestone", metallic=0.03, roughness=0.85),
        "bridge_iron": make_mat("M_BridgeAgedBronzeIron", (132, 94, 62), "Metal", metallic=0.70, roughness=0.44),
        # Hub preview context only
        "hub_grass": make_mat("M_HubMeadowGrass", (96, 106, 48), "Grass", metallic=0.0, roughness=0.92, specular=0.14),
    }


# ---------------------------------------------------------------------------
# BMesh Construction Primitives (all inputs in Roblox Y-up space)
# ---------------------------------------------------------------------------

def ensure_outward_solid(tmp: bmesh.types.BMesh) -> None:
    """Makes face winding consistent and forces positive signed volume (outward normals)."""
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    if tmp.calc_volume(signed=True) < 0.0:
        bmesh.ops.reverse_faces(tmp, faces=tmp.faces)
    tmp.normal_update()


def merge_bmesh(dst: bmesh.types.BMesh, src: bmesh.types.BMesh) -> None:
    vmap: dict[int, bmesh.types.BMVert] = {}
    for v in src.verts:
        vmap[v.index] = dst.verts.new(v.co)
    for f in src.faces:
        try:
            dst.faces.new([vmap[v.index] for v in f.verts])
        except ValueError:
            pass


def _assign_box_uvs(bm: bmesh.types.BMesh, scale: float = 0.25) -> None:
    uv_layer = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u, v = co.x * scale, co.y * scale
            elif ax >= ay and ax >= az:
                u, v = co.y * scale, co.z * scale
            else:
                u, v = co.x * scale, co.z * scale
            loop[uv_layer].uv = (u, v)


def commit_bmesh(
    name: str,
    bm: bmesh.types.BMesh,
    col: bpy.types.Collection,
    mat: bpy.types.Material,
    smooth_angle_deg: float = 36.0,
    all_smooth: bool = False,
    collidable: bool = False,
) -> bpy.types.Object:
    # Normals are already outward-oriented per closed solid primitive before merge;
    # never call recalc_face_normals after split_edges (which creates open face islands).
    if not all_smooth and smooth_angle_deg > 0:
        sharp_edges = [
            e for e in bm.edges
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(smooth_angle_deg)
        ]
        if sharp_edges:
            bmesh.ops.split_edges(bm, edges=sharp_edges)
    bmesh.ops.triangulate(bm, faces=bm.faces, ngon_method="EAR_CLIP")
    bm.normal_update()
    _assign_box_uvs(bm)

    tri_count = len(bm.faces)
    assert tri_count <= MAX_TRIS_PER_PART, f"{name} exceeded Roblox MeshPart triangle budget: {tri_count} > {MAX_TRIS_PER_PART}"

    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    mesh.polygons.foreach_set("use_smooth", [all_smooth] * len(mesh.polygons))
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(mat)
    obj["rbx_collidable"] = collidable
    col.objects.link(obj)
    return obj


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
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(Vector(center)) @ rot, verts=tmp.verts)
    for v in tmp.verts:
        v.co = r2b(v.co)
    ensure_outward_solid(tmp)
    merge_bmesh(bm, tmp)
    tmp.free()


def add_prism(
    bm: bmesh.types.BMesh,
    pts_xy: list[tuple[float, float]],
    z0: float,
    z1: float,
    bevel: float = 0.03,
    rot_deg: tuple[float, float, float] = (0.0, 0.0, 0.0),
    offset: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    """Extrudes a 2D polygon in Roblox (X, Y) from z0 to z1."""
    tmp = bmesh.new()
    vf = [tmp.verts.new((x, y, z0)) for (x, y) in pts_xy]
    vb = [tmp.verts.new((x, y, z1)) for (x, y) in pts_xy]
    n = len(pts_xy)
    tmp.faces.new(list(reversed(vf)))
    tmp.faces.new(vb)
    for i in range(n):
        ni = (i + 1) % n
        tmp.faces.new((vf[i], vf[ni], vb[ni], vb[i]))
    ensure_outward_solid(tmp)
    if bevel > 0.0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect="EDGES", clamp_overlap=True)
    rot = Euler([math.radians(a) for a in rot_deg], "XYZ").to_matrix().to_4x4()
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(Vector(offset)) @ rot, verts=tmp.verts)
    for v in tmp.verts:
        v.co = r2b(v.co)
    ensure_outward_solid(tmp)
    bmesh.ops.triangulate(tmp, faces=tmp.faces, ngon_method="EAR_CLIP")
    tmp.normal_update()
    merge_bmesh(bm, tmp)
    tmp.free()


def add_xz_prism(
    bm: bmesh.types.BMesh,
    pts_xz: list[tuple[float, float]],
    y0: float,
    y1: float,
    bevel: float = 0.04,
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
    ensure_outward_solid(tmp)
    if bevel > 0.0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect="EDGES", clamp_overlap=True)
    for v in tmp.verts:
        v.co = r2b(v.co)
    ensure_outward_solid(tmp)
    bmesh.ops.triangulate(tmp, faces=tmp.faces, ngon_method="EAR_CLIP")
    tmp.normal_update()
    merge_bmesh(bm, tmp)
    tmp.free()


def add_strut(
    bm: bmesh.types.BMesh,
    p0: tuple[float, float, float],
    p1: tuple[float, float, float],
    width: float,
    depth: float,
    bevel: float = 0.0,
) -> None:
    """Adds a clean rectangular stroke between two Roblox 3D points."""
    a, b = Vector(p0), Vector(p1)
    delta = b - a
    length = delta.length
    if length < 1e-4:
        return
    z_axis = delta.normalized()
    hint = Vector((0, 0, 1)) if abs(z_axis.z) < 0.9 else Vector((1, 0, 0))
    x_axis = hint.cross(z_axis).normalized()
    y_axis = z_axis.cross(x_axis).normalized()
    rot = Matrix((x_axis, y_axis, z_axis)).transposed().to_4x4()
    mid = (a + b) * 0.5

    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.transform(tmp, matrix=Matrix.Diagonal((width, depth, length + width * 0.35, 1.0)), verts=tmp.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect="EDGES", clamp_overlap=True)
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(mid) @ rot, verts=tmp.verts)
    for v in tmp.verts:
        v.co = r2b(v.co)
    ensure_outward_solid(tmp)
    merge_bmesh(bm, tmp)
    tmp.free()


def add_swept_tube(
    bm: bmesh.types.BMesh,
    points_rbx: list[Vector],
    radius: float,
    segs: int = 8,
    closed: bool = False,
) -> None:
    """Sweeps a smooth circular tube along a Roblox-space polyline using parallel transport."""
    n_pts = len(points_rbx)
    if n_pts < 2:
        return
    pts = [r2b(p) for p in points_rbx]

    tangents: list[Vector] = []
    for i in range(n_pts):
        if closed:
            p_prev = pts[(i - 1) % n_pts]
            p_next = pts[(i + 1) % n_pts]
            t = (p_next - p_prev).normalized()
        else:
            if i == 0:
                t = (pts[1] - pts[0]).normalized()
            elif i == n_pts - 1:
                t = (pts[-1] - pts[-2]).normalized()
            else:
                t = (pts[i + 1] - pts[i - 1]).normalized()
        tangents.append(t)

    t0 = tangents[0]
    ref = Vector((0, 0, 1)) if abs(t0.z) < 0.9 else Vector((1, 0, 0))
    n_vec = t0.cross(ref).normalized()
    b_vec = t0.cross(n_vec).normalized()

    tmp = bmesh.new()
    rings: list[list[bmesh.types.BMVert]] = []
    for i in range(n_pts):
        t_cur = tangents[i]
        if i > 0:
            rot_q = tangents[i - 1].rotation_difference(t_cur)
            n_vec = (rot_q @ n_vec).normalized()
            b_vec = t_cur.cross(n_vec).normalized()
        ring = []
        for s in range(segs):
            a = math.tau * s / segs
            offset = (n_vec * math.cos(a) + b_vec * math.sin(a)) * radius
            ring.append(tmp.verts.new(pts[i] + offset))
        rings.append(ring)

    ring_count = n_pts if closed else n_pts - 1
    for i in range(ring_count):
        r_a = rings[i]
        r_b = rings[(i + 1) % n_pts]
        for s in range(segs):
            ns = (s + 1) % segs
            tmp.faces.new((r_a[s], r_a[ns], r_b[ns], r_b[s]))

    if not closed:
        tmp.faces.new(list(reversed(rings[0])))
        tmp.faces.new(rings[-1])

    ensure_outward_solid(tmp)
    merge_bmesh(bm, tmp)
    tmp.free()


def add_torus_link(
    bm: bmesh.types.BMesh,
    center_rbx: Vector,
    rot_euler: Euler,
    half_len: float,
    half_w: float,
    wire_r: float,
    path_segs: int = 10,
    tube_segs: int = 6,
) -> None:
    """Adds a stadium-shaped forged chain link centered at center_rbx."""
    pts: list[Vector] = []
    straight = max(0.02, half_len - half_w)
    rot_m = rot_euler.to_matrix()
    for i in range(path_segs):
        frac = i / path_segs
        ang = frac * math.tau
        cx = math.cos(ang) * half_w
        cy = math.sin(ang) * half_w + (straight if math.sin(ang) >= 0 else -straight)
        p_local = Vector((cx, cy, 0.0))
        pts.append(center_rbx + (rot_m @ p_local))
    add_swept_tube(bm, pts, wire_r, segs=tube_segs, closed=True)


def add_chain(
    bm: bmesh.types.BMesh,
    p0: Vector,
    p1: Vector,
    link_pitch: float = 0.72,
    link_w: float = 0.24,
    wire_r: float = 0.088,
) -> None:
    """Adds alternating interlocking 3D chain links between Roblox points p0 and p1."""
    delta = p1 - p0
    dist = delta.length
    if dist < 0.1:
        return
    axis = delta.normalized()
    q_align = Vector((0, 1, 0)).rotation_difference(axis)
    n_links = max(2, int(round(dist / link_pitch)))
    step = dist / n_links
    for i in range(n_links):
        t = (i + 0.5) / n_links
        pos = p0.lerp(p1, t)
        twist = Euler((0.0, math.pi * 0.5 if i % 2 == 1 else 0.0, 0.0), "XYZ")
        rot = (q_align.to_matrix() @ twist.to_matrix()).to_euler()
        add_torus_link(bm, pos, rot, half_len=step * 0.68, half_w=link_w, wire_r=wire_r, path_segs=10, tube_segs=6)


# ---------------------------------------------------------------------------
# Component 1: The Runesmith's Anvil (Reference Image 3)
# ---------------------------------------------------------------------------

def build_runesmith_anvil(root_col: bpy.types.Collection, pal: dict[str, bpy.types.Material]) -> None:
    col = get_col("RunesmithAnvil", root_col)
    y0 = ANVIL_PLINTH_TOP_Y

    # 1A. Castellated Notched Base Plate + Waist Transition Collar (dark gunmetal)
    bm_base = bmesh.new()
    base_pts = [
        (-2.55, -2.20), (-1.45, -2.20), (-1.35, -1.78), (-0.65, -1.78), (-0.52, -1.35),
        (0.52, -1.35), (0.65, -1.78), (1.35, -1.78), (1.45, -2.20), (2.55, -2.20),
        (2.55, -1.62), (3.18, -1.62), (3.18, -0.58), (2.75, -0.48), (2.75, 0.48),
        (3.18, 0.58), (3.18, 1.62), (2.55, 1.62), (2.55, 2.20), (1.45, 2.20),
        (1.35, 1.78), (0.65, 1.78), (0.52, 1.35), (-0.52, 1.35), (-0.65, 1.78),
        (-1.35, 1.78), (-1.45, 2.20), (-2.55, 2.20), (-2.55, 1.62), (-3.18, 1.62),
        (-3.18, 0.58), (-2.75, 0.48), (-2.75, -0.48), (-3.18, -0.58), (-3.18, -1.62),
        (-2.55, -1.62),
    ]
    add_xz_prism(bm_base, base_pts, y0, y0 + 0.72, bevel=0.05)

    for sx in (-2.85, 2.85):
        for sz in (-1.32, 1.32):
            add_box(bm_base, (sx, y0 + 0.74, sz), (0.14, 0.08, 0.14), bevel=0.02)
    for sx in (-2.25, 2.25):
        for sz in (-1.92, 1.92):
            add_box(bm_base, (sx, y0 + 0.74, sz), (0.14, 0.08, 0.14), bevel=0.02)

    collar_pts_1 = [
        (-2.25, -1.25), (-0.90, -1.38), (0.90, -1.38), (2.25, -1.25),
        (2.48, -0.60), (2.48, 0.60), (2.25, 1.25), (0.90, 1.38),
        (-0.90, 1.38), (-2.25, 1.25), (-2.48, 0.60), (-2.48, -0.60),
    ]
    add_xz_prism(bm_base, collar_pts_1, y0 + 0.70, y0 + 0.96, bevel=0.04)
    collar_pts_2 = [(x * 0.90, z * 0.88) for (x, z) in collar_pts_1]
    add_xz_prism(bm_base, collar_pts_2, y0 + 0.94, y0 + 1.14, bevel=0.04)
    commit_bmesh("Anvil_BasePlate", bm_base, col, pal["anvil_dark"], smooth_angle_deg=34.0)

    # 1B. Flared Concave Waist Body + Vertical Iron Ribs + Upper Working Block + Heel + Horn
    bm_body = bmesh.new()
    waist_levels = [
        (1.10, 2.02, 1.14),
        (1.42, 1.78, 0.98),
        (1.85, 1.66, 0.90),
        (2.25, 1.74, 0.94),
        (2.60, 2.08, 1.10),
        (2.90, 2.65, 1.42),
    ]
    tmp_waist = bmesh.new()
    rings_v: list[list[bmesh.types.BMVert]] = []
    prof_n = 16
    for dy, rx, rz in waist_levels:
        ring = []
        for i in range(prof_n):
            a = math.tau * i / prof_n
            ca, sa = math.cos(a), math.sin(a)
            px = math.copysign(abs(ca) ** 0.65, ca) * rx
            pz = math.copysign(abs(sa) ** 0.65, sa) * rz
            if dy > 2.2 and px > 0:
                px *= 1.0 + (dy - 2.2) * 0.25
            ring.append(tmp_waist.verts.new(r2b((px, y0 + dy, pz))))
        rings_v.append(ring)

    for li in range(len(rings_v) - 1):
        ra, rb = rings_v[li], rings_v[li + 1]
        for i in range(prof_n):
            ni = (i + 1) % prof_n
            tmp_waist.faces.new((ra[i], ra[ni], rb[ni], rb[i]))
    tmp_waist.faces.new(list(reversed(rings_v[0])))
    tmp_waist.faces.new(rings_v[-1])
    ensure_outward_solid(tmp_waist)
    merge_bmesh(bm_body, tmp_waist)
    tmp_waist.free()

    for side_z in (-1.0, 1.0):
        add_box(bm_body, (-0.98, y0 + 1.98, side_z * 1.02), (0.24, 1.68, 0.28), rot_deg=(0, 0, -4), bevel=0.03)
        add_box(bm_body, (0.98, y0 + 1.98, side_z * 1.02), (0.24, 1.68, 0.28), rot_deg=(0, 0, 4), bevel=0.03)
        add_box(bm_body, (-0.42, y0 + 1.98, side_z * 1.04), (0.20, 1.66, 0.30), rot_deg=(0, 0, -2), bevel=0.03)
        add_box(bm_body, (0.42, y0 + 1.98, side_z * 1.04), (0.20, 1.66, 0.30), rot_deg=(0, 0, 2), bevel=0.03)
        add_box(bm_body, (0.0, y0 + 2.74, side_z * 1.08), (2.15, 0.22, 0.30), bevel=0.03)
        add_box(bm_body, (0.0, y0 + 1.24, side_z * 1.06), (2.25, 0.22, 0.28), bevel=0.03)

    add_box(bm_body, (0.0, y0 + 3.55, 0.0), (5.30, 1.34, 2.95), bevel=0.06, segments=2)
    for side_z in (-1.0, 1.0):
        add_box(bm_body, (0.0, y0 + 4.10, side_z * 1.48), (5.36, 0.22, 0.22), bevel=0.03)
        add_box(bm_body, (0.0, y0 + 3.00, side_z * 1.48), (5.36, 0.22, 0.22), bevel=0.03)
        add_box(bm_body, (-2.58, y0 + 3.55, side_z * 1.48), (0.20, 1.22, 0.22), bevel=0.03)
        add_box(bm_body, (2.58, y0 + 3.55, side_z * 1.48), (0.20, 1.22, 0.22), bevel=0.03)

    heel_pts = [
        (2.62, y0 + 2.72),
        (3.85, y0 + 3.45),
        (3.85, y0 + 4.20),
        (2.62, y0 + 4.20),
    ]
    add_prism(bm_body, heel_pts, z0=-1.44, z1=1.44, bevel=0.05)

    add_box(bm_body, (-2.82, y0 + 3.16, 0.0), (0.58, 1.62, 2.66), bevel=0.06, segments=2)
    add_box(bm_body, (-3.02, y0 + 3.16, 0.0), (0.36, 1.38, 2.28), bevel=0.05)
    for side_z in (-1.0, 1.0):
        add_box(bm_body, (-2.86, y0 + 3.74, side_z * 1.28), (0.14, 0.14, 0.10), bevel=0.02)

    horn_stations = [
        (-3.05, y0 + 3.08, 0.72, 1.04),
        (-3.65, y0 + 3.08, 0.64, 0.88),
        (-4.35, y0 + 3.12, 0.52, 0.68),
        (-5.05, y0 + 3.18, 0.38, 0.48),
        (-5.65, y0 + 3.24, 0.24, 0.30),
        (-6.12, y0 + 3.30, 0.10, 0.13),
    ]
    horn_n = 18
    tmp_horn = bmesh.new()
    horn_rings: list[list[bmesh.types.BMVert]] = []
    for hx, hy, ry_h, rz_h in horn_stations:
        ring = []
        for i in range(horn_n):
            a = math.tau * i / horn_n
            ca, sa = math.cos(a), math.sin(a)
            py_local = sa * ry_h * (0.78 if sa > 0 else 1.05)
            pz_local = ca * rz_h
            ring.append(tmp_horn.verts.new(r2b((hx, hy + py_local, pz_local))))
        horn_rings.append(ring)
    for li in range(len(horn_rings) - 1):
        ra, rb = horn_rings[li], horn_rings[li + 1]
        for i in range(horn_n):
            ni = (i + 1) % horn_n
            tmp_horn.faces.new((ra[i], ra[ni], rb[ni], rb[i]))
    tmp_horn.faces.new(list(reversed(horn_rings[0])))
    tmp_horn.faces.new(horn_rings[-1])
    ensure_outward_solid(tmp_horn)
    merge_bmesh(bm_body, tmp_horn)
    tmp_horn.free()

    for hx_seam, hy_c, ry_s, rz_s in [(-3.72, y0 + 3.09, 0.54, 0.87), (-4.42, y0 + 3.13, 0.43, 0.67)]:
        tmp_seam = bmesh.new()
        seam_ring_pts: list[list[bmesh.types.BMVert]] = []
        for dx_off in (-0.06, 0.06):
            s_ring = []
            for i in range(horn_n):
                a = math.tau * i / horn_n
                ca, sa = math.cos(a), math.sin(a)
                py_loc = sa * (ry_s + 0.03) * (0.78 if sa > 0 else 1.05)
                pz_loc = ca * (rz_s + 0.03)
                s_ring.append(tmp_seam.verts.new(r2b((hx_seam + dx_off, hy_c + py_loc, pz_loc))))
            seam_ring_pts.append(s_ring)
        for i in range(horn_n):
            ni = (i + 1) % horn_n
            tmp_seam.faces.new((seam_ring_pts[0][i], seam_ring_pts[0][ni], seam_ring_pts[1][ni], seam_ring_pts[1][i]))
        tmp_seam.faces.new(list(reversed(seam_ring_pts[0])))
        tmp_seam.faces.new(seam_ring_pts[1])
        ensure_outward_solid(tmp_seam)
        merge_bmesh(bm_body, tmp_seam)
        tmp_seam.free()

    commit_bmesh("Anvil_Body", bm_body, col, pal["anvil_metal"], smooth_angle_deg=40.0)

    # 1C. Glowing Molten-Orange Waist Furnace Vents (III) on both -Z and +Z
    bm_molten = bmesh.new()
    for side_z in (-1.0, 1.0):
        z_glow = side_z * 0.96
        center_pts = [
            (-0.24, y0 + 1.34),
            (0.24, y0 + 1.34),
            (0.14, y0 + 2.64),
            (-0.14, y0 + 2.64),
        ]
        add_prism(bm_molten, center_pts, z0=z_glow - 0.14, z1=z_glow + 0.14, bevel=0.02)
        for sx in (-0.70, 0.70):
            add_box(bm_molten, (sx, y0 + 1.98, z_glow), (0.20, 1.32, 0.24), rot_deg=(0, 0, sx * -4.0), bevel=0.02)
    commit_bmesh("Anvil_MoltenCore", bm_molten, col, pal["anvil_molten"], smooth_angle_deg=45.0)

    # 1D. Glowing Orange Elder Rune Frieze along both -Z and +Z upper block faces
    bm_srunes = bmesh.new()
    rune_x = [-2.22, -1.92, -1.62, -1.32, -1.04, -0.78, -0.44, -0.14, 0.16, 0.46, 0.74, 1.00, 1.34, 1.64, 1.94, 2.24]
    glyph_seq = ["D", "1", "U", "1", "C", "I", "D", "1", "U", "1", "C", "I", "D", "1", "U", "I"]
    for side_z in (-1.0, 1.0):
        zf = side_z * 1.49
        yc = y0 + 3.55
        st = 0.058
        dp = 0.06
        for rx, g in zip(rune_x, glyph_seq):
            if g == "D":
                add_strut(bm_srunes, (rx, yc + 0.18, zf), (rx + 0.11, yc, zf), st, dp)
                add_strut(bm_srunes, (rx + 0.11, yc, zf), (rx, yc - 0.18, zf), st, dp)
                add_strut(bm_srunes, (rx, yc - 0.18, zf), (rx - 0.11, yc, zf), st, dp)
                add_strut(bm_srunes, (rx - 0.11, yc, zf), (rx, yc + 0.18, zf), st, dp)
            elif g == "1":
                add_strut(bm_srunes, (rx, yc - 0.24, zf), (rx, yc + 0.24, zf), st, dp)
                add_strut(bm_srunes, (rx - 0.10, yc + 0.12, zf), (rx, yc + 0.24, zf), st, dp)
            elif g == "U":
                add_strut(bm_srunes, (rx, yc - 0.24, zf), (rx, yc + 0.24, zf), st, dp)
                add_strut(bm_srunes, (rx - 0.12, yc + 0.08, zf), (rx, yc + 0.24, zf), st, dp)
                add_strut(bm_srunes, (rx + 0.12, yc + 0.08, zf), (rx, yc + 0.24, zf), st, dp)
            elif g == "C":
                add_strut(bm_srunes, (rx + 0.10, yc + 0.22, zf), (rx - 0.10, yc, zf), st, dp)
                add_strut(bm_srunes, (rx - 0.10, yc, zf), (rx + 0.10, yc - 0.22, zf), st, dp)
            else:
                add_strut(bm_srunes, (rx, yc - 0.24, zf), (rx, yc + 0.24, zf), st, dp)
                add_strut(bm_srunes, (rx - 0.08, yc + 0.22, zf), (rx + 0.08, yc + 0.22, zf), st * 0.9, dp)
                add_strut(bm_srunes, (rx - 0.08, yc - 0.22, zf), (rx + 0.08, yc - 0.22, zf), st * 0.9, dp)
    commit_bmesh("Anvil_SideRunes", bm_srunes, col, pal["anvil_rune"], smooth_angle_deg=35.0)

    # 1E. Top Golden Monogram Sigil & Circular Border Ring on Working Face
    bm_top = bmesh.new()
    yt = y0 + 4.23
    ring_pts = [
        Vector((math.cos(math.tau * i / 36) * 1.55, yt, math.sin(math.tau * i / 36) * 1.10))
        for i in range(36)
    ]
    add_swept_tube(bm_top, ring_pts, radius=0.04, segs=6, closed=True)
    s_th = 0.095
    s_h = 0.06
    add_strut(bm_top, (-0.52, yt, -0.58), (-0.52, yt, 0.58), s_th, s_h)
    add_strut(bm_top, (0.52, yt, -0.58), (0.52, yt, 0.58), s_th, s_h)
    add_strut(bm_top, (-0.72, yt, -0.58), (-0.32, yt, -0.58), s_th * 0.85, s_h)
    add_strut(bm_top, (-0.72, yt, 0.58), (-0.32, yt, 0.58), s_th * 0.85, s_h)
    add_strut(bm_top, (0.32, yt, -0.58), (0.72, yt, -0.58), s_th * 0.85, s_h)
    add_strut(bm_top, (0.32, yt, 0.58), (0.72, yt, 0.58), s_th * 0.85, s_h)
    add_strut(bm_top, (-0.52, yt, 0.0), (0.52, yt, -0.32), s_th * 0.9, s_h)
    add_strut(bm_top, (-0.52, yt, 0.0), (0.52, yt, 0.34), s_th * 0.9, s_h)
    add_strut(bm_top, (0.0, yt, -0.45), (0.0, yt, 0.45), s_th * 0.85, s_h)
    commit_bmesh("Anvil_TopSigil", bm_top, col, pal["anvil_gold_sigil"], smooth_angle_deg=35.0)


# ---------------------------------------------------------------------------
# Component 2: Elevated Floating Craggy Rock Platform (Reference Image 2)
# ---------------------------------------------------------------------------

def _rock_circle_pts(
    radius: float,
    n: int,
    seed: int,
    radial_jitter: float = 0.14,
    front_notch_flatten: bool = False,
) -> list[tuple[float, float]]:
    rng = random.Random(seed)
    pts: list[tuple[float, float]] = []
    for i in range(n):
        a = math.tau * i / n
        r = radius * (1.0 + rng.uniform(-radial_jitter, radial_jitter))
        x = math.sin(a) * r
        z = -math.cos(a) * r
        if front_notch_flatten and z < -radius * 0.72 and abs(x) < 4.5:
            z = max(z, -PLAT_RADIUS + 1.1)
        pts.append((x, z))
    return pts


def build_floating_platform(root_col: bpy.types.Collection, pal: dict[str, bpy.types.Material]) -> None:
    col = get_col("FloatingPlatform", root_col)
    rng = random.Random(7701)

    bm_slabs = bmesh.new()
    outer_pts = _rock_circle_pts(PLAT_RADIUS, 26, seed=101, radial_jitter=0.07, front_notch_flatten=True)
    add_xz_prism(bm_slabs, outer_pts, PLAT_TOP_Y - 0.95, PLAT_TOP_Y - 0.18, bevel=0.14)

    n_pie = 10
    for i in range(n_pie):
        a0 = math.tau * i / n_pie + 0.02
        a1 = math.tau * (i + 1) / n_pie - 0.02
        r_in = 4.2 + rng.uniform(-0.3, 0.3)
        r_out = PLAT_RADIUS - 0.3 + rng.uniform(-0.5, 0.4)
        poly: list[tuple[float, float]] = []
        for a in (a0, (a0 + a1) * 0.5, a1):
            x, z = math.sin(a) * r_out, -math.cos(a) * r_out
            if z < -PLAT_RADIUS * 0.72 and abs(x) < 4.6:
                z = max(z, -PLAT_RADIUS + 1.0)
            poly.append((x, z))
        for a in (a1, a0):
            poly.append((math.sin(a) * r_in, -math.cos(a) * r_in))
        top_y = PLAT_TOP_Y + rng.uniform(-0.04, 0.04)
        add_xz_prism(bm_slabs, poly, PLAT_TOP_Y - 0.45, top_y, bevel=0.08)

    apron_pts = _rock_circle_pts(5.2, 12, seed=202, radial_jitter=0.05)
    add_xz_prism(bm_slabs, apron_pts, PLAT_TOP_Y - 0.25, PLAT_TOP_Y + 0.02, bevel=0.06)
    plinth_pts = [
        (-3.6, -2.5), (3.6, -2.5), (4.0, 0.0), (3.6, 2.5), (-3.6, 2.5), (-4.0, 0.0)
    ]
    add_xz_prism(bm_slabs, plinth_pts, PLAT_TOP_Y - 0.1, ANVIL_PLINTH_TOP_Y, bevel=0.07)
    commit_bmesh("Platform_TopFlagstones", bm_slabs, col, pal["plat_slab"], smooth_angle_deg=32.0)

    bm_dark = bmesh.new()
    for i in range(14):
        a = math.tau * i / 14 + 0.2
        if abs(math.sin(a)) < 0.28 and -math.cos(a) < -0.5:
            continue
        rx = math.sin(a) * (PLAT_RADIUS - 0.8)
        rz = -math.cos(a) * (PLAT_RADIUS - 0.8)
        add_box(
            bm_dark,
            (rx, PLAT_TOP_Y - 0.55, rz),
            (rng.uniform(3.2, 5.2), rng.uniform(0.9, 1.4), rng.uniform(2.6, 3.8)),
            rot_deg=(rng.uniform(-6, 6), math.degrees(a), rng.uniform(-6, 6)),
            bevel=0.14,
        )
    commit_bmesh("Platform_RimShelves", bm_dark, col, pal["plat_slab_dark"], smooth_angle_deg=35.0)

    bm_spire = bmesh.new()
    strata = [
        (3.65, 13.0, 0.12),
        (1.60, 11.4, 0.16),
        (-1.20, 9.2, 0.18),
        (-4.50, 7.2, 0.20),
        (-8.20, 5.2, 0.22),
        (-12.0, 3.3, 0.24),
        (-15.6, 1.7, 0.22),
        (-18.5, 0.25, 0.05),
    ]
    n_rad = 18
    tmp_spire = bmesh.new()
    spire_rings: list[list[bmesh.types.BMVert]] = []
    for idx, (sy, sr, jit) in enumerate(strata):
        ring = []
        s_rng = random.Random(900 + idx * 31)
        for k in range(n_rad):
            a = math.tau * k / n_rad + (idx % 2) * (math.pi / n_rad)
            r = sr * (1.0 + s_rng.uniform(-jit, jit))
            dy = s_rng.uniform(-0.45, 0.45) if 0 < idx < len(strata) - 1 else 0.0
            ring.append(tmp_spire.verts.new(r2b((math.sin(a) * r, sy + dy, -math.cos(a) * r))))
        spire_rings.append(ring)

    for li in range(len(spire_rings) - 1):
        ra, rb = spire_rings[li], spire_rings[li + 1]
        for k in range(n_rad):
            nk = (k + 1) % n_rad
            tmp_spire.faces.new((ra[k], rb[k], rb[nk], ra[nk]))
    tmp_spire.faces.new(spire_rings[0])
    tmp_spire.faces.new(list(reversed(spire_rings[-1])))
    ensure_outward_solid(tmp_spire)
    bmesh.ops.triangulate(tmp_spire, faces=tmp_spire.faces, ngon_method="EAR_CLIP")
    tmp_spire.normal_update()
    merge_bmesh(bm_spire, tmp_spire)
    tmp_spire.free()

    for rib_i in range(9):
        a = math.tau * rib_i / 9 + rng.uniform(-0.15, 0.15)
        r_mid = rng.uniform(5.8, 8.8)
        y_mid = rng.uniform(-7.5, 0.5)
        h_rib = rng.uniform(5.5, 9.5)
        add_box(
            bm_spire,
            (math.sin(a) * r_mid, y_mid, -math.cos(a) * r_mid),
            (rng.uniform(2.6, 4.2), h_rib, rng.uniform(2.4, 3.8)),
            rot_deg=(rng.uniform(-14, 14), math.degrees(a), rng.uniform(-14, 14)),
            bevel=0.18,
        )
    commit_bmesh("Platform_RockSpire", bm_spire, col, pal["rock_upper"], smooth_angle_deg=34.0)


# ---------------------------------------------------------------------------
# Component 3: Concentric Floating Ancient Stone Rune Rings & Chains (Image 2)
# ---------------------------------------------------------------------------

def _add_curved_stone_arc(
    bm: bmesh.types.BMesh,
    radius: float,
    y_center: float,
    radial_w: float,
    height: float,
    a0: float,
    a1: float,
    seed: int,
) -> None:
    rng = random.Random(seed)
    steps = max(4, int(round(abs(a1 - a0) * radius / 1.8)))
    hw = radial_w * 0.5
    hh = height * 0.5
    cross_rings: list[list[bmesh.types.BMVert]] = []
    b_cut = 0.22
    profile = [
        (-hw + b_cut, -hh),
        (hw - b_cut, -hh),
        (hw, -hh + b_cut),
        (hw, hh - b_cut),
        (hw - b_cut, hh),
        (-hw + b_cut, hh),
        (-hw, hh - b_cut),
        (-hw, -hh + b_cut),
    ]
    tmp_arc = bmesh.new()
    for s in range(steps + 1):
        t = s / steps
        ang = a0 + (a1 - a0) * t
        edge_fade = 1.0 - 0.08 * (1.0 - math.sin(math.pi * t))
        r_jit = rng.uniform(-0.10, 0.10)
        y_jit = rng.uniform(-0.08, 0.08)
        ca, sa = math.sin(ang), -math.cos(ang)
        ring: list[bmesh.types.BMVert] = []
        for dr, dy in profile:
            rr = radius + dr * edge_fade + r_jit
            yy = y_center + dy * edge_fade + y_jit
            ring.append(tmp_arc.verts.new(r2b((ca * rr, yy, sa * rr))))
        cross_rings.append(ring)

    pn = len(profile)
    for s in range(steps):
        ra, rb = cross_rings[s], cross_rings[s + 1]
        for k in range(pn):
            nk = (k + 1) % pn
            tmp_arc.faces.new((ra[k], ra[nk], rb[nk], rb[k]))
    tmp_arc.faces.new(list(reversed(cross_rings[0])))
    tmp_arc.faces.new(cross_rings[-1])
    ensure_outward_solid(tmp_arc)
    merge_bmesh(bm, tmp_arc)
    tmp_arc.free()


def _add_arc_glyph(
    bm: bmesh.types.BMesh,
    glyph_idx: int,
    angle: float,
    face_radius: float,
    y_center: float,
    char_h: float,
    char_w: float,
    extrude_dir: float,
) -> None:
    t_dir = Vector((math.cos(angle), 0.0, math.sin(angle)))
    r_dir = Vector((math.sin(angle), 0.0, -math.cos(angle))) * extrude_dir
    origin = Vector((math.sin(angle) * face_radius, y_center, -math.cos(angle) * face_radius)) + r_dir * 0.04

    def p(u: float, v: float) -> tuple[float, float, float]:
        vec = origin + t_dir * (u * char_w) + Vector((0.0, v * char_h, 0.0))
        return (vec.x, vec.y, vec.z)

    st = max(0.08, char_h * 0.095)
    dp = max(0.09, st * 1.1)

    add_strut(bm, p(-0.46, 0.42), p(0.46, 0.42), st, dp)
    add_strut(bm, p(0.46, 0.42), p(0.38, 0.28), st * 0.85, dp)

    variant = glyph_idx % 8
    if variant == 0:
        add_strut(bm, p(-0.18, 0.42), p(-0.18, -0.36), st, dp)
        add_strut(bm, p(-0.18, -0.36), p(0.28, -0.44), st * 0.9, dp)
        add_strut(bm, p(-0.18, 0.08), p(0.26, 0.04), st * 0.85, dp)
        add_strut(bm, p(0.26, 0.04), p(0.22, -0.22), st * 0.85, dp)
    elif variant == 1:
        add_strut(bm, p(0.18, 0.42), p(0.18, -0.34), st, dp)
        add_strut(bm, p(-0.32, 0.42), p(-0.32, 0.02), st * 0.9, dp)
        add_strut(bm, p(-0.32, 0.02), p(0.18, -0.14), st * 0.85, dp)
        add_strut(bm, p(-0.12, -0.46), p(0.34, -0.36), st * 0.8, dp)
    elif variant == 2:
        add_strut(bm, p(-0.26, 0.42), p(0.22, -0.10), st, dp)
        add_strut(bm, p(0.22, -0.10), p(-0.20, -0.44), st * 0.9, dp)
        add_strut(bm, p(0.28, 0.42), p(0.28, -0.38), st * 0.9, dp)
    elif variant == 3:
        add_strut(bm, p(0.0, 0.42), p(0.0, -0.16), st, dp)
        add_strut(bm, p(-0.34, 0.14), p(0.32, 0.14), st * 0.85, dp)
        add_strut(bm, p(-0.34, 0.14), p(-0.26, -0.34), st * 0.85, dp)
        add_strut(bm, p(-0.26, -0.34), p(0.24, -0.44), st * 0.85, dp)
        add_strut(bm, p(0.22, 0.56), p(0.38, 0.64), st * 0.75, dp)
    elif variant == 4:
        add_strut(bm, p(-0.30, 0.42), p(-0.30, -0.24), st, dp)
        add_strut(bm, p(0.16, 0.42), p(0.16, -0.42), st, dp)
        add_strut(bm, p(-0.30, -0.24), p(0.16, -0.14), st * 0.85, dp)
        add_strut(bm, p(-0.14, 0.56), p(0.08, 0.64), st * 0.75, dp)
    elif variant == 5:
        add_strut(bm, p(0.22, 0.42), p(-0.26, 0.04), st, dp)
        add_strut(bm, p(-0.26, 0.04), p(0.20, -0.26), st * 0.9, dp)
        add_strut(bm, p(0.20, -0.26), p(-0.10, -0.46), st * 0.85, dp)
        add_strut(bm, p(0.26, 0.18), p(0.34, -0.40), st * 0.85, dp)
    elif variant == 6:
        add_strut(bm, p(-0.22, 0.42), p(-0.22, -0.40), st, dp)
        add_strut(bm, p(0.22, 0.42), p(0.22, -0.18), st, dp)
        add_strut(bm, p(-0.22, 0.06), p(0.22, 0.06), st * 0.85, dp)
        add_strut(bm, p(0.22, -0.18), p(-0.04, -0.44), st * 0.85, dp)
    else:
        add_strut(bm, p(-0.08, 0.42), p(-0.28, -0.12), st, dp)
        add_strut(bm, p(-0.28, -0.12), p(0.26, -0.12), st * 0.9, dp)
        add_strut(bm, p(0.26, -0.12), p(0.06, -0.46), st * 0.9, dp)
        add_strut(bm, p(0.26, 0.42), p(0.32, 0.08), st * 0.85, dp)


def build_floating_rings_and_chains(
    root_col: bpy.types.Collection, pal: dict[str, bpy.types.Material]
) -> None:
    col = get_col("FloatingRingsAndChains", root_col)

    bm_lower_stone = bmesh.new()
    bm_lower_runes = bmesh.new()
    lower_segs = 10
    for i in range(lower_segs):
        a0 = math.tau * i / lower_segs + 0.045
        a1 = math.tau * (i + 1) / lower_segs - 0.045
        _add_curved_stone_arc(bm_lower_stone, LOWER_RING_R, LOWER_RING_Y, 2.05, 2.45, a0, a1, seed=300 + i)
        for k in range(2):
            ang = a0 + (a1 - a0) * (0.30 + k * 0.40)
            _add_arc_glyph(bm_lower_runes, i * 2 + k, ang, LOWER_RING_R + 1.03, LOWER_RING_Y, 1.48, 1.25, 1.0)
            _add_arc_glyph(bm_lower_runes, i * 2 + k + 3, ang, LOWER_RING_R - 1.03, LOWER_RING_Y, 1.42, 1.15, -1.0)
    commit_bmesh("Ring_LowerStone", bm_lower_stone, col, pal["ring_stone"], smooth_angle_deg=35.0)
    commit_bmesh("Ring_LowerRunes", bm_lower_runes, col, pal["ring_rune_blue"], smooth_angle_deg=45.0)

    bm_upper_stone = bmesh.new()
    bm_upper_runes = bmesh.new()
    upper_segs = 8
    for i in range(upper_segs):
        gap = 0.095 if i in (0, 7) else 0.055
        a0 = math.tau * i / upper_segs + gap
        a1 = math.tau * (i + 1) / upper_segs - gap
        _add_curved_stone_arc(bm_upper_stone, UPPER_RING_R, UPPER_RING_Y, 2.75, 3.35, a0, a1, seed=500 + i)
        for k in range(2):
            ang = a0 + (a1 - a0) * (0.28 + k * 0.44)
            _add_arc_glyph(bm_upper_runes, i * 3 + k, ang, UPPER_RING_R + 1.38, UPPER_RING_Y, 2.10, 1.85, 1.0)
            _add_arc_glyph(bm_upper_runes, i * 3 + k + 2, ang, UPPER_RING_R - 1.38, UPPER_RING_Y, 1.98, 1.72, -1.0)
    commit_bmesh("Ring_UpperStone", bm_upper_stone, col, pal["ring_stone"], smooth_angle_deg=35.0)
    commit_bmesh("Ring_UpperRunes", bm_upper_runes, col, pal["ring_rune_blue"], smooth_angle_deg=45.0)

    # Split iron chains cleanly under 9,500 tris per MeshPart
    bm_chains_front = bmesh.new()
    for deg in (45.0, 315.0):
        a = math.radians(deg)
        cx, cz = math.sin(a) * LOWER_RING_R, -math.cos(a) * LOWER_RING_R
        add_chain(bm_chains_front, Vector((cx, LOWER_RING_Y - 1.18, cz)), Vector((cx, PLAT_TOP_Y + 0.06, cz)), link_pitch=0.72)
        add_box(bm_chains_front, (cx, PLAT_TOP_Y + 0.08, cz), (0.95, 0.22, 0.95), rot_deg=(0, deg, 0), bevel=0.04)
    commit_bmesh("Chains_Iron_Front", bm_chains_front, col, pal["chain_iron"], all_smooth=True)

    bm_chains_back = bmesh.new()
    for deg in (135.0, 225.0):
        a = math.radians(deg)
        cx, cz = math.sin(a) * LOWER_RING_R, -math.cos(a) * LOWER_RING_R
        add_chain(bm_chains_back, Vector((cx, LOWER_RING_Y - 1.18, cz)), Vector((cx, PLAT_TOP_Y + 0.06, cz)), link_pitch=0.72)
        add_box(bm_chains_back, (cx, PLAT_TOP_Y + 0.08, cz), (0.95, 0.22, 0.95), rot_deg=(0, deg, 0), bevel=0.04)
    commit_bmesh("Chains_Iron_Back", bm_chains_back, col, pal["chain_iron"], all_smooth=True)

    bm_chains_upper = bmesh.new()
    for deg in (38.0, 142.0, 218.0, 322.0):
        a_up = math.radians(deg)
        a_lo = math.radians(deg + (24.0 if deg < 180 else -24.0))
        p_up = Vector((math.sin(a_up) * (UPPER_RING_R - 0.6), UPPER_RING_Y - 1.55, -math.cos(a_up) * (UPPER_RING_R - 0.6)))
        p_lo = Vector((math.sin(a_lo) * (LOWER_RING_R + 0.2), LOWER_RING_Y + 1.15, -math.cos(a_lo) * (LOWER_RING_R + 0.2)))
        add_chain(bm_chains_upper, p_up, p_lo, link_pitch=0.74, link_w=0.24, wire_r=0.085)

    for deg in (90.0, 270.0):
        a = math.radians(deg)
        p_up = Vector((math.sin(a) * (UPPER_RING_R - 1.2), UPPER_RING_Y - 1.45, -math.cos(a) * (UPPER_RING_R - 1.2)))
        p_lo = Vector((math.sin(a) * (LOWER_RING_R + 0.4), LOWER_RING_Y + 1.15, -math.cos(a) * (LOWER_RING_R + 0.4)))
        add_chain(bm_chains_upper, p_up, p_lo, link_pitch=0.72, link_w=0.24, wire_r=0.085)
    commit_bmesh("Chains_Iron_Upper", bm_chains_upper, col, pal["chain_iron"], all_smooth=True)


# ---------------------------------------------------------------------------
# Component 4: Mossy Stone & Interwoven Iron-Lattice Arch Bridge (Image 4)
# ---------------------------------------------------------------------------

def bridge_deck_y(z: float) -> float:
    if z <= BRIDGE_Z_HUB_PIER:
        t_in = max(0.0, min(1.0, (z - BRIDGE_Z_HUB_END) / (BRIDGE_Z_HUB_PIER - BRIDGE_Z_HUB_END)))
        return 0.08 + 0.92 * t_in
    if z >= BRIDGE_Z_PLAT_PIER:
        return PLAT_TOP_Y
    t = (z - BRIDGE_Z_HUB_PIER) / (BRIDGE_Z_PLAT_PIER - BRIDGE_Z_HUB_PIER)
    return 1.00 + (PLAT_TOP_Y - 1.00) * t + 1.05 * math.sin(math.pi * t)


def _add_finial_pillar(
    bm_stone: bmesh.types.BMesh,
    bm_moss: bmesh.types.BMesh,
    x: float,
    y_base: float,
    z: float,
    width: float,
    height: float,
) -> None:
    add_box(bm_moss, (x, y_base + 0.35, z), (width * 1.24, 0.72, width * 1.24), bevel=0.05)
    add_box(bm_moss, (x, y_base + 0.85, z), (width * 1.10, 0.42, width * 1.10), bevel=0.04)
    shaft_h = max(0.8, height - 1.25)
    add_box(bm_stone, (x, y_base + 0.95 + shaft_h * 0.5, z), (width, shaft_h, width), bevel=0.05)
    cap_y = y_base + 0.95 + shaft_h
    add_box(bm_stone, (x, cap_y + 0.16, z), (width * 1.26, 0.28, width * 1.26), bevel=0.04)
    add_box(bm_stone, (x, cap_y + 0.36, z), (width * 1.04, 0.16, width * 1.04), bevel=0.03)
    fy = cap_y + 0.44
    add_box(bm_stone, (x, fy + 0.12, z), (width * 0.58, 0.24, width * 0.58), rot_deg=(0, 45, 0), bevel=0.05)
    fin_levels = [(0.16, 0.34), (0.38, 0.44), (0.64, 0.34), (0.90, 0.18), (1.14, 0.03)]
    tmp_fin = bmesh.new()
    rings: list[list[bmesh.types.BMVert]] = []
    segs = 8
    for dy, rad in fin_levels:
        r_scaled = rad * (width / 1.15)
        ring = []
        for s in range(segs):
            a = math.tau * s / segs
            ring.append(tmp_fin.verts.new(r2b((x + math.cos(a) * r_scaled, fy + dy, z + math.sin(a) * r_scaled))))
        rings.append(ring)
    for li in range(len(rings) - 1):
        ra, rb = rings[li], rings[li + 1]
        for s in range(segs):
            ns = (s + 1) % segs
            tmp_fin.faces.new((ra[s], rb[s], rb[ns], ra[ns]))
    tmp_fin.faces.new(list(reversed(rings[0])))
    tmp_fin.faces.new(rings[-1])
    ensure_outward_solid(tmp_fin)
    merge_bmesh(bm_stone, tmp_fin)
    tmp_fin.free()


def _add_sloped_wing_wall(
    bm_stone: bmesh.types.BMesh,
    bm_moss: bmesh.types.BMesh,
    x: float,
    z0: float,
    y_bot0: float,
    y_top0: float,
    z1: float,
    y_bot1: float,
    y_top1: float,
    thickness: float = 0.78,
) -> None:
    hw = thickness * 0.5
    pts_zy = [(z0, y_bot0), (z1, y_bot1), (z1, y_top1), (z0, y_top0)]
    tmp = bmesh.new()
    vl = [tmp.verts.new(r2b((x - hw, y, z))) for (z, y) in pts_zy]
    vr = [tmp.verts.new(r2b((x + hw, y, z))) for (z, y) in pts_zy]
    tmp.faces.new(list(reversed(vl)))
    tmp.faces.new(vr)
    for k in range(4):
        nk = (k + 1) % 4
        tmp.faces.new((vl[k], vl[nk], vr[nk], vr[k]))
    ensure_outward_solid(tmp)
    bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=0.04, segments=1, affect="EDGES", clamp_overlap=True)
    ensure_outward_solid(tmp)
    merge_bmesh(bm_stone, tmp)
    tmp.free()

    dz = z1 - z0
    dy = y_top1 - y_top0
    coping_len = math.hypot(dz, dy) + 0.12
    pitch = -math.degrees(math.atan2(dy, dz))
    add_box(
        bm_stone,
        (x, (y_top0 + y_top1) * 0.5 + 0.12, (z0 + z1) * 0.5),
        (thickness + 0.20, 0.24, coping_len),
        rot_deg=(pitch, 0.0, 0.0),
        bevel=0.03,
    )
    add_box(
        bm_moss,
        (x, (y_bot0 + y_bot1) * 0.5 + 0.34, (z0 + z1) * 0.5),
        (thickness + 0.24, 0.74, abs(dz) + 0.15),
        rot_deg=(-math.degrees(math.atan2(y_bot1 - y_bot0, dz)), 0.0, 0.0),
        bevel=0.05,
    )


def build_sanctuary_bridge(root_col: bpy.types.Collection, pal: dict[str, bpy.types.Material]) -> None:
    col = get_col("SanctuaryBridge", root_col)

    bm_deck = bmesh.new()
    n_span = 22
    hw = BRIDGE_HALF_W
    deck_t = 0.62
    for i in range(n_span):
        z0 = BRIDGE_Z_HUB_END + (BRIDGE_Z_PLAT_END - BRIDGE_Z_HUB_END) * (i / n_span)
        z1 = BRIDGE_Z_HUB_END + (BRIDGE_Z_PLAT_END - BRIDGE_Z_HUB_END) * ((i + 1) / n_span)
        y0, y1 = bridge_deck_y(z0), bridge_deck_y(z1)
        ym = (y0 + y1) * 0.5
        zm = (z0 + z1) * 0.5
        dz = z1 - z0
        dy = y1 - y0
        seg_len = math.hypot(dz, dy) + 0.08
        pitch = -math.degrees(math.atan2(dy, dz))
        add_box(bm_deck, (0.0, ym - deck_t * 0.5, zm), (hw * 2.0, deck_t, seg_len), rot_deg=(pitch, 0, 0), bevel=0.04)
        for sx in (-1.0, 1.0):
            add_box(bm_deck, (sx * (hw - 0.24), ym + 0.16, zm), (0.48, 0.36, seg_len), rot_deg=(pitch, 0, 0), bevel=0.03)
    commit_bmesh("Bridge_WalkwayDeck", bm_deck, col, pal["bridge_deck"], smooth_angle_deg=35.0)

    bm_stone = bmesh.new()
    bm_moss = bmesh.new()
    for sx in (-1.0, 1.0):
        px = sx * (hw + 0.42)
        _add_finial_pillar(bm_stone, bm_moss, px, -0.20, -27.2, width=1.10, height=2.85)
        _add_finial_pillar(bm_stone, bm_moss, px, 0.0, -23.8, width=1.28, height=4.45)
        _add_sloped_wing_wall(bm_stone, bm_moss, px, -27.2, -0.20, 1.95, -23.8, 0.0, 3.15)

        _add_finial_pillar(bm_stone, bm_moss, px, PLAT_TOP_Y - 0.55, -12.4, width=1.28, height=4.50)
        _add_finial_pillar(bm_stone, bm_moss, px, PLAT_TOP_Y - 0.25, -9.6, width=1.10, height=3.05)
        _add_sloped_wing_wall(
            bm_stone, bm_moss, px, -12.4, PLAT_TOP_Y - 0.55, PLAT_TOP_Y + 3.05, -9.6, PLAT_TOP_Y - 0.25, PLAT_TOP_Y + 2.00
        )

    commit_bmesh("Bridge_StoneAbutments", bm_stone, col, pal["bridge_stone"], smooth_angle_deg=35.0)
    commit_bmesh("Bridge_StoneMoss", bm_moss, col, pal["bridge_moss"], smooth_angle_deg=38.0)

    bm_lattice = bmesh.new()
    bm_canopy = bmesh.new()
    z_a = BRIDGE_Z_HUB_PIER + 0.25
    z_b = BRIDGE_Z_PLAT_PIER - 0.25
    span_z = z_b - z_a
    samples = 48

    for sx in (-1.0, 1.0):
        rx_base = sx * (hw + 0.18)
        rail_pts = [
            Vector((rx_base, bridge_deck_y(z_a + span_z * (k / samples)) + 2.55, z_a + span_z * (k / samples)))
            for k in range(samples + 1)
        ]
        add_swept_tube(bm_lattice, rail_pts, radius=0.145, segs=8, closed=False)

        chord_pts = [
            Vector((
                rx_base,
                bridge_deck_y(z_a + span_z * (k / samples)) - 0.45 - 1.55 * math.sin(math.pi * k / samples),
                z_a + span_z * (k / samples),
            ))
            for k in range(samples + 1)
        ]
        add_swept_tube(bm_lattice, chord_pts, radius=0.22, segs=8, closed=False)

        wave_a_pts = []
        wave_b_pts = []
        for k in range(samples + 1):
            t = k / samples
            zz = z_a + span_z * t
            yd = bridge_deck_y(zz)
            env = math.sin(math.pi * t) ** 0.35
            ya = yd + 0.95 + (1.45 * math.sin(t * math.pi * 6.0) + 0.15) * env
            yb = yd + 0.55 + (1.85 * math.sin(t * math.pi * 6.0 + math.pi) - 0.55) * env
            xa = rx_base + sx * 0.12 * math.cos(t * math.pi * 6.0)
            xb = rx_base - sx * 0.12 * math.cos(t * math.pi * 6.0)
            wave_a_pts.append(Vector((xa, ya, zz)))
            wave_b_pts.append(Vector((xb, yb, zz)))
        add_swept_tube(bm_lattice, wave_a_pts, radius=0.135, segs=7, closed=False)
        add_swept_tube(bm_lattice, wave_b_pts, radius=0.155, segs=7, closed=False)

        z_mid = (z_a + z_b) * 0.5
        y_mid_deck = bridge_deck_y(z_mid)
        loop_pts: list[Vector] = []
        loop_segs = 44
        loop_rz = 4.95
        loop_ry_up = 8.15
        loop_ry_dn = 2.65
        for k in range(loop_segs):
            ang = math.tau * k / loop_segs
            sa, ca = math.sin(ang), math.cos(ang)
            z_off = ca * loop_rz * (1.0 - 0.12 * max(0.0, sa))
            y_off = sa * (loop_ry_up if sa >= 0 else loop_ry_dn)
            lean_x = -sx * max(0.0, y_off) * 0.18
            loop_pts.append(Vector((rx_base + lean_x, y_mid_deck + 0.15 + y_off, z_mid + z_off)))
        add_swept_tube(bm_canopy, loop_pts, radius=0.15, segs=9, closed=True)

    commit_bmesh("Bridge_IronLattice", bm_lattice, col, pal["bridge_iron"], all_smooth=True)
    commit_bmesh("Bridge_CanopyRings", bm_canopy, col, pal["bridge_iron"], all_smooth=True)


# ---------------------------------------------------------------------------
# Component 5: Hub Chasm Wall (exported) + Preview Grass Context (preview only)
# ---------------------------------------------------------------------------

def build_chasm_rim(root_col: bpy.types.Collection, pal: dict[str, bpy.types.Material]) -> None:
    col = get_col("ChasmRim", root_col)
    rng = random.Random(4242)

    bm_wall = bmesh.new()
    # Closed thick annular rocky cliff wall lining the chasm perimeter from lawn level down into void.
    # Inner face sits slightly inside HOLE_RADIUS (21.55 < 22.0) at the top to shield any meadow skirt gap.
    wall_levels = [
        (0.20, HOLE_RADIUS - 0.78, 0.12),
        (-1.60, HOLE_RADIUS - 0.65, 0.18),
        (-4.40, HOLE_RADIUS - 0.15, 0.25),
        (-8.20, HOLE_RADIUS + 0.35, 0.35),
        (-12.6, HOLE_RADIUS + 0.80, 0.40),
        (-17.4, HOLE_RADIUS + 1.25, 0.35),
    ]
    n_wall = 32
    tmp_cliff = bmesh.new()
    in_rings: list[list[bmesh.types.BMVert]] = []
    out_rings: list[list[bmesh.types.BMVert]] = []
    for wy, wr, jit in wall_levels:
        r_in_ring = []
        r_out_ring = []
        for k in range(n_wall):
            a = math.tau * k / n_wall
            r_in = wr + rng.uniform(-jit, jit)
            # Keep the top cliff lip flush below bridge approach deck
            sx, cz = math.sin(a), -math.cos(a)
            if wy > -0.5 and cz < -0.72 and abs(sx * r_in) < 4.4:
                y_cur = -0.15
            else:
                y_cur = wy
            r_in_ring.append(tmp_cliff.verts.new(r2b((sx * r_in, y_cur, cz * r_in))))
            r_out = r_in + 1.15
            r_out_ring.append(tmp_cliff.verts.new(r2b((sx * r_out, y_cur, cz * r_out))))
        in_rings.append(r_in_ring)
        out_rings.append(r_out_ring)

    for li in range(len(in_rings) - 1):
        ia, ib = in_rings[li], in_rings[li + 1]
        oa, ob = out_rings[li], out_rings[li + 1]
        for k in range(n_wall):
            nk = (k + 1) % n_wall
            tmp_cliff.faces.new((ia[k], ib[k], ib[nk], ia[nk]))
            tmp_cliff.faces.new((oa[k], oa[nk], ob[nk], ob[k]))
    for k in range(n_wall):
        nk = (k + 1) % n_wall
        tmp_cliff.faces.new((in_rings[0][k], in_rings[0][nk], out_rings[0][nk], out_rings[0][k]))
        tmp_cliff.faces.new((in_rings[-1][k], out_rings[-1][k], out_rings[-1][nk], in_rings[-1][nk]))

    ensure_outward_solid(tmp_cliff)
    merge_bmesh(bm_wall, tmp_cliff)
    tmp_cliff.free()

    for i in range(44):
        a = math.tau * i / 44 + rng.uniform(-0.025, 0.025)
        r_off = HOLE_RADIUS + rng.uniform(-0.20, 0.55)
        rx = math.sin(a) * r_off
        rz = -math.cos(a) * r_off
        if rz < -HOLE_RADIUS * 0.72 and abs(rx) < 4.4:
            continue
        add_box(
            bm_wall,
            (rx, rng.uniform(-0.22, 0.22), rz),
            (rng.uniform(2.8, 4.5), rng.uniform(0.95, 1.45), rng.uniform(1.8, 2.9)),
            rot_deg=(rng.uniform(-9, 9), -math.degrees(a) + rng.uniform(-16, 16), rng.uniform(-9, 9)),
            bevel=0.18,
        )
    commit_bmesh("Hub_ChasmWall", bm_wall, col, pal["rock_deep"], smooth_angle_deg=35.0)


def build_preview_grass_context(pal: dict[str, bpy.types.Material]) -> bpy.types.Collection:
    """Preview-only meadow ring around the chasm hole (excluded from FBX & Luau shards)."""
    col = get_col("PreviewContext")
    bm_lawn = bmesh.new()
    n_ang = 48
    outer_extent = 48.0
    in_verts: list[bmesh.types.BMVert] = []
    out_verts: list[bmesh.types.BMVert] = []
    for i in range(n_ang):
        a = math.tau * i / n_ang
        sa, ca = math.sin(a), math.cos(a)
        in_verts.append(bm_lawn.verts.new(r2b((sa * HOLE_RADIUS, 0.0, -ca * HOLE_RADIUS))))
        scale = outer_extent / max(abs(sa), abs(ca), 1e-6)
        out_verts.append(bm_lawn.verts.new(r2b((sa * scale, 0.0, -ca * scale))))
    for i in range(n_ang):
        ni = (i + 1) % n_ang
        bm_lawn.faces.new((in_verts[i], out_verts[i], out_verts[ni], in_verts[ni]))
    commit_bmesh("Hub_LawnRim", bm_lawn, col, pal["hub_grass"], smooth_angle_deg=50.0)
    return col


# ---------------------------------------------------------------------------
# FBX Export, Manifest & Packed Luau BMesh Shards
# ---------------------------------------------------------------------------

def extract_part_geometry(obj: bpy.types.Object, root_col: bpy.types.Collection) -> dict:
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces, ngon_method="EAR_CLIP")
    bm.verts.ensure_lookup_table()

    # Convert Blender Z-up back to Roblox Y-up: (bx, by, bz) -> (bx, bz, -by)
    pts = [(v.co.x, v.co.z, -v.co.y) for v in bm.verts]
    xs, ys, zs = [p[0] for p in pts], [p[1] for p in pts], [p[2] for p in pts]
    cx, cy, cz = (min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5

    flat_verts = []
    for px, py, pz in pts:
        flat_verts.extend([round(px - cx, 4), round(py - cy, 4), round(pz - cz, 4)])
    flat_tris = []
    for f in bm.faces:
        if len(f.verts) == 3:
            flat_tris.extend([f.verts[0].index + 1, f.verts[1].index + 1, f.verts[2].index + 1])
    bm.free()

    mat = obj.data.materials[0] if obj.data.materials else None
    sub_col = next((c.name for c in obj.users_collection if c != root_col), "")
    clean_name = re.sub(r"\.\d+$", "", obj.name)
    return {
        "Name": clean_name,
        "SubCollection": sub_col,
        "Offset": [round(cx, 4), round(cy, 4), round(cz, 4)],
        "Size": [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)],
        "Material": mat.get("rbx_material", "Slate") if mat else "Slate",
        "Color": list(mat.get("rbx_color", [92, 88, 98])) if mat else [92, 88, 98],
        "Collidable": bool(obj.get("rbx_collidable", False)),
        "MeshId": "",
        "Verts": flat_verts,
        "Tris": flat_tris,
    }


def load_uploaded_mesh_ids() -> dict:
    if not MESH_IDS_PATH.exists():
        return {}
    return json.loads(MESH_IDS_PATH.read_text(encoding="utf-8"))


def _encode_part_buffers(p: dict) -> tuple[str, str]:
    verts, tris = p["Verts"], p["Tris"]
    sx, sy, sz = p["Size"]
    hx, hy, hz = max(1e-5, sx * 0.5), max(1e-5, sy * 0.5), max(1e-5, sz * 0.5)
    vbuf = bytearray()
    for i in range(0, len(verts), 3):
        qx = max(-32767, min(32767, round((verts[i] / hx) * 32767.0)))
        qy = max(-32767, min(32767, round((verts[i + 1] / hy) * 32767.0)))
        qz = max(-32767, min(32767, round((verts[i + 2] / hz) * 32767.0)))
        vbuf.extend(struct.pack("<hhh", qx, qy, qz))
    tbuf = bytearray()
    for i in range(0, len(tris), 3):
        tbuf.extend(struct.pack("<HHH", tris[i], tris[i + 1], tris[i + 2]))
    return base64.b64encode(bytes(vbuf)).decode("ascii"), base64.b64encode(bytes(tbuf)).decode("ascii")


def export_sanctuary(root_col: bpy.types.Collection) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    objs = [o for o in root_col.all_objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active = objs[0]

    # Exact Roblox axis alignment: axis_forward="Z", axis_up="Y", bake_space_transform=False
    bpy.ops.export_scene.fbx(
        filepath=str(FBX_PATH),
        use_selection=True,
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        axis_forward="Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=False,
    )
    print(f"[Runesmith] Exported FBX -> {FBX_PATH} ({FBX_PATH.stat().st_size} bytes)")

    uploaded = load_uploaded_mesh_ids().get("runesmith_sanctuary", {})
    parts_full, parts_summary, tri_total = [], [], 0
    for obj in objs:
        pinfo = extract_part_geometry(obj, root_col)
        pinfo["MeshId"] = uploaded.get(pinfo["Name"], "")
        tris = len(pinfo["Tris"]) // 3
        tri_total += tris
        print(f"  - {pinfo['SubCollection']:24s} / {pinfo['Name']:22s} tris={tris:5d}")
        parts_full.append(pinfo)
        parts_summary.append({k: v for k, v in pinfo.items() if k not in ("Verts", "Tris")})

    manifest = {
        "TemplateId": "runesmith_sanctuary",
        "FBX": FBX_PATH.name,
        "AxisForward": "Z",
        "AxisUp": "Y",
        "Triangles": tri_total,
        "HoleRadius": HOLE_RADIUS,
        "PlatformRadius": PLAT_RADIUS,
        "PlatformTopY": PLAT_TOP_Y,
        "BridgeZHubEnd": BRIDGE_Z_HUB_END,
        "BridgeZPlatEnd": BRIDGE_Z_PLAT_END,
        "Parts": parts_summary,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"[Runesmith] Wrote manifest -> {MANIFEST_PATH} (total tris={tri_total}, parts={len(parts_full)})")

    # Write Luau geometry shards + loader module
    SHARDS_DIR.mkdir(parents=True, exist_ok=True)
    shard_path = SHARDS_DIR / "runesmith_sanctuary.luau"
    lines = [
        "--!nocheck",
        "-- ReplicatedStorage/Assets/RunesmithMeshes/runesmith_sanctuary.luau",
        "-- Generated directly from Blender geometry (tools/blender/generate_runesmith_sanctuary.py).",
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
            f'\t\tMaterial = Enum.Material.{p["Material"]}, Color = Color3.fromRGB({c[0]}, {c[1]}, {c[2]}),',
            f"\t\tCollidable = {col_lit}, MeshId = {mesh_lit},",
            f'\t\tVB = "{vb}",',
            f'\t\tTB = "{tb}",',
            "\t},",
        ])
    lines.append("}")
    shard_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[Runesmith] Wrote shard -> {shard_path} ({shard_path.stat().st_size} bytes)")

    loader_src = """--!strict
-- ReplicatedStorage/Assets/RunesmithMeshData.luau
-- Decodes Blender-authored Runesmith Sanctuary geometry shards from ReplicatedStorage.Assets.RunesmithMeshes.

local RunesmithMeshData = {}

export type PartMeshSpec = {
	Name: string,
	SubCollection: string,
	Offset: Vector3,
	Size: Vector3,
	Material: Enum.Material,
	Color: Color3,
	Collidable: boolean,
	MeshId: string,
	VB: string?,
	TB: string?,
	Verts: { number }?,
	Tris: { number }?,
}

local B64_LOOKUP = table.create(256, -1)
do
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	for i = 1, #alphabet do
		B64_LOOKUP[string.byte(alphabet, i)] = i - 1
	end
end

local function decodeBase64(str: string): buffer
	local len = #str
	local pad = if len >= 2 and string.sub(str, len - 1, len) == "==" then 2 elseif len >= 1 and string.sub(str, len, len) == "=" then 1 else 0
	local outLen = (len // 4) * 3 - pad
	local buf = buffer.create(outLen)
	local outPos = 0
	for i = 1, len, 4 do
		local a = B64_LOOKUP[string.byte(str, i)] or 0
		local b = B64_LOOKUP[string.byte(str, i + 1)] or 0
		local c = B64_LOOKUP[string.byte(str, i + 2)]
		local d = B64_LOOKUP[string.byte(str, i + 3)]
		local bits = bit32.lshift(a, 18) + bit32.lshift(b, 12) + bit32.lshift(if c and c >= 0 then c else 0, 6) + (if d and d >= 0 then d else 0)
		if outPos < outLen then
			buffer.writeu8(buf, outPos, bit32.band(bit32.rshift(bits, 16), 255))
			outPos += 1
		end
		if outPos < outLen then
			buffer.writeu8(buf, outPos, bit32.band(bit32.rshift(bits, 8), 255))
			outPos += 1
		end
		if outPos < outLen then
			buffer.writeu8(buf, outPos, bit32.band(bits, 255))
			outPos += 1
		end
	end
	return buf
end

local function unpackVerts(vb: string, size: Vector3): { number }
	local buf = decodeBase64(vb)
	local nBytes = buffer.len(buf)
	local verts = table.create(nBytes // 2)
	local hx = math.max(1e-5, size.X * 0.5) / 32767
	local hy = math.max(1e-5, size.Y * 0.5) / 32767
	local hz = math.max(1e-5, size.Z * 0.5) / 32767
	for off = 0, nBytes - 6, 6 do
		verts[#verts + 1] = buffer.readi16(buf, off) * hx
		verts[#verts + 1] = buffer.readi16(buf, off + 2) * hy
		verts[#verts + 1] = buffer.readi16(buf, off + 4) * hz
	end
	return verts
end

local function unpackTris(tb: string): { number }
	local buf = decodeBase64(tb)
	local nBytes = buffer.len(buf)
	local tris = table.create(nBytes // 2)
	for off = 0, nBytes - 2, 2 do
		tris[#tris + 1] = buffer.readu16(buf, off)
	end
	return tris
end

local function unpackModel(shardModule: Instance): { PartMeshSpec }
	local rawList = require(shardModule :: ModuleScript) :: { any }
	local unpacked = table.create(#rawList)
	for _, raw in ipairs(rawList) do
		unpacked[#unpacked + 1] = {
			Name = raw.Name,
			SubCollection = raw.SubCollection,
			Offset = raw.Offset,
			Size = raw.Size,
			Material = raw.Material,
			Color = raw.Color,
			Collidable = raw.Collidable,
			MeshId = raw.MeshId or "",
			VB = raw.VB,
			TB = raw.TB,
			Verts = raw.Verts,
			Tris = raw.Tris,
		}
	end
	return unpacked
end

function RunesmithMeshData.GetGeometry(spec: PartMeshSpec): ({ number }, { number })
	if not spec.Verts then
		spec.Verts = if spec.VB then unpackVerts(spec.VB, spec.Size) else {}
	end
	if not spec.Tris then
		spec.Tris = if spec.TB then unpackTris(spec.TB) else {}
	end
	return spec.Verts :: { number }, spec.Tris :: { number }
end

local MeshesFolder = (script.Parent :: Instance):WaitForChild("RunesmithMeshes")

RunesmithMeshData.Models = {
	runesmith_sanctuary = unpackModel(MeshesFolder:WaitForChild("runesmith_sanctuary")),
} :: { [string]: { PartMeshSpec } }

return RunesmithMeshData
"""
    LUAU_DATA_PATH.write_text(loader_src, encoding="utf-8")
    print(f"[Runesmith] Wrote Luau mesh data loader -> {LUAU_DATA_PATH}")


# ---------------------------------------------------------------------------
# Preview Lighting, Cameras & Multi-Angle Rendering
# ---------------------------------------------------------------------------

def save_blend_and_render(do_render: bool) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    blend_path = OUT_DIR / "runesmith_sanctuary.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    print(f"[Runesmith] Saved Blender file -> {blend_path}")

    if not do_render:
        return

    scene = bpy.context.scene
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"

    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX" if "AgX" in [
        i.identifier for i in scene.view_settings.bl_rna.properties["view_transform"].enum_items
    ] else "Standard"
    scene.view_settings.exposure = 0.20

    world = bpy.data.worlds.new("RunesmithPreviewWorld")
    scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Color"].default_value = (0.11, 0.14, 0.21, 1.0)
    bg.inputs["Strength"].default_value = 1.25
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])

    def add_sun(name: str, rot_deg: tuple[float, float, float], energy: float, color: tuple[float, float, float]) -> None:
        ld = bpy.data.lights.new(name, type="SUN")
        ld.energy = energy
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        lo.rotation_euler = Euler([math.radians(a) for a in rot_deg], "XYZ")
        scene.collection.objects.link(lo)

    def add_point(name: str, rpos: tuple[float, float, float], energy: float, color: tuple[float, float, float], radius: float = 1.5) -> None:
        ld = bpy.data.lights.new(name, type="POINT")
        ld.energy = energy
        ld.color = color
        ld.shadow_soft_size = radius
        lo = bpy.data.objects.new(name, ld)
        lo.location = r2b(rpos)
        scene.collection.objects.link(lo)

    add_sun("KeySun", (48.0, 22.0, -35.0), 2.8, (1.0, 0.92, 0.80))
    add_sun("SkyRimSun", (68.0, -140.0, 120.0), 1.0, (0.62, 0.80, 1.0))

    add_point("AnvilMoltenFront", (0.0, 6.8, -2.5), 260.0, (1.0, 0.44, 0.10), 1.0)
    add_point("AnvilMoltenBack", (0.0, 6.8, 2.5), 200.0, (1.0, 0.42, 0.08), 1.0)
    add_point("AnvilHornMetallicFill", (-7.5, 10.2, -5.5), 260.0, (0.86, 0.90, 1.0), 2.5)
    add_point("GoldenChainGlow", (0.0, 14.5, 0.0), 340.0, (1.0, 0.82, 0.42), 2.0)
    add_point("BlueRingsGlow", (0.0, 25.0, 0.0), 750.0, (0.35, 0.80, 1.0), 4.0)
    add_point("BridgeFillLight", (-8.0, 10.0, -21.0), 480.0, (0.96, 0.93, 0.86), 3.2)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam

    shots = [
        {
            "filename": "runesmith_sanctuary_overview.png",
            "res": (1600, 1060),
            "lens": 28.0,
            "pos": (-38.0, 32.0, -48.0),
            "target": (0.0, 11.5, -5.0),
        },
        {
            "filename": "runesmith_floating_rings_hero.png",
            "res": (1280, 1440),
            "lens": 25.0,
            "pos": (26.0, 7.5, -36.0),
            "target": (-1.5, 14.5, -2.0),
        },
        {
            "filename": "runesmith_anvil_closeup.png",
            "res": (1440, 1080),
            "lens": 28.0,
            "pos": (-5.6, 10.7, -6.0),
            "target": (-0.9, 6.8, 0.0),
        },
        {
            "filename": "runesmith_bridge_closeup.png",
            "res": (1520, 1040),
            "lens": 26.0,
            "pos": (-22.5, 9.2, -26.5),
            "target": (0.0, 5.2, -18.0),
        },
    ]

    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    for shot in shots:
        scene.render.resolution_x = shot["res"][0]
        scene.render.resolution_y = shot["res"][1]
        cam_data.lens = shot["lens"]
        cam.location = r2b(shot["pos"])
        tgt = r2b(shot["target"])
        cam.rotation_euler = (tgt - cam.location).normalized().to_track_quat("-Z", "Y").to_euler()
        out_png = PREVIEW_DIR / shot["filename"]
        scene.render.filepath = str(out_png)
        bpy.ops.render.render(write_still=True)
        print(f"[Runesmith] Rendered preview -> {out_png}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Runesmith Sanctuary FBX + Luau BMesh Shards")
    parser.add_argument("--no-render", action="store_true")
    cli_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args, _ = parser.parse_known_args(cli_args)

    clear_scene()
    root_col = get_col("RunesmithSanctuary")
    pal = create_palette()

    build_runesmith_anvil(root_col, pal)
    build_floating_platform(root_col, pal)
    build_floating_rings_and_chains(root_col, pal)
    build_sanctuary_bridge(root_col, pal)
    build_chasm_rim(root_col, pal)

    # Export Sanctuary FBX & packed BMesh Luau shards BEFORE adding preview-only grass context
    export_sanctuary(root_col)
    build_preview_grass_context(pal)
    save_blend_and_render(do_render=not args.no_render)


if __name__ == "__main__":
    main()
