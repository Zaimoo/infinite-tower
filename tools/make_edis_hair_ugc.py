"""
Edis Callen's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

From her card art and 3D render: long, voluminous, messy black hair. Choppy bangs falling to
the eyes with a strand between them, wild tufts flaring out beside the cheeks, a couple of
flyaways at the crown, thick wavy locks over the front of the shoulders onto the chest, and a
curly fall down her back to the waist.

The user asked for the hair to be as long and accurate as possible, past the usual triangle
budget. Roblox's importer takes about 20k triangles per mesh, so the hair is two meshes:
EdisHair (scalp, crown, bangs, tufts and front locks) and EdisBackHair (the long back fall).
Both are built in the same head space, so each is placed from its own export centre.

Same construction as tools/make_jenna_hair_ugc.py: ribbon locks with a centre ridge over a full
scalp cap, in Roblox head space on a 1.2-stud reference head. Export each object with the
hero-remodel skill's scripts/blender_export_hair.py (docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random, os, json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "EdisHair"
BACK = "EdisBackHair"
rng = random.Random(613)

for ob in list(bpy.data.objects):
    if ob.name in (NAME, BACK) or ob.name == "Cube":
        bpy.data.objects.remove(ob, do_unlink=True)
for ob in bpy.data.objects:
    if ob.name.endswith("Hair") and ob.name not in (NAME, BACK):
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



PART = shell(math.radians(-8), 0.66, 0.05)  # slightly off-centre part, towards her left
CROWN = Vector((0.0, CY + RY + 0.03, 0.18))

def curly(pts, amp, waves, phase, below=0.2):
    """Sideways and outward waves on the hanging part of a lock, growing towards the tip."""
    out = [pts[0]]
    n = len(pts)
    for i, p in enumerate(pts[1:], 1):
        t = i / (n - 1)
        if p.y < below:
            th = math.atan2(p.x, -(p.z - CZ))
            side = Vector((math.cos(th), 0, math.sin(th)))
            radial = Vector((math.sin(th), 0, -math.cos(th)))
            g = 0.5 + 0.5 * t
            p = p + side * (amp * g * math.sin(waves * math.pi * t + phase)) \
                  + radial * (0.4 * amp * g * math.cos(waves * math.pi * t + phase))
        out.append(p)
    return out

def hang(th, y_end, off, steps=7, flare_rate=0.16, flare_max=0.55):
    """Lock from the scalp down past the head at azimuth th, flaring out with volume."""
    pts = [shell(th, 0.95, off + 0.02) if abs(math.cos(th)) < 0.9 else PART]
    for k in range(1, steps + 1):
        y = 0.85 - (0.85 - y_end) * k / steps
        flare = 0.0 if y > 0.0 else min(flare_max, -y * flare_rate)
        pts.append(shell(th, y, off + flare))
    return pts

def finish(name, colour):
    global bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    mat = bpy.data.materials.get("EdisHairBlack") or bpy.data.materials.new("EdisHairBlack")
    mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs[0].default_value = colour
        bsdf.inputs["Roughness"].default_value = 0.35
    mat.diffuse_color = colour
    me.materials.append(mat)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print(name, "tris", tris)
    return ob

COLOUR = (0.05, 0.05, 0.07, 1)

# ===== EdisHair: the head part ==========================================================

# 1. Crown: chunky locks swirling out from the crown, tips flicking outward around the ears.
for i in range(18):
    th = math.radians(-180 + i * 20 + rng.uniform(-6, 6))
    if math.cos(th) > 0.75:
        continue  # the bangs cover the front
    end_y = rng.uniform(-0.05, 0.25)
    pts = [CROWN + Vector((rng.uniform(-0.05, 0.05), 0, rng.uniform(-0.05, 0.05))),
           shell(th, 0.78, 0.07),
           shell(th, 0.5, 0.1),
           shell(th + rng.uniform(-0.15, 0.15), end_y + 0.12, 0.15),
           shell(th + rng.uniform(-0.2, 0.2), end_y, 0.26)]
    ribbon([jitter(p, 0.015) for p in pts], 0.25, 0.04, segs=16, tip=2.5, twist=rng.uniform(-0.5, 0.5))

# 2. Wild tufts beside the cheeks and behind the ears, sticking out sideways.
for side in (-1, 1):
    for k in range(5):
        th = math.radians(side * (68 + 14 * k + rng.uniform(-4, 4)))
        y0 = rng.uniform(0.15, 0.35)
        pts = [shell(th, 0.55, 0.06), shell(th, y0, 0.1),
               shell(th * 1.02, y0 - 0.22, 0.24),
               shell(th * 1.05, y0 - 0.38 + rng.uniform(-0.08, 0.08), 0.42 + rng.uniform(0, 0.12))]
        ribbon([jitter(p, 0.012) for p in pts], 0.2, 0.034, segs=12, tip=2.6, twist=rng.uniform(-0.6, 0.6))

# 3. Choppy bangs to the eyes, swept from the part; one longer strand between the eyes.
for k, (x_end, y_end, w) in enumerate([(-0.46, -0.3, 0.21), (-0.32, -0.08, 0.21), (-0.18, 0.04, 0.19),
                                       (-0.03, -0.12, 0.17), (0.11, 0.02, 0.19), (0.25, 0.04, 0.2),
                                       (0.37, -0.1, 0.21), (0.48, -0.32, 0.21)]):
    th_end = math.asin(max(-0.95, min(0.95, x_end / 0.78)))
    mid = shell(th_end * 0.6, 0.42, 0.09)
    end = shell(th_end, y_end, 0.1 + 0.03 * abs(x_end))
    pts = [PART + Vector((rng.uniform(-0.05, 0.05), 0.02, 0)), shell(th_end * 0.35, 0.62, 0.08), mid,
           (mid + end) / 2 + Vector((0, 0, -0.03)), end]
    ribbon([jitter(p, 0.01) for p in pts], w, 0.036, segs=16, tip=2.7, twist=rng.uniform(-0.3, 0.3))

# 3b. Face-framing locks down each temple to the jaw, closing the gap between the bangs and the
# side locks. They keep their own random state so the back fall (EdisBackHair) stays identical.
_state = rng.getstate()
for side in (-1, 1):
    for k, (th_deg, y_end, w) in enumerate([(43, -0.4, 0.2), (52, -0.7, 0.23), (61, -0.55, 0.23)]):
        th = math.radians(th_deg) * side
        pts = [shell(th * 0.5, 0.74, 0.07), shell(th * 0.85, 0.5, 0.09), shell(th, 0.2, 0.1),
               shell(th, -0.1, 0.11), shell(th * 1.02, (y_end - 0.1) / 2, 0.13), shell(th * 1.04, y_end, 0.17)]
        ribbon([jitter(p, 0.008) for p in pts], w, 0.036, segs=18, tip=2.6, twist=0.15 * side)
rng.setstate(_state)

# 4. Two flyaways at the crown, arcing up and over.
for k, th_deg in enumerate((-35, 150)):
    th = math.radians(th_deg)
    base = CROWN + Vector((0.05 * (2 * k - 1), -0.03, 0.04 * k))
    d = Vector((math.sin(th), 0, -math.cos(th)))
    pts = [base, base + d * 0.1 + Vector((0, 0.1, 0)), base + d * 0.26 + Vector((0, 0.12, 0)),
           base + d * 0.4 + Vector((0, 0.04, 0))]
    ribbon(pts, 0.1, 0.028, segs=12, tip=2.4, root=0.9)

# 5. Thick wavy locks over the front of each shoulder, onto the chest.
for side in (-1, 1):
    # Locks start at the temples and fall beside the cheeks, never across the face.
    for k, (th_deg, y_end, w) in enumerate([(64, -1.5, 0.24), (76, -1.85, 0.26), (88, -1.65, 0.25), (100, -1.4, 0.24)]):
        th = math.radians(th_deg) * side
        pts = [shell(th * 0.8, 0.72, 0.06), shell(th, 0.35, 0.12), shell(th, 0.0, 0.16),
               shell(th * 1.04, -0.4, 0.22), shell(th * 1.08, -0.8, 0.3),
               shell(th * 1.08, (y_end - 0.8) / 2 - 0.4, 0.36), shell(th * 1.05, y_end, 0.4)]
        pts = curly(pts, 0.12, 4.0, rng.uniform(0, 6.28), below=0.1)
        ribbon([jitter(p, 0.012) for p in pts], w, 0.036, segs=30, tip=2.7, twist=rng.uniform(-0.4, 0.4))

head_part = finish(NAME, COLOUR)

# ===== EdisBackHair: the long curly fall ================================================
bm = bmesh.new()

# 6. Outer volume layer over the back of the head, ending at the shoulders.
for i in range(14):
    th = math.radians(95 + i * (170 / 13))
    pts = curly(hang(th, -0.75 - 0.25 * rng.random(), 0.09, steps=6), 0.08, 2.5, rng.uniform(0, 6.28))
    ribbon([jitter(p, 0.015) for p in pts], 0.24, 0.036, segs=18, tip=2.3, twist=rng.uniform(-0.4, 0.4))

# 7. The long fall: curly locks down her back to the waist, the outer ones a little shorter.
for i in range(22):
    th = math.radians(96 + i * (168 / 21))
    edge = abs(math.cos(th + math.pi))  # 1 at the centre back, smaller towards the sides
    y_end = -2.1 - 0.8 * edge - 0.35 * rng.random()
    pts = curly(hang(th, y_end, 0.035 + 0.02 * (i % 2), steps=12, flare_rate=0.17, flare_max=0.6),
                0.13, 5.0, rng.uniform(0, 6.28))
    ribbon([jitter(p, 0.014) for p in pts], 0.3, 0.038, segs=44, tip=2.7, twist=rng.uniform(-0.4, 0.4))

back_part = finish(BACK, COLOUR)
