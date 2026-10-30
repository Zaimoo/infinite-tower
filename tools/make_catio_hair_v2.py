"""
Generates Catio's high-poly Roblox UGC style anime hair in Blender using direct bmesh geometry.
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

def create_catio_hair_v2():
    # 1. Clean existing hair objects
    for obj in list(bpy.data.objects):
        if obj.name.startswith("CatioHair") or obj.name in ("HairProfile_Catio", "RobloxHeadRef_Catio"):
            bpy.data.objects.remove(obj, do_unlink=True)

    ref = bpy.data.objects.get("RefHead")
    if ref:
        ref.hide_set(False)
        ref.hide_render = False

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

    # Coordinates in Blender space:
    # Origin (0,0,0) is head center.
    # +X = Right, -X = Left
    # +Y = Front (Face), -Y = Back
    # +Z = Up (Crown), -Z = Down (Neck)
    # Head cylinder: radius 0.6, height 1.2 (Z: -0.6 to +0.6)

    bm = bmesh.new()

    # -------------------------------------------------------------------------
    # Helper: Bezier curves
    # -------------------------------------------------------------------------
    def bez3(p0, p1, p2, t):
        a = (1.0 - t) ** 2
        b = 2.0 * (1.0 - t) * t
        c = t * t
        return Vector(p0) * a + Vector(p1) * b + Vector(p2) * c

    def bez4(p0, p1, p2, p3, t):
        a = (1.0 - t) ** 3
        b = 3.0 * (1.0 - t) ** 2 * t
        c = 3.0 * (1.0 - t) * t * t
        d = t ** 3
        return Vector(p0) * a + Vector(p1) * b + Vector(p2) * c + Vector(p3) * d

    # -------------------------------------------------------------------------
    # Helper: High-Poly Crested Hair Lock
    # -------------------------------------------------------------------------
    def add_ridge_lock(pts, width, thick, ridge_height, out_hint, segs=10, tip_taper=2.0):
        """
        Creates a high-poly stylized anime lock with a sharp outer crest ridge.
        Cross section:
          0: Inner base (against scalp)
          1: Right outer edge
          2: Sharp central crest ridge
          3: Left outer edge
        """
        rings = []
        is_cubic = len(pts) == 4

        for s in range(segs + 1):
            t = s / segs
            if is_cubic:
                p = bez4(pts[0], pts[1], pts[2], pts[3], t)
                t_next = min(1.0, t + 0.015)
                t_prev = max(0.0, t - 0.015)
                p_next = bez4(pts[0], pts[1], pts[2], pts[3], t_next)
                p_prev = bez4(pts[0], pts[1], pts[2], pts[3], t_prev)
            else:
                p = bez3(pts[0], pts[1], pts[2], t)
                t_next = min(1.0, t + 0.015)
                t_prev = max(0.0, t - 0.015)
                p_next = bez3(pts[0], pts[1], pts[2], t_next)
                p_prev = bez3(pts[0], pts[1], pts[2], t_prev)

            tan = (p_next - p_prev).normalized()
            hint = Vector(out_hint)
            side = tan.cross(hint)
            if side.length < 1e-4:
                side = tan.cross(Vector((0, 0, 1)))
            side.normalize()
            nrm = side.cross(tan).normalized()

            taper = max(0.03, 1.0 - t ** tip_taper)
            w = width * taper + 0.006
            h = thick * (0.6 + 0.4 * taper) * taper + 0.006
            rh = ridge_height * taper + 0.005

            ring_coords = [
                p - nrm * (h * 0.45),               # 0: inner scalp contact
                p + side * w,                       # 1: right edge
                p + nrm * h + (nrm * rh),           # 2: sharp crest ridge
                p - side * w,                       # 3: left edge
            ]
            rings.append([bm.verts.new(v) for v in ring_coords])

        for a, b in zip(rings, rings[1:]):
            for k in range(4):
                bm.faces.new([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]])
        # Cap root
        bm.faces.new(list(reversed(rings[0])))
        # Cap tip
        bm.faces.new(rings[-1])

    # -------------------------------------------------------------------------
    # 1. FULL-COVERAGE BASE SCALP DOME (Envelopes Head Cylinder Completely)
    # -------------------------------------------------------------------------
    def add_scalp_dome(center, radii, keep, rings=18, segs=36):
        verts = {}
        for i in range(rings + 1):
            phi = math.pi * i / rings
            for j in range(segs):
                th = 2.0 * math.pi * j / segs
                x = radii[0] * math.sin(phi) * math.cos(th)
                y = radii[1] * math.sin(phi) * math.sin(th)
                z = radii[2] * math.cos(phi)
                if keep(x, y, z):
                    verts[(i, j)] = bm.verts.new(Vector((center[0] + x, center[1] + y, center[2] + z)))
        for i in range(rings):
            for j in range(segs):
                q = [(i, j), (i, (j + 1) % segs), (i + 1, (j + 1) % segs), (i + 1, j)]
                if all(k in verts for k in q):
                    bm.faces.new([verts[k] for k in q])

    def cap_filter(x, y, z):
        # Face cutout: opening for eyebrows and eyes
        if y > 0.30 and abs(x) < 0.44:
            return z > 0.20
        # Temples and over-ear sides: must go down to z = -0.46
        if abs(x) >= 0.44 and y > -0.15:
            return z > -0.46
        # Occipital and nape: down to z = -0.56
        if y <= -0.15:
            return z > -0.56
        return z > -0.46

    # Upper scalp cap (covers upper and mid skull, slightly enlarged to 0.74/0.75 to fully envelope beveled head corners)
    add_scalp_dome((0, 0.0, 0.06), (0.74, 0.75, 0.72), cap_filter, rings=18, segs=36)
    # Lower occipital/nape base shell to guarantee 100% back coverage
    add_scalp_dome((0, -0.06, -0.05), (0.74, 0.72, 0.74), lambda x, y, z: y < 0.0 and z > -0.60, rings=16, segs=32)

    # -------------------------------------------------------------------------
    # 2. CENTER-LEFT PARTED CURTAIN BANGS (Fringe)
    # -------------------------------------------------------------------------
    # Parting line sits at X ≈ -0.05, Y ≈ 0.42, Z ≈ 0.65
    # Main sweeping left curtain bang (thick, curving over brow towards left cheek)
    add_ridge_lock(
        [(-0.06, 0.42, 0.65), (-0.26, 0.72, 0.48), (-0.46, 0.68, 0.24), (-0.54, 0.56, 0.04)],
        width=0.22, thick=0.10, ridge_height=0.06, out_hint=(-0.4, 1.0, -0.2), segs=12
    )
    # Left secondary overlapping outer bang (volume layer)
    add_ridge_lock(
        [(-0.16, 0.38, 0.68), (-0.36, 0.72, 0.50), (-0.52, 0.64, 0.20)],
        width=0.20, thick=0.09, ridge_height=0.055, out_hint=(-0.5, 1.0, 0.1), segs=10
    )
    # Left outer forehead framing clump
    add_ridge_lock(
        [(-0.28, 0.36, 0.62), (-0.52, 0.62, 0.40), (-0.62, 0.50, 0.12)],
        width=0.21, thick=0.09, ridge_height=0.055, out_hint=(-0.7, 0.8, -0.1), segs=10
    )

    # Main sweeping right curtain bang (thick, sweeping to the right over brow)
    add_ridge_lock(
        [(0.02, 0.42, 0.65), (0.24, 0.72, 0.48), (0.44, 0.68, 0.24), (0.52, 0.56, 0.04)],
        width=0.22, thick=0.10, ridge_height=0.06, out_hint=(0.4, 1.0, -0.2), segs=12
    )
    # Right secondary overlapping outer bang (volume layer)
    add_ridge_lock(
        [(0.12, 0.38, 0.68), (0.34, 0.72, 0.50), (0.50, 0.64, 0.20)],
        width=0.20, thick=0.09, ridge_height=0.055, out_hint=(0.5, 1.0, 0.1), segs=10
    )
    # Right outer forehead framing clump
    add_ridge_lock(
        [(0.26, 0.36, 0.62), (0.50, 0.62, 0.40), (0.60, 0.50, 0.12)],
        width=0.21, thick=0.09, ridge_height=0.055, out_hint=(0.7, 0.8, -0.1), segs=10
    )

    # Center dipping forehead strands (falling between eyes down towards nose bridge)
    add_ridge_lock(
        [(-0.04, 0.44, 0.63), (-0.06, 0.72, 0.38), (-0.03, 0.70, 0.04)],
        width=0.11, thick=0.06, ridge_height=0.035, out_hint=(0.0, 1.0, -0.2), segs=10
    )
    add_ridge_lock(
        [(0.01, 0.44, 0.63), (0.04, 0.72, 0.36), (0.02, 0.70, 0.02)],
        width=0.11, thick=0.06, ridge_height=0.035, out_hint=(0.0, 1.0, -0.2), segs=10
    )
    # Delicate micro-tendril dipping right between eyes
    add_ridge_lock(
        [(-0.01, 0.46, 0.62), (0.00, 0.73, 0.34), (0.00, 0.70, -0.04)],
        width=0.06, thick=0.04, ridge_height=0.025, out_hint=(0.0, 1.0, -0.1), segs=10
    )

    # -------------------------------------------------------------------------
    # 3. LONG JAW / CHEST FRAMING SIDE LOCKS (Catio's signature framing)
    # -------------------------------------------------------------------------
    for sgn in (-1, 1):
        # Long jaw/chest-framing lock (reaches down to Z = -0.74, past the chin)
        add_ridge_lock(
            [(0.45 * sgn, 0.36, 0.58), (0.76 * sgn, 0.44, 0.18), (0.78 * sgn, 0.40, -0.22), (0.66 * sgn, 0.34, -0.74)],
            width=0.22, thick=0.095, ridge_height=0.06, out_hint=(sgn * 0.8, 0.5, -0.3), segs=14
        )
        # Mid-ear sideburn lock (reaches down to Z = -0.70)
        add_ridge_lock(
            [(0.55 * sgn, 0.14, 0.52), (0.84 * sgn, 0.16, 0.12), (0.82 * sgn, 0.12, -0.26), (0.68 * sgn, 0.14, -0.70)],
            width=0.22, thick=0.095, ridge_height=0.06, out_hint=(sgn * 1.0, 0.1, -0.2), segs=14
        )
        # Outer temple volume lock (covering the front-side beveled corner)
        add_ridge_lock(
            [(0.38 * sgn, 0.38, 0.64), (0.68 * sgn, 0.52, 0.38), (0.75 * sgn, 0.44, 0.05), (0.65 * sgn, 0.38, -0.35)],
            width=0.21, thick=0.09, ridge_height=0.055, out_hint=(sgn * 0.8, 0.6, -0.2), segs=12
        )
        # Fluffy lateral anime flare (outward volume)
        add_ridge_lock(
            [(0.42 * sgn, -0.06, 0.60), (0.82 * sgn, -0.04, 0.28), (0.86 * sgn, -0.08, -0.02), (0.76 * sgn, -0.06, -0.38)],
            width=0.21, thick=0.09, ridge_height=0.055, out_hint=(sgn * 1.0, -0.2, -0.2), segs=12
        )

    # -------------------------------------------------------------------------
    # 4. CROWN VOLUME & STYLIZED UGC FLYAWAY STRANDS (Top)
    # -------------------------------------------------------------------------
    # Crown tufts arching up and back
    add_ridge_lock(
        [(-0.08, 0.24, 0.68), (-0.18, 0.16, 0.80), (-0.28, 0.04, 0.78), (-0.38, -0.10, 0.68)],
        width=0.19, thick=0.085, ridge_height=0.05, out_hint=(-0.4, 0.3, 0.7), segs=10
    )
    add_ridge_lock(
        [(0.05, 0.24, 0.68), (0.16, 0.16, 0.80), (0.26, 0.04, 0.78), (0.36, -0.10, 0.68)],
        width=0.19, thick=0.085, ridge_height=0.05, out_hint=(0.4, 0.3, 0.7), segs=10
    )
    add_ridge_lock(
        [(-0.02, 0.16, 0.70), (0.00, 0.02, 0.82), (0.00, -0.16, 0.78), (0.00, -0.32, 0.66)],
        width=0.20, thick=0.090, ridge_height=0.055, out_hint=(0.0, 0.1, 0.8), segs=10
    )
    add_ridge_lock(
        [(-0.14, 0.00, 0.69), (-0.26, -0.10, 0.78), (-0.36, -0.26, 0.70)],
        width=0.17, thick=0.08, ridge_height=0.045, out_hint=(-0.5, -0.2, 0.7), segs=8
    )
    add_ridge_lock(
        [(0.12, 0.00, 0.69), (0.24, -0.10, 0.78), (0.34, -0.26, 0.70)],
        width=0.17, thick=0.08, ridge_height=0.045, out_hint=(0.5, -0.2, 0.7), segs=8
    )

    # UGC Signature Ahoge / Floating Flyaways (thin, elegant floating S-curves)
    add_ridge_lock(
        [(-0.02, 0.26, 0.70), (-0.05, 0.18, 0.90), (0.02, 0.06, 0.95), (0.08, -0.10, 0.88), (0.14, -0.22, 0.76)],
        width=0.060, thick=0.035, ridge_height=0.020, out_hint=(0.2, 0.4, 0.8), segs=12
    )
    add_ridge_lock(
        [(-0.10, 0.22, 0.70), (-0.18, 0.14, 0.86), (-0.26, 0.02, 0.85), (-0.34, -0.12, 0.74)],
        width=0.050, thick=0.030, ridge_height=0.018, out_hint=(-0.4, 0.3, 0.7), segs=10
    )
    add_ridge_lock(
        [(0.08, 0.22, 0.70), (0.16, 0.14, 0.86), (0.24, 0.02, 0.85), (0.32, -0.12, 0.74)],
        width=0.050, thick=0.030, ridge_height=0.018, out_hint=(0.4, 0.3, 0.7), segs=10
    )

    # -------------------------------------------------------------------------
    # 5. VOLUMINOUS LAYERED BACK & OCCIPITAL CANOPY (Covering back to hood line)
    # -------------------------------------------------------------------------
    # Tier 1 (High Occipital - Upper Crown to Back Transition)
    for x in (-0.24, 0.0, 0.24):
        add_ridge_lock(
            [(x, -0.18, 0.68), (x * 1.1, -0.48, 0.52), (x * 1.15, -0.66, 0.26)],
            width=0.23, thick=0.095, ridge_height=0.06, out_hint=(x * 0.3, -0.9, 0.2), segs=10
        )
    # Tier 2 (Upper Occipital Sweeping Down)
    for x in (-0.38, -0.19, 0.0, 0.19, 0.38):
        add_ridge_lock(
            [(x, -0.34, 0.56), (x * 1.15, -0.66, 0.30), (x * 1.25, -0.74, -0.06)],
            width=0.22, thick=0.09, ridge_height=0.055, out_hint=(x * 0.4, -1.0, -0.2), segs=10
        )
    # Tier 3 (Mid Occipital Layer)
    for x in (-0.30, 0.0, 0.30):
        add_ridge_lock(
            [(x, -0.46, 0.36), (x * 1.2, -0.74, 0.02), (x * 1.3, -0.78, -0.32)],
            width=0.23, thick=0.095, ridge_height=0.055, out_hint=(x * 0.5, -1.0, -0.3), segs=10
        )

    # Tier 4 (Cascading Nape & Shoulder Tips - Draping outward over shoulders/hood)
    nape_locks = [
        ([(-0.44, -0.40, -0.12), (-0.62, -0.65, -0.38), (-0.68, -0.68, -0.68)], 0.21, 0.085, 0.05, (-0.8, -0.8, -0.2)),
        ([(-0.26, -0.46, -0.15), (-0.38, -0.75, -0.36), (-0.44, -0.82, -0.72)], 0.21, 0.085, 0.05, (-0.4, -1.0, -0.1)),
        ([(-0.09, -0.50, -0.18), (-0.13, -0.78, -0.38), (-0.15, -0.84, -0.74)], 0.21, 0.085, 0.05, (-0.1, -1.0, 0.0)),
        ([(0.09, -0.50, -0.18), (0.13, -0.78, -0.38), (0.15, -0.84, -0.74)], 0.21, 0.085, 0.05, (0.1, -1.0, 0.0)),
        ([(0.26, -0.46, -0.15), (0.38, -0.75, -0.36), (0.44, -0.82, -0.72)], 0.21, 0.085, 0.05, (0.4, -1.0, -0.1)),
        ([(0.44, -0.40, -0.12), (0.62, -0.65, -0.38), (0.68, -0.68, -0.68)], 0.21, 0.085, 0.05, (0.8, -0.8, -0.2)),
    ]
    for pts, w, th, rh, out in nape_locks:
        add_ridge_lock(pts, w, th, rh, out, segs=10, tip_taper=1.8)

    # Finalize BMesh and build Object
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("CatioHair")
    bm.to_mesh(me)
    bm.free()

    joined = bpy.data.objects.new("CatioHair", me)
    joined.data.materials.append(mat)
    bpy.context.collection.objects.link(joined)

    # Smooth shading & Weighted Normal
    bpy.ops.object.select_all(action='DESELECT')
    joined.select_set(True)
    bpy.context.view_layer.objects.active = joined
    bpy.ops.object.shade_smooth()

    mod_wn = joined.modifiers.new(name="WeightedNormal", type='WEIGHTED_NORMAL')
    mod_wn.keep_sharp = True
    bpy.ops.object.modifier_apply(modifier="WeightedNormal")

    me.calc_loop_triangles()
    total_verts = len(me.vertices)
    total_tris = len(me.loop_triangles)
    print(f"=== CATIO HAIR V2 CREATED ===")
    print(f"Total Vertices: {total_verts}")
    print(f"Total Triangles: {total_tris}")

    # Save FBX and JSON
    out_dir = r"d:\Programming shi\infinite-tower\assets\hair"
    os.makedirs(out_dir, exist_ok=True)
    fbx_path = os.path.join(out_dir, "catio_hair.fbx")

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
    create_catio_hair_v2()
