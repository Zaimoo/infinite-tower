"""
Jenna's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

Layered long red hair from her reference art: spiky crown, side-swept fringe with a long
strand between the eyes, two face-framing locks down to the chest, and the back locks
converging into a ponytail at the centre of the back (the reference braid moved behind).

Style: every lock is a thin ribbon plate with a raised centre ridge and a needle tip, laid
in layers over a full scalp cap, like avatar hair accessories. Locks are built in Roblox
head space (Y up, front -Z) on a 1.2-stud reference head, converted to Blender with
B(p) = (x, -z, y). Exports FBX + JSON to assets/hair (see docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random, os, json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "JennaHair"
rng = random.Random(23)

for ob in list(bpy.data.objects):
    if ob.name.startswith(NAME) or ob.name == "Cube":
        bpy.data.objects.remove(ob, do_unlink=True)

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

CROWN = Vector((0.05, CY + RY + 0.02, 0.12))
TIE = Vector((0.0, -0.2, CZ + RZ + 0.04))

# 1. Back canopy: locks from the crown sweeping down the back and converging into the tie.
for i in range(15):
    th = math.radians(115 + i * (130 / 14))
    path = [CROWN + Vector((0, 0, 0.0))]
    for t in (0.25, 0.5, 0.72, 0.88):
        th_t = th + (math.pi - th) * t ** 1.6
        y_t = CROWN.y + (TIE.y - CROWN.y) * t
        path.append(shell(th_t, y_t, 0.02 + 0.02 * math.sin(math.pi * t)))
    path.append(TIE + Vector((math.sin(th - math.pi) * 0.05, 0, -0.03)))
    ribbon(path, 0.16, 0.034, segs=16, end_tie=True, twist=rng.uniform(-0.15, 0.15))

# 2. Side layers: locks over the ears hanging to the jaw, tips flicking outward.
for side in (-1, 1):
    for i, (th_deg, y_end, off) in enumerate([(70, -0.42, 0.03), (88, -0.5, 0.035), (106, -0.4, 0.03), (80, -0.3, 0.06), (98, -0.34, 0.065)]):
        th = math.radians(th_deg) * side
        path = [CROWN, shell(th * 0.7, 0.75, off), shell(th, 0.35, off), shell(th, 0.0, off),
                shell(th, y_end + 0.12, off + 0.02), shell(th * 1.05, y_end, off + 0.09)]
        ribbon([jitter(p, 0.015) for p in path], 0.17, 0.034, segs=18, tip=2.0, twist=rng.uniform(-0.2, 0.2))

# 3. Crown layer: shorter locks fanning from the crown and flicking out (the spiky top).
for i in range(14):
    th = math.radians(i * 360 / 14 + 8)
    if math.cos(th) > 0.8:
        continue
    lift = 0.07 + 0.04 * (i % 2)
    path = [CROWN, shell(th, 0.84, lift), shell(th, 0.62, lift + 0.03), shell(th, 0.42, lift + 0.1) + Vector((0, 0.06, 0))]
    ribbon([jitter(p, 0.02) for p in path], 0.15, 0.03, segs=12, tip=1.8, twist=rng.uniform(-0.3, 0.3))
# Flyaways at the top sides, as in the reference.
for side in (-1, 1):
    for k in range(2):
        th = math.radians(75 + 25 * k) * side
        path = [shell(th, 0.82, 0.05), shell(th, 0.68, 0.1), shell(th * 1.05, 0.6, 0.17) + Vector((0, 0.08, 0))]
        ribbon(path, 0.07, 0.024, segs=10, tip=1.6)

# 3b. Nape layer: locks under the canopy, hanging past the hairline either side of the ponytail.
for i in range(10):
    th = math.radians(118 + i * (124 / 9))
    if abs(th - math.pi) < math.radians(14):
        continue  # the ponytail covers the centre
    path = [shell(th, 0.35, 0.015), shell(th, 0.0, 0.02), shell(th, -0.35, 0.03), shell(th, -0.62, 0.07)]
    ribbon([jitter(p, 0.012) for p in path], 0.17, 0.032, segs=14, tip=2.0, twist=rng.uniform(-0.2, 0.2))
# Behind the ears: fill between the side layer and the nape.
for side in (-1, 1):
    for th_deg in (112, 124):
        th = math.radians(th_deg) * side
        path = [shell(th, 0.6, 0.02), shell(th, 0.2, 0.025), shell(th, -0.2, 0.03), shell(th, -0.55, 0.08)]
        ribbon([jitter(p, 0.012) for p in path], 0.18, 0.032, segs=14, tip=2.0)

# 4. Fringe: side-swept locks over the forehead, the longest falling between the eyes.
fringe = [  # (root theta deg, tip x, tip y, width)
    (-40, -0.56, 0.05, 0.15), (-24, -0.38, 0.12, 0.16), (-10, -0.12, -0.12, 0.15),
    (2, 0.02, -0.02, 0.14), (14, 0.16, 0.12, 0.16), (28, 0.36, 0.08, 0.16), (42, 0.55, 0.16, 0.14),
]
for th_deg, tx, ty, w in fringe:
    th = math.radians(th_deg)
    path = [CROWN + Vector((0, 0, -0.1)), shell(th * 0.5, 0.9, 0.06), shell(th, 0.62, 0.07), shell(th, 0.35, 0.08),
            Vector((tx * 0.9, (0.35 + ty) / 2, -0.8)), Vector((tx, ty, -0.76))]
    ribbon([jitter(p, 0.012) for p in path], w, 0.034, segs=18, tip=2.4, twist=rng.uniform(-0.25, 0.25))

# 5. Two long face-framing locks per side, down past the jaw onto the chest.
for side in (-1, 1):
    for k, (th_deg, off, tip_y, tip_x) in enumerate([(55, 0.07, -1.35, 0.6), (68, 0.1, -1.15, 0.72)]):
        th = math.radians(th_deg) * side
        path = [shell(th * 0.6, 0.85, off), shell(th, 0.45, off), shell(th, 0.0, off), shell(th, -0.4, off + 0.02),
                Vector((tip_x * side, (-0.4 + tip_y) / 2, -0.52)), Vector((tip_x * 0.95 * side, tip_y, -0.5))]
        ribbon([jitter(p, 0.012) for p in path], 0.16 - 0.03 * k, 0.034, segs=22, tip=2.3, twist=rng.uniform(-0.3, 0.3))

# 6. Ponytail at the centre of the back: a bundle gathered at the tie, swelling, then pointed.
for k in range(11):
    a = 2 * math.pi * k / 11
    r0 = 0.06
    o = Vector((math.cos(a), 0, math.sin(a)))
    sway = rng.uniform(-0.08, 0.08)
    path = [TIE + Vector((o.x * r0, 0.02, o.z * r0 * 0.6)),
            TIE + Vector((o.x * 0.14, -0.3, 0.2 + o.z * 0.08)),
            TIE + Vector((o.x * 0.18 + sway, -0.75, 0.3 + o.z * 0.08)),
            TIE + Vector((o.x * 0.13 + sway * 1.5, -1.25, 0.26 + o.z * 0.06)),
            TIE + Vector((o.x * 0.04 + sway * 2, -1.7 - rng.uniform(0, 0.2), 0.16))]
    ribbon(path, 0.13, 0.04, segs=20, tip=2.0, root=0.8, twist=rng.uniform(-0.5, 0.5))
# Tie band.
bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=16, radius1=0.11, radius2=0.11, depth=0.1,
                      matrix=__import__("mathutils").Matrix.Translation(B(TIE + Vector((0, -0.04, 0.03)))))

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

mat = bpy.data.materials.get("JennaHairRed") or bpy.data.materials.new("JennaHairRed")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
if bsdf:
    bsdf.inputs[0].default_value = (0.76, 0.08, 0.03, 1)
    bsdf.inputs["Roughness"].default_value = 0.4
mat.diffuse_color = (0.76, 0.08, 0.03, 1)
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("JennaHair tris", tris)
