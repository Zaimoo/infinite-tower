"""
Shurn's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

Built with chunky diamond-ridge Bezier locks (add_ridge_lock) and WeightedNormal shading:
  - Swept-back medium brown scholar hairstyle with an exposed forehead and a subtle widow's peak
    hairline curve.
  - One signature loose strand dipping down over the inner-left brow (viewer's right, -X in Blender,
    +X in Roblox).
  - Thick, voluminous crown waves swept up and back with subtle upturned tips.
  - Neatly swept-back temple locks, cropped tapered sideburns in front of the ears, and layered
    feathered occipital/nape locks with zero gaps.
"""

import bpy
import bmesh
import math
import os
import json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "ShurnHair"

for obj in list(bpy.data.objects):
    if obj.name.startswith("ShurnHair") or obj.name in ("Cube", "RobloxHeadRef", "HairProfile_Ridge"):
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

def add_ridge_lock(pts, width, thick, ridge_height, out_hint, segs=10, tip_taper=1.85, root_scale=0.82):
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

        grow = root_scale + (1.0 - root_scale) * min(1.0, t / 0.22)
        taper = max(0.03, grow * (1.0 - t ** tip_taper) * (1.0 + 0.14 * math.sin(math.pi * t)))
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
# 1. BASE SCALP CAP (Smoothly contoured, completely covers RefHead on top/back)
# -------------------------------------------------------------------------
def add_scalp_dome(center, radii, keep, rings=22, segs=44):
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
    # Exposed forehead in front (z > 0.36 at y = 0.72), sloping smoothly down to z > -0.34 at nape
    slope_limit = 0.02 + 0.44 * y
    return z > slope_limit

add_scalp_dome((0, 0.0, 0.08), (0.74, 0.75, 0.73), cap_filter, rings=22, segs=44)

# -------------------------------------------------------------------------
# 2. SWEPT-BACK FRONT HAIRLINE LOCKS (Organic curved hairline + diagonal sweep)
# -------------------------------------------------------------------------
# Note on front-camera coordinates: looking from +Y toward the origin, +X is viewer's LEFT
# (character's right) and -X is viewer's RIGHT (character's left).
# In the reference art, the hair sweeps diagonally up and toward viewer's RIGHT (-X),
# with the hanging strand and side tufts on viewer's RIGHT (-X).
swept_front = [
    # 1. Far-left temple-hairline sweep (viewer's left, +X)
    ([(0.48, 0.44, 0.40), (0.60, 0.42, 0.72), (0.54, 0.02, 0.86), (0.46, -0.44, 0.72)], 0.21, 0.095, 0.06, (0.55, 0.35, 0.85)),
    # 2. Outer-left hairline sweep (viewer's left, +X)
    ([(0.32, 0.52, 0.42), (0.42, 0.54, 0.78), (0.34, 0.10, 0.94), (0.28, -0.40, 0.82)], 0.21, 0.10, 0.065, (0.35, 0.45, 0.95)),
    # 3. Inner-left hairline sweep (dips slightly lower at the widow's peak root)
    ([(0.15, 0.57, 0.40), (0.22, 0.62, 0.82), (0.12, 0.16, 1.02), (0.08, -0.36, 0.90)], 0.22, 0.105, 0.065, (0.15, 0.5, 1.0)),
    # 4. Center widow's peak crest (sweeps up and slightly toward viewer's right -X, tallest wave)
    ([(-0.02, 0.58, 0.39), (-0.04, 0.65, 0.85), (-0.12, 0.18, 1.06), (-0.14, -0.34, 0.94)], 0.23, 0.11, 0.07, (-0.08, 0.5, 1.0)),
    # 5. Inner-right parting wave (arches up from the parting on viewer's right, -X)
    ([(-0.18, 0.55, 0.44), (-0.28, 0.60, 0.82), (-0.36, 0.14, 1.00), (-0.36, -0.36, 0.86)], 0.21, 0.10, 0.065, (-0.28, 0.45, 0.95)),
    # 6. Mid-right hairline sweep (flares slightly right -X and back)
    ([(-0.34, 0.50, 0.42), (-0.48, 0.52, 0.76), (-0.58, 0.08, 0.90), (-0.54, -0.38, 0.76)], 0.20, 0.095, 0.06, (-0.48, 0.4, 0.85)),
    # 7. Far-right temple-hairline sweep (viewer's right, -X)
    ([(-0.48, 0.42, 0.38), (-0.62, 0.40, 0.68), (-0.70, 0.00, 0.80), (-0.64, -0.42, 0.66)], 0.19, 0.09, 0.055, (-0.68, 0.3, 0.75)),
]
for pts, w, th, rh, out in swept_front:
    add_ridge_lock(pts, w, th, rh, out, segs=12, tip_taper=1.8, root_scale=0.78)

# -------------------------------------------------------------------------
# 3. SIGNATURE FOREHEAD STRAND (On viewer's right / character's left brow, -X in Blender)
# -------------------------------------------------------------------------
# In the reference art, a single prominent S-curved lock springs out from the right-of-center
# hairline (x ~ -0.15) and curves gracefully down over the right side of the forehead (-X),
# tapering to a sharp point just above his left eyebrow.
add_ridge_lock(
    [(-0.15, 0.55, 0.46), (-0.28, 0.73, 0.48), (-0.35, 0.75, 0.26), (-0.29, 0.70, 0.04)],
    width=0.115, thick=0.065, ridge_height=0.045, out_hint=(-0.25, 1.0, 0.05), segs=12, tip_taper=1.95, root_scale=0.72
)
# Subtle shorter hairline flick right next to the hanging strand (viewer's right, -X)
add_ridge_lock(
    [(-0.28, 0.51, 0.45), (-0.44, 0.68, 0.50), (-0.52, 0.63, 0.34)],
    width=0.095, thick=0.052, ridge_height=0.036, out_hint=(-0.45, 0.9, 0.2), segs=9, tip_taper=1.85, root_scale=0.72
)

# -------------------------------------------------------------------------
# 4. SECOND CROWN & UPPER-BACK LAYER (Seals crown-to-back & adds upturned tips)
# -------------------------------------------------------------------------
crown_waves = [
    # Left-center crown wave kicking slightly up at the rear crown (+X)
    ([(0.22, 0.04, 0.74), (0.28, -0.34, 1.02), (0.34, -0.68, 0.90)], 0.22, 0.10, 0.06, (0.25, -0.4, 1.0)),
    # Center crown wave kicking up at the apex
    ([(0.00, 0.06, 0.76), (-0.04, -0.32, 1.06), (-0.06, -0.68, 0.96)], 0.23, 0.105, 0.065, (-0.05, -0.4, 1.0)),
    # Right-center crown wave kicking up (-X)
    ([(-0.22, 0.04, 0.74), (-0.30, -0.34, 1.02), (-0.36, -0.68, 0.90)], 0.22, 0.10, 0.06, (-0.25, -0.4, 1.0)),
    # Right-side outward tuft 1 (matches the small upturned tufts on viewer's right -X in the art)
    ([(-0.36, 0.10, 0.68), (-0.64, -0.06, 0.90), (-0.82, -0.26, 0.80)], 0.19, 0.09, 0.055, (-0.7, -0.15, 0.75)),
    # Right-side outward tuft 2 (lower temple flick on viewer's right -X)
    ([(-0.48, 0.02, 0.54), (-0.76, -0.14, 0.68), (-0.90, -0.32, 0.56)], 0.18, 0.085, 0.05, (-0.85, -0.2, 0.5)),
    # Left-side neat swept wave (tighter on viewer's left +X as in the art)
    ([(0.38, 0.08, 0.66), (0.62, -0.12, 0.84), (0.74, -0.36, 0.70)], 0.20, 0.09, 0.055, (0.65, -0.25, 0.7)),
]
for pts, w, th, rh, out in crown_waves:
    add_ridge_lock(pts, w, th, rh, out, segs=9, tip_taper=1.75)

# -------------------------------------------------------------------------
# 5. TEMPLES & SIDEBURNS (Swept-back temple locks + tapered sideburns)
# -------------------------------------------------------------------------
for sgn in (-1, 1):
    # Upper temple swept-back lock (streams from temple back over the ear)
    add_ridge_lock(
        [(0.54 * sgn, 0.36, 0.38), (0.80 * sgn, 0.12, 0.44), (0.84 * sgn, -0.26, 0.32)],
        width=0.21, thick=0.095, ridge_height=0.055, out_hint=(sgn, 0.15, 0.3), segs=9, tip_taper=1.8
    )
    # Mid temple swept-back lock
    add_ridge_lock(
        [(0.58 * sgn, 0.22, 0.22), (0.82 * sgn, -0.04, 0.22), (0.84 * sgn, -0.42, 0.08)],
        width=0.21, thick=0.095, ridge_height=0.055, out_hint=(sgn, 0.05, 0.15), segs=9, tip_taper=1.8
    )
    # Lower temple / over-ear swept lock
    add_ridge_lock(
        [(0.60 * sgn, 0.04, 0.08), (0.82 * sgn, -0.22, 0.02), (0.80 * sgn, -0.54, -0.16)],
        width=0.21, thick=0.095, ridge_height=0.05, out_hint=(sgn, -0.15, 0.0), segs=9, tip_taper=1.8
    )
    # Tapered sideburn in front of the ear (descends cleanly along the cheek edge to Z = -0.32)
    add_ridge_lock(
        [(0.56 * sgn, 0.34, 0.30), (0.74 * sgn, 0.30, 0.00), (0.68 * sgn, 0.24, -0.32)],
        width=0.15, thick=0.075, ridge_height=0.045, out_hint=(sgn, 0.35, -0.1), segs=8, tip_taper=1.75
    )

# -------------------------------------------------------------------------
# 6. BACK & NAPE (4 overlapping occipital tiers from crown down to nape)
# -------------------------------------------------------------------------
# Tier 0: High crown-to-back bridge (covers upper occipital curve completely)
for x in (-0.36, -0.12, 0.12, 0.36):
    add_ridge_lock(
        [(x, -0.14, 0.72), (x * 1.15, -0.62, 0.68), (x * 1.25, -0.86, 0.42)],
        width=0.23, thick=0.10, ridge_height=0.06, out_hint=(x * 0.4, -0.9, 0.45), segs=9, tip_taper=1.8
    )

# Tier 1: Mid-upper occipital waves
for x in (-0.42, -0.21, 0.0, 0.21, 0.42):
    add_ridge_lock(
        [(x, -0.28, 0.56), (x * 1.18, -0.76, 0.42), (x * 1.26, -0.92, 0.12)],
        width=0.22, thick=0.095, ridge_height=0.06, out_hint=(x * 0.4, -1.0, 0.2), segs=9, tip_taper=1.8
    )

# Tier 2: Mid-lower occipital waves
for x in (-0.42, -0.21, 0.0, 0.21, 0.42):
    add_ridge_lock(
        [(x, -0.40, 0.34), (x * 1.18, -0.80, 0.12), (x * 1.24, -0.90, -0.18)],
        width=0.21, thick=0.09, ridge_height=0.055, out_hint=(x * 0.4, -1.0, 0.0), segs=8, tip_taper=1.8
    )

# Tier 3: Nape tapered tips
for x in (-0.42, -0.24, -0.08, 0.08, 0.24, 0.42):
    add_ridge_lock(
        [(x, -0.44, 0.08), (x * 1.15, -0.74, -0.16), (x * 1.20, -0.82, -0.40)],
        width=0.19, thick=0.08, ridge_height=0.048, out_hint=(x * 0.5, -1.0, -0.15), segs=7, tip_taper=1.7
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

COLOUR = (0.486, 0.345, 0.227, 1.0)  # Warm Medium Chestnut Brown (#7C583A)
mat = bpy.data.materials.get("ShurnHairBrown") or bpy.data.materials.new("ShurnHairBrown")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
if bsdf:
    bsdf.inputs[0].default_value = COLOUR
    bsdf.inputs["Roughness"].default_value = 0.46
mat.diffuse_color = COLOUR
me.materials.append(mat)

wn = hair.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
wn.keep_sharp = True

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print(NAME, "tris", tris)
