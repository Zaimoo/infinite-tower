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
CX, CY, CZ = 0.0, 0.14, 0.04
RX, RY, RZ = 0.68, 0.73, 0.69

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

def dome_pt(x, z, off=0.0):
    """Point directly on the scalp dome at (x, z), pushed outward by off along dome normal."""
    r2 = (x / RX) ** 2 + ((z - CZ) / RZ) ** 2
    y = CY + RY * math.sqrt(max(0.0, 1.0 - min(0.999, r2)))
    p = Vector((CX + x, y, z))
    return p + out_normal(p) * off

bm = bmesh.new()

# --- Scalp cap: middle-parted left/right crown dome matching the ref center part -----------------
def cap():
    s_segs, r_segs = 36, 20
    uvl = bm.loops.layers.uv.verify()

    def tri_wave(x):
        f = x % 1.0
        return 1.0 - abs(2.0 * f - 1.0)

    def rim_limit(c):
        if c > 0.68:
            t_arch = (c - 0.68) / 0.32
            return 0.40 + 0.10 * t_arch
        if c > 0.25:
            t_side = (c - 0.25) / 0.43
            return -0.10 + 0.50 * t_side
        if c > -0.2:
            return -0.10
        return -0.34

    phi_front = math.asin((0.52 - CY) / RY)         # ~31.4 deg above -Z (front center forehead)
    phi_back = math.radians(120.0)                  # ~30 deg past top pole (natural crown end of middle part)
    cap_faces = []

    for side in (-1, 1):
        verts = {}
        for j in range(s_segs + 1):
            s = j / s_segs
            th = side * math.pi * s
            c = math.cos(th)
            y_rim = rim_limit(c)
            k_rim = 1.0 if y_rim <= CY else math.sqrt(max(0.0, 1.0 - ((y_rim - CY) / RY) ** 2))
            d_rim = Vector((math.sin(th) * k_rim, (y_rim - CY) / RY, -c * k_rim))

            phi_s = phi_front + s * (phi_back - phi_front)
            d_spine = Vector((0.0, math.sin(phi_s), -math.cos(phi_s)))

            # Sculpt the middle-part cleft along the spine (x=0) rising into two lush waves before tapering over temples/back
            part_env = math.sin(min(1.0, s / 0.88) * math.pi) ** 0.55

            for i in range(r_segs + 1):
                row_t = i / r_segs
                # Ease slightly denser near the center part curve so the cleft & pillow crest are silky smooth
                w_t = row_t ** 1.12
                v_mix = d_spine.lerp(d_rim, w_t)
                y = CY + RY * v_mix.y
                # Keep surface flush with head ellipsoid above CY, cylinder below CY
                k = 1.0 if y <= CY else math.sqrt(max(0.0, 1.0 - ((y - CY) / RY) ** 2))

                crown_t = max(0.0, min(1.0, (y - 0.45) / 0.34))
                off = 0.004 + 0.018 * crown_t
                if c > 0.68:
                    front_t = max(0.0, min(1.0, (y - 0.40) / 0.32))
                    edge_t = max(0.0, min(1.0, (y - y_rim) / 0.06))
                    off = 0.004 + (max(off, 0.012 + 0.010 * front_t) - 0.004) * edge_t
                elif c > 0.25:
                    off = max(off, 0.014)
                # Smooth center-part cleft & parted waves on top/front crown; taper rear cap gently under back cape
                back_recess = max(0.0, min(1.0, (s - 0.50) / 0.35))
                if c < 0.10:
                    rear_t = max(0.0, min(1.0, (y - 0.56) / 0.20))
                    off = 0.002 + 0.018 * (crown_t * rear_t)
                elif back_recess > 0.0:
                    off = off * (1.0 - 0.25 * back_recess) + 0.008 * back_recess

                # Center-part cleft dip (-0.018 at row_t=0) rising smoothly into parted waves (+0.016 in front)
                cleft = -0.018 * math.exp(-(row_t / 0.075) ** 2) * part_env * (1.0 - 0.45 * back_recess)
                pillow = 0.016 * math.exp(-((row_t - 0.22) / 0.16) ** 2) * part_env * (1.0 - 0.70 * back_recess)
                off = max(0.002, off + cleft + pillow)

                if i == 0:
                    x_dir, z_dir = 0.0, -math.cos(phi_s)
                    h_k = abs(z_dir)
                    x_pos = 0.0
                    z_pos = CZ + (RZ + off) * (-math.cos(phi_s))
                    y_pos = CY + (RY + off * 0.6) * math.sin(phi_s)
                else:
                    h_len = math.hypot(v_mix.x, v_mix.z)
                    if h_len < 1e-5:
                        x_pos = 0.0
                        z_pos = CZ
                    else:
                        x_pos = (RX + off) * k * (v_mix.x / h_len)
                        z_pos = CZ + (RZ + off) * k * (v_mix.z / h_len)
                    y_pos = y + (off * 0.6 if y > CY else 0.0)

                verts[(i, j)] = bm.verts.new(B(Vector((CX + x_pos, y_pos, z_pos))))

        for i in range(r_segs):
            for j in range(s_segs):
                q = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
                if side < 0:
                    q = list(reversed(q))
                f = bm.faces.new([verts[k] for k in q])
                cap_faces.append(f)
                for loop, (ii, jj) in zip(f.loops, q):
                    u = 0.03 + 0.19 * tri_wave((jj / s_segs) * 7.0)
                    v = 0.99 - 0.54 * (ii / r_segs)
                    loop[uvl].uv = (u, v)

    bmesh.ops.recalc_face_normals(bm, faces=cap_faces)
cap()

# --- Ribbon lock ---------------------------------------------------------------------------
# Sculpted Roblox UGC anime lock cross-section: plump rounded dome with clean underside bevel
PROFILE = [(1.0, 0.0), (0.55, 0.20), (0.0, 0.30), (-0.55, 0.20), (-1.0, 0.0), (0.0, -0.14)]
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
    prev_side = None
    for s, p in enumerate(pts):
        t = s / segs
        a = pts[max(0, s - 1)]; b = pts[min(segs, s + 1)]
        tan = (b - a).normalized()
        if prev_side is None:
            nrm = out_normal(p)
            side = tan.cross(nrm)
            if side.length < 1e-5:
                side = tan.cross(Vector((0, 0, 1)))
            if side.length < 1e-5:
                side = tan.cross(Vector((1, 0, 0)))
            side.normalize()
        else:
            # Parallel transport keeps the ribbon flat without 180-degree flips on outward-curling wings
            side = prev_side - tan * prev_side.dot(tan)
            if side.length < 1e-5:
                side = tan.cross(out_normal(p))
            side.normalize()
        prev_side = side
        nrm = side.cross(tan).normalized()
        ang = twist * t
        s_vec = side * math.cos(ang) + nrm * math.sin(ang)
        n_vec = nrm * math.cos(ang) - side * math.sin(ang)
        grow = root + (1 - root) * min(1.0, t / grow_len)
        if end_tie:
            shape = grow * (1 - 0.75 * t ** 2)  # gathers into the tie instead of a point
        else:
            shape = grow * (1 - t ** tip) * (1 + 0.15 * math.sin(math.pi * t))
        w = width * shape + 0.004
        h = thick * (0.5 + 0.5 * shape) + 0.003
        rings.append([bm.verts.new(B(p + s_vec * (sx * w) + n_vec * (ny * h))) for sx, ny in PROFILE])
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

COLOUR = (0.86, 0.88, 0.96, 1)

# ===== Unified AstreaHair: middle-parted crown blending seamlessly into UGC anime bangs, sidelocks & cape =====

# 1. Clean iconic anime curtain-bang wing per side (IN FRONT, plump sculpted UGC volume framing temples/cheeks)
for side in (-1, 1):
    # Main sleek flared curtain wing matching ref (media_1794663964630_6fda0dd4.jpg)
    pts_main = [
        dome_pt(side * 0.042, CZ - 0.24, 0.016),
        shell(side * math.radians(16), 0.60, 0.030),
        shell(side * math.radians(32), 0.36, 0.058),
        shell(side * math.radians(49), 0.14, 0.098),
        shell(side * math.radians(62), 0.02, 0.152) + Vector((side * 0.02, 0.0, -0.01)),
        shell(side * math.radians(70), 0.00, 0.205) + Vector((side * 0.06, 0.01, 0.00)),
    ]
    ribbon(pts_main, 0.20, 0.058, segs=24, tip=2.4, root=0.14, grow_len=0.26)

    # Secondary softer inner curl strictly underneath the main wing (starts well off center line so top stays smooth)
    pts_sub = [
        shell(side * math.radians(18), 0.58, -0.006),
        shell(side * math.radians(26), 0.50, 0.006),
        shell(side * math.radians(42), 0.26, 0.028),
        shell(side * math.radians(58), 0.02, 0.064),
        shell(side * math.radians(72), -0.14, 0.122) + Vector((side * 0.04, 0.00, 0.02)),
    ]
    ribbon(pts_sub, 0.17, 0.048, segs=22, tip=2.4, root=0.14, grow_len=0.26)

# 2. Plump UGC sidelocks clearly BEHIND the flared curtain wings (tucked behind cheeks down to head/neck length)
for side in (-1, 1):
    for k, (th_deg, y_end, out_z, w, sep) in enumerate([
        (68, -0.82, -0.24, 0.19, 0.000),
        (82, -0.70, -0.08, 0.20, 0.008),
    ]):
        th = side * math.radians(th_deg)
        pts = [
            shell(th * 0.88, 0.64, -0.006),
            shell(th * 0.94, 0.34, 0.018 + sep * 0.5),
            shell(th, -0.04, 0.048 + sep),
            shell(th * 1.01, -0.34, 0.068 + sep) + Vector((0.0, 0.0, out_z * 0.25)),
            shell(th * 1.02, y_end, 0.080 + sep) + Vector((-side * 0.03, 0.0, out_z * 0.45)),
        ]
        ribbon(pts, w, 0.052, segs=22, tip=2.5, root=0.14, grow_len=0.28)

# 3. Sculpted crescent ahoge strand arching off her right upper crown (rooted inside crown cap)
base = CROWN + Vector((0.04, -0.06, -0.05))
pts = [
    base,
    base + Vector((0.09, 0.21, -0.05)),
    base + Vector((0.24, 0.25, -0.12)),
    base + Vector((0.37, 0.14, -0.20)),
]
ribbon(pts, 0.062, 0.045, segs=16, tip=2.4, root=0.72)

# 4. Blended middle-part-to-cape UGC anime locks: fan smoothly out from under the rear crown dome
# and drape in lush wide sculpted curves behind the shoulders with zero crossing wedges or inner poke-through.
for layer, specs in enumerate([
    # Inner darker shadow layer (6 fuller chunks strictly beneath outer layer, emerging only near tips)
    [(th_d, -1.78 - 0.18 * math.sin(idx * 1.7), 0.055, 0.25) for idx, th_d in enumerate([114, 138, 164, 192, 218, 246])],
    # Outer sculpted bright silver UGC cape (8 wide rounded locks seamlessly overlapping from crown cap down)
    [(th_d, -1.58 - 0.38 * (math.sin(((idx + 0.5) / 8) * math.pi) ** 0.75) - 0.06 * (idx % 2), 0.100, 0.28)
     for idx, th_d in enumerate([94, 116, 139, 164, 190, 215, 239, 264])],
]):
    is_inner = (layer == 0)
    count = len(specs)
    for i, (th_deg, y_end, off, width) in enumerate(specs):
        u_span = i / max(1, count - 1)
        th = math.radians(th_deg)
        pts = hang(th, y_end, off, steps=11, flare_rate=0.14, flare_max=0.38)
        if is_inner:
            full = [off + (0.0 if q.y > 0.0 else min(0.36, -q.y * 0.11)) for q in pts]
            body = [shell(th, q.y, -0.002 + (f + 0.002) * min(1.0, max(0.0, (0.35 - q.y) / 0.80))) for q, f in zip(pts, full) if q.y < 0.30]
            pts = [shell(th, 0.54, -0.012), shell(th, 0.38, -0.002)] + body
            root_w, grow_l, thick = 0.35, 0.24, 0.052
        else:
            low = 0.026
            full = [off + (0.0 if q.y > 0.0 else min(0.38, -q.y * 0.12)) for q in pts]
            body = [shell(th, q.y, low + (f - low) * min(1.0, max(0.0, (0.42 - q.y) / 0.56))) for q, f in zip(pts, full) if q.y < 0.36]
            pts = [shell(th, 0.72, -0.006), shell(th, 0.58, 0.016), shell(th, 0.44, 0.024)] + body
            root_w, grow_l, thick = 0.24, 0.28, 0.062
        # Smooth graceful left-sweeping wind flow + lush anime S-curve tips
        sweep_x = -0.22 - 0.42 * (u_span ** 0.90)
        new_pts = [pts[0]]
        n_p = len(pts)
        for j, q in enumerate(pts[1:], 1):
            t = j / (n_p - 1)
            if q.y < 0.0:
                s_curve = 0.032 * math.sin(1.25 * math.pi * t + u_span * 1.4)
                q = q + Vector((sweep_x * (t ** 1.45) + s_curve, 0.0, 0.055 * t))
            new_pts.append(q)
        ribbon(new_pts, width, thick, segs=22, tip=2.8, root=root_w, inner=is_inner, grow_len=grow_l)

head_part = finish(NAME, COLOUR)
