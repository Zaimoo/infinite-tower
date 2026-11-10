"""
Gide's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

From his reference art: short, thick, messy dark-brown anime hair. Spiky bangs fall to the
brows with two pointed central strands dipping over the bridge of the nose, temple locks
frame the face down to the cheekbones, short cropped layers cover the sides and nape with
outward-flicking tips, and tousled locks fan out from the crown with short lifted spikes on
top and at the upper sides.

Same construction as tools/make_jenna_hair_ugc.py: ribbon locks with a centre ridge over a full
scalp cap, in Roblox head space on a 1.2-stud reference head. Export with the hero-remodel
skill's scripts/blender_export_hair.py (docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random, os, json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "GideHair"
rng = random.Random(419)

for ob in list(bpy.data.objects):
    if ob.name == NAME or ob.name == "Cube":
        bpy.data.objects.remove(ob, do_unlink=True)
for ob in bpy.data.objects:
    if ob.name.endswith("Hair") and ob.name != NAME:
        ob.hide_set(True)

# Reference head (the in-game rounded head, authored size 1.2).
if not bpy.data.objects.get("RefHead"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.6, depth=1.2, location=(0, 0, 0))
    head = bpy.context.active_object
    head.name = "RefHead"
    bev = head.modifiers.new("Bevel", "BEVEL"); bev.width = 0.18; bev.segments = 5
    skin = bpy.data.materials.new("RefSkin"); skin.diffuse_color = (0.95, 0.8, 0.7, 1)
    head.data.materials.append(skin)
    bpy.ops.object.shade_smooth()

def B(p):
    return Vector((p[0], -p[2], p[1]))

# Scalp shell: an ellipsoid on top, a straight cylinder below its equator.
CX, CY, CZ = 0.0, 0.16, 0.04
RX, RY, RZ = 0.7, 0.76, 0.71

def shell(theta, y, off=0.0):
    """Point on the scalp at azimuth theta (0 = front, +90 deg = his right, +X) and height y."""
    k = 1.0 if y <= CY else math.sqrt(max(0.0, 1 - ((y - CY) / RY) ** 2))
    k = max(k, 0.06)
    x = (RX + off) * k * math.sin(theta)
    z = CZ - (RZ + off) * k * math.cos(theta)
    yy = min(y, CY + RY + off)
    return Vector((CX + x, yy + (off * 0.6 if y > CY else 0), z))

def out_normal(p):
    axis = Vector((CX, min(p.y, CY), CZ))
    n = p - axis
    return n.normalized() if n.length > 1e-5 else Vector((0, 1, 0))

bm = bmesh.new()

# --- Scalp cap: full coverage under the locks ---------------------------------------------
def cap():
    rings, segs = 22, 44
    verts = {}
    for i in range(rings + 1):
        y = CY + RY - (RY + 0.95) * i / rings  # top down to well below the equator
        for j in range(segs):
            th = 2 * math.pi * j / segs
            front = math.cos(th) > 0.74  # the face opening; the temples stay covered
            limit = 0.3 if front else (-0.12 if math.cos(th) > -0.2 else -0.3)
            if y < limit:
                continue
            verts[(i, j)] = bm.verts.new(B(shell(th, y, -0.01)))
    for i in range(rings):
        for j in range(segs):
            q = [(i, j), (i, (j + 1) % segs), (i + 1, (j + 1) % segs), (i + 1, j)]
            if all(k in verts for k in q):
                bm.faces.new([verts[k] for k in q])
cap()

# --- Ribbon lock ---------------------------------------------------------------------------
# Thin plate with a raised centre ridge (the UGC strand look); narrow root, needle tip.
PROFILE = [(1.0, 0.0), (0.55, 0.42), (0.0, 0.8), (-0.55, 0.42), (-1.0, 0.0), (0.0, -0.35)]

def smooth_path(pts, n):
    """Catmull-Rom resample of control points into n+1 points."""
    P = [Vector(p) for p in pts]
    P = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    out = []
    seg = len(P) - 3
    for s in range(n + 1):
        u = s / n * seg
        i = min(int(u), seg - 1)
        t = u - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    return out

def ribbon(ctrl, width, thick=0.035, segs=16, tip=2.2, root=0.55, end_tie=False, twist=0.0):
    pts = smooth_path(ctrl, segs)
    rings = []
    for s, p in enumerate(pts):
        t = s / segs
        a = pts[max(0, s - 1)]; b = pts[min(segs, s + 1)]
        tan = (b - a).normalized()
        nrm = out_normal(p)
        side = tan.cross(nrm)
        if side.length < 1e-5:
            side = tan.cross(Vector((0, 0, 1)))
        side.normalize()
        nrm = side.cross(tan).normalized()
        ang = twist * t
        side, nrm = side * math.cos(ang) + nrm * math.sin(ang), nrm * math.cos(ang) - side * math.sin(ang)
        grow = root + (1 - root) * min(1.0, t / 0.18)
        if end_tie:
            shape = grow * (1 - 0.75 * t ** 2)  # gathers into the tie instead of a point
        else:
            shape = grow * (1 - t ** tip) * (1 + 0.15 * math.sin(math.pi * t))
        w = width * shape + 0.004
        h = thick * (0.5 + 0.5 * shape) + 0.003
        rings.append([bm.verts.new(B(p + side * (sx * w) + nrm * (ny * h))) for sx, ny in PROFILE])
    n = len(PROFILE)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new([r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])

def jitter(v, a=0.03):
    return Vector(v) + Vector((rng.uniform(-a, a), rng.uniform(-a, a), rng.uniform(-a, a)))


PART = shell(math.radians(-6), 0.72, 0.06)  # central-left whorl
CROWN = Vector((-0.02, CY + RY + 0.03, 0.14))

def lock(pts, width, thick=0.038, segs=14, tip=2.55, twist=0.0):
    ribbon([jitter(p, 0.007) for p in pts], width, thick, segs=segs, tip=tip, twist=twist)

# 1. Crown: thick messy locks fanning out smoothly from the crown, tips lifting slightly off the head.
for i in range(16):
    th = math.radians(-180 + i * 22.5 + rng.uniform(-5, 5))
    if math.cos(th) > 0.7:
        continue  # the bangs cover the front
    end_y = rng.uniform(0.16, 0.38)
    swirl = rng.uniform(-0.06, 0.06)
    lock([
        CROWN + Vector((rng.uniform(-0.03, 0.03), 0, rng.uniform(-0.03, 0.03))),
        shell(th, 0.80, 0.07),
        shell(th + swirl * 0.5, 0.56, 0.11),
        shell(th + swirl * 0.8, end_y + 0.12, 0.16),
        shell(th + swirl, end_y, 0.24 + rng.uniform(0, 0.06)),
    ], 0.26, 0.04, segs=14, tip=2.5, twist=rng.uniform(-0.18, 0.18))

# 2. Sides and back: shorter, rugged cropped layers over the ears and nape with outward-flicking tips.
for i in range(15):
    th = math.radians(64 + i * (232 / 14) + rng.uniform(-4, 4))
    back = max(0.0, -math.cos(th))  # 1 at the centre back
    y_end = -0.20 - 0.22 * back - 0.10 * rng.random()
    swirl = rng.uniform(-0.05, 0.05)
    lock([
        shell(th, 0.66, 0.06),
        shell(th, 0.34, 0.10),
        shell(th + swirl * 0.5, 0.06, 0.12),
        shell(th + swirl * 0.8, (y_end + 0.06) / 2, 0.15),
        shell(th + swirl, y_end, 0.22 + 0.07 * rng.random()),
    ], 0.25, 0.038, segs=15, tip=2.55, twist=rng.uniform(-0.2, 0.2))

# 3. Bangs: spiky fringe across the forehead, with two central spikes dipping over the brow bridge
# and shorter angled spikes over the brows.
for x_end, y_end, w in [
    (-0.49, -0.22, 0.20),
    (-0.37, 0.02, 0.21),
    (-0.24, 0.08, 0.20),
    (-0.11, -0.04, 0.18),
    (0.01, -0.09, 0.17),
    (0.13, 0.01, 0.18),
    (0.25, 0.08, 0.20),
    (0.38, 0.00, 0.21),
    (0.50, -0.22, 0.20),
]:
    th_end = math.asin(max(-0.95, min(0.95, x_end / 0.78)))
    mid = shell(th_end * 0.6, 0.45, 0.10)
    end = shell(th_end, y_end, 0.10 + 0.03 * abs(x_end))
    lock([
        PART + Vector((rng.uniform(-0.03, 0.03), 0.02, 0)),
        shell(th_end * 0.35, 0.64, 0.09),
        mid,
        (mid + end) / 2 + Vector((0, 0, -0.025)),
        end,
    ], w, 0.038, segs=15, tip=2.65, twist=rng.uniform(-0.15, 0.15))

# 4. Temple locks framing the sides down to the cheekbones so no scalp shows at the sides.
for side in (-1, 1):
    for th_deg, y_end, w in [(43, -0.28, 0.20), (52, -0.36, 0.22), (61, -0.28, 0.22)]:
        th = math.radians(th_deg) * side
        lock([
            shell(th * 0.5, 0.74, 0.07),
            shell(th * 0.85, 0.50, 0.09),
            shell(th, 0.22, 0.10),
            shell(th, -0.04, 0.11),
            shell(th * 1.03, y_end, 0.18),
        ], w, 0.036, segs=14, tip=2.6, twist=0.12 * side)

# 5. Upper-side and back-crown flared spikes: long smooth arcs from the upper crown that flare out
# cleanly at the sides and upper back, matching the spiky anime silhouette.
for th_deg, y_end, reach in [
    (-58, 0.28, 0.28),
    (58, 0.28, 0.28),
    (-82, 0.12, 0.29),
    (82, 0.12, 0.29),
    (-125, 0.32, 0.27),
    (128, 0.32, 0.27),
]:
    th = math.radians(th_deg)
    lock([
        CROWN,
        shell(th * 0.65, 0.78, 0.08),
        shell(th * 0.88, 0.56, 0.13),
        shell(th, y_end + 0.12, 0.19),
        shell(th * 1.02, y_end, reach),
    ], 0.22, 0.038, segs=12, tip=2.5, twist=0.0)

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

COLOUR = (0.376, 0.259, 0.180, 1)  # Warm brown (#60422E)
mat = bpy.data.materials.get("GideHairBrown") or bpy.data.materials.new("GideHairBrown")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
if bsdf:
    bsdf.inputs[0].default_value = COLOUR
    bsdf.inputs["Roughness"].default_value = 0.38
mat.diffuse_color = COLOUR
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print(NAME, "tris", tris)
