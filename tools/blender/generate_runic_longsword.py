"""
=============================================================================
Infinite Towers: Become a Master! - 3D Weapon Pipeline
Asset: Runic Longsword (2-Star Base / Vanguard Swords Archetype)
Reference: media_1793467570611_e9eed503.png
Target Engine: Blender 4.x / 5.x -> Roblox Studio (MeshPart / HeroSockets)
=============================================================================
Procedural generation script to model, shade, UV unwrap, and configure the
Runic Longsword and its secondary Aura Mesh matching the frosty, ancient Norse
runic longsword reference image.

Features:
  - Heroic Proportions & Budget: ~1,350 - 1,550 triangles (Roblox target: 1,000-1,800).
  - Exact dimensions:
      Total Length = 4.75 studs (1.33m)
      Blade Length = 3.40 studs (Y = 0.70 to 4.10)
      Crossguard Span = 1.34 studs (X = -0.67 to +0.67)
      Handle Grip Length = 0.80 studs (Y = -0.40 to +0.40)
      Pommel Length = 0.45 studs (Y = -0.40 to -0.85)
  - Pivot Placement: World Origin (0, 0, 0) at the exact geometric midpoint
    of the handle grip for zero-drift socketing in HoldingAnimationController /
    HeroSockets.
  - Orientation: Longitudinal blade axis along +Y, cutting edges along +/-X,
    blade faces/flats along +/-Z.
  - 4-Zone Material Split:
      Zone 1: Frosted Steel (Polished icy cutting edge and diamond tip)
      Zone 2: Forged Dark Iron (Gothic star crossguard, quillons, pommel cage)
      Zone 3: Obsidian Grip (Matte fluted leather/polymer wrap)
      Zone 4: Runic Neon Core (Recessed fuller channel, star gem, pommel core)
  - Standardized Attachments:
      GripAttachment (0, 0, 0)
      TrailBottom (0, 0.75, 0)
      TrailTop (0, 4.10, 0)
      VFXCore (0, 2.40, 0)
=============================================================================
"""

import bpy
import bmesh
import math
import os
import json
from mathutils import Vector, Matrix

# =============================================================================
# CONFIGURATION CONSTANTS (ROBLOX STUD SCALE)
# =============================================================================
SWORD_OBJ_NAME = "RunicLongsword_Mesh"
AURA_OBJ_NAME  = "RunicLongsword_AuraMesh"

GRIP_HALF_LEN   = 0.40  # Grip from Y = -0.40 to +0.40 (0.80 studs)
GRIP_RADIUS     = 0.082

GUARD_Y_BASE    = 0.38
GUARD_Y_TOP     = 0.72
GUARD_HALF_W    = 0.67  # Total guard span = 1.34 studs

BLADE_BASE_Y    = 0.70
BLADE_TIP_Y     = 4.10  # Blade length = 3.40 studs
FULLER_END_Y    = 3.35

POMMEL_TOP_Y    = -0.40
POMMEL_TIP_Y    = -0.85

# Material Specifications
ZONE_SPECS = {
    "Zone1_FrostedSteel": {
        "name": "M_FrostedSteel_Edge",
        "hex": "#CBE8F7",
        "metallic": 0.88,
        "roughness": 0.22,
        "emission": "#000000",
        "emission_strength": 0.0,
        "rgb": (0.796, 0.910, 0.969, 1.0),
    },
    "Zone2_ForgedDarkIron": {
        "name": "M_ForgedDarkIron_Trim",
        "hex": "#252830",
        "metallic": 0.80,
        "roughness": 0.45,
        "emission": "#000000",
        "emission_strength": 0.0,
        "rgb": (0.145, 0.157, 0.188, 1.0),
    },
    "Zone3_ObsidianGrip": {
        "name": "M_ObsidianGrip_Leather",
        "hex": "#18181F",
        "metallic": 0.12,
        "roughness": 0.75,
        "emission": "#000000",
        "emission_strength": 0.0,
        "rgb": (0.094, 0.094, 0.122, 1.0),
    },
    "Zone4_RunicNeon": {
        "name": "M_RunicNeon_Core",
        "hex": "#00E5FF",
        "metallic": 0.10,
        "roughness": 0.15,
        "emission": "#38BDF8",
        "emission_strength": 4.5,
        "rgb": (0.000, 0.898, 1.000, 1.0),
    },
}

def hex_to_rgb(hex_str: str) -> tuple:
    c = hex_str.lstrip('#')
    return tuple(int(c[i:i+2], 16) / 255.0 for i in (0, 2, 4))

# =============================================================================
# 1. PBR & NEON MATERIAL BUILDER
# =============================================================================
def build_materials():
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
# 2. RUNIC LONGSWORD MESH (BMESH)
# =============================================================================
def build_runic_longsword_mesh():
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
    # PART A: HANDLE GRIP & TEMPERED STEEL COLLARS
    # -------------------------------------------------------------------------
    num_grip_segments = 14
    num_radial = 14
    grip_rings = []
    
    for i in range(num_grip_segments + 1):
        t = i / float(num_grip_segments)
        y = -GRIP_HALF_LEN + t * (GRIP_HALF_LEN * 2.0)
        
        rib = math.sin(t * math.pi * 10.0) * 0.0065
        is_collar = (i in (0, 1, num_grip_segments - 1, num_grip_segments))
        r = GRIP_RADIUS * 1.25 if is_collar else (GRIP_RADIUS + rib)
        
        ring_verts = []
        for a in range(num_radial):
            theta = (a / float(num_radial)) * 2.0 * math.pi
            vx = math.cos(theta) * r
            vz = math.sin(theta) * (r * 0.88)
            ring_verts.append(bm.verts.new((vx, y, vz)))
        grip_rings.append((ring_verts, is_collar))

    for i in range(num_grip_segments):
        r1, c1 = grip_rings[i]
        r2, c2 = grip_rings[i + 1]
        mat_idx = 1 if (c1 or c2) else 2
        for j in range(num_radial):
            jn = (j + 1) % num_radial
            add_quad(r1[j], r1[jn], r2[jn], r2[j], mat_idx)

    # -------------------------------------------------------------------------
    # PART B: ASTRAL STAR CROSSGUARD & BARBED GOTHIC QUILIONS
    # -------------------------------------------------------------------------
    guard_center_y = (GUARD_Y_BASE + GUARD_Y_TOP) * 0.5
    
    star_profile = [
        (0.00,  0.18, 0.08, "North Point"),
        (0.07,  0.07, 0.05, "North-East Minor"),
        (0.20,  0.00, 0.08, "East Point"),
        (0.07, -0.07, 0.05, "South-East Minor"),
        (0.00, -0.18, 0.08, "South Point"),
        (-0.07, -0.07, 0.05, "South-West Minor"),
        (-0.20,  0.00, 0.08, "West Point"),
        (-0.07,  0.07, 0.05, "North-West Minor"),
    ]
    
    star_rim_pos = [bm.verts.new((x, guard_center_y + yo, z)) for x, yo, z, _ in star_profile]
    star_rim_neg = [bm.verts.new((x, guard_center_y + yo, -z)) for x, yo, z, _ in star_profile]
    
    star_core_pos = bm.verts.new((0.0, guard_center_y, 0.115))
    star_core_neg = bm.verts.new((0.0, guard_center_y, -0.115))
    
    for i in range(8):
        nxt = (i + 1) % 8
        f_p = add_tri(star_core_pos, star_rim_pos[i], star_rim_pos[nxt], 3)
        f_n = add_tri(star_core_neg, star_rim_neg[nxt], star_rim_neg[i], 3)
        for e in f_p.edges:
            sharp_edges.add(e)
        for e in f_n.edges:
            sharp_edges.add(e)

    quillon_profile = [
        (0.16,  0.000, 0.150, 0.120),
        (0.26,  0.018, 0.135, 0.100),
        (0.38,  0.048, 0.115, 0.085),
        (0.48,  0.095, 0.100, 0.070),
        (0.58,  0.165, 0.125, 0.065),
        (0.67,  0.245, 0.075, 0.045),
    ]
    
    subwing_profile = [
        (0.22, -0.04, 0.08, 0.06),
        (0.35, -0.07, 0.07, 0.05),
        (0.45, -0.05, 0.05, 0.04),
    ]
    
    def build_quillon_wing(sign: float):
        main_rings = []
        for x, yo, hy, dz in quillon_profile:
            px = x * sign
            py = guard_center_y + yo
            hy2 = hy * 0.5
            dz2 = dz * 0.5
            ring = [
                bm.verts.new((px, py + hy2, 0.0)),
                bm.verts.new((px, py + hy2 * 0.5, dz2)),
                bm.verts.new((px, py - hy2 * 0.5, dz2)),
                bm.verts.new((px, py - hy2, 0.0)),
                bm.verts.new((px, py - hy2 * 0.5, -dz2)),
                bm.verts.new((px, py + hy2 * 0.5, -dz2)),
            ]
            main_rings.append(ring)
            
        for r in range(len(main_rings) - 1):
            r1, r2 = main_rings[r], main_rings[r + 1]
            for j in range(6):
                jn = (j + 1) % 6
                if sign > 0:
                    add_quad(r1[j], r1[jn], r2[jn], r2[j], 1)
                else:
                    add_quad(r1[jn], r1[j], r2[j], r2[jn], 1)
                    
        q_tip = bm.verts.new((quillon_profile[-1][0] * sign * 1.03, guard_center_y + quillon_profile[-1][1] + 0.05, 0.0))
        for j in range(6):
            jn = (j + 1) % 6
            if sign > 0:
                add_tri(main_rings[-1][j], main_rings[-1][jn], q_tip, 1)
            else:
                add_tri(main_rings[-1][jn], main_rings[-1][j], q_tip, 1)

        sub_rings = []
        for x, yo, hy, dz in subwing_profile:
            px = x * sign
            py = guard_center_y + yo
            hy2 = hy * 0.5
            dz2 = dz * 0.5
            ring = [
                bm.verts.new((px, py + hy2, 0.0)),
                bm.verts.new((px, py, dz2)),
                bm.verts.new((px, py - hy2, 0.0)),
                bm.verts.new((px, py, -dz2)),
            ]
            sub_rings.append(ring)
            
        for r in range(len(sub_rings) - 1):
            r1, r2 = sub_rings[r], sub_rings[r + 1]
            for j in range(4):
                jn = (j + 1) % 4
                if sign > 0:
                    add_quad(r1[j], r1[jn], r2[jn], r2[j], 1)
                else:
                    add_quad(r1[jn], r1[j], r2[j], r2[jn], 1)
                    
        sub_tip = bm.verts.new((subwing_profile[-1][0] * sign * 1.05, guard_center_y + subwing_profile[-1][1] - 0.03, 0.0))
        for j in range(4):
            jn = (j + 1) % 4
            if sign > 0:
                add_tri(sub_rings[-1][j], sub_rings[-1][jn], sub_tip, 1)
            else:
                add_tri(sub_rings[-1][jn], sub_rings[-1][j], sub_tip, 1)
                
    build_quillon_wing(+1.0)
    build_quillon_wing(-1.0)

    # -------------------------------------------------------------------------
    # PART C: RUNIC BLADE WITH RECESSED EMISSIVE FULLER (Y = 0.70 to 4.10)
    # -------------------------------------------------------------------------
    blade_stations = [
        # (y, width, thickness, fuller_w, fuller_depth_factor, has_fuller)
        (BLADE_BASE_Y, 0.46, 0.080, 0.22, 0.35, True),
        (0.85,         0.44, 0.076, 0.20, 0.32, True),
        (1.15,         0.43, 0.074, 0.19, 0.29, True),
        (1.50,         0.42, 0.071, 0.18, 0.28, True),
        (1.90,         0.40, 0.068, 0.17, 0.27, True),
        (2.30,         0.38, 0.064, 0.16, 0.26, True),
        (2.70,         0.35, 0.060, 0.15, 0.26, True),
        (3.05,         0.32, 0.056, 0.13, 0.26, True),
        (FULLER_END_Y, 0.29, 0.052, 0.10, 0.25, True),
        (3.52,         0.26, 0.048, 0.03, 0.65, False),
        (3.75,         0.20, 0.042, 0.01, 1.00, False),
        (3.95,         0.11, 0.030, 0.00, 1.00, False),
    ]
    
    blade_rings = []
    for y, w, t, fw, f_fac, has_f in blade_stations:
        hw = w * 0.5
        ht = t * 0.5
        hfw = fw * 0.5
        tf = ht * f_fac
        hfw_inner = hfw * 0.60
        hw_step = hw * 0.75
        
        v_ring = [
            bm.verts.new((-hw, y, 0)),
            bm.verts.new((-hw_step, y, ht * 0.5)),
            bm.verts.new((-hfw, y, ht)),
            bm.verts.new((-hfw_inner, y, tf)),
            bm.verts.new((0.0, y, tf * 0.85)),
            bm.verts.new((+hfw_inner, y, tf)),
            bm.verts.new((+hfw, y, ht)),
            bm.verts.new((+hw_step, y, ht * 0.5)),
            bm.verts.new((+hw, y, 0)),
            bm.verts.new((+hw_step, y, -ht * 0.5)),
            bm.verts.new((+hfw, y, -ht)),
            bm.verts.new((+hfw_inner, y, -tf)),
            bm.verts.new((0.0, y, -tf * 0.85)),
            bm.verts.new((-hfw_inner, y, -tf)),
            bm.verts.new((-hfw, y, -ht)),
            bm.verts.new((-hw_step, y, -ht * 0.5)),
        ]
        blade_rings.append((v_ring, has_f))

    blade_tip = bm.verts.new((0, BLADE_TIP_Y, 0))

    for r in range(len(blade_rings) - 1):
        r1_verts, r1_has_f = blade_rings[r]
        r2_verts, r2_has_f = blade_rings[r + 1]
        
        for j in range(16):
            jn = (j + 1) % 16
            v0, v1, v2, v3 = r1_verts[j], r1_verts[jn], r2_verts[jn], r2_verts[j]
            
            if (r1_has_f or r2_has_f) and (j in (3, 4, 11, 12)):
                mat_idx = 3 # Neon Rune Inlay
            else:
                mat_idx = 0 # Frosted Steel Edge
                
            f = add_quad(v0, v1, v2, v3, mat_idx)
            
            if j in (0, 2, 6, 8, 10, 14):
                for e in f.edges:
                    if (e.verts[0] in (v0, v3) and e.verts[1] in (v0, v3)) or \
                       (e.verts[0] in (v1, v2) and e.verts[1] in (v1, v2)):
                        sharp_edges.add(e)

    last_r_verts, _ = blade_rings[-1]
    for j in range(16):
        jn = (j + 1) % 16
        f = add_tri(last_r_verts[j], last_r_verts[jn], blade_tip, 0)
        for e in f.edges:
            if blade_tip in e.verts:
                sharp_edges.add(e)

    # -------------------------------------------------------------------------
    # PART D: GOTHIC CROWN POMMEL & FACETED CYAN RUNIC CRYSTAL CORE
    # -------------------------------------------------------------------------
    gem_levels = [
        (-0.50, 0.020),
        (-0.58, 0.068),
        (-0.68, 0.055),
        (-0.76, 0.022),
    ]
    gem_rings = []
    num_gem_facets = 8
    for y, rad in gem_levels:
        r_verts = []
        for s in range(num_gem_facets):
            th = (s / float(num_gem_facets)) * 2.0 * math.pi
            r_verts.append(bm.verts.new((math.cos(th) * rad, y, math.sin(th) * rad)))
        gem_rings.append(r_verts)
        
    for r in range(len(gem_rings) - 1):
        r1, r2 = gem_rings[r], gem_rings[r + 1]
        for j in range(num_gem_facets):
            jn = (j + 1) % num_gem_facets
            add_quad(r1[j], r1[jn], r2[jn], r2[j], 3)
            
    gem_top_v = bm.verts.new((0, -0.48, 0))
    gem_bot_v = bm.verts.new((0, -0.78, 0))
    for j in range(num_gem_facets):
        jn = (j + 1) % num_gem_facets
        add_tri(gem_rings[0][jn], gem_rings[0][j], gem_top_v, 3)
        add_tri(gem_rings[-1][j], gem_rings[-1][jn], gem_bot_v, 3)

    num_claws = 6
    for claw_idx in range(num_claws):
        angle = claw_idx * (math.pi * 2.0 / num_claws)
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        
        claw_nodes = [
            (-0.40, 0.098, 0.032),
            (-0.48, 0.118, 0.028),
            (-0.60, 0.126, 0.026),
            (-0.72, 0.088, 0.022),
            (-0.82, 0.032, 0.018),
        ]
        
        claw_rings = []
        for py, dist, thk in claw_nodes:
            cx = cos_a * dist
            cz = sin_a * dist
            px = -sin_a * thk
            pz =  cos_a * thk
            rx =  cos_a * thk
            rz =  sin_a * thk
            
            c_ring = [
                bm.verts.new((cx - px, py, cz - pz)),
                bm.verts.new((cx + rx, py, cz + rz)),
                bm.verts.new((cx + px, py, cz + pz)),
                bm.verts.new((cx - rx, py, cz - rz)),
            ]
            claw_rings.append(c_ring)
            
        for r in range(len(claw_rings) - 1):
            r1, r2 = claw_rings[r], claw_rings[r + 1]
            for j in range(4):
                jn = (j + 1) % 4
                add_quad(r1[j], r1[jn], r2[jn], r2[j], 1)

    finial_tip = bm.verts.new((0, POMMEL_TIP_Y, 0))
    base_ring = []
    for s in range(num_claws):
        th = s * (math.pi * 2.0 / num_claws)
        base_ring.append(bm.verts.new((math.cos(th) * 0.032, -0.82, math.sin(th) * 0.032)))
    for s in range(num_claws):
        sn = (s + 1) % num_claws
        add_tri(base_ring[s], base_ring[sn], finial_tip, 1)

    for e in sharp_edges:
        e.smooth = False

    bm.verts.ensure_lookup_table()
    bm.edges.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    
    return bm

# =============================================================================
# 3. SECONDARY AURA MESH (TWIN FROST RIBBONS)
# =============================================================================
def build_aura_mesh():
    bm = bmesh.new()
    num_steps = 16
    ribbon_start_y = 0.80
    ribbon_end_y   = 4.05
    
    r1_verts = []
    r2_verts = []
    
    for i in range(num_steps + 1):
        t = i / float(num_steps)
        y = ribbon_start_y + t * (ribbon_end_y - ribbon_start_y)
        w = (math.sin(t * math.pi) * 0.30 + 0.06) * 0.5
        twist = t * math.pi * 1.5
        
        rx1 = math.cos(twist) * (w + 0.04)
        rz1 = math.sin(twist) * (w * 0.6 + 0.03)
        v1a = bm.verts.new((rx1 - 0.015, y, rz1))
        v1b = bm.verts.new((rx1 + 0.015, y, rz1))
        r1_verts.append((v1a, v1b))
        
        rx2 = math.cos(twist + math.pi) * (w + 0.04)
        rz2 = math.sin(twist + math.pi) * (w * 0.6 + 0.03)
        v2a = bm.verts.new((rx2 - 0.015, y, rz2))
        v2b = bm.verts.new((rx2 + 0.015, y, rz2))
        r2_verts.append((v2a, v2b))
        
    for i in range(num_steps):
        (v0a, v0b) = r1_verts[i]
        (v1a, v1b) = r1_verts[i + 1]
        f1 = bm.faces.new([v0a, v0b, v1b, v1a])
        f1.material_index = 0
        
        (v2a, v2b) = r2_verts[i]
        (v3a, v3b) = r2_verts[i + 1]
        f2 = bm.faces.new([v2a, v2b, v3b, v3a])
        f2.material_index = 0
        
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    return bm

# =============================================================================
# 4. SCENE GENERATOR, UV UNWRAPPING & ATTACHMENT CREATION
# =============================================================================
def generate_runic_longsword(clean_scene: bool = True, export_fbx_path: str = None, export_json_path: str = None):
    if clean_scene:
        bpy.ops.object.select_all(action='SELECT')
        bpy.ops.object.delete(use_global=False)
        
    materials = build_materials()
    mat_slots = [
        materials["Zone1_FrostedSteel"],
        materials["Zone2_ForgedDarkIron"],
        materials["Zone3_ObsidianGrip"],
        materials["Zone4_RunicNeon"],
    ]

    # 1. Primary Sword Mesh
    bm_sword = build_runic_longsword_mesh()
    mesh_sword = bpy.data.meshes.new(f"{SWORD_OBJ_NAME}_Data")
    bm_sword.to_mesh(mesh_sword)
    bm_sword.free()
    
    obj_sword = bpy.data.objects.new(SWORD_OBJ_NAME, mesh_sword)
    bpy.context.collection.objects.link(obj_sword)
    bpy.context.view_layer.objects.active = obj_sword
    obj_sword.select_set(True)
    
    for mat in mat_slots:
        mesh_sword.materials.append(mat)
        
    col_attr = mesh_sword.color_attributes.new(name="Color", type='BYTE_COLOR', domain='CORNER')
    color_map = {
        0: ZONE_SPECS["Zone1_FrostedSteel"]["rgb"],
        1: ZONE_SPECS["Zone2_ForgedDarkIron"]["rgb"],
        2: ZONE_SPECS["Zone3_ObsidianGrip"]["rgb"],
        3: ZONE_SPECS["Zone4_RunicNeon"]["rgb"],
    }
    
    for poly in mesh_sword.polygons:
        mat_idx = poly.material_index
        c = color_map.get(mat_idx, ZONE_SPECS["Zone1_FrostedSteel"]["rgb"])
        for loop_idx in poly.loop_indices:
            col_attr.data[loop_idx].color = c
            
    for poly in mesh_sword.polygons:
        poly.use_smooth = True
        
    if hasattr(bpy.ops.object, "shade_auto_smooth"):
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
    elif hasattr(mesh_sword, "use_auto_smooth"):
        mesh_sword.use_auto_smooth = True
        mesh_sword.auto_smooth_angle = math.radians(40)
        
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # 2. Secondary Aura Mesh
    bm_aura = build_aura_mesh()
    mesh_aura = bpy.data.meshes.new(f"{AURA_OBJ_NAME}_Data")
    bm_aura.to_mesh(mesh_aura)
    bm_aura.free()
    
    obj_aura = bpy.data.objects.new(AURA_OBJ_NAME, mesh_aura)
    bpy.context.collection.objects.link(obj_aura)
    obj_aura.select_set(True)
    obj_aura.parent = obj_sword
    mesh_aura.materials.append(materials["Zone4_RunicNeon"])
    
    for poly in mesh_aura.polygons:
        poly.use_smooth = True
        
    bpy.context.view_layer.objects.active = obj_aura
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')

    # 3. Attachments
    attachments = {
        "GripAttachment": (Vector((0.0, 0.00, 0.0)), "Center of Handle Grip (HoldingAnimationController pivot)"),
        "TrailBottom":    (Vector((0.0, 0.75, 0.0)), "Ricasso / Blade Base just above crossguard"),
        "TrailTop":       (Vector((0.0, 4.10, 0.0)), "Exact Spear Tip of Blade"),
        "VFXCore":        (Vector((0.0, 2.40, 0.0)), "Center of Runic Fuller / Particle Spawner"),
    }
    
    created_empties = {}
    print("\n" + "="*70)
    print("ROBLOX STUDIO ATTACHMENT COORDINATES (Vector3 Offsets):")
    print("="*70)
    for att_name, (pos, desc) in attachments.items():
        empty = bpy.data.objects.new(att_name, None)
        empty.empty_display_type = 'ARROWS'
        empty.empty_display_size = 0.2
        empty.location = pos
        empty.parent = obj_sword
        bpy.context.collection.objects.link(empty)
        created_empties[att_name] = empty
        print(f"  [{att_name}]: Vector3.new({pos.x:.3f}, {pos.y:.3f}, {pos.z:.3f}) -- {desc}")
    print("="*70 + "\n")

    sword_tris = sum(len(p.vertices) - 2 for p in mesh_sword.polygons)
    aura_tris  = sum(len(p.vertices) - 2 for p in mesh_aura.polygons)
    total_tris = sword_tris + aura_tris
    dims = obj_sword.dimensions
    
    print(f"SUCCESS: Generated '{SWORD_OBJ_NAME}' and '{AURA_OBJ_NAME}'")
    print(f"  - Primary Mesh Triangles: {sword_tris} tris")
    print(f"  - Aura Mesh Triangles:    {aura_tris} tris")
    print(f"  - Total Weapon Triangles: {total_tris} tris (Budget: 1,000-1,800 tris)")
    print(f"  - Dimensions: X={dims.x:.3f}, Y={dims.y:.3f}, Z={dims.z:.3f} studs")
    print(f"  - Pivot Origin (0,0,0):   Exact Midpoint of Handle Grip")
    print(f"  - Material Zones:         4 configured PBR / Neon slots")

    if export_fbx_path:
        export_fbx_for_roblox(obj_sword, export_fbx_path)
        
    if export_json_path:
        export_mesh_to_json(obj_sword, export_json_path)

    return obj_sword, obj_aura

# =============================================================================
# 5. EXPORT PIPELINES
# =============================================================================
def export_fbx_for_roblox(obj, export_path: str):
    os.makedirs(os.path.dirname(os.path.abspath(export_path)), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    for child in obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = obj
    
    bpy.ops.export_scene.fbx(
        filepath=export_path,
        use_selection=True,
        object_types={'MESH', 'EMPTY'},
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

def export_mesh_to_json(obj, export_path: str):
    os.makedirs(os.path.dirname(os.path.abspath(export_path)), exist_ok=True)
    mesh = obj.data
    mesh.calc_loop_triangles()
    
    verts = [[round(v.co.x, 4), round(v.co.y, 4), round(v.co.z, 4)] for v in mesh.vertices]
    tris = [[lt.vertices[0] + 1, lt.vertices[1] + 1, lt.vertices[2] + 1] for lt in mesh.loop_triangles]
    
    data = {
        "verts": verts,
        "tris": tris,
        "tri_count": len(tris),
        "vert_count": len(verts),
    }
    with open(export_path, "w") as f:
        json.dump(data, f)
    print(f"Exported JSON mesh data: {export_path} (Tris: {len(tris)})")

# =============================================================================
# ENTRY POINT
# =============================================================================
if __name__ == "__main__":
    fbx_out = r"C:\WORK\infinite-tower\assets\models\weapons\runic_longsword.fbx"
    json_out = r"C:\WORK\infinite-tower\assets\models\weapons\runic_longsword_mesh.json"
    generate_runic_longsword(clean_scene=True, export_fbx_path=fbx_out, export_json_path=json_out)
