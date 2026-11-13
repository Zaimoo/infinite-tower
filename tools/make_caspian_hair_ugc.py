"""
Caspian's hair, UGC-accessory style (run inside Blender: exec(open(path, encoding="utf-8").read())).

From his reference art: short auburn hair swept up and back from the forehead into a full
quiff, with a couple of loose locks falling over his forehead on his right, short sides swept
back above the ears, a short layered back to the nape, and a few messy spikes over the crown.
Built UGC style (thick, rounded clumps over a lightly grooved base sheet) with the helpers from
tools/make_isabelle_hair_ugc.py. Untextured: the costume colours it. Roblox head space (Y up,
-Z front, +X the hero's right) on a 1.2-stud reference head. Export with the hero-remodel
skill's scripts/blender_export_hair.py.
"""

import bpy, bmesh, math, random
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "CaspianHair"
rng = random.Random(5150)

for ob in list(bpy.data.objects):
    if ob.name == NAME or ob.name == "Cube":
        bpy.data.objects.remove(ob, do_unlink=True)
for ob in bpy.data.objects:
    if ob.name.endswith("Hair") and ob.name != NAME:
        ob.hide_set(True)
        ob.hide_render = True

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

# --- Scalp cap: full coverage under the locks; the face opening stops at the hairline ------
def cap():
    rings, segs = 22, 44
    verts = {}
    for i in range(rings + 1):
        y = CY + RY - (RY + 0.95) * i / rings
        for j in range(segs):
            th = 2 * math.pi * j / segs
            c = math.cos(th)
            if c > 0.2:
                limit = -0.14 + 0.46 * min(1.0, (c - 0.2) / 0.55) ** 1.4
            else:
                limit = -0.14 - 0.12 * min(1.0, (0.2 - c) / 0.8)
            if y < limit:
                continue
            verts[(i, j)] = bm.verts.new(B(shell(th, y, -0.01)))
    for i in range(rings):
        for j in range(segs):
            q = [(i, j), (i, (j + 1) % segs), (i + 1, (j + 1) % segs), (i + 1, j)]
            if all(k in verts for k in q):
                bm.faces.new([verts[k] for k in q])
# No scalp cap: its stepped edge would show below this short cut's hem; the base sheet and
# crown dome cover the head.

# --- Ribbon lock ---------------------------------------------------------------------------
# A plump, rounded clump profile (UGC hair reads as thick soft clumps, not flat strips).
PROFILE = [(1.0, 0.0), (0.72, 0.6), (0.0, 0.95), (-0.72, 0.6), (-1.0, 0.0), (-0.62, -0.32), (0.0, -0.42), (0.62, -0.32)]

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

def ribbon(ctrl, width, thick=0.035, segs=16, tip=2.5, root=0.6, end_tie=False, twist=0.0):
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
            shape = grow * (1 - 0.7 * t ** 2)  # gathers into the tie instead of a point
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

def lock(pts, width, thick=0.036, segs=14, tip=2.6, end_tie=False, twist=0.0):
    ribbon([jitter(p, 0.01) for p in pts], width, thick, segs=segs, tip=tip, root=0.7, end_tie=end_tie, twist=twist)

def curtain(th0, th1, y_top, y_end, off_top, off_bot, thick=0.045, nth=72, ny=12, grooves=17, depth=0.014):
    """A blunt-cut sheet of hair over the scalp between azimuths th0..th1: from y_top down to
    y_end(theta), standing off the head from off_top to off_bot. Shallow vertical grooves give
    it strand clumps, and the bottom edge is cut straight (the anime 'hime' fringe), which
    separate ribbon locks can't do without a sawtooth edge."""
    outer, inner = [], []
    for i in range(nth + 1):
        u = i / nth
        th = th0 + (th1 - th0) * u
        groove = depth * abs(math.sin(math.pi * grooves * u))
        col_o, col_i = [], []
        for j in range(ny + 1):
            v = j / ny
            y = y_top + (y_end(th) - y_top) * v
            off = off_top + (off_bot - off_top) * v
            col_o.append(bm.verts.new(B(shell(th, y, off + groove))))
            col_i.append(bm.verts.new(B(shell(th, y, off - thick))))
        outer.append(col_o); inner.append(col_i)
    for i in range(nth):
        for j in range(ny):
            bm.faces.new([outer[i][j], outer[i + 1][j], outer[i + 1][j + 1], outer[i][j + 1]])
            bm.faces.new([inner[i][j + 1], inner[i + 1][j + 1], inner[i + 1][j], inner[i][j]])
    for i in range(nth):  # top and bottom edges
        bm.faces.new([outer[i][0], inner[i][0], inner[i + 1][0], outer[i + 1][0]])
        bm.faces.new([outer[i + 1][ny], inner[i + 1][ny], inner[i][ny], outer[i][ny]])
    for j in range(ny):  # side edges
        bm.faces.new([outer[0][j + 1], inner[0][j + 1], inner[0][j], outer[0][j]])
        bm.faces.new([outer[nth][j], inner[nth][j], inner[nth][j + 1], outer[nth][j + 1]])

def clump(pts, width, thick=0.06, segs=14, tip=3.2, twist=0.0):
    """One UGC-style hair clump: thick and rounded, keeping its width most of the way and
    narrowing to a soft point at the end."""
    ribbon([jitter(p, 0.004) for p in pts], width, thick, segs=segs, tip=tip, root=0.75, twist=twist)


# 1. Base sheet: a high front hairline, short sides above the ears, the back to the nape.
FRONT = math.radians(70)

def hem(th):
    a = abs(th)
    if a <= FRONT:
        return 0.44
    if a <= math.radians(115):
        t = (a - FRONT) / math.radians(45)
        return 0.44 + (0.06 - 0.44) * t * t * (3 - 2 * t)
    t = min(1.0, (a - math.radians(115)) / math.radians(50))
    return 0.06 + (-0.14 - 0.06) * t * t * (3 - 2 * t)

curtain(-math.pi, math.pi, 0.915, hem, 0.04, 0.07, thick=0.04, nth=128, ny=8, grooves=24, depth=0.01)

crown = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=0.1)
for v in crown["verts"]:
    v.co = B(Vector((v.co.x * 1.4, v.co.z * 0.5, v.co.y * 1.4)) + shell(0, CY + RY, 0.0) + Vector((0, -0.01, 0.02)))

# 2. The quiff: full clumps from the front hairline that rise and sweep up and back over the
#    top of the head, their tips flicking up at the back of the crown.
for k, x in enumerate([-0.42, -0.28, -0.14, 0.0, 0.14, 0.28, 0.42]):
    lift = 0.06 * (1 - abs(x) / 0.5) + rng.uniform(-0.02, 0.02)
    pts = [Vector((x, 0.44, -0.6)), Vector((x * 1.08, 0.8 + lift, -0.56)), Vector((x * 1.12, 1.0 + lift, -0.24)),
           Vector((x * 1.18, 0.96 + lift * 0.5, 0.1)), Vector((x * 1.25, 0.86, 0.3))]
    clump(pts, rng.uniform(0.14, 0.17), 0.08, segs=18, tip=rng.uniform(2.2, 2.8))

# 3. Loose locks falling over the forehead on his right (+X), lying close to the brow.
for x0, y_end, w in [(0.14, 0.24, 0.09), (0.27, 0.2, 0.08)]:
    pts = [Vector((x0, 0.5, -0.64)), Vector((x0 + 0.04, 0.42, -0.67)), Vector((x0 + 0.09, 0.32, -0.67)), Vector((x0 + 0.13, y_end, -0.65))]
    clump(pts, w, 0.04, segs=12, tip=2.2)

# 4. Short sides: from above the temples, down and back to just above the ears, close to the head.
for side in (1, -1):
    for th_deg, y_end in [(76, 0.12), (92, 0.04), (108, 0.0)]:
        th = math.radians(th_deg) * side
        pts = [shell(th * 0.9, 0.6, 0.05), shell(th, 0.38, 0.07), shell(th + math.radians(10) * side, 0.18, 0.08),
               shell(th + math.radians(18) * side, y_end, 0.085)]
        clump(pts, 0.16, 0.055, segs=12, tip=2.6)

# 5. The back: short layered clumps from the crown to the top of the nape, with small flicks.
for k, th_deg in enumerate(range(122, 239, 13)):
    th = math.radians(th_deg + rng.uniform(-3, 3))
    off = 0.08 + (0.02 if k % 2 else 0.0)
    y_end = rng.uniform(-0.2, -0.06)
    pts = [shell(th * 0.5 + math.pi * 0.5, 0.93, 0.03), shell(th, 0.75, off), shell(th, 0.4, off + 0.01),
           shell(th, y_end + 0.12, off + 0.01), shell(th, y_end, off + rng.uniform(0.03, 0.06))]
    clump(pts, rng.uniform(0.16, 0.2), 0.065, segs=14, tip=rng.uniform(2.2, 2.8))

# 6. A few messy tufts over the crown, swept back with the quiff.
for x in (-0.18, 0.04, 0.22):
    base = Vector((x, 1.0, -0.02 + rng.uniform(-0.04, 0.04)))
    pts = [base, base + Vector((x * 0.15, 0.07, 0.12)), base + Vector((x * 0.3, 0.06, 0.26))]
    clump(pts, rng.uniform(0.11, 0.14), 0.055, segs=8, tip=2.2)

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

mat = bpy.data.materials.get("CaspianHairAuburn") or bpy.data.materials.new("CaspianHairAuburn")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
col = (0.33, 0.08, 0.025, 1)  # about rgb(156, 78, 44)
if bsdf:
    bsdf.inputs[0].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.45
mat.diffuse_color = col
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print(NAME, "tris", tris)
