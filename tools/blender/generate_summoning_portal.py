"""
=============================================================================
Infinite Towers: Become a Master! - 3D Environment & VFX Pipeline
Asset: Wall-Mounted Gothic Summoning Portal (Corner Citadel Architecture)
References:
  - Closed State: image_88350b.jpg (Ornate winged relief doors, glowing seam)
  - Open Active State: watermarked_img_327187431411185130.jpg / image_883544.jpg
  - In-Game Placement: image_882daa.jpg (Corner castle wall & cyan floor paths)
Target Engine: Blender 4.x / 5.x -> Roblox Studio (MeshPart / PlotFacilities)
=============================================================================
Procedural generation script that builds the wall-mounted Gothic Summoning
Portal as 3 modular sub-mesh groups with hinged doors, 4 material zones,
auto-smooth normals, Smart UV Project unwrapping, and Roblox Attachment sockets.

Coordinate Convention:
  - In Blender: X = Width (+/-X), Y = Depth (-Y is Front toward courtyard,
    +Y is Back toward castle wall), Z = Height (+Z is Up, Z = 0 is floor).
  - Exported to Roblox FBX (axis_up='Y', axis_forward='Z'):
    Roblox X = Blender X
    Roblox Y (Up) = Blender Z
    Roblox Z (Front/+Z) = -Blender Y
  - World Origin (0, 0, 0): Ground-level base center (Y_Roblox = 0 / Z_Blender = 0)
    aligned with the rear wall-contact plane (Z_Roblox = 0 / Y_Blender = 0).

Sub-Mesh Hierarchy:
  1. Portal_Frame_StaticMesh
     - Flush rear corner masonry housing & wall-contact block
     - Two-tier dark-stone stepped pedestal & 3 front approach steps
     - Side & front glowing cyan floor conduit channels
     - Towering peaked Gothic archway (H = 26.5 studs, W = 24.0 studs),
       engaged outer gothic columns, spandrel tracery reliefs, coursed ashlar
       stonework, carved inner arch ribs, runic pilaster tablets, keystone
  2. Portal_Doors_ClosedMesh (Parent container for hinged doors)
     - Portal_Door_Left  (Hinged at X = -5.5, Z_Roblox = +3.6)
     - Portal_Door_Right (Hinged at X = +5.5, Z_Roblox = +3.6)
     - Sculpted multi-tiered seraphim/angelic wing filigree (#2C2538) with
       recessed glowing cyan energy fissures (#22D3EE) and blazing center seam (#00E5FF)
  3. Portal_Active_VortexMesh
     - Light-tight obsidian backing shield (prevents seeing behind castle wall)
     - Logarithmic spiral-twisted energy vortex dish (#00E5FF / #1E88E5)
     - 10 crackling 3D lightning arc ribbons radiating across the opening
=============================================================================
"""

import bpy
import bmesh
import math
import os
import json
from mathutils import Vector, Matrix

# =============================================================================
# 1. DIMENSIONS & ARCHITECTURAL CONSTANTS (1 BLENDER METER = 1 ROBLOX STUD)
# =============================================================================
FRAME_OBJ_NAME       = "Portal_Frame_StaticMesh"
DOORS_GROUP_NAME     = "Portal_Doors_ClosedMesh"
DOOR_LEFT_OBJ_NAME   = "Portal_Door_Left"
DOOR_RIGHT_OBJ_NAME  = "Portal_Door_Right"
VORTEX_OBJ_NAME      = "Portal_Active_VortexMesh"

# Scale Audit Constants (fits 28-stud castle wall & 32-stud merlons cleanly)
TOTAL_WIDTH          = 24.0   # X: -12.0 to +12.0 studs
TOTAL_HEIGHT         = 26.5   # Z_Blender (Y_Roblox): 0.0 to 26.5 studs (below 28-stud wall top)
ARCH_INNER_HALF_W    = 5.5    # Inner archway opening width = 11.0 studs (X: -5.5 to +5.5)
ARCH_OUTER_HALF_W    = 10.6   # Outer gothic pier width = 21.2 studs
ARCH_SPRING_Z        = 13.5   # Height where vertical jambs transition into pointed Gothic arch
ARCH_INNER_APEX_Z    = 21.2   # Inner arch crown height
ARCH_OUTER_APEX_Z    = 24.2   # Outer arch hood-mould crown height
PEDIMENT_APEX_Z      = 26.5   # Top gable peak height
PLINTH_TOP_Z         = 2.0    # Threshold floor height above courtyard ground (Z=0)

# Material Zone Specifications (Step 4)
ZONE_SPECS = {
    "Zone1_SlateWall": {
        "name": "M_Zone1_GothicSlateWall",
        "hex": "#18151D",
        "metallic": 0.10,
        "roughness": 0.85,
        "emission": "#000000",
        "emission_strength": 0.0,
        "rgb": (0.094, 0.082, 0.114, 1.0),
    },
    "Zone2_WingedRelief": {
        "name": "M_Zone2_ObsidianBronzeDoor",
        "hex": "#2C2538",
        "metallic": 0.45,
        "roughness": 0.65,
        "emission": "#000000",
        "emission_strength": 0.0,
        "rgb": (0.173, 0.145, 0.220, 1.0),
    },
    "Zone3_RuneInlay": {
        "name": "M_Zone3_CyanRuneGlow",
        "hex": "#22D3EE",
        "metallic": 0.05,
        "roughness": 0.20,
        "emission": "#1E88E5",
        "emission_strength": 3.8,
        "rgb": (0.133, 0.827, 0.933, 1.0),
    },
    "Zone4_ActiveVortex": {
        "name": "M_Zone4_ElectricVortexNeon",
        "hex": "#00E5FF",
        "metallic": 0.05,
        "roughness": 0.10,
        "emission": "#00E5FF",
        "emission_strength": 6.5,
        "rgb": (0.000, 0.898, 1.000, 1.0),
    },
}


def hex_to_rgb(hex_str: str) -> tuple:
    c = hex_str.lstrip("#")
    return tuple(int(c[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def rbx_to_blender(rx: float, ry: float, rz: float) -> Vector:
    """
    Converts Roblox station-local coordinates:
      rx = Right (+X), ry = Up (+Y), rz = Front (+Z toward courtyard)
    into Blender world coordinates:
      bx = rx (+X), by = -rz (-Y is Front), bz = ry (+Z is Up).
    """
    return Vector((rx, -rz, ry))


def arch_profile_point(t: float, half_w: float, spring_y: float, apex_y: float) -> tuple:
    """
    Returns (x, y_up) in Roblox arch plane for t in [0, 1] from right base (t=0)
    over the pointed Gothic crown (t=0.5) to left base (t=1.0).
    """
    if t <= 0.5:
        u = t * 2.0
        angle = u * (math.pi * 0.5)
        x = half_w * math.pow(math.cos(angle), 0.82)
        y = spring_y + (apex_y - spring_y) * math.pow(math.sin(angle), 0.92)
        return (x, y)
    else:
        u = (1.0 - t) * 2.0
        angle = u * (math.pi * 0.5)
        x = -half_w * math.pow(math.cos(angle), 0.82)
        y = spring_y + (apex_y - spring_y) * math.pow(math.sin(angle), 0.92)
        return (x, y)


# =============================================================================
# 2. PBR & NEON MATERIAL BUILDER
# =============================================================================
def build_materials() -> dict:
    materials = {}
    for key, spec in ZONE_SPECS.items():
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

            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.5
            elif "Specular" in bsdf.inputs:
                bsdf.inputs["Specular"].default_value = 0.5

            if spec["emission_strength"] > 0.0:
                er, eg, eb = hex_to_rgb(spec["emission"])
                if "Emission Color" in bsdf.inputs:
                    bsdf.inputs["Emission Color"].default_value = (er, eg, eb, 1.0)
                elif "Emission" in bsdf.inputs:
                    bsdf.inputs["Emission"].default_value = (er, eg, eb, 1.0)
                if "Emission Strength" in bsdf.inputs:
                    bsdf.inputs["Emission Strength"].default_value = spec["emission_strength"]

        mat.diffuse_color = (r, g, b, 1.0)
        materials[key] = mat
    return materials


# =============================================================================
# 3. GEOMETRY HELPERS (BMESH IN ROBLOX-TO-BLENDER COORDS)
# =============================================================================
def add_box_rbx(
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
):
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    tx = max(0.04, hx - bevel_top)
    tz = max(0.04, hz - bevel_top)

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
    ca, sa = math.cos(yaw_rad), math.sin(yaw_rad)
    verts = []
    for lx, ly, lz in local_pts:
        rx = cx + (lx * ca + lz * sa)
        ry = cy + ly
        rz = cz + (-lx * sa + lz * ca)
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


def add_prism_strip_rbx(
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
    if cap_ends and n == 4:
        try:
            f0 = bm.faces.new((va[0], va[3], va[2], va[1]))
            f0.material_index = mat_idx
            f1 = bm.faces.new((vb[0], vb[1], vb[2], vb[3]))
            f1.material_index = mat_idx
        except ValueError:
            pass


def add_octagonal_column_rbx(
    bm: bmesh.types.BMesh,
    cx: float,
    y_bot: float,
    y_top: float,
    cz: float,
    r_bot: float,
    r_top: float,
    mat_idx: int,
    sides: int = 8,
):
    ring_b = []
    ring_t = []
    for i in range(sides):
        a = (i / float(sides)) * math.pi * 2.0
        ring_b.append((cx + math.cos(a) * r_bot, y_bot, cz + math.sin(a) * r_bot))
        ring_t.append((cx + math.cos(a) * r_top, y_top, cz + math.sin(a) * r_top))
    add_prism_strip_rbx(bm, ring_b, ring_t, mat_idx=mat_idx, cap_ends=False)


# =============================================================================
# 4. SUB-MESH 1: PORTAL_FRAME_STATICMESH (GOTHIC ARCH, REAR HOUSING, PEDESTAL)
# =============================================================================
def build_portal_frame_bmesh() -> bmesh.types.BMesh:
    bm = bmesh.new()

    # -------------------------------------------------------------------------
    # A. STEPPED PEDESTAL PLINTH & FLOOR PATH CONDUITS (Y_rbx = 0.0 to 2.0)
    # -------------------------------------------------------------------------
    add_box_rbx(bm, 0.0, 0.55, 0.4, 24.0, 1.10, 13.8, mat_idx=0, bevel_top=0.25)
    add_box_rbx(bm, 0.0, 1.50, 0.2, 21.6, 1.00, 11.8, mat_idx=0, bevel_top=0.20)

    # 3 Wide Approach Steps facing Courtyard (+Z_rbx = +5.2 to +9.6)
    for step_idx in range(3):
        step_h = 0.62
        cy = (step_idx + 0.5) * step_h
        cz = 8.8 - step_idx * 1.45
        sw = 13.6 - step_idx * 0.6
        add_box_rbx(bm, 0.0, cy, cz, sw, step_h, 1.65, mat_idx=0, bevel_top=0.06)
        add_box_rbx(bm, 0.0, cy + 0.12, cz + 0.84, sw - 1.2, 0.14, 0.08, mat_idx=3)

    # Side Light-Channel Conduits where glowing cyan floor pathways meet the portal base
    for side_sign in (-1.0, 1.0):
        add_box_rbx(bm, side_sign * 8.4, 0.35, 7.4, 2.2, 0.70, 4.2, mat_idx=1, bevel_top=0.10, yaw_rad=side_sign * 0.28)
        add_box_rbx(bm, side_sign * 8.4, 0.72, 7.4, 0.85, 0.14, 4.0, mat_idx=3, yaw_rad=side_sign * 0.28)
        add_box_rbx(bm, side_sign * 7.8, 2.03, 3.8, 0.65, 0.12, 4.8, mat_idx=3)

    # Front Threshold Runic Floor Arc (Zone 4: #00E5FF)
    arc_segs = 12
    for i in range(arc_segs):
        a0 = -0.68 + (i / float(arc_segs)) * 1.36
        a1 = -0.68 + ((i + 1) / float(arc_segs)) * 1.36
        r_in, r_out = 9.8, 10.35
        ring_a = [
            (math.sin(a0) * r_in,  0.02, math.cos(a0) * r_in),
            (math.sin(a0) * r_out, 0.02, math.cos(a0) * r_out),
            (math.sin(a0) * r_out, 0.18, math.cos(a0) * r_out),
            (math.sin(a0) * r_in,  0.18, math.cos(a0) * r_in),
        ]
        ring_b = [
            (math.sin(a1) * r_in,  0.02, math.cos(a1) * r_in),
            (math.sin(a1) * r_out, 0.02, math.cos(a1) * r_out),
            (math.sin(a1) * r_out, 0.18, math.cos(a1) * r_out),
            (math.sin(a1) * r_in,  0.18, math.cos(a1) * r_in),
        ]
        add_prism_strip_rbx(bm, ring_a, ring_b, mat_idx=3, cap_ends=(i == 0 or i == arc_segs - 1))

    # -------------------------------------------------------------------------
    # B. FLUSH CORNER / WALL-HUGGING REAR MASONRY HOUSING (Z_rbx = -6.8 to -2.1)
    # Leaves a deep hollow Gothic vault (Z_rbx = +4.8 down to -1.9) so the doors
    # can swing 78 deg inward without intersecting the back wall or vortex!
    # -------------------------------------------------------------------------
    add_box_rbx(bm, 0.0, 12.25, -3.1, 22.8, 24.5, 2.0, mat_idx=0, bevel_top=0.3)

    w_ring_bot = [
        (-11.0, 0.0, -4.1),
        ( 11.0, 0.0, -4.1),
        (  3.2, 0.0, -7.2),
        ( -3.2, 0.0, -7.2),
    ]
    w_ring_top = [
        (-10.4, 24.0, -4.1),
        ( 10.4, 24.0, -4.1),
        (  2.8, 24.0, -6.8),
        ( -2.8, 24.0, -6.8),
    ]
    add_prism_strip_rbx(bm, w_ring_bot, w_ring_top, mat_idx=0, cap_ends=True)

    # -------------------------------------------------------------------------
    # C. MASSIVE FLANKING GOTHIC PIERS, ENGAGED COLUMNS & ASHLAR MASONRY
    # -------------------------------------------------------------------------
    for side_sign in (-1.0, 1.0):
        pier_cx = side_sign * 8.35
        # Deep side piers extend from Z_rbx = -2.2 to +4.8 to enclose the recessed vault
        add_box_rbx(bm, pier_cx, 13.0, 1.3, 5.5, 22.0, 7.0, mat_idx=0, bevel_top=0.15)
        add_box_rbx(bm, pier_cx, 3.6, 1.6, 6.3, 3.2, 7.4, mat_idx=1, bevel_top=0.25)
        add_box_rbx(bm, pier_cx, 13.6, 1.6, 6.2, 1.1, 7.3, mat_idx=1, bevel_top=0.15)
        add_box_rbx(bm, side_sign * 9.6, 24.4, 1.5, 3.4, 1.4, 7.0, mat_idx=1, bevel_top=0.20)

        # Engaged Outer Gothic Column with Carved Pedestal & Capital (watermarked_img_327187431411185130.jpg)
        col_x = side_sign * 10.65
        col_z = 4.65
        add_box_rbx(bm, col_x, 3.8, col_z, 2.4, 3.6, 2.4, mat_idx=1, bevel_top=0.22)
        add_octagonal_column_rbx(bm, col_x, 5.6, 13.2, col_z, 0.95, 0.88, mat_idx=1, sides=8)
        add_octagonal_column_rbx(bm, col_x, 13.2, 14.3, col_z, 0.88, 1.25, mat_idx=1, sides=8)
        add_octagonal_column_rbx(bm, col_x, 14.3, 23.6, col_z, 0.82, 0.78, mat_idx=1, sides=8)

        # Recessed Vertical Rune Inlay Channel & Carved Glyphs (Zone 3: #22D3EE)
        rune_x = side_sign * 6.45
        add_box_rbx(bm, rune_x, 8.2, 4.65, 0.44, 9.8, 0.25, mat_idx=2)
        for r_idx in range(7):
            ry = 3.6 + r_idx * 1.48
            add_box_rbx(bm, rune_x, ry, 4.74, 0.72, 0.20, 0.30, mat_idx=1)

        # Weathered Coursed Ashlar Stone Relief Blocks along outer pier wall (image_88350b.jpg)
        for course in range(10):
            cy = 3.0 + course * 2.05
            x_shift = 0.35 if (course % 2 == 0) else -0.35
            bx = side_sign * (8.8 + x_shift * 0.45)
            add_box_rbx(bm, bx, cy, 4.60, 2.6, 0.88, 0.45, mat_idx=0, bevel_top=0.08)

        # Spandrel Gothic Tracery Relief above the arch haunches (Y_rbx = 20.5..23.2)
        sp_x = side_sign * 8.2
        add_box_rbx(bm, sp_x, 22.1, 4.78, 3.2, 2.2, 0.35, mat_idx=1, bevel_top=0.15)
        add_box_rbx(bm, sp_x, 22.1, 4.92, 1.4, 1.0, 0.18, mat_idx=2, bevel_top=0.10)

    # -------------------------------------------------------------------------
    # D. POINTED GOTHIC ARCH VOUSSOIRS, RUNE TRIM & APEX KEYSTONE (Y_rbx = 13.5..24.2)
    # -------------------------------------------------------------------------
    arch_steps = 24
    for i in range(arch_steps):
        t0 = i / float(arch_steps)
        t1 = (i + 1) / float(arch_steps)

        ix0, iy0 = arch_profile_point(t0, ARCH_INNER_HALF_W, ARCH_SPRING_Z, ARCH_INNER_APEX_Z)
        ox0, oy0 = arch_profile_point(t0, ARCH_OUTER_HALF_W - 1.2, ARCH_SPRING_Z, ARCH_OUTER_APEX_Z)
        ix1, iy1 = arch_profile_point(t1, ARCH_INNER_HALF_W, ARCH_SPRING_Z, ARCH_INNER_APEX_Z)
        ox1, oy1 = arch_profile_point(t1, ARCH_OUTER_HALF_W - 1.2, ARCH_SPRING_Z, ARCH_OUTER_APEX_Z)

        z_back = -0.4
        z_front = 4.85 + (0.20 if (i % 2 == 0) else 0.0)
        mat_arch = 1 if (i % 2 == 0) else 0

        ring_a = [
            (ix0, iy0, z_back),
            (ox0, oy0, z_back),
            (ox0, oy0, z_front),
            (ix0, iy0, z_front),
        ]
        ring_b = [
            (ix1, iy1, z_back),
            (ox1, oy1, z_back),
            (ox1, oy1, z_front),
            (ix1, iy1, z_front),
        ]
        add_prism_strip_rbx(bm, ring_a, ring_b, mat_idx=mat_arch, cap_ends=False)

        # Inner Glowing Cyan Arch Trim (Zone 3: #22D3EE)
        rx0, ry0 = arch_profile_point(t0, ARCH_INNER_HALF_W + 0.52, ARCH_SPRING_Z, ARCH_INNER_APEX_Z + 0.52)
        rx1, ry1 = arch_profile_point(t1, ARCH_INNER_HALF_W + 0.52, ARCH_SPRING_Z, ARCH_INNER_APEX_Z + 0.52)
        rx0_o, ry0_o = arch_profile_point(t0, ARCH_INNER_HALF_W + 0.92, ARCH_SPRING_Z, ARCH_INNER_APEX_Z + 0.92)
        rx1_o, ry1_o = arch_profile_point(t1, ARCH_INNER_HALF_W + 0.92, ARCH_SPRING_Z, ARCH_INNER_APEX_Z + 0.92)

        rune_a = [
            (rx0,   ry0,   4.55),
            (rx0_o, ry0_o, 4.55),
            (rx0_o, ry0_o, 5.02),
            (rx0,   ry0,   5.02),
        ]
        rune_b = [
            (rx1,   ry1,   4.55),
            (rx1_o, ry1_o, 4.55),
            (rx1_o, ry1_o, 5.02),
            (rx1,   ry1,   5.02),
        ]
        add_prism_strip_rbx(bm, rune_a, rune_b, mat_idx=2, cap_ends=False)

        # Deep Recessed Inner Soffit Ribs & Organic Tendril Moulding (Z_rbx = -2.0..4.5)
        sx0, sy0 = arch_profile_point(t0, ARCH_INNER_HALF_W - 0.18, ARCH_SPRING_Z, ARCH_INNER_APEX_Z - 0.18)
        sx1, sy1 = arch_profile_point(t1, ARCH_INNER_HALF_W - 0.18, ARCH_SPRING_Z, ARCH_INNER_APEX_Z - 0.18)
        soffit_a = [
            (sx0, sy0, -2.0),
            (ix0, iy0, -2.0),
            (ix0, iy0,  4.45),
            (sx0, sy0,  4.45),
        ]
        soffit_b = [
            (sx1, sy1, -2.0),
            (ix1, iy1, -2.0),
            (ix1, iy1,  4.45),
            (sx1, sy1,  4.45),
        ]
        add_prism_strip_rbx(bm, soffit_a, soffit_b, mat_idx=1, cap_ends=False)

    # Monumental Apex Keystone & Glowing Crest Gem at top of Gothic Arch (Y_rbx = 22.8)
    add_box_rbx(bm, 0.0, 22.6, 3.2, 2.8, 3.4, 4.2, mat_idx=1, bevel_top=0.25)
    add_box_rbx(bm, 0.0, 22.5, 5.38, 1.1, 2.1, 0.35, mat_idx=2, bevel_top=0.10)

    # -------------------------------------------------------------------------
    # E. TOP SPANDREL ENTABLATURE & PEAKED GOTHIC PEDIMENT (Y_rbx = 23.5..26.5)
    # -------------------------------------------------------------------------
    add_box_rbx(bm, 0.0, 24.3, 2.4, 22.4, 1.4, 5.2, mat_idx=0, bevel_top=0.18)
    add_box_rbx(bm, 0.0, 24.3, 5.05, 18.0, 0.28, 0.18, mat_idx=2)

    ped_base = [
        (-11.4, 24.9, -0.4),
        ( 11.4, 24.9, -0.4),
        ( 11.4, 24.9,  5.3),
        (-11.4, 24.9,  5.3),
    ]
    ped_peak = [
        (-1.8, PEDIMENT_APEX_Z, -0.2),
        ( 1.8, PEDIMENT_APEX_Z, -0.2),
        ( 1.8, PEDIMENT_APEX_Z,  5.5),
        (-1.8, PEDIMENT_APEX_Z,  5.5),
    ]
    add_prism_strip_rbx(bm, ped_base, ped_peak, mat_idx=1, cap_ends=True)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    return bm


# =============================================================================
# 5. SUB-MESH 2: PORTAL_DOOR_LEFT & PORTAL_DOOR_RIGHT (WINGED RELIEF DOORS)
# =============================================================================
def build_single_door_bmesh(is_left: bool) -> bmesh.types.BMesh:
    """
    Builds one hinged gothic door leaf in local coordinates centered at its
    hinge pivot:
      Left Door Hinge in Roblox world:  (-5.5, 2.0, 3.6)
      Right Door Hinge in Roblox world: (+5.5, 2.0, 3.6)
    Features multi-tiered angelic/seraph wing feathers (image_88350b.jpg)
    radiating across the entire door leaf with recessed cyan energy veins.
    """
    bm = bmesh.new()
    sign = 1.0 if is_left else -1.0  # Direction from outer hinge (0) toward center seam (5.46)
    door_w = ARCH_INNER_HALF_W - 0.04
    thickness = 0.68

    def arch_top_at_u(u_from_hinge: float) -> float:
        wx = (-ARCH_INNER_HALF_W + u_from_hinge * door_w) if is_left else (ARCH_INNER_HALF_W - u_from_hinge * door_w)
        ratio = min(1.0, abs(wx) / ARCH_INNER_HALF_W)
        angle = math.acos(math.pow(ratio, 1.0 / 0.82))
        top_world_y = ARCH_SPRING_Z + (ARCH_INNER_APEX_Z - ARCH_SPRING_Z) * math.pow(math.sin(angle), 0.92)
        return top_world_y - PLINTH_TOP_Z - 0.15

    # 1. Arched Door Slab (8 vertical strips following the pointed Gothic arch profile)
    cols = 8
    for c in range(cols):
        u0 = c / float(cols)
        u1 = (c + 1) / float(cols)
        lx0 = sign * (u0 * door_w)
        lx1 = sign * (u1 * door_w)
        h0 = arch_top_at_u(u0)
        h1 = arch_top_at_u(u1)

        ring_bot = [
            (lx0, 0.0, -thickness * 0.5),
            (lx1, 0.0, -thickness * 0.5),
            (lx1, 0.0,  thickness * 0.5),
            (lx0, 0.0,  thickness * 0.5),
        ]
        ring_top = [
            (lx0, h0, -thickness * 0.5),
            (lx1, h1, -thickness * 0.5),
            (lx1, h1,  thickness * 0.5),
            (lx0, h0,  thickness * 0.5),
        ]
        add_prism_strip_rbx(bm, ring_bot, ring_top, mat_idx=1, cap_ends=True)

    # 2. Glowing Vertical Center Seam Edge & Astragal Moulding (Zone 4: #00E5FF & Zone 3: #22D3EE)
    seam_x = sign * (door_w - 0.06)
    apex_local_h = arch_top_at_u(0.98)
    add_box_rbx(bm, seam_x, apex_local_h * 0.5, 0.0, 0.14, apex_local_h, thickness + 0.16, mat_idx=3)
    add_box_rbx(bm, sign * (door_w - 0.24), apex_local_h * 0.5, 0.36, 0.22, apex_local_h - 0.4, 0.18, mat_idx=2)

    # Outer Hinge-Side Gothic Border Rib & glowing inset groove
    add_box_rbx(bm, sign * 0.32, arch_top_at_u(0.06) * 0.5, 0.36, 0.42, arch_top_at_u(0.06), 0.20, mat_idx=1)
    add_box_rbx(bm, sign * 0.62, arch_top_at_u(0.11) * 0.48, 0.35, 0.14, arch_top_at_u(0.11) * 0.9, 0.14, mat_idx=2)

    # 3. Sculpted Seraphim / Angelic Wing Filigree Relief (image_88350b.jpg)
    # Each feather curves in a 2-segment arc from the central seam spire out across the door leaf
    wing_tiers = [
        # (seam_base_y, seam_span, num_feathers, reach_u_min, reach_u_max, sweep_dy)
        (0.8,  4.2, 6, 0.14, 0.32, 3.2),  # Lower sweeping guardian wing skirt
        (5.2,  5.8, 7, 0.12, 0.26, 4.4),  # Middle grand seraph primary feathers
        (11.2, 4.8, 6, 0.18, 0.42, 3.0),  # Upper arched halo / crown feathers
    ]
    for seam_y0, seam_span, num_f, u_min, u_max, sweep_dy in wing_tiers:
        for f_idx in range(num_f):
            ft = f_idx / float(max(1, num_f - 1))
            # Root near center seam (u ~ 0.90), Midpoint (u ~ 0.52), Tip near hinge (u ~ u_min..u_max)
            u_root = 0.90 - ft * 0.06
            u_mid  = 0.52 - ft * 0.05
            u_tip  = u_min + ft * (u_max - u_min)

            y_root = seam_y0 + ft * seam_span
            y_mid  = min(arch_top_at_u(u_mid) - 0.5, y_root + sweep_dy * 0.58)
            y_tip  = min(arch_top_at_u(u_tip) - 0.5, y_root + sweep_dy * (1.0 - 0.18 * ft))

            pts_u = [u_root, u_mid, u_tip]
            pts_y = [y_root, y_mid, y_tip]

            for seg in range(2):
                x0 = sign * (pts_u[seg] * door_w)
                x1 = sign * (pts_u[seg + 1] * door_w)
                y0 = pts_y[seg]
                y1 = pts_y[seg + 1]
                fw0 = 0.46 if seg == 0 else 0.34
                fw1 = 0.34 if seg == 0 else 0.18

                # Raised Bronze-Obsidian Feather Plate (Zone 2)
                r0 = [
                    (x0, y0,             0.32),
                    (x0, y0 + fw0,       0.32),
                    (x0, y0 + fw0 * 0.8, 0.62),
                    (x0, y0 + 0.06,      0.62),
                ]
                r1 = [
                    (x1, y1,             0.32),
                    (x1, y1 + fw1,       0.32),
                    (x1, y1 + fw1 * 0.8, 0.52),
                    (x1, y1 + 0.04,      0.52),
                ]
                add_prism_strip_rbx(bm, r0, r1, mat_idx=1, cap_ends=(seg == 1))

                # Recessed Cyan Energy Vein glowing between feathers (Zone 3: #22D3EE)
                v0 = [
                    (x0, y0 - 0.11, 0.34),
                    (x0, y0 + 0.03, 0.34),
                    (x0, y0 + 0.03, 0.48),
                    (x0, y0 - 0.11, 0.48),
                ]
                v1 = [
                    (x1, y1 - 0.08, 0.34),
                    (x1, y1 + 0.02, 0.34),
                    (x1, y1 + 0.02, 0.44),
                    (x1, y1 - 0.08, 0.44),
                ]
                add_prism_strip_rbx(bm, v0, v1, mat_idx=2, cap_ends=False)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    return bm


# =============================================================================
# 6. SUB-MESH 3: PORTAL_ACTIVE_VORTEXMESH (SWIRLING VORTEX + BACK SHIELD + ARCS)
# =============================================================================
def build_active_vortex_bmesh() -> bmesh.types.BMesh:
    bm = bmesh.new()

    center_y = 11.4
    vortex_rx = ARCH_INNER_HALF_W + 0.35
    vortex_ry = 9.6

    # 1. Light-Tight Dark Backing Wall Shield (Z_rbx = -2.25, Zone 1: #18151D)
    shield_segs = 24
    shield_center = bm.verts.new(rbx_to_blender(0.0, center_y, -2.25))
    shield_ring = []
    for i in range(shield_segs):
        theta = (i / float(shield_segs)) * math.pi * 2.0
        px = math.cos(theta) * (vortex_rx + 0.8)
        py = max(PLINTH_TOP_Z - 0.2, center_y + math.sin(theta) * (vortex_ry + 0.8))
        shield_ring.append(bm.verts.new(rbx_to_blender(px, py, -2.25)))
    for i in range(shield_segs):
        inext = (i + 1) % shield_segs
        f = bm.faces.new((shield_center, shield_ring[i], shield_ring[inext]))
        f.material_index = 0

    # 2. Logarithmic Spiral-Twisted Vortex Dish (Z_rbx = -1.85 to -1.25, Zone 4 & Zone 3)
    num_rings = 8
    num_radial = 24
    rings = []
    for r_idx in range(num_rings + 1):
        u = r_idx / float(num_rings)
        twist_angle = (1.0 - u) * 3.6
        depth_z = -1.85 + math.sin(u * math.pi) * 0.45
        ring_verts = []
        for s_idx in range(num_radial):
            base_a = (s_idx / float(num_radial)) * math.pi * 2.0 + twist_angle
            rx = math.cos(base_a) * (vortex_rx * u)
            ry = max(PLINTH_TOP_Z, center_y + math.sin(base_a) * (vortex_ry * u))
            ring_verts.append(bm.verts.new(rbx_to_blender(rx, ry, depth_z)))
        rings.append(ring_verts)

    for r_idx in range(num_rings):
        r_in = rings[r_idx]
        r_out = rings[r_idx + 1]
        for s_idx in range(num_radial):
            s_next = (s_idx + 1) % num_radial
            arm_idx = (s_idx + r_idx * 2) % 4
            mat_idx = 3 if (arm_idx in (0, 1) or r_idx == 0) else 2
            try:
                f = bm.faces.new((r_in[s_idx], r_out[s_idx], r_out[s_next], r_in[s_next]))
                f.material_index = mat_idx
            except ValueError:
                pass

    # 3. Crackling 3D Lightning Arc Filaments (10 jagged bolts across the vortex opening, Zone 4)
    num_bolts = 10
    for b_idx in range(num_bolts):
        base_theta = (b_idx / float(num_bolts)) * math.pi * 2.0 + 0.35
        bolt_steps = 5
        for st in range(bolt_steps):
            u0 = (st + 0.3) / float(bolt_steps)
            u1 = (st + 1.3) / float(bolt_steps)
            jag0 = (0.18 if (st % 2 == 0) else -0.18)
            jag1 = (-0.18 if (st % 2 == 0) else 0.18)

            a0 = base_theta + jag0 + (1.0 - u0) * 1.1
            a1 = base_theta + jag1 + (1.0 - u1) * 1.1

            x0 = math.cos(a0) * (vortex_rx * 0.92 * u0)
            y0 = max(PLINTH_TOP_Z + 0.3, center_y + math.sin(a0) * (vortex_ry * 0.92 * u0))
            z0 = -1.15 + u0 * 0.65

            x1 = math.cos(a1) * (vortex_rx * 0.92 * u1)
            y1 = max(PLINTH_TOP_Z + 0.3, center_y + math.sin(a1) * (vortex_ry * 0.92 * u1))
            z1 = -1.15 + u1 * 0.65

            w = 0.11 * (1.15 - 0.5 * u0)
            ring_0 = [
                (x0 - w, y0 - w, z0),
                (x0 + w, y0 - w, z0),
                (x0 + w, y0 + w, z0 + 0.08),
                (x0 - w, y0 + w, z0 + 0.08),
            ]
            ring_1 = [
                (x1 - w, y1 - w, z1),
                (x1 + w, y1 - w, z1),
                (x1 + w, y1 + w, z1 + 0.08),
                (x1 - w, y1 + w, z1 + 0.08),
            ]
            add_prism_strip_rbx(bm, ring_0, ring_1, mat_idx=3, cap_ends=True)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    return bm


# =============================================================================
# 7. OBJECT CREATION, AUTO-SMOOTH, UV UNWRAPPING & SOCKETS
# =============================================================================
def finalize_mesh_object(
    name: str,
    bm: bmesh.types.BMesh,
    mat_slots: list,
    location_blender: Vector = Vector((0.0, 0.0, 0.0)),
    parent_obj=None,
):
    mesh_data = bpy.data.meshes.new(f"{name}_Data")
    bm.to_mesh(mesh_data)
    bm.free()

    obj = bpy.data.objects.new(name, mesh_data)
    obj.location = location_blender
    if parent_obj is not None:
        obj.parent = parent_obj
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    for mat in mat_slots:
        mesh_data.materials.append(mat)

    col_attr = mesh_data.color_attributes.new(name="Color", type="BYTE_COLOR", domain="CORNER")
    color_map = {
        0: ZONE_SPECS["Zone1_SlateWall"]["rgb"],
        1: ZONE_SPECS["Zone2_WingedRelief"]["rgb"],
        2: ZONE_SPECS["Zone3_RuneInlay"]["rgb"],
        3: ZONE_SPECS["Zone4_ActiveVortex"]["rgb"],
    }
    for poly in mesh_data.polygons:
        c = color_map.get(poly.material_index, ZONE_SPECS["Zone1_SlateWall"]["rgb"])
        for loop_idx in poly.loop_indices:
            col_attr.data[loop_idx].color = c
        poly.use_smooth = True

    if hasattr(bpy.ops.object, "shade_auto_smooth"):
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40.0))
    elif hasattr(mesh_data, "use_auto_smooth"):
        mesh_data.use_auto_smooth = True
        mesh_data.auto_smooth_angle = math.radians(40.0)

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    obj.select_set(False)
    return obj


def generate_summoning_portal(clean_scene: bool = True, export_fbx_path: str = None):
    if clean_scene:
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)

    materials = build_materials()
    mat_slots = [
        materials["Zone1_SlateWall"],
        materials["Zone2_WingedRelief"],
        materials["Zone3_RuneInlay"],
        materials["Zone4_ActiveVortex"],
    ]

    # 1. Sub-Mesh 1: Portal_Frame_StaticMesh (Root at World Origin (0,0,0))
    bm_frame = build_portal_frame_bmesh()
    obj_frame = finalize_mesh_object(FRAME_OBJ_NAME, bm_frame, mat_slots, Vector((0.0, 0.0, 0.0)))

    # 2. Sub-Mesh 2: Portal_Doors_ClosedMesh container + Hinged Left/Right Doors
    doors_group = bpy.data.objects.new(DOORS_GROUP_NAME, None)
    doors_group.empty_display_type = "PLAIN_AXES"
    doors_group.empty_display_size = 1.0
    doors_group.location = Vector((0.0, 0.0, 0.0))
    doors_group.parent = obj_frame
    bpy.context.collection.objects.link(doors_group)

    bm_door_l = build_single_door_bmesh(is_left=True)
    obj_door_l = finalize_mesh_object(
        DOOR_LEFT_OBJ_NAME,
        bm_door_l,
        mat_slots,
        rbx_to_blender(-ARCH_INNER_HALF_W, PLINTH_TOP_Z, 3.6),
        parent_obj=doors_group,
    )

    bm_door_r = build_single_door_bmesh(is_left=False)
    obj_door_r = finalize_mesh_object(
        DOOR_RIGHT_OBJ_NAME,
        bm_door_r,
        mat_slots,
        rbx_to_blender(ARCH_INNER_HALF_W, PLINTH_TOP_Z, 3.6),
        parent_obj=doors_group,
    )

    # 3. Sub-Mesh 3: Portal_Active_VortexMesh
    bm_vortex = build_active_vortex_bmesh()
    obj_vortex = finalize_mesh_object(
        VORTEX_OBJ_NAME,
        bm_vortex,
        mat_slots,
        Vector((0.0, 0.0, 0.0)),
        parent_obj=obj_frame,
    )

    # 4. Standard Roblox Attachment Sockets (Step 3)
    sockets_rbx = {
        "CenterVFXSocket":   ((0.0, 11.5, 1.2),  "Center of archway opening for vortex particles, PointLight & god-ray Beams"),
        "SkyBeamBaseSocket": ((0.0,  2.0, 1.2),  "Base of vertical translucent cyan sky-beam column"),
        "SkyBeamTopSocket":  ((0.0, 42.0, 1.2),  "Top of vertical translucent cyan sky-beam column"),
        "WallBackAnchor":    ((0.0, 12.0, 0.0),  "Rear wall-contact plane anchor (zero gap against castle corner wall)"),
        "PromptAnchor":      ((0.0,  2.0, 6.0),  "Front base of steps for [F] Summon Heroes ProximityPrompt"),
    }

    print("\n" + "=" * 78)
    print("ROBLOX STUDIO SOCKET ATTACHMENTS (Station-Local Vector3 Offsets):")
    print("=" * 78)
    for sock_name, (rbx_pt, desc) in sockets_rbx.items():
        empty = bpy.data.objects.new(sock_name, None)
        empty.empty_display_type = "ARROWS"
        empty.empty_display_size = 0.85
        empty.location = rbx_to_blender(*rbx_pt)
        empty.parent = obj_frame
        bpy.context.collection.objects.link(empty)
        print(f"  [{sock_name:<18}]: Vector3.new({rbx_pt[0]:6.2f}, {rbx_pt[1]:6.2f}, {rbx_pt[2]:6.2f}) -- {desc}")
    print("=" * 78)

    def count_tris(o) -> int:
        return sum(len(p.vertices) - 2 for p in o.data.polygons)

    tris_frame  = count_tris(obj_frame)
    tris_door_l = count_tris(obj_door_l)
    tris_door_r = count_tris(obj_door_r)
    tris_vortex = count_tris(obj_vortex)
    total_tris  = tris_frame + tris_door_l + tris_door_r + tris_vortex

    print(f"SUCCESS: Generated Gothic Corner Summoning Portal")
    print(f"  - {FRAME_OBJ_NAME:<26}: {tris_frame:4d} tris")
    print(f"  - {DOOR_LEFT_OBJ_NAME:<26}: {tris_door_l:4d} tris")
    print(f"  - {DOOR_RIGHT_OBJ_NAME:<26}: {tris_door_r:4d} tris")
    print(f"  - {VORTEX_OBJ_NAME:<26}: {tris_vortex:4d} tris")
    print(f"  - TOTAL TRIANGLE COUNT      : {total_tris:4d} tris (Target Budget: 3,500 - 5,000 tris)")
    print("=" * 78 + "\n")

    if export_fbx_path:
        export_portal_fbx(obj_frame, export_fbx_path)

    return obj_frame, doors_group, obj_door_l, obj_door_r, obj_vortex


def set_portal_preview_state(open_angle_deg: float = 0.0, show_vortex: bool = True):
    """
    Helper to preview Closed (0 deg) vs Open/Active (80 deg inward swing) states in Blender.
    In Blender (+X Right, +Y Back/Inward, +Z Up), swinging inward around Z is +rad for Left, -rad for Right.
    """
    door_l = bpy.data.objects.get(DOOR_LEFT_OBJ_NAME)
    door_r = bpy.data.objects.get(DOOR_RIGHT_OBJ_NAME)
    vortex = bpy.data.objects.get(VORTEX_OBJ_NAME)
    rad = math.radians(open_angle_deg)
    if door_l:
        door_l.rotation_euler = (0.0, 0.0, rad)
    if door_r:
        door_r.rotation_euler = (0.0, 0.0, -rad)
    if vortex:
        vortex.hide_viewport = not show_vortex
        vortex.hide_render = not show_vortex


def export_portal_fbx(root_obj, export_path: str):
    os.makedirs(os.path.dirname(os.path.abspath(export_path)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root_obj.select_set(True)
    for child in root_obj.children_recursive:
        child.select_set(True)
    bpy.context.view_layer.objects.active = root_obj

    bpy.ops.export_scene.fbx(
        filepath=export_path,
        use_selection=True,
        object_types={"MESH", "EMPTY"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        use_subsurf=False,
        use_custom_props=True,
        colors_type="SRGB",
        prioritize_active_color=True,
        axis_forward="Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=False,
    )
    print(f"Exported Roblox FBX: {export_path}")


if __name__ == "__main__":
    fbx_out = r"C:\WORK\infinite-tower\assets\models\facilities\summoning_portal_gothic.fbx"
    generate_summoning_portal(clean_scene=True, export_fbx_path=fbx_out)
