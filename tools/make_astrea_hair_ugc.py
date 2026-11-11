"""
Astrea's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

Rebuilt from her second reference art (bow drawn, silver tiara): very long, sleek, straight
silver hair with a soft lavender sheen. A centre part with curtain bangs swept out to each
temple and a few fine strands over the forehead, long locks framing the face that fall in front
of the shoulders down to the waist, and a straight back fall to the knees that flows a little
towards her right as if caught by the wind. Tips taper to fine points and the edge strands
separate, so the fall reads as layered hair rather than a sheet.

The user asked for the hair to be as accurate and beautiful as possible, past the usual budget.
Roblox's importer takes about 20k triangles per mesh, so the hair is two meshes, as for Edis:
AstreaHair (scalp, crown, bangs and the face-framing front locks) and AstreaBackHair (the long
back fall). Both are built in the same head space, so each is placed from its own export centre.

Same construction as tools/make_jenna_hair_ugc.py: ribbon locks with a centre ridge over a full
scalp cap, in Roblox head space on a 1.2-stud reference head. Export each object with the
hero-remodel skill's scripts/blender_export_hair.py (docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random, os, json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "AstreaHair"
BACK = "AstreaBackHair"
rng = random.Random(1127)

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
    uvl = bm.loops.layers.uv.verify()
    for i in range(rings):
        for j in range(segs):
            q = [(i, j), (i, (j + 1) % segs), (i + 1, (j + 1) % segs), (i + 1, j)]
            if all(k in verts for k in q):
                f = bm.faces.new([verts[k] for k in q])
                # Inner atlas column 2, strands running down from the crown; four faces span it.
                u0 = 0.5 + 0.25 * (j % 4) / 4
                for loop, (ii, jj) in zip(f.loops, q):
                    du = 0.25 / 4 if jj != j else 0.0
                    loop[uvl].uv = (u0 + du, 1.0 - 0.6 * ii / rings)
cap()

# --- Ribbon lock ---------------------------------------------------------------------------
# A flat card with a gentle crown across it (the strand detail comes from the texture), a
# narrow root and a fine tip. PROFILE_U places each profile point across the lock in UV space.
PROFILE = [(1.0, 0.0), (0.5, 0.24), (0.0, 0.32), (-0.5, 0.24), (-1.0, 0.0), (0.0, -0.22)]
PROFILE_U = [1.0, 0.75, 0.5, 0.25, 0.0, 0.5]
uv_rng = random.Random(4242)  # separate from rng, so texture choices never change the shape
# Atlas columns (assets/hair/make_astrea_hair_texture.py): 0-1 outer locks, 2-3 inner layers.
ATLAS_INSET = 0.01

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

def ribbon(ctrl, width, thick=0.035, segs=16, tip=2.2, root=0.55, end_tie=False, twist=0.0, inner=False, grow_len=0.18):
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
        grow = root + (1 - root) * min(1.0, t / grow_len)
        if end_tie:
            shape = grow * (1 - 0.75 * t ** 2)  # gathers into the tie instead of a point
        else:
            shape = grow * (1 - t ** tip) * (1 + 0.15 * math.sin(math.pi * t))
        w = width * shape + 0.004
        h = thick * (0.5 + 0.5 * shape) + 0.003
        rings.append([bm.verts.new(B(p + side * (sx * w) + nrm * (ny * h))) for sx, ny in PROFILE])
    n = len(PROFILE)
    col = uv_rng.choice((2, 3) if inner else (0, 1))
    u_lo, u_span = col * 0.25 + ATLAS_INSET, 0.25 - 2 * ATLAS_INSET
    uv_of = {}
    for s, ring in enumerate(rings):
        for k, v in enumerate(ring):
            uv_of[v] = (u_lo + u_span * PROFILE_U[k], 1.0 - s / segs)  # v = 1 at the root
    uvl = bm.loops.layers.uv.verify()
    faces = []
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            faces.append(bm.faces.new([r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]]))
    faces.append(bm.faces.new(list(reversed(rings[0]))))
    faces.append(bm.faces.new(rings[-1]))
    for f in faces:
        for loop in f.loops:
            loop[uvl].uv = uv_of[loop.vert]


def jitter(v, a=0.03):
    return Vector(v) + Vector((rng.uniform(-a, a), rng.uniform(-a, a), rng.uniform(-a, a)))


PART = shell(0.0, 0.68, 0.05)  # centre part above the forehead
CROWN = Vector((0.0, CY + RY + 0.03, 0.16))

def sway(pts, flow=0.0, amp=0.0, phase=0.0, below=0.1):
    """Straight hair with life: a slow S-curve and a sideways flow (towards +X, her right)
    that grows towards the tip, on the hanging part of the lock only."""
    out = [pts[0]]
    n = len(pts)
    for i, p in enumerate(pts[1:], 1):
        t = i / (n - 1)
        if p.y < below:
            th = math.atan2(p.x, -(p.z - CZ))
            side = Vector((math.cos(th), 0, math.sin(th)))
            p = p + side * (amp * math.sin(1.6 * math.pi * t + phase)) + Vector((flow * t * t, 0, 0))
        out.append(p)
    return out

def hang(th, y_end, off, steps=7, flare_rate=0.1, flare_max=0.38):
    """Lock from the scalp down past the head at azimuth th, flaring gently (sleek hair)."""
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
    mat = bpy.data.materials.get("AstreaHairSilver") or bpy.data.materials.new("AstreaHairSilver")
    mat.use_nodes = True
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf:
        bsdf.inputs[0].default_value = colour
        bsdf.inputs["Roughness"].default_value = 0.35
        # Preview with the strand texture (Roblox gets the same PNG as the mesh's TextureId)
        tex_path = os.path.join(OUT_DIR, "astrea_hair_texture.png")
        if os.path.exists(tex_path) and not any(n.type == "TEX_IMAGE" for n in mat.node_tree.nodes):
            tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = bpy.data.images.load(tex_path, check_existing=True)
            mat.node_tree.links.new(tex.outputs[0], bsdf.inputs[0])
    mat.diffuse_color = colour
    me.materials.append(mat)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print(name, "tris", tris)
    return ob

COLOUR = (0.78, 0.8, 0.9, 1)

# ===== AstreaHair: the head part =========================================================

# 1. Sleek crown: a smooth top layer swirling out from the crown over the sides and back,
# ending in staggered soft tips on the upper back of the head. The bangs and front locks cover
# the front half, and the long fall starts underneath this layer, so nothing cuts through it.
for i in range(15):
    th = math.radians(70 + i * (220 / 14))
    behind = math.cos(th) < -0.3
    y_end = rng.uniform(0.12, 0.36) if behind else rng.uniform(-0.05, 0.2)
    # Start in a ring round the crown, not at one point: converging cards form a criss-cross
    # lattice. The textured scalp shows strands radiating from the crown inside the ring.
    o = 0.016 * (i % 2)  # neighbours alternate under/over, so overlapping cards stack
    pts = [shell(th, 0.87, 0.06 + o), shell(th, 0.8, 0.12 + o), shell(th, 0.62, 0.13 + o),
           shell(th, (0.62 + y_end) / 2, 0.135 + o), shell(th, y_end, 0.14 + o)]
    ribbon(pts, 0.34, 0.026, segs=16, tip=1.8, root=0.12, grow_len=0.45)

# 2. Curtain bangs from the centre part. Each bang is a smooth arc, not a diagonal: it leaves
# the part sweeping sideways while staying high on the forehead, then curves down at the temple
# (azimuth eases out like a sine, height eases in like 1 - cos), so the set reads as a rounded
# curtain framing the face. The outer bangs are longer and lie on top of the inner ones.
for side in (-1, 1):
    for k, (x_end, y_end, w) in enumerate([(0.38, 0.1, 0.22), (0.46, -0.04, 0.24), (0.53, -0.2, 0.25), (0.59, -0.36, 0.24)]):
        th_end = math.asin(min(0.95, x_end / 0.8)) * side
        th_root = side * math.radians(6)  # all four leave the part from one point
        y_root = 0.66
        lift = 0.014 * k  # outer bangs on top
        pts = []
        for j in range(7):
            u = j / 6
            th = th_root + (th_end - th_root) * math.sin(u * math.pi / 2)
            y = y_root - (y_root - y_end) * (1 - math.cos(u * math.pi / 2)) ** 0.85
            pts.append(shell(th, y, 0.07 + lift + 0.03 * u))
        ribbon([jitter(q, 0.002) for q in pts], w, 0.034, segs=22, tip=2.3, root=0.35)

# 3. Long front locks: from the temples, down beside the cheeks, over the front of each
# shoulder and onto the chest, the longest reaching the waist.
for side in (-1, 1):
    for k, (th_deg, x_low, y_end, w) in enumerate([(58, 0.52, -1.75, 0.2), (68, 0.62, -2.35, 0.24),
                                                    (78, 0.72, -2.05, 0.23), (88, 0.8, -1.55, 0.21)]):
        th = math.radians(th_deg) * side
        jx = rng.uniform(-0.03, 0.03)
        pts = [shell(th * 0.8, 0.45, 0.05), shell(th * 0.92, 0.25, 0.08), shell(th, 0.0, 0.11),
               shell(th * 1.03, -0.35, 0.13),
               Vector((side * (x_low - 0.02 + jx), -0.75, -0.3 - 0.02 * k)),
               Vector((side * (x_low + jx), -1.2, -0.42 - 0.02 * k)),
               Vector((side * (x_low - 0.02 + jx), (y_end - 1.2) / 2 - 0.6, -0.45 - 0.02 * k)),
               Vector((side * (x_low - 0.06 + jx), y_end, -0.43 - 0.02 * k))]
        pts = sway(pts, 0.0, 0.03, rng.uniform(0, 6.28), below=-0.4)
        ribbon([jitter(p, 0.006) for p in pts], w, 0.034, segs=36, tip=3.0, twist=rng.uniform(-0.25, 0.25))
    # A fine separated strand in front of each lock group
    th = math.radians(64) * side
    pts = [shell(th * 0.85, 0.35, 0.1), shell(th, 0.1, 0.14), shell(th * 1.04, -0.35, 0.15),
           Vector((side * 0.5, -0.8, -0.36)), Vector((side * 0.47, -1.4, -0.47)), Vector((side * 0.44, -1.9, -0.48))]
    ribbon(pts, 0.07, 0.022, segs=24, tip=2.6, root=0.8)

# 4. Shaggy layers (the layered UGC look): medium locks from the crown over the sides, ending
# at cheek, jaw and shoulder height with tips that flick outward, over the long hair below.
for side in (-1, 1):
    for k in range(6):
        th = math.radians(side * (62 + 13 * k + rng.uniform(-4, 4)))
        y_end = rng.uniform(-0.35, -0.95) if k < 4 else rng.uniform(-0.2, -0.6)
        flick = rng.uniform(0.32, 0.44)
        pts = [shell(th * 0.9, 0.78, 0.15), shell(th, 0.45, 0.16), shell(th, 0.1, 0.17),
               shell(th * 1.02, (0.1 + y_end) / 2, 0.2), shell(th * 1.05, y_end + 0.08, flick - 0.06),
               shell(th * 1.08, y_end, flick)]
        ribbon([jitter(q, 0.006) for q in pts], rng.uniform(0.2, 0.26), 0.03, segs=20, tip=2.4, root=0.4)

# 5. A stray strand rising from the crown and arcing forward (the ahoge in both references).
for k, (dx, h, reach) in enumerate(((0.02, 0.24, 0.4),)):
    base = CROWN + Vector((dx, -0.05, -0.08))
    pts = [base, base + Vector((dx, h * 0.8, -reach * 0.35)), base + Vector((dx * 2, h, -reach * 0.7)),
           base + Vector((dx * 3, h * 0.55, -reach))]
    ribbon(pts, 0.06, 0.02, segs=16, tip=2.0, root=0.8)

head_part = finish(NAME, COLOUR)

# ===== AstreaBackHair: the long straight fall ===========================================
bm = bmesh.new()

# 6. The long fall: straight locks down her back to the knees, the centre longest, the tips
# flowing towards her right. Two interleaved layers so no gaps show between them.
for layer, (count, off, width) in enumerate([(24, 0.07, 0.27), (20, 0.13, 0.24)]):
    for i in range(count):
        th = math.radians(94 + (i + 0.5 * layer) * (172 / (count - 1)))
        edge = abs(math.cos(th + math.pi))  # 1 at the centre back
        y_end = -2.4 - 1.25 * edge ** 0.7 - 0.35 * rng.random() - 0.15 * layer
        pts = hang(th, y_end, off + 0.022 * (i % 2), steps=14)
        # Stay under the crown layer (offset 0.13-0.14) until below its tips, so the two never
        # cross (crossing cards make a criss-cross lattice on the back of the head).
        low = 0.05 + 0.03 * layer
        full = [off + 0.022 * (i % 2) + (0.0 if q.y > 0.0 else min(0.38, -q.y * 0.1)) for q in pts]
        pts = [shell(th, q.y, low + (f - low) * min(1.0, max(0.0, (0.1 - q.y) / 0.5))) for q, f in zip(pts, full)]
        pts[0] = shell(th, 0.74, 0.04 + 0.03 * layer)
        pts = sway(pts, 0.28 + 0.1 * rng.random(), 0.035, rng.uniform(0, 6.28))
        lock = [jitter(p, 0.004) for p in pts]
        ribbon(lock, width, 0.034, segs=24, tip=3.0, root=0.9, inner=(layer == 0))
        # On the outer layer, a split wisp peels off the last third of every other lock.
        if layer == 1 and i % 2 == 0:
            branch = lock[-6:]
            sidestep = Vector((rng.choice((-1, 1)) * 0.09, -0.05, 0.02))
            wisp = [branch[0]] + [q + sidestep * ((j + 1) / (len(branch) - 1)) ** 1.5 for j, q in enumerate(branch[1:])]
            wisp[-1] = wisp[-1] + Vector((0, -0.12, 0))
            ribbon(wisp, 0.06, 0.02, segs=12, tip=2.4, root=0.9)

# 7. Separated fine strands at the edges and over the fall, so the silhouette has wisps.
for i in range(10):
    th = math.radians(rng.uniform(100, 260))
    y_end = rng.uniform(-3.4, -2.2)
    pts = hang(th, y_end, 0.14, steps=12)
    pts = [shell(th, 0.15, 0.13)] + [q for q in pts if q.y < 0.1]  # start below the crown tips
    pts = sway(pts, 0.35 + 0.2 * rng.random(), 0.05, rng.uniform(0, 6.28))
    ribbon([jitter(p, 0.01) for p in pts], 0.08, 0.022, segs=22, tip=2.6, root=0.8, twist=rng.uniform(-0.4, 0.4))

back_part = finish(BACK, COLOUR)
