"""
Eolka's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

From her reference art: hair swept back off the forehead into a high ponytail at the
crown-back (gold band added as a costume piece), centre-parted curtain bangs sweeping to
both sides past the cheeks, side locks to the jaw, and the ponytail arcing up, back and
down behind the head.

Same construction as tools/make_jenna_hair_ugc.py: thin ribbon locks with a centre ridge
and needle tips over a full scalp cap, built in Roblox head space on a 1.2-stud reference
head. Exports FBX + JSON to assets/hair (see docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random, os, json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-towerssets\hair"
NAME = "EolkaHair"
rng = random.Random(31)

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


TIE = shell(math.pi, 0.74, 0.06) + Vector((0, 0.06, 0))  # high ponytail tie, crown-back
PART = shell(0.0, 0.62, 0.05)  # centre part above the forehead

def toward_tie(th, y, off, n=5):
    """Path from a hairline point over the scalp into the tie."""
    pts = []
    for s in range(n):
        t = s / (n - 1)
        th_t = th + (math.pi * (1 if th >= 0 else -1) - th) * t ** 1.3 if abs(th) > 1e-6 else 0
        y_t = y + (TIE.y - 0.05 - y) * t ** 0.8
        p = shell(th_t, y_t, off + 0.03 * math.sin(math.pi * t))
        pts.append(p)
    pts[-1] = TIE + Vector((0, -0.04, -0.03))
    return pts

# 1. Swept-back canopy: hairline all round, combed over the scalp into the tie.
hairline = []
for i in range(9):  # forehead (behind the bangs)
    hairline.append((math.radians(-64 + i * 16), 0.34))
for side in (-1, 1):
    for d in (78, 94, 110, 126):  # above the ears, temples to behind
        hairline.append((math.radians(d) * side, 0.12))
    for d in (142, 158, 172):  # back of the head down to the nape
        hairline.append((math.radians(d) * side, -0.4))
for k, (th, y) in enumerate(hairline):
    off = 0.02 + 0.015 * (k % 2)
    ribbon([jitter(p, 0.01) for p in toward_tie(th, y, off)], 0.17, 0.034, segs=18, root=1.0, end_tie=True, twist=rng.uniform(-0.15, 0.15))

# 2. Curtain bangs from the centre part, sweeping to each side past the cheek.
for side in (-1, 1):
    for k, (spread, tip_y, w) in enumerate([(0.0, -0.18, 0.15), (0.12, -0.32, 0.16), (0.24, -0.45, 0.15)]):
        th0 = math.radians(4 + 10 * k) * side
        path = [PART + Vector((side * 0.03 * k, 0.02, 0)),
                shell(th0 + math.radians(18) * side, 0.52, 0.08 + 0.02 * k),
                shell(math.radians(46 + 8 * k) * side, 0.22, 0.09 + 0.02 * k),
                shell(math.radians(60 + 8 * k) * side, -0.08, 0.1 + 0.02 * k),
                Vector((side * (0.6 + spread * 0.4), tip_y, -0.5 + spread * 0.3))]
        ribbon([jitter(p, 0.01) for p in path], w, 0.034, segs=20, tip=2.2, twist=rng.uniform(-0.25, 0.25))

# 3. Side locks over the ears down to the jaw, tips curling forward.
for side in (-1, 1):
    for d, y_end, off in [(84, -0.52, 0.06), (100, -0.46, 0.07), (72, -0.4, 0.1)]:
        th = math.radians(d) * side
        path = [shell(th, 0.55, off), shell(th, 0.15, off), shell(th, -0.2, off + 0.02),
                shell(th - math.radians(8) * side, y_end, off + 0.025)]
        ribbon([jitter(p, 0.012) for p in path], 0.17, 0.034, segs=16, tip=2.1, twist=rng.uniform(-0.2, 0.2))

# 4. High ponytail: rises from the tie, arcs back over and falls behind the head.
for k in range(13):
    a = 2 * math.pi * k / 13
    o = Vector((math.cos(a), 0, math.sin(a)))
    sway = rng.uniform(-0.07, 0.07)
    length = rng.uniform(0.0, 0.25)
    # Rises a little, rolls over close behind the head, then cascades down the back.
    path = [TIE + Vector((o.x * 0.07, 0.02, o.z * 0.05)),
            TIE + Vector((o.x * 0.12, 0.2, 0.06 + o.z * 0.07)),
            TIE + Vector((o.x * 0.17 + sway, 0.2, 0.3 + o.z * 0.08)),
            TIE + Vector((o.x * 0.18 + sway, -0.2, 0.44 + o.z * 0.07)),
            TIE + Vector((o.x * 0.12 + sway * 1.5, -0.8, 0.44)),
            TIE + Vector((o.x * 0.04 + sway * 2, -1.3 - length, 0.34))]
    ribbon(path, 0.13, 0.04, segs=24, tip=2.0, root=0.8, twist=rng.uniform(-0.4, 0.4))
# Short spiky strands flicking up out of the tie.
for k in range(4):
    a = math.radians(-60 + 40 * k)
    path = [TIE + Vector((0, 0.03, 0)), TIE + Vector((math.sin(a) * 0.1, 0.2, 0.02)), TIE + Vector((math.sin(a) * 0.18, 0.32, 0.1))]
    ribbon(path, 0.07, 0.025, segs=10, tip=1.6)

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

mat = bpy.data.materials.get("EolkaHairCopper") or bpy.data.materials.new("EolkaHairCopper")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
if bsdf:
    bsdf.inputs[0].default_value = (0.85, 0.27, 0.05, 1)
    bsdf.inputs["Roughness"].default_value = 0.4
mat.diffuse_color = (0.85, 0.27, 0.05, 1)
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("EolkaHair tris", tris, "tie", tuple(round(c, 4) for c in TIE))
