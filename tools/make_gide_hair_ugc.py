"""
Gide's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

Built with chunky diamond-ridge Bezier locks (add_ridge_lock) and WeightedNormal shading:
  - Distinct from Han's flat, downward-hanging shag and Aaron's wide curtain bangs.
  - Rugged, multi-layered spiky shonen brow fringe with overlapping upper-forehead spikes.
  - Full temple and ear coverage with stacked outward-flaring lateral spikes.
  - Clean standing crown cowlick spikes and feathered spiky occipital/nape layers.
"""

import bpy
import bmesh
import math
import os
import json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "GideHair"

for obj in list(bpy.data.objects):
    if obj.name.startswith("GideHair") or obj.name in ("Cube", "RobloxHeadRef", "HairProfile_Ridge"):
        bpy.data.objects.remove(obj, do_unlink=True)
for obj in bpy.data.objects:
    if obj.name.endswith("Hair") and obj.name != NAME:
        obj.hide_set(True)

# Reference head (the in-game rounded head, authored size 1.2).
if not bpy.data.objects.get("RefHead"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.6, depth=1.2, location=(0, 0, 0))
    head = bpy.context.active_object
    head.name = "RefHead"
    bev = head.modifiers.new("Bevel", "BEVEL"); bev.width = 0.18; bev.segments = 5
    skin = bpy.data.materials.new("RefSkin"); skin.diffuse_color = (0.95, 0.8, 0.7, 1)
    head.data.materials.append(skin)
    bpy.ops.object.shade_smooth()

ref = bpy.data.objects.get("RefHead")
if ref:
    ref.hide_set(False)
    ref.hide_render = False

bm = bmesh.new()

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

def add_ridge_lock(pts, width, thick, ridge_height, out_hint, segs=10, tip_taper=1.85):
    """
    Creates a chunky sculpted anime lock with a sharp outer central crest ridge.
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

        taper = max(0.03, (1.0 - t ** tip_taper) * (1.0 + 0.16 * math.sin(math.pi * t)))
        w = width * taper + 0.004
        h = thick * (0.6 + 0.4 * taper) * taper + 0.004
        rh = ridge_height * taper + 0.004

        ring_coords = [
            p - nrm * (h * 0.45),               # 0: inner scalp contact
            p + side * w,                       # 1: right edge
            p + nrm * h + (nrm * rh),           # 2: SHARP CENTRAL RIDGE
            p - side * w,                       # 3: left edge
        ]
        rings.append([bm.verts.new(v) for v in ring_coords])

    for a, b in zip(rings, rings[1:]):
        for k in range(4):
            bm.faces.new([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])

# -------------------------------------------------------------------------
# 1. BASE SCALP CAP (Smoothly contoured so no square step ever pokes out)
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
    # Smoothly sloped cutoff from front brow (z > 0.28) down to back nape (z > -0.32)
    # so there is no stair-step anywhere on the temples, cheeks, or behind the ear.
    slope_limit = -0.02 + 0.32 * y
    return z > slope_limit

add_scalp_dome((0, 0.0, 0.08), (0.73, 0.74, 0.71), cap_filter, rings=20, segs=40)

# -------------------------------------------------------------------------
# 2. FRONT: JAGGED MULTI-LAYERED SHONEN BROW SPIKES
# -------------------------------------------------------------------------
front_lower_spikes = [
    # Far-left temple-brow spike
    ([(-0.24, 0.34, 0.64), (-0.50, 0.64, 0.42), (-0.64, 0.56, 0.06)], 0.21, 0.095, 0.06, (-0.65, 0.9, -0.1)),
    # Mid-left brow spike
    ([(-0.10, 0.38, 0.66), (-0.28, 0.70, 0.44), (-0.38, 0.68, 0.08)], 0.20, 0.095, 0.06, (-0.35, 1.0, -0.15)),
    # Center-left main spike (dips toward inner left brow, angled left)
    ([(0.02, 0.40, 0.66), (-0.06, 0.73, 0.42), (-0.12, 0.72, 0.04)], 0.19, 0.095, 0.06, (-0.1, 1.0, -0.2)),
    # Center-right spike (angled right, leaving a crisp V-notch over the bridge of the nose)
    ([(0.08, 0.40, 0.66), (0.15, 0.73, 0.44), (0.20, 0.71, 0.11)], 0.19, 0.095, 0.06, (0.18, 1.0, -0.15)),
    # Mid-right brow spike
    ([(0.16, 0.38, 0.66), (0.35, 0.70, 0.46), (0.46, 0.65, 0.12)], 0.20, 0.095, 0.06, (0.42, 1.0, -0.15)),
    # Far-right temple-brow spike
    ([(0.26, 0.34, 0.64), (0.52, 0.64, 0.42), (0.64, 0.56, 0.08)], 0.21, 0.095, 0.06, (0.65, 0.9, -0.1)),
]
for pts, w, th, rh, out in front_lower_spikes:
    add_ridge_lock(pts, w, th, rh, out, segs=9, tip_taper=1.75)

# Upper forehead overlapping spikes (second shorter spiky tier on top of the bangs)
front_upper_spikes = [
    ([(-0.16, 0.22, 0.72), (-0.38, 0.62, 0.62), (-0.54, 0.70, 0.34)], 0.20, 0.09, 0.055, (-0.45, 1.0, 0.3)),
    ([(0.00, 0.24, 0.74), (-0.08, 0.66, 0.64), (-0.16, 0.78, 0.36)], 0.19, 0.09, 0.055, (-0.1, 1.0, 0.35)),
    ([(0.10, 0.24, 0.74), (0.22, 0.66, 0.64), (0.32, 0.76, 0.36)], 0.19, 0.09, 0.055, (0.25, 1.0, 0.35)),
    ([(0.20, 0.22, 0.72), (0.44, 0.60, 0.60), (0.60, 0.66, 0.34)], 0.20, 0.09, 0.055, (0.55, 0.9, 0.3)),
]
for pts, w, th, rh, out in front_upper_spikes:
    add_ridge_lock(pts, w, th, rh, out, segs=8, tip_taper=1.7)

# -------------------------------------------------------------------------
# 3. SIDES: FULL TEMPLE COVERAGE + THREE STACKED OUTWARD-FLARING SPIKES
# -------------------------------------------------------------------------
for sgn in (-1, 1):
    # Front temple bridge spike (seals gap between outer bang and sideburn)
    add_ridge_lock(
        [(0.42 * sgn, 0.28, 0.58), (0.72 * sgn, 0.50, 0.32), (0.76 * sgn, 0.44, -0.12)],
        width=0.22, thick=0.095, ridge_height=0.055, out_hint=(sgn, 0.65, -0.1), segs=9, tip_taper=1.75
    )
    # Sharp cropped sideburn in front of the ear (down to Z = -0.32)
    add_ridge_lock(
        [(0.52 * sgn, 0.18, 0.52), (0.80 * sgn, 0.26, 0.12), (0.74 * sgn, 0.22, -0.32)],
        width=0.22, thick=0.095, ridge_height=0.055, out_hint=(sgn, 0.35, -0.15), segs=9, tip_taper=1.75
    )
    # Mid-ear lower coverage spike (seals the side scalp completely)
    add_ridge_lock(
        [(0.58 * sgn, -0.02, 0.44), (0.84 * sgn, 0.00, 0.06), (0.80 * sgn, -0.06, -0.34)],
        width=0.23, thick=0.095, ridge_height=0.055, out_hint=(sgn, 0.0, -0.1), segs=9, tip_taper=1.75
    )
    # Tier 1 (Upper-side bold spike flaring wide out above temple)
    add_ridge_lock(
        [(0.36 * sgn, 0.08, 0.68), (0.76 * sgn, 0.12, 0.64), (1.00 * sgn, 0.02, 0.44)],
        width=0.23, thick=0.10, ridge_height=0.06, out_hint=(sgn, 0.15, 0.6), segs=9, tip_taper=1.7
    )
    # Tier 2 (Mid-side bold outward spike flaring out over the ear)
    add_ridge_lock(
        [(0.48 * sgn, -0.04, 0.56), (0.86 * sgn, -0.08, 0.34), (1.04 * sgn, -0.20, 0.08)],
        width=0.24, thick=0.105, ridge_height=0.065, out_hint=(sgn, -0.1, 0.35), segs=9, tip_taper=1.7
    )
    # Tier 3 (Lower-side outward spike kicking out behind the ear)
    add_ridge_lock(
        [(0.56 * sgn, -0.18, 0.38), (0.86 * sgn, -0.28, 0.08), (0.96 * sgn, -0.40, -0.24)],
        width=0.22, thick=0.095, ridge_height=0.055, out_hint=(sgn, -0.3, 0.1), segs=8, tip_taper=1.7
    )
    # Behind-ear transition spike
    add_ridge_lock(
        [(0.52 * sgn, -0.32, 0.48), (0.82 * sgn, -0.52, 0.22), (0.90 * sgn, -0.64, -0.12)],
        width=0.22, thick=0.095, ridge_height=0.055, out_hint=(sgn, -0.6, 0.2), segs=8, tip_taper=1.75
    )

# -------------------------------------------------------------------------
# 4. CROWN & TOP SPIKES (Clean, non-curling upward/outward shonen spikes)
# -------------------------------------------------------------------------
crown_spikes = [
    # Center-left standing cowlick spike (sweeping up and left)
    ([(0.04, 0.06, 0.68), (-0.14, 0.02, 0.94), (-0.34, -0.08, 1.06)], 0.22, 0.10, 0.06, (-0.4, 0.1, 1.0)),
    # Center-right standing cowlick spike (sweeping up and right)
    ([(-0.04, 0.04, 0.68), (0.16, 0.00, 0.96), (0.38, -0.10, 1.08)], 0.22, 0.10, 0.06, (0.4, 0.1, 1.0)),
    # Front-crown uplifted crest (sweeping up and slightly left-forward, no downward hook)
    ([(0.04, 0.18, 0.68), (-0.04, 0.32, 0.90), (-0.12, 0.42, 0.98)], 0.20, 0.095, 0.055, (-0.2, 0.7, 0.8)),
    # Rear-tilted tall crown spike
    ([(0.00, -0.06, 0.68), (0.00, -0.32, 0.96), (0.00, -0.62, 1.02)], 0.23, 0.105, 0.065, (0.0, -0.5, 1.0)),
    # Upper-left diagonal crown spike
    ([(-0.18, -0.02, 0.68), (-0.50, -0.12, 0.90), (-0.82, -0.26, 0.82)], 0.23, 0.10, 0.06, (-0.7, -0.2, 0.7)),
    # Upper-right diagonal crown spike
    ([(0.18, -0.02, 0.68), (0.50, -0.12, 0.90), (0.82, -0.26, 0.82)], 0.23, 0.10, 0.06, (0.7, -0.2, 0.7)),
    # Back-left high crown spike
    ([(-0.16, -0.16, 0.68), (-0.38, -0.46, 0.88), (-0.60, -0.76, 0.74)], 0.22, 0.095, 0.06, (-0.5, -0.7, 0.6)),
    # Back-right high crown spike
    ([(0.16, -0.16, 0.68), (0.38, -0.46, 0.88), (0.60, -0.76, 0.74)], 0.22, 0.095, 0.06, (0.5, -0.7, 0.6)),
]
for pts, w, th, rh, out in crown_spikes:
    add_ridge_lock(pts, w, th, rh, out, segs=9, tip_taper=1.75)

# -------------------------------------------------------------------------
# 5. BACK & NAPE: LAYERED OCCIPITAL SPIKES & OUTWARD DUCKTAIL TIPS
# -------------------------------------------------------------------------
for x in (-0.34, -0.12, 0.12, 0.34):
    add_ridge_lock(
        [(x, -0.32, 0.56), (x * 1.25, -0.74, 0.42), (x * 1.45, -0.92, 0.16)],
        width=0.23, thick=0.10, ridge_height=0.06, out_hint=(x * 0.5, -1.0, 0.3), segs=8, tip_taper=1.75
    )

for x in (-0.42, -0.20, 0.0, 0.20, 0.42):
    add_ridge_lock(
        [(x, -0.44, 0.34), (x * 1.22, -0.82, 0.12), (x * 1.35, -0.94, -0.16)],
        width=0.23, thick=0.095, ridge_height=0.06, out_hint=(x * 0.5, -1.0, 0.0), segs=8, tip_taper=1.75
    )

for x in (-0.44, -0.26, -0.09, 0.09, 0.26, 0.44):
    add_ridge_lock(
        [(x, -0.46, 0.04), (x * 1.22, -0.76, -0.20), (x * 1.36, -0.88, -0.42)],
        width=0.20, thick=0.085, ridge_height=0.05, out_hint=(x * 0.6, -1.0, -0.1), segs=7, tip_taper=1.65
    )

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

me = bpy.data.meshes.new(NAME)
bm.to_mesh(me)
bm.free()

for p in me.polygons:
    p.use_smooth = True

hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

COLOUR = (0.424, 0.282, 0.188, 1.0)  # Warm Brown (#6C4830)
mat = bpy.data.materials.get("GideHairBrown") or bpy.data.materials.new("GideHairBrown")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
if bsdf:
    bsdf.inputs[0].default_value = COLOUR
    bsdf.inputs["Roughness"].default_value = 0.48
mat.diffuse_color = COLOUR
me.materials.append(mat)

wn = hair.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
wn.keep_sharp = True

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print(NAME, "tris", tris)
