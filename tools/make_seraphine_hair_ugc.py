"""
Seraphine's hair, UGC-accessory style (run inside Blender: exec(open(path, encoding="utf-8").read())).

From her reference art: very long, straight silver-white hair, swept back off the forehead with
no fringe (the gilt circlet sits on the bare hairline), the top drawn up into a high round bun at
the crown, a few long, thin strands framing the face and falling in front of the shoulders to the
chest, and the rest hanging straight down her back to the hips in long, smooth clumps that end in
staggered points. Built UGC style: thick, rounded clumps over a lightly grooved base sheet; the
bun is a round core wrapped by coiled clumps.

Textured with assets/hair/seraphine_hair_texture.png (assets/hair/make_seraphine_hair_texture.py):
every lock and every bun coil is mapped along its own length (V from 1 at the root to 0 at the
tip, U across, a random slice per lock), so the strand lines follow the hair; the base sheet maps
V down from the crown.

Derived from tools/make_isabelle_hair_ugc.py (the same helpers and per-lock UVs). Roblox head
space (Y up, -Z front, +X the hero's right) on a 1.2-stud reference head. Export with the
hero-remodel skill's scripts/blender_export_hair.py (or the hero-creation skill's
scripts/run_hair_headless.py --export).
"""

import bpy, bmesh, math, os, random
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "SeraphineHair"
rng = random.Random(2310)

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
RX, RY, RZ = 0.72, 0.80, 0.74

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

# --- Ribbon lock ---------------------------------------------------------------------------
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

# Texture coordinates per vertex (VERT_UV), written to the loops before vertices are merged.
VERT_UV = {}
PROFILE_U = [1.0, 0.86, 0.5, 0.14, 0.0, 0.19, 0.5, 0.81]
uv_rng = random.Random(2311)  # separate from rng, so texture choices never change the shape

def zigzag(x):
    """0..1 back and forth (continuous, so a wrapped strip has no seam)."""
    return 0.02 + 0.96 * abs((x % 2) - 1)

def ribbon(ctrl, width, thick=0.035, segs=16, tip=2.5, root=0.6, normal_fn=None):
    pts = smooth_path(ctrl, segs)
    u_lo = uv_rng.uniform(0.02, 0.5)
    rings = []
    for s, p in enumerate(pts):
        t = s / segs
        a = pts[max(0, s - 1)]; b = pts[min(segs, s + 1)]
        tan = (b - a).normalized()
        nrm = (normal_fn or out_normal)(p)
        side = tan.cross(nrm)
        if side.length < 1e-5:
            side = tan.cross(Vector((0, 0, 1)))
        side.normalize()
        nrm = side.cross(tan).normalized()
        grow = root + (1 - root) * min(1.0, t / 0.18)
        shape = grow * (1 - t ** tip) * (1 + 0.15 * math.sin(math.pi * t))
        w = width * shape + 0.004
        h = thick * (0.5 + 0.5 * shape) + 0.003
        ring = [bm.verts.new(B(p + side * (sx * w) + nrm * (ny * h))) for sx, ny in PROFILE]
        for k, vert in enumerate(ring):
            VERT_UV[vert] = (u_lo + 0.46 * PROFILE_U[k], 0.98 - 0.96 * t)  # root at the top
        rings.append(ring)
    n = len(PROFILE)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new([r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])

def jitter(v, a=0.004):
    return Vector(v) + Vector((rng.uniform(-a, a), rng.uniform(-a, a), rng.uniform(-a, a)))

def clump(pts, width, thick=0.06, segs=14, tip=3.2, normal_fn=None):
    """One UGC-style hair clump: thick and rounded, keeping its width most of the way and
    narrowing to a soft point at the end."""
    ribbon([jitter(p) for p in pts], width, thick, segs=segs, tip=tip, root=0.75, normal_fn=normal_fn)

def curtain(th0, th1, y_top, y_end, off_top, off_bot, thick=0.045, nth=72, ny=12, grooves=17, depth=0.014):
    """A sheet of hair over the scalp between azimuths th0..th1, from y_top down to y_end(theta),
    with shallow vertical grooves for strand clumps."""
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
            vo = bm.verts.new(B(shell(th, y, off + groove)))
            vi = bm.verts.new(B(shell(th, y, off - thick)))
            VERT_UV[vo] = VERT_UV[vi] = (zigzag(u * 6), 0.98 - 0.5 * v)
            col_o.append(vo)
            col_i.append(vi)
        outer.append(col_o); inner.append(col_i)
    for i in range(nth):
        for j in range(ny):
            bm.faces.new([outer[i][j], outer[i + 1][j], outer[i + 1][j + 1], outer[i][j + 1]])
            bm.faces.new([inner[i][j + 1], inner[i + 1][j + 1], inner[i + 1][j], inner[i][j]])
    for i in range(nth):
        bm.faces.new([outer[i][0], inner[i][0], inner[i + 1][0], outer[i + 1][0]])
        bm.faces.new([outer[i + 1][ny], inner[i + 1][ny], inner[i][ny], outer[i][ny]])
    for j in range(ny):
        bm.faces.new([outer[0][j + 1], inner[0][j + 1], inner[0][j], outer[0][j]])
        bm.faces.new([outer[nth][j], inner[nth][j], inner[nth][j + 1], outer[nth][j + 1]])

# 1. Base sheet: smooth inner cap tucked cleanly under the sculpted front arches and crown
#    waves (thick enough at the center part to close any skin gap above the circlet) and down
#    to the nape at the back.
FRONT = math.radians(72)

def hem(th):
    a = abs(th)
    if a <= FRONT:
        u = a / FRONT
        return 0.460 - 0.290 * (u ** 1.45)
    t = min(1.0, (a - FRONT) / math.radians(34))
    t = t * t * (3 - 2 * t)
    return 0.17 + (-0.34 - 0.17) * t

curtain(-math.pi, math.pi, 1.02, hem, 0.020, 0.028, thick=0.032, nth=56, ny=7, grooves=12, depth=0.002)

# 2. The bun's place: high on the crown, set slightly back so the swept crown hair rises into it
#    gracefully and the front silhouette shows a soft parted crown below the bun.
BUN = Vector((0.0, 1.04, 0.24))
BUN_R = 0.28

# 3. The bun: a smooth rounded chignon core wrapped by one continuous ascending spiral coil
#    (adjacent turns sit side by side cleanly with zero separate-coil sawtooth clipping).
core = bmesh.ops.create_uvsphere(bm, u_segments=18, v_segments=12, radius=1.0)
for vert in core["verts"]:
    c = Vector((vert.co.x, vert.co.z, vert.co.y))
    u = math.atan2(c.x, c.z) / math.pi
    VERT_UV[vert] = (zigzag(u * 3), 0.65 + 0.25 * (c.y + 1) / 2)
    vert.co = B(BUN + Vector((c.x * BUN_R * 0.86, c.y * BUN_R * 0.76, c.z * BUN_R * 0.86)))

def bun_normal(p):
    n = p - BUN
    return n.normalized() if n.length > 1e-5 else Vector((0, 1, 0))

bun_pts = []
turns = 2.8
for i in range(31):
    u = i / 30
    a = -0.3 * math.pi + u * turns * math.pi * 2.0
    y = -0.78 + 1.56 * u
    y_c = max(-0.94, min(0.94, y))
    # Subtle spiral swell: ends tuck softly into the core so no exposed tip pokes out at top
    tuck = min(1.0, u / 0.12) * min(1.0, (1.0 - u) / 0.25)
    r = BUN_R * (0.72 + 0.28 * tuck) * math.sqrt(max(0.10, 1 - (y_c * 0.84) ** 2))
    bun_pts.append(BUN + Vector((math.sin(a) * r, y_c * BUN_R * 0.80, math.cos(a) * r)))
ribbon(bun_pts, 0.082, 0.044, segs=44, tip=2.4, root=0.82, normal_fn=bun_normal)

# 3b. Center-parted front curtain-bang arches & sleek swept crown:
#     Wide, smooth, shingle-layered waves tucked into the center part (-1.5 deg overlap) cleanly
#     above the inner curtain cap (off >= 0.040 at part with close 12-deg guide points so chord
#     interpolation never dips into the cap), arching around the forehead corners & temples and
#     sweeping upward-and-back smoothly into the bun / upper back.
for side in (-1, 1):
    fan_specs = [
        # (width, thick, root_scale, to_bun, [(th_deg, y, off), ...])
        (0.155, 0.020, 0.86, False, [(-1.5, 0.515, 0.040), (14, 0.465, 0.056), (32, 0.340, 0.060), (54, 0.215, 0.058), (82, 0.200, 0.054), (118, 0.290, 0.046), (150, 0.42, 0.038)]),
        (0.165, 0.018, 0.86, False, [(-1.5, 0.605, 0.040), (18, 0.570, 0.062), (40, 0.475, 0.066), (68, 0.385, 0.064), (104, 0.400, 0.057), (142, 0.520, 0.046)]),
        (0.175, 0.017, 0.86, True,  [(-1.0, 0.700, 0.040), (16, 0.685, 0.062), (36, 0.645, 0.070), (64, 0.600, 0.071), (98, 0.610, 0.066), (132, 0.700, 0.056)]),
        (0.180, 0.016, 0.84, True,  [(-0.5, 0.800, 0.042), (16, 0.788, 0.066), (38, 0.760, 0.076), (68, 0.735, 0.076), (104, 0.750, 0.070), (138, 0.820, 0.060)]),
        (0.175, 0.016, 0.82, True,  [(0.0,  0.895, 0.044), (16, 0.885, 0.068), (40, 0.868, 0.078), (74, 0.855, 0.080), (118, 0.870, 0.068)]),
    ]
    for k, (w, thk, root_w, to_bun, spec) in enumerate(fan_specs):
        pts = [shell(math.radians(th_deg) * side, y, off) for th_deg, y, off in spec]
        if to_bun:
            pts.append(BUN + Vector((side * 0.08, -BUN_R * 0.16, -0.05)))
        ribbon(pts, w, thk, segs=18, tip=2.2, root=root_w)

# 4. Face-framing strands: emerge smoothly from under the swept temple wave near the ears
#    and drape gracefully along the jawline and in front of the shoulders onto the chest.
for side in (1, -1):
    for th_deg, w, x_low, z_low, y_end, thick in [
        (62, 0.088, 0.49, -0.50, -1.28, 0.036),
        (74, 0.122, 0.58, -0.45, -1.52, 0.044),
    ]:
        th = math.radians(th_deg) * side
        pts = [
            shell(th * 0.90, 0.34, 0.042),
            shell(th * 0.96, 0.12, 0.060),
            shell(th * 0.88, -0.16, 0.062),
            Vector((x_low * side, -0.54, z_low)),
            Vector((x_low * 0.94 * side, (y_end - 0.54) * 0.54 - 0.54, z_low - 0.04)),
            Vector((x_low * 0.88 * side, y_end, z_low - 0.05)),
        ]
        clump(pts, w, thick, segs=15, tip=2.6)

# 5. Long back hair: clumps from the back of the head that fall straight down her back to the
#    hips (their roots start inside the bun, so the back hangs from under it, half up), drawn in
#    behind the shoulders (the back of the robe is at about z 0.4), with the tips staggered into
#    a soft V. Depth alternates so neighbours overlap cleanly.
def back_point(th, y, off):
    """Below the head the hair fan narrows behind the back instead of following the cylinder."""
    narrow = math.pi + (th - math.pi) * 0.72
    p = shell(narrow, y, off)
    return Vector((p.x * 1.05, p.y, max(0.5 + off, p.z * 0.78)))  # close over the back, clear of the robe

for k, th_deg in enumerate(range(96, 265, 12)):
    th = math.radians(th_deg + rng.uniform(-2, 2))
    off = 0.062 + (0.022 if k % 2 else 0.0) + rng.uniform(-0.004, 0.008)
    centre = 1 - abs(th_deg - 180) / 84  # 1 in the middle of the back, 0 at the sides
    y_end = -1.75 - 0.72 * centre + rng.uniform(-0.1, 0.1)
    pts = [BUN + Vector((math.sin(th) * 0.04, -BUN_R * 0.18, -0.03)), shell(th * 0.75 + math.pi * 0.25, 0.76, off - 0.025), shell(th, 0.55, off), shell(th, 0.1, off + 0.01),
           back_point(th, -0.45, off + 0.04), back_point(th, (y_end - 0.45) * 0.5 - 0.2, off + 0.05),
           back_point(th, y_end, off + 0.06)]
    clump(pts, rng.uniform(0.24, 0.28), rng.uniform(0.052, 0.064), segs=16, tip=rng.uniform(2.8, 3.6))

# Center-back seal clump beneath the main layer so no hairline vertical slit shows through
clump([BUN + Vector((0.0, -BUN_R * 0.18, -0.03)), shell(math.pi, 0.76, 0.040), shell(math.pi, 0.50, 0.055), shell(math.pi, 0.05, 0.060),
       back_point(math.pi, -0.50, 0.078), back_point(math.pi, -1.45, 0.085), back_point(math.pi, -2.42, 0.090)],
      0.30, 0.050, segs=14, tip=3.2)

# 6. A softer top layer over the back, emerging smoothly from beneath the bun.
for th_deg in range(116, 245, 20):
    th = math.radians(th_deg + rng.uniform(-3, 3))
    y_end = rng.uniform(-2.05, -1.55)
    pts = [BUN + Vector((math.sin(th) * 0.04, -BUN_R * 0.14, -0.04)), shell(th * 0.75 + math.pi * 0.25, 0.80, 0.024), shell(th, 0.52, 0.088), shell(th, 0.0, 0.118),
           back_point(th, y_end, 0.124)]
    clump(pts, rng.uniform(0.20, 0.24), 0.048, segs=14, tip=rng.uniform(2.4, 3.2))

# Write the texture coordinates to the loops (before merging vertices, which would drop the
# per-vertex table's keys).
uvl = bm.loops.layers.uv.verify()
for face in bm.faces:
    for loop in face.loops:
        loop[uvl].uv = VERT_UV.get(loop.vert, (0.5, 0.96))

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

mat = bpy.data.materials.get("SeraphineHairSilver") or bpy.data.materials.new("SeraphineHairSilver")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
col = (0.78, 0.79, 0.86, 1)
tex_path = os.path.join(OUT_DIR, "seraphine_hair_texture.png")
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
