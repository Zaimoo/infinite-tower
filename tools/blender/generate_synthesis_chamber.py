"""
=============================================================================
Infinite Towers: Become a Master! - 3D Environment & VFX Pipeline
Asset: Enterable Dark-Gothic Synthesis Chamber ("The Pit" / `SynthesisChamber`)
Reference:
  - Implementation Plan: synthesis_chamber_blender_roblox_implementation_plan.md
Target Engine: Blender 4.x / 5.x -> Roblox Studio (MeshPart / PlotFacilities)
=============================================================================
Procedural generation script that builds the enterable cylindrical dark-gothic
rotunda Synthesis Chamber in the `SynthesisChamber_Asset` collection:
  1. `Chamber_Exterior_StaticMesh`  - 40x40 stepped plinth, 7-step entrance
     staircase, 34-stud outer diameter stone rotunda, colonnade, recessed
     blind arches, cyan lattice windows, crenellated parapet, intact 8-ribbed
     dome roof with glowing violet rune channels, dormer vents & cupola spire.
  2. `Chamber_Door_Left`            - Hinged left arched timber/iron door leaf
     with Object Origin at outer-left hinge (-6.0, 2.45, 17.4) for -95 deg
     outward swing.
  3. `Chamber_Door_Right`           - Hinged right arched timber/iron door leaf
     with Object Origin at outer-right hinge (+6.0, 2.45, 17.4) for +95 deg
     outward swing.
  4. `Chamber_Interior_StaticMesh`  - 30-stud inner diameter two-tier gothic
     arcade gallery, balustrade railings, stained-glass lancets & ribbed dome
     ceiling.
  5. `Chamber_Center_Pedestal`      - Central circular stone dais and dark
     forged-iron Synthesis Anvil with cyan rune inlay.
  6. `Chamber_MagicCircle_Neon`     - 16-stud concentric cyan & violet arcane
     magic circle inlaid into the sanctum floor.
  7. Empty Sockets: `DoorTriggerCenter`, `PromptAnchor`,
     `PedestalCoreVFXSocket`, `RoofSmokeVFXSocket`.

Coordinate Convention (1 Blender Meter = 1 Roblox Stud):
  - In Roblox station-local coordinates:
      rx = Right (+X), ry = Up (+Y), rz = Front (+Z toward entrance steps)
  - In Blender world coordinates:
      bx = rx (+X), by = -rz (-Y is Front), bz = ry (+Z is Up).
=============================================================================
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector

COLLECTION_NAME = "SynthesisChamber_Asset"

# 6-Zone Material Split (Step 4)
MATERIAL_SPECS = {
    "Mat_DarkGothicStone": {
        "hex": "#3A3F47",
        "metallic": 0.08,
        "roughness": 0.85,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "Mat_InteriorGalleryStone": {
        "hex": "#4A4458",
        "metallic": 0.06,
        "roughness": 0.70,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "Mat_HeavyDoorTimber": {
        "hex": "#2E282A",
        "metallic": 0.30,
        "roughness": 0.65,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "Mat_DarkForgedIron": {
        "hex": "#1A1C20",
        "metallic": 0.85,
        "roughness": 0.35,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    "Mat_NeonCyanArcane": {
        "hex": "#00E5FF",
        "metallic": 0.0,
        "roughness": 0.15,
        "emission": "#00E5FF",
        "emission_strength": 4.0,
    },
    "Mat_NeonVioletRune": {
        "hex": "#C084FC",
        "metallic": 0.0,
        "roughness": 0.15,
        "emission": "#C084FC",
        "emission_strength": 3.5,
    },
}

MAT_KEYS = [
    "Mat_DarkGothicStone",       # 0
    "Mat_InteriorGalleryStone",  # 1
    "Mat_HeavyDoorTimber",       # 2
    "Mat_DarkForgedIron",        # 3
    "Mat_NeonCyanArcane",        # 4
    "Mat_NeonVioletRune",        # 5
]

M_STONE   = 0
M_GALLERY = 1
M_TIMBER  = 2
M_IRON    = 3
M_CYAN    = 4
M_VIOLET  = 5


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
# BMESH PRIMITIVES IN ROBLOX COORDINATES (rx, ry_up, rz_front)
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
    origin_rbx: tuple = (0.0, 0.0, 0.0),
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
    ox, oy, oz = origin_rbx

    verts = []
    for lx, ly, lz in local_pts:
        x1 = lx * cr - ly * sr
        y1 = lx * sr + ly * cr
        z1 = lz
        x2 = x1
        y2 = y1 * cp - z1 * sp
        z2 = y1 * sp + z1 * cp
        rx = cx + (x2 * cyaw + z2 * syaw) - ox
        ry = cy + y2 - oy
        rz = cz + (-x2 * syaw + z2 * cyaw) - oz
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
    origin_rbx: tuple = (0.0, 0.0, 0.0),
):
    ox, oy, oz = origin_rbx
    va = [bm.verts.new(rbx_to_blender(pt[0] - ox, pt[1] - oy, pt[2] - oz)) for pt in ring_a]
    vb = [bm.verts.new(rbx_to_blender(pt[0] - ox, pt[1] - oy, pt[2] - oz)) for pt in ring_b]
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
    origin_rbx: tuple = (0.0, 0.0, 0.0),
):
    ring_b = []
    ring_t = []
    for i in range(sides):
        a = (i / float(sides)) * math.pi * 2.0
        ring_b.append((cx + math.cos(a) * r_bot, y_bot, cz + math.sin(a) * r_bot))
        ring_t.append((cx + math.cos(a) * r_top, y_top, cz + math.sin(a) * r_top))
    add_prism_strip(bm, ring_b, ring_t, mat_idx=mat_idx, cap_ends=cap_ends, origin_rbx=origin_rbx)


def add_disc_z(
    bm: bmesh.types.BMesh,
    cx: float,
    cy: float,
    cz: float,
    radius: float,
    thickness: float,
    mat_idx: int,
    sides: int = 16,
    origin_rbx: tuple = (0.0, 0.0, 0.0),
):
    hz = thickness * 0.5
    ring_a = []
    ring_b = []
    for i in range(sides):
        a = (i / float(sides)) * math.pi * 2.0
        ring_a.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius, cz - hz))
        ring_b.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius, cz + hz))
    add_prism_strip(bm, ring_a, ring_b, mat_idx=mat_idx, cap_ends=True, origin_rbx=origin_rbx)


def add_ring_box(
    bm: bmesh.types.BMesh,
    angle_deg: float,
    radius: float,
    y: float,
    sx: float,
    sy: float,
    sz: float,
    mat_idx: int,
    pitch_rad: float = 0.0,
):
    a = math.radians(angle_deg)
    cx = math.sin(a) * radius
    cz = math.cos(a) * radius
    add_box(bm, cx, y, cz, sx, sy, sz, mat_idx, yaw_rad=a, pitch_rad=pitch_rad)


def dome_profile(t: float) -> tuple:
    r = 16.2 * math.sqrt(max(0.0, 1.0 - t * t))
    y = 23.0 + 9.5 * t
    return r, y


# =============================================================================
# 1. EXTERIOR ROTUNDA, STEPPED PLINTH & INTACT RIBBED DOME
# =============================================================================
def build_exterior_mesh() -> bmesh.types.BMesh:
    bm = bmesh.new()

    # 1A. Stepped Circular Podium (Y = 0..2.4, no protruding square corners)
    add_cylinder_y(bm, 0.0, 0.0, 1.2, 0.0, 19.4, 19.4, M_STONE, sides=16)
    add_cylinder_y(bm, 0.0, 1.0, 1.25, 0.0, 19.6, 19.6, M_STONE, sides=16, cap_ends=False)
    add_cylinder_y(bm, 0.0, 1.2, 2.4, 0.0, 18.6, 18.6, M_STONE, sides=16)

    # 7-Step Entrance Staircase (+Z = 17.5..25.0) & Cheek Walls
    rise = 2.4 / 7.0
    back_z = 17.5
    for i in range(1, 8):
        top_y = i * rise
        front_z = 25.0 - (i - 1) * 1.0
        depth = front_z - back_z
        add_box(bm, 0.0, top_y * 0.5, back_z + depth * 0.5, 14.0, top_y, depth, M_STONE)
    cheek_len = 25.4 - back_z
    for s in (-1.0, 1.0):
        add_box(bm, s * 7.9, 1.6, back_z + cheek_len * 0.5, 1.8, 3.2, cheek_len, M_STONE)
        add_box(bm, s * 7.9, 3.4, back_z + cheek_len * 0.5, 2.2, 0.4, cheek_len + 0.2, M_STONE)

    # 1B. Cylindrical Stone Rotunda Wall (Outer R = 17.0, Y = 2.4..22.0)
    wall_h = 19.6
    wall_mid_y = 2.4 + wall_h * 0.5
    for k in range(16):
        a_deg = 11.25 + k * 22.5
        a_rad = math.radians(a_deg)
        if not (math.cos(a_rad) > 0.0 and abs(math.sin(a_rad) * 16.0) < 9.6):
            add_ring_box(bm, a_deg, 16.4, wall_mid_y, 6.8, wall_h, 1.2, M_STONE)

    # Projecting Entrance Bay with 12x16 Round-Arched Opening (+Z = 13.4..17.4)
    bay_z = 15.4
    for s in (-1.0, 1.0):
        add_box(bm, s * 7.75, wall_mid_y, bay_z, 3.5, wall_h, 4.0, M_STONE)
    for j in range(5):
        h_mid = (j + 0.5) * (6.0 / 5.0)
        w = math.sqrt(max(0.0, 36.0 - h_mid * h_mid))
        fill_w = 6.0 - w
        if fill_w > 0.05:
            for s in (-1.0, 1.0):
                add_box(bm, s * (w + fill_w * 0.5), 12.4 + h_mid, bay_z, fill_w, 1.2, 4.0, M_STONE)
    add_box(bm, 0.0, 20.2, bay_z, 12.0, 3.6, 4.0, M_STONE)

    # Arch Voussoir Ring & Violet Keystone Rune
    v_count = 9
    v_r = 7.2
    for i in range(v_count):
        th = math.pi * (i + 0.5) / v_count
        vx = math.cos(th) * v_r
        vy = 12.4 + math.sin(th) * v_r
        add_box(bm, vx, vy, 17.2, 2.5, 1.2, 0.6, M_STONE, roll_rad=th + math.pi * 0.5)
    add_box(bm, 0.0, 12.4 + v_r, 17.6, 0.7, 0.7, 0.12, M_VIOLET, roll_rad=math.pi * 0.25)

    # Engaged Entrance Bay Columns & Violet Frieze
    for s in (-1.0, 1.0):
        bx = s * 8.75
        add_box(bm, bx, 2.9, 17.7, 1.9, 1.0, 1.2, M_STONE)
        add_cylinder_y(bm, bx, 3.4, 20.0, 17.65, 0.7, 0.65, M_STONE, sides=8, cap_ends=False)
        add_box(bm, bx, 20.5, 17.7, 2.0, 1.0, 1.3, M_STONE)
    add_box(bm, 0.0, 21.0, 17.55, 19.0, 0.9, 0.5, M_STONE)
    add_box(bm, 0.0, 21.0, 17.85, 9.0, 0.22, 0.1, M_VIOLET)

    # 1C. Exterior Colonnade (10 Columns) + Blind Arches + Cyan Lattice Windows
    for a_deg in range(60, 301, 30):
        a_rad = math.radians(a_deg)
        cx, cz = math.sin(a_rad) * 18.0, math.cos(a_rad) * 18.0
        add_ring_box(bm, a_deg, 18.0, 2.9, 2.0, 1.0, 2.0, M_STONE)
        add_cylinder_y(bm, cx, 3.4, 20.8, cz, 0.8, 0.75, M_STONE, sides=8, cap_ends=False)
        add_ring_box(bm, a_deg, 18.0, 21.3, 2.2, 1.0, 2.2, M_STONE)

    window_bays = {75, 105, 255, 285}
    for a_deg in range(45, 316, 30):
        add_ring_box(bm, a_deg, 17.05, 10.3, 3.0, 8.6, 0.2, M_STONE)
        if a_deg in window_bays:
            add_ring_box(bm, a_deg, 17.17, 9.6, 1.3, 4.6, 0.2, M_CYAN)
            add_ring_box(bm, a_deg, 17.30, 9.6, 0.16, 4.6, 0.12, M_IRON)
            add_ring_box(bm, a_deg, 17.30, 8.6, 1.3, 0.16, 0.12, M_IRON)
            add_ring_box(bm, a_deg, 17.30, 10.6, 1.3, 0.16, 0.12, M_IRON)

    # 1D. Overhanging Cornice & Crenellated Battlements
    for k in range(16):
        a_deg = k * 22.5
        add_ring_box(bm, a_deg, 17.7, 22.4, 7.2, 1.2, 2.4, M_STONE)
        add_ring_box(bm, a_deg, 18.2, 23.5, 7.4, 1.0, 1.0, M_STONE)
    for k in range(16):
        add_ring_box(bm, k * 22.5 + 11.25, 18.2, 24.7, 2.2, 1.4, 1.2, M_STONE)

    # 1E. Intact Ribbed Stone Dome, Violet Rune Channels, Dormer Vents & Cupola Spire
    tiers = 6
    for i in range(tiers):
        r0, y0 = dome_profile(i / float(tiers))
        r1, y1 = dome_profile((i + 1) / float(tiers))
        add_cylinder_y(bm, 0.0, y0, y1, 0.0, r0, max(1.8, r1), M_STONE, sides=16, cap_ends=(i == tiers - 1))

    for k in range(8):
        az = 22.5 + k * 45.0
        for j in range(4):
            ta = 0.88 * (j / 4.0)
            tb = 0.88 * ((j + 1) / 4.0)
            ra, ya = dome_profile(ta)
            rb, yb = dome_profile(tb)
            rmid = (ra + rb) * 0.5 + 0.3
            ymid = (ya + yb) * 0.5
            seg_len = math.hypot(rb - ra, yb - ya) + 0.15
            pitch = math.atan2(yb - ya, ra - rb)
            add_ring_box(bm, az, rmid, ymid, 0.9, 0.7, seg_len, M_STONE, pitch_rad=-pitch)

    for k in range(4):
        az = k * 90.0
        for j in range(3):
            ta = 0.12 + 0.68 * (j / 3.0)
            tb = 0.12 + 0.68 * ((j + 1) / 3.0)
            ra, ya = dome_profile(ta)
            rb, yb = dome_profile(tb)
            rmid = (ra + rb) * 0.5 + 0.06
            ymid = (ya + yb) * 0.5
            seg_len = math.hypot(rb - ra, yb - ya) + 0.1
            pitch = math.atan2(yb - ya, ra - rb)
            add_ring_box(bm, az, rmid, ymid, 0.35, 0.12, seg_len, M_VIOLET, pitch_rad=-pitch)

        # 4 Dormer Vents
        d_az = 45.0 + k * 90.0
        dr, dy = dome_profile(0.30)
        add_ring_box(bm, d_az, dr - 0.6, dy + 0.6, 2.6, 2.2, 2.2, M_STONE)
        add_ring_box(bm, d_az, dr - 0.5, dy + 1.9, 3.0, 0.4, 2.6, M_STONE)
        add_ring_box(bm, d_az, dr + 0.52, dy + 0.5, 1.4, 1.1, 0.12, M_VIOLET)

    # Central Cupola Spire
    y = 32.5
    for r, h, mat in (
        (2.7, 1.3, M_STONE),
        (3.0, 0.4, M_STONE),
        (1.6, 1.8, M_STONE),
        (2.0, 0.4, M_STONE),
        (1.2, 0.9, M_STONE),
        (0.8, 0.9, M_STONE),
        (0.45, 0.9, M_STONE),
        (0.16, 2.8, M_IRON),
    ):
        add_cylinder_y(bm, 0.0, y, y + h, 0.0, r, r * 0.88 if h > 2.0 else r, mat, sides=8, cap_ends=(h <= 0.5))
        y += h

    return bm


# =============================================================================
# 2. OUTWARD-OPENING DOUBLE DOORS (Hinge Origin at Outer Doorjambs)
# =============================================================================
def build_door_leaf_mesh(side: float) -> tuple:
    """
    side = -1.0 for Chamber_Door_Left (hinge at X = -6.0, Y = 2.45, Z = 17.4)
    side = +1.0 for Chamber_Door_Right (hinge at X = +6.0, Y = 2.45, Z = 17.4)
    All vertices are built relative to `hinge_origin_rbx` so the mesh's
    Object Origin (0,0,0) sits directly on its vertical hinge axis.
    """
    bm = bmesh.new()
    hinge_origin = (side * 6.0, 2.45, 17.4)
    hx = side * 6.0
    z_mid = 17.1
    z_face = 17.45

    def leaf_x(dx: float) -> float:
        return hx - side * dx

    # Continuous vertical arch-topped timber planks (6 planks per 6-stud door leaf)
    num_planks = 6
    plank_w = 6.0 / num_planks
    for p_idx in range(num_planks):
        x_center_mag = (p_idx + 0.5) * plank_w
        arch_h = math.sqrt(max(0.0, 36.0 - x_center_mag * x_center_mag))
        total_h = 9.9 + arch_h
        cy = 2.45 + total_h * 0.5
        add_box(bm, side * x_center_mag, cy, z_mid, plank_w - 0.03, total_h, 0.6, M_TIMBER, origin_rbx=hinge_origin)

    # Outer hinge stile & inner meeting stile
    add_box(bm, side * 5.82, 7.42, z_mid, 0.36, 9.95, 0.72, M_IRON, origin_rbx=hinge_origin)
    add_box(bm, side * 0.18, 10.42, z_mid, 0.36, 15.9, 0.72, M_IRON, origin_rbx=hinge_origin)

    # Curved upper arch rim border following the quarter-circle top edge of this leaf
    arch_segs = 6
    for j in range(arch_segs):
        t0 = (j / float(arch_segs)) * (math.pi * 0.5)
        t1 = ((j + 1) / float(arch_segs)) * (math.pi * 0.5)
        t_mid = (t0 + t1) * 0.5
        r_rim = 5.82
        seg_len = 2.0 * r_rim * math.sin((t1 - t0) * 0.5) + 0.08
        rx = side * math.cos(t_mid) * r_rim
        ry = 12.4 + math.sin(t_mid) * r_rim
        roll = -side * (t_mid + math.pi * 0.5)
        add_box(bm, rx, ry, z_mid, 0.38, seg_len, 0.74, M_IRON, roll_rad=roll, origin_rbx=hinge_origin)

    # Iron hinge straps & waist band
    for y_strap in (4.6, 10.6):
        add_box(bm, leaf_x(1.5), y_strap, z_face, 3.0, 0.45, 0.12, M_IRON, origin_rbx=hinge_origin)
    add_box(bm, leaf_x(3.0), 7.4, z_face, 5.7, 0.35, 0.10, M_IRON, origin_rbx=hinge_origin)

    # Raised circular / crescent molding & pull ring
    rx_roundel = leaf_x(3.0)
    add_disc_z(bm, rx_roundel, 11.2, z_face, 1.4, 0.12, M_TIMBER, sides=12, origin_rbx=hinge_origin)
    add_disc_z(bm, rx_roundel + side * 0.30, 11.3, z_face + 0.04, 0.72, 0.14, M_IRON, sides=10, origin_rbx=hinge_origin)
    add_disc_z(bm, rx_roundel, 11.2, z_face + 0.06, 0.25, 0.18, M_VIOLET, sides=8, origin_rbx=hinge_origin)
    add_disc_z(bm, leaf_x(5.1), 7.0, z_face + 0.06, 0.50, 0.12, M_IRON, sides=10, origin_rbx=hinge_origin)

    return bm, hinge_origin


# =============================================================================
# 3. ACCESSIBLE INTERIOR SANCTUM, PEDESTAL & MAGIC CIRCLE
# =============================================================================
def build_interior_mesh() -> bmesh.types.BMesh:
    bm = bmesh.new()
    fy = 2.45
    wall_h = 19.6
    wall_mid_y = 2.4 + wall_h * 0.5

    # Sanctum floor & inner masonry wall liner
    add_cylinder_y(bm, 0.0, fy - 0.1, fy, 0.0, 15.05, 15.05, M_GALLERY, sides=20)
    for k in range(16):
        a_deg = 11.25 + k * 22.5
        a_rad = math.radians(a_deg)
        if not (math.cos(a_rad) > 0.0 and abs(math.sin(a_rad) * 16.0) < 9.6):
            add_ring_box(bm, a_deg, 15.4, wall_mid_y, 6.0, wall_h, 0.8, M_GALLERY)

    # Two-tier circular gothic colonnade gallery (R = 13.4)
    gr = 13.4
    cap_top = fy + 8.75
    for a_deg in range(45, 316, 45):
        a_rad = math.radians(a_deg)
        cx, cz = math.sin(a_rad) * gr, math.cos(a_rad) * gr
        add_ring_box(bm, a_deg, gr, fy + 0.25, 1.5, 0.5, 1.5, M_GALLERY)
        add_cylinder_y(bm, cx, fy + 0.5, fy + 8.2, cz, 0.6, 0.56, M_GALLERY, sides=6, cap_ends=False)
        add_ring_box(bm, a_deg, gr, cap_top - 0.3, 1.7, 0.6, 1.7, M_GALLERY)
        add_cylinder_y(bm, cx, 15.7, 23.0, cz, 0.45, 0.42, M_GALLERY, sides=6, cap_ends=False)

    for a_deg in range(67, 294, 45):
        add_ring_box(bm, a_deg, 13.8, 15.3, 10.4, 0.8, 2.4, M_GALLERY)
        add_ring_box(bm, a_deg, 12.75, 16.2, 9.6, 1.0, 0.3, M_GALLERY)
        add_ring_box(bm, a_deg, 12.75, 16.82, 9.8, 0.25, 0.5, M_GALLERY)
        # Cyan lower lancet & violet upper lancet stained glass
        add_ring_box(bm, a_deg, 14.95, fy + 4.6, 1.4, 4.4, 0.15, M_CYAN)
        add_ring_box(bm, a_deg, 14.95, 19.0, 1.6, 3.8, 0.15, M_VIOLET)

    # Ceiling frieze, radial ribs & violet oculus
    for k in range(8):
        add_ring_box(bm, k * 45.0 + 22.5, 14.0, 22.6, 10.6, 0.8, 1.8, M_GALLERY)
    for k in range(8):
        add_ring_box(bm, 22.5 + k * 45.0, 8.0, 22.75, 0.6, 0.5, 10.4, M_GALLERY)
    add_cylinder_y(bm, 0.0, 22.6, 23.0, 0.0, 3.0, 3.0, M_GALLERY, sides=12)
    add_cylinder_y(bm, 0.0, 22.5, 22.62, 0.0, 2.3, 2.3, M_VIOLET, sides=12)

    return bm


def build_pedestal_mesh() -> bmesh.types.BMesh:
    bm = bmesh.new()
    fy = 2.45
    add_cylinder_y(bm, 0.0, fy, fy + 0.8, 0.0, 3.2, 3.0, M_STONE, sides=12)
    add_cylinder_y(bm, 0.0, fy + 0.8, fy + 1.3, 0.0, 2.5, 2.4, M_IRON, sides=12)
    ay = fy + 1.3
    add_box(bm, 0.0, ay + 0.25, 0.0, 2.4, 0.5, 1.7, M_IRON)
    add_box(bm, 0.0, ay + 1.05, 0.0, 1.1, 1.1, 1.0, M_IRON)
    add_box(bm, -0.2, ay + 1.95, 0.0, 3.2, 0.7, 1.4, M_IRON)
    add_box(bm, 1.8, ay + 1.95, 0.0, 1.1, 0.5, 0.9, M_IRON)
    add_box(bm, -0.2, ay + 2.32, 0.0, 2.4, 0.06, 0.25, M_CYAN)
    return bm


def build_magic_circle_mesh() -> bmesh.types.BMesh:
    bm = bmesh.new()
    fy = 2.45
    add_cylinder_y(bm, 0.0, fy + 0.02, fy + 0.05, 0.0, 8.0, 8.0, M_CYAN, sides=16)
    add_cylinder_y(bm, 0.0, fy + 0.06, fy + 0.09, 0.0, 7.4, 7.4, M_VIOLET, sides=16)
    add_cylinder_y(bm, 0.0, fy + 0.10, fy + 0.13, 0.0, 5.2, 5.2, M_CYAN, sides=16)
    glyph_y = fy + 0.16
    for k in range(8):
        add_ring_box(bm, k * 45.0 + 22.5, 6.15, glyph_y, 1.1, 0.04, 0.32, M_VIOLET)
        add_ring_box(bm, k * 45.0, 6.15, glyph_y, 0.18, 0.04, 0.9, M_CYAN)
    tri_r = 4.7
    side = tri_r * math.sqrt(3.0)
    for k in range(6):
        add_ring_box(bm, k * 60.0 + 30.0, tri_r * 0.5, glyph_y + 0.01, side, 0.04, 0.18, M_CYAN)
    return bm


# =============================================================================
# 4. SCENE ASSEMBLY & FBX EXPORT
# =============================================================================
def link_bmesh_to_collection(
    name: str,
    bm: bmesh.types.BMesh,
    col: bpy.types.Collection,
    mat_slots: list,
    location_rbx: tuple = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    mesh_data = bpy.data.meshes.new(f"{name}_Mesh")
    bm.to_mesh(mesh_data)
    bm.free()

    obj = bpy.data.objects.new(name, mesh_data)
    obj.location = rbx_to_blender(*location_rbx)
    col.objects.link(obj)

    for mat in mat_slots:
        mesh_data.materials.append(mat)

    for poly in mesh_data.polygons:
        poly.use_smooth = False

    return obj


def create_synthesis_chamber(export_fbx_path: str = None):
    default_cube = bpy.data.objects.get("Cube")
    if default_cube and len(default_cube.data.polygons) == 6:
        bpy.data.objects.remove(default_cube, do_unlink=True)

    if COLLECTION_NAME in bpy.data.collections:
        old_col = bpy.data.collections[COLLECTION_NAME]
        for obj in list(old_col.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old_col)

    chamber_col = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(chamber_col)

    mat_slots = build_materials()

    obj_ext = link_bmesh_to_collection(
        "Chamber_Exterior_StaticMesh", build_exterior_mesh(), chamber_col, mat_slots
    )
    bm_left, loc_left = build_door_leaf_mesh(-1.0)
    obj_door_l = link_bmesh_to_collection(
        "Chamber_Door_Left", bm_left, chamber_col, mat_slots, location_rbx=loc_left
    )
    bm_right, loc_right = build_door_leaf_mesh(1.0)
    obj_door_r = link_bmesh_to_collection(
        "Chamber_Door_Right", bm_right, chamber_col, mat_slots, location_rbx=loc_right
    )
    obj_int = link_bmesh_to_collection(
        "Chamber_Interior_StaticMesh", build_interior_mesh(), chamber_col, mat_slots
    )
    obj_ped = link_bmesh_to_collection(
        "Chamber_Center_Pedestal", build_pedestal_mesh(), chamber_col, mat_slots
    )
    obj_cir = link_bmesh_to_collection(
        "Chamber_MagicCircle_Neon", build_magic_circle_mesh(), chamber_col, mat_slots
    )

    mesh_objs = (obj_ext, obj_door_l, obj_door_r, obj_int, obj_ped, obj_cir)
    for child in (obj_door_l, obj_door_r, obj_int, obj_ped, obj_cir):
        child.parent = obj_ext

    # Empty Attachment Markers (Step 3)
    sockets = {
        "DoorTriggerCenter":     (0.0, 3.0, 18.5),
        "PromptAnchor":          (0.0, 6.2, 0.0),
        "PedestalCoreVFXSocket": (0.0, 7.45, 0.0),
        "RoofSmokeVFXSocket":    (0.0, 35.2, 0.0),
    }
    for s_name, pt_rbx in sockets.items():
        emp = bpy.data.objects.new(s_name, None)
        emp.empty_display_type = "ARROWS"
        emp.empty_display_size = 0.9
        emp.location = rbx_to_blender(*pt_rbx)
        emp.parent = obj_ext
        chamber_col.objects.link(emp)

    total_tris = sum(
        sum(len(p.vertices) - 2 for p in o.data.polygons) for o in mesh_objs
    )
    print(f"Synthesis Chamber procedural geometry generated ({total_tris} tris).")

    if export_fbx_path:
        os.makedirs(os.path.dirname(os.path.abspath(export_fbx_path)), exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        obj_ext.select_set(True)
        for ch in obj_ext.children_recursive:
            ch.select_set(True)
        bpy.context.view_layer.objects.active = obj_ext
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
        print(f"Exported Synthesis Chamber FBX to: {export_fbx_path}")

    return obj_ext, total_tris


if __name__ == "__main__":
    create_synthesis_chamber(
        export_fbx_path=r"C:\WORK\infinite-tower\assets\models\facilities\SynthesisChamber.fbx"
    )
