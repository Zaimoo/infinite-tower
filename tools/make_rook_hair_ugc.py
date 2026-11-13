"""Rook's hair, textured UGC-accessory style (run inside Blender).

Wild, voluminous rust-copper lion-like warrior mane from his reference art:
- Exposed forehead with a few sharp center widow's-peak strands, framed by bold swept-back
  flame-shaped crown spikes radiating upward and outward-back.
- Clean cheek/jaw-framing side locks curling inward slightly toward his neck, backed by crisp
  outward-flaring temple spikes at ear and cheekbone height.
- Dense two-tier back mane falling cleanly to the upper shoulders/fur mantle.

Blender coordinates: +Y is back (-Y is front/face), +Z is up. Built in authored Roblox head
space via B(p) = (p.x, -p.z, p.y) on a 1.2-stud rounded RefHead and UV-mapped for
assets/hair/rook_hair_texture.png.
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "RookHair"
rng = random.Random(8427)

for obj in list(bpy.data.objects):
    if obj.name.startswith("RookHair") or obj.name in ("Cube", "RobloxHeadRef"):
        bpy.data.objects.remove(obj, do_unlink=True)
for obj in bpy.data.objects:
    if obj.name.endswith("Hair") and obj.name != NAME:
        ob_hide = obj.hide_set(True)

if not bpy.data.objects.get("RefHead"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.6, depth=1.2, location=(0, 0, 0))
    head = bpy.context.active_object
    head.name = "RefHead"
    bev = head.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.18
    bev.segments = 5
    skin = bpy.data.materials.new("RefSkin")
    skin.diffuse_color = (0.76, 0.52, 0.38, 1)
    head.data.materials.append(skin)
    bpy.ops.object.shade_smooth()


def B(p):
    return Vector((p[0], -p[2], p[1]))


CX, CY, CZ = 0.0, 0.16, 0.04
RX, RY, RZ = 0.66, 0.72, 0.67


def shell(theta, y, off=0.0):
    """Point on the scalp at azimuth theta (0 = front, +pi/2 = his right +X) and height y."""
    k = 1.0 if y <= CY else math.sqrt(max(0.0, 1 - ((y - CY) / RY) ** 2))
    k = max(k, 0.06)
    x = (RX + off) * k * math.sin(theta)
    z = CZ - (RZ + off) * k * math.cos(theta)
    yy = min(y, CY + RY + off)
    return Vector((CX + x, yy + (off * 0.55 if y > CY else 0), z))


def out_normal(p):
    axis = Vector((CX, min(p.y, CY), CZ))
    n = p - axis
    return n.normalized() if n.length > 1e-5 else Vector((0, 1, 0))


bm = bmesh.new()
VERT_UV = {}

PROFILE = [(1.0, 0.0), (0.55, 0.44), (0.0, 0.85), (-0.55, 0.44), (-1.0, 0.0), (0.0, -0.35)]
U_PROFILE = [0.02, 0.25, 0.50, 0.75, 0.98, 0.50]


def smooth_path(pts, n):
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


def ribbon(ctrl, width, thick=0.055, segs=14, tip=2.0, root=0.72, twist=0.0, face_hint=None):
    pts = smooth_path(ctrl, segs)
    rings = []
    for s, p in enumerate(pts):
        t = s / segs
        a = pts[max(0, s - 1)]
        b = pts[min(segs, s + 1)]
        tan = (b - a).normalized()
        nrm = Vector(face_hint).normalized() if face_hint is not None else out_normal(p)
        side = tan.cross(nrm)
        if side.length < 1e-4:
            side = tan.cross(Vector((0, 0, -1)))
        if side.length < 1e-4:
            side = tan.cross(Vector((1, 0, 0)))
        side.normalize()
        nrm = side.cross(tan).normalized()
        ang = twist * t
        side, nrm = side * math.cos(ang) + nrm * math.sin(ang), nrm * math.cos(ang) - side * math.sin(ang)
        grow = root + (1 - root) * min(1.0, t / 0.16)
        shape = grow * (1 - t ** tip) * (1 + 0.14 * math.sin(math.pi * t))
        w = width * shape + 0.004
        h = thick * (0.55 + 0.45 * shape) + 0.004
        ring = []
        v_tex = max(0.03, 0.96 - 0.90 * t)
        for idx, (sx, ny) in enumerate(PROFILE):
            vo = bm.verts.new(B(p + side * (sx * w) + nrm * (ny * h)))
            VERT_UV[vo] = (U_PROFILE[idx], v_tex)
            ring.append(vo)
        rings.append(ring)
    n = len(PROFILE)
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            bm.faces.new([r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def clump(pts, width, thick=0.06, segs=14, tip=2.1, root=0.72, twist=0.0, face_hint=None):
    ribbon(pts, width, thick, segs=segs, tip=tip, root=root, twist=twist, face_hint=face_hint)


def curtain(th0, th1, y_top, y_end, off_top, off_bot, thick=0.04, nth=96, ny=8, grooves=20, depth=0.01):
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
            uv = (0.04 + 0.92 * abs((u * 8) % 2 - 1), 0.98 - 0.42 * v)
            VERT_UV[vo] = uv
            VERT_UV[vi] = uv
            col_o.append(vo)
            col_i.append(vi)
        outer.append(col_o)
        inner.append(col_i)
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


# 1. Scalp base sheet: sits inside the swept-back hairline & covers all seams cleanly.
FRONT = math.radians(52)


def hem(th):
    a = abs(th)
    if a <= FRONT:
        return 0.48 - 0.04 * math.cos(a / FRONT * math.pi * 0.5)
    t = min(1.0, (a - FRONT) / math.radians(48))
    t = t * t * (3 - 2 * t)
    return 0.48 + (-0.28 - 0.48) * t


curtain(-math.pi, math.pi, 0.88, hem, 0.03, 0.055, thick=0.04, nth=96, ny=8, grooves=18, depth=0.01)

crown = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=0.11)
for v in crown["verts"]:
    v.co = B(Vector((v.co.x * 1.4, v.co.z * 0.45, v.co.y * 1.4)) + shell(0, CY + RY, 0.0) + Vector((0, -0.02, 0.02)))


# 2. Front forehead: a subtle center widow's-peak tuff + faint brow framing wisps (no row of fangs).
for th_deg, y_end, x_off, w in [(-4, 0.24, 0.03, 0.115), (7, 0.30, -0.04, 0.10)]:
    th = math.radians(th_deg)
    clump([shell(th * 0.4, 0.76, 0.08), shell(th * 0.8, 0.54, 0.12), shell(th, 0.40, 0.11), shell(th + x_off, y_end, 0.09)], w, 0.052, segs=12, tip=1.7, root=0.72)


# 3. Crown & Lion-Mane Fan: smooth natural arch over the forehead into jagged alternating
#    flame spikes around the crown matching his wild lion's mane silhouette.
for th_deg, y_start, lift_y, z_tip, y_tip, x_splay, width in [
    (-50, 0.44, 0.78, 0.28, 0.90, -0.34, 0.22),
    (-32, 0.45, 0.88, 0.34, 1.07, -0.22, 0.23),
    (-14, 0.45, 0.92, 0.38, 1.15, -0.09, 0.24),
    (2, 0.44, 0.95, 0.42, 1.24, 0.01, 0.25),
    (18, 0.45, 0.91, 0.37, 1.12, 0.11, 0.24),
    (34, 0.45, 0.86, 0.33, 1.04, 0.24, 0.23),
    (50, 0.44, 0.76, 0.27, 0.88, 0.35, 0.22),
]:
    th = math.radians(th_deg)
    p0 = shell(th * 0.88, y_start, 0.07)
    p1 = shell(th * 0.95, 0.74, 0.16)
    p2 = Vector((math.sin(th) * 0.56 + x_splay * 0.45, lift_y, -0.12 + z_tip * 0.35))
    p3 = Vector((math.sin(th) * 0.62 + x_splay, y_tip, z_tip))
    clump([p0, p1, p2, p3], width, 0.068, segs=14, tip=1.75, root=0.84, face_hint=(math.sin(th) * 0.25, 0.62, -0.74))

# Second outer halo tier of staggered flame spikes arching above & behind the crown
for th_deg, y_peak, x_reach, z_reach, width in [
    (-72, 0.86, -0.88, 0.16, 0.20),
    (-48, 1.09, -0.68, 0.29, 0.22),
    (-22, 1.24, -0.36, 0.39, 0.22),
    (2, 1.35, 0.02, 0.44, 0.24),
    (24, 1.22, 0.40, 0.39, 0.22),
    (48, 1.08, 0.70, 0.29, 0.22),
    (72, 0.85, 0.88, 0.16, 0.20),
]:
    th = math.radians(th_deg)
    p0 = Vector((math.sin(th) * 0.38, 0.80, -0.02))
    p1 = Vector((x_reach * 0.55, (0.80 + y_peak) * 0.52, z_reach * 0.45))
    p2 = Vector((x_reach * 0.86, y_peak * 0.95, z_reach * 0.82))
    p3 = Vector((x_reach, y_peak, z_reach))
    clump([p0, p1, p2, p3], width, 0.065, segs=12, tip=1.6, root=0.78, face_hint=(0.0, 0.42, -0.90))


# 4. Sides: organic upward-curling flame tufts flaring behind the ears/cheekbones + seamless
#    jaw-framing locks whose roots tuck smoothly high into the crown (no seam step).
for side in (1, -1):
    # Staggered sweeping upward-flicked mane spikes behind ears/cheeks
    for y_root, y_mid, y_tip, x_out, z_back, width in [
        (0.58, 0.62, 0.72, 1.08, 0.08, 0.19),
        (0.40, 0.42, 0.50, 1.18, 0.15, 0.20),
        (0.22, 0.19, 0.24, 1.12, 0.22, 0.19),
        (0.04, -0.02, -0.05, 1.00, 0.26, 0.18),
    ]:
        p0 = Vector((side * 0.50, y_root, 0.04 + z_back * 0.2))
        p1 = Vector((side * 0.82, y_mid, z_back * 0.6))
        p2 = Vector((side * x_out, y_tip, z_back))
        clump([p0, p1, p2], width, 0.064, segs=12, tip=1.65, root=0.80, face_hint=(0.0, 0.25, -0.95))

    # Seamless cheek/jaw locks starting high on the crown (y=0.74) so no shelf shows at temples
    for th_deg, y_end, x_in, z_fwd in [(52, -0.46, -0.07, -0.06), (68, -0.58, -0.02, 0.00), (86, -0.62, 0.04, 0.06)]:
        th = math.radians(th_deg) * side
        p0 = shell(th * 0.72, 0.74, 0.08)
        p1 = shell(th * 0.94, 0.44, 0.12)
        p2 = shell(th, 0.08, 0.13)
        p3 = shell(th, -0.24, 0.12) + Vector((side * x_in * 0.6, 0, z_fwd * 0.6))
        p4 = shell(th * 0.90, y_end, 0.08) + Vector((side * x_in, 0, z_fwd))
        clump([p0, p1, p2, p3, p4], 0.15, 0.062, segs=16, tip=2.0, twist=-0.05 * side)


# 5. Back: full layered warrior mane reaching collar/mantle cleanly.
for k, th_deg in enumerate(range(104, 257, 14)):
    th = math.radians(th_deg + rng.uniform(-2, 2))
    y_end = rng.uniform(-0.72, -0.52)
    off = 0.11 + (0.04 if k % 2 else 0.0)
    pts = [
        shell(th * 0.55 + math.pi * 0.45, 0.86, 0.05),
        shell(th, 0.55, off),
        shell(th, 0.10, off + 0.06),
        shell(th, -0.28, off + 0.12),
        shell(th + rng.uniform(-0.06, 0.06), y_end, off + rng.uniform(0.16, 0.24)),
    ]
    clump(pts, rng.uniform(0.18, 0.22), 0.068, segs=16, tip=1.95)

for k, th_deg in enumerate(range(112, 249, 18)):
    th = math.radians(th_deg + rng.uniform(-2, 2))
    y_end = rng.uniform(-0.14, 0.20)
    pts = [
        shell(th * 0.5 + math.pi * 0.5, 0.88, 0.08),
        shell(th, 0.68, 0.20),
        shell(th, 0.34, 0.28),
        shell(th + rng.uniform(-0.05, 0.05), y_end, rng.uniform(0.32, 0.40)),
    ]
    clump(pts, rng.uniform(0.18, 0.22), 0.068, segs=14, tip=1.85)


uvl = bm.loops.layers.uv.verify()
for face in bm.faces:
    for loop in face.loops:
        loop[uvl].uv = VERT_UV.get(loop.vert, (0.5, 0.96))

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me)
bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

mat = bpy.data.materials.get("RookHairRust") or bpy.data.materials.new("RookHairRust")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
col = (0.36, 0.08, 0.03, 1)
tex_path = os.path.join(OUT_DIR, "rook_hair_texture.png")
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
