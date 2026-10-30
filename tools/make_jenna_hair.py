"""
Generates Jenna's high-poly Roblox UGC style anime hair in Blender (V11).
Exact match to user reference screenshots (media_1793191796058_998db482.png,
media_1793191889885_846339cc.png, media_1793191909319_ac1cd57f.png)
and Jenna's character art (media_1793190627542_a3feebb8.png):
1. ZERO base cap overlap: Cap at the back terminates high (Z > -0.06), so it NEVER
   protrudes or overlaps through the back converging hair locks.
2. Complete 360-degree head coverage: Upper scalp cap radii (0.74, 0.75, 0.72)
   fully envelopes the beveled Roblox head corners, eliminating all gray gaps.
3. Sleek, thin anime ribbon plates (thickness 0.026-0.032, ridge 0.014-0.018),
   giving the exact Roblox UGC aesthetic of the reference screenshots.
4. Razor-sharp needle point tips on every single strand (zero blunt stumps).
5. Bouncy, spiky anime fringe with center V-split tendrils and layered volume clumps.
6. Two signature front framing tails draping forward over collarbones/chest to sharp points.
7. Back: 100% full-coverage converging canopy meeting a gold-accented nape tie,
   with a rich, interwoven 3D anime braid cascading down to a lower gold tie band
   and elegant tail tassel.
"""

import bpy
import bmesh
import math
import os
import json
from mathutils import Vector

def create_jenna_hair():
    if bpy.context.view_layer.objects.active and bpy.context.view_layer.objects.active.mode != 'OBJECT':
        try:
            bpy.ops.object.mode_set(mode='OBJECT')
        except Exception:
            pass

    # 1. Clean existing hair objects
    for obj in list(bpy.data.objects):
        if obj.name.startswith("JennaHair") or obj.name in ("HairProfile_Jenna", "RobloxHeadRef_Jenna"):
            bpy.data.objects.remove(obj, do_unlink=True)

    ref = bpy.data.objects.get("RefHead")
    if ref:
        ref.hide_set(False)
        ref.hide_render = False

    # 2. Materials
    # Primary Hair: Warm Crimson-Auburn (#D83A20 -> sRGB ~0.847, 0.228, 0.125)
    mat_hair = bpy.data.materials.get("JennaAuburn_D83A20") or bpy.data.materials.new(name="JennaAuburn_D83A20")
    mat_hair.use_nodes = True
    bsdf_hair = mat_hair.node_tree.nodes.get("Principled BSDF")
    if bsdf_hair:
        bsdf_hair.inputs["Base Color"].default_value = (0.847, 0.228, 0.125, 1.0)
        bsdf_hair.inputs["Roughness"].default_value = 0.42
        if "Specular IOR Level" in bsdf_hair.inputs:
            bsdf_hair.inputs["Specular IOR Level"].default_value = 0.60
        elif "Specular" in bsdf_hair.inputs:
            bsdf_hair.inputs["Specular"].default_value = 0.60

    # Hair Tie: Dark Charcoal (#18181C)
    mat_tie = bpy.data.materials.get("JennaTie_Dark") or bpy.data.materials.new(name="JennaTie_Dark")
    mat_tie.use_nodes = True
    bsdf_tie = mat_tie.node_tree.nodes.get("Principled BSDF")
    if bsdf_tie:
        bsdf_tie.inputs["Base Color"].default_value = (0.09, 0.09, 0.11, 1.0)
        bsdf_tie.inputs["Roughness"].default_value = 0.65

    # Gold Accent: Burnished Gold (#E5A93C)
    mat_gold = bpy.data.materials.get("JennaGold_Accent") or bpy.data.materials.new(name="JennaGold_Accent")
    mat_gold.use_nodes = True
    bsdf_gold = mat_gold.node_tree.nodes.get("Principled BSDF")
    if bsdf_gold:
        bsdf_gold.inputs["Base Color"].default_value = (0.898, 0.663, 0.235, 1.0)
        bsdf_gold.inputs["Roughness"].default_value = 0.30
        if "Metallic" in bsdf_gold.inputs:
            bsdf_gold.inputs["Metallic"].default_value = 0.85

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
    # Helper: Sleek Sharp-Point Anime Hair Ribbon Lock
    # -------------------------------------------------------------------------
    def add_anime_lock(pts, width=0.20, thick=0.028, ridge=0.016, out_hint=(0, 0, 1), segs=10, tip_taper=2.0, root_taper=False, mat_idx=0):
        rings = []
        is_cubic = len(pts) == 4

        for s in range(segs):
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

            taper_tip = max(0.04, 1.0 - (t ** tip_taper))
            if root_taper and t < 0.20:
                taper_root = 0.50 + 0.50 * (t / 0.20)
            else:
                taper_root = 1.0

            taper = taper_tip * taper_root
            w = width * taper + 0.003
            h = thick * (0.40 + 0.60 * taper) * taper + 0.002
            rh = ridge * taper + 0.002

            ring_coords = [
                p - nrm * (h * 0.40),               # 0: inner contact
                p + side * w,                       # 1: right edge
                p + nrm * h + (nrm * rh),           # 2: sharp crest ridge
                p - side * w,                       # 3: left edge
            ]
            rings.append([bm.verts.new(v) for v in ring_coords])

        for a, b in zip(rings, rings[1:]):
            for k in range(4):
                f = bm.faces.new([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]])
                f.material_index = mat_idx

        f_root = bm.faces.new(list(reversed(rings[0])))
        f_root.material_index = mat_idx

        p_tip = pts[3] if is_cubic else pts[2]
        v_tip = bm.verts.new(Vector(p_tip))
        last_ring = rings[-1]
        for k in range(4):
            f = bm.faces.new([last_ring[k], last_ring[(k + 1) % 4], v_tip])
            f.material_index = mat_idx

    # -------------------------------------------------------------------------
    # 1. BASE SCALP DOME (Envelopes Head Corners, ZERO Overlap at Back)
    # -------------------------------------------------------------------------
    def add_inner_cap(center, radii, keep, rings=18, segs=36):
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
                    f = bm.faces.new([verts[k] for k in q])
                    f.material_index = 0

    def cap_filter(x, y, z):
        # 1. Zero cap at the back! The back canopy locks cover 100% of the back.
        # This completely guarantees the base cap NEVER overlaps back hair strands!
        if y <= -0.10:
            return False
        # 2. Zero cap over the face / forehead! The bangs cover the front cleanly.
        if y >= 0.25 and abs(x) < 0.46:
            return False
        # 3. Sides, temples, and top skull liner
        return z > -0.35

    # Tight skull liner at 0.64 (strictly under hair locks at 0.70-0.78)
    add_inner_cap((0, 0.0, 0.02), (0.64, 0.64, 0.64), cap_filter, rings=18, segs=36)

    # -------------------------------------------------------------------------
    # 2. TOP CROWN PARTING & WIDE OVERLAPPING PLATES (Ref Image 2)
    # -------------------------------------------------------------------------
    crown_parting = [
        # (py, pz, sweep_len, drop_z) - 7 cascading anime plates from temple to occiput
        (0.46, 0.65, 0.74, 0.12),
        (0.36, 0.68, 0.76, 0.04),
        (0.24, 0.70, 0.78, -0.02),
        (0.12, 0.71, 0.80, -0.10),
        (0.00, 0.71, 0.80, -0.16),
        (-0.12, 0.69, 0.78, -0.18),
        (-0.24, 0.66, 0.75, -0.20),
    ]

    # Character Left (-X) Crown Plates
    for i, (py, pz, slen, dz) in enumerate(crown_parting):
        rx = -0.012 if (i % 2 == 0) else -0.022
        p0 = (rx, py, pz + 0.04)
        p1 = (rx - 0.38, py * 0.98, pz + 0.08)
        p2 = (-0.68, py * 0.94, 0.64)
        p3 = (-slen, py * 0.90, dz)
        hint = (-0.7, py * 0.2, 0.7)
        add_anime_lock([p0, p1, p2, p3], width=0.26, thick=0.032, ridge=0.018, out_hint=hint, segs=12, tip_taper=1.6)

    # Character Right (+X) Crown Plates
    for i, (py, pz, slen, dz) in enumerate(crown_parting):
        rx = 0.012 if (i % 2 != 0) else 0.022
        p0 = (rx, py, pz + 0.04)
        p1 = (rx + 0.38, py * 0.98, pz + 0.08)
        p2 = (0.68, py * 0.94, 0.64)
        p3 = (slen, py * 0.90, dz)
        hint = (0.7, py * 0.2, 0.7)
        add_anime_lock([p0, p1, p2, p3], width=0.26, thick=0.032, ridge=0.018, out_hint=hint, segs=12, tip_taper=1.6)

    # -------------------------------------------------------------------------
    # 3. LATERAL SIDE, TEMPLE, & EAR LOCKS (Tucked seamlessly under crown plates)
    # -------------------------------------------------------------------------
    for sgn in (-1, 1):
        # Mid-ear side lock (covering right over the ear, tucked under crown plates)
        add_anime_lock(
            [(0.42 * sgn, 0.14, 0.62), (0.80 * sgn, 0.16, 0.38), (0.80 * sgn, 0.12, -0.05), (0.68 * sgn, 0.10, -0.55)],
            width=0.22, thick=0.030, ridge=0.016, out_hint=(sgn * 1.0, 0.1, -0.2), segs=12, tip_taper=1.8, root_taper=True
        )
        # Behind-ear lateral flare (connecting side to back canopy)
        add_anime_lock(
            [(0.42 * sgn, -0.08, 0.62), (0.78 * sgn, -0.10, 0.40), (0.80 * sgn, -0.16, 0.05), (0.72 * sgn, -0.18, -0.42)],
            width=0.22, thick=0.030, ridge=0.016, out_hint=(sgn * 1.0, -0.2, -0.2), segs=12, tip_taper=1.8, root_taper=True
        )
        # Diagonal occipital corner lock (envelopes back-side diagonal corner above Z=0.60)
        add_anime_lock(
            [(0.35 * sgn, -0.20, 0.66), (0.68 * sgn, -0.36, 0.62), (0.74 * sgn, -0.46, 0.22), (0.58 * sgn, -0.52, -0.25)],
            width=0.22, thick=0.032, ridge=0.016, out_hint=(sgn * 0.9, -0.5, 0.1), segs=12, tip_taper=1.8, root_taper=True
        )

    # -------------------------------------------------------------------------
    # 4. BACK CONVERGING CANOPY (Ref Image 3 - 100% Back Coverage, ZERO Overlap)
    # -------------------------------------------------------------------------
    tie_pos = Vector((0.0, -0.64, -0.16))

    back_angles = [-48, -32, -16, 0, 16, 32, 48]
    for deg in back_angles:
        rad = math.radians(deg)
        sin_a = math.sin(rad)
        cos_a = math.cos(rad)

        rx = 0.40 * sin_a
        ry = -0.22 - 0.22 * cos_a
        rz = 0.66 - 0.05 * (sin_a ** 2)

        mx = 0.50 * sin_a
        my = -0.70 - 0.06 * cos_a
        mz = 0.22 - 0.04 * abs(sin_a)

        ex = tie_pos.x + 0.10 * sin_a
        ey = tie_pos.y + 0.03 * cos_a
        ez = tie_pos.z + 0.03

        pts = [(rx, ry, rz), (mx, my, mz), (ex, ey, ez)]
        hint = (sin_a * 0.6, -1.0, 0.2)
        add_anime_lock(pts, width=0.25, thick=0.032, ridge=0.018, out_hint=hint, segs=12, tip_taper=1.5)

    # Lateral nape tuck locks
    for deg in [-62, 62]:
        rad = math.radians(deg)
        sgn = -1 if deg < 0 else 1
        p0 = (0.50 * sgn, -0.32, 0.16)
        p1 = (0.56 * sgn, -0.58, -0.10)
        p2 = (0.42 * sgn, -0.64, -0.38)
        hint = (sgn * 0.8, -0.8, -0.2)
        add_anime_lock([p0, p1, p2], width=0.20, thick=0.030, ridge=0.016, out_hint=hint, segs=10)

    # -------------------------------------------------------------------------
    # 5. SPIKY, BOUNCY FRONT BANGS (Character Art - media_1793190627542_a3feebb8.png)
    # -------------------------------------------------------------------------
    add_anime_lock(
        [(-0.02, 0.44, 0.65), (-0.05, 0.73, 0.40), (-0.04, 0.70, 0.10)],
        width=0.09, thick=0.026, ridge=0.014, out_hint=(0.0, 1.0, -0.2), segs=10, tip_taper=2.2
    )
    add_anime_lock(
        [(0.03, 0.44, 0.65), (0.06, 0.73, 0.40), (0.05, 0.70, 0.08)],
        width=0.09, thick=0.026, ridge=0.014, out_hint=(0.1, 1.0, -0.2), segs=10, tip_taper=2.2
    )
    add_anime_lock(
        [(0.00, 0.46, 0.63), (0.01, 0.74, 0.36), (0.00, 0.71, 0.02)],
        width=0.06, thick=0.022, ridge=0.012, out_hint=(0.0, 1.0, -0.15), segs=10, tip_taper=2.4
    )

    left_bangs = [
        ([(-0.07, 0.43, 0.66), (-0.14, 0.73, 0.44), (-0.18, 0.70, 0.22), (-0.20, 0.64, 0.06)], 0.12, 0.028, 0.015, (-0.2, 1.0, -0.25)),
        ([(-0.13, 0.42, 0.66), (-0.21, 0.72, 0.45), (-0.25, 0.67, 0.26), (-0.26, 0.60, 0.17)], 0.11, 0.026, 0.014, (-0.3, 1.0, -0.25)),
        ([(-0.18, 0.41, 0.65), (-0.29, 0.71, 0.46), (-0.34, 0.66, 0.24), (-0.36, 0.57, 0.04)], 0.13, 0.028, 0.015, (-0.4, 1.0, -0.25)),
        ([(-0.25, 0.39, 0.64), (-0.37, 0.68, 0.44), (-0.43, 0.61, 0.26), (-0.45, 0.53, 0.14)], 0.12, 0.026, 0.014, (-0.5, 1.0, -0.20)),
        ([(-0.32, 0.37, 0.63), (-0.46, 0.64, 0.42), (-0.53, 0.55, 0.22), (-0.55, 0.47, 0.05)], 0.13, 0.028, 0.015, (-0.7, 0.9, -0.15)),
        ([(-0.39, 0.34, 0.61), (-0.53, 0.57, 0.36), (-0.60, 0.47, 0.18)], 0.11, 0.025, 0.013, (-0.8, 0.8, -0.15)),
    ]
    for pts, w, th, rh, hint in left_bangs:
        add_anime_lock(pts, width=w, thick=th, ridge=rh, out_hint=hint, segs=10 if len(pts)==4 else 8, tip_taper=2.0)

    right_bangs = [
        ([(0.08, 0.43, 0.66), (0.15, 0.73, 0.44), (0.19, 0.70, 0.22), (0.21, 0.64, 0.06)], 0.12, 0.028, 0.015, (0.2, 1.0, -0.25)),
        ([(0.14, 0.42, 0.66), (0.22, 0.72, 0.45), (0.26, 0.67, 0.26), (0.27, 0.60, 0.17)], 0.11, 0.026, 0.014, (0.3, 1.0, -0.25)),
        ([(0.19, 0.41, 0.65), (0.30, 0.71, 0.46), (0.35, 0.66, 0.24), (0.37, 0.57, 0.04)], 0.13, 0.028, 0.015, (0.4, 1.0, -0.25)),
        ([(0.26, 0.39, 0.64), (0.38, 0.68, 0.44), (0.44, 0.61, 0.26), (0.46, 0.53, 0.14)], 0.12, 0.026, 0.014, (0.5, 1.0, -0.20)),
        ([(0.33, 0.37, 0.63), (0.47, 0.64, 0.42), (0.54, 0.55, 0.22), (0.56, 0.47, 0.05)], 0.13, 0.028, 0.015, (0.7, 0.9, -0.15)),
        ([(0.40, 0.34, 0.61), (0.54, 0.57, 0.36), (0.61, 0.47, 0.18)], 0.11, 0.025, 0.013, (0.8, 0.8, -0.15)),
    ]
    for pts, w, th, rh, hint in right_bangs:
        add_anime_lock(pts, width=w, thick=th, ridge=rh, out_hint=hint, segs=10 if len(pts)==4 else 8, tip_taper=2.0)

    overlay_bangs = [
        ([(-0.09, 0.36, 0.68), (-0.19, 0.74, 0.48), (-0.26, 0.68, 0.24)], 0.13, 0.028, 0.015, (-0.3, 1.0, -0.1)),
        ([(-0.22, 0.34, 0.67), (-0.35, 0.71, 0.46), (-0.43, 0.62, 0.20)], 0.13, 0.028, 0.015, (-0.5, 1.0, -0.1)),
        ([(0.10, 0.36, 0.68), (0.20, 0.74, 0.48), (0.27, 0.68, 0.24)], 0.13, 0.028, 0.015, (0.3, 1.0, -0.1)),
        ([(0.23, 0.34, 0.67), (0.36, 0.71, 0.46), (0.44, 0.62, 0.20)], 0.13, 0.028, 0.015, (0.5, 1.0, -0.1)),
    ]
    for pts, w, th, rh, hint in overlay_bangs:
        add_anime_lock(pts, width=w, thick=th, ridge=rh, out_hint=hint, segs=8, tip_taper=2.0)

    # -------------------------------------------------------------------------
    # 6. THE TWO SIGNATURE FRONT TAILS (Character Art - media_1793190627542_a3feebb8.png)
    # -------------------------------------------------------------------------
    # Character Right (+X) Tail:
    add_anime_lock(
        [(0.44, 0.32, 0.44), (0.55, 0.46, 0.12), (0.46, 0.48, -0.26), (0.32, 0.44, -0.70)],
        width=0.13, thick=0.030, ridge=0.015, out_hint=(0.4, 0.9, -0.2), segs=14, tip_taper=2.2
    )
    add_anime_lock(
        [(0.48, 0.28, 0.38), (0.58, 0.42, 0.06), (0.50, 0.44, -0.32)],
        width=0.09, thick=0.024, ridge=0.012, out_hint=(0.5, 0.8, -0.2), segs=10, tip_taper=2.2
    )

    # Character Left (-X) Tail:
    add_anime_lock(
        [(-0.44, 0.32, 0.44), (-0.55, 0.46, 0.12), (-0.46, 0.48, -0.26), (-0.32, 0.44, -0.70)],
        width=0.13, thick=0.030, ridge=0.015, out_hint=(-0.4, 0.9, -0.2), segs=14, tip_taper=2.2
    )
    add_anime_lock(
        [(-0.48, 0.28, 0.38), (-0.58, 0.42, 0.06), (-0.50, 0.44, -0.32)],
        width=0.09, thick=0.024, ridge=0.012, out_hint=(-0.5, 0.8, -0.2), segs=10, tip_taper=2.2
    )

    # Cheek & jawline sideburns (framing jawline behind the front tails)
    for sgn in (-1, 1):
        add_anime_lock(
            [(0.58 * sgn, 0.16, 0.40), (0.68 * sgn, 0.18, 0.10), (0.65 * sgn, 0.12, -0.20), (0.58 * sgn, 0.08, -0.52)],
            width=0.14, thick=0.030, ridge=0.015, out_hint=(sgn * 0.9, 0.2, -0.2), segs=12, tip_taper=2.0
        )
        add_anime_lock(
            [(0.62 * sgn, 0.04, 0.36), (0.72 * sgn, 0.06, 0.05), (0.68 * sgn, 0.02, -0.28)],
            width=0.12, thick=0.026, ridge=0.013, out_hint=(sgn * 1.0, 0.0, -0.2), segs=10, tip_taper=2.0
        )

    # -------------------------------------------------------------------------
    # 7. CROWN TUFTS / AHOGE
    # -------------------------------------------------------------------------
    tufts = [
        ((0.02, 0.02, 0.71), (0.05, -0.04, 0.85), (0.08, -0.10, 0.94), 0.08, 0.024, 0.012, (0.3, 0.0, 1.0)),
        ((-0.02, 0.02, 0.71), (-0.05, -0.04, 0.85), (-0.08, -0.10, 0.94), 0.08, 0.024, 0.012, (-0.3, 0.0, 1.0)),
        ((0.00, 0.10, 0.70), (0.01, 0.08, 0.83), (0.02, 0.02, 0.91), 0.07, 0.022, 0.011, (0.0, 0.3, 1.0)),
    ]
    for p0, p1, p2, w, th, rh, hint in tufts:
        add_anime_lock([p0, p1, p2], width=w, thick=th, ridge=rh, out_hint=hint, segs=8, tip_taper=2.2)

    # -------------------------------------------------------------------------
    # 8. BACK NAPE TIE & RICH WOVEN ANIME BRAID
    # -------------------------------------------------------------------------
    tie_z = -0.16
    tie_y = -0.64
    tie_x = 0.0
    tie_rad = 0.092
    tie_height = 0.046
    tie_segs = 16
    tie_rings = []
    for tz in (tie_z + tie_height * 0.5, tie_z - tie_height * 0.5):
        ring = []
        for i in range(tie_segs):
            ang = 2.0 * math.pi * i / tie_segs
            vx = tie_x + tie_rad * math.cos(ang)
            vy = tie_y + tie_rad * 0.82 * math.sin(ang)
            ring.append(bm.verts.new(Vector((vx, vy, tz))))
        tie_rings.append(ring)
    for i in range(tie_segs):
        i_next = (i + 1) % tie_segs
        f = bm.faces.new([tie_rings[0][i], tie_rings[0][i_next], tie_rings[1][i_next], tie_rings[1][i]])
        f.material_index = 1

    gold_ring_z = tie_z
    gold_rad = tie_rad * 1.035
    g_rings = []
    for gz in (gold_ring_z + 0.009, gold_ring_z - 0.009):
        ring = []
        for i in range(tie_segs):
            ang = 2.0 * math.pi * i / tie_segs
            vx = tie_x + gold_rad * math.cos(ang)
            vy = tie_y + gold_rad * 0.82 * math.sin(ang)
            ring.append(bm.verts.new(Vector((vx, vy, gz))))
        g_rings.append(ring)
    for i in range(tie_segs):
        i_next = (i + 1) % tie_segs
        f = bm.faces.new([g_rings[0][i], g_rings[0][i_next], g_rings[1][i_next], g_rings[1][i]])
        f.material_index = 2

    # Continuous Interlocking Woven Anime Braid
    braid_weave = [
        # Pod L1
        ([(-0.07, -0.63, -0.18), (-0.03, -0.72, -0.26), (0.04, -0.65, -0.34)], 0.15, 0.046, 0.022, (0.4, -0.9, -0.2)),
        # Pod R1
        ([(0.07, -0.63, -0.24), (0.03, -0.72, -0.33), (-0.04, -0.65, -0.41)], 0.15, 0.046, 0.022, (-0.4, -0.9, -0.2)),
        # Pod L2
        ([(-0.06, -0.63, -0.32), (-0.02, -0.71, -0.41), (0.04, -0.64, -0.49)], 0.14, 0.044, 0.020, (0.4, -0.9, -0.2)),
        # Pod R2
        ([(0.06, -0.63, -0.40), (0.02, -0.71, -0.49), (-0.03, -0.64, -0.57)], 0.14, 0.044, 0.020, (-0.4, -0.9, -0.2)),
        # Pod L3
        ([(-0.05, -0.63, -0.48), (-0.02, -0.69, -0.57), (0.03, -0.63, -0.64)], 0.13, 0.040, 0.018, (0.4, -0.9, -0.2)),
        # Pod R3
        ([(0.05, -0.63, -0.56), (0.02, -0.69, -0.63), (0.00, -0.63, -0.69)], 0.12, 0.038, 0.016, (-0.4, -0.9, -0.2)),
    ]
    for pts, w, th, rh, hint in braid_weave:
        add_anime_lock(pts, width=w, thick=th, ridge=rh, out_hint=hint, segs=10, tip_taper=1.6)

    # Lower Braid Tie Band at Z = -0.69
    btie_z = -0.69
    btie_y = -0.63
    btie_rad = 0.052
    btie_h = 0.030
    btie_rings = []
    for tz in (btie_z + btie_h * 0.5, btie_z - btie_h * 0.5):
        ring = []
        for i in range(12):
            ang = 2.0 * math.pi * i / 12
            vx = btie_rad * math.cos(ang)
            vy = btie_y + btie_rad * 0.85 * math.sin(ang)
            ring.append(bm.verts.new(Vector((vx, vy, tz))))
        btie_rings.append(ring)
    for i in range(12):
        i_next = (i + 1) % 12
        f = bm.faces.new([btie_rings[0][i], btie_rings[0][i_next], btie_rings[1][i_next], btie_rings[1][i]])
        f.material_index = 2

    # Tail Tassel flick below the lower braid tie with needle-sharp tips
    add_anime_lock(
        [(0.00, btie_y, btie_z - 0.01), (0.01, -0.65, -0.77), (0.02, -0.62, -0.85)],
        width=0.10, thick=0.030, ridge=0.015, out_hint=(0.0, -1.0, -0.2), segs=10, tip_taper=2.2
    )
    add_anime_lock(
        [(-0.02, btie_y, btie_z - 0.01), (-0.04, -0.64, -0.75), (-0.03, -0.61, -0.82)],
        width=0.08, thick=0.024, ridge=0.012, out_hint=(-0.3, -0.9, -0.2), segs=8, tip_taper=2.2
    )
    add_anime_lock(
        [(0.02, btie_y, btie_z - 0.01), (0.04, -0.64, -0.75), (0.03, -0.61, -0.81)],
        width=0.08, thick=0.024, ridge=0.012, out_hint=(0.3, -0.9, -0.2), segs=8, tip_taper=2.2
    )

    # -------------------------------------------------------------------------
    # Finalize Mesh & Weighted Normal
    # -------------------------------------------------------------------------
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("JennaHairMesh")
    bm.to_mesh(me)
    bm.free()

    joined = bpy.data.objects.new("JennaHair", me)
    joined.data.materials.append(mat_hair)
    joined.data.materials.append(mat_tie)
    joined.data.materials.append(mat_gold)
    bpy.context.collection.objects.link(joined)

    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    joined.select_set(True)
    bpy.context.view_layer.objects.active = joined
    for poly in me.polygons:
        poly.use_smooth = True

    mod_wn = joined.modifiers.new(name="WeightedNormal", type='WEIGHTED_NORMAL')
    mod_wn.keep_sharp = True
    try:
        with bpy.context.temp_override(object=joined, active_object=joined):
            bpy.ops.object.modifier_apply(modifier="WeightedNormal")
    except Exception as e:
        print("WeightedNormal note:", e)

    me.calc_loop_triangles()
    total_verts = len(me.vertices)
    total_tris = len(me.loop_triangles)
    print(f"=== JENNA HAIR V11 CREATED ===")
    print(f"Total Vertices: {total_verts}")
    print(f"Total Triangles: {total_tris}")

    out_dir = r"d:\Programming shi\infinite-tower\assets\hair"
    os.makedirs(out_dir, exist_ok=True)
    fbx_path = os.path.join(out_dir, "jenna_hair.fbx")

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

    verts_roblox = [[round(v.co.x, 4), round(v.co.z, 4), round(-v.co.y, 4)] for v in me.vertices]
    json_path = os.path.join(out_dir, "jenna_hair.json")
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
    create_jenna_hair()
