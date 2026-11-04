"""
Solaris's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

From her reference art: long, wavy copper hair with a centre part, waves framing the face down
to the chest, and a full fall of waves down the back past the shoulders.

Same construction as tools/make_jenna_hair_ugc.py: thin ribbon locks with a centre ridge and
needle tips over a full scalp cap, built in Roblox head space on a 1.2-stud reference head.
Waves come from a sideways sine wobble along each lock. Exports FBX + JSON to assets/hair (see
docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random, os, json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-towerssets\hair"
NAME = "SolarisHair"
rng = random.Random(97)

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


PART = shell(0.0, 0.66, 0.05)  # centre part above the forehead
CROWN = Vector((0.0, CY + RY + 0.03, 0.18))

def wavy(pts, amp, waves, phase):
    """Adds a sideways wave to the hanging part of a lock (below the head's equator)."""
    out = [pts[0]]
    n = len(pts)
    for i, p in enumerate(pts[1:], 1):
        t = i / (n - 1)
        if p.y < 0.2:
            side = Vector((math.cos(math.atan2(p.x, -(p.z - CZ)) ), 0, math.sin(math.atan2(p.x, -(p.z - CZ)))))
            p = p + side * (amp * math.sin(waves * math.pi * t + phase))
        out.append(p)
    return out

def hang(th, y_end, off, steps=7):
    """Lock from the scalp straight down past the head at azimuth th, flaring a little."""
    pts = [shell(th, 0.95, off + 0.02) if abs(math.cos(th)) < 0.9 else PART]
    for k in range(1, steps + 1):
        y = 0.85 - (0.85 - y_end) * k / steps
        flare = 0.0 if y > 0.0 else min(0.18, -y * 0.16)
        pts.append(shell(th, y, off + flare))
    return pts

# 1. Back and sides: a full fall of wavy locks past the shoulders.
for i in range(22):
    th = math.radians(62 + i * (236 / 21))
    y_end = -1.3 - 0.25 * rng.random()
    pts = wavy(hang(th, y_end, 0.03 + 0.015 * (i % 2)), 0.1, 3.5, rng.uniform(0, 6.28))
    ribbon([jitter(p, 0.012) for p in pts], 0.2, 0.034, segs=24, tip=2.4, twist=rng.uniform(-0.3, 0.3))

# 2. Outer layer over the top, for volume, ending around the jaw.
for i in range(14):
    th = math.radians(50 + i * (260 / 13))
    pts = wavy(hang(th, -0.5 - 0.15 * rng.random(), 0.075, steps=5), 0.07, 2.5, rng.uniform(0, 6.28))
    ribbon([jitter(p, 0.015) for p in pts], 0.2, 0.034, segs=18, tip=2.2, twist=rng.uniform(-0.3, 0.3))

# 3. Curtain waves from the centre part, framing the face down onto the chest.
for side in (-1, 1):
    for k, (th_deg, y_end, w) in enumerate([(28, -1.0, 0.15), (42, -1.25, 0.17), (56, -1.1, 0.16)]):
        th = math.radians(th_deg) * side
        pts = [PART + Vector((side * 0.04 * k, 0.02, 0)),
               shell(math.radians(12 + 6 * k) * side, 0.6, 0.08),
               shell(th, 0.3, 0.09 + 0.01 * k),
               shell(th * 1.05, 0.0, 0.1 + 0.01 * k),
               shell(th * 1.1, -0.35, 0.12),
               shell(th * 1.1, -0.7, 0.16),
               shell(th * 1.08, y_end, 0.2)]
        pts = wavy(pts, 0.09, 3.0, k * 1.7)
        ribbon([jitter(p, 0.01) for p in pts], w, 0.034, segs=24, tip=2.3, twist=rng.uniform(-0.25, 0.25))

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

mat = bpy.data.materials.get("SolarisHairCopper") or bpy.data.materials.new("SolarisHairCopper")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
if bsdf:
    bsdf.inputs[0].default_value = (0.8, 0.3, 0.08, 1)
    bsdf.inputs["Roughness"].default_value = 0.4
mat.diffuse_color = (0.8, 0.3, 0.08, 1)
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("SolarisHair tris", tris)
