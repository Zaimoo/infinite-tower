"""
Diran's hair, UGC-accessory style (run inside Blender: exec(open(path).read())).

From his reference art: silver-grey hair swept back off the forehead from a centre part into a
high ponytail at the crown-back, long centre-parted curtain bangs framing both sides of the face
down past the cheeks with a delicate forehead strand dipping between the brows, side locks over
the ears to the jaw, and a thick ponytail arcing up and cascading toward his left shoulder with
flared, layered tips.

Same construction as tools/make_jenna_hair_ugc.py and tools/make_eolka_hair_ugc.py: thin ribbon
locks with a raised centre ridge and needle tips over a full scalp cap, built in Roblox head
space on a 1.2-stud reference head. Exports FBX + JSON to assets/hair (see
docs/hero-art-pipeline.md 4.4).
"""

import bpy, bmesh, math, random, os, json
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "DiranHair"
rng = random.Random(31)

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

def ribbon(ctrl, width, thick=0.035, segs=16, tip=2.2, root=0.55, end_tie=False, twist=0.0, nrm_fn=None):
    pts = smooth_path(ctrl, segs)
    rings = []
    for s, p in enumerate(pts):
        t = s / segs
        a = pts[max(0, s - 1)]; b = pts[min(segs, s + 1)]
        tan = (b - a).normalized()
        nrm = nrm_fn(p, t) if nrm_fn else out_normal(p)
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


TIE = shell(math.pi, 0.74, 0.06) + Vector((0, 0.06, 0))  # high ponytail tie, crown-back
PART = shell(0.0, 0.62, 0.05)  # centre part above the forehead

def toward_tie(th, y, off, n=5):
    """Path from a hairline point over the scalp into the tie."""
    pts = []
    for s in range(n):
        t = s / (n - 1)
        th_t = th + (math.pi * (1 if th >= 0 else -1) - th) * t ** 1.3 if abs(th) > 1e-6 else 0
        y_t = y + (TIE.y - 0.05 - y) * t ** 0.8
        p = shell(th_t, y_t, off + 0.03 * math.sin(math.pi * t))
        pts.append(p)
    pts[-1] = TIE + Vector((0, -0.04, -0.03))
    return pts

# 1. Swept-back canopy: hairline all round, combed over the scalp into the tie (Eolka pattern).
hairline = []
for i in range(11):  # forehead (behind the bangs)
    hairline.append((math.radians(-68 + i * 13.6), 0.34))
for side in (-1, 1):
    for d in (78, 94, 110, 126):  # above the ears, temples to behind
        hairline.append((math.radians(d) * side, 0.12))
    for d in (142, 158, 172):  # back of the head down to the nape
        hairline.append((math.radians(d) * side, -0.4))
for k, (th, y) in enumerate(hairline):
    off = 0.022 + 0.015 * (k % 2)
    ribbon([jitter(p, 0.008) for p in toward_tie(th, y, off)], 0.18, 0.035, segs=18, root=1.0, end_tie=True, twist=rng.uniform(-0.12, 0.12))

# 2. Curtain bangs from the centre part, framing both sides of the face down past the jaw (like the
# reference art), plus a delicate central strand dipping between the brows.
for side in (-1, 1):
    # (th_top_deg, th_mid_deg, th_end_deg, y_end, width, off0)
    for k, (d_top, d_mid, d_end, y_end, w, off0) in enumerate([
        (16, 30, 32, -0.64, 0.16, 0.065),
        (24, 42, 44, -0.76, 0.18, 0.080),
        (34, 54, 56, -0.58, 0.17, 0.090),
    ]):
        th_top = math.radians(d_top) * side
        th_mid = math.radians(d_mid) * side
        th_end = math.radians(d_end) * side
        path = [
            PART + Vector((side * 0.025 * k, 0.02, 0)),
            shell(th_top, 0.56, off0),
            shell(th_mid * 0.85, 0.28, off0 + 0.01),
            shell(th_mid, -0.02, off0 + 0.015),
            shell(th_end, -0.34, off0 + 0.025),
            shell(th_end * 0.96, y_end, off0 + 0.04),
        ]
        ribbon([jitter(p, 0.006) for p in path], w, 0.036, segs=22, tip=2.4, twist=0.12 * side)

# Central forehead strand dipping between the brows from the centre part
center_strand = [
    PART + Vector((0, 0.02, 0)),
    shell(math.radians(-4), 0.56, 0.075),
    shell(math.radians(-6), 0.34, 0.09),
    shell(math.radians(-3), 0.12, 0.09),
    shell(math.radians(0), -0.04, 0.08),
]
ribbon(center_strand, 0.105, 0.030, segs=14, tip=2.4, twist=-0.06)

# 3. Side locks over the ears down to the jaw, tips curling slightly forward.
for side in (-1, 1):
    for d, y_end, off in [(78, -0.52, 0.055), (94, -0.46, 0.065), (66, -0.44, 0.08)]:
        th = math.radians(d) * side
        path = [
            shell(th, 0.54, off),
            shell(th, 0.15, off),
            shell(th, -0.20, off + 0.018),
            shell(th - math.radians(8) * side, y_end, off + 0.025),
        ]
        ribbon([jitter(p, 0.008) for p in path], 0.17, 0.034, segs=16, tip=2.2, twist=rng.uniform(-0.15, 0.15))

# 4. High ponytail: rises from the tie, arcs gracefully back and to his left (-X so it sweeps over
# his left shoulder in front silhouette like the reference art), with layered S-curve tips.
for k in range(15):
    a = 2 * math.pi * k / 15
    o = Vector((math.cos(a), 0, math.sin(a)))
    sway = rng.uniform(-0.06, 0.06)
    length = rng.uniform(0.0, 0.26)
    layer = k % 3

    spine = [
        TIE + Vector((0.0, 0.02, 0.0)),
        TIE + Vector((-0.14, 0.22, 0.08)),
        TIE + Vector((-0.42, 0.16, 0.28)),
        TIE + Vector((-0.72, -0.22, 0.40)),
        TIE + Vector((-0.94, -0.78 - length * 0.5, 0.38)),
        TIE + Vector((-1.12 - 0.08 * layer, -1.24 - length + 0.06 * layer, 0.30)),
    ]
    radii = [
        (0.07, 0.05),
        (0.12, 0.08),
        (0.17, 0.10),
        (0.18, 0.10),
        (0.15, 0.08),
        (0.10, 0.06),
    ]
    path = []
    for idx, (sp, (rx, rz)) in enumerate(zip(spine, radii)):
        w_factor = 0.0 if idx < 2 else sway * (idx - 1) * 0.45
        path.append(sp + Vector((o.x * rx + w_factor, 0.02 * layer if idx in (1, 2) else 0.0, o.z * rz)))

    out_dir = Vector((o.x, 0.25, o.z + 0.35)).normalized()
    ribbon(path, 0.15, 0.038, segs=24, tip=2.2, root=0.82, twist=rng.uniform(-0.25, 0.25), nrm_fn=lambda p, t, d=out_dir: d)

# Wrapped hair tie band around the ponytail base
for r_idx in range(2):
    r_pts = []
    for s in range(17):
        ang = 2 * math.pi * s / 16
        r_pts.append(TIE + Vector((0.10 * math.cos(ang), -0.02 + 0.028 * r_idx, 0.09 * math.sin(ang))))
    ribbon(r_pts, 0.048, 0.026, segs=16, tip=6.0, root=0.95)

bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new(NAME)
bm.to_mesh(me); bm.free()
for p in me.polygons:
    p.use_smooth = True
hair = bpy.data.objects.new(NAME, me)
bpy.context.collection.objects.link(hair)

COLOUR = (0.75, 0.79, 0.84, 1)
mat = bpy.data.materials.get("DiranHairSilver") or bpy.data.materials.new("DiranHairSilver")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
if bsdf:
    bsdf.inputs[0].default_value = COLOUR
    bsdf.inputs["Roughness"].default_value = 0.38
mat.diffuse_color = COLOUR
me.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in me.polygons)
print("DiranHair tris", tris, "tie", tuple(round(c, 4) for c in TIE))

HAIR = NAME
exec(open(r"D:\Programming shi\infinite-tower\.agents\skills\hero-remodel\scripts\blender_export_hair.py", encoding="utf-8").read())

# Render 4 angles for inspection
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in scene.render.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.film_transparent = False
if not scene.world:
    scene.world = bpy.data.worlds.new("World")
scene.world.use_nodes = True
bg = scene.world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.18, 0.20, 0.24, 1.0)

for ob in list(bpy.data.objects):
    if ob.type in ("CAMERA", "LIGHT"):
        bpy.data.objects.remove(ob, do_unlink=True)

cam_data = bpy.data.cameras.new("RenderCam")
cam_data.lens = 65
cam = bpy.data.objects.new("RenderCam", cam_data)
bpy.context.collection.objects.link(cam)
scene.camera = cam

key_data = bpy.data.lights.new("KeyLight", type="SUN")
key_data.energy = 3.2
key = bpy.data.objects.new("KeyLight", key_data)
key.rotation_euler = (math.radians(48), math.radians(15), math.radians(-30))
bpy.context.collection.objects.link(key)

fill_data = bpy.data.lights.new("FillLight", type="SUN")
fill_data.energy = 1.4
fill = bpy.data.objects.new("FillLight", fill_data)
fill.rotation_euler = (math.radians(65), math.radians(-20), math.radians(145))
bpy.context.collection.objects.link(fill)

ref = bpy.data.objects.get("RefHead")
if ref:
    ref.hide_set(False)
    ref.hide_render = False
target = Vector((0.0, 0.0, 0.08))
views = [
    ("front", Vector((0.0, 1.0, 0.12))),
    ("three_quarter", Vector((0.8, 0.6, 0.2))),
    ("side", Vector((1.0, -0.1, 0.1))),
    ("back", Vector((0.0, -1.0, 0.25))),
]

for tag, vdir in views:
    pos = target + vdir.normalized() * 4.4
    cam.location = pos
    direction = (target - pos).normalized()
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = direction.to_track_quat("-Z", "Y")
    scene.render.filepath = os.path.join(OUT_DIR, f"_diran_{tag}.png")
    bpy.ops.render.render(write_still=True)
