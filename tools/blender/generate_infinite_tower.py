"""
=============================================================================
Infinite Towers: Become a Master! - 3D Environment & VFX Pipeline
Asset: Central Gothic Infinite Tower Kit (`CentralTower`)
Reference: Gothic Dark-Stone & Crimson Window Tower (`image_8c0265.jpg`)
Target Engine: Blender 4.x / 5.x -> Roblox Studio (MeshPart / CentralCrimsonTower)
=============================================================================
Procedural Blender Python (`bpy` / `bmesh`) generator that builds the modular,
stackable Central Gothic Tower kit:
  1. Tower_Base_Entrance:
     Heavy dark-stone foundation segment featuring a grand, open pointed
     gothic archway at ground level facing the standard forward vector (-Z in
     Roblox / -Y in Blender) with a flat stone threshold designed to snap
     cleanly to the Hub / Master's Commons arrival bridge.
  2. Tower_Mid_Segment:
     Seamlessly repeatable, non-tapering cylindrical dark-stone segment
     featuring 2 vertical tiers of 12 pointed gothic arched windows (with
     pointed hood moulds, center mullions, and recessed crimson neon panes),
     protruding wrought-iron balconies with spiked finials, and 12 heavy
     vertical gothic buttresses with gargoyle/spike projections.
  3. Cloud_Ring_Bottom:
     Stylized low-poly solid mesh of dense swirling clouds wrapping tightly
     around the lower tower foundation just above the entrance archway.
  4. Cloud_Ring_Top:
     Heavy overhanging stylized storm-cloud mesh sitting at the peak of the
     tower stack to swallow the top into the storm.

Geometry & Origin Rules:
  - Total triangle count across all 4 modules is strictly under 4,500 tris.
  - World Origin (0, 0, 0) is set to the exact bottom-center of both
    `Tower_Base_Entrance` and `Tower_Mid_Segment` so they stack seamlessly
    along the vertical Y-axis in Roblox.
  - Auto-Smooth normals applied at 35 degrees.

Material Zones (4 Slots):
  - Zone 1 (Masonry):        Weathered Dark Slate (#18151D)
  - Zone 2 (Window Emissive): Intense Crimson Glow (#FF2222, Enum.Material.Neon)
  - Zone 3 (Trims/Iron):     Wrought Iron (#111111)
  - Zone 4 (Cloud Meshes):   Dark Storm Grey (#2A2A35)

VFX & Alignment Empty Markers:
  - `Bridge_Snap_Point`: Exact center of `Tower_Base_Entrance` front threshold
  - `VFX_Fog_Base`:      Placed around `Cloud_Ring_Bottom`
  - `VFX_Storm_Peak`:    Placed around `Cloud_Ring_Top`
  - `VFX_Window_Glow`:   Placed inside the gothic window arches
=============================================================================
"""

import bpy
import bmesh
import math
import os
import json
from mathutils import Vector

COLLECTION_NAME = "InfiniteTower_ModularKit"

# =============================================================================
# 1. MODULAR DIMENSIONS (1 BLENDER METER = 1 ROBLOX STUD, STACKABLE ON Y_ROBLOX)
# =============================================================================
# Note: In Roblox, the tower can be used at 1:1 scale or uniformly scaled to match
# the 325-stud radius Hub Ring (`TowerWalkwayRadius = 375`, `TowerHubArrival = -325`).
TOWER_RADIUS        = 32.5   # 65.0m diameter in Blender (scales 10x -> 650 studs in Hub, or 1x modular)
BASE_HEIGHT         = 28.0   # Height of `Tower_Base_Entrance` (Y_rbx: 0.0 -> 28.0)
MID_SEGMENT_HEIGHT  = 36.0   # Height of `Tower_Mid_Segment` (Y_rbx: 0.0 -> 36.0, 2 window stories per segment)
BAY_COUNT           = 12     # 12 gothic bays around circumference; Bay 0 faces -Z_rbx (North / Hub Bridge)

ARCH_HALF_WIDTH     = 7.2    # Grand entrance archway clear width = 14.4m (scales to ~144 studs or 32-stud gate)
ARCH_SPRING_Y       = 11.5   # Arch spring height
ARCH_APEX_Y         = 21.0   # Pointed gothic arch crown height
THRESHOLD_OUTER_Z   = -35.8  # Flat stone threshold front edge facing -Z_rbx (snaps to Hub bridge)

# =============================================================================
# 2. MATERIAL ZONE SPECIFICATIONS (4 ZONES)
# =============================================================================
ZONE_SPECS = [
    {
        "key": "Zone1_Masonry",
        "name": "M_Zone1_DarkSlateMasonry",
        "hex": "#18151D",
        "metallic": 0.10,
        "roughness": 0.86,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    {
        "key": "Zone2_WindowEmissive",
        "name": "M_Zone2_CrimsonWindowNeon",
        "hex": "#FF2222",
        "metallic": 0.0,
        "roughness": 0.12,
        "emission": "#FF2222",
        "emission_strength": 6.0,
    },
    {
        "key": "Zone3_WroughtIron",
        "name": "M_Zone3_WroughtIronTrim",
        "hex": "#111111",
        "metallic": 0.82,
        "roughness": 0.38,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
    {
        "key": "Zone4_StormCloud",
        "name": "M_Zone4_StormCloudGrey",
        "hex": "#2A2A35",
        "metallic": 0.02,
        "roughness": 0.95,
        "emission": "#000000",
        "emission_strength": 0.0,
    },
]


def hex_to_rgb(hex_str: str) -> tuple:
    c = hex_str.lstrip("#")
    return tuple(int(c[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def rbx_to_blender(rx: float, ry_up: float, rz: float) -> Vector:
    """
    Converts Roblox coordinates:
      rx    = Right (+X)
      ry_up = Up (+Y)
      rz    = Back (+Z); Forward vector (-Z in Roblox) maps to Front (-Y in Blender)
    into Blender world coordinates (X Right, Y Back, Z Up):
      bx = rx
      by = rz   (so -Z_rbx = -Y_blender, facing standard front view!)
      bz = ry_up
    """
    return Vector((rx, rz, ry_up))


def build_materials() -> list:
    mats = []
    for spec in ZONE_SPECS:
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
        mats.append(mat)
    return mats


# =============================================================================
# 3. LOW-POLY BMESH GEOMETRY HELPERS (STRICTLY BUDGETED FOR < 4,500 TRIS TOTAL)
# =============================================================================
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
    if cap_ends and n >= 3:
        try:
            f0 = bm.faces.new(tuple(reversed(va)))
            f0.material_index = mat_idx
            f1 = bm.faces.new(tuple(vb))
            f1.material_index = mat_idx
        except ValueError:
            pass


def add_cylinder_ring_rbx(
    bm: bmesh.types.BMesh,
    y_bot: float,
    y_top: float,
    r_bot: float,
    r_top: float,
    mat_idx: int,
    sides: int = 24,
    cap_ends: bool = True,
    cx: float = 0.0,
    cz: float = 0.0,
):
    ring_b = []
    ring_t = []
    for i in range(sides):
        # Angle 0 points along -Z_rbx (North / Hub Bridge)
        a = (i / float(sides)) * math.pi * 2.0
        ring_b.append((cx + math.sin(a) * r_bot, y_bot, cz - math.cos(a) * r_bot))
        ring_t.append((cx + math.sin(a) * r_top, y_top, cz - math.cos(a) * r_top))
    add_prism_strip_rbx(bm, ring_b, ring_t, mat_idx=mat_idx, cap_ends=cap_ends)


def add_oriented_box_rbx(
    bm: bmesh.types.BMesh,
    angle_rad: float,
    radial_dist: float,
    cy: float,
    tangential_w: float,
    height_y: float,
    radial_d: float,
    mat_idx: int,
    taper_top: float = 1.0,
    tangent_offset: float = 0.0,
    cap_ends: bool = True,
):
    """
    Places a box oriented radially around the tower cylinder at `angle_rad`
    (where angle_rad = 0 is -Z_rbx, facing the Hub bridge).
    """
    sa, ca = math.sin(angle_rad), -math.cos(angle_rad)  # Outward radial unit vector (rx, rz)
    tx, tz = math.cos(angle_rad), math.sin(angle_rad)   # Right tangent unit vector

    hw_b = tangential_w * 0.5
    hd_b = radial_d * 0.5
    hw_t = hw_b * taper_top
    hd_t = hd_b * taper_top
    hy = height_y * 0.5

    cx = sa * radial_dist + tx * tangent_offset
    cz = ca * radial_dist + tz * tangent_offset

    def pt(w_off: float, y_off: float, d_off: float) -> tuple:
        return (
            cx + tx * w_off + sa * d_off,
            cy + y_off,
            cz + tz * w_off + ca * d_off,
        )

    ring_bot = [
        pt(-hw_b, -hy, -hd_b),
        pt( hw_b, -hy, -hd_b),
        pt( hw_b, -hy,  hd_b),
        pt(-hw_b, -hy,  hd_b),
    ]
    ring_top = [
        pt(-hw_t,  hy, -hd_t),
        pt( hw_t,  hy, -hd_t),
        pt( hw_t,  hy,  hd_t),
        pt(-hw_t,  hy,  hd_t),
    ]
    add_prism_strip_rbx(bm, ring_bot, ring_top, mat_idx=mat_idx, cap_ends=cap_ends)


def add_gothic_window_bay_rbx(
    bm: bmesh.types.BMesh,
    angle_rad: float,
    wall_radius: float,
    y_sill: float,
    win_w: float,
    win_h: float,
    include_balcony: bool = False,
):
    """
    Builds a single pointed Gothic window bay on the cylindrical wall at `angle_rad`:
      - Pointed 5-sided Gothic stone surround & hood mould (Zone 1: #18151D)
      - Recessed pointed crimson emissive window pane (Zone 2: #FF2222)
      - Wrought-iron vertical center mullion & lancet tracery bar (Zone 3: #111111)
    Triangle cost: ~38 tris per window (all open rear caps omitted against the wall).
    """
    sa, ca = math.sin(angle_rad), -math.cos(angle_rad)
    tx, tz = math.cos(angle_rad), math.sin(angle_rad)

    def rpt(u_tang: float, y_val: float, r_off: float) -> tuple:
        r = wall_radius + r_off
        return (sa * r + tx * u_tang, y_val, ca * r + tz * u_tang)

    hw = win_w * 0.5
    spring_y = y_sill + win_h * 0.64
    apex_y = y_sill + win_h

    # 1. Outer Pointed Gothic Stone Arch Frame Plinth (5-vert pointed pentagon prism, Zone 1 = index 0)
    fw = hw + 0.72
    frame_b = [
        rpt(-fw, y_sill - 0.35, -0.10),
        rpt( fw, y_sill - 0.35, -0.10),
        rpt( fw, spring_y + 0.2, -0.10),
        rpt(0.0, apex_y + 1.05,  -0.10),
        rpt(-fw, spring_y + 0.2, -0.10),
    ]
    frame_f = [
        rpt(-fw, y_sill - 0.35, 0.82),
        rpt( fw, y_sill - 0.35, 0.82),
        rpt( fw, spring_y + 0.2, 0.82),
        rpt(0.0, apex_y + 1.05,  0.95),
        rpt(-fw, spring_y + 0.2, 0.82),
    ]
    add_prism_strip_rbx(bm, frame_b, frame_f, mat_idx=0, cap_ends=False)
    # Front face cap of the pointed stone arch frame
    vf_frame = [bm.verts.new(rbx_to_blender(*p)) for p in frame_f]
    try:
        ff = bm.faces.new(tuple(vf_frame))
        ff.material_index = 0
    except ValueError:
        pass

    # 2. Glowing Crimson Pointed Window Pane (5-vert pointed pentagon, Zone 2 = index 1)
    pw = hw * 0.82
    pane_b = [
        rpt(-pw, y_sill + 0.25, 0.75),
        rpt( pw, y_sill + 0.25, 0.75),
        rpt( pw, spring_y,      0.75),
        rpt(0.0, apex_y - 0.25, 0.75),
        rpt(-pw, spring_y,      0.75),
    ]
    pane_f = [
        rpt(-pw, y_sill + 0.25, 0.98),
        rpt( pw, y_sill + 0.25, 0.98),
        rpt( pw, spring_y,      0.98),
        rpt(0.0, apex_y - 0.25, 1.05),
        rpt(-pw, spring_y,      0.98),
    ]
    add_prism_strip_rbx(bm, pane_b, pane_f, mat_idx=1, cap_ends=False)
    vf_pane = [bm.verts.new(rbx_to_blender(*p)) for p in pane_f]
    try:
        fp = bm.faces.new(tuple(vf_pane))
        fp.material_index = 1
    except ValueError:
        pass

    # 3. Wrought-Iron Center Vertical Mullion & Lancet Transom Bar (Zone 3 = index 2)
    add_oriented_box_rbx(
        bm,
        angle_rad,
        wall_radius + 1.04,
        y_sill + win_h * 0.48,
        0.34,
        win_h * 0.88,
        0.24,
        mat_idx=2,
        cap_ends=False,
    )
    add_oriented_box_rbx(
        bm,
        angle_rad,
        wall_radius + 1.04,
        spring_y - 0.15,
        win_w * 0.78,
        0.30,
        0.22,
        mat_idx=2,
        cap_ends=False,
    )

    # 4. Optional Protruding Wrought-Iron Balcony with Finial Rail (Zone 3 = index 2)
    if include_balcony:
        add_oriented_box_rbx(
            bm,
            angle_rad,
            wall_radius + 1.35,
            y_sill - 0.35,
            win_w + 1.8,
            0.70,
            2.1,
            mat_idx=2,
            taper_top=1.08,
            cap_ends=False,
        )


# =============================================================================
# 4. MODULE 1: `Tower_Base_Entrance` (Origin (0,0,0) at Bottom-Center)
# =============================================================================
def build_tower_base_entrance() -> bmesh.types.BMesh:
    """
    Builds `Tower_Base_Entrance` with origin at (0, 0, 0) bottom-center:
      - Stepped octagonal/24-sided dark-slate foundation plinth (Y: 0 -> 4.0)
      - Flat stone threshold apron extending to -Z_rbx (`THRESHOLD_OUTER_Z`) so it
        snaps seamlessly to the Hub / Master's Commons perimeter bridge
      - Open pointed Gothic entrance archway facing -Z_rbx (Bay 0) with deep
        vaulted passage, flanking buttress towers, wrought-iron portcullis teeth,
        and glowing crimson arch runes
      - 10 upper perimeter gothic windows around the non-gate bays
      - Heavy top cornice & wrought-iron balustrade gallery at Y = BASE_HEIGHT (28.0)
    """
    bm = bmesh.new()

    # 1. Stepped Heavy Stone Foundation Plinth (Y = 0.0 -> 3.6, Zone 1: #18151D)
    add_cylinder_ring_rbx(bm, 0.0, 1.8, TOWER_RADIUS + 2.8, TOWER_RADIUS + 2.2, mat_idx=0, sides=24, cap_ends=True)
    add_cylinder_ring_rbx(bm, 1.8, 3.6, TOWER_RADIUS + 2.0, TOWER_RADIUS + 0.8, mat_idx=0, sides=24, cap_ends=True)

    # 2. Main Cylindrical Dark-Stone Wall Drum (Y = 3.6 -> BASE_HEIGHT = 28.0)
    add_cylinder_ring_rbx(bm, 3.6, BASE_HEIGHT - 2.0, TOWER_RADIUS, TOWER_RADIUS, mat_idx=0, sides=24, cap_ends=True)

    # Top Cornice Ledge & Wrought-Iron Gallery Ring at Y = 26.0 -> 28.0
    add_cylinder_ring_rbx(bm, BASE_HEIGHT - 2.0, BASE_HEIGHT, TOWER_RADIUS + 1.8, TOWER_RADIUS + 2.2, mat_idx=0, sides=24, cap_ends=True)
    add_cylinder_ring_rbx(bm, BASE_HEIGHT, BASE_HEIGHT + 1.3, TOWER_RADIUS + 1.9, TOWER_RADIUS + 1.9, mat_idx=2, sides=24, cap_ends=False)

    # 3. Grand Projecting Gothic Gatehouse Porch & Flat Bridge-Snap Threshold Facing -Z_rbx (Angle 0)
    #    - Drum tangent at angle 0 is Z = -TOWER_RADIUS (-32.5)
    #    - Gatehouse porch projects out to Z = -35.2, and flat stone threshold snaps at THRESHOLD_OUTER_Z (-35.8)
    z_gate_back  = -TOWER_RADIUS + 1.8   # -30.7 (embedded cleanly into drum wall)
    z_gate_front = -TOWER_RADIUS - 2.4   # -34.9 (projecting forward clear of drum curvature!)

    # Flat Stone Threshold Apron (Y = 0.0 -> 2.0, Z = -30.5 -> THRESHOLD_OUTER_Z = -35.8)
    thresh_bot = [
        (-ARCH_HALF_WIDTH - 3.8, 0.0, z_gate_back),
        ( ARCH_HALF_WIDTH + 3.8, 0.0, z_gate_back),
        ( ARCH_HALF_WIDTH + 3.8, 0.0, THRESHOLD_OUTER_Z),
        (-ARCH_HALF_WIDTH - 3.8, 0.0, THRESHOLD_OUTER_Z),
    ]
    thresh_top = [
        (-ARCH_HALF_WIDTH - 3.6, 2.0, z_gate_back),
        ( ARCH_HALF_WIDTH + 3.6, 2.0, z_gate_back),
        ( ARCH_HALF_WIDTH + 3.6, 2.0, THRESHOLD_OUTER_Z),
        (-ARCH_HALF_WIDTH - 3.6, 2.0, THRESHOLD_OUTER_Z),
    ]
    add_prism_strip_rbx(bm, thresh_bot, thresh_top, mat_idx=0, cap_ends=True)

    # Wrought-Iron Curb Trim along Threshold Sides (Zone 3: #111111)
    for sx in (-1.0, 1.0):
        curb_x = sx * (ARCH_HALF_WIDTH + 3.1)
        c_bot = [
            (curb_x - 0.45, 2.0, z_gate_back),
            (curb_x + 0.45, 2.0, z_gate_back),
            (curb_x + 0.45, 2.0, THRESHOLD_OUTER_Z),
            (curb_x - 0.45, 2.0, THRESHOLD_OUTER_Z),
        ]
        c_top = [
            (curb_x - 0.35, 3.3, z_gate_back),
            (curb_x + 0.35, 3.3, z_gate_back),
            (curb_x + 0.35, 3.3, THRESHOLD_OUTER_Z),
            (curb_x - 0.35, 3.3, THRESHOLD_OUTER_Z),
        ]
        add_prism_strip_rbx(bm, c_bot, c_top, mat_idx=2, cap_ends=True)

    # 4. Grand Open Pointed Gothic Entrance Archway & Flanking Buttresses at Bay 0 (-Z_rbx)
    for sx in (-1.0, 1.0):
        px = sx * (ARCH_HALF_WIDTH + 2.2)
        p_bot = [
            (px - 2.2, 2.0, z_gate_back),
            (px + 2.2, 2.0, z_gate_back),
            (px + 1.9, 2.0, z_gate_front - 0.3),
            (px - 1.9, 2.0, z_gate_front - 0.3),
        ]
        p_top = [
            (px - 1.8, ARCH_APEX_Y + 3.8, z_gate_back),
            (px + 1.8, ARCH_APEX_Y + 3.8, z_gate_back),
            (px + 1.5, ARCH_APEX_Y + 3.8, z_gate_front),
            (px - 1.5, ARCH_APEX_Y + 3.8, z_gate_front),
        ]
        add_prism_strip_rbx(bm, p_bot, p_top, mat_idx=0, cap_ends=True)

        # Wrought-Iron Finial Spire atop each Entrance Buttress Pier (Zone 3)
        sp_base = [
            (px - 1.1, ARCH_APEX_Y + 3.8, z_gate_front + 1.8),
            (px + 1.1, ARCH_APEX_Y + 3.8, z_gate_front + 1.8),
            (px + 1.1, ARCH_APEX_Y + 3.8, z_gate_front - 0.2),
            (px - 1.1, ARCH_APEX_Y + 3.8, z_gate_front - 0.2),
        ]
        sp_tip = [
            (px - 0.15, ARCH_APEX_Y + 7.6, z_gate_front + 0.9),
            (px + 0.15, ARCH_APEX_Y + 7.6, z_gate_front + 0.9),
            (px + 0.15, ARCH_APEX_Y + 7.6, z_gate_front + 0.7),
            (px - 0.15, ARCH_APEX_Y + 7.6, z_gate_front + 0.7),
        ]
        add_prism_strip_rbx(bm, sp_base, sp_tip, mat_idx=2, cap_ends=True)

    # Pointed Gothic Arch Voussoirs & Gable Hood over the Entrance (8 segments)
    arch_segs = 8
    for i in range(arch_segs):
        t0 = i / float(arch_segs)
        t1 = (i + 1) / float(arch_segs)

        def gate_arch_pt(t: float, r_w: float, r_apex: float) -> tuple:
            if t <= 0.5:
                u = t * 2.0
                ang = u * (math.pi * 0.5)
                return (r_w * math.cos(ang), ARCH_SPRING_Y + (r_apex - ARCH_SPRING_Y) * math.sin(ang))
            else:
                u = (1.0 - t) * 2.0
                ang = u * (math.pi * 0.5)
                return (-r_w * math.cos(ang), ARCH_SPRING_Y + (r_apex - ARCH_SPRING_Y) * math.sin(ang))

        ix0, iy0 = gate_arch_pt(t0, ARCH_HALF_WIDTH, ARCH_APEX_Y)
        ox0, oy0 = gate_arch_pt(t0, ARCH_HALF_WIDTH + 2.5, ARCH_APEX_Y + 3.4)
        ix1, iy1 = gate_arch_pt(t1, ARCH_HALF_WIDTH, ARCH_APEX_Y)
        ox1, oy1 = gate_arch_pt(t1, ARCH_HALF_WIDTH + 2.5, ARCH_APEX_Y + 3.4)

        va = [(ix0, iy0, z_gate_back), (ox0, oy0, z_gate_back), (ox0, oy0, z_gate_front), (ix0, iy0, z_gate_front)]
        vb = [(ix1, iy1, z_gate_back), (ox1, oy1, z_gate_back), (ox1, oy1, z_gate_front), (ix1, iy1, z_gate_front)]
        add_prism_strip_rbx(bm, va, vb, mat_idx=0, cap_ends=False)

    # Crimson Glowing Portal Sanctuary Plane Recessed Inside the Open Archway (Zone 2: #FF2222)
    # Placed at z_portal = -33.6 (completely in front of the -32.5 cylinder wall so it never clips!)
    z_portal = -TOWER_RADIUS - 1.15
    p_back = [
        (-ARCH_HALF_WIDTH + 0.1, 2.0,           z_portal + 0.8),
        ( ARCH_HALF_WIDTH - 0.1, 2.0,           z_portal + 0.8),
        ( ARCH_HALF_WIDTH - 0.1, ARCH_SPRING_Y, z_portal + 0.8),
        ( 0.0,                   ARCH_APEX_Y,   z_portal + 0.8),
        (-ARCH_HALF_WIDTH + 0.1, ARCH_SPRING_Y, z_portal + 0.8),
    ]
    p_front = [
        (-ARCH_HALF_WIDTH + 0.1, 2.0,           z_portal),
        ( ARCH_HALF_WIDTH - 0.1, 2.0,           z_portal),
        ( ARCH_HALF_WIDTH - 0.1, ARCH_SPRING_Y, z_portal),
        ( 0.0,                   ARCH_APEX_Y,   z_portal),
        (-ARCH_HALF_WIDTH + 0.1, ARCH_SPRING_Y, z_portal),
    ]
    add_prism_strip_rbx(bm, p_back, p_front, mat_idx=1, cap_ends=True)

    # Wrought-Iron Raised Portcullis Bars in the Upper Archway (Zone 3: #111111)
    for bx_i in range(-2, 3):
        bx = bx_i * 2.4
        b_bot = [(bx - 0.22, ARCH_SPRING_Y + 1.5, z_gate_front + 0.7), (bx + 0.22, ARCH_SPRING_Y + 1.5, z_gate_front + 0.7), (bx + 0.22, ARCH_SPRING_Y + 1.5, z_gate_front + 0.2), (bx - 0.22, ARCH_SPRING_Y + 1.5, z_gate_front + 0.2)]
        b_top = [(bx - 0.22, ARCH_APEX_Y - 0.6,   z_gate_front + 0.7), (bx + 0.22, ARCH_APEX_Y - 0.6,   z_gate_front + 0.7), (bx + 0.22, ARCH_APEX_Y - 0.6,   z_gate_front + 0.2), (bx - 0.22, ARCH_APEX_Y - 0.6,   z_gate_front + 0.2)]
        add_prism_strip_rbx(bm, b_bot, b_top, mat_idx=2, cap_ends=True)

    # 5. Perimeter Buttresses (12 ribs) & Gothic Windows on Non-Entrance Bays (Bays 1..11)
    for bay_idx in range(BAY_COUNT):
        bay_angle = (bay_idx / float(BAY_COUNT)) * math.pi * 2.0
        rib_angle = ((bay_idx + 0.5) / float(BAY_COUNT)) * math.pi * 2.0

        # Heavy Vertical Gothic Buttress Pillar between bays
        add_oriented_box_rbx(
            bm,
            rib_angle,
            TOWER_RADIUS + 1.05,
            BASE_HEIGHT * 0.5,
            2.1,
            BASE_HEIGHT - 1.2,
            2.4,
            mat_idx=0,
            taper_top=0.82,
            cap_ends=True,
        )

        # Skip Bay 0 (and immediate edges) where the grand entrance archway stands
        if bay_idx not in (0, 1, 11):
            add_gothic_window_bay_rbx(
                bm,
                bay_angle,
                TOWER_RADIUS,
                y_sill=9.5,
                win_w=5.2,
                win_h=12.5,
                include_balcony=(bay_idx % 2 == 0),
            )

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# =============================================================================
# 5. MODULE 2: `Tower_Mid_Segment` (Origin (0,0,0) at Bottom-Center)
# =============================================================================
def build_tower_mid_segment() -> bmesh.types.BMesh:
    """
    Builds a seamlessly repeatable, non-tapering cylindrical gothic tower
    segment (`Tower_Mid_Segment`, Y: 0.0 -> MID_SEGMENT_HEIGHT = 36.0):
      - Cylindrical dark-slate masonry core (Zone 1: #18151D)
      - 2 vertical stories of 12 pointed gothic crimson windows (24 windows/segment)
        with wrought-iron mullions & pointed hood moulds
      - 12 continuous vertical gothic buttress piers with aggressive gargoyle/spike
        spurs and wrought-iron spire pinnacles on the upper gallery
      - Mid-level stringcourse band and top crenellated wrought-iron balcony ring
    """
    bm = bmesh.new()

    # 1. Non-Tapering Cylindrical Dark-Stone Core (Y = 0.0 -> MID_SEGMENT_HEIGHT = 36.0)
    add_cylinder_ring_rbx(bm, 0.0, MID_SEGMENT_HEIGHT, TOWER_RADIUS, TOWER_RADIUS, mat_idx=0, sides=24, cap_ends=True)

    # Bottom Stringcourse Moulding (Y = 0.0 -> 1.4)
    add_cylinder_ring_rbx(bm, 0.0, 1.4, TOWER_RADIUS + 1.5, TOWER_RADIUS + 1.1, mat_idx=0, sides=24, cap_ends=True)

    # Mid-Story Stone Stringcourse Ledge (Y = 17.2 -> 18.8)
    add_cylinder_ring_rbx(bm, 17.2, 18.8, TOWER_RADIUS + 1.4, TOWER_RADIUS + 1.4, mat_idx=0, sides=24, cap_ends=True)

    # Top Overhanging Cornice Gallery & Wrought-Iron Balustrade Ring (Y = 33.8 -> 36.0)
    add_cylinder_ring_rbx(bm, MID_SEGMENT_HEIGHT - 2.2, MID_SEGMENT_HEIGHT, TOWER_RADIUS + 1.4, TOWER_RADIUS + 2.3, mat_idx=0, sides=24, cap_ends=True)
    add_cylinder_ring_rbx(bm, MID_SEGMENT_HEIGHT - 0.2, MID_SEGMENT_HEIGHT + 1.25, TOWER_RADIUS + 2.0, TOWER_RADIUS + 2.0, mat_idx=2, sides=24, cap_ends=False)

    # 2. 12 Vertical Gothic Buttresses + Spire Pinnacles + 2 Tiers of 12 Pointed Arched Windows
    for bay_idx in range(BAY_COUNT):
        bay_angle = (bay_idx / float(BAY_COUNT)) * math.pi * 2.0
        rib_angle = ((bay_idx + 0.5) / float(BAY_COUNT)) * math.pi * 2.0

        # Full-height Gothic Buttress Rib (Zone 1: #18151D)
        add_oriented_box_rbx(
            bm,
            rib_angle,
            TOWER_RADIUS + 1.1,
            MID_SEGMENT_HEIGHT * 0.5,
            1.95,
            MID_SEGMENT_HEIGHT,
            2.3,
            mat_idx=0,
            cap_ends=False,
        )

        # Wrought-Iron Buttress Pinnacle & Gargoyle Spur at Top Gallery (Zone 3: #111111)
        add_oriented_box_rbx(
            bm,
            rib_angle,
            TOWER_RADIUS + 2.35,
            MID_SEGMENT_HEIGHT + 1.6,
            1.15,
            4.2,
            1.15,
            mat_idx=2,
            taper_top=0.15,
            cap_ends=True,
        )
        # Outward-jutting Gothic Spur / Gargoyle Finial at Mid & Top Ledges
        for spur_y in (18.0, MID_SEGMENT_HEIGHT - 1.0):
            add_oriented_box_rbx(
                bm,
                rib_angle,
                TOWER_RADIUS + 2.8,
                spur_y,
                0.75,
                1.35,
                2.4,
                mat_idx=2,
                taper_top=0.25,
                cap_ends=True,
            )

        # Lower Tier Pointed Gothic Window (Y_sill = 2.8, Height = 12.6)
        add_gothic_window_bay_rbx(
            bm,
            bay_angle,
            TOWER_RADIUS,
            y_sill=2.8,
            win_w=5.0,
            win_h=12.6,
            include_balcony=(bay_idx % 3 == 0),
        )

        # Upper Tier Pointed Gothic Window (Y_sill = 20.0, Height = 12.6)
        add_gothic_window_bay_rbx(
            bm,
            bay_angle,
            TOWER_RADIUS,
            y_sill=20.0,
            win_w=5.0,
            win_h=12.6,
            include_balcony=((bay_idx + 1) % 3 == 0),
        )

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# =============================================================================
# 6. MODULES 3 & 4: `Cloud_Ring_Bottom` & `Cloud_Ring_Top` (Zone 4: #2A2A35)
# =============================================================================
def add_stylized_cloud_lobe_rbx(
    bm: bmesh.types.BMesh,
    cx: float,
    cy: float,
    cz: float,
    rx: float,
    ry: float,
    rz: float,
    mat_idx: int = 3,
    lon_segs: int = 10,
    lat_rings: int = 4,
):
    """
    Creates a faceted low-poly billowy cloud lobe (80 tris per lobe at 10x4)
    with a gently flattened underside and puffed upper crown.
    """
    rings = []
    bot_pole = bm.verts.new(rbx_to_blender(cx, cy - ry * 0.78, cz))
    top_pole = bm.verts.new(rbx_to_blender(cx, cy + ry, cz))

    for r_i in range(1, lat_rings):
        v = r_i / float(lat_rings)
        phi = (v - 0.5) * math.pi
        c_phi = math.cos(phi)
        s_phi = math.sin(phi)
        y_scale = 0.78 if s_phi < 0 else 1.0
        ring_v = []
        for s_i in range(lon_segs):
            theta = (s_i / float(lon_segs)) * math.pi * 2.0
            # Subtle organic puff modulation
            puff = 1.0 + 0.08 * math.sin(theta * 3.0 + phi * 2.0)
            px = cx + math.cos(theta) * c_phi * rx * puff
            py = cy + s_phi * ry * y_scale
            pz = cz + math.sin(theta) * c_phi * rz * puff
            ring_v.append(bm.verts.new(rbx_to_blender(px, py, pz)))
        rings.append(ring_v)

    # Bottom cap fan
    first_ring = rings[0]
    for s_i in range(lon_segs):
        s_next = (s_i + 1) % lon_segs
        try:
            f = bm.faces.new((bot_pole, first_ring[s_next], first_ring[s_i]))
            f.material_index = mat_idx
        except ValueError:
            pass

    # Middle quad bands
    for r_i in range(len(rings) - 1):
        r0 = rings[r_i]
        r1 = rings[r_i + 1]
        for s_i in range(lon_segs):
            s_next = (s_i + 1) % lon_segs
            try:
                f = bm.faces.new((r0[s_i], r0[s_next], r1[s_next], r1[s_i]))
                f.material_index = mat_idx
            except ValueError:
                pass

    # Top cap fan
    last_ring = rings[-1]
    for s_i in range(lon_segs):
        s_next = (s_i + 1) % lon_segs
        try:
            f = bm.faces.new((top_pole, last_ring[s_i], last_ring[s_next]))
            f.material_index = mat_idx
        except ValueError:
            pass


def build_cloud_ring_bottom() -> bmesh.types.BMesh:
    """
    Builds `Cloud_Ring_Bottom`: a dense, swirling ring of stylized low-poly
    clouds that tightly wraps `Tower_Base_Entrance` just above the entrance
    archway while leaving Bay 0 (-Z_rbx) parted so the grand gothic gatehouse
    remains dramatic and unobstructed.
    Origin is at (0, 0, 0) bottom-center of its cloud band.
    """
    bm = bmesh.new()
    lobe_count = 12
    for i in range(lobe_count):
        ang = (i / float(lobe_count)) * math.pi * 2.0
        # Part above angle 0 (-Z_rbx) so the gatehouse gable & arch are framed, not obscured
        is_front_gate = (i == 0 or i == 1 or i == lobe_count - 1)
        r_dist = TOWER_RADIUS + (5.2 if is_front_gate else 2.2) + (i % 2) * 3.0
        y_off = (13.5 if i == 0 else (9.5 if is_front_gate else 5.0)) + (i % 3) * 2.2
        rx = (10.0 if i == 0 else 12.5) + (i % 3) * 2.4
        ry = (4.8 if i == 0 else 6.5) + (i % 2) * 1.8
        rz = (9.5 if i == 0 else 12.5) + ((i + 1) % 3) * 2.4

        cx = math.sin(ang) * r_dist
        cz = -math.cos(ang) * r_dist
        add_stylized_cloud_lobe_rbx(bm, cx, y_off, cz, rx, ry, rz, mat_idx=3, lon_segs=8, lat_rings=3)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def build_cloud_ring_top() -> bmesh.types.BMesh:
    """
    Builds `Cloud_Ring_Top`: a massive, overhanging stylized storm-cloud
    canopy designed to sit at the absolute peak of the tower stack, completely
    swallowing the top of the tower into the dark storm clouds (matching
    `image_8c0265.jpg`).
    Origin is at (0, 0, 0) bottom-center of the storm cloud mass.
    """
    bm = bmesh.new()
    # 1. Central Swallowing Storm Core Cap
    add_stylized_cloud_lobe_rbx(bm, 0.0, 12.0, 0.0, TOWER_RADIUS * 1.48, 11.5, TOWER_RADIUS * 1.48, mat_idx=3, lon_segs=10, lat_rings=3)

    # 2. Inner Billowing Overhang Ring (8 large storm lobes)
    for i in range(8):
        ang = (i / float(8)) * math.pi * 2.0
        r_dist = TOWER_RADIUS * 1.05 + (i % 2) * 4.0
        y_off = 8.0 + (i % 3) * 2.8
        lobe_r = 17.5 + (i % 3) * 2.5
        lobe_h = 9.5 + (i % 2) * 2.2
        cx = math.sin(ang) * r_dist
        cz = -math.cos(ang) * r_dist
        add_stylized_cloud_lobe_rbx(bm, cx, y_off, cz, lobe_r, lobe_h, lobe_r, mat_idx=3, lon_segs=8, lat_rings=3)

    # 3. Outer Swirling Storm Anvil Ring (8 wide overhanging cloud masses)
    for i in range(8):
        ang = ((i + 0.5) / float(8)) * math.pi * 2.0
        r_dist = TOWER_RADIUS * 1.42 + (i % 2) * 3.5
        y_off = 13.5 + (i % 2) * 3.0
        lobe_r = 19.5 + (i % 2) * 3.0
        lobe_h = 10.8
        cx = math.sin(ang) * r_dist
        cz = -math.cos(ang) * r_dist
        add_stylized_cloud_lobe_rbx(bm, cx, y_off, cz, lobe_r, lobe_h, lobe_r, mat_idx=3, lon_segs=8, lat_rings=3)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


# =============================================================================
# 7. SCENE ASSEMBLY, SHADE AUTO SMOOTH (35 DEG), EMPTY MARKERS & EXPORT
# =============================================================================
def create_mesh_object(
    name: str,
    bm: bmesh.types.BMesh,
    collection: bpy.types.Collection,
    mat_slots: list,
    location_rbx: tuple = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    mesh_data = bpy.data.meshes.new(f"{name}_Mesh")
    bm.to_mesh(mesh_data)
    bm.free()

    obj = bpy.data.objects.new(name, mesh_data)
    obj.location = rbx_to_blender(*location_rbx)
    collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    for mat in mat_slots:
        mesh_data.materials.append(mat)

    for poly in mesh_data.polygons:
        poly.use_smooth = True

    # Apply Shade Auto Smooth (35 degrees) compatible with Blender 4.x and 5.x
    if hasattr(bpy.ops.object, "shade_auto_smooth"):
        try:
            bpy.ops.object.shade_auto_smooth(angle=math.radians(35.0))
        except Exception:
            pass
    elif hasattr(mesh_data, "use_auto_smooth"):
        mesh_data.use_auto_smooth = True
        mesh_data.auto_smooth_angle = math.radians(35.0)

    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    obj.select_set(False)
    return obj


def create_empty_socket(
    name: str,
    location_rbx: tuple,
    parent_obj: bpy.types.Object,
    collection: bpy.types.Collection,
    display_size: float = 2.0,
) -> bpy.types.Object:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_type = "ARROWS"
    empty.empty_display_size = display_size
    world_vec = rbx_to_blender(*location_rbx)
    if parent_obj is not None:
        empty.parent = parent_obj
        empty.location = world_vec - parent_obj.location
    else:
        empty.location = world_vec
    collection.objects.link(empty)
    return empty


def generate_infinite_tower(
    clean_scene: bool = True,
    preview_stack_count: int = 3,
    export_dir: str = None,
) -> dict:
    if clean_scene:
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)

    if COLLECTION_NAME in bpy.data.collections:
        old_col = bpy.data.collections[COLLECTION_NAME]
        for obj in list(old_col.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old_col)

    tower_col = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(tower_col)

    mat_slots = build_materials()

    # -------------------------------------------------------------------------
    # Build the 4 Modular Assets with Origin (0,0,0) at Bottom-Center of Base & Mid
    # -------------------------------------------------------------------------
    obj_base = create_mesh_object(
        "Tower_Base_Entrance",
        build_tower_base_entrance(),
        tower_col,
        mat_slots,
        location_rbx=(0.0, 0.0, 0.0),
    )

    obj_mid = create_mesh_object(
        "Tower_Mid_Segment",
        build_tower_mid_segment(),
        tower_col,
        mat_slots,
        location_rbx=(0.0, 0.0, 0.0),
    )

    # Position `Cloud_Ring_Bottom` wrapping `Tower_Base_Entrance` just above the archway (Y = 18.0)
    obj_cloud_bot = create_mesh_object(
        "Cloud_Ring_Bottom",
        build_cloud_ring_bottom(),
        tower_col,
        mat_slots,
        location_rbx=(0.0, 18.0, 0.0),
    )

    # Position `Cloud_Ring_Top` at the peak of the stacked preview column
    top_cloud_y = BASE_HEIGHT + max(1, preview_stack_count) * MID_SEGMENT_HEIGHT - 8.0
    obj_cloud_top = create_mesh_object(
        "Cloud_Ring_Top",
        build_cloud_ring_top(),
        tower_col,
        mat_slots,
        location_rbx=(0.0, top_cloud_y, 0.0),
    )

    # Create Linked Preview Instances of `Tower_Mid_Segment` so the Blender viewport
    # shows the full towering gothic spire from `image_8c0265.jpg` while keeping
    # `Tower_Mid_Segment` itself at World Origin (0,0,0) for clean Roblox export!
    preview_instances = []
    for s_idx in range(preview_stack_count):
        stack_y = BASE_HEIGHT + s_idx * MID_SEGMENT_HEIGHT
        inst = bpy.data.objects.new(f"Tower_Mid_PreviewStack_{s_idx + 1:02d}", obj_mid.data)
        inst.location = rbx_to_blender(0.0, stack_y, 0.0)
        tower_col.objects.link(inst)
        preview_instances.append(inst)

    # -------------------------------------------------------------------------
    # STEP 2: VFX & ALIGNMENT EMPTY MARKERS
    # -------------------------------------------------------------------------
    # 1. `Bridge_Snap_Point`: Exact center of `Tower_Base_Entrance` threshold (-Z_rbx)
    create_empty_socket(
        "Bridge_Snap_Point",
        (0.0, 0.0, THRESHOLD_OUTER_Z),
        obj_base,
        tower_col,
        display_size=3.5,
    )

    # 2. `VFX_Fog_Base`: Placed around the bottom cloud mesh
    create_empty_socket(
        "VFX_Fog_Base",
        (0.0, 22.0, 0.0),
        obj_cloud_bot,
        tower_col,
        display_size=4.0,
    )
    for idx in range(4):
        ang = (idx / 4.0) * math.pi * 2.0
        r = TOWER_RADIUS + 4.0
        create_empty_socket(
            f"VFX_Fog_Base_{idx + 1}",
            (math.sin(ang) * r, 22.0, -math.cos(ang) * r),
            obj_cloud_bot,
            tower_col,
            display_size=2.5,
        )

    # 3. `VFX_Storm_Peak`: Placed around the upper cloud mesh
    create_empty_socket(
        "VFX_Storm_Peak",
        (0.0, top_cloud_y + 10.0, 0.0),
        obj_cloud_top,
        tower_col,
        display_size=4.5,
    )
    for idx in range(4):
        ang = (idx / 4.0) * math.pi * 2.0
        r = TOWER_RADIUS + 8.0
        create_empty_socket(
            f"VFX_Storm_Peak_{idx + 1}",
            (math.sin(ang) * r, top_cloud_y + 10.0, -math.cos(ang) * r),
            obj_cloud_top,
            tower_col,
            display_size=2.8,
        )

    # 4. `VFX_Window_Glow`: Placed inside the gothic window arches of `Tower_Mid_Segment`
    create_empty_socket(
        "VFX_Window_Glow",
        (0.0, 9.0, -(TOWER_RADIUS + 0.4)),
        obj_mid,
        tower_col,
        display_size=2.0,
    )
    for bay_idx in range(0, BAY_COUNT, 2):
        ang = (bay_idx / float(BAY_COUNT)) * math.pi * 2.0
        r = TOWER_RADIUS + 0.4
        create_empty_socket(
            f"VFX_Window_Glow_Lower_{bay_idx:02d}",
            (math.sin(ang) * r, 9.0, -math.cos(ang) * r),
            obj_mid,
            tower_col,
            display_size=1.6,
        )
        create_empty_socket(
            f"VFX_Window_Glow_Upper_{bay_idx:02d}",
            (math.sin(ang) * r, 26.2, -math.cos(ang) * r),
            obj_mid,
            tower_col,
            display_size=1.6,
        )

    # -------------------------------------------------------------------------
    # TRIANGLE BUDGET AUDIT (Must be strictly < 4,500 tris across all 4 modules)
    # -------------------------------------------------------------------------
    def count_tris(o: bpy.types.Object) -> int:
        return sum(len(p.vertices) - 2 for p in o.data.polygons)

    tris_base      = count_tris(obj_base)
    tris_mid       = count_tris(obj_mid)
    tris_cloud_bot = count_tris(obj_cloud_bot)
    tris_cloud_top = count_tris(obj_cloud_top)
    total_kit_tris = tris_base + tris_mid + tris_cloud_bot + tris_cloud_top

    assert total_kit_tris < 4500, f"Polygon budget exceeded: {total_kit_tris} >= 4500 tris!"

    summary = {
        "Tower_Base_Entrance": tris_base,
        "Tower_Mid_Segment": tris_mid,
        "Cloud_Ring_Bottom": tris_cloud_bot,
        "Cloud_Ring_Top": tris_cloud_top,
        "Total_Kit_Triangles": total_kit_tris,
        "Budget_Limit": 4500,
        "Bridge_Snap_Point_Rbx": [0.0, 0.0, THRESHOLD_OUTER_Z],
        "Base_Height_Rbx": BASE_HEIGHT,
        "Mid_Segment_Height_Rbx": MID_SEGMENT_HEIGHT,
        "Tower_Radius_Rbx": TOWER_RADIUS,
    }

    print("\n" + "=" * 78)
    print("CENTRAL GOTHIC INFINITE TOWER KIT - GENERATION SUMMARY")
    print("=" * 78)
    for k, v in summary.items():
        print(f"  {k:<28}: {v}")
    print("=" * 78 + "\n")

    # -------------------------------------------------------------------------
    # EXPORT FBX FILES FOR ROBLOX STUDIO IMPORT
    # -------------------------------------------------------------------------
    if export_dir:
        os.makedirs(export_dir, exist_ok=True)
        modules = [obj_base, obj_mid, obj_cloud_bot, obj_cloud_top]

        # Temporarily place Cloud_Ring_Bottom and Cloud_Ring_Top at Y=0 for standalone FBX export, then restore
        saved_locs = {m.name: m.location.copy() for m in modules}

        # 1. Combined Modular Kit FBX (the 4 core modules + sockets, excluding preview duplicates)
        bpy.ops.object.select_all(action="DESELECT")
        for m in modules:
            m.select_set(True)
            for ch in m.children_recursive:
                ch.select_set(True)
        bpy.context.view_layer.objects.active = obj_base

        combined_fbx = os.path.join(export_dir, "CentralGothicTower_Kit.fbx")
        bpy.ops.export_scene.fbx(
            filepath=combined_fbx,
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

        # 2. Individual Module FBXs with (0,0,0) bottom-center origins
        for m in modules:
            bpy.ops.object.select_all(action="DESELECT")
            m.location = Vector((0.0, 0.0, 0.0))
            m.select_set(True)
            for ch in m.children_recursive:
                ch.select_set(True)
            bpy.context.view_layer.objects.active = m
            mod_fbx = os.path.join(export_dir, f"{m.name}.fbx")
            bpy.ops.export_scene.fbx(
                filepath=mod_fbx,
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
            m.location = saved_locs[m.name]

        # Keep the canonical `Tower_Mid_Segment` at World Origin (0,0,0) for export,
        # and hide it in the viewport so only the stacked segments above `Tower_Base_Entrance`
        # are visible when inspecting the assembled tower in Blender!
        obj_mid.hide_viewport = True
        with open(os.path.join(export_dir, "CentralGothicTower_Metadata.json"), "w", encoding="utf-8") as f:
            json.dump(summary, f, indent=2)

    return summary


if __name__ == "__main__":
    out_folder = r"C:\WORK\infinite-tower\assets\models\central_tower"
    generate_infinite_tower(clean_scene=True, preview_stack_count=3, export_dir=out_folder)
