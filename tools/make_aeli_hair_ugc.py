"""
Aeli's hair, UGC-accessory style (run inside Blender: exec(open(path, encoding="utf-8").read())).

From her reference art: long ash-blond hair swept back from a near-centre part, leaving the
forehead clear. Long face-framing locks fall in front of the (pointed) ears down to the collar.
Everything else is gathered at the back of the crown into one thick three-strand braid that
curves back over her right shoulder and hangs behind it to the waist, ending in a tie and a
short tuft. The silver crown clasp, the braid's silver cuff and the elf ears are costume pieces,
not part of this mesh (the mesh is untextured and takes one colour).

The braid follows the art's stylised plait: stacked plump teardrop lobes that alternate left
and right, each slanting down from its edge into the middle and overlapping the one above, so
the outer face reads as a herringbone of Vs (a true three-strand tube weave read as a twisted
rope at this size). A filled core behind the lobes stops gaps showing through.

Same construction as tools/make_han_hair_ugc.py (helpers from make_jenna_hair_ugc.py): ribbon
locks with a centre ridge over a full scalp cap, in Roblox head space (Y up, -Z front, +X the
hero's right) on a 1.2-stud reference head. Export with the hero-remodel skill's
scripts/blender_export_hair.py (docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random
from mathutils import Vector

OUT_DIR = r"C:\Projects\infinite-tower\assets\hair"
NAME = "AeliHair"
rng = random.Random(431)

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

# Where the hair gathers into the braid: the back of the crown, a little to her right, sitting
# just off the scalp so the locks pile up into it.
GATHER = Vector((0.08, 0.6, 0.66))
PART = math.radians(4)  # near-centre part

# 1. Swept-back top: smooth locks from the hairline over the top of the head into the gather.
for th_deg in range(-78, 79, 13):
    th = math.radians(th_deg + rng.uniform(-2, 2)) + (PART if th_deg >= 0 else -PART) * 0.5
    top = shell(th * 0.45, 0.93, 0.08)
    pts = [shell(th, 0.34, 0.02), shell(th * 0.9, 0.6, 0.06), shell(th * 0.8, 0.8, 0.08), top,
           top.lerp(GATHER, 0.55) + Vector((0, 0.05, 0)), GATHER + Vector((rng.uniform(-0.04, 0.04), rng.uniform(-0.03, 0.03), 0))]
    ribbon([jitter(p, 0.01) for p in pts], 0.21, 0.04, segs=18, root=0.35, end_tie=True)

# 2. Sides and back: gathered up from behind the ears and the nape into the same gather, so
#    the back of the head reads swept up rather than loose.
for th_deg in range(96, 265, 15):
    th = math.radians(th_deg + rng.uniform(-3, 3))
    low = shell(th, -0.2 + rng.uniform(-0.03, 0.03), 0.05)
    pts = [low, shell(th, 0.12, 0.08), shell(th * 0.96 + math.pi * 0.04, 0.42, 0.09),
           shell(th, 0.6, 0.1).lerp(GATHER, 0.5), GATHER + Vector((rng.uniform(-0.04, 0.04), -0.03, 0.01))]
    lock(pts, 0.25, 0.04, segs=14, end_tie=True)

# 3. Face-framing locks: from beside the part, falling in front of the ears down past the jaw
#    to the collar, with a slight wave and the tips turning out a little. Two per side.
for side in (-1, 1):
    for th_deg, y_end, w in [(42, -0.62, 0.17), (58, -0.78, 0.18)]:
        th = math.radians(th_deg) * side
        wave = 0.05 * side
        pts = [shell(th * 0.35, 0.74, 0.06), shell(th * 0.8, 0.42, 0.09), shell(th, 0.1, 0.1) + Vector((wave, 0, 0)),
               shell(th * 1.04, -0.25, 0.11) - Vector((wave, 0, 0)), shell(th * 1.08, y_end + 0.15, 0.13),
               shell(th * 1.12, y_end, 0.17)]
        lock(pts, w, 0.036, segs=20, tip=2.6, twist=0.1 * side)

# 4. Two loose strands at the part, lying back over the forehead's hairline.
for th_deg, y_end in [(-8, 0.3), (10, 0.34)]:
    th = math.radians(th_deg)
    lock([shell(th, 0.72, 0.07), shell(th * 1.4, 0.5, 0.1), shell(th * 1.8, y_end, 0.1)], 0.1, 0.03, segs=10, tip=2.4)

# --- Braid -----------------------------------------------------------------------------------
# Centre line: out of the gather, back and down over her right shoulder, then hanging behind it
# to the waist. Head space, 1.2-stud units: the shoulders are about 0.7 below the head centre
# and the waist about 2.0 below; z > 0.8 keeps it outside the fur collar and cape.
BRAID_PATH = [GATHER + Vector((0.02, -0.04, 0.04)), Vector((0.2, 0.32, 0.86)), Vector((0.38, -0.1, 0.98)),
              Vector((0.5, -0.62, 0.98)), Vector((0.56, -1.18, 0.94)), Vector((0.58, -1.72, 0.9))]
BRAID_END = Vector((0.58, -1.92, 0.88))  # the silver cuff sits here (costume piece BraidCuff)

def braid(path, end, width0=0.46, width1=0.3, spacing=0.15, slant=34.0):
    """A plaited braid as stacked plump lobes, the stylised UGC/anime braid of the art: each
    plait is a teardrop that slants down from one edge into the middle, the lobes alternate
    left and right and overlap the one above, so the outer face reads as a herringbone of Vs.
    A filled core behind them keeps any gap between lobes from showing through."""
    centre = smooth_path(path + [end], 120)
    s = [0.0]
    for a, b in zip(centre, centre[1:]):
        s.append(s[-1] + (b - a).length)
    total = s[-1]
    def at(dist):
        for i in range(1, len(s)):
            if s[i] >= dist:
                f = (dist - s[i - 1]) / max(1e-9, s[i] - s[i - 1])
                return centre[i - 1].lerp(centre[i], f), (centre[i] - centre[i - 1]).normalized()
        return centre[-1], (centre[-1] - centre[-2]).normalized()
    def frame(tan):
        # Face the plait outward: away from the body (+Z, back) and a bit to her right.
        out = Vector((0.4, 0, 1)).normalized()
        out = (out - tan * out.dot(tan)).normalized()
        return out, tan.cross(out).normalized()

    # Core: a plain tube along the centre line, a little narrower than the lobes.
    rings, n, sides = [], 60, 8
    for k in range(n + 1):
        d = total * k / n
        c, tan = at(d)
        out, side = frame(tan)
        w = width0 + (width1 - width0) * d / total
        r = 0.24 * w * (1 - 0.35 * max(0.0, (d / total - 0.94) / 0.06))
        rings.append([bm.verts.new(B(c + side * (math.cos(2 * math.pi * j / sides) * r * 1.2)
                                     + out * (math.sin(2 * math.pi * j / sides) * r * 0.8))) for j in range(sides)])
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(sides):
            bm.faces.new([r0[j], r0[(j + 1) % sides], r1[(j + 1) % sides], r1[j]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])

    # Lobes.
    count = int((total - 0.1) / spacing)
    a_s = math.radians(slant)
    for k in range(count):
        d = 0.08 + k * spacing
        c, tan = at(d)
        out, side = frame(tan)
        w = width0 + (width1 - width0) * d / total
        sgn = 1 if k % 2 == 0 else -1
        # Long axis runs down the braid and in toward the middle; the lobe sits on its own side.
        L = (tan * math.cos(a_s) - side * sgn * math.sin(a_s)).normalized()
        Wd = L.cross(out).normalized()
        half_len = spacing * 1.35
        half_w = 0.29 * w
        half_d = 0.21 * w
        centre_pt = c + side * sgn * 0.2 * w + out * 0.06 * w
        # A teardrop: rounder at the outer, upper end and tapering into the middle.
        segs_l, segs_r = 7, 8
        grid = []
        for i in range(segs_l + 1):
            v = i / segs_l                      # 0 top (outer edge) -> 1 bottom (middle)
            along = (v - 0.5) * 2 * half_len
            prof = math.sin(math.pi * min(0.999, max(0.001, v))) ** 0.5 * (1.1 - 0.25 * v)
            ring = []
            for j in range(segs_r):
                a = 2 * math.pi * j / segs_r
                pnt = centre_pt + L * along + Wd * (math.cos(a) * half_w * prof) + out * (math.sin(a) * half_d * prof)
                ring.append(bm.verts.new(B(pnt)))
            grid.append(ring)
        for r0, r1 in zip(grid, grid[1:]):
            for j in range(segs_r):
                bm.faces.new([r0[j], r0[(j + 1) % segs_r], r1[(j + 1) % segs_r], r1[j]])
        bm.faces.new(list(reversed(grid[0])))
        bm.faces.new(grid[-1])

braid(BRAID_PATH, BRAID_END)

# Tuft below the tie: a few short locks fanning slightly out of the braid's end.
down = (BRAID_END - BRAID_PATH[-1]).normalized()
for k in range(5):
    a = 2 * math.pi * k / 5
    off = Vector((math.cos(a) * 0.05, 0, math.sin(a) * 0.05))
    pts = [BRAID_END + off * 0.5, BRAID_END + down * 0.14 + off, BRAID_END + down * 0.3 + off * 1.6 + Vector((0, rng.uniform(-0.03, 0.03), 0))]
    ribbon(pts, 0.07, 0.03, segs=8, tip=2.2, root=0.9)

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

mat = bpy.data.materials.get("AeliHairAsh") or bpy.data.materials.new("AeliHairAsh")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
col = (0.62, 0.52, 0.37, 1)  # rgb(206, 192, 164) in linear
if bsdf:
    bsdf.inputs[0].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.45
mat.diffuse_color = col
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print(NAME, "tris", tris)
