import bpy
import bmesh
import math
import os
import json
from mathutils import Vector

def create_aaron_hair_v2():
    # 1. Clean up old hair and reference objects
    for obj in list(bpy.data.objects):
        if obj.name.startswith("AaronHair") or obj.name in ("RobloxHeadRef", "HairProfile_Ridge"):
            bpy.data.objects.remove(obj, do_unlink=True)

    ref = bpy.data.objects.get("RefHead")
    if ref:
        ref.hide_set(False)
        ref.hide_render = False

    # 2. Material: Sandy Blonde (#DEC085) with smooth matte plastic finish
    mat = bpy.data.materials.get("AaronBlonde_DEC085") or bpy.data.materials.new(name="AaronBlonde_DEC085")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        # #DEC085 -> sRGB (0.871, 0.753, 0.522)
        bsdf.inputs["Base Color"].default_value = (0.871, 0.753, 0.522, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.55
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.5
        elif "Specular" in bsdf.inputs:
            bsdf.inputs["Specular"].default_value = 0.5

    # Coordinates in Blender space:
    # Origin (0, 0, 0) is head center.
    # +X = Right, -X = Left
    # +Y = Front (Face), -Y = Back
    # +Z = Up (Crown), -Z = Down (Neck)
    # Head cylinder: radius 0.6, height 1.2 (Z: -0.6 to +0.6)

    bm = bmesh.new()

    # -------------------------------------------------------------------------
    # Helper: Bezier evaluation
    # -------------------------------------------------------------------------
    def bez3(p0, p1, p2, t):
        a = (1.0 - t) ** 2
        b = 2.0 * (1.0 - t) * t
        c = t * t
        return Vector(p0) * a + Vector(p1) * b + Vector(p2) * c

    def bez4(p0, p1, p2, p3, t):
        a = (1.0 - t) ** 3
        b = 3.0 * ((1.0 - t) ** 2) * t
        c = 3.0 * (1.0 - t) * (t * t)
        d = t ** 3
        return Vector(p0) * a + Vector(p1) * b + Vector(p2) * c + Vector(p3) * d

    # -------------------------------------------------------------------------
    # Helper: Chunky hair lock with SHARP CENTRAL RIDGE (5-point diamond profile)
    # -------------------------------------------------------------------------
    def add_ridge_lock(pts, width, thick, ridge_height, out_hint, segs=8, tip_taper=2.0):
        """
        Creates a chunky lock with a sharp outer central ridge.
        Profile points:
          0: inner center (against scalp)
          1: left lateral edge
          2: sharp central ridge (crest)
          3: right lateral edge
        """
        rings = []
        is_cubic = len(pts) == 4

        for s in range(segs + 1):
            t = s / segs
            if is_cubic:
                p = bez4(pts[0], pts[1], pts[2], pts[3], t)
                t_next = min(1.0, t + 0.02)
                t_prev = max(0.0, t - 0.02)
                p_next = bez4(pts[0], pts[1], pts[2], pts[3], t_next)
                p_prev = bez4(pts[0], pts[1], pts[2], pts[3], t_prev)
            else:
                p = bez3(pts[0], pts[1], pts[2], t)
                t_next = min(1.0, t + 0.02)
                t_prev = max(0.0, t - 0.02)
                p_next = bez3(pts[0], pts[1], pts[2], t_next)
                p_prev = bez3(pts[0], pts[1], pts[2], t_prev)

            tan = (p_next - p_prev).normalized()
            side = tan.cross(Vector(out_hint))
            if side.length < 1e-4:
                side = tan.cross(Vector((0, 0, 1)))
            side.normalize()
            nrm = side.cross(tan).normalized()

            taper = max(0.04, 1.0 - t ** tip_taper)
            w = width * taper + 0.005
            h = thick * (0.6 + 0.4 * taper) * taper + 0.005
            rh = ridge_height * taper + 0.004

            # 5-point cross section: diamond with sharp crest
            ring_coords = [
                p - nrm * (h * 0.4),                # 0: inner scalp contact
                p + side * w,                       # 1: right edge
                p + nrm * h + (nrm * rh),           # 2: SHARP CENTRAL RIDGE
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
    # 1. BASE SCALP CAP (Full Coverage: Temples, Ears, Occipital, Nape)
    # -------------------------------------------------------------------------
    def add_scalp_dome(center, radii, keep, rings=16, segs=32):
        verts = {}
        for i in range(rings + 1):
            phi = math.pi * i / rings
            for j in range(segs):
                th = 2.0 * math.pi * j / segs
                # in Blender: X is right, Y is front, Z is up
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
    # 2. FRONT: CENTER-LEFT PARTED THICK CURTAIN BANGS & TWO CENTRAL STRANDS
    # -------------------------------------------------------------------------
    # Parting line sits at X ≈ 0.12, Y ≈ 0.35, Z ≈ 0.65

    # === Two small strands in the center (dipping between eyebrows) ===
    # Central strand 1 (dipping down slightly left of center)
    add_ridge_lock(
        [(-0.04, 0.40, 0.62), (-0.06, 0.68, 0.36), (-0.02, 0.68, 0.04)],
        width=0.10, thick=0.06, ridge_height=0.04, out_hint=(0, 1, -0.2), segs=8, tip_taper=2.0
    )
    # Central strand 2 (dipping down slightly right of center)
    add_ridge_lock(
        [(0.05, 0.40, 0.62), (0.07, 0.68, 0.38), (0.04, 0.67, 0.09)],
        width=0.09, thick=0.055, ridge_height=0.035, out_hint=(0.1, 1, -0.2), segs=8, tip_taper=2.0
    )

    # === Right Curtain Bang (Sweeping to character's right / viewer's left) ===
    # Main heavy curtain clump
    add_ridge_lock(
        [(0.02, 0.42, 0.65), (-0.18, 0.70, 0.48), (-0.38, 0.66, 0.12)],
        width=0.22, thick=0.10, ridge_height=0.06, out_hint=(-0.4, 1, -0.2), segs=9, tip_taper=1.8
    )
    # Secondary overlapping right curtain lock (volume layer)
    add_ridge_lock(
        [(-0.08, 0.38, 0.68), (-0.24, 0.72, 0.52), (-0.46, 0.62, 0.20)],
        width=0.19, thick=0.09, ridge_height=0.055, out_hint=(-0.5, 1, 0.1), segs=8, tip_taper=1.9
    )
    # Outer right forehead framing clump
    add_ridge_lock(
        [(-0.25, 0.36, 0.62), (-0.48, 0.62, 0.42), (-0.58, 0.52, 0.15)],
        width=0.20, thick=0.09, ridge_height=0.05, out_hint=(-0.7, 0.8, -0.1), segs=8, tip_taper=1.9
    )

    # === Left Curtain Bang (Sweeping to character's left / viewer's right from part) ===
    # Main heavy curtain clump
    add_ridge_lock(
        [(0.16, 0.42, 0.65), (0.32, 0.70, 0.46), (0.46, 0.64, 0.12)],
        width=0.22, thick=0.10, ridge_height=0.06, out_hint=(0.4, 1, -0.2), segs=9, tip_taper=1.8
    )
    # Secondary overlapping left curtain lock (volume layer)
    add_ridge_lock(
        [(0.22, 0.38, 0.68), (0.38, 0.72, 0.50), (0.52, 0.60, 0.20)],
        width=0.19, thick=0.09, ridge_height=0.055, out_hint=(0.5, 1, 0.1), segs=8, tip_taper=1.9
    )
    # Outer left forehead framing clump
    add_ridge_lock(
        [(0.35, 0.36, 0.62), (0.54, 0.60, 0.40), (0.62, 0.50, 0.15)],
        width=0.20, thick=0.09, ridge_height=0.05, out_hint=(0.7, 0.8, -0.1), segs=8, tip_taper=1.9
    )

    # -------------------------------------------------------------------------
    # 3. SIDES: CHEEK-FRAMING LOCKS & TEMPLE TUFTS (Covers ears down to Z=-0.48)
    # -------------------------------------------------------------------------
    for sgn in (-1, 1):
        # Front jaw/cheek-framing lock (reaches down to Z = -0.48)
        add_ridge_lock(
            [(0.58 * sgn, 0.32, 0.44), (0.80 * sgn, 0.42, 0.0), (0.68 * sgn, 0.36, -0.48)],
            width=0.20, thick=0.09, ridge_height=0.055, out_hint=(sgn, 0.4, -0.3), segs=8, tip_taper=1.8
        )
        # Mid-ear sideburn lock (reaches down to Z = -0.52)
        add_ridge_lock(
            [(0.66 * sgn, 0.10, 0.40), (0.88 * sgn, 0.12, -0.06), (0.72 * sgn, 0.08, -0.52)],
            width=0.21, thick=0.095, ridge_height=0.055, out_hint=(sgn, 0.1, 0), segs=8, tip_taper=1.8
        )
        # Lateral fluffy side flare (outward silhouette volume)
        add_ridge_lock(
            [(0.62 * sgn, 0.02, 0.52), (0.94 * sgn, 0.05, 0.22), (0.86 * sgn, -0.15, -0.22)],
            width=0.23, thick=0.10, ridge_height=0.06, out_hint=(sgn, 0.2, 0.2), segs=8, tip_taper=1.9
        )
        # Behind-ear framing lock
        add_ridge_lock(
            [(0.68 * sgn, -0.18, 0.36), (0.86 * sgn, -0.22, -0.10), (0.70 * sgn, -0.28, -0.50)],
            width=0.20, thick=0.09, ridge_height=0.05, out_hint=(sgn, -0.3, 0), segs=8, tip_taper=1.8
        )

    # -------------------------------------------------------------------------
    # 4. CROWN & TOP SPIKES (Messy, fluffy anime volume around parting)
    # -------------------------------------------------------------------------
    crown_spikes = [
        # (pts, width, thick, ridge_h, out_hint)
        # Upturned tuft at the parting (flicking up & right)
        ([(0.14, 0.10, 0.70), (0.24, 0.05, 1.05), (0.36, -0.15, 1.02)], 0.22, 0.10, 0.06, (0.3, 0.2, 1.0)),
        # Counter-tuft flicking up & left
        ([(-0.06, 0.12, 0.70), (-0.20, 0.08, 1.05), (-0.38, -0.12, 1.00)], 0.22, 0.10, 0.06, (-0.3, 0.2, 1.0)),
        # Forward crest flick
        ([(0.08, 0.28, 0.68), (0.10, 0.42, 0.98), (0.06, 0.48, 0.82)], 0.20, 0.09, 0.055, (0.1, 0.8, 0.5)),
        # High center-back spike
        ([(0.02, -0.05, 0.72), (0.05, -0.25, 1.08), (0.02, -0.52, 0.96)], 0.22, 0.10, 0.06, (0, -0.5, 1.0)),
        # Left lateral high flare
        ([(-0.35, 0.05, 0.64), (-0.68, -0.10, 0.86), (-0.82, -0.32, 0.54)], 0.22, 0.09, 0.055, (-0.8, -0.2, 0.5)),
        # Right lateral high flare
        ([(0.35, 0.05, 0.64), (0.68, -0.10, 0.86), (0.82, -0.32, 0.54)], 0.22, 0.09, 0.055, (0.8, -0.2, 0.5)),
        # Mid-crown messy fillers
        ([(-0.15, -0.15, 0.70), (-0.26, -0.35, 0.98), (-0.32, -0.55, 0.80)], 0.19, 0.085, 0.05, (-0.3, -0.6, 0.7)),
        ([(0.15, -0.15, 0.70), (0.26, -0.35, 0.98), (0.32, -0.55, 0.80)], 0.19, 0.085, 0.05, (0.3, -0.6, 0.7)),
    ]
    for pts, w, th, rh, out in crown_spikes:
        add_ridge_lock(pts, w, th, rh, out, segs=8, tip_taper=2.0)

    # -------------------------------------------------------------------------
    # 5. BACK: FEATHERED OCCIPITAL LOCKS (Layered coverage down the back)
    # -------------------------------------------------------------------------
    # High-occipital feathered locks (covers crown-to-back transition)
    for x in (-0.22, 0.22):
        add_ridge_lock(
            [(x, -0.22, 0.65), (x * 1.1, -0.52, 0.45), (x * 1.15, -0.68, 0.18)],
            width=0.22, thick=0.095, ridge_height=0.06, out_hint=(x * 0.3, -0.9, 0.2), segs=8, tip_taper=1.9
        )
    # Upper-occipital feathered layer (sweeping down the skull)
    for x in (-0.36, -0.18, 0.0, 0.18, 0.36):
        add_ridge_lock(
            [(x, -0.38, 0.52), (x * 1.15, -0.68, 0.25), (x * 1.25, -0.74, -0.12)],
            width=0.21, thick=0.09, ridge_height=0.055, out_hint=(x * 0.4, -1.0, -0.2), segs=8, tip_taper=1.9
        )
    # Mid-occipital feathered layer (overlapping lower skull)
    for x in (-0.28, 0.0, 0.28):
        add_ridge_lock(
            [(x, -0.50, 0.32), (x * 1.2, -0.76, -0.05), (x * 1.3, -0.78, -0.35)],
            width=0.22, thick=0.095, ridge_height=0.055, out_hint=(x * 0.5, -1.0, -0.3), segs=8, tip_taper=1.9
        )

    # -------------------------------------------------------------------------
    # 6. NAPE: SHORT SPIKY DUCKTAIL NAPE LOCKS (Flaring outward at bottom)
    # -------------------------------------------------------------------------
    # 6 short spiky ducktail flicks flaring out and slightly up/back
    ducktail_nape = [
        # Far-left nape flare
        ([(-0.42, -0.42, -0.15), (-0.60, -0.65, -0.38), (-0.66, -0.68, -0.55)], 0.19, 0.08, 0.045, (-0.8, -0.8, -0.2)),
        # Mid-left nape ducktail
        ([(-0.24, -0.48, -0.18), (-0.36, -0.75, -0.35), (-0.42, -0.82, -0.56)], 0.19, 0.08, 0.045, (-0.4, -1.0, -0.1)),
        # Center-left ducktail
        ([(-0.08, -0.52, -0.20), (-0.12, -0.78, -0.36), (-0.14, -0.84, -0.58)], 0.19, 0.08, 0.045, (-0.1, -1.0, 0.0)),
        # Center-right ducktail
        ([(0.08, -0.52, -0.20), (0.12, -0.78, -0.36), (0.14, -0.84, -0.58)], 0.19, 0.08, 0.045, (0.1, -1.0, 0.0)),
        # Mid-right nape ducktail
        ([(0.24, -0.48, -0.18), (0.36, -0.75, -0.35), (0.42, -0.82, -0.56)], 0.19, 0.08, 0.045, (0.4, -1.0, -0.1)),
        # Far-right nape flare
        ([(0.42, -0.42, -0.15), (0.60, -0.65, -0.38), (0.66, -0.68, -0.55)], 0.19, 0.08, 0.045, (0.8, -0.8, -0.2)),
    ]
    for pts, w, th, rh, out in ducktail_nape:
        add_ridge_lock(pts, w, th, rh, out, segs=7, tip_taper=1.7)

    # -------------------------------------------------------------------------
    # Clean up doubles and finalize mesh
    # -------------------------------------------------------------------------
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    me = bpy.data.meshes.new("AaronHair_V2")
    bm.to_mesh(me)
    bm.free()

    hair_obj = bpy.data.objects.new("AaronHair", me)
    bpy.context.collection.objects.link(hair_obj)
    hair_obj.data.materials.append(mat)

    for p in me.polygons:
        p.use_smooth = True

    # WeightedNormal modifier for clean studio specular roll-offs
    wn = hair_obj.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True

    total_tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print(f"AaronHair_V2 built! Vertices: {len(me.vertices)}, Triangles: {total_tris}")

    # -------------------------------------------------------------------------
    # Export FBX and JSON
    # -------------------------------------------------------------------------
    out_dir = r"D:\Programming shi\infinite-tower\assets\hair"
    bpy.ops.object.select_all(action="DESELECT")
    hair_obj.select_set(True)
    bpy.context.view_layer.objects.active = hair_obj

    fbx_path = os.path.join(out_dir, "aaron_hair.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        bake_space_transform=True,
    )
    print(f"Exported FBX: {fbx_path}")

    blend_path = os.path.join(out_dir, "hero_hair.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, copy=True)
    print(f"Saved blend file: {blend_path}")

    # Compute bounds in Roblox space: (X, Y up, -Z front) -> in Blender: (X, -Z, Y)
    # So Roblox coords = (co.x, co.z, -co.y)
    me.calc_loop_triangles()
    verts_roblox = [[round(v.co.x, 4), round(v.co.z, 4), round(-v.co.y, 4)] for v in me.vertices]
    json_path = os.path.join(out_dir, "aaron_hair.json")
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
        "verts": len(me.vertices),
        "tris": total_tris,
        "center": center,
        "size": size,
    }

if __name__ == "__main__":
    create_aaron_hair_v2()
