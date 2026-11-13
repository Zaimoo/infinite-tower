"""
Rhyman's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

A swept-back dirty-blond cut in the manner of UGC male hair: a full, smooth mass that hugs
the head, built from many slim layered locks instead of a few big spikes.
  - A bare forehead with a low quiff: the front locks lift a little off the hairline and flow
    back over the crown, with two stray strands on the brow.
  - Two layers over the top, the upper one shorter, so the surface reads as combed clumps.
  - Sides falling down and back over the ears, and a layered back that reaches the collar. A few short tufts break the outline; nothing stands up as a spike.

Uses the diamond-ridge locks from tools/make_gide_hair_ugc.py (add_ridge_lock), here slim and
blunt-tipped, and WeightedNormal shading. Blender coordinates: +Y is the face's front, +Z is
up, centred on the 1.2-stud reference head.
"""

import math
import random

import bmesh
import bpy
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "RhymanHair"

rng = random.Random(6017)

for obj in list(bpy.data.objects):
    if obj.name.startswith("RhymanHair") or obj.name in ("Cube", "RobloxHeadRef", "HairProfile_Ridge"):
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
    """A chunky sculpted anime lock with a sharp crest ridge down its outer face."""
    rings = []
    curve = bez4 if len(pts) == 4 else bez3
    for s in range(segs + 1):
        t = s / segs
        p = curve(*pts, t)
        tan = (curve(*pts, min(1.0, t + 0.02)) - curve(*pts, max(0.0, t - 0.02))).normalized()
        side = tan.cross(Vector(out_hint))
        if side.length < 1e-4:
            side = tan.cross(Vector((0, 0, 1)))
        side.normalize()
        nrm = side.cross(tan).normalized()

        taper = max(0.03, (1.0 - t ** tip_taper) * (1.0 + 0.16 * math.sin(math.pi * t)))
        w = width * taper + 0.004
        h = thick * (0.6 + 0.4 * taper) * taper + 0.004
        rh = ridge_height * taper + 0.004
        ring = [
            p - nrm * (h * 0.45),  # inner scalp contact
            p + side * w,  # right edge
            p + nrm * h + (nrm * rh),  # the crest ridge
            p - side * w,  # left edge
        ]
        rings.append([bm.verts.new(v) for v in ring])

    for a, b in zip(rings, rings[1:]):
        for k in range(4):
            bm.faces.new([a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def jit(amount):
    return rng.uniform(-amount, amount)


def lock(pts, width, out, thick=0.07, ridge=0.014, segs=12, taper=3.4):
    # A high taper exponent keeps a lock full along its length and closes it in a short,
    # blunt tip (a combed clump, not a spike).
    add_ridge_lock(pts, width, thick, ridge, out, segs=segs, tip_taper=taper)


# -------------------------------------------------------------------------
# 1. SCALP CAP: a high hairline in front (bare forehead), down to the nape behind.
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
    # Hairline at z ~0.36 over the brow, sloping to z ~-0.40 at the nape.
    return z > -0.02 + 0.52 * y


add_scalp_dome((0, -0.03, 0.09), (0.76, 0.79, 0.75), cap_filter, rings=20, segs=40)

# -------------------------------------------------------------------------
# 2. TOP: two layers combed from the hairline back over the crown.
# -------------------------------------------------------------------------
def top_lock(u, layer):
    """u in -1..1 across the head. Layer 0 runs hairline to the back of the crown; layer 1
    sits on top of it, starts further back and ends sooner."""
    drop = 0.14 * u * u
    lean = 0.05  # the whole top leans a touch to his left
    if layer == 0:
        pts = [
            (0.50 * u, 0.56 - 0.10 * u * u, 0.44),
            (0.56 * u + lean, 0.60 - 0.12 * u * u, 0.84 - drop + jit(0.015)),
            (0.66 * u + lean, -0.30, 0.90 - drop),
            (0.70 * u + lean, -0.88 + jit(0.04), 0.52 - drop + jit(0.04)),
        ]
        lock(pts, 0.25, (u * 0.7, 0.2, 1.0))
    else:
        pts = [
            (0.44 * u, 0.30, 0.74 - drop),
            (0.52 * u + lean, 0.16, 0.96 - drop + jit(0.015)),
            (0.60 * u + lean, -0.36, 0.95 - drop),
            (0.64 * u + lean, -0.74 + jit(0.05), 0.72 - drop + jit(0.04)),
        ]
        lock(pts, 0.21, (u * 0.7, 0.1, 1.0), thick=0.065)


for k in range(9):
    top_lock(-1 + 2 * k / 8, 0)
for k in range(8):
    top_lock(-0.875 + 2 * k / 8, 1)

# The quiff: three short locks rolled up and back off the middle of the hairline.
for x, lift in ((-0.16, 0.95), (0.02, 1.0), (0.2, 0.96)):
    lock([(x, 0.54, 0.46), (x * 1.1 + 0.03, 0.72, 0.80), (x * 1.2 + 0.07, 0.34, lift)], 0.2, (x, 0.5, 1.0), thick=0.075, segs=10)
# Two stray strands on the brow.
lock([(-0.08, 0.56, 0.46), (-0.20, 0.76, 0.44), (-0.16, 0.73, 0.22)], 0.07, (-0.2, 1.0, 0.0), thick=0.045, ridge=0.02, segs=8, taper=1.8)
lock([(0.10, 0.56, 0.46), (0.20, 0.74, 0.48), (0.24, 0.72, 0.32)], 0.06, (0.2, 1.0, 0.0), thick=0.04, ridge=0.02, segs=8, taper=1.8)

# -------------------------------------------------------------------------
# 3. SIDES: combed back past the ears, close to the head.
# -------------------------------------------------------------------------
for sgn in (-1, 1):
    # A curtain falling down and back from the edge of the top, each lock overlapping the
    # next, so the side is one combed surface that covers the top of the ear.
    for k in range(5):
        back = 0.21 * k
        lock(
            [(0.54 * sgn, 0.30 - back, 0.66), (0.84 * sgn, 0.20 - back, 0.40), (0.86 * sgn, 0.02 - back, 0.04), (0.80 * sgn, -0.16 - back + jit(0.03), -0.24 - 0.07 * k + jit(0.03))],
            0.24, (sgn, 0.1, 0.2),
        )
    # A short sideburn in front of the ear.
    lock([(0.58 * sgn, 0.30, 0.20), (0.71 * sgn, 0.32, -0.02), (0.67 * sgn, 0.28, -0.22)], 0.11, (sgn, 0.4, -0.1), thick=0.06, segs=8, taper=1.9)

# -------------------------------------------------------------------------
# 4. BACK: two layers down to the collar, the ends turned out a little.
# -------------------------------------------------------------------------
for k in range(7):
    x = -0.54 + 1.08 * k / 6
    lock(
        [(x, -0.56, 0.44), (x * 1.12, -0.90, 0.20), (x * 1.14, -0.92, -0.14), (x * 1.2, -1.0 + jit(0.03), -0.34 + jit(0.04))],
        0.25, (x * 0.5, -1.0, 0.1),
    )
for k in range(8):
    x = -0.56 + 1.12 * k / 7
    lock(
        [(x, -0.56, 0.06), (x * 1.1, -0.84, -0.20), (x * 1.1, -0.84, -0.48), (x * 1.22, -0.96 + jit(0.03), -0.68 + jit(0.05))],
        0.23, (x * 0.6, -1.0, -0.1), thick=0.065,
    )

# -------------------------------------------------------------------------
# 5. TUFTS: a few short ends lifting off the surface, so the outline is not a helmet.
# -------------------------------------------------------------------------
tufts = [
    ([(-0.22, -0.40, 0.90), (-0.34, -0.66, 1.00), (-0.42, -0.90, 0.96)], (-0.3, -0.5, 1.0)),
    ([(0.26, -0.30, 0.90), (0.40, -0.56, 1.02), (0.52, -0.80, 0.98)], (0.3, -0.5, 1.0)),
    ([(0.04, -0.62, 0.78), (0.06, -0.92, 0.80), (0.08, -1.12, 0.68)], (0.0, -1.0, 0.6)),
]
for pts, out in tufts:
    lock(pts, 0.14, out, thick=0.06, segs=9, taper=2.2)

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

me = bpy.data.meshes.new(NAME)
bm.to_mesh(me)
bm.free()

for p in me.polygons:
    p.use_smooth = True

hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

COLOUR = (0.769, 0.627, 0.353, 1.0)  # dirty blond (#C4A05A)
mat = bpy.data.materials.get("RhymanHairBlond") or bpy.data.materials.new("RhymanHairBlond")
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
