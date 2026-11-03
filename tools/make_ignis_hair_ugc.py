"""
Ignis's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

Derived from tools/make_archon_hair_ugc.py. From his reference art: short spiky hair swept up
and over to his left, sides and back cropped close. The reference is two-tone (blond top,
red-orange sides); a hair mesh takes one costume colour, so the costume uses a golden
blond-orange between the two.

Same construction as tools/make_jenna_hair_ugc.py: thin ribbon locks with a centre ridge and
needle tips over a full scalp cap, built in Roblox head space on a 1.2-stud reference head.
Exports FBX + JSON to assets/hair (see docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random, os, json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-towerssets\hair"
NAME = "IgnisHair"
rng = random.Random(83)

for ob in list(bpy.data.objects):
    if ob.name.startswith(NAME) or ob.name == "Cube":
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
    """Point on the scalp at azimuth theta (0 = front, +90 deg = her right, +X) and height y."""
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
            front = math.cos(th) > 0.55
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


# 1. Close-cropped sides and back: short, flat locks combed down and back.
for i in range(24):
    th = math.radians(50 + i * (260 / 23))
    y0 = 0.55 + rng.uniform(-0.04, 0.04)
    y1 = (0.08 if abs(math.cos(th)) < 0.5 else -0.28) + rng.uniform(-0.03, 0.03)
    pts = [shell(th, y0, 0.018), shell(th + 0.06, (y0 + y1) / 2, 0.02), shell(th + 0.1, y1, 0.022)]
    ribbon(pts, 0.17, 0.018, segs=10, tip=2.6, root=0.9, twist=rng.uniform(-0.15, 0.15))

# 2. Tousled top: locks fanning out from the crown in every direction, flicking up and out.
CROWN = Vector((0.0, CY + RY + 0.04, 0.1))
for ring, (y_mid, y_end, count, lift) in enumerate([(0.62, 0.36, 18, 0.1), (0.72, 0.5, 14, 0.16)]):
    for i in range(count):
        th = math.radians(i * 360 / count + ring * 12 + rng.uniform(-5, 5))
        end_pt = shell(th, y_end + rng.uniform(-0.1, 0.1), 0.08 + 0.04 * ring)  # staggered ends, no brim line
        flick = out_normal(end_pt) * (0.03 + rng.uniform(0, 0.03)) + Vector((0, lift * 0.6 + rng.uniform(0, 0.05), 0))
        pts = [CROWN, shell(th, 0.9, 0.06 + 0.03 * ring), shell(th, y_mid, 0.07 + 0.03 * ring), end_pt + flick]
        ribbon([jitter(p, 0.015) for p in pts], rng.uniform(0.18, 0.23), 0.032, segs=14, tip=2.6, twist=rng.uniform(-0.35, 0.35))

# 3. Messy spikes standing up and back out of the top.
for i in range(12):
    th = math.radians(rng.uniform(-150, 150))
    base = shell(th, rng.uniform(0.8, 0.93), 0.1)
    pts = [base, base + out_normal(base) * 0.08 + Vector((0, 0.14, 0.05)),
           base + out_normal(base) * 0.16 + Vector((-0.12, 0.3 + rng.uniform(0, 0.12), 0.08))]
    ribbon(pts, rng.uniform(0.13, 0.17), 0.03, segs=10, tip=1.8, root=0.9, twist=rng.uniform(-0.4, 0.4))

# 4. Swept-up front quiff from the hairline.
for x in (-0.32, -0.12, 0.08, 0.28):
    th = math.radians(x * 90)
    base = shell(th, 0.4, 0.06)
    pts = [base, base + Vector((x * 0.1 - 0.04, 0.24, 0.0)), base + Vector((x * 0.2 - 0.14, 0.46, 0.14)), base + Vector((x * 0.3 - 0.26, 0.56, 0.3))]
    ribbon(pts, 0.17, 0.032, segs=12, tip=1.9, root=0.9, twist=rng.uniform(-0.2, 0.2))

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

mat = bpy.data.materials.get("IgnisHairGold") or bpy.data.materials.new("IgnisHairGold")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
if bsdf:
    bsdf.inputs[0].default_value = (0.85, 0.5, 0.15, 1)
    bsdf.inputs["Roughness"].default_value = 0.45
mat.diffuse_color = (0.85, 0.5, 0.15, 1)
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("IgnisHair tris", tris)
