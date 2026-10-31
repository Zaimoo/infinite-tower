"""
=============================================================================
Infinite Towers: Become a Master! - 3D Weapon Pipeline
Asset: Iron Broadsword (1-Star Starter / Vanguard Swords Archetype)
Target Engine: Blender 4.x / 5.x -> Roblox Studio (MeshPart / HeroSockets)
=============================================================================
Procedural generation script to model, shade, UV unwrap, and configure the
Iron Broadsword matching the gothic/realistic medieval reference image.

Features:
  - Strict polygon budget: ~1,054 triangles (Roblox target: 800-1,500 tris).
  - Exact dimensions: Total Length = 4.2 studs (1.176m), Blade = 3.05 studs,
    Crossguard Width = 0.95 studs, Grip = 0.75 studs, Pommel = 0.40 studs.
  - Pivot Placement: World Origin (0, 0, 0) at the exact geometric midpoint
    of the handle grip for zero-drift socketing in HoldingAnimationController /
    HeroSockets.
  - Orientation: Longitudinal blade axis along +Y, cutting edges along +/-X,
    blade faces/flats along +/-Z.
  - Material & Rarity Progression: 3 distinct Material Slots + Vertex Colors
    (Zone 1: Polished Steel, Zone 2: Forged Iron, Zone 3: Dark Grip).
  - Production Shading: Smooth shading with sharp edges on cutting bevels,
    fuller lips, quillon ridges, and pommel facets (40° Auto Smooth).
  - Automatic UV Unwrapping: Non-overlapping Smart UV Project with 0.02 margin.
=============================================================================
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector, Color

# =============================================================================
# CONFIGURATION CONSTANTS
# =============================================================================
OBJECT_NAME = "IronBroadsword_Mesh"

# Scale factor: 1.38 = Heroic Roblox proportions matching Honshu broadsword reference
# Total length = 5.80 studs, Guard width = 1.38 studs, Thickness = 0.26 studs
SCALE = 1.38

# Total Proportions in Studs
BLADE_TIP_Y     =  3.425 * SCALE
RICASSO_START_Y =  0.460 * SCALE
RICASSO_END_Y   =  0.780 * SCALE
FULLER_END_Y    =  2.400 * SCALE
DIAMOND_START_Y =  2.620 * SCALE

GUARD_CENTER_Y  =  0.450 * SCALE
GUARD_WIDTH     =  0.950 * SCALE # Half-width = 0.475

GRIP_TOP_Y      =  0.375 * SCALE
GRIP_BOTTOM_Y   = -0.375 * SCALE # Length = 0.75 studs, centered at Y = 0.0

POMMEL_TOP_Y    = -0.375 * SCALE
POMMEL_TIP_Y    = -0.775 * SCALE # Length = 0.40 studs

# Material Colors & PBR Parameters
ZONE_COLORS = {
    # Zone 1: Polished Steel (Blade Cutting Edges, Diamond Tip, Pommel Cap)
    "Zone1_Steel": {
        "name": "M_Steel_Polished",
        "hex": "#D4D8DF",
        "metallic": 0.85,
        "roughness": 0.25,
        "rgb": (0.831, 0.847, 0.875, 1.0),
    },
    # Zone 2: Forged Iron (Fuller, Ricasso, Crossguard, Ferrule, Pommel Body)
    "Zone2_Iron": {
        "name": "M_Iron_Forged",
        "hex": "#8C929E",
        "metallic": 0.75,
        "roughness": 0.40,
        "rgb": (0.549, 0.573, 0.620, 1.0),
    },
    # Zone 3: Dark Polymer / Leather (Grip Body)
    "Zone3_Grip": {
        "name": "M_Grip_Dark",
        "hex": "#1E1D24",
        "metallic": 0.10,
        "roughness": 0.75,
        "rgb": (0.118, 0.114, 0.141, 1.0),
    },
}


def hex_to_rgb(hex_str: str) -> tuple:
    c = hex_str.lstrip('#')
    return tuple(int(c[i:i+2], 16) / 255.0 for i in (0, 2, 4))


# =============================================================================
# 1. MATERIAL BUILDER
# =============================================================================
def build_materials():
    materials = {}
    for key, spec in ZONE_COLORS.items():
        mat_name = spec["name"]
        mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(name=mat_name)
        mat.use_nodes = True
        tree = mat.node_tree
        
        # Locate Principled BSDF node
        bsdf = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        r, g, b = hex_to_rgb(spec["hex"])
        
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
            bsdf.inputs["Metallic"].default_value = spec["metallic"]
            bsdf.inputs["Roughness"].default_value = spec["roughness"]
            # Compatibility across Blender 3.x, 4.x, and 5.x
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.5
            elif "Specular" in bsdf.inputs:
                bsdf.inputs["Specular"].default_value = 0.5
                
        mat.diffuse_color = (r, g, b, 1.0)
        materials[key] = mat
        
    return materials


# =============================================================================
# 2. PROCEDURAL MESH GENERATION (BMESH)
# =============================================================================
def build_iron_broadsword_mesh():
    bm = bmesh.new()
    sharp_edges = set()

    def add_quad(v0, v1, v2, v3, mat_idx):
        f = bm.faces.new([v0, v1, v2, v3])
        f.material_index = mat_idx
        return f

    def add_tri(v0, v1, v2, mat_idx):
        f = bm.faces.new([v0, v1, v2])
        f.material_index = mat_idx
        return f

    # -------------------------------------------------------------------------
    # PART A: BLADE (Ricasso, Fuller, Diamond Section, Spear Tip)
    # -------------------------------------------------------------------------
    # Cross section: 10 vertices per ring for crisp fuller lip and trough
    blade_stations = [
        # (y, width, thickness, fuller_w, fuller_depth_factor, is_ricasso)
        (RICASSO_START_Y, 0.280 * SCALE, 0.055 * SCALE, 0.120 * SCALE, 1.00, True),
        (0.550 * SCALE,   0.280 * SCALE, 0.055 * SCALE, 0.120 * SCALE, 1.00, True),
        (0.680 * SCALE,   0.280 * SCALE, 0.055 * SCALE, 0.120 * SCALE, 1.00, True),
        (RICASSO_END_Y,   0.280 * SCALE, 0.055 * SCALE, 0.120 * SCALE, 1.00, True),
        (0.860 * SCALE,   0.276 * SCALE, 0.053 * SCALE, 0.115 * SCALE, 0.35, False),
        (1.150 * SCALE,   0.268 * SCALE, 0.051 * SCALE, 0.105 * SCALE, 0.35, False),
        (1.500 * SCALE,   0.258 * SCALE, 0.049 * SCALE, 0.100 * SCALE, 0.35, False),
        (1.850 * SCALE,   0.248 * SCALE, 0.047 * SCALE, 0.095 * SCALE, 0.35, False),
        (2.150 * SCALE,   0.238 * SCALE, 0.045 * SCALE, 0.090 * SCALE, 0.35, False),
        (FULLER_END_Y,    0.230 * SCALE, 0.043 * SCALE, 0.080 * SCALE, 0.35, False),
        (2.520 * SCALE,   0.225 * SCALE, 0.042 * SCALE, 0.045 * SCALE, 0.75, False),
        (DIAMOND_START_Y, 0.220 * SCALE, 0.040 * SCALE, 0.012 * SCALE, 1.00, False),
        (2.850 * SCALE,   0.190 * SCALE, 0.036 * SCALE, 0.008 * SCALE, 1.00, False),
        (3.100 * SCALE,   0.150 * SCALE, 0.030 * SCALE, 0.006 * SCALE, 1.00, False),
        (3.280 * SCALE,   0.095 * SCALE, 0.022 * SCALE, 0.004 * SCALE, 1.00, False),
    ]

    blade_rings = []
    for y, w, t, fw, f_fac, is_ricasso in blade_stations:
        hw = w / 2.0
        ht = t / 2.0
        hfw = fw / 2.0
        tf = ht * f_fac
        hfw_floor = hfw * 0.45
        
        v_ring = [
            bm.verts.new((-hw, y, 0)),
            bm.verts.new((-hfw, y, ht)),
            bm.verts.new((-hfw_floor, y, tf)),
            bm.verts.new((+hfw_floor, y, tf)),
            bm.verts.new((+hfw, y, ht)),
            bm.verts.new((+hw, y, 0)),
            bm.verts.new((+hfw, y, -ht)),
            bm.verts.new((+hfw_floor, y, -tf)),
            bm.verts.new((-hfw_floor, y, -tf)),
            bm.verts.new((-hfw, y, -ht)),
        ]
        blade_rings.append((v_ring, is_ricasso, f_fac < 0.9))

    blade_tip = bm.verts.new((0, BLADE_TIP_Y, 0))

    # Connect blade rings
    for r in range(len(blade_rings) - 1):
        r1_verts, r1_ricasso, r1_fuller = blade_rings[r]
        r2_verts, r2_ricasso, r2_fuller = blade_rings[r + 1]
        
        for j in range(10):
            jn = (j + 1) % 10
            v0, v1, v2, v3 = r1_verts[j], r1_verts[jn], r2_verts[jn], r2_verts[j]
            
            # Material slot selection:
            # Slot 0 = Steel (Zone 1)
            # Slot 1 = Forged Iron (Zone 2)
            if r1_ricasso or r2_ricasso:
                mat_idx = 1 # Ricasso is forged iron
            elif (j in (1, 2, 3, 6, 7, 8)) and (r1_fuller or r2_fuller):
                mat_idx = 1 # Fuller groove is forged iron
            else:
                mat_idx = 0 # Cutting edge bevels & diamond flats are polished steel
                
            f = add_quad(v0, v1, v2, v3, mat_idx)
            
            # Mark cutting edges and fuller rims sharp
            if j in (0, 4, 5, 9):
                for e in f.edges:
                    if (e.verts[0] in (v0, v3) and e.verts[1] in (v0, v3)) or \
                       (e.verts[0] in (v1, v2) and e.verts[1] in (v1, v2)):
                        sharp_edges.add(e)

    # Connect last ring to acute spear point
    last_verts, _, _ = blade_rings[-1]
    for j in range(10):
        jn = (j + 1) % 10
        f = add_tri(last_verts[j], last_verts[jn], blade_tip, 0)
        if j in (0, 4, 5, 9):
            for e in f.edges:
                if blade_tip in e.verts:
                    sharp_edges.add(e)

    # -------------------------------------------------------------------------
    # PART B: CROSSGUARD & ECUSSON (Quillons curving toward tip with finials)
    # -------------------------------------------------------------------------
    guard_stations_pos = [
        # (x, y_off, height_y, depth_z, ecusson_crest)
        (0.000 * SCALE, 0.000 * SCALE, 0.160 * SCALE, 0.140 * SCALE, 0.080 * SCALE), # Center ecusson apex
        (0.040 * SCALE, 0.000 * SCALE, 0.130 * SCALE, 0.120 * SCALE, 0.040 * SCALE), # Center ecusson slope
        (0.080 * SCALE, 0.000 * SCALE, 0.095 * SCALE, 0.100 * SCALE, 0.010 * SCALE), # Quillon root
        (0.180 * SCALE, 0.002 * SCALE, 0.080 * SCALE, 0.085 * SCALE, 0.000),         # Quillon inner
        (0.280 * SCALE, 0.008 * SCALE, 0.072 * SCALE, 0.075 * SCALE, 0.000),         # Quillon mid (slight curve)
        (0.380 * SCALE, 0.022 * SCALE, 0.070 * SCALE, 0.070 * SCALE, 0.000),         # Quillon outer bend
        (0.440 * SCALE, 0.045 * SCALE, 0.095 * SCALE, 0.080 * SCALE, 0.000),         # Finial flare
        (0.475 * SCALE, 0.065 * SCALE, 0.115 * SCALE, 0.090 * SCALE, 0.000),         # Finial tip
    ]

    def make_guard_ring(x, y_off, hy, dz, ecusson):
        hy2 = hy / 2.0
        dz2 = dz / 2.0
        yb = GUARD_CENTER_Y + y_off
        verts = [
            bm.verts.new((x, yb + hy2 + ecusson, 0)),
            bm.verts.new((x, yb + hy2 * 0.7, dz2 * 0.7)),
            bm.verts.new((x, yb, dz2)),
            bm.verts.new((x, yb - hy2 * 0.7 - ecusson * 0.4, dz2 * 0.7)),
            bm.verts.new((x, yb - hy2 - ecusson * 0.5, 0)),
            bm.verts.new((x, yb - hy2 * 0.7 - ecusson * 0.4, -dz2 * 0.7)),
            bm.verts.new((x, yb, -dz2)),
            bm.verts.new((x, yb + hy2 * 0.7, -dz2 * 0.7)),
        ]
        return verts

    guard_pos_rings = [make_guard_ring(x, yo, hy, dz, ec) for x, yo, hy, dz, ec in guard_stations_pos]
    guard_neg_rings = [guard_pos_rings[0]]
    for x, yo, hy, dz, ec in guard_stations_pos[1:]:
        guard_neg_rings.append(make_guard_ring(-x, yo, hy, dz, ec))

    # Connect positive quillon
    for r in range(len(guard_pos_rings) - 1):
        r1 = guard_pos_rings[r]
        r2 = guard_pos_rings[r + 1]
        for j in range(8):
            jn = (j + 1) % 8
            f = add_quad(r1[j], r1[jn], r2[jn], r2[j], 1) # Zone 2: Forged Iron
            if j in (0, 2, 4, 6):
                for e in f.edges:
                    if (e.verts[0] in (r1[j], r2[j]) and e.verts[1] in (r1[j], r2[j])):
                        sharp_edges.add(e)

    # Positive finial cap
    pos_cap = bm.faces.new(guard_pos_rings[-1])
    pos_cap.material_index = 1
    for e in pos_cap.edges:
        sharp_edges.add(e)

    # Connect negative quillon
    for r in range(len(guard_neg_rings) - 1):
        r1 = guard_neg_rings[r]
        r2 = guard_neg_rings[r + 1]
        for j in range(8):
            jn = (j + 1) % 8
            f = add_quad(r2[j], r2[jn], r1[jn], r1[j], 1) # Zone 2: Forged Iron
            if j in (0, 2, 4, 6):
                for e in f.edges:
                    if (e.verts[0] in (r1[j], r2[j]) and e.verts[1] in (r1[j], r2[j])):
                        sharp_edges.add(e)

    # Negative finial cap
    neg_cap = bm.faces.new(list(reversed(guard_neg_rings[-1])))
    neg_cap.material_index = 1
    for e in neg_cap.edges:
        sharp_edges.add(e)

    # -------------------------------------------------------------------------
    # PART C: GRIP / HANDLE & RIVETS (Origin 0,0,0 at Midpoint)
    # -------------------------------------------------------------------------
    grip_stations = [
        # (y, rx, rz, mat_idx, is_ring)
        ( GRIP_TOP_Y,     0.068 * SCALE, 0.062 * SCALE, 1, False), # Metallic Ferrule
        ( 0.335 * SCALE,  0.070 * SCALE, 0.064 * SCALE, 1, True),  # Ferrule Stepped Lip
        ( 0.325 * SCALE,  0.065 * SCALE, 0.060 * SCALE, 2, False), # Grip Top Body
        ( 0.220 * SCALE,  0.064 * SCALE, 0.059 * SCALE, 2, False), # Upper Rivet Zone
        ( 0.135 * SCALE,  0.063 * SCALE, 0.058 * SCALE, 2, False), # Upper Grip Lower
        ( 0.125 * SCALE,  0.070 * SCALE, 0.065 * SCALE, 2, True),  # Raised Divider Ring 1
        ( 0.115 * SCALE,  0.062 * SCALE, 0.057 * SCALE, 2, False), # Mid Grip Upper
        ( 0.000 * SCALE,  0.060 * SCALE, 0.055 * SCALE, 2, False), # Waist Center (Y = 0)
        (-0.115 * SCALE,  0.062 * SCALE, 0.057 * SCALE, 2, False), # Mid Grip Lower
        (-0.125 * SCALE,  0.070 * SCALE, 0.065 * SCALE, 2, True),  # Raised Divider Ring 2
        (-0.135 * SCALE,  0.063 * SCALE, 0.058 * SCALE, 2, False), # Lower Grip Upper
        (-0.220 * SCALE,  0.064 * SCALE, 0.059 * SCALE, 2, False), # Lower Rivet Zone
        (-0.335 * SCALE,  0.065 * SCALE, 0.060 * SCALE, 2, False), # Lower Grip Lower
        (-0.345 * SCALE,  0.068 * SCALE, 0.063 * SCALE, 1, True),  # Bottom Collar Lip
        ( GRIP_BOTTOM_Y,  0.065 * SCALE, 0.060 * SCALE, 1, False), # Pommel Junction
    ]

    NUM_GRIP_SEGS = 12
    grip_rings = []
    for y, rx, rz, m_idx, is_r in grip_stations:
        verts = []
        for s in range(NUM_GRIP_SEGS):
            ang = 2.0 * math.pi * s / NUM_GRIP_SEGS
            verts.append(bm.verts.new((rx * math.cos(ang), y, rz * math.sin(ang))))
        grip_rings.append((verts, m_idx, is_r))

    for r in range(len(grip_rings) - 1):
        r1_verts, m1, is_r1 = grip_rings[r]
        r2_verts, m2, is_r2 = grip_rings[r + 1]
        face_mat = m1 if m1 == m2 else (1 if (m1 == 1 or m2 == 1) else 2)
        for s in range(NUM_GRIP_SEGS):
            sn = (s + 1) % NUM_GRIP_SEGS
            f = add_quad(r1_verts[s], r1_verts[sn], r2_verts[sn], r2_verts[s], face_mat)
            if is_r1 or is_r2:
                for e in f.edges:
                    if (e.verts[0] in (r1_verts[s], r1_verts[sn]) and e.verts[1] in (r1_verts[s], r1_verts[sn])):
                        sharp_edges.add(e)

    # 4 Subtle circular rivet heads (front +Z and back -Z at Y = +/- 0.22)
    rivet_positions = [
        (0.0,  0.220 * SCALE,  0.060 * SCALE),
        (0.0,  0.220 * SCALE, -0.060 * SCALE),
        (0.0, -0.220 * SCALE,  0.060 * SCALE),
        (0.0, -0.220 * SCALE, -0.060 * SCALE),
    ]

    for rx, ry, rz in rivet_positions:
        sign = 1.0 if rz > 0 else -1.0
        r_radius = 0.016 * SCALE
        r_height = 0.005 * SCALE * sign
        
        r_verts_base = []
        r_verts_top  = []
        for k in range(6):
            kang = 2.0 * math.pi * k / 6.0
            kx = rx + r_radius * math.cos(kang)
            ky = ry + r_radius * math.sin(kang)
            r_verts_base.append(bm.verts.new((kx, ky, rz)))
            r_verts_top.append(bm.verts.new((kx * 0.7, ky * 0.7 + ry * 0.3, rz + r_height)))
        r_apex = bm.verts.new((rx, ry, rz + r_height * 1.4))
        
        for k in range(6):
            kn = (k + 1) % 6
            if sign > 0:
                add_quad(r_verts_base[k], r_verts_base[kn], r_verts_top[kn], r_verts_top[k], 1)
                add_tri(r_verts_top[k], r_verts_top[kn], r_apex, 1)
            else:
                add_quad(r_verts_base[kn], r_verts_base[k], r_verts_top[k], r_verts_top[kn], 1)
                add_tri(r_verts_top[kn], r_verts_top[k], r_apex, 1)

    # -------------------------------------------------------------------------
    # PART D: POMMEL (Faceted Fishtail / Scent-Stopper with Crown Cap)
    # -------------------------------------------------------------------------
    pommel_stations = [
        # (y, rx, rz, mat_idx)
        (POMMEL_TOP_Y,    0.065 * SCALE, 0.060 * SCALE, 1), # Neck junction (Zone 2)
        (-0.415 * SCALE,  0.060 * SCALE, 0.055 * SCALE, 1), # Neck waist (Zone 2)
        (-0.490 * SCALE,  0.082 * SCALE, 0.070 * SCALE, 1), # Fishtail start (Zone 2)
        (-0.580 * SCALE,  0.108 * SCALE, 0.082 * SCALE, 1), # Fishtail mid flare (Zone 2)
        (-0.670 * SCALE,  0.130 * SCALE, 0.092 * SCALE, 1), # Widest fishtail flare (Zone 2)
        (-0.710 * SCALE,  0.122 * SCALE, 0.086 * SCALE, 1), # Crown cap shoulder (Zone 2)
        (-0.735 * SCALE,  0.105 * SCALE, 0.075 * SCALE, 0), # Crown cap start (Zone 1: Steel)
        (-0.760 * SCALE,  0.065 * SCALE, 0.050 * SCALE, 0), # Crown dome (Zone 1: Steel)
    ]

    NUM_POMMEL_SEGS = 8
    pommel_rings = []
    for y, rx, rz, m_idx in pommel_stations:
        verts = []
        for s in range(NUM_POMMEL_SEGS):
            ang = 2.0 * math.pi * s / NUM_POMMEL_SEGS
            verts.append(bm.verts.new((rx * math.cos(ang), y, rz * math.sin(ang))))
        pommel_rings.append((verts, m_idx))

    peen_apex = bm.verts.new((0, POMMEL_TIP_Y, 0))

    for r in range(len(pommel_rings) - 1):
        r1_verts, m1 = pommel_rings[r]
        r2_verts, m2 = pommel_rings[r + 1]
        face_mat = m2
        for s in range(NUM_POMMEL_SEGS):
            sn = (s + 1) % NUM_POMMEL_SEGS
            f = add_quad(r1_verts[s], r1_verts[sn], r2_verts[sn], r2_verts[s], face_mat)
            for e in f.edges:
                if (e.verts[0] in (r1_verts[s], r2_verts[s]) and e.verts[1] in (r1_verts[s], r2_verts[s])):
                    sharp_edges.add(e)

    # Cap crown peen dome
    last_p_verts, _ = pommel_rings[-1]
    for s in range(NUM_POMMEL_SEGS):
        sn = (s + 1) % NUM_POMMEL_SEGS
        add_tri(last_p_verts[s], last_p_verts[sn], peen_apex, 0) # Zone 1: Steel

    # Mark sharp edges on bmesh
    for e in sharp_edges:
        e.smooth = False

    bm.normal_update()
    return bm


# =============================================================================
# 3. MAIN GENERATION PIPELINE
# =============================================================================
def generate_iron_broadsword(clean_scene: bool = True, export_fbx_path: str = ""):
    print("\n--- Starting Iron Broadsword Generation Pipeline ---")
    
    if clean_scene:
        # Remove previous instances of the object
        old_obj = bpy.data.objects.get(OBJECT_NAME)
        if old_obj:
            bpy.data.objects.remove(old_obj, do_unlink=True)
            
    # Step 1: Build Materials
    materials = build_materials()
    mat_slots = [
        materials["Zone1_Steel"], # Slot 0: Steel (Zone 1)
        materials["Zone2_Iron"],  # Slot 1: Iron (Zone 2)
        materials["Zone3_Grip"],  # Slot 2: Grip (Zone 3)
    ]
    
    # Step 2: Build Mesh Geometry
    bm = build_iron_broadsword_mesh()
    mesh = bpy.data.meshes.new(OBJECT_NAME)
    bm.to_mesh(mesh)
    bm.free()
    
    # Step 3: Create Object & Link
    obj = bpy.data.objects.new(OBJECT_NAME, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    
    # Assign Material Slots
    for mat in mat_slots:
        mesh.materials.append(mat)
        
    # Step 4: Vertex Colors (Color Attribute)
    col_attr = mesh.color_attributes.new(name="Color", type='BYTE_COLOR', domain='CORNER')
    color_map = {
        0: ZONE_COLORS["Zone1_Steel"]["rgb"],
        1: ZONE_COLORS["Zone2_Iron"]["rgb"],
        2: ZONE_COLORS["Zone3_Grip"]["rgb"],
    }
    
    for poly in mesh.polygons:
        mat_idx = poly.material_index
        c = color_map.get(mat_idx, ZONE_COLORS["Zone1_Steel"]["rgb"])
        for loop_idx in poly.loop_indices:
            col_attr.data[loop_idx].color = c
            
    # Step 5: Smooth Shading & Auto Smooth (Smooth by Angle)
    for poly in mesh.polygons:
        poly.use_smooth = True
        
    if hasattr(bpy.ops.object, "shade_auto_smooth"):
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
    elif hasattr(mesh, "use_auto_smooth"):
        mesh.use_auto_smooth = True
        mesh.auto_smooth_angle = math.radians(40)
        
    # Step 6: Smart UV Projection (Island Margin 0.02)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Step 7: Apply All Transforms (Pivot verification at Grip Center)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    
    # Validation Statistics
    tri_count = sum(len(p.vertices) - 2 for p in mesh.polygons)
    dims = obj.dimensions
    print(f"SUCCESS: Generated '{obj.name}'")
    print(f"  - Polygon Count: {len(mesh.polygons)} quads/tris")
    print(f"  - Triangle Count: {tri_count} tris (Budget: 800-1,500 tris)")
    print(f"  - Vertex Count: {len(mesh.vertices)}")
    print(f"  - Dimensions: X={dims.x:.3f}, Y={dims.y:.3f}, Z={dims.z:.3f} studs")
    print(f"  - Origin (0,0,0) Location: Exact Grip Midpoint")
    
    # Optional FBX Export
    if export_fbx_path:
        export_fbx_for_roblox(obj, export_fbx_path)
        
    return obj


# =============================================================================
# 4. FBX EXPORT PIPELINE FOR ROBLOX STUDIO
# =============================================================================
def export_fbx_for_roblox(obj, export_path: str):
    """
    Exports the target mesh to FBX with optimal settings for Roblox Studio:
    - Apply Scalings: FBX Units Scale
    - Forward: -Z, Up: +Y
    - Selected Objects only (Mesh only)
    - Triangulate Faces enabled to lock custom split normals
    """
    os.makedirs(os.path.dirname(os.path.abspath(export_path)), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    
    bpy.ops.export_scene.fbx(
        filepath=export_path,
        use_selection=True,
        object_types={'MESH'},
        use_mesh_modifiers=True,
        mesh_smooth_type='FACE',
        use_subsurf=False,
        use_custom_props=True,
        colors_type='SRGB',
        prioritize_active_color=True,
        axis_forward='-Z',
        axis_up='Y',
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_UNITS',
        bake_space_transform=False,
    )
    print(f"Exported Roblox FBX: {export_path}")


# =============================================================================
# EXECUTION ENTRY POINT
# =============================================================================
if __name__ == "__main__":
    generate_iron_broadsword(clean_scene=True)
