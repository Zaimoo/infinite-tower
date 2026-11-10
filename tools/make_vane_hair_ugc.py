"""
Vane's hair, UGC-accessory style (run inside Blender: exec(open(path, encoding="utf-8").read())).

From his reference art: short, voluminous violet hair with an off-centre middle part (a little
towards his right). His right curtain is a short swoop curving out over the temple; his left
curtain is heavier, falling to the top of his glasses with one long strand across the left lens
and the outer lock flicking out at the temple. The crown is layered and tousled, its locks
fanning out like shingles with lifted tips and a cowlick at the back. The sides end at mid-ear and the back
at the nape. Laid out like tools/make_han_hair_ugc.py (wide grooved locks, staggered ends).

Same construction as tools/make_morrigan_hair_ugc.py (helpers from make_jenna_hair_ugc.py):
ribbon locks with a centre ridge over a full scalp cap, built in Roblox head space (Y up, -Z
front, +X the hero's right) on a 1.2-stud reference head. Export with the hero-remodel skill's
scripts/blender_export_hair.py (docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random
from mathutils import Vector

OUT_DIR = r"C:\Projects\infinite-tower\assets\hair"
NAME = "VaneHair"
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

# --- Scalp cap: full coverage under the locks, down behind the ears and to the nape --------
def cap():
    rings, segs = 22, 44
    verts = {}
    for i in range(rings + 1):
        y = CY + RY - (RY + 0.95) * i / rings
        for j in range(segs):
            th = 2 * math.pi * j / segs
            c = math.cos(th)
            # Hairline at the front, easing down the temples to behind the ears and the nape,
            # with no step between them.
            if c > 0.2:
                limit = -0.14 + 0.44 * min(1.0, (c - 0.2) / 0.55) ** 1.4
            else:
                limit = -0.14 - 0.1 * min(1.0, (0.2 - c) / 0.8)  # ends just above the back locks' tips
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

def ribbon(ctrl, width, thick=0.035, segs=16, tip=2.5, root=0.6, twist=0.0):
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

PART = shell(math.radians(14), 0.7, 0.06)  # off-centre middle part, a little towards his right (+X)
CROWN = Vector((0.04, CY + RY + 0.04, 0.14))

def lock(pts, width, thick=0.036, segs=14, tip=2.6, twist=0.0):
    ribbon([jitter(p, 0.012) for p in pts], width, thick, segs=segs, tip=tip, root=0.6, twist=twist)

# 1. Crown: wide layered locks fanning out from the crown in every direction (except the front,
#    which the fringe covers). Their tips lift well off the head, which gives the top its volume
#    and the tousled silhouette of the art. Ends are staggered so they don't form a brim.
for i in range(11):
    th = math.radians(-180 + i * (360 / 11) + rng.uniform(-6, 6))
    if math.cos(th) > 0.62:
        continue
    end_y = rng.uniform(0.32, 0.5)
    # The lift grows steadily along the lock, so neighbours overlap like shingles instead of
    # crossing each other.
    lock([CROWN + Vector((rng.uniform(-0.03, 0.03), 0, rng.uniform(-0.03, 0.03))),
          shell(th, 0.86, 0.08), shell(th + rng.uniform(-0.06, 0.06), 0.68, 0.12),
          shell(th + rng.uniform(-0.1, 0.1), end_y + 0.08, 0.15),
          shell(th + rng.uniform(-0.12, 0.12), end_y + rng.uniform(0.0, 0.05), 0.19 + rng.uniform(0, 0.04))],
         0.3, 0.042, segs=14, tip=2.5, twist=rng.uniform(-0.1, 0.1))

# 2. Sides and back: a short lower layer, ending at mid-ear on the sides and at the nape behind,
#    ends staggered and flicking out.
for i in range(13):
    th = math.radians(72 + i * (216 / 12) + rng.uniform(-4, 4))
    back = max(0.0, -math.cos(th))  # 1 at the centre back
    y_end = 0.0 - 0.24 * back - 0.08 * rng.random()
    lock([shell(th, 0.7, 0.07), shell(th, 0.4, 0.1), shell(th + rng.uniform(-0.06, 0.06), (y_end + 0.4) / 2, 0.12),
          shell(th + rng.uniform(-0.08, 0.08), y_end, 0.15 + 0.05 * rng.random())],
         0.25, 0.038, segs=14, tip=2.6, twist=rng.uniform(-0.2, 0.2))

# 3. Fringe from the off-centre part. His right curtain (+X) is short and swoops out over the
#    temple, leaving a little forehead by the part. His left curtain (-X) is heavier: it falls to
#    the top of the glasses, one long strand crosses the left lens, and the outer lock flicks out
#    at the temple.
FRINGE = [  # (end x, end y, width)
    (0.5, 0.1, 0.21), (0.37, 0.2, 0.21), (0.24, 0.26, 0.18),   # his right: the swoop
    (0.08, 0.04, 0.14),                                         # long strand beside the part
    (-0.06, 0.12, 0.19), (-0.19, 0.05, 0.2), (-0.31, -0.08, 0.17),  # his left, over the glasses
    (-0.43, 0.06, 0.2), (-0.53, -0.04, 0.2),                   # his left temple, flicking out
]
part_x = PART.x
for x_end, y_end, w in FRINGE:
    th_end = math.asin(max(-0.95, min(0.95, x_end / 0.78)))
    right = x_end > part_x + 0.1
    # The swoop arcs sideways first, then down; the rest fall more directly.
    mid = shell(th_end * (0.85 if right else 0.6), 0.5 if right else 0.44, 0.11)
    end = shell(th_end * (1.06 if right else 1.0), y_end, 0.1 + 0.04 * abs(x_end))
    flick = Vector((0.04 if right else (-0.03 if x_end < -0.4 else 0), 0, 0))
    lock([PART + Vector((rng.uniform(-0.04, 0.04), 0.02, 0)), shell(th_end * 0.35, 0.66, 0.09), mid,
          (mid + end) / 2 + Vector((0, 0, -0.03)), end + flick], w, 0.038, segs=16, tip=2.7, twist=rng.uniform(-0.15, 0.15))

# 4. Temple locks, so no scalp shows between the fringe and the short sides.
for side, ends in ((1, [(48, 0.1, 0.2), (60, 0.02, 0.21)]), (-1, [(48, -0.02, 0.2), (60, -0.04, 0.21)])):
    for th_deg, y_end, w in ends:
        th = math.radians(th_deg) * side
        lock([shell(th * 0.5, 0.76, 0.07), shell(th * 0.85, 0.52, 0.09), shell(th, 0.26, 0.1),
              shell(th * 1.04, y_end, 0.16)], w, 0.036, segs=12, tip=2.6, twist=0.15 * side)

# 5. Cowlick: two broad locks lifting up and back off the back of the crown, the raised volume
#    the art shows behind his part.
for th_deg, reach in [(150, 0.16), (-160, 0.14)]:
    th = math.radians(th_deg + rng.uniform(-5, 5))
    lock([CROWN + Vector((0, 0.01, 0.04)), shell(th, 0.84, 0.12), shell(th, 0.74, 0.12 + reach * 0.7),
          shell(th * 1.02, 0.78, 0.12 + reach)], 0.28, 0.042, segs=10, tip=2.5)

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

mat = bpy.data.materials.get("VaneHairViolet") or bpy.data.materials.new("VaneHairViolet")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
col = (0.19, 0.03, 0.58, 1)  # rgb(120, 50, 200) in linear
if bsdf:
    bsdf.inputs[0].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.4
mat.diffuse_color = col
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("VaneHair tris", tris)
result = {"tris": tris}
