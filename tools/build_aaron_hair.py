import bpy
import bmesh
import math
import os
import json
from mathutils import Vector

def build_aaron_hair():
    # Clear existing AaronHair objects
    for name in ("AaronHair",):
        ob = bpy.data.objects.get(name)
        if ob:
            bpy.data.objects.remove(ob, do_unlink=True)

    vh = bpy.data.objects.get("VelkistHair")
    if vh:
        vh.hide_set(True)
        vh.hide_render = True
    ref = bpy.data.objects.get("RefHead")
    if ref:
        ref.hide_set(False)
        ref.hide_render = False

    # Coordinate mapping: Roblox (X, Y up, -Z front) -> Blender (X, -Z, Y)
    def B(p):
        return Vector((p[0], -p[2], p[1]))

    bm = bmesh.new()

    # Dome generator for scalp volume
    def dome(center, radii, keep, rings=16, segs=32):
        verts = {}
        for i in range(rings + 1):
            phi = math.pi * i / rings
            for j in range(segs):
                th = 2 * math.pi * j / segs
                x = radii[0] * math.sin(phi) * math.cos(th)
                y = radii[1] * math.cos(phi)
                z = radii[2] * math.sin(phi) * math.sin(th)
                if keep(x, y, z):
                    verts[(i, j)] = bm.verts.new(B((center[0] + x, center[1] + y, center[2] + z)))
        for i in range(rings):
            for j in range(segs):
                q = [(i, j), (i, (j + 1) % segs), (i + 1, (j + 1) % segs), (i + 1, j)]
                if all(k in verts for k in q):
                    bm.faces.new([verts[k] for k in q])

    # Quadratic Bézier evaluation
    def bez(p0, p1, p2, t):
        a, b, c = (1 - t) ** 2, 2 * (1 - t) * t, t * t
        return Vector(p0) * a + Vector(p1) * b + Vector(p2) * c

    # 6-point grooved strand lock
    def lock(root, ctrl, tip, width, thick, out_hint, segs=8, tip_taper=2.0, groove=0.35):
        rings = []
        for s in range(segs + 1):
            t = s / segs
            p = bez(root, ctrl, tip, t)
            tan = (bez(root, ctrl, tip, min(1.0, t + 0.02)) - bez(root, ctrl, tip, max(0.0, t - 0.02))).normalized()
            side = tan.cross(Vector(out_hint))
            if side.length < 1e-4:
                side = tan.cross(Vector((0, 0, 1)))
            side.normalize()
            nrm = side.cross(tan).normalized()
            taper = max(0.04, 1.0 - t ** tip_taper)
            w = width * taper + 0.005
            h = thick * (0.6 + 0.4 * taper) * taper + 0.005
            # 6-point grooved cross section
            ring = [
                p + side * w,
                p + nrm * h + side * (w * 0.4),
                p + nrm * (h * (1.0 - groove)), # indented groove
                p + nrm * h - side * (w * 0.4),
                p - side * w,
                p - nrm * (h * 0.5) # inner scalp side
            ]
            rings.append([bm.verts.new(B(v)) for v in ring])
        for a, b in zip(rings, rings[1:]):
            for k in range(6):
                bm.faces.new([a[k], a[(k + 1) % 6], b[(k + 1) % 6], b[k]])
        # Cap root and tip
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])

    # =========================================================================
    # 1. SCALP DOME (Full Coverage: Temples to y=-0.48, Nape to y=-0.58)
    # =========================================================================
    def scalp_keep(x, y, z):
        # Front face opening for anime face decal
        if z < -0.28 and abs(x) < 0.46:
            return y > 0.20
        # Sides over temples/ears: down to y = -0.48
        if abs(x) >= 0.46 and z < 0.15:
            return y > -0.48
        # Back & nape: down to y = -0.58
        if z >= 0.15:
            return y > -0.58
        return y > -0.48

    # Upper and mid scalp dome (slightly larger than 0.6 head radius: 0.71)
    dome((0, 0.08, 0.02), (0.71, 0.68, 0.72), scalp_keep, rings=16, segs=32)
    # Lower nape dome for full seamless back coverage
    dome((0, -0.06, 0.06), (0.71, 0.72, 0.68), lambda x, y, z: z > 0.02 and y > -0.60, rings=14, segs=28)

    # =========================================================================
    # 2. FRINGE / BANGS (Chunky, layered anime bangs matching reference)
    # =========================================================================
    # Layer 1 (Base fringe)
    fringe_l1 = [
        # (root, ctrl, tip, width, thick, out_hint)
        # Signature dipped center lock between eyebrows
        ((0.02, 0.70, -0.28), (0.00, 0.64, -0.84), (-0.02, -0.08, -0.72), 0.22, 0.09, (0, 0, -1)),
        # Left-center lock curving slightly
        ((-0.18, 0.68, -0.27), (-0.22, 0.62, -0.82), (-0.26, 0.02, -0.70), 0.20, 0.08, (-0.2, 0, -1)),
        # Right-center lock
        ((0.20, 0.68, -0.27), (0.28, 0.62, -0.82), (0.34, 0.04, -0.68), 0.20, 0.08, (0.2, 0, -1)),
        # Outer left forehead
        ((-0.36, 0.65, -0.24), (-0.54, 0.58, -0.76), (-0.56, 0.10, -0.64), 0.19, 0.08, (-0.4, 0, -1)),
        # Outer right forehead (part side)
        ((0.38, 0.65, -0.24), (0.52, 0.56, -0.74), (0.58, 0.12, -0.62), 0.19, 0.08, (0.4, 0, -1)),
    ]
    for r, c, t, w, th, out in fringe_l1:
        lock(r, c, t, w, th, out, segs=8, tip_taper=2.0)

    # Layer 2 (Raised volume locks on top of fringe)
    fringe_l2 = [
        # Center-left overlapping lock
        ((-0.08, 0.74, -0.24), (-0.10, 0.72, -0.86), (-0.12, 0.12, -0.76), 0.18, 0.08, (0, 0.2, -1)),
        # Center-right sweeping lock
        ((0.12, 0.74, -0.24), (0.16, 0.72, -0.86), (0.18, 0.15, -0.76), 0.18, 0.08, (0.1, 0.2, -1)),
        # Left brow accent lock
        ((-0.28, 0.72, -0.22), (-0.42, 0.66, -0.80), (-0.44, 0.20, -0.70), 0.17, 0.07, (-0.3, 0.2, -1)),
        # Right brow accent lock
        ((0.30, 0.72, -0.22), (0.44, 0.66, -0.78), (0.48, 0.22, -0.68), 0.17, 0.07, (0.3, 0.2, -1)),
    ]
    for r, c, t, w, th, out in fringe_l2:
        lock(r, c, t, w, th, out, segs=8, tip_taper=2.2)

    # =========================================================================
    # 3. SIDES & TEMPLE LOCKS (Ear-covering & Cheek-framing)
    # =========================================================================
    for sgn in (-1, 1):
        # Front cheek-framing lock (reaches down to y = -0.48)
        lock(
            (0.58 * sgn, 0.46, -0.28),
            (0.80 * sgn, 0.02, -0.44),
            (0.68 * sgn, -0.48, -0.38),
            0.20, 0.09, (sgn, 0.1, -0.3), segs=8, tip_taper=1.8
        )
        # Mid-ear sideburn lock (reaches down to y = -0.52)
        lock(
            (0.66 * sgn, 0.40, -0.05),
            (0.88 * sgn, -0.08, -0.15),
            (0.72 * sgn, -0.52, -0.10),
            0.21, 0.09, (sgn, 0, 0), segs=8, tip_taper=1.8
        )
        # Upper flared side tuft (silhouette volume)
        lock(
            (0.64 * sgn, 0.52, 0.05),
            (0.92 * sgn, 0.20, 0.08),
            (0.84 * sgn, -0.25, 0.18),
            0.22, 0.10, (sgn, 0.2, 0.2), segs=7, tip_taper=2.0
        )
        # Behind-ear framing lock
        lock(
            (0.68 * sgn, 0.36, 0.20),
            (0.86 * sgn, -0.12, 0.25),
            (0.70 * sgn, -0.50, 0.30),
            0.20, 0.09, (sgn, 0, 0.4), segs=8, tip_taper=1.8
        )

    # =========================================================================
    # 4. CROWN & TOP CLUMPS (Fluffy messy spikes matching reference render)
    # =========================================================================
    crown_locks = [
        # Up and back left
        ((-0.20, 0.74, -0.15), (-0.35, 1.08, 0.02), (-0.50, 1.00, 0.35), 0.23, 0.10, (-0.3, 1, 0.3)),
        # Up and back right
        ((0.18, 0.76, -0.18), (0.30, 1.10, -0.02), (0.45, 1.02, 0.30), 0.23, 0.10, (0.3, 1, 0.3)),
        # High center flick
        ((0.02, 0.78, 0.02), (0.06, 1.14, 0.22), (0.02, 0.98, 0.58), 0.22, 0.10, (0, 1, 0.5)),
        # Forward crest flick
        ((0.05, 0.75, -0.18), (0.08, 1.06, -0.36), (0.05, 0.88, -0.52), 0.21, 0.09, (0, 1, -0.4)),
        # Left high lateral spike
        ((-0.42, 0.66, 0.10), (-0.72, 0.88, 0.28), (-0.86, 0.54, 0.52), 0.22, 0.09, (-1, 0.8, 0.3)),
        # Right high lateral spike
        ((0.42, 0.66, 0.10), (0.72, 0.88, 0.28), (0.86, 0.54, 0.52), 0.22, 0.09, (1, 0.8, 0.3)),
        # Crown back volume
        ((0.00, 0.66, 0.32), (0.00, 0.86, 0.64), (0.04, 0.40, 0.84), 0.22, 0.09, (0, 0.5, 1)),
        # Secondary top left flick
        ((-0.15, 0.75, 0.10), (-0.25, 1.04, 0.28), (-0.32, 0.85, 0.54), 0.19, 0.08, (-0.2, 0.9, 0.4)),
        # Secondary top right flick
        ((0.15, 0.75, 0.10), (0.25, 1.04, 0.28), (0.32, 0.85, 0.54), 0.19, 0.08, (0.2, 0.9, 0.4)),
    ]
    for r, c, t, w, th, out in crown_locks:
        lock(r, c, t, w, th, out, segs=8, tip_taper=2.0)

    # =========================================================================
    # 5. BACK & NAPE FLICKS (Layered neck flares)
    # =========================================================================
    # Mid-back layer
    for x in (-0.32, 0.0, 0.32):
        lock(
            (x, 0.46, 0.46),
            (x * 1.15, 0.60, 0.72),
            (x * 1.30, 0.20, 0.86),
            0.20, 0.08, (x * 0.5, 0.2, 1.0), segs=8, tip_taper=1.9
        )
    # Lower nape layer (flicking out at neck line down to y = -0.58)
    for x in (-0.40, -0.20, 0.0, 0.20, 0.40):
        lock(
            (x, -0.18, 0.58),
            (x * 1.25, -0.42, 0.76),
            (x * 1.45, -0.58, 0.65),
            0.18, 0.07, (x * 0.8, -0.2, 1.0), segs=7, tip_taper=1.8
        )

    # Clean up doubles and normals
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

    me = bpy.data.meshes.new("AaronHair")
    bm.to_mesh(me)
    bm.free()

    hair = bpy.data.objects.new("AaronHair", me)
    bpy.context.collection.objects.link(hair)

    # Blond material for viewport preview
    hm = bpy.data.materials.get("HairBlond") or bpy.data.materials.new("HairBlond")
    hm.diffuse_color = (0.90, 0.76, 0.42, 1)
    me.materials.append(hm)

    for p in me.polygons:
        p.use_smooth = True

    # Add WeightedNormal modifier for crisp cel-shaded specular lines
    wn = hair.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
    wn.keep_sharp = True

    total_tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print(f"AaronHair generated! Verts: {len(me.vertices)}, Tris: {total_tris}")

    # =========================================================================
    # EXPORT FBX & JSON
    # =========================================================================
    out_dir = r"D:\Programming shi\infinite-tower\assets\hair"
    bpy.ops.object.select_all(action="DESELECT")
    hair.select_set(True)
    bpy.context.view_layer.objects.active = hair

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

    # Save hero_hair.blend
    blend_path = os.path.join(out_dir, "hero_hair.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path, copy=True)
    print(f"Saved blend file: {blend_path}")

    # Compute Roblox bounds: (X, Y up, -Z front) -> Blender is (X, -Z, Y)
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
    print(f"Exported JSON: {json_path}")

    min_c = [min(v[i] for v in verts_roblox) for i in range(3)]
    max_c = [max(v[i] for v in verts_roblox) for i in range(3)]
    center = [round((min_c[i] + max_c[i]) / 2, 4) for i in range(3)]
    size = [round(max_c[i] - min_c[i], 4) for i in range(3)]
    print(f"ROBLOX_BOUNDS_CENTER = {center}")
    print(f"ROBLOX_BOUNDS_SIZE = {size}")

    return {
        "verts": len(me.vertices),
        "tris": total_tris,
        "center": center,
        "size": size,
    }

if __name__ == "__main__":
    build_aaron_hair()
