"""
Caspian's hair, UGC-accessory style (run inside Blender: exec(open(path, encoding="utf-8").read())).

From his second reference art: a messy, voluminous auburn shag. Spiky, pointed bangs fall to
his brows with one longer piece between the eyes; spiky locks cover the tops of his ears and
flick outward; the back is layered to the nape with outward flicks, which with the bangs gives
the crown its volume. Built UGC style (thick, rounded clumps over a lightly grooved base sheet) with the
helpers from tools/make_isabelle_hair_ugc.py. Textured: the mesh has UVs with V mapped to height
on the head (1 at the crown, about 0.5 at the brows, 0 at the nape) for
assets/hair/caspian_hair_texture.png (assets/hair/make_caspian_hair_texture.py): darker roots, a
warm shine near the crown, lighter tips and strand lines. Roblox head
space (Y up, -Z front, +X the hero's right) on a 1.2-stud reference head. Export with the
hero-remodel skill's scripts/blender_export_hair.py.
"""

import bpy, bmesh, math, os, random
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


# 1. Base sheet: stops above the bangs in front, reaches the tops of the ears at the sides and
#    the nape at the back, so no scalp shows between the clumps.
FRONT = math.radians(70)

def hem(th):
    a = abs(th)
    if a <= FRONT:
        return 0.5
    t = min(1.0, (a - FRONT) / math.radians(40))
    t = t * t * (3 - 2 * t)
    return 0.5 + (-0.24 - 0.5) * t

curtain(-math.pi, math.pi, 0.915, hem, 0.05, 0.08, thick=0.04, nth=128, ny=8, grooves=24, depth=0.01)

crown = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=0.1)
for v in crown["verts"]:
    v.co = B(Vector((v.co.x * 1.4, v.co.z * 0.5, v.co.y * 1.4)) + shell(0, CY + RY, 0.0) + Vector((0, -0.01, 0.02)))

# 2. Bangs: spiky, pointed clumps from the front of the crown, standing out with volume over the
#    forehead and ending around the brows at staggered heights; one longer piece falls between
#    the eyes. A narrower layer behind fills the gaps.
for k, th_deg in enumerate(range(-66, 67, 12)):
    th = math.radians(th_deg + rng.uniform(-2, 2))
    edge = abs(th_deg) / 66
    y_end = 0.18 - 0.06 * edge + rng.uniform(-0.05, 0.05)
    if abs(th_deg) <= 6:
        y_end = 0.02  # the long piece between the eyes
    sweep = math.radians(rng.uniform(-6, 6))
    pts = [shell(th * 0.3, 0.88, 0.0), shell(th * 0.7, 0.78, 0.12), shell(th * 0.95, 0.56, 0.15),
           shell(th + sweep * 0.6, (0.56 + y_end) / 2, 0.13), shell(th + sweep, y_end, 0.08)]
    clump(pts, rng.uniform(0.13, 0.16), 0.065, segs=16, tip=rng.uniform(2.0, 2.5))
for th_deg in range(-60, 61, 12):
    th = math.radians(th_deg)
    pts = [shell(th * 0.3, 0.86, -0.02), shell(th * 0.7, 0.74, 0.08), shell(th * 0.95, 0.5, 0.1), shell(th, 0.24, 0.07)]
    clump(pts, 0.12, 0.05, segs=12, tip=2.4)

# 3. Sides: spiky clumps over the tops of the ears, flicking outward at the tips.
for side in (1, -1):
    for th_deg, y_end in [(74, 0.04), (88, -0.06), (102, -0.12), (116, -0.16)]:
        th = math.radians(th_deg + rng.uniform(-3, 3)) * side
        y_end += rng.uniform(-0.05, 0.04)
        pts = [shell(th * 0.85, 0.66, 0.08), shell(th, 0.38, 0.13), shell(th, 0.12, 0.14),
               shell(th * 1.03, y_end, 0.14 + rng.uniform(0.06, 0.12))]
        clump(pts, rng.uniform(0.15, 0.18), 0.065, segs=14, tip=rng.uniform(2.0, 2.4), twist=0.08 * side)

# 4. Back: layered spiky clumps from the crown to the nape, each with its own width, length,
#    depth and outward flick.
for k, th_deg in enumerate(range(124, 237, 12)):
    th = math.radians(th_deg + rng.uniform(-3, 3))
    off = 0.11 + (0.025 if k % 2 else 0.0)
    y_end = rng.uniform(-0.44, -0.26)
    pts = [shell(th * 0.5 + math.pi * 0.5, 0.93, 0.04), shell(th, 0.78, off), shell(th, 0.42, off + 0.02),
           shell(th, 0.05, off + 0.02), shell(th + rng.uniform(-0.08, 0.08), y_end, off + rng.uniform(0.08, 0.14))]
    clump(pts, rng.uniform(0.15, 0.2), 0.065, segs=14, tip=rng.uniform(2.0, 2.5))

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)

# UVs: V by height (1 at the crown, about 0.5 at the brows, 0 at the nape), U across the head
# from his left to his right (no wrap, so no seam). Kept just inside 0..1: a V of exactly 1
# samples across the wrap into the other end of the texture.
uvl = bm.loops.layers.uv.verify()
for f in bm.faces:
    for loop in f.loops:
        co = loop.vert.co  # Blender (x, y, z) = Roblox (x, -z, y)
        v = max(0.02, min(0.98, (co.z + 0.5) / 1.45))
        u = max(0.02, min(0.98, (co.x + 1.0) / 2.0))
        loop[uvl].uv = (u, v)
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
tex_path = os.path.join(OUT_DIR, "caspian_hair_texture.png")
if bsdf:
    bsdf.inputs[0].default_value = col
    bsdf.inputs["Roughness"].default_value = 0.45
    if os.path.exists(tex_path):
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(tex_path, check_existing=True)
        mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs[0])
mat.diffuse_color = col
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print(NAME, "tris", tris)
