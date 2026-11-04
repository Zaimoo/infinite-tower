"""
=============================================================================
Infinite Towers: Become a Master! - 3D Environment & VFX Pipeline
Asset: Medieval Gothic Enterable Blacksmith House (`BlacksmithForge`)
References:
  - Courtyard Overview: media_1793806800634_7e8ceb46.jpg
  - Blacksmith Close-Up: media_1793806860112_3aef783c.jpg
  - Layout Plan: blacksmith_forge_fortress_layout_plan.md
Target Engine: Blender 4.x / 5.x -> Roblox Studio (MeshPart / PlotFacilities)
=============================================================================
Procedural generation script that builds the enterable medieval-gothic
Blacksmith House as modular sub-mesh objects in the `BlacksmithForge_Asset`
collection with 8 rich PBR/Neon material zones, coursed ashlar stonework,
half-timbered gable truss, slate roof shingles with twin dormers, tapered
cylindrical stone smokestack with battlements, open wooden door, flanking
brazier pedestals, hanging shield-and-anvil sign on chains, exterior sword
rack & barrels, and a full hollowed interior with brick hearth firebox,
anvil on timber block, weapon rack, workbench, and quench trough.

Strictly non-orcish (no horns, spikes, or tribal red banners).

Coordinate Convention (1 Blender Meter = 1 Roblox Stud):
  - In Blender: X = Width (+/-X), Y = Depth (-Y is Front toward courtyard,
    +Y is Back toward castle wall), Z = Height (+Z is Up, Z = 0 is floor).
  - Exported to Roblox FBX (axis_up='Y', axis_forward='Z'):
    Roblox X = Blender X
    Roblox Y (Up) = Blender Z
    Roblox Z (Front/+Z) = -Blender Y
  - Footprint: ~32 x 36 studs (walkable interior ~26 x 28 studs, arch 10x12.5).
=============================================================================
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector

COLLECTION_NAME = "BlacksmithForge_Asset"

MATERIAL_SPECS = {
    "SlateStone": {
        "name": "M_Forge_SlateStone",
        "hex": "#4E525C",
        "metallic": 0.08,
        "roughness": 0.85,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "AshlarTrim": {
        "name": "M_Forge_AshlarTrim",
        "hex": "#686D7A",
        "metallic": 0.10,
        "roughness": 0.78,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "RoofShingle": {
        "name": "M_Forge_DarkRoofShingle",
        "hex": "#2B303A",
        "metallic": 0.15,
        "roughness": 0.72,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "HeavyTimber": {
        "name": "M_Forge_HeavyTimber",
        "hex": "#4A3221",
        "metallic": 0.05,
        "roughness": 0.82,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "HearthBrick": {
        "name": "M_Forge_HearthBrick",
        "hex": "#5C352C",
        "metallic": 0.05,
        "roughness": 0.88,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "DarkIron": {
        "name": "M_Forge_DarkIron",
        "hex": "#262930",
        "metallic": 0.78,
        "roughness": 0.42,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "SteelSilver": {
        "name": "M_Forge_SteelSilver",
        "hex": "#9CA3B0",
        "metallic": 0.85,
        "roughness": 0.30,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "EmberGlow": {
        "name": "M_Forge_EmberGlow",
        "hex": "#FF7A1A",
        "metallic": 0.0,
        "roughness": 0.15,
        "emission": "#FF6A00",
        "emission_strength": 5.5,
    },
    "QuenchWater": {
        "name": "M_Forge_QuenchWater",
        "hex": "#2C78B8",
        "metallic": 0.1,
        "roughness": 0.12,
        "emission": "#1B4F7A",
        "emission_strength": 0.6,
    },
}

MAT_KEYS = [
    "SlateStone",   # 0
    "AshlarTrim",   # 1
    "RoofShingle",  # 2
    "HeavyTimber",  # 3
    "HearthBrick",  # 4
    "DarkIron",     # 5
    "SteelSilver",  # 6
    "EmberGlow",    # 7
    "QuenchWater",  # 8
]


def hex_to_rgb(hex_str: str) -> tuple:
    c = hex_str.lstrip("#")
    return tuple(int(c[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def rbx_to_blender(rx: float, ry: float, rz: float) -> Vector:
    """
    Roblox station-local coordinates:
      rx = Right (+X), ry = Up (+Y), rz = Front (+Z toward courtyard)
    into Blender world coordinates:
      bx = rx (+X), by = -rz (-Y is Front), bz = ry (+Z is Up).
    """
    return Vector((rx, -rz, ry))


def build_materials() -> list:
    mat_list = []
    for key in MAT_KEYS:
        spec = MATERIAL_SPECS[key]
        mat_name = spec["name"]
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
# BMESH PRIMITIVE HELPERS IN ROBLOX COORDINATES (rx, ry_up, rz_front)
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
    bevel_top: float = 0.0,
    yaw_rad: float = 0.0,
    pitch_rad: float = 0.0,
    roll_rad: float = 0.0,
):
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    tx = max(0.02, hx - bevel_top)
    tz = max(0.02, hz - bevel_top)

    local_pts = [
        (-hx, -hy, -hz),
        ( hx, -hy, -hz),
        ( hx, -hy,  hz),
        (-hx, -hy,  hz),
        (-tx,  hy, -tz),
        ( tx,  hy, -tz),
        ( tx,  hy,  tz),
        (-tx,  hy,  tz),
    ]
    cyaw, syaw = math.cos(yaw_rad), math.sin(yaw_rad)
    cp, sp = math.cos(pitch_rad), math.sin(pitch_rad)
    cr, sr = math.cos(roll_rad), math.sin(roll_rad)

    verts = []
    for lx, ly, lz in local_pts:
        # Roll around Z (in local X-Y)
        x1 = lx * cr - ly * sr
        y1 = lx * sr + ly * cr
        z1 = lz
        # Pitch around X (in Y-Z)
        x2 = x1
        y2 = y1 * cp - z1 * sp
        z2 = y1 * sp + z1 * cp
        # Yaw around Y (in X-Z)
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


def add_prism_strip(
    bm: bmesh.types.BMesh,
    ring_a: list,
    ring_b: list,
    mat_idx: int,
    cap_ends: bool = True,
):
    va = [bm.verts.new(rbx_to_blender(*pt)) for pt in ring_a]
    vb = [bm.verts.new(rbx_to_blender(*pt)) for pt in ring_b]
    n = len(va)
    for i in range(n):
        inext = (i + 1) % n
        try:
            f = bm.faces.new((va[i], va[inext], vb[inext], vb[i]))
            f.material_index = mat_idx
        except ValueError:
            pass
    if cap_ends and n >= 3:
        try:
            f0 = bm.faces.new(tuple(reversed(va)))
            f0.material_index = mat_idx
            f1 = bm.faces.new(tuple(vb))
            f1.material_index = mat_idx
        except ValueError:
            pass


def add_cylinder_y(
    bm: bmesh.types.BMesh,
    cx: float,
    y_bot: float,
    y_top: float,
    cz: float,
    r_bot: float,
    r_top: float,
    mat_idx: int,
    sides: int = 16,
    cap_ends: bool = True,
):
    ring_b = []
    ring_t = []
    for i in range(sides):
        a = (i / float(sides)) * math.pi * 2.0
        ring_b.append((cx + math.cos(a) * r_bot, y_bot, cz + math.sin(a) * r_bot))
        ring_t.append((cx + math.cos(a) * r_top, y_top, cz + math.sin(a) * r_top))
    add_prism_strip(bm, ring_b, ring_t, mat_idx=mat_idx, cap_ends=cap_ends)


def add_gable_roof_slope(
    bm: bmesh.types.BMesh,
    x_ridge: float,
    y_ridge: float,
    x_eave: float,
    y_eave: float,
    z_back: float,
    z_front: float,
    thickness: float,
    mat_base: int,
    mat_shingle: int,
    shingle_rows: int = 7,
    shingle_cols: int = 8,
):
    """
    Creates a pitched roof slab from (x_ridge, y_ridge) down to (x_eave, y_eave)
    spanning z_back to z_front, plus overlapping slate shingle courses on top.
    """
    dx = x_eave - x_ridge
    dy = y_eave - y_ridge
    length = math.hypot(dx, dy)
    nx = -dy / max(0.001, length)
    ny = dx / max(0.001, length)
    if ny < 0:
        nx, ny = -nx, -ny

    ring_back = [
        (x_ridge, y_ridge, z_back),
        (x_eave,  y_eave,  z_back),
        (x_eave + nx * thickness,  y_eave + ny * thickness,  z_back),
        (x_ridge + nx * thickness, y_ridge + ny * thickness, z_back),
    ]
    ring_front = [
        (x_ridge, y_ridge, z_front),
        (x_eave,  y_eave,  z_front),
        (x_eave + nx * thickness,  y_eave + ny * thickness,  z_front),
        (x_ridge + nx * thickness, y_ridge + ny * thickness, z_front),
    ]
    add_prism_strip(bm, ring_back, ring_front, mat_idx=mat_base, cap_ends=True)

    # Shingle courses running from eave (r=0) up to ridge (r=shingle_rows-1)
    z_span = z_front - z_back
    col_w = (z_span - 0.4) / float(shingle_cols)
    for r in range(shingle_rows):
        u0 = r / float(shingle_rows)
        u1 = min(1.0, (r + 1.08) / float(shingle_rows))
        sx0 = x_eave + (x_ridge - x_eave) * u0
        sy0 = y_eave + (y_ridge - y_eave) * u0
        sx1 = x_eave + (x_ridge - x_eave) * u1
        sy1 = y_eave + (y_ridge - y_eave) * u1

        for c in range(shingle_cols):
            stag = 0.25 * col_w if (r % 2 == 1) else 0.0
            z0 = z_back + 0.2 + c * col_w + stag
            z1 = min(z_front - 0.15, z0 + col_w * 0.92)
            if z1 <= z0 + 0.1:
                continue
            h_var = 0.18 + ((r + c) % 3) * 0.04
            b_off = thickness
            t_off = thickness + h_var

            sb = [
                (sx0 + nx * b_off, sy0 + ny * b_off, z0),
                (sx1 + nx * b_off, sy1 + ny * b_off, z0),
                (sx1 + nx * (b_off + 0.06), sy1 + ny * (b_off + 0.06), z0),
                (sx0 + nx * t_off, sy0 + ny * t_off, z0),
            ]
            sf = [
                (sx0 + nx * b_off, sy0 + ny * b_off, z1),
                (sx1 + nx * b_off, sy1 + ny * b_off, z1),
                (sx1 + nx * (b_off + 0.06), sy1 + ny * (b_off + 0.06), z1),
                (sx0 + nx * t_off, sy0 + ny * t_off, z1),
            ]
            add_prism_strip(bm, sb, sf, mat_idx=mat_shingle, cap_ends=True)


# =============================================================================
# 1. FORGE STONE SHELL, STEPPED FOUNDATION, ARCHED ENTRYWAY & CHIMNEY TOWER
# =============================================================================
def build_forge_stone_shell() -> bmesh.types.BMesh:
    bm = bmesh.new()

    # -------------------------------------------------------------------------
    # A. STEPPED STONE FOUNDATION & PAVED INTERIOR FLOOR (32 x 36 footprint)
    #    X: -16 to +16, Z: -16 (Back) to +18 (Front Steps)
    # -------------------------------------------------------------------------
    # Main Interior Floor Slab (Y = 0.0 to 1.2, X: -13.5..13.5, Z: -15.0..13.5)
    add_box(bm, 0.0, 0.6, -0.75, 27.0, 1.2, 28.5, mat_idx=0, bevel_top=0.08)

    # Interior Flagstone Paving Grid (raised 0.08 studs on floor)
    for ix in range(-4, 5):
        for iz in range(-4, 5):
            px = ix * 2.7
            pz = iz * 2.8 - 0.5
            mat_pave = 1 if ((ix + iz) % 2 == 0) else 0
            add_box(bm, px, 1.24, pz, 2.52, 0.08, 2.62, mat_idx=mat_pave, bevel_top=0.02)

    # Side Lean-To Stone Foundations (Left & Right wings X: +-13.0 to +-16.2)
    for s in (-1.0, 1.0):
        add_box(bm, s * 14.5, 0.7, -0.5, 3.4, 1.4, 25.0, mat_idx=0, bevel_top=0.10)
        # Stepped Side Base Curb
        add_box(bm, s * 15.8, 0.35, -0.5, 1.4, 0.7, 26.2, mat_idx=1, bevel_top=0.06)

    # 3 Wide Front Stone Porch Steps with Heavy Sloped Cheek Buttresses (Z = +13.0 to +17.8)
    for st in range(3):
        step_y = 0.22 + st * 0.36
        step_z = 16.8 - st * 1.35
        step_w = 11.2 - st * 0.4
        add_box(bm, 0.0, step_y, step_z, step_w, 0.42, 1.55, mat_idx=1, bevel_top=0.04)

    # Sloped Stone Porch Cheek Walls flanking the front steps
    for s in (-1.0, 1.0):
        c_ring_l = [
            (s * 5.6, 0.0, 13.2),
            (s * 5.6, 0.0, 17.8),
            (s * 5.6, 0.7, 17.8),
            (s * 5.6, 1.6, 13.2),
        ]
        c_ring_r = [
            (s * 6.5, 0.0, 13.2),
            (s * 6.5, 0.0, 17.8),
            (s * 6.5, 0.7, 17.8),
            (s * 6.5, 1.6, 13.2),
        ]
        add_prism_strip(bm, c_ring_l, c_ring_r, mat_idx=1, cap_ends=True)

    # -------------------------------------------------------------------------
    # B. HOLLOWED MAIN HALL PERIMETER WALLS (Interior ~23 x 25 studs clear!)
    #    Wall thickness = 1.8 studs; Back wall Z=-14.2, Left/Right X=+-12.2
    # -------------------------------------------------------------------------
    # Back Wall (Z = -14.2, X: -13.0 to +13.0, Y: 1.2 to 13.5)
    add_box(bm, 0.0, 7.35, -14.2, 26.0, 12.3, 1.8, mat_idx=0, bevel_top=0.05)
    # Back Gable Triangular Masonry Wall (Y: 13.5 to 23.0)
    bg_front = [(-12.5, 13.4, -13.3), (12.5, 13.4, -13.3), (0.0, 23.2, -13.3)]
    bg_back  = [(-12.5, 13.4, -15.1), (12.5, 13.4, -15.1), (0.0, 23.2, -15.1)]
    add_prism_strip(bm, bg_back, bg_front, mat_idx=0, cap_ends=True)

    # Left & Right Main Hall Walls (X = +-12.2, Z: -14.2 to +12.5, Y: 1.2 to 13.0)
    for s in (-1.0, 1.0):
        add_box(bm, s * 12.2, 7.1, -0.8, 1.8, 11.8, 26.8, mat_idx=0, bevel_top=0.05)
        # Side Lean-To Brick & Stone Lower Walls (X = +-15.2, Z: -11.5 to +10.5, Y: 1.2 to 6.8)
        add_box(bm, s * 15.2, 2.3, -0.5, 1.2, 2.2, 21.6, mat_idx=1, bevel_top=0.06)
        add_box(bm, s * 15.1, 4.8, -0.5, 1.0, 3.0, 20.8, mat_idx=4, bevel_top=0.02)
        # Coursed Ashlar Quoins on Side Corners
        for c_z in (-11.2, 10.2):
            for q in range(4):
                add_box(bm, s * 15.3, 2.0 + q * 1.25, c_z, 1.4, 0.95, 1.4, mat_idx=1, bevel_top=0.05)

    # -------------------------------------------------------------------------
    # C. FRONT WALL & OVERSIZED ARCHED ENTRYWAY (Z = +12.5, Arch 11.2W x 13.0H)
    #    Leaves center X: -5.6 to +5.6 completely open for Roblox avatars!
    # -------------------------------------------------------------------------
    for s in (-1.0, 1.0):
        # Flanking Front Wall Segments (X: +-5.6 to +-12.8)
        add_box(bm, s * 9.2, 7.2, 12.2, 6.8, 12.0, 2.0, mat_idx=0, bevel_top=0.05)
        # Brick Inset Panel on Front Flanking Wall
        add_box(bm, s * 9.8, 5.2, 13.25, 3.8, 4.4, 0.3, mat_idx=4)

        # Massive Tiered Ashlar Stone Buttress Pillars framing the Entry Arch (X = +-6.8, Z = +13.4)
        px, pz = s * 6.8, 13.4
        add_box(bm, px, 2.2, pz, 3.2, 2.2, 3.2, mat_idx=1, bevel_top=0.12)
        for tier in range(6):
            ty = 3.8 + tier * 1.45
            tw = 2.6 if (tier % 2 == 0) else 2.4
            add_box(bm, px, ty, pz, tw, 1.32, tw, mat_idx=1, bevel_top=0.06)
        # Buttress Mid-Band & Capital Cap
        add_box(bm, px, 7.4, pz, 3.0, 0.75, 3.0, mat_idx=1, bevel_top=0.08)
        add_box(bm, px, 12.6, pz, 3.1, 0.95, 3.1, mat_idx=1, bevel_top=0.10)

    # Oversized Semicircular/Pointed Voussoir Stone Archway (Span X: -5.6 to +5.6, Spring Y=8.0, Crown Y=14.0)
    arch_segs = 18
    r_in = 5.6
    r_out = 7.1
    spring_y = 8.0
    for i in range(arch_segs):
        a0 = math.pi * (i / float(arch_segs))
        a1 = math.pi * ((i + 1) / float(arch_segs))
        # Pointed gothic lift at the crown
        lift0 = 0.75 * math.sin(a0)
        lift1 = 0.75 * math.sin(a1)

        ix0, iy0 = math.cos(a0) * r_in, spring_y + math.sin(a0) * r_in + lift0
        ox0, oy0 = math.cos(a0) * r_out, spring_y + math.sin(a0) * r_out + lift0
        ix1, iy1 = math.cos(a1) * r_in, spring_y + math.sin(a1) * r_in + lift1
        ox1, oy1 = math.cos(a1) * r_out, spring_y + math.sin(a1) * r_out + lift1

        zf = 14.35 if (i % 2 == 0) else 14.15
        zb = 11.1
        mat_v = 1 if (i % 2 == 0) else 0
        ring_a = [(ix0, iy0, zb), (ox0, oy0, zb), (ox0, oy0, zf), (ix0, iy0, zf)]
        ring_b = [(ix1, iy1, zb), (ox1, oy1, zb), (ox1, oy1, zf), (ix1, iy1, zf)]
        add_prism_strip(bm, ring_a, ring_b, mat_idx=mat_v, cap_ends=False)

    # Arch Keystone at Crown (X = 0, Y = 14.3, Z = 13.0)
    add_box(bm, 0.0, 14.3, 13.0, 1.6, 2.1, 3.5, mat_idx=1, bevel_top=0.10)

    # Front Gable Upper Wall (Brick & Plaster Infill behind Timber Truss, Y: 13.5 to 23.0, Z = 12.3)
    fg_front = [(-11.8, 13.2, 12.8), (11.8, 13.2, 12.8), (0.0, 23.2, 12.8)]
    fg_back  = [(-11.8, 13.2, 11.5), (11.8, 13.2, 11.5), (0.0, 23.2, 11.5)]
    add_prism_strip(bm, fg_back, fg_front, mat_idx=4, cap_ends=True)

    # -------------------------------------------------------------------------
    # D. CENTRAL TAPERED CYLINDRICAL STONE SMOKESTACK TOWER WITH CRENELLATIONS
    #    Rises above the rear-center roof (X = 0, Z = -5.5, Y = 16.0 to 33.5)
    # -------------------------------------------------------------------------
    cx, cz = 0.0, -5.5
    # Square Stone Base Saddle on Roof Ridge
    add_box(bm, cx, 18.5, cz, 9.6, 5.5, 9.6, mat_idx=0, bevel_top=0.25)

    # Coursed Tapered Cylindrical Stone Chimney Shaft (8 courses with mortar bevels)
    num_courses = 9
    y_start = 20.5
    course_h = 1.15
    for c_idx in range(num_courses):
        t0 = c_idx / float(num_courses)
        t1 = (c_idx + 1) / float(num_courses)
        r0 = 4.65 * (1.0 - 0.18 * t0)
        r1 = 4.65 * (1.0 - 0.18 * t1)
        yc0 = y_start + c_idx * course_h
        yc1 = yc0 + course_h * 0.92
        mat_c = 1 if (c_idx % 2 == 0) else 0
        add_cylinder_y(bm, cx, yc0, yc1, cz, r0, r1, mat_idx=mat_c, sides=18, cap_ends=True)

    # Corbelled Crenellated Battlement Crown & Iron Studs (Y = 30.8 to 33.8)
    crown_y = y_start + num_courses * course_h
    add_cylinder_y(bm, cx, crown_y - 0.3, crown_y + 0.9, cz, 3.9, 4.45, mat_idx=1, sides=18, cap_ends=True)
    add_cylinder_y(bm, cx, crown_y + 0.9, crown_y + 1.8, cz, 4.45, 4.50, mat_idx=4, sides=18, cap_ends=True)

    # 8 Crenellated Stone Merlons around the Chimney Rim + Iron Pyramid Bosses
    merlon_count = 8
    rim_r = 4.15
    for m_idx in range(merlon_count):
        ang = (m_idx / float(merlon_count)) * math.pi * 2.0
        mx = cx + math.cos(ang) * rim_r
        mz = cz + math.sin(ang) * rim_r
        add_box(bm, mx, crown_y + 2.45, mz, 1.55, 1.45, 0.95, mat_idx=1, bevel_top=0.06, yaw_rad=-ang)
        # Iron Stud on outer face of chimney band
        sx = cx + math.cos(ang) * 4.52
        sz = cz + math.sin(ang) * 4.52
        add_box(bm, sx, crown_y + 1.35, sz, 0.42, 0.42, 0.35, mat_idx=5, bevel_top=0.15, yaw_rad=-ang)

    # Glowing Ember Flue Bed inside the top of the Chimney (Zone 7: EmberGlow)
    add_cylinder_y(bm, cx, crown_y + 0.8, crown_y + 1.95, cz, 3.2, 3.2, mat_idx=7, sides=16, cap_ends=True)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# =============================================================================
# 2. STEEP GABLED SLATE ROOF, DORMERS, SIDE LEAN-TO ROOFS & STONE COPING
# =============================================================================
def build_forge_roof_and_timber() -> bmesh.types.BMesh:
    bm = bmesh.new()

    # -------------------------------------------------------------------------
    # A. MAIN STEEP GABLED SLATE ROOF (X: 0 to +-13.4, Y: 23.5 to 12.6, Z: -15.6 to +14.8)
    # -------------------------------------------------------------------------
    for s in (-1.0, 1.0):
        add_gable_roof_slope(
            bm,
            x_ridge=0.0,
            y_ridge=23.5,
            x_eave=s * 13.4,
            y_eave=12.6,
            z_back=-15.6,
            z_front=14.6,
            thickness=0.65,
            mat_base=0,
            mat_shingle=2,
            shingle_rows=8,
            shingle_cols=9,
        )

    # Heavy Beveled Stone Ridge Coping Crest along Main Roof Peak (Y = 24.3)
    for r_seg in range(8):
        rz = -14.0 + r_seg * 3.9
        add_box(bm, 0.0, 24.35, rz, 1.35, 0.95, 3.75, mat_idx=1, bevel_top=0.18)

    # -------------------------------------------------------------------------
    # B. RIGHT CROSS-GABLE WING & DORMER WINDOWS (matching reference close-up)
    # -------------------------------------------------------------------------
    # Right Cross-Gable Wing Roof (X: +4.0 to +15.8, Z: -8.5 to +2.5, Ridge Y = 21.0)
    for sz in (-1.0, 1.0):
        z_r = -3.0
        z_e = -3.0 + sz * 6.2
        ring_in = [(4.0, 21.2, z_r), (4.0, 14.5, z_e), (4.0, 15.2, z_e), (4.0, 21.9, z_r)]
        ring_out = [(15.6, 21.2, z_r), (15.6, 14.5, z_e), (15.6, 15.2, z_e), (15.6, 21.9, z_r)]
        add_prism_strip(bm, ring_in, ring_out, mat_idx=2, cap_ends=True)
    # Cross-Gable Stone Ridge Cap
    add_box(bm, 9.8, 22.1, -3.0, 11.8, 0.85, 1.15, mat_idx=1, bevel_top=0.14)

    # Gothc Pointed Dormer Window on Right Cross-Gable Front Face (X = +10.2, Y = 16.5, Z = +2.2)
    add_box(bm, 10.2, 16.5, 1.8, 3.6, 3.8, 2.8, mat_idx=3, bevel_top=0.05)
    add_box(bm, 10.2, 16.5, 3.25, 2.2, 2.6, 0.25, mat_idx=5)  # Dark Iron Mullion Frame
    add_box(bm, 10.2, 16.5, 3.38, 0.22, 2.5, 0.15, mat_idx=3)  # Vertical Mullion
    add_box(bm, 10.2, 16.7, 3.38, 2.1, 0.22, 0.15, mat_idx=3)  # Horizontal Transom
    # Dormer Gable Hood
    d_back  = [(8.0, 18.0, 0.4), (12.4, 18.0, 0.4), (10.2, 20.4, 0.4)]
    d_front = [(8.0, 18.0, 3.8), (12.4, 18.0, 3.8), (10.2, 20.4, 3.8)]
    add_prism_strip(bm, d_back, d_front, mat_idx=2, cap_ends=True)

    # Upper Left/Front Dormer Window on Main Roof Slope (X = +3.2, Y = 18.8, Z = +5.8)
    add_box(bm, 3.2, 18.6, 5.8, 2.8, 3.2, 3.2, mat_idx=3)
    u_back  = [(1.5, 19.8, 4.0), (4.9, 19.8, 4.0), (3.2, 21.8, 4.0)]
    u_front = [(1.5, 19.8, 7.6), (4.9, 19.8, 7.6), (3.2, 21.8, 7.6)]
    add_prism_strip(bm, u_back, u_front, mat_idx=2, cap_ends=True)

    # -------------------------------------------------------------------------
    # C. LOWER SIDE LEAN-TO SHED ROOFS (Left & Right X: +-11.8 to +-16.6, Y: 10.6 to 6.2)
    # -------------------------------------------------------------------------
    for s in (-1.0, 1.0):
        add_gable_roof_slope(
            bm,
            x_ridge=s * 11.8,
            y_ridge=10.6,
            x_eave=s * 16.8,
            y_eave=6.2,
            z_back=-11.8,
            z_front=11.2,
            thickness=0.50,
            mat_base=3,
            mat_shingle=2,
            shingle_rows=4,
            shingle_cols=7,
        )
        # Heavy Timber Corner Posts & Diagonal Braces supporting Lean-To Eaves
        for pz in (-10.2, 0.0, 9.8):
            add_box(bm, s * 15.2, 3.8, pz, 0.95, 5.2, 0.95, mat_idx=3)

    # -------------------------------------------------------------------------
    # D. FRONT GABLE HEAVY TIMBER TRUSS, BARGEBOARDS & IRON BRACKETS
    # -------------------------------------------------------------------------
    # Horizontal Tie Beam above Stone Arch (Y = 13.8, Z = +13.6)
    add_box(bm, 0.0, 13.8, 13.6, 15.6, 1.05, 1.15, mat_idx=3, bevel_top=0.04)
    # King Post (X = 0, Y: 14.2 to 22.8, Z = +13.5)
    add_box(bm, 0.0, 18.5, 13.5, 1.05, 8.6, 0.95, mat_idx=3)
    # Diagonal Timber Struts in Gable Truss
    for s in (-1.0, 1.0):
        add_box(bm, s * 2.4, 16.5, 13.45, 0.85, 5.6, 0.80, mat_idx=3, roll_rad=s * 0.62)
        add_box(bm, s * 4.8, 15.4, 13.45, 0.75, 3.8, 0.75, mat_idx=3, roll_rad=-s * 0.55)

        # Heavy Angled Timber Bargeboards framing the Front Gable Peak (Z = +14.2)
        b_len = 15.6
        ang = math.atan2(10.9, 13.4)  # Roof pitch angle
        cx_b = s * 6.8
        cy_b = 18.1
        add_box(bm, cx_b, cy_b, 14.2, b_len, 1.15, 1.10, mat_idx=3, roll_rad=-s * ang)

        # Wrought-Iron Corner Strap Bracket with Rivet Studs on Lower Bargeboard
        ix_b = s * 10.6
        iy_b = 15.0
        add_box(bm, ix_b, iy_b, 14.25, 2.2, 1.35, 1.25, mat_idx=5, roll_rad=-s * ang)
        add_box(bm, ix_b, iy_b, 14.92, 0.35, 0.35, 0.25, mat_idx=6)

        # Stone Corbel Finial at Base of Gable Bargeboard
        add_box(bm, s * 13.2, 12.6, 14.2, 2.1, 1.8, 2.2, mat_idx=1, bevel_top=0.12)

    # Peak Stone Finial Block at Front Gable Apex (X = 0, Y = 24.4, Z = +14.5)
    add_box(bm, 0.0, 24.4, 14.5, 1.8, 1.6, 2.4, mat_idx=1, bevel_top=0.15)

    # -------------------------------------------------------------------------
    # E. OPEN ARCHED WOODEN DOOR (Hinged on Left Jamb X = -5.4, swung inward)
    # -------------------------------------------------------------------------
    door_hinge_x = -5.4
    door_hinge_z = 11.8
    # Swung inward at 78 degrees so the entryway is wide open
    door_yaw = math.radians(-78.0)
    add_box(bm, door_hinge_x + 0.5, 5.8, door_hinge_z - 2.1, 4.4, 9.2, 0.48, mat_idx=3, yaw_rad=door_yaw)
    # Iron Strap Hinges on the Wooden Door
    for hy in (2.8, 5.8, 8.6):
        add_box(bm, door_hinge_x + 0.5, hy, door_hinge_z - 2.1, 4.0, 0.32, 0.58, mat_idx=5, yaw_rad=door_yaw)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# =============================================================================
# 3. INTERIOR HEARTH FIREBOX, ANVIL ON TIMBER BLOCK & BLACKSMITH TOOLS
# =============================================================================
def build_forge_interior_props() -> bmesh.types.BMesh:
    bm = bmesh.new()

    # -------------------------------------------------------------------------
    # A. INTERIOR STONE & BRICK HEARTH FIREBOX AGAINST BACK WALL (Z = -10.2)
    # -------------------------------------------------------------------------
    hx = -0.8
    # Coursed Stone Masonry Blocks on Back Interior Wall behind Hearth & Sword Barrel
    for r_row in range(6):
        ry = 2.0 + r_row * 1.45
        for c_col in range(-5, 6):
            stag = 0.7 if (r_row % 2 == 1) else 0.0
            rx_b = c_col * 2.1 + stag
            if abs(rx_b) <= 11.2:
                add_box(bm, rx_b, ry, -13.1, 1.95, 1.32, 0.35, mat_idx=1 if ((r_row + c_col) % 2 == 0) else 0, bevel_top=0.04)

    # Interior Heavy Timber Ceiling Beams & Wall Posts
    for tx in (-5.8, 5.8):
        add_box(bm, tx, 7.2, -12.6, 0.95, 11.8, 0.95, mat_idx=3)
    for tz in (-8.5, -2.5, 3.5):
        add_box(bm, 0.0, 12.6, tz, 23.0, 0.95, 0.95, mat_idx=3)

    # Warm Wood Plank Flooring in the Inner Forge Workshop Zone (Z: -12.5 to +3.5)
    for p_idx in range(-5, 6):
        px = p_idx * 2.0
        add_box(bm, px, 1.28, -4.5, 1.88, 0.10, 15.6, mat_idx=3, bevel_top=0.02)

    # Raised Stone Hearth Plinth
    add_box(bm, hx, 2.1, -10.2, 11.6, 1.8, 6.2, mat_idx=1, bevel_top=0.12)
    # Flanking Brick Firebox Piers
    for s in (-1.0, 1.0):
        add_box(bm, hx + s * 4.2, 5.4, -10.2, 2.8, 4.8, 5.4, mat_idx=4, bevel_top=0.05)
    # Back Brick Firebox Wall
    add_box(bm, hx, 5.4, -12.0, 6.0, 4.8, 1.8, mat_idx=4)
    # Arched Stone Hearth Lintel & Tapered Chimney Hood
    add_box(bm, hx, 8.2, -10.0, 11.2, 1.4, 5.8, mat_idx=1, bevel_top=0.15)
    hood_bot = [(hx - 5.2, 8.9, -12.6), (hx + 5.2, 8.9, -12.6), (hx + 5.2, 8.9, -7.4), (hx - 5.2, 8.9, -7.4)]
    hood_top = [(hx - 3.2, 14.5, -12.2), (hx + 3.2, 14.5, -12.2), (hx + 3.2, 14.5, -8.2), (hx - 3.2, 14.5, -8.2)]
    add_prism_strip(bm, hood_bot, hood_top, mat_idx=0, cap_ends=True)

    # Roaring Glowing Ember Bed & Coals inside the Hearth Firebox (Zone 7: EmberGlow)
    add_box(bm, hx, 3.3, -10.0, 5.2, 0.85, 3.6, mat_idx=7, bevel_top=0.25)
    add_box(bm, hx - 1.1, 3.85, -9.8, 1.6, 0.75, 1.5, mat_idx=7, bevel_top=0.30, yaw_rad=0.4)
    add_box(bm, hx + 1.2, 3.95, -10.1, 1.8, 0.85, 1.6, mat_idx=7, bevel_top=0.35, yaw_rad=-0.3)

    # -------------------------------------------------------------------------
    # B. CENTRAL IRON ANVIL ON HEAVY TIMBER BLOCK & STEPPED BASE (X = -0.5, Z = +1.8)
    #    Positioned in the front-center of the interior, clearly visible from outside!
    # -------------------------------------------------------------------------
    ax, az = -0.5, 1.8
    # Stepped Stone Pedestal Base under Anvil
    add_box(bm, ax, 1.55, az, 4.4, 0.70, 3.6, mat_idx=1, bevel_top=0.08)
    # Heavy Banded Timber Block
    add_box(bm, ax, 2.65, az, 3.2, 1.55, 2.5, mat_idx=3, bevel_top=0.05)
    add_box(bm, ax, 2.95, az, 3.32, 0.24, 2.62, mat_idx=5)  # Iron hoop band
    # Cast-Iron Anvil Base, Waist, Working Face, Heel & Tapered Horn
    add_box(bm, ax, 3.65, az, 2.6, 0.50, 1.6, mat_idx=5, bevel_top=0.08)
    add_box(bm, ax, 4.15, az, 1.8, 0.65, 1.15, mat_idx=5)
    add_box(bm, ax, 4.72, az, 3.4, 0.58, 1.45, mat_idx=5, bevel_top=0.03)
    add_box(bm, ax, 5.02, az, 3.2, 0.08, 1.35, mat_idx=6)  # Polished steel top face
    # Tapered Anvil Horn pointing +X
    horn_base = [(ax + 1.6, 4.48, az - 0.58), (ax + 1.6, 4.48, az + 0.58), (ax + 1.6, 4.98, az + 0.58), (ax + 1.6, 4.98, az - 0.58)]
    horn_tip  = [(ax + 3.15, 4.72, az - 0.14), (ax + 3.15, 4.72, az + 0.14), (ax + 3.15, 4.92, az + 0.14), (ax + 3.15, 4.92, az - 0.14)]
    add_prism_strip(bm, horn_base, horn_tip, mat_idx=5, cap_ends=True)

    # Blacksmith Hammer resting on the Anvil
    add_box(bm, ax - 0.4, 5.18, az + 0.1, 0.95, 0.18, 0.18, mat_idx=3, yaw_rad=0.45)
    add_box(bm, ax - 0.05, 5.22, az - 0.1, 0.35, 0.32, 0.58, mat_idx=6, yaw_rad=0.45)

    # -------------------------------------------------------------------------
    # C. INTERIOR WATER QUENCHING TROUGH, SWORD BARREL & SIDE EMBER COUNTER
    # -------------------------------------------------------------------------
    # Stone Quenching Trough / Barrel to the right of the Anvil (X = +4.8, Z = +1.2)
    add_cylinder_y(bm, 4.8, 1.2, 3.6, 1.2, 1.55, 1.65, mat_idx=3, sides=14, cap_ends=True)
    add_cylinder_y(bm, 4.8, 3.3, 3.68, 1.2, 1.35, 1.35, mat_idx=8, sides=14, cap_ends=True)

    # Interior Sword Barrel next to Hearth with 5 Fanned Swords (blades pointing UP!)
    sb_x, sb_z = 2.6, -6.8
    add_cylinder_y(bm, sb_x, 1.2, 4.2, sb_z, 1.25, 1.38, mat_idx=3, sides=14, cap_ends=True)
    add_cylinder_y(bm, sb_x, 2.2, 2.4, sb_z, 1.36, 1.36, mat_idx=5, sides=14, cap_ends=False)
    add_cylinder_y(bm, sb_x, 3.6, 3.8, sb_z, 1.40, 1.40, mat_idx=5, sides=14, cap_ends=False)
    for b_idx in range(5):
        ang = 0.36 - b_idx * 0.18  # Fan outward at top!
        bx_s = sb_x + (b_idx - 2) * 0.38
        add_box(bm, bx_s, 5.4, sb_z, 0.16, 3.8, 0.28, mat_idx=6, roll_rad=ang)
        add_box(bm, bx_s - math.sin(ang) * 1.1, 6.4, sb_z, 0.72, 0.16, 0.32, mat_idx=5, roll_rad=ang)
        add_box(bm, bx_s - math.sin(ang) * 1.55, 6.85, sb_z, 0.16, 0.65, 0.16, mat_idx=3, roll_rad=ang)

    # Secondary Stone Brazier / Forge Counter on Right Back Wall (X = +6.4, Z = -7.2)
    add_box(bm, 6.4, 2.6, -7.2, 4.2, 2.8, 3.8, mat_idx=1, bevel_top=0.08)
    add_box(bm, 6.4, 4.2, -7.2, 2.6, 0.65, 2.2, mat_idx=7, bevel_top=0.20)

    # Heavy Timber Workbench along Left Interior Wall (X = -8.6, Z = -3.0)
    add_box(bm, -8.6, 3.0, -3.0, 2.8, 0.45, 7.6, mat_idx=3)
    for lz in (-6.0, 0.0):
        add_box(bm, -8.6, 2.0, lz, 2.4, 1.6, 0.55, mat_idx=3)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# =============================================================================
# 4. EXTERIOR HANGING ANVIL SIGN, FLANKING BRAZIERS, WEAPON RACK & BARRELS
# =============================================================================
def build_forge_exterior_props() -> bmesh.types.BMesh:
    bm = bmesh.new()

    # -------------------------------------------------------------------------
    # A. HANGING BLACKSMITH SHIELD & ANVIL SIGN ON RIGHT TIMBER CRANE ARM
    #    Matches reference close-up: horizontal beam on right side (+X), diagonal
    #    brace, iron chains, and shield sign with sculpted anvil & hammer!
    # -------------------------------------------------------------------------
    # Horizontal Timber Crane Beam (X: +11.5 to +22.8, Y = 14.8, Z = +1.5)
    add_box(bm, 17.2, 14.8, 1.5, 11.6, 0.95, 0.95, mat_idx=3, bevel_top=0.04)
    # Diagonal Timber Support Brace
    add_box(bm, 14.2, 12.6, 1.5, 5.8, 0.75, 0.75, mat_idx=3, roll_rad=0.68)
    # Iron Mounting Collar Straps on Beam for Chains
    for cx_chain in (18.2, 21.4):
        add_box(bm, cx_chain, 14.8, 1.5, 0.48, 1.15, 1.15, mat_idx=5)
        # Hanging Chain Links (Y: 14.2 down to 10.6)
        for lk in range(6):
            ly = 14.0 - lk * 0.62
            yaw_l = 0.0 if (lk % 2 == 0) else (math.pi * 0.5)
            add_box(bm, cx_chain, ly, 1.5, 0.18, 0.72, 0.42, mat_idx=5, yaw_rad=yaw_l)

    # Draped Swag Chain from Inner Beam to Sign
    for sw in range(7):
        t = sw / 6.0
        sx = 14.5 + t * 3.5
        sy = 14.2 - math.sin(t * math.pi) * 2.2 - t * 1.6
        add_box(bm, sx, sy, 1.5, 0.55, 0.25, 0.25, mat_idx=5, roll_rad=-0.35 + t * 0.7)

    # Shield Sign Board with Iron Rim (Centered at X = 19.8, Y = 8.2, Z = +1.5)
    sx_c, sy_c, sz_c = 19.8, 8.2, 1.5
    shield_back = [
        (sx_c - 2.3, sy_c + 2.2, sz_c - 0.25),
        (sx_c + 2.3, sy_c + 2.2, sz_c - 0.25),
        (sx_c + 2.1, sy_c - 0.4, sz_c - 0.25),
        (sx_c,       sy_c - 2.5, sz_c - 0.25),
        (sx_c - 2.1, sy_c - 0.4, sz_c - 0.25),
    ]
    shield_front = [
        (sx_c - 2.3, sy_c + 2.2, sz_c + 0.25),
        (sx_c + 2.3, sy_c + 2.2, sz_c + 0.25),
        (sx_c + 2.1, sy_c - 0.4, sz_c + 0.25),
        (sx_c,       sy_c - 2.5, sz_c + 0.25),
        (sx_c - 2.1, sy_c - 0.4, sz_c + 0.25),
    ]
    add_prism_strip(bm, shield_back, shield_front, mat_idx=3, cap_ends=True)
    # Top Iron Frame Bar on Shield
    add_box(bm, sx_c, sy_c + 2.2, sz_c, 4.8, 0.38, 0.62, mat_idx=5)

    # Relief Anvil & Crossed Hammer Emblem on both front and back of the Shield Sign
    for f_sign in (-1.0, 1.0):
        ez = sz_c + f_sign * 0.32
        # Anvil Base & Horn Relief
        add_box(bm, sx_c, sy_c - 0.9, ez, 1.6, 0.45, 0.18, mat_idx=6)
        add_box(bm, sx_c, sy_c - 0.35, ez, 2.4, 0.55, 0.20, mat_idx=6)
        # Hammer above Anvil Relief
        add_box(bm, sx_c + 0.2, sy_c + 0.85, ez, 1.6, 0.22, 0.18, mat_idx=3, roll_rad=0.45)
        add_box(bm, sx_c - 0.3, sy_c + 1.15, ez, 0.75, 0.42, 0.22, mat_idx=6, roll_rad=0.45)

    # -------------------------------------------------------------------------
    # B. TWO FLANKING STONE PEDESTALS & IRON FIRE BRAZIERS AT FRONT ENTRANCE
    #    Positioned at X = +-7.4, Z = +15.8 (flanking the 3 front steps)
    # -------------------------------------------------------------------------
    for s in (-1.0, 1.0):
        bx, bz = s * 7.4, 15.8
        # Two-Tier Stepped Stone Pedestal
        add_box(bm, bx, 0.45, bz, 3.6, 0.90, 3.6, mat_idx=0, bevel_top=0.08)
        add_box(bm, bx, 1.25, bz, 2.8, 0.80, 2.8, mat_idx=1, bevel_top=0.08)
        # Octagonal Cast-Iron Brazier Bowl
        add_cylinder_y(bm, bx, 1.65, 2.25, bz, 0.85, 1.45, mat_idx=5, sides=8, cap_ends=True)
        add_cylinder_y(bm, bx, 2.25, 2.65, bz, 1.45, 1.55, mat_idx=5, sides=8, cap_ends=True)
        # Glowing Fire & Logs inside Brazier Bowl (Zone 7: EmberGlow)
        add_cylinder_y(bm, bx, 2.55, 3.25, bz, 1.15, 0.55, mat_idx=7, sides=8, cap_ends=True)
        add_box(bm, bx, 3.35, bz, 0.85, 0.95, 0.85, mat_idx=7, bevel_top=0.35, yaw_rad=0.5)

    # -------------------------------------------------------------------------
    # C. EXTERIOR WOODEN SWORD RACK & BARRELS (Front-Right of Forge)
    # -------------------------------------------------------------------------
    rx, rz = 10.6, 13.8
    for sx in (-1.8, 1.8):
        add_box(bm, rx + sx, 1.8, rz, 0.35, 3.2, 0.35, mat_idx=3)
        add_box(bm, rx + sx, 0.3, rz, 0.45, 0.35, 1.6, mat_idx=3)
    add_box(bm, rx, 2.8, rz, 4.0, 0.32, 0.38, mat_idx=3)
    add_box(bm, rx, 1.1, rz, 4.0, 0.32, 0.38, mat_idx=3)
    # 3 Broadswords resting in the Rack
    for sw_i in (-1, 0, 1):
        sx_w = rx + sw_i * 1.05
        add_box(bm, sx_w, 2.1, rz + 0.12, 0.20, 2.9, 0.08, mat_idx=6)
        add_box(bm, sx_w, 3.1, rz + 0.12, 0.75, 0.16, 0.18, mat_idx=5)
        add_box(bm, sx_w, 3.5, rz + 0.12, 0.16, 0.65, 0.16, mat_idx=3)

    # Wooden Barrels with Iron Hoops near Right Lean-To Corner (X = +14.8, Z = +11.8)
    for b_pos in ((14.8, 11.8, 1.0), (16.4, 9.8, 0.9), (-14.8, 12.2, 0.95)):
        px_b, pz_b, sc = b_pos
        add_cylinder_y(bm, px_b, 0.0, 2.8 * sc, pz_b, 1.05 * sc, 1.12 * sc, mat_idx=3, sides=12, cap_ends=True)
        for hy in (0.65 * sc, 2.15 * sc):
            add_cylinder_y(bm, px_b, hy, hy + 0.18 * sc, pz_b, 1.15 * sc, 1.15 * sc, mat_idx=5, sides=12, cap_ends=False)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# =============================================================================
# 5. COLLECTION & MESH OBJECT ASSEMBLY + FBX EXPORT
# =============================================================================
def link_bmesh_to_collection(
    name: str,
    bm: bmesh.types.BMesh,
    col: bpy.types.Collection,
    mat_slots: list,
) -> bpy.types.Object:
    mesh_data = bpy.data.meshes.new(f"{name}_Mesh")
    bm.to_mesh(mesh_data)
    bm.free()

    obj = bpy.data.objects.new(name, mesh_data)
    col.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    for mat in mat_slots:
        mesh_data.materials.append(mat)

    for poly in mesh_data.polygons:
        poly.use_smooth = False

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return obj


def create_blacksmith_forge(export_fbx_path: str = None):
    # Remove default startup Cube if untouched
    default_cube = bpy.data.objects.get("Cube")
    if default_cube and len(default_cube.data.polygons) == 6:
        bpy.data.objects.remove(default_cube, do_unlink=True)

    # Clear existing collection if present
    if COLLECTION_NAME in bpy.data.collections:
        old_col = bpy.data.collections[COLLECTION_NAME]
        for obj in list(old_col.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old_col)

    forge_col = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(forge_col)

    mat_slots = build_materials()

    obj_shell = link_bmesh_to_collection("Forge_StoneShell", build_forge_stone_shell(), forge_col, mat_slots)
    obj_roof  = link_bmesh_to_collection("Forge_RoofAndTimber", build_forge_roof_and_timber(), forge_col, mat_slots)
    obj_inter = link_bmesh_to_collection("Forge_InteriorAnvilHearth", build_forge_interior_props(), forge_col, mat_slots)
    obj_exter = link_bmesh_to_collection("Forge_ExteriorBraziersSign", build_forge_exterior_props(), forge_col, mat_slots)

    # Parent sub-meshes under Forge_StoneShell for clean single-model pivoting
    for child in (obj_roof, obj_inter, obj_exter):
        child.parent = obj_shell

    # Add Roblox Attachment Sockets
    sockets = {
        "PromptAnchor":      (0.5, 4.2, 1.5),    # Above central Anvil inside the forge
        "HearthFireSocket":  (0.0, 4.2, -10.0),  # Inside brick firebox for flames & PointLight
        "ChimneySmokeSocket":(0.0, 32.5, -5.5),  # Top of stone smokestack for rising dark smoke
        "BrazierLeftSocket": (-7.4, 3.2, 15.8),  # Front-left entrance brazier flame
        "BrazierRightSocket":( 7.4, 3.2, 15.8),  # Front-right entrance brazier flame
    }
    for s_name, pt_rbx in sockets.items():
        emp = bpy.data.objects.new(s_name, None)
        emp.empty_display_type = "ARROWS"
        emp.empty_display_size = 0.8
        emp.location = rbx_to_blender(*pt_rbx)
        emp.parent = obj_shell
        forge_col.objects.link(emp)

    total_tris = sum(
        sum(len(p.vertices) - 2 for p in o.data.polygons)
        for o in (obj_shell, obj_roof, obj_inter, obj_exter)
    )
    print(f"Blacksmith Forge procedural geometry generated successfully ({total_tris} tris).")

    if export_fbx_path:
        os.makedirs(os.path.dirname(os.path.abspath(export_fbx_path)), exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        obj_shell.select_set(True)
        for ch in obj_shell.children_recursive:
            ch.select_set(True)
        bpy.context.view_layer.objects.active = obj_shell
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
        print(f"Exported Blacksmith Forge FBX to: {export_fbx_path}")

    return obj_shell


if __name__ == "__main__":
    for fbx_out in (
        r"C:\WORK\infinite-tower\assets\models\facilities\blacksmith_forge_gothic.fbx",
        r"C:\WORK\infinite-tower\assets\models\facilities\BlacksmithForge.fbx",
        r"C:\WORK\infinite-tower\assets-source\facilities\blacksmith_forge\BlacksmithForge.fbx",
    ):
        create_blacksmith_forge(export_fbx_path=fbx_out)
