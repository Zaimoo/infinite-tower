"""
=============================================================================
Infinite Towers: Become a Master! - 3D Environment & VFX Pipeline
Asset: Central Gothic Tiered Goddess Fountain (`GoddessFountain_Asset`)
Reference:
  - Implementation Plan: fountain_overhaul_plan.md
Target Engine: Blender 4.x / 5.x -> Roblox Studio (MeshPart / PlazaFountain)
=============================================================================
Procedural generation script that builds the multi-tiered gothic stone fountain
and 1:1 classical/gothic draped Goddess Statue in the `GoddessFountain_Asset`
collection, split into the 3 modular MeshPart exports required by the plan:

  1. `Fountain_Base_And_Tiers` - Wide circular ground basin with gold filigree
     relief panels, 4 semi-circular outer catch basins, 4 square gold-topped
     rim piers, lower-mid basin with 4 arched spout hoods and 12 rim spouts,
     8-column gothic pointed/round arch colonnade, upper-mid basin with 8
     carved gargoyle spouts, fluted pedestal with volute brackets, and top
     crown basin.
  2. `Goddess_Statue`          - Detailed 1:1 classical/gothic draped goddess
     standing on the top pedestal (~3,400 tris, Shade Auto Smooth 35 deg),
     featuring a pleated chiton with golden waist sash, flowing shoulder shawl,
     wavy hair, ornate golden diadem crown, raised left blessing hand, and
     tilted amphora (water jug) held in her right hand pouring water.
  3. `Water_Surface_Meshes`    - UV-mapped planar water discs inside Tier 1,
     the 4 outer catch basins, Tier 2, Tier 3, and Tier 4 for UV-scrolling
     water ripples.
  4. Empty Sockets: `Waterfall_Spout_1`..`Waterfall_Spout_29` and matching
     `Waterfall_Impact_1`..`Waterfall_Impact_29` for Roblox `Beam` waterfalls
     and `ParticleEmitter` splash/mist impacts.

Coordinate Convention (1 Blender Meter = 1 Roblox Stud):
  - In Roblox fountain-local coordinates:
      rx = Right (+X), ry = Up (+Y), rz = Front (-Z faces front gate, +Z rear)
  - In Blender world coordinates:
      bx = rx (+X), by = -rz (-Y is +Z), bz = ry (+Z is Up).
=============================================================================
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix

COLLECTION_NAME = "GoddessFountain_Asset"

MATERIAL_SPECS = {
    "Mat_GothicStoneDark": {
        "hex": "#383D47",
        "metallic": 0.08,
        "roughness": 0.84,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "Mat_GothicStoneLight": {
        "hex": "#58606E",
        "metallic": 0.06,
        "roughness": 0.76,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "Mat_GoddessMarble": {
        "hex": "#CDD2DC",
        "metallic": 0.04,
        "roughness": 0.62,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "Mat_AntiqueGoldTrim": {
        "hex": "#C89B3C",
        "metallic": 0.82,
        "roughness": 0.34,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "Mat_FountainWaterCyan": {
        "hex": "#0EA5E9",
        "metallic": 0.05,
        "roughness": 0.18,
        "emission": "#0EA5E9",
        "emission_strength": 0.45,
    },
}

MAT_KEYS = [
    "Mat_GothicStoneDark",    # 0
    "Mat_GothicStoneLight",   # 1
    "Mat_GoddessMarble",      # 2
    "Mat_AntiqueGoldTrim",    # 3
    "Mat_FountainWaterCyan",  # 4
]

M_STONE_DARK  = 0
M_STONE_LIGHT = 1
M_MARBLE      = 2
M_GOLD        = 3
M_WATER       = 4


def hex_to_rgb(hex_str: str) -> tuple:
    c = hex_str.lstrip("#")
    return tuple(int(c[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def rbx_to_blender(rx: float, ry: float, rz: float) -> Vector:
    return Vector((rx, -rz, ry))


def build_materials() -> list:
    mat_list = []
    for mat_name in MAT_KEYS:
        spec = MATERIAL_SPECS[mat_name]
        mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(name=mat_name)
        mat.use_nodes = True
        tree = mat.node_tree
        bsdf = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        r, g, b = hex_to_rgb(spec["hex"])
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
            bsdf.inputs["Metallic"].default_value = spec["metallic"]
            bsdf.inputs["Roughness"].default_value = spec["roughness"]
            if spec["emission_strength"] > 0.0:
                er, eg, eb = hex_to_rgb(spec["emission"])
                if "Emission Color" in bsdf.inputs:
                    bsdf.inputs["Emission Color"].default_value = (er, eg, eb, 1.0)
                elif "Emission" in bsdf.inputs:
                    bsdf.inputs["Emission"].default_value = (er, eg, eb, 1.0)
                if "Emission Strength" in bsdf.inputs:
                    bsdf.inputs["Emission Strength"].default_value = spec["emission_strength"]
        mat.diffuse_color = (r, g, b, 1.0)
        mat_list.append(mat)
    return mat_list


# =============================================================================
# BMESH PRIMITIVES IN ROBLOX COORDINATES (rx, ry_up, rz)
# =============================================================================
def add_box(
    bm: bmesh.types.BMesh,
    cx: float,
    cy: float,
    cz: float,
    sx: float,
    sy: float,
    sz: float,
    mat_idx: int,
    yaw_rad: float = 0.0,
    pitch_rad: float = 0.0,
    roll_rad: float = 0.0,
):
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    local_pts = [
        (-hx, -hy, -hz),
        ( hx, -hy, -hz),
        ( hx, -hy,  hz),
        (-hx, -hy,  hz),
        (-hx,  hy, -hz),
        ( hx,  hy, -hz),
        ( hx,  hy,  hz),
        (-hx,  hy,  hz),
    ]
    cyaw, syaw = math.cos(yaw_rad), math.sin(yaw_rad)
    cp, sp = math.cos(pitch_rad), math.sin(pitch_rad)
    cr, sr = math.cos(roll_rad), math.sin(roll_rad)

    verts = []
    for lx, ly, lz in local_pts:
        x1 = lx * cr - ly * sr
        y1 = lx * sr + ly * cr
        z1 = lz
        x2 = x1
        y2 = y1 * cp - z1 * sp
        z2 = y1 * sp + z1 * cp
        rx = cx + (x2 * cyaw + z2 * syaw)
        ry = cy + y2
        rz = cz + (-x2 * syaw + z2 * cyaw)
        verts.append(bm.verts.new(rbx_to_blender(rx, ry, rz)))

    faces = [
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (3, 7, 6, 2),
        (1, 2, 6, 5),
        (0, 1, 5, 4),
        (0, 4, 7, 3),
    ]
    for i0, i1, i2, i3 in faces:
        try:
            f = bm.faces.new((verts[i0], verts[i1], verts[i2], verts[i3]))
            f.material_index = mat_idx
        except ValueError:
            pass


def add_ring_box(
    bm: bmesh.types.BMesh,
    angle_deg: float,
    radius: float,
    cy: float,
    sx: float,
    sy: float,
    sz: float,
    mat_idx: int,
    pitch_rad: float = 0.0,
    roll_rad: float = 0.0,
):
    a = math.radians(angle_deg)
    cx = math.sin(a) * radius
    cz = math.cos(a) * radius
    add_box(bm, cx, cy, cz, sx, sy, sz, mat_idx, yaw_rad=a, pitch_rad=pitch_rad, roll_rad=roll_rad)


def add_cylinder_y(
    bm: bmesh.types.BMesh,
    cx: float,
    y0: float,
    y1: float,
    cz: float,
    r0: float,
    r1: float,
    mat_idx: int,
    sides: int = 24,
    cap_bottom: bool = True,
    cap_top: bool = True,
):
    ring0 = []
    ring1 = []
    for i in range(sides):
        a = (i / sides) * math.tau
        sa, ca = math.sin(a), math.cos(a)
        ring0.append(bm.verts.new(rbx_to_blender(cx + sa * r0, y0, cz + ca * r0)))
        ring1.append(bm.verts.new(rbx_to_blender(cx + sa * r1, y1, cz + ca * r1)))

    for i in range(sides):
        ni = (i + 1) % sides
        try:
            f = bm.faces.new((ring0[i], ring0[ni], ring1[ni], ring1[i]))
            f.material_index = mat_idx
        except ValueError:
            pass

    if cap_bottom and r0 > 0.001:
        try:
            fb = bm.faces.new(list(reversed(ring0)))
            fb.material_index = mat_idx
        except ValueError:
            pass
    if cap_top and r1 > 0.001:
        try:
            ft = bm.faces.new(ring1)
            ft.material_index = mat_idx
        except ValueError:
            pass


def add_tube_y(
    bm: bmesh.types.BMesh,
    cx: float,
    y0: float,
    y1: float,
    cz: float,
    r_outer: float,
    r_inner: float,
    mat_idx: int,
    sides: int = 24,
    cap_bottom: bool = True,
    cap_top: bool = True,
):
    o0, o1, i0, i1 = [], [], [], []
    for k in range(sides):
        a = (k / sides) * math.tau
        sa, ca = math.sin(a), math.cos(a)
        o0.append(bm.verts.new(rbx_to_blender(cx + sa * r_outer, y0, cz + ca * r_outer)))
        o1.append(bm.verts.new(rbx_to_blender(cx + sa * r_outer, y1, cz + ca * r_outer)))
        i0.append(bm.verts.new(rbx_to_blender(cx + sa * r_inner, y0, cz + ca * r_inner)))
        i1.append(bm.verts.new(rbx_to_blender(cx + sa * r_inner, y1, cz + ca * r_inner)))

    for k in range(sides):
        nk = (k + 1) % sides
        for quad in (
            (o0[k], o0[nk], o1[nk], o1[k]),
            (i0[nk], i0[k], i1[k], i1[nk]),
        ):
            try:
                f = bm.faces.new(quad)
                f.material_index = mat_idx
            except ValueError:
                pass
        if cap_top:
            try:
                ft = bm.faces.new((o1[k], o1[nk], i1[nk], i1[k]))
                ft.material_index = mat_idx
            except ValueError:
                pass
        if cap_bottom:
            try:
                fb = bm.faces.new((o0[nk], o0[k], i0[k], i0[nk]))
                fb.material_index = mat_idx
            except ValueError:
                pass


# =============================================================================
# 1. FOUNTAIN BASE AND TIERS (`Fountain_Base_And_Tiers`)
# =============================================================================
def build_fountain_base_and_tiers() -> tuple[bmesh.types.BMesh, dict]:
    bm = bmesh.new()
    sockets = {}
    spout_idx = 1

    # 1A. Stepped Foundation Plinth (Outer R = 12.6, H = 0.55)
    add_cylinder_y(bm, 0.0, 0.0, 0.35, 0.0, 12.6, 12.4, M_STONE_DARK, sides=20, cap_bottom=False)
    add_cylinder_y(bm, 0.0, 0.35, 0.55, 0.0, 12.1, 11.9, M_STONE_LIGHT, sides=20, cap_bottom=False)

    # 1B. Tier 1 Wide Ground Basin (Outer R = 11.5, Inner R = 10.1, Y = 0.55..3.35)
    add_cylinder_y(bm, 0.0, 0.55, 1.15, 0.0, 10.1, 10.1, M_STONE_DARK, sides=16, cap_bottom=False)
    add_tube_y(bm, 0.0, 0.55, 3.15, 0.0, 11.5, 10.1, M_STONE_DARK, sides=20, cap_bottom=False)
    # Molded Upper Rim + Gold Filigree Band
    add_tube_y(bm, 0.0, 3.15, 3.55, 0.0, 11.85, 9.95, M_STONE_LIGHT, sides=20, cap_bottom=False)
    add_tube_y(bm, 0.0, 2.05, 2.55, 0.0, 11.62, 11.45, M_GOLD, sides=20, cap_bottom=False, cap_top=False)

    # 1C. 4 Square Corner Piers with Gold Relief Tops (at 0, 90, 180, 270 deg)
    for k in range(4):
        ang = k * 90.0
        add_ring_box(bm, ang, 11.45, 2.05, 2.2, 3.0, 2.2, M_STONE_LIGHT)
        add_ring_box(bm, ang, 11.45, 3.65, 2.45, 0.32, 2.45, M_STONE_DARK)
        add_ring_box(bm, ang, 11.45, 3.84, 1.85, 0.12, 1.85, M_GOLD)
        add_ring_box(bm, ang, 12.56, 2.15, 1.45, 1.55, 0.12, M_GOLD)

    # 1D. 4 Semi-Circular Outer Catch Basins (at 45, 135, 225, 315 deg)
    for k in range(4):
        ang_deg = 45.0 + k * 90.0
        ang_rad = math.radians(ang_deg)
        bx = math.sin(ang_rad) * 11.25
        bz = math.cos(ang_rad) * 11.25
        add_cylinder_y(bm, bx, 0.55, 1.0, bz, 2.25, 2.15, M_STONE_DARK, sides=10, cap_bottom=False)
        add_tube_y(bm, bx, 0.55, 2.95, bz, 2.15, 1.62, M_STONE_DARK, sides=10, cap_bottom=False)
        add_tube_y(bm, bx, 2.95, 3.28, bz, 2.32, 1.55, M_STONE_LIGHT, sides=10, cap_bottom=False)
        add_tube_y(bm, bx, 1.75, 2.15, bz, 2.22, 2.10, M_GOLD, sides=10, cap_bottom=False, cap_top=False)

    # 2A. Tier 2 Lower-Mid Drum & Basin (Outer R = 7.8, Inner R = 6.6, Y = 2.6..6.4)
    add_cylinder_y(bm, 0.0, 1.15, 5.6, 0.0, 7.1, 7.3, M_STONE_DARK, sides=16, cap_bottom=False)
    add_tube_y(bm, 0.0, 5.6, 6.25, 0.0, 7.8, 6.6, M_STONE_DARK, sides=16, cap_bottom=False)
    add_tube_y(bm, 0.0, 6.25, 6.58, 0.0, 8.05, 6.48, M_STONE_LIGHT, sides=16, cap_bottom=False)
    add_tube_y(bm, 0.0, 4.45, 4.95, 0.0, 7.42, 7.25, M_GOLD, sides=16, cap_bottom=False, cap_top=False)

    # 2B. 4 Ornate Arched Spout Hoods on Tier 2 Rim (at 45, 135, 225, 315 deg -> Catch Basins)
    # Reserve Waterfall_Spout_1 for the Goddess Jug; start tier spouts after Jug & upper tiers
    # Wait: let's assign spout indices in a clean top-to-bottom order at the end!
    tier2_arch_spouts = []
    for k in range(4):
        ang_deg = 45.0 + k * 90.0
        ang_rad = math.radians(ang_deg)
        add_ring_box(bm, ang_deg, 7.55, 5.65, 2.35, 2.35, 1.55, M_STONE_LIGHT)
        add_ring_box(bm, ang_deg, 7.62, 6.92, 2.55, 0.45, 1.75, M_STONE_DARK)
        add_ring_box(bm, ang_deg, 7.75, 5.95, 1.85, 1.65, 1.35, M_GOLD)
        add_ring_box(bm, ang_deg, 8.32, 5.65, 0.85, 0.55, 0.95, M_STONE_DARK)
        spout_pos = (math.sin(ang_rad) * 8.65, 5.62, math.cos(ang_rad) * 8.65)
        impact_pos = (math.sin(ang_rad) * 11.25, 2.95, math.cos(ang_rad) * 11.25)
        tier2_arch_spouts.append((spout_pos, impact_pos))

    # 2C. 12 Tier 2 Rim Spouts (3 per quadrant between the 4 arched hoods -> Tier 1 Pool)
    tier2_rim_spouts = []
    for q in range(4):
        base_ang = q * 90.0
        for sub_off in (-18.0, 0.0, 18.0):
            ang_deg = (base_ang + sub_off) % 360.0
            ang_rad = math.radians(ang_deg)
            add_ring_box(bm, ang_deg, 7.95, 6.05, 0.62, 0.48, 0.72, M_GOLD)
            spout_pos = (math.sin(ang_rad) * 8.15, 6.02, math.cos(ang_rad) * 8.15)
            impact_pos = (math.sin(ang_rad) * 9.05, 3.22, math.cos(ang_rad) * 9.05)
            tier2_rim_spouts.append((spout_pos, impact_pos))

    # 3A. Gothic Arch Colonnade under Tier 3 (Y = 5.8..10.6)
    add_cylinder_y(bm, 0.0, 5.6, 10.6, 0.0, 2.55, 2.35, M_STONE_DARK, sides=10, cap_bottom=False, cap_top=False)
    col_r = 4.45
    for k in range(8):
        ang_deg = k * 45.0
        ang_rad = math.radians(ang_deg)
        cx = math.sin(ang_rad) * col_r
        cz = math.cos(ang_rad) * col_r
        add_cylinder_y(bm, cx, 5.6, 6.1, cz, 0.68, 0.62, M_STONE_LIGHT, sides=6, cap_bottom=False)
        add_cylinder_y(bm, cx, 6.1, 9.5, cz, 0.46, 0.42, M_STONE_DARK, sides=6, cap_bottom=False, cap_top=False)
        add_cylinder_y(bm, cx, 9.5, 9.95, cz, 0.48, 0.72, M_GOLD, sides=6, cap_bottom=False)
        # Gothic arch rib connecting adjacent columns at angle + 22.5 deg
        mid_ang = ang_deg + 22.5
        add_ring_box(bm, mid_ang, col_r * 0.94, 10.18, 1.85, 0.62, 0.75, M_STONE_LIGHT)
        add_ring_box(bm, mid_ang, col_r * 0.96, 10.22, 0.52, 0.75, 0.85, M_GOLD)

    # 3B. Tier 3 Upper-Mid Basin (Outer R = 5.4, Inner R = 4.4, Y = 10.4..11.85)
    add_cylinder_y(bm, 0.0, 10.35, 10.95, 0.0, 3.2, 5.2, M_STONE_DARK, sides=14, cap_bottom=False)
    add_tube_y(bm, 0.0, 10.95, 11.6, 0.0, 5.4, 4.4, M_STONE_DARK, sides=14, cap_bottom=False)
    add_tube_y(bm, 0.0, 11.6, 11.9, 0.0, 5.62, 4.3, M_STONE_LIGHT, sides=14, cap_bottom=False)
    add_tube_y(bm, 0.0, 11.1, 11.48, 0.0, 5.48, 5.35, M_GOLD, sides=14, cap_bottom=False, cap_top=False)

    # 3C. 8 Carved Spouts around Tier 3 Rim -> Tier 2 Pool
    tier3_spouts = []
    for k in range(8):
        ang_deg = 22.5 + k * 45.0
        ang_rad = math.radians(ang_deg)
        add_ring_box(bm, ang_deg, 5.45, 11.45, 0.95, 0.65, 0.85, M_STONE_LIGHT)
        add_ring_box(bm, ang_deg, 5.68, 11.38, 0.55, 0.42, 0.65, M_GOLD)
        spout_pos = (math.sin(ang_rad) * 5.82, 11.35, math.cos(ang_rad) * 5.82)
        impact_pos = (math.sin(ang_rad) * 6.35, 6.22, math.cos(ang_rad) * 6.35)
        tier3_spouts.append((spout_pos, impact_pos))

    # 4A. Ornate Carved Pedestal under Tier 4 (Y = 11.2..14.4)
    add_cylinder_y(bm, 0.0, 11.1, 11.8, 0.0, 2.35, 1.95, M_STONE_LIGHT, sides=10, cap_bottom=False)
    add_cylinder_y(bm, 0.0, 11.8, 13.9, 0.0, 1.85, 1.55, M_STONE_DARK, sides=10, cap_bottom=False, cap_top=False)
    add_cylinder_y(bm, 0.0, 13.9, 14.35, 0.0, 1.65, 2.55, M_STONE_LIGHT, sides=10, cap_bottom=False)
    for k in range(4):
        ang_deg = 45.0 + k * 90.0
        add_ring_box(bm, ang_deg, 1.85, 12.85, 0.58, 1.85, 0.85, M_GOLD, pitch_rad=math.radians(-12.0))

    # 4B. Tier 4 Top Crown Basin & Statue Plinth (Outer R = 3.25, Inner R = 2.45, Y = 14.35..15.35)
    add_cylinder_y(bm, 0.0, 14.35, 14.75, 0.0, 2.55, 3.15, M_STONE_DARK, sides=12, cap_bottom=False)
    add_tube_y(bm, 0.0, 14.75, 15.2, 0.0, 3.25, 2.45, M_STONE_DARK, sides=12, cap_bottom=False)
    add_tube_y(bm, 0.0, 15.2, 15.42, 0.0, 3.42, 2.38, M_STONE_LIGHT, sides=12, cap_bottom=False)
    add_tube_y(bm, 0.0, 14.85, 15.15, 0.0, 3.31, 3.20, M_GOLD, sides=12, cap_bottom=False, cap_top=False)

    # Statue Plinth inside Tier 4 Basin (Y = 14.75..15.85)
    add_cylinder_y(bm, 0.0, 14.75, 15.65, 0.0, 1.48, 1.32, M_STONE_LIGHT, sides=10, cap_bottom=False)
    add_cylinder_y(bm, 0.0, 15.65, 15.85, 0.0, 1.38, 1.28, M_GOLD, sides=10, cap_bottom=False)

    # 4C. 4 Tier 4 Top Basin Spouts -> Tier 3 Pool
    tier4_spouts = []
    for k in range(4):
        ang_deg = k * 90.0
        ang_rad = math.radians(ang_deg)
        add_ring_box(bm, ang_deg, 3.32, 15.05, 0.65, 0.45, 0.68, M_GOLD)
        spout_pos = (math.sin(ang_rad) * 3.52, 15.0, math.cos(ang_rad) * 3.52)
        impact_pos = (math.sin(ang_rad) * 4.15, 11.62, math.cos(ang_rad) * 4.15)
        tier4_spouts.append((spout_pos, impact_pos))

    # Register all Waterfall_Spout_N and Waterfall_Impact_N sockets in order:
    # 1: Goddess Amphora Jug -> Top/Mid basin
    sockets["Waterfall_Spout_1"] = (1.76, 19.35, -0.68)
    sockets["Waterfall_Impact_1"] = (2.05, 15.12, -0.82)
    spout_idx = 2

    for s_pos, i_pos in tier4_spouts + tier3_spouts + tier2_arch_spouts + tier2_rim_spouts:
        sockets[f"Waterfall_Spout_{spout_idx}"] = s_pos
        sockets[f"Waterfall_Impact_{spout_idx}"] = i_pos
        spout_idx += 1

    return bm, sockets


# =============================================================================
# 2. 1:1 GODDESS STATUE (`Goddess_Statue`)
# =============================================================================
def add_lofted_surface(
    bm: bmesh.types.BMesh,
    rings_verts: list[list[bmesh.types.BMVert]],
    mat_idx: int,
    cap_bottom: bool = False,
    cap_top: bool = False,
):
    for r_idx in range(len(rings_verts) - 1):
        r0 = rings_verts[r_idx]
        r1 = rings_verts[r_idx + 1]
        n = len(r0)
        for i in range(n):
            ni = (i + 1) % n
            try:
                f = bm.faces.new((r0[i], r0[ni], r1[ni], r1[i]))
                f.material_index = mat_idx
            except ValueError:
                pass
    if cap_bottom and len(rings_verts[0]) >= 3:
        try:
            fb = bm.faces.new(list(reversed(rings_verts[0])))
            fb.material_index = mat_idx
        except ValueError:
            pass
    if cap_top and len(rings_verts[-1]) >= 3:
        try:
            ft = bm.faces.new(rings_verts[-1])
            ft.material_index = mat_idx
        except ValueError:
            pass


def add_limb_tube(
    bm: bmesh.types.BMesh,
    waypoints: list[tuple[float, float, float, float]],
    mat_idx: int,
    sides: int = 12,
    cap_ends: bool = True,
):
    rings = []
    count = len(waypoints)
    for idx, (px, py, pz, radius) in enumerate(waypoints):
        p_curr = Vector(rbx_to_blender(px, py, pz))
        if idx == 0:
            p_next = Vector(rbx_to_blender(*waypoints[idx + 1][:3]))
            tangent = (p_next - p_curr).normalized()
        elif idx == count - 1:
            p_prev = Vector(rbx_to_blender(*waypoints[idx - 1][:3]))
            tangent = (p_curr - p_prev).normalized()
        else:
            p_prev = Vector(rbx_to_blender(*waypoints[idx - 1][:3]))
            p_next = Vector(rbx_to_blender(*waypoints[idx + 1][:3]))
            tangent = (p_next - p_prev).normalized()

        up_ref = Vector((0.0, 0.0, 1.0))
        if abs(tangent.dot(up_ref)) > 0.92:
            up_ref = Vector((1.0, 0.0, 0.0))
        binormal = tangent.cross(up_ref).normalized()
        normal = binormal.cross(tangent).normalized()

        ring = []
        for s in range(sides):
            a = (s / sides) * math.tau
            pt = p_curr + (normal * math.cos(a) + binormal * math.sin(a)) * radius
            ring.append(bm.verts.new(pt))
        rings.append(ring)

    add_lofted_surface(bm, rings, mat_idx, cap_bottom=cap_ends, cap_top=cap_ends)


def add_uv_sphere_rbx(
    bm: bmesh.types.BMesh,
    cx: float,
    cy: float,
    cz: float,
    rx: float,
    ry: float,
    rz: float,
    mat_idx: int,
    u_Step: int = 16,
    v_Step: int = 12,
):
    rings = []
    for iv in range(v_Step + 1):
        phi = -math.pi * 0.5 + (iv / v_Step) * math.pi
        cphi, sphi = math.cos(phi), math.sin(phi)
        r_eff = max(0.002, cphi)
        ring = []
        for iu in range(u_Step):
            theta = (iu / u_Step) * math.tau
            px = cx + math.sin(theta) * r_eff * rx
            py = cy + sphi * ry
            pz = cz + math.cos(theta) * r_eff * rz
            ring.append(bm.verts.new(rbx_to_blender(px, py, pz)))
        rings.append(ring)
    add_lofted_surface(bm, rings, mat_idx, cap_bottom=True, cap_top=True)


def build_goddess_statue_mesh() -> bmesh.types.BMesh:
    """
    Builds the 1:1 classical/gothic draped Goddess Statue (~3,500-3,800 triangles).
    Note: Front of the plot faces -Z (toward the entrance bridge), so the statue faces -Z.
    """
    bm = bmesh.new()
    base_y = 15.85

    # 1. Flowing Pleated Chiton & Bodice (26 vertical slices x 32 radial segments = ~1,720 tris)
    num_slices = 26
    num_radial = 32
    chiton_rings = []

    # Height profile from hem (h=0.0) to shoulders (h=5.75):
    for s_idx in range(num_slices + 1):
        t = s_idx / num_slices
        h = t * 5.75
        y = base_y + h

        # Base anatomical + drapery envelope (rx_base, rz_base)
        if t < 0.58:
            # Flowing skirt from plinth up to waist, flaring at hem and cinching at waist
            u = t / 0.58
            rx_base = 1.28 * (1.0 - 0.44 * (u ** 0.85)) + 0.08 * math.sin(u * math.pi)
            rz_base = 1.16 * (1.0 - 0.46 * (u ** 0.85)) + 0.08 * math.sin(u * math.pi)
            fold_amp = 0.105 * (1.0 - 0.40 * u)
            fold_freq = 14
        elif t < 0.72:
            # Cinched golden girdle waist transition
            u = (t - 0.58) / 0.14
            rx_base = 0.72 - 0.08 * math.sin(u * math.pi)
            rz_base = 0.62 - 0.07 * math.sin(u * math.pi)
            fold_amp = 0.038
            fold_freq = 12
        else:
            # Draped classical bodice over chest & shoulders
            u = (t - 0.72) / 0.28
            bust = math.sin(u * math.pi)
            rx_base = 0.72 + 0.24 * bust - 0.12 * (u ** 2)
            rz_base = 0.62 + 0.26 * bust - 0.14 * (u ** 2)
            fold_amp = 0.032 * (1.0 - 0.5 * u)
            fold_freq = 10

        # Subtle contrapposto hip/knee sway
        sway_x = 0.08 * math.sin(t * math.pi * 1.3)
        sway_z = -0.05 * math.sin(t * math.pi)

        ring = []
        for r_idx in range(num_radial):
            theta = (r_idx / num_radial) * math.tau
            st, ct = math.sin(theta), math.cos(theta)
            # Harmonic drapery folds + deeper vertical pleats in front/back
            pleat = (
                fold_amp * math.cos(fold_freq * theta + t * 1.4)
                + (fold_amp * 0.45) * math.sin((fold_freq * 2) * theta - t * 0.8)
            )
            # Left knee forward contour (-Z is front)
            knee_push = 0.0
            if 0.18 < t < 0.48 and ct < -0.25 and st < 0.1:
                knee_push = 0.14 * math.sin((t - 0.18) / 0.30 * math.pi) * abs(ct)

            rx = sway_x + st * (rx_base + pleat)
            rz = sway_z + ct * (rz_base + pleat + knee_push)
            ring.append(bm.verts.new(rbx_to_blender(rx, y, rz)))
        chiton_rings.append(ring)

    add_lofted_surface(bm, chiton_rings, M_MARBLE, cap_bottom=True, cap_top=True)

    # 2. Ornate Golden Waist Girdle / Sash & Classical Neckline Border (M_GOLD)
    waist_y = base_y + 3.62
    add_cylinder_y(bm, 0.04, waist_y - 0.15, waist_y + 0.16, -0.03, 0.76, 0.75, M_GOLD, sides=24)
    # Cascading golden sash ribbon down the front (-Z)
    add_limb_tube(
        bm,
        [
            (0.02, waist_y, -0.72, 0.13),
            (0.06, waist_y - 0.85, -0.82, 0.12),
            (0.09, waist_y - 1.70, -0.92, 0.10),
            (0.12, waist_y - 2.45, -1.00, 0.08),
        ],
        M_GOLD,
        sides=8,
    )
    # Golden V-collar & neckline trim
    add_cylinder_y(bm, 0.0, base_y + 5.52, base_y + 5.74, -0.02, 0.72, 0.58, M_GOLD, sides=20)

    # 3. Flowing Shoulder Himation / Shawl Drape (cascading over left shoulder & back)
    add_limb_tube(
        bm,
        [
            (-0.72, base_y + 5.62, 0.05, 0.26),
            (-0.98, base_y + 4.75, 0.24, 0.32),
            (-1.10, base_y + 3.65, 0.36, 0.34),
            (-1.14, base_y + 2.40, 0.40, 0.30),
            (-1.08, base_y + 1.25, 0.38, 0.22),
        ],
        M_MARBLE,
        sides=10,
    )

    # 4. Neck, Classical Sculpted Head, Wavy Hair & Golden Floral/Star Diadem Crown
    add_cylinder_y(bm, 0.0, base_y + 5.68, base_y + 6.28, -0.02, 0.31, 0.26, M_MARBLE, sides=14)
    head_y = base_y + 6.76
    add_uv_sphere_rbx(bm, 0.0, head_y, -0.05, 0.50, 0.62, 0.55, M_MARBLE, u_Step=18, v_Step=12)
    # Subtle classical nose & brow bridge facing -Z
    add_box(bm, 0.0, head_y + 0.02, -0.58, 0.12, 0.26, 0.14, M_MARBLE, pitch_rad=math.radians(14.0))

    # Sculpted wavy hair crown & shoulder tresses
    add_uv_sphere_rbx(bm, 0.0, head_y + 0.14, 0.08, 0.56, 0.58, 0.60, M_MARBLE, u_Step=16, v_Step=10)
    for side in (-1.0, 1.0):
        add_limb_tube(
            bm,
            [
                (side * 0.42, head_y + 0.06, 0.04, 0.19),
                (side * 0.52, head_y - 0.42, -0.08, 0.18),
                (side * 0.56, head_y - 0.95, -0.12, 0.15),
                (side * 0.48, head_y - 1.35, -0.10, 0.10),
            ],
            M_MARBLE,
            sides=8,
        )

    # Ornate Golden Diadem / Crown with 7 radial floral/star spikes
    crown_y = head_y + 0.42
    add_tube_y(bm, 0.0, crown_y, crown_y + 0.22, 0.0, 0.58, 0.48, M_GOLD, sides=18)
    for k in range(-3, 4):
        ang_deg = 180.0 + k * 24.0  # Centered around -Z (180 deg)
        spike_h = 0.34 - abs(k) * 0.045
        add_ring_box(bm, ang_deg, 0.53, crown_y + 0.22 + spike_h * 0.5, 0.12, spike_h, 0.09, M_GOLD)

    # 5. Left Arm Raised Outward & Upward in Serene Blessing (matching reference image)
    add_limb_tube(
        bm,
        [
            (-0.76, base_y + 5.42, 0.0, 0.25),
            (-1.25, base_y + 5.75, -0.18, 0.21),
            (-1.62, base_y + 6.45, -0.32, 0.18),
            (-1.82, base_y + 7.12, -0.40, 0.15),
            (-1.88, base_y + 7.48, -0.44, 0.11),
        ],
        M_MARBLE,
        sides=12,
    )

    # 6. Right Arm Cradling the Tilted Pouring Amphora (Water Jug)
    add_limb_tube(
        bm,
        [
            (0.76, base_y + 5.42, 0.0, 0.25),
            (1.22, base_y + 4.82, -0.20, 0.22),
            (1.48, base_y + 4.25, -0.38, 0.19),
            (1.58, base_y + 3.85, -0.52, 0.15),
        ],
        M_MARBLE,
        sides=12,
    )

    # 7. Ornate Tilted Amphora (Water Jug) held at right hip, tilted downward toward -Z/+X
    # Jug axis runs from base (1.18, base_y + 4.28, -0.18) to pouring lip (1.76, base_y + 3.50, -0.68)
    jug_profile = [
        (0.00, 0.18, M_GOLD),
        (0.12, 0.32, M_STONE_LIGHT),
        (0.32, 0.64, M_STONE_DARK),
        (0.52, 0.68, M_GOLD),
        (0.70, 0.46, M_STONE_DARK),
        (0.85, 0.30, M_STONE_LIGHT),
        (1.00, 0.42, M_GOLD),
    ]
    p0 = Vector(rbx_to_blender(1.18, base_y + 4.28, -0.18))
    p1 = Vector(rbx_to_blender(1.76, base_y + 3.50, -0.68))
    jug_axis = (p1 - p0).normalized()
    up_ref = Vector((0.0, 0.0, 1.0))
    j_binorm = jug_axis.cross(up_ref).normalized()
    j_norm = j_binorm.cross(jug_axis).normalized()
    jug_len = (p1 - p0).length

    jug_rings = []
    jug_sides = 16
    for t_val, rad_val, _ in jug_profile:
        center = p0 + jug_axis * (t_val * jug_len)
        ring = []
        for s in range(jug_sides):
            a = (s / jug_sides) * math.tau
            pt = center + (j_norm * math.cos(a) + j_binorm * math.sin(a)) * rad_val
            ring.append(bm.verts.new(pt))
        jug_rings.append(ring)

    for idx in range(len(jug_rings) - 1):
        mat_idx = jug_profile[idx][2]
        r0 = jug_rings[idx]
        r1 = jug_rings[idx + 1]
        for s in range(jug_sides):
            ns = (s + 1) % jug_sides
            try:
                f = bm.faces.new((r0[s], r0[ns], r1[ns], r1[s]))
                f.material_index = mat_idx
            except ValueError:
                pass

    return bm


# =============================================================================
# 3. WATER SURFACE MESHES (`Water_Surface_Meshes`)
# =============================================================================
def add_uv_water_disc(
    bm: bmesh.types.BMesh,
    uv_layer,
    cx: float,
    cy: float,
    cz: float,
    r_outer: float,
    r_inner: float = 0.0,
    sides: int = 24,
    uv_scale: float = 0.18,
):
    if r_inner <= 0.01:
        center_v = bm.verts.new(rbx_to_blender(cx, cy, cz))
        ring = []
        for i in range(sides):
            a = (i / sides) * math.tau
            rx = cx + math.sin(a) * r_outer
            rz = cz + math.cos(a) * r_outer
            ring.append((bm.verts.new(rbx_to_blender(rx, cy, rz)), rx, rz))
        for i in range(sides):
            ni = (i + 1) % sides
            v0, x0, z0 = ring[i]
            v1, x1, z1 = ring[ni]
            try:
                f = bm.faces.new((center_v, v0, v1))
                f.material_index = M_WATER
                f.loops[0][uv_layer].uv = (cx * uv_scale, cz * uv_scale)
                f.loops[1][uv_layer].uv = (x0 * uv_scale, z0 * uv_scale)
                f.loops[2][uv_layer].uv = (x1 * uv_scale, z1 * uv_scale)
            except ValueError:
                pass
    else:
        inner_ring = []
        outer_ring = []
        for i in range(sides):
            a = (i / sides) * math.tau
            sa, ca = math.sin(a), math.cos(a)
            ix, iz = cx + sa * r_inner, cz + ca * r_inner
            ox, oz = cx + sa * r_outer, cz + ca * r_outer
            inner_ring.append((bm.verts.new(rbx_to_blender(ix, cy, iz)), ix, iz))
            outer_ring.append((bm.verts.new(rbx_to_blender(ox, cy, oz)), ox, oz))
        for i in range(sides):
            ni = (i + 1) % sides
            vi0, ix0, iz0 = inner_ring[i]
            vi1, ix1, iz1 = inner_ring[ni]
            vo0, ox0, oz0 = outer_ring[i]
            vo1, ox1, oz1 = outer_ring[ni]
            try:
                f = bm.faces.new((vi0, vo0, vo1, vi1))
                f.material_index = M_WATER
                f.loops[0][uv_layer].uv = (ix0 * uv_scale, iz0 * uv_scale)
                f.loops[1][uv_layer].uv = (ox0 * uv_scale, oz0 * uv_scale)
                f.loops[2][uv_layer].uv = (ox1 * uv_scale, oz1 * uv_scale)
                f.loops[3][uv_layer].uv = (ix1 * uv_scale, iz1 * uv_scale)
            except ValueError:
                pass


def build_water_surface_meshes() -> bmesh.types.BMesh:
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UVMap")

    # Tier 1 Main Pool (annulus around Tier 2 drum: R = 7.25..10.12, Y = 3.22)
    add_uv_water_disc(bm, uv_layer, 0.0, 3.22, 0.0, 10.12, 7.22, sides=32)

    # 4 Outer Semi-Circular Catch-Basin Pools (Y = 2.95, R = 1.64)
    for k in range(4):
        ang_rad = math.radians(45.0 + k * 90.0)
        bx = math.sin(ang_rad) * 11.25
        bz = math.cos(ang_rad) * 11.25
        add_uv_water_disc(bm, uv_layer, bx, 2.95, bz, 1.64, 0.0, sides=16)

    # Tier 2 Pool (annulus around Gothic Colonnade: R = 2.52..6.62, Y = 6.22)
    add_uv_water_disc(bm, uv_layer, 0.0, 6.22, 0.0, 6.62, 2.52, sides=24)

    # Tier 3 Pool (annulus around Tier 4 pedestal: R = 1.92..4.42, Y = 11.62)
    add_uv_water_disc(bm, uv_layer, 0.0, 11.62, 0.0, 4.42, 1.92, sides=24)

    # Tier 4 Top Crown Pool (annulus around Statue plinth: R = 1.35..2.46, Y = 15.12)
    add_uv_water_disc(bm, uv_layer, 0.0, 15.12, 0.0, 2.46, 1.35, sides=20)

    return bm


# =============================================================================
# 4. SCENE ASSEMBLY, SHADE AUTO SMOOTH & FBX EXPORT
# =============================================================================
def link_bmesh_to_collection(
    name: str,
    bm: bmesh.types.BMesh,
    col: bpy.types.Collection,
    mat_slots: list,
    smooth_angle_deg: float = None,
) -> bpy.types.Object:
    mesh_data = bpy.data.meshes.new(f"{name}_Mesh")
    bm.normal_update()
    bm.to_mesh(mesh_data)
    bm.free()

    obj = bpy.data.objects.new(name, mesh_data)
    col.objects.link(obj)

    for mat in mat_slots:
        mesh_data.materials.append(mat)

    if smooth_angle_deg is not None:
        for poly in mesh_data.polygons:
            poly.use_smooth = True
        if hasattr(mesh_data, "use_auto_smooth"):
            mesh_data.use_auto_smooth = True
            mesh_data.auto_smooth_angle = math.radians(smooth_angle_deg)
        elif hasattr(mesh_data, "shade_smooth"):
            pass
    else:
        for poly in mesh_data.polygons:
            poly.use_smooth = False

    return obj


def create_goddess_fountain(export_fbx_path: str = None):
    # Clear existing scene objects so viewport frames the fountain cleanly
    for obj in list(bpy.data.objects):
        if obj.type in {"MESH", "EMPTY"}:
            bpy.data.objects.remove(obj, do_unlink=True)

    for col in list(bpy.data.collections):
        if col.name in {COLLECTION_NAME, "SynthesisChamber_Asset"}:
            bpy.data.collections.remove(col)

    fountain_col = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(fountain_col)

    mat_slots = build_materials()

    bm_base, sockets = build_fountain_base_and_tiers()
    obj_base = link_bmesh_to_collection(
        "Fountain_Base_And_Tiers", bm_base, fountain_col, mat_slots, smooth_angle_deg=None
    )

    bm_statue = build_goddess_statue_mesh()
    obj_statue = link_bmesh_to_collection(
        "Goddess_Statue", bm_statue, fountain_col, mat_slots, smooth_angle_deg=35.0
    )

    bm_water = build_water_surface_meshes()
    obj_water = link_bmesh_to_collection(
        "Water_Surface_Meshes", bm_water, fountain_col, mat_slots, smooth_angle_deg=35.0
    )

    obj_statue.parent = obj_base
    obj_water.parent = obj_base

    # Apply Shade Auto Smooth (35 deg) via operator on Goddess_Statue if Blender 4.1+/5.x
    try:
        bpy.ops.object.select_all(action="DESELECT")
        obj_statue.select_set(True)
        bpy.context.view_layer.objects.active = obj_statue
        if hasattr(bpy.ops.object, "shade_auto_smooth"):
            bpy.ops.object.shade_auto_smooth(angle=math.radians(35.0))
        else:
            bpy.ops.object.shade_smooth()
    except Exception:
        pass

    # Attach Empty socket markers for every spout and water impact point
    for s_name, pt_rbx in sockets.items():
        emp = bpy.data.objects.new(s_name, None)
        emp.empty_display_type = "ARROWS"
        emp.empty_display_size = 0.45
        emp.location = rbx_to_blender(*pt_rbx)
        emp.parent = obj_base
        fountain_col.objects.link(emp)

    mesh_objs = (obj_base, obj_statue, obj_water)
    tri_counts = {
        o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in mesh_objs
    }
    total_tris = sum(tri_counts.values())
    print(
        f"Goddess Fountain generated: {tri_counts} | Total = {total_tris} tris (< 8,000 budget) | {len(sockets)} sockets."
    )

    if export_fbx_path:
        os.makedirs(os.path.dirname(os.path.abspath(export_fbx_path)), exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        obj_base.select_set(True)
        for ch in obj_base.children_recursive:
            ch.select_set(True)
        bpy.context.view_layer.objects.active = obj_base
        bpy.ops.export_scene.fbx(
            filepath=export_fbx_path,
            use_selection=True,
            object_types={"MESH", "EMPTY"},
            use_mesh_modifiers=True,
            mesh_smooth_type="FACE",
            axis_forward="Z",
            axis_up="Y",
            apply_unit_scale=True,
            apply_scale_options="FBX_SCALE_UNITS",
            bake_space_transform=False,
        )
        print(f"Exported Goddess Fountain FBX to: {export_fbx_path}")

    return obj_base, tri_counts, total_tris


if __name__ == "__main__":
    create_goddess_fountain(
        export_fbx_path=r"C:\WORK\infinite-tower\assets\models\facilities\GoddessFountain.fbx"
    )
