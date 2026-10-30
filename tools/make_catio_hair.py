"""
Generates Catio's high-poly Roblox UGC style anime hair in Blender.
Style: Dark Slate Navy Blue (#2D334A), shaggy layered anime wolf-cut / bob,
center-left parted curtain bangs, long jaw/chest framing side locks,
dense layered back canopy, crown tufts with delicate UGC flyaway strands.
"""

import bpy
import bmesh
import math
import os
import json
from mathutils import Vector

def create_catio_hair():
    # 1. Clean existing hair objects
    for obj in list(bpy.data.objects):
        if obj.name.startswith("CatioHair") or obj.name in ("HairProfile_Catio", "RobloxHeadRef_Catio"):
            bpy.data.objects.remove(obj, do_unlink=True)

    # 2. Material: Dark Slate Navy Blue (#2D334A -> sRGB ~0.176, 0.200, 0.290)
    mat = bpy.data.materials.get("CatioNavy_2D334A") or bpy.data.materials.new(name="CatioNavy_2D334A")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (0.176, 0.200, 0.290, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.50
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.55
        elif "Specular" in bsdf.inputs:
            bsdf.inputs["Specular"].default_value = 0.55

    # 3. Create High-Poly UGC Stylized Clump Profiles
    # Profile A: Standard chunky lock with sharp ridge crest and curved belly (6 points)
    # Scaled to unit 1.0 width/height; curve radius scales it per vertex.
    prof_data = bpy.data.curves.new('HairProfile_Catio', type='CURVE')
    prof_data.dimensions = '2D'
    spline = prof_data.splines.new('POLY')
    spline.points.add(5)
    # Points: Left mid, Top-left slope, Sharp central ridge, Top-right slope, Right mid, Bottom belly
    profile_coords = [
        (-0.55, 0.0, 0, 1),
        (-0.25, 0.35, 0, 1),
        (0.0, 0.50, 0, 1),
        (0.25, 0.35, 0, 1),
        (0.55, 0.0, 0, 1),
        (0.0, -0.22, 0, 1),
    ]
    for i, c in enumerate(profile_coords):
        spline.points[i].co = c
    spline.use_cyclic_u = True
    prof_obj = bpy.data.objects.new('HairProfile_Catio', prof_data)
    bpy.context.collection.objects.link(prof_obj)
    prof_obj.hide_viewport = True
    prof_obj.hide_render = True

    # Profile B: Thin Flyaway Strand (Ahoge / floating strand) (5 points)
    prof_thin_data = bpy.data.curves.new('HairProfile_Catio_Thin', type='CURVE')
    prof_thin_data.dimensions = '2D'
    spline_t = prof_thin_data.splines.new('POLY')
    spline_t.points.add(4)
    thin_coords = [
        (-0.35, 0.0, 0, 1),
        (0.0, 0.35, 0, 1),
        (0.35, 0.0, 0, 1),
        (0.0, -0.20, 0, 1),
        (0.0, 0.0, 0, 1),
    ]
    for i, c in enumerate(thin_coords[:5]):
        spline_t.points[i].co = thin_coords[i]
    spline_t.use_cyclic_u = True
    prof_thin_obj = bpy.data.objects.new('HairProfile_Catio_Thin', prof_thin_data)
    bpy.context.collection.objects.link(prof_thin_obj)
    prof_thin_obj.hide_viewport = True
    prof_thin_obj.hide_render = True

    hair_curve_objects = []

    def add_hair_clump(name, points, radii, tilts, bevel_obj=prof_obj, res_u=16):
        cdata = bpy.data.curves.new(name, type='CURVE')
        cdata.dimensions = '3D'
        cdata.bevel_mode = 'OBJECT'
        cdata.bevel_object = bevel_obj
        cdata.use_fill_caps = True
        cdata.resolution_u = res_u
        
        sp = cdata.splines.new('BEZIER')
        sp.bezier_points.add(len(points) - 1)
        for i, (pt, rad, tilt) in enumerate(zip(points, radii, tilts)):
            bp = sp.bezier_points[i]
            bp.co = pt
            bp.handle_left_type = 'AUTO'
            bp.handle_right_type = 'AUTO'
            bp.radius = rad
            bp.tilt = math.radians(tilt)
            
        cobj = bpy.data.objects.new(name, cdata)
        cobj.data.materials.append(mat)
        bpy.context.collection.objects.link(cobj)
        hair_curve_objects.append(cobj)
        return cobj

    # Coordinates in Blender space:
    # Origin (0,0,0) is head center.
    # +X = Right, -X = Left
    # +Y = Front (Face), -Y = Back
    # +Z = Up (Crown), -Z = Down (Neck)
    # Head cylinder: radius 0.6, height 1.2 (Z: -0.6 to +0.6)

    # =========================================================================
    # CLUMPS SPECIFICATION (Over 45 tailored high-poly locks)
    # =========================================================================
    clumps = []

    # -------------------------------------------------------------------------
    # A. CENTER-LEFT PARTED CURTAIN BANGS (Fringe)
    # -------------------------------------------------------------------------
    # Main sweeping left curtain bang (thick, curving over brow towards left cheek)
    clumps.append((
        "CatioHair_Bang_L_Main",
        [(-0.06, 0.58, 0.63), (-0.22, 0.66, 0.48), (-0.36, 0.64, 0.28), (-0.48, 0.55, 0.08)],
        [0.09, 0.15, 0.13, 0.015],
        [15, -20, -35, -45],
        prof_obj, 16
    ))
    # Left secondary overlapping outer bang
    clumps.append((
        "CatioHair_Bang_L_Outer",
        [(-0.12, 0.56, 0.65), (-0.32, 0.65, 0.46), (-0.46, 0.60, 0.22), (-0.54, 0.50, -0.02)],
        [0.08, 0.13, 0.11, 0.015],
        [20, -15, -30, -40],
        prof_obj, 16
    ))
    # Left brow-skimming inner tuft
    clumps.append((
        "CatioHair_Bang_L_Inner",
        [(-0.04, 0.59, 0.61), (-0.14, 0.67, 0.45), (-0.22, 0.66, 0.26), (-0.26, 0.63, 0.14)],
        [0.07, 0.11, 0.09, 0.01],
        [10, -10, -20, -25],
        prof_obj, 16
    ))

    # Main sweeping right curtain bang (thick, sweeping to the right over brow)
    clumps.append((
        "CatioHair_Bang_R_Main",
        [(-0.02, 0.58, 0.63), (0.16, 0.66, 0.48), (0.34, 0.64, 0.28), (0.46, 0.55, 0.06)],
        [0.09, 0.15, 0.14, 0.015],
        [-15, 20, 35, 45],
        prof_obj, 16
    ))
    # Right secondary overlapping outer bang
    clumps.append((
        "CatioHair_Bang_R_Outer",
        [(0.06, 0.56, 0.65), (0.28, 0.65, 0.46), (0.44, 0.60, 0.20), (0.52, 0.48, -0.04)],
        [0.08, 0.13, 0.11, 0.015],
        [-20, 15, 30, 40],
        prof_obj, 16
    ))
    # Right brow-skimming inner tuft
    clumps.append((
        "CatioHair_Bang_R_Inner",
        [(0.01, 0.59, 0.61), (0.12, 0.67, 0.45), (0.20, 0.66, 0.26), (0.24, 0.63, 0.12)],
        [0.07, 0.10, 0.08, 0.01],
        [-10, 10, 20, 25],
        prof_obj, 16
    ))

    # Center delicate dipping strands (falling between eyes down towards nose bridge)
    clumps.append((
        "CatioHair_Bang_Center_Dip1",
        [(-0.04, 0.60, 0.62), (-0.06, 0.68, 0.42), (-0.04, 0.67, 0.22), (-0.02, 0.65, 0.06)],
        [0.05, 0.07, 0.05, 0.01],
        [0, -5, 0, 5],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Bang_Center_Dip2",
        [(0.01, 0.60, 0.62), (0.04, 0.68, 0.40), (0.06, 0.67, 0.20), (0.04, 0.65, 0.04)],
        [0.05, 0.07, 0.05, 0.01],
        [0, 5, 0, -5],
        prof_obj, 16
    ))
    # Delicate fine micro-strand dipping between eyes
    clumps.append((
        "CatioHair_Bang_Center_Fine",
        [(-0.01, 0.61, 0.60), (0.00, 0.69, 0.38), (0.01, 0.68, 0.18), (0.00, 0.66, -0.02)],
        [0.03, 0.045, 0.03, 0.008],
        [0, 0, 0, 0],
        prof_thin_obj, 16
    ))

    # -------------------------------------------------------------------------
    # B. LONG JAW / CHEST FRAMING SIDE LOCKS (Catio's signature framing)
    # -------------------------------------------------------------------------
    # Main Left Long Framing Lock (cascades down past chin to collar/chest level Z = -0.72)
    clumps.append((
        "CatioHair_Side_L_Long1",
        [(-0.42, 0.42, 0.52), (-0.56, 0.46, 0.20), (-0.58, 0.44, -0.15), (-0.52, 0.40, -0.48), (-0.46, 0.36, -0.74)],
        [0.09, 0.14, 0.13, 0.11, 0.015],
        [-35, -45, -50, -40, -25],
        prof_obj, 18
    ))
    # Left Inner Cheek Hugging Lock
    clumps.append((
        "CatioHair_Side_L_Cheek",
        [(-0.35, 0.48, 0.45), (-0.48, 0.54, 0.16), (-0.50, 0.50, -0.12), (-0.44, 0.44, -0.38)],
        [0.07, 0.11, 0.09, 0.012],
        [-30, -35, -30, -20],
        prof_obj, 16
    ))
    # Left Ear / Temple Lock (curving over the ear)
    clumps.append((
        "CatioHair_Side_L_Ear",
        [(-0.48, 0.25, 0.50), (-0.62, 0.26, 0.20), (-0.64, 0.20, -0.16), (-0.58, 0.18, -0.48), (-0.50, 0.20, -0.70)],
        [0.08, 0.13, 0.12, 0.10, 0.015],
        [-55, -65, -70, -60, -45],
        prof_obj, 18
    ))

    # Main Right Long Framing Lock (cascades down past chin to collar/chest level Z = -0.72)
    clumps.append((
        "CatioHair_Side_R_Long1",
        [(0.40, 0.42, 0.52), (0.54, 0.46, 0.20), (0.56, 0.44, -0.15), (0.50, 0.40, -0.48), (0.44, 0.36, -0.74)],
        [0.09, 0.14, 0.13, 0.11, 0.015],
        [35, 45, 50, 40, 25],
        prof_obj, 18
    ))
    # Right Inner Cheek Hugging Lock
    clumps.append((
        "CatioHair_Side_R_Cheek",
        [(0.33, 0.48, 0.45), (0.46, 0.54, 0.16), (0.48, 0.50, -0.12), (0.42, 0.44, -0.38)],
        [0.07, 0.11, 0.09, 0.012],
        [30, 35, 30, 20],
        prof_obj, 16
    ))
    # Right Ear / Temple Lock (curving over the ear)
    clumps.append((
        "CatioHair_Side_R_Ear",
        [(0.46, 0.25, 0.50), (0.60, 0.26, 0.20), (0.62, 0.20, -0.16), (0.56, 0.18, -0.48), (0.48, 0.20, -0.70)],
        [0.08, 0.13, 0.12, 0.10, 0.015],
        [55, 65, 70, 60, 45],
        prof_obj, 18
    ))

    # Outer Flaring Side Tufts (giving the shaggy anime wolf-cut silhouette)
    clumps.append((
        "CatioHair_Side_L_Flare1",
        [(-0.38, 0.10, 0.55), (-0.62, 0.12, 0.30), (-0.68, 0.08, 0.05), (-0.64, 0.06, -0.22)],
        [0.08, 0.13, 0.11, 0.015],
        [-65, -80, -85, -75],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Side_L_Flare2",
        [(-0.35, -0.10, 0.54), (-0.60, -0.08, 0.25), (-0.66, -0.12, -0.05), (-0.60, -0.10, -0.35)],
        [0.08, 0.12, 0.10, 0.015],
        [-75, -90, -95, -85],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Side_R_Flare1",
        [(0.36, 0.10, 0.55), (0.60, 0.12, 0.30), (0.66, 0.08, 0.05), (0.62, 0.06, -0.22)],
        [0.08, 0.13, 0.11, 0.015],
        [65, 80, 85, 75],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Side_R_Flare2",
        [(0.33, -0.10, 0.54), (0.58, -0.08, 0.25), (0.64, -0.12, -0.05), (0.58, -0.10, -0.35)],
        [0.08, 0.12, 0.10, 0.015],
        [75, 90, 95, 85],
        prof_obj, 16
    ))

    # -------------------------------------------------------------------------
    # C. CROWN VOLUME & STYLIZED UGC FLYAWAY STRANDS (Top)
    # -------------------------------------------------------------------------
    # Crown tufts arching up and back
    clumps.append((
        "CatioHair_Crown_Tuft_L1",
        [(-0.08, 0.30, 0.65), (-0.18, 0.22, 0.74), (-0.28, 0.10, 0.72), (-0.36, -0.04, 0.64)],
        [0.08, 0.13, 0.10, 0.015],
        [-15, -30, -45, -60],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Crown_Tuft_R1",
        [(0.05, 0.30, 0.65), (0.16, 0.22, 0.74), (0.26, 0.10, 0.72), (0.34, -0.04, 0.64)],
        [0.08, 0.13, 0.10, 0.015],
        [15, 30, 45, 60],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Crown_Peak_C",
        [(-0.02, 0.20, 0.66), (0.00, 0.08, 0.76), (0.00, -0.10, 0.73), (0.00, -0.26, 0.62)],
        [0.08, 0.14, 0.11, 0.015],
        [0, 0, 0, 0],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Crown_Tuft_L2",
        [(-0.14, 0.05, 0.66), (-0.26, -0.05, 0.73), (-0.35, -0.20, 0.66)],
        [0.08, 0.12, 0.015],
        [-30, -50, -70],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Crown_Tuft_R2",
        [(0.12, 0.05, 0.66), (0.24, -0.05, 0.73), (0.33, -0.20, 0.66)],
        [0.08, 0.12, 0.015],
        [30, 50, 70],
        prof_obj, 16
    ))

    # UGC Signature Ahoge / Floating Flyaways (thin, elegant floating S-curves)
    clumps.append((
        "CatioHair_Ahoge_Main",
        [(-0.02, 0.32, 0.66), (-0.05, 0.24, 0.82), (0.02, 0.12, 0.86), (0.08, -0.04, 0.81), (0.14, -0.16, 0.72)],
        [0.03, 0.045, 0.04, 0.03, 0.006],
        [0, 15, 30, 45, 60],
        prof_thin_obj, 18
    ))
    clumps.append((
        "CatioHair_Ahoge_Left",
        [(-0.10, 0.28, 0.66), (-0.18, 0.20, 0.79), (-0.26, 0.08, 0.78), (-0.32, -0.06, 0.70)],
        [0.025, 0.04, 0.03, 0.006],
        [-20, -35, -50, -65],
        prof_thin_obj, 16
    ))
    clumps.append((
        "CatioHair_Ahoge_Right",
        [(0.08, 0.28, 0.66), (0.16, 0.20, 0.79), (0.24, 0.08, 0.78), (0.30, -0.06, 0.70)],
        [0.025, 0.04, 0.03, 0.006],
        [20, 35, 50, 65],
        prof_thin_obj, 16
    ))

    # -------------------------------------------------------------------------
    # D. VOLUMINOUS LAYERED BACK & OCCIPITAL CANOPY (Covering back to hood line)
    # -------------------------------------------------------------------------
    # Tier 1 (Upper Back Canopy)
    clumps.append((
        "CatioHair_Back_Upper_L1",
        [(-0.10, -0.18, 0.64), (-0.16, -0.38, 0.52), (-0.22, -0.52, 0.30), (-0.26, -0.58, 0.02)],
        [0.09, 0.14, 0.12, 0.015],
        [-15, -25, -30, -35],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Back_Upper_R1",
        [(0.08, -0.18, 0.64), (0.14, -0.38, 0.52), (0.20, -0.52, 0.30), (0.24, -0.58, 0.02)],
        [0.09, 0.14, 0.12, 0.015],
        [15, 25, 30, 35],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Back_Upper_C",
        [(-0.01, -0.22, 0.64), (0.00, -0.42, 0.52), (0.00, -0.56, 0.28), (0.00, -0.62, 0.00)],
        [0.10, 0.15, 0.13, 0.015],
        [0, 0, 0, 0],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Back_Upper_L2",
        [(-0.24, -0.14, 0.60), (-0.34, -0.32, 0.46), (-0.42, -0.46, 0.22), (-0.46, -0.52, -0.08)],
        [0.08, 0.13, 0.11, 0.015],
        [-35, -45, -55, -60],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Back_Upper_R2",
        [(0.22, -0.14, 0.60), (0.32, -0.32, 0.46), (0.40, -0.46, 0.22), (0.44, -0.52, -0.08)],
        [0.08, 0.13, 0.11, 0.015],
        [35, 45, 55, 60],
        prof_obj, 16
    ))

    # Tier 2 (Mid Occipital & Lower Back)
    clumps.append((
        "CatioHair_Back_Mid_C",
        [(0.00, -0.35, 0.42), (0.00, -0.52, 0.18), (0.00, -0.60, -0.12), (0.00, -0.62, -0.42)],
        [0.10, 0.15, 0.13, 0.015],
        [0, 0, 0, 0],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Back_Mid_L1",
        [(-0.14, -0.32, 0.42), (-0.18, -0.50, 0.16), (-0.22, -0.58, -0.14), (-0.24, -0.58, -0.44)],
        [0.09, 0.14, 0.12, 0.015],
        [-15, -20, -25, -25],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Back_Mid_R1",
        [(0.12, -0.32, 0.42), (0.16, -0.50, 0.16), (0.20, -0.58, -0.14), (0.22, -0.58, -0.44)],
        [0.09, 0.14, 0.12, 0.015],
        [15, 20, 25, 25],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Back_Mid_L2",
        [(-0.28, -0.28, 0.40), (-0.34, -0.46, 0.14), (-0.38, -0.54, -0.16), (-0.40, -0.52, -0.46)],
        [0.08, 0.13, 0.11, 0.015],
        [-35, -45, -50, -50],
        prof_obj, 16
    ))
    clumps.append((
        "CatioHair_Back_Mid_R2",
        [(0.26, -0.28, 0.40), (0.32, -0.46, 0.14), (0.36, -0.54, -0.16), (0.38, -0.52, -0.46)],
        [0.08, 0.13, 0.11, 0.015],
        [35, 45, 50, 50],
        prof_obj, 16
    ))

    # Tier 3 (Cascading Nape & Shoulder Tips - Draping outward over shoulders/hood)
    clumps.append((
        "CatioHair_Back_Nape_C",
        [(0.00, -0.42, 0.05), (0.00, -0.55, -0.22), (0.00, -0.58, -0.50), (0.00, -0.56, -0.72)],
        [0.10, 0.14, 0.12, 0.015],
        [0, 0, 0, 0],
        prof_obj, 18
    ))
    clumps.append((
        "CatioHair_Back_Nape_L1",
        [(-0.16, -0.40, 0.04), (-0.20, -0.54, -0.24), (-0.24, -0.56, -0.52), (-0.26, -0.52, -0.72)],
        [0.09, 0.13, 0.11, 0.015],
        [-15, -25, -30, -30],
        prof_obj, 18
    ))
    clumps.append((
        "CatioHair_Back_Nape_R1",
        [(0.14, -0.40, 0.04), (0.18, -0.54, -0.24), (0.22, -0.56, -0.52), (0.24, -0.52, -0.72)],
        [0.09, 0.13, 0.11, 0.015],
        [15, 25, 30, 30],
        prof_obj, 18
    ))
    clumps.append((
        "CatioHair_Back_Nape_L2",
        [(-0.30, -0.34, 0.02), (-0.36, -0.48, -0.26), (-0.40, -0.50, -0.52), (-0.42, -0.44, -0.70)],
        [0.08, 0.12, 0.10, 0.015],
        [-35, -45, -50, -50],
        prof_obj, 18
    ))
    clumps.append((
        "CatioHair_Back_Nape_R2",
        [(0.28, -0.34, 0.02), (0.34, -0.48, -0.26), (0.38, -0.50, -0.52), (0.40, -0.44, -0.70)],
        [0.08, 0.12, 0.10, 0.015],
        [35, 45, 50, 50],
        prof_obj, 18
    ))

    # Generate all clumps
    for name, pts, rads, tilts, b_obj, r_u in clumps:
        add_hair_clump(name, pts, rads, tilts, b_obj, r_u)

    print(f"Generated {len(clumps)} high-poly hair clump curves.")

    # 4. Generate High-Density Scalp Cap (Covers entire skull, temples down to Z = -0.45, nape to Z = -0.58)
    # Using a tailored bmesh dome with rounded beveling
    bm = bmesh.new()
    # Upper dome: radius ~0.61 (just outside 0.60 head cylinder)
    u_steps = 28
    v_steps = 14
    cap_verts = []
    for vi in range(v_steps + 1):
        # theta from 0 (top crown, Z = 0.65) to pi/2 + extra down to neck (Z = -0.55)
        # We parameterize:
        t = vi / v_steps
        z = 0.65 - t * 1.20 # Z from 0.65 down to -0.55
        # Radius expands to fit 0.61 at temples/ears, tapering at nape
        r = 0.61 * math.sin(t * math.pi * 0.75 + 0.25)
        r = max(0.20, min(0.64, r))
        ring = []
        for ui in range(u_steps):
            phi = 2.0 * math.pi * (ui / u_steps)
            # Front is +Y, Back is -Y, Right is +X, Left is -X
            # Slight offset forward/backward to hug head
            x = r * math.sin(phi) * 0.98
            y = r * math.cos(phi) * 0.96 - 0.02
            v = bm.verts.new((x, y, z))
            ring.append(v)
        cap_verts.append(ring)

    # Top pole vertex
    top_v = bm.verts.new((0, -0.02, 0.66))
    for ui in range(u_steps):
        bm.faces.new((top_v, cap_verts[0][(ui + 1) % u_steps], cap_verts[0][ui]))

    # Grid faces
    for vi in range(v_steps):
        for ui in range(u_steps):
            v0 = cap_verts[vi][ui]
            v1 = cap_verts[vi][(ui + 1) % u_steps]
            v2 = cap_verts[vi + 1][(ui + 1) % u_steps]
            v3 = cap_verts[vi + 1][ui]
            bm.faces.new((v0, v1, v2, v3))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    cap_me = bpy.data.meshes.new("CatioHair_BaseCap")
    bm.to_mesh(cap_me)
    bm.free()
    cap_obj = bpy.data.objects.new("CatioHair_BaseCap", cap_me)
    cap_obj.data.materials.append(mat)
    bpy.context.collection.objects.link(cap_obj)

    # 5. Convert curves to meshes and join with BaseCap
    bpy.ops.object.select_all(action='DESELECT')
    for cobj in hair_curve_objects:
        cobj.select_set(True)
    bpy.context.view_layer.objects.active = hair_curve_objects[0]
    bpy.ops.object.convert(target='MESH')

    # Join all hair meshes into BaseCap
    cap_obj.select_set(True)
    bpy.context.view_layer.objects.active = cap_obj
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = "CatioHair"
    
    # Smooth shading and weighted normal
    bpy.ops.object.shade_smooth()
    mod_wn = joined.modifiers.new(name="WeightedNormal", type='WEIGHTED_NORMAL')
    mod_wn.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier="WeightedNormal")

    me = joined.data
    me.calc_loop_triangles()
    total_verts = len(me.vertices)
    total_tris = len(me.loop_triangles)
    print(f"=== CATIO HAIR CREATED ===")
    print(f"Total Vertices: {total_verts}")
    print(f"Total Triangles: {total_tris}")

    # Remove temporary profile objects
    if prof_obj.name in bpy.data.objects:
        bpy.data.objects.remove(prof_obj, do_unlink=True)
    if prof_thin_obj.name in bpy.data.objects:
        bpy.data.objects.remove(prof_thin_obj, do_unlink=True)

    # 6. Save FBX and JSON
    out_dir = r"d:\Programming shi\infinite-tower\assets\hair"
    os.makedirs(out_dir, exist_ok=True)
    fbx_path = os.path.join(out_dir, "catio_hair.fbx")

    bpy.ops.object.select_all(action='DESELECT')
    joined.select_set(True)
    bpy.context.view_layer.objects.active = joined

    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        global_scale=1.0,
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_NONE',
        axis_forward='-Z',
        axis_up='Y',
        bake_space_transform=False,
        mesh_smooth_type='FACE',
        add_leaf_bones=False,
    )
    print(f"Exported FBX to: {fbx_path}")

    blend_path = os.path.join(out_dir, "hero_hair.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, copy=True)
    print(f"Saved blend file: {blend_path}")

    # Compute bounds in Roblox space: (X, Y up, -Z front) -> in Blender: (X, -Z, Y)
    # Roblox coords = (co.x, co.z, -co.y)
    verts_roblox = [[round(v.co.x, 4), round(v.co.z, 4), round(-v.co.y, 4)] for v in me.vertices]
    json_path = os.path.join(out_dir, "catio_hair.json")
    with open(json_path, "w") as f:
        json.dump(
            {"verts": verts_roblox, "tris": [list(t.vertices) for t in me.loop_triangles]},
            f,
            separators=(",", ":")
        )

    min_c = [min(v[i] for v in verts_roblox) for i in range(3)]
    max_c = [max(v[i] for v in verts_roblox) for i in range(3)]
    center = [round((min_c[i] + max_c[i]) / 2, 4) for i in range(3)]
    size = [round(max_c[i] - min_c[i], 4) for i in range(3)]
    print(f"ROBLOX_CENTER: {center}")
    print(f"ROBLOX_SIZE: {size}")

    return {
        "verts": total_verts,
        "tris": total_tris,
        "center": center,
        "size": size,
    }

if __name__ == "__main__":
    create_catio_hair()
