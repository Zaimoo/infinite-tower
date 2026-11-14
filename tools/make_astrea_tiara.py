"""
Astrea's Astral Silver & 5-Crystal Tiara (run inside Blender headless or GUI).

Generates two precision-fitted meshes in Roblox 1.2-stud head space matching her
reference art (media_1794663964630_6fda0dd4.jpg):
  - AstreaTiaraFrame    : Ornate sculpted silver filigree crown arch, scrolling wing
                          volutes, center diamond bezel, and 5 pronged crystal collets
                          (exported for Material = Metal, silver).
  - AstreaTiaraCrystals : 5 radiant emerald/quartz-cut 6-sided crystal spires + front
                          bezel diamond gem with crisp flat facets and crystal UVs
                          (exported for astrea_tiara_crystals_texture.png).

Exports:
  - assets/tiara/astrea_tiara.fbx          (contains both objects for 1-click Import 3D)
  - assets/tiara/astrea_tiara.blend
  - assets/tiara/astrea_tiara_frame.json   (centre/size in Roblox head space)
  - assets/tiara/astrea_tiara_crystals.json
"""

import json
import math
import os
import bpy
import bmesh
from mathutils import Matrix, Vector

REPO = r"d:\Programming shi\infinite-tower"
OUT_DIR = os.path.join(REPO, "assets", "tiara")
os.makedirs(OUT_DIR, exist_ok=True)

FRAME_NAME = "AstreaTiaraFrame"
CRYSTAL_NAME = "AstreaTiaraCrystals"

for ob in list(bpy.data.objects):
    if ob.name in (FRAME_NAME, CRYSTAL_NAME):
        bpy.data.objects.remove(ob, do_unlink=True)


def B(p):
    """Convert Roblox head space (x right, y up, z back/-front) -> Blender space."""
    return Vector((p.x, -p.z, p.y))


# Match AstreaHair's exact scalp dome parameters so the tiara seats flush with zero gap
CX, CY, CZ = 0.0, 0.14, 0.04
RX, RY, RZ = 0.695, 0.745, 0.705


def hair_surface(x, z, extra=0.0):
    """Point hugging the upper-front crown surface of AstreaHair in Roblox space."""
    r2 = (x / RX) ** 2 + ((z - CZ) / RZ) ** 2
    y = CY + RY * math.sqrt(max(0.0, 1.0 - min(0.985, r2)))
    pillow = 0.015 * math.exp(-((abs(x) - 0.14) / 0.13) ** 2)
    return Vector((x, y + pillow + extra, z))


def surface_normal(p):
    n = Vector(((p.x - CX) / (RX * RX), (p.y - CY) / (RY * RY), (p.z - CZ) / (RZ * RZ)))
    return n.normalized() if n.length > 1e-6 else Vector((0.0, 1.0, 0.0))


def crown_pt(u, lift=0.0, fwd=0.0, extra_r=0.0):
    """Curvilinear crown coordinate across upper crown arc u in [-1, 1].
    Spans cleanly across top/temples (+/-58 deg) and tucks ends softly into hair surface.
    """
    th = u * math.radians(58.0)
    x = 0.64 * math.sin(th)
    z = CZ - 0.385 * math.cos(th) + 0.045 * (u * u) - fwd * math.cos(th * 0.5)
    # Tuck outer temple ends snugly into the hair surface so tips never float
    tuck = -0.026 * (max(0.0, abs(u) - 0.65) / 0.35) ** 1.6
    base = hair_surface(x, z, extra=0.010 + extra_r + tuck)
    up_dir = Vector((0.15 * math.sin(th), 0.96, -0.22 * math.cos(th * 0.7))).normalized()
    n_dir = surface_normal(base)
    return base + up_dir * lift + n_dir * fwd


def eval_catmull(pts, n_samples):
    P = [Vector(p) for p in pts]
    if len(P) < 2:
        return P
    P = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    out = []
    seg = len(P) - 3
    for s in range(n_samples + 1):
        t_all = (s / n_samples) * seg
        i = min(int(t_all), seg - 1)
        t = t_all - i
        p0, p1, p2, p3 = P[i], P[i + 1], P[i + 2], P[i + 3]
        out.append(
            0.5 * (
                (2 * p1)
                + (-p0 + p2) * t
                + (2 * p0 - 5 * p1 + 4 * p2 - p3) * (t * t)
                + (-p0 + 3 * p1 - 3 * p2 + p3) * (t * t * t)
            )
        )
    return out


# Sleek diamond-beveled metalwork cross-section (sharp edges catch silver rim light)
SILVER_PROF = [
    (1.0, 0.0),
    (0.50, 0.74),
    (0.0, 1.0),
    (-0.50, 0.74),
    (-1.0, 0.0),
    (-0.50, -0.74),
    (0.0, -1.0),
    (0.50, -0.74),
]


def sweep_tube(bm, ctrl, radii_fn, segs=28, profile=SILVER_PROF, cap_ends=True, flat_up=None):
    """Sweep a beveled metallic profile along smoothed Roblox-space control points."""
    pts = eval_catmull(ctrl, segs)
    rings = []
    prev_side = None
    for s, p in enumerate(pts):
        t = s / segs
        a = pts[max(0, s - 1)]
        b = pts[min(segs, s + 1)]
        tan = (b - a)
        if tan.length < 1e-6:
            tan = Vector((1.0, 0.0, 0.0))
        tan.normalize()
        up_ref = flat_up if flat_up is not None else surface_normal(p)
        if prev_side is None:
            side = tan.cross(up_ref)
            if side.length < 1e-5:
                side = tan.cross(Vector((0.0, 1.0, 0.0)))
            if side.length < 1e-5:
                side = tan.cross(Vector((0.0, 0.0, 1.0)))
            side.normalize()
        else:
            side = prev_side - tan * prev_side.dot(tan)
            if side.length < 1e-5:
                side = tan.cross(up_ref)
            side.normalize()
        prev_side = side
        nrm = side.cross(tan).normalized()
        rx, ry = radii_fn(t)
        ring = [bm.verts.new(B(p + side * (px * rx) + nrm * (py * ry))) for px, py in profile]
        rings.append(ring)

    n = len(profile)
    faces = []
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(n):
            faces.append(bm.faces.new([r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]]))
    if cap_ends:
        faces.append(bm.faces.new(list(reversed(rings[0]))))
        faces.append(bm.faces.new(rings[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    return faces


def add_beveled_sphere(bm, center_r, rx, ry, rz, u_segs=10, v_segs=6):
    mat = Matrix.Translation(B(center_r)) @ Matrix.Diagonal((rx, rz, ry, 1.0))
    bmesh.ops.create_uvsphere(bm, u_segments=u_segs, v_segments=v_segs, radius=1.0, matrix=mat)


def make_bezel_diamond(bm, center_r, half_w, half_h, depth):
    """Build a crisp hollow diamond bezel frame in Roblox space facing slightly up/front."""
    fwd = Vector((0.0, 0.22, -0.975)).normalized()
    right = Vector((1.0, 0.0, 0.0))
    up = right.cross(fwd).normalized()

    corners = [
        (0.0, half_h),
        (half_w, 0.0),
        (0.0, -half_h),
        (-half_w, 0.0),
    ]
    loops = []
    for scale, z_off in [(1.0, depth * 0.42), (0.64, depth * 0.65), (0.64, -depth * 0.48), (1.0, -depth * 0.42)]:
        ring = []
        for cx, cy in corners:
            p = center_r + right * (cx * scale) + up * (cy * scale) + fwd * z_off
            ring.append(bm.verts.new(B(p)))
        loops.append(ring)

    faces = []
    for li in range(4):
        l0 = loops[li]
        l1 = loops[(li + 1) % 4]
        for k in range(4):
            faces.append(bm.faces.new([l0[k], l0[(k + 1) % 4], l1[(k + 1) % 4], l1[k]]))
    bmesh.ops.recalc_face_normals(bm, faces=faces)

    for cx, cy in corners:
        p0 = center_r + right * (cx * 0.96) + up * (cy * 0.96) + fwd * (-depth * 0.05)
        p1 = center_r + right * (cx * 0.78) + up * (cy * 0.78) + fwd * (depth * 0.85)
        p2 = center_r + right * (cx * 0.58) + up * (cy * 0.58) + fwd * (depth * 0.96)
        sweep_tube(
            bm, [p0, p1, p2],
            lambda t: (0.0075 * (1.0 - 0.65 * t), 0.0075 * (1.0 - 0.65 * t)),
            segs=5, flat_up=fwd,
        )


def add_faceted_gem(bm, uvl, center_r, half_w, half_h, front_z, back_z):
    """Build a kite/diamond-cut jewel with 8 crisp crown facets + table face + UVs."""
    fwd = Vector((0.0, 0.22, -0.975)).normalized()
    right = Vector((1.0, 0.0, 0.0))
    up = right.cross(fwd).normalized()

    def P(rx, ry, rz):
        return bm.verts.new(B(center_r + right * rx + up * ry + fwd * rz))

    girdle = [
        P(0.0, half_h, 0.0),
        P(half_w, 0.0, 0.0),
        P(0.0, -half_h, 0.0),
        P(-half_w, 0.0, 0.0),
    ]
    table = [
        P(0.0, half_h * 0.48, front_z),
        P(half_w * 0.48, 0.0, front_z),
        P(0.0, -half_h * 0.48, front_z),
        P(-half_w * 0.48, 0.0, front_z),
    ]
    culet = P(0.0, 0.0, -back_z)

    faces = []
    f_tab = bm.faces.new(table)
    faces.append(f_tab)
    for lp in f_tab.loops:
        lp[uvl].uv = (0.5, 0.92)
    for k in range(4):
        f_cr = bm.faces.new([girdle[k], girdle[(k + 1) % 4], table[(k + 1) % 4], table[k]])
        faces.append(f_cr)
        for idx, lp in enumerate(f_cr.loops):
            lp[uvl].uv = ((k + (1 if idx in (1, 2) else 0)) / 4.0, 0.78 if idx >= 2 else 0.48)
        f_pv = bm.faces.new([girdle[(k + 1) % 4], girdle[k], culet])
        faces.append(f_pv)
        for lp in f_pv.loops:
            lp[uvl].uv = (0.5, 0.18)
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def add_crystal_spire(bm_crys, uvl, bm_frame, base_r, axis_dir, length, radius, side_vec):
    """Build a sculpted 6-sided emerald/quartz crystal spire + 6-claw silver collet socket."""
    axis = axis_dir.normalized()
    s1 = side_vec - axis * side_vec.dot(axis)
    s1.normalize()
    s2 = axis.cross(s1).normalized()

    profile_levels = [
        (0.00, 0.76),
        (0.24, 0.90),
        (0.60, 1.08),
        (0.69, 0.96),
        (0.87, 0.45),
    ]
    n_sides = 6
    rings = []
    for t_h, r_mul in profile_levels:
        ring = []
        c = base_r + axis * (length * t_h)
        for k in range(n_sides):
            ang = k * (2.0 * math.pi / n_sides) + math.pi / 6.0
            rx = radius * r_mul
            rz = radius * 0.74 * r_mul
            pt = c + s1 * (rx * math.cos(ang)) + s2 * (rz * math.sin(ang))
            ring.append(bm_crys.verts.new(B(pt)))
        rings.append(ring)

    tip = bm_crys.verts.new(B(base_r + axis * length))
    bot = bm_crys.verts.new(B(base_r - axis * (length * 0.04)))

    faces = []
    for ri in range(len(rings) - 1):
        r0, r1 = rings[ri], rings[ri + 1]
        v0 = profile_levels[ri][0]
        v1 = profile_levels[ri + 1][0]
        for k in range(n_sides):
            f = bm_crys.faces.new([r0[k], r0[(k + 1) % n_sides], r1[(k + 1) % n_sides], r1[k]])
            faces.append(f)
            u0, u1 = k / n_sides, (k + 1) / n_sides
            for lp, uv in zip(f.loops, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]):
                lp[uvl].uv = uv

    r_top = rings[-1]
    v_top = profile_levels[-1][0]
    for k in range(n_sides):
        f = bm_crys.faces.new([r_top[k], r_top[(k + 1) % n_sides], tip])
        faces.append(f)
        u0, u1 = k / n_sides, (k + 1) / n_sides
        for lp, uv in zip(f.loops, [(u0, v_top), (u1, v_top), (0.5 * (u0 + u1), 0.99)]):
            lp[uvl].uv = uv

    r_bot = rings[0]
    for k in range(n_sides):
        f = bm_crys.faces.new([r_bot[(k + 1) % n_sides], r_bot[k], bot])
        faces.append(f)
        for lp in f.loops:
            lp[uvl].uv = (0.5, 0.02)

    bmesh.ops.recalc_face_normals(bm_crys, faces=faces)

    # Sculpted silver octagonal collet collar gripping the crystal base cleanly
    col_pts = []
    for k in range(n_sides + 1):
        ang = (k % n_sides) * (2.0 * math.pi / n_sides) + math.pi / 6.0
        col_pts.append(
            base_r
            + axis * (length * 0.05)
            + s1 * (radius * 0.95 * math.cos(ang))
            + s2 * (radius * 0.74 * math.sin(ang))
        )
    sweep_tube(
        bm_frame,
        col_pts,
        lambda t: (0.013, 0.016),
        segs=18,
        cap_ends=False,
        flat_up=axis,
    )

    # Tapered Gothic silver claw prongs hugging up the crystal ridges (~30% height)
    for k in range(n_sides):
        ang = k * (2.0 * math.pi / n_sides) + math.pi / 6.0
        rad_dir = s1 * math.cos(ang) + s2 * (0.76 * math.sin(ang))
        p_root = base_r - axis * 0.015 + rad_dir * (radius * 0.87)
        p_mid = base_r + axis * (length * 0.16) + rad_dir * (radius * 0.92)
        p_tip = base_r + axis * (length * 0.30) + rad_dir * (radius * 0.85)
        sweep_tube(
            bm_frame,
            [p_root, p_mid, p_tip],
            lambda t: (0.0085 * (1.0 - 0.70 * t), 0.0085 * (1.0 - 0.70 * t)),
            segs=6,
            flat_up=rad_dir.normalized(),
        )


# ==============================================================================
# 1. BUILD ORNATE SILVER FILIGREE TIARA FRAME
# ==============================================================================
bm_frame = bmesh.new()

# Lower base contour band sweeping across upper crown parting, tapering gently into temple hair
low_ctrl = []
for i in range(25):
    u = -1.0 + 2.0 * (i / 24.0)
    center_dip = -0.022 * math.exp(-(u / 0.14) ** 2)
    arch = 0.012 * math.sin(math.pi * (1.0 - abs(u)))
    low_ctrl.append(crown_pt(u, lift=0.004 + center_dip + arch, fwd=0.014))

sweep_tube(
    bm_frame,
    low_ctrl,
    lambda t: (
        0.010 + 0.008 * math.sin(math.pi * t),
        0.014 + 0.012 * math.sin(math.pi * t) ** 1.15,
    ),
    segs=48,
)

# Upper sculpted crest arch: rises into twin winged peaks beside center bezel without blocking center spire
up_ctrl = []
for i in range(29):
    u = -0.90 + 1.80 * (i / 28.0)
    au = abs(u)
    # Graceful royal crescent arch peaking cleanly at center-shoulders & cradling the 5 crystal bases
    center_arch = 0.105 * math.exp(-(au / 0.19) ** 1.45)
    inner_wave = 0.056 * math.exp(-((au - 0.36) / 0.13) ** 2)
    outer_wave = 0.026 * math.exp(-((au - 0.64) / 0.14) ** 2)
    taper = max(0.0, 1.0 - (au / 0.90) ** 2.1)
    lift = 0.006 + (center_arch + inner_wave + outer_wave + 0.018 * taper)
    fwd = 0.022 * taper + 0.010
    up_ctrl.append(crown_pt(u, lift=lift, fwd=fwd))

sweep_tube(
    bm_frame,
    up_ctrl,
    lambda t: (
        0.0085 + 0.0065 * math.sin(math.pi * t),
        0.011 + 0.010 * math.sin(math.pi * t),
    ),
    segs=52,
)

# Symmetrical filigree wings & scrolls matching Astrea's tiara silhouette
for side in (-1.0, 1.0):
    # Inner swept S-wing rising around center spire base and curling gracefully into inner shoulder
    s_wing = [
        crown_pt(side * 0.06, lift=0.088, fwd=0.022),
        crown_pt(side * 0.18, lift=0.056, fwd=0.019),
        crown_pt(side * 0.31, lift=0.098, fwd=0.019),
        crown_pt(side * 0.40, lift=0.118, fwd=0.012),
        crown_pt(side * 0.34, lift=0.130, fwd=0.008),
    ]
    sweep_tube(
        bm_frame,
        s_wing,
        lambda t: (0.011 * (1.0 - 0.42 * t), 0.013 * (1.0 - 0.38 * t)),
        segs=20,
    )

    # Outer swept filigree wing hugging the crown arch contour gracefully
    outer_wing = [
        crown_pt(side * 0.42, lift=0.032, fwd=0.014),
        crown_pt(side * 0.58, lift=0.072, fwd=0.008),
        crown_pt(side * 0.74, lift=0.088, fwd=0.000),
        crown_pt(side * 0.82, lift=0.068, fwd=-0.005),
        crown_pt(side * 0.73, lift=0.052, fwd=0.000),
    ]
    sweep_tube(
        bm_frame,
        outer_wing,
        lambda t: (0.0105 * (1.0 - 0.44 * t), 0.012 * (1.0 - 0.42 * t)),
        segs=20,
    )

    # Compact temple scroll loop closing cleanly into the hair dome
    temple_curl = [
        crown_pt(side * 0.66, lift=0.016, fwd=0.008),
        crown_pt(side * 0.82, lift=0.032, fwd=0.002),
        crown_pt(side * 0.94, lift=0.016, fwd=-0.008),
    ]
    sweep_tube(
        bm_frame,
        temple_curl,
        lambda t: (0.009 * (1.0 - 0.45 * t), 0.0105 * (1.0 - 0.45 * t)),
        segs=12,
    )

    # Pierced lancet ribs linking upper arch and lower contour band cleanly
    for u_s, top_l in [(0.14, 0.088), (0.30, 0.078), (0.50, 0.054), (0.68, 0.038)]:
        p_bot = crown_pt(side * u_s, lift=0.008, fwd=0.014)
        p_top = crown_pt(side * u_s, lift=top_l, fwd=0.017)
        sweep_tube(
            bm_frame,
            [p_bot, p_bot.lerp(p_top, 0.5) + Vector((0.0, 0.0, -0.004)), p_top],
            lambda t: (0.008, 0.010),
            segs=8,
        )

    # Subtle metallic pearls at peak tips & flanking diamond shoulders
    for u_b, l_b, r_b in [(0.11, 0.056, 0.013), (0.40, 0.118, 0.014), (0.74, 0.088, 0.013)]:
        add_beveled_sphere(bm_frame, crown_pt(side * u_b, lift=l_b, fwd=0.014), r_b, r_b, r_b)

# Central front diamond bezel right below the center spire notch
bezel_center = crown_pt(0.0, lift=0.048, fwd=0.038)
make_bezel_diamond(bm_frame, bezel_center, half_w=0.048, half_h=0.068, depth=0.024)


# ==============================================================================
# 2. BUILD 5 RADIANT FACETED CYAN CRYSTALS + FRONT BEZEL GEM
# ==============================================================================
bm_crys = bmesh.new()
uv_crys = bm_crys.loops.layers.uv.verify()

# Front center diamond jewel nested snugly inside the silver bezel
add_faceted_gem(bm_crys, uv_crys, bezel_center, half_w=0.035, half_h=0.052, front_z=0.021, back_z=0.012)

# 5 radiant astral crystal spires anchored directly into the tiara crown arch
CRYSTAL_SPECS = [
    # (u, lift_base, fwd_base, length, radius, splay_deg, pitch_fwd_deg)
    (0.00, 0.098, -0.002, 0.445, 0.066, 0.0, 10.0),    # Tall central astral spire
    (-0.21, 0.072, -0.004, 0.305, 0.048, -14.0, 11.0), # Inner left spire
    (0.21, 0.072, -0.004, 0.305, 0.048, 14.0, 11.0),   # Inner right spire
    (-0.42, 0.046, -0.006, 0.215, 0.039, -26.5, 12.0), # Outer left spire
    (0.42, 0.046, -0.006, 0.215, 0.039, 26.5, 12.0),   # Outer right spire
]

for u_c, lift_c, fwd_c, length, rad, splay_deg, pitch_deg in CRYSTAL_SPECS:
    base_pos = crown_pt(u_c, lift=lift_c, fwd=fwd_c)
    s_rad = math.radians(splay_deg)
    p_rad = math.radians(pitch_deg)
    axis_dir = Vector((
        math.sin(s_rad),
        math.cos(s_rad) * math.cos(p_rad),
        -math.cos(s_rad) * math.sin(p_rad),
    )).normalized()
    side_vec = Vector((math.cos(s_rad), -math.sin(s_rad), 0.0)).normalized()
    add_crystal_spire(bm_crys, uv_crys, bm_frame, base_pos, axis_dir, length, rad, side_vec)

# Subtle tucked silver support struts connecting each crystal collet down into the lower crown rail
for u_c, lift_c, fwd_c, *_ in CRYSTAL_SPECS:
    p_col = crown_pt(u_c, lift=lift_c + 0.01, fwd=fwd_c)
    p_rail = crown_pt(u_c, lift=0.012, fwd=0.012)
    sweep_tube(bm_frame, [p_rail, p_col], lambda t: (0.011, 0.013), segs=6)


# ==============================================================================
# 3. CREATE BLENDER OBJECTS, MATERIALS, EXPORT FBX + JSON + BLEND
# ==============================================================================
def build_obj(bm, name, smooth, mat):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(mat)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print(f"{name}: verts={len(me.vertices)} tris={tris}")
    return ob


silver_mat = bpy.data.materials.get("AstreaTiaraSilver") or bpy.data.materials.new("AstreaTiaraSilver")
silver_mat.use_nodes = True
s_bsdf = next((n for n in silver_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
if s_bsdf:
    s_bsdf.inputs["Base Color"].default_value = (0.93, 0.95, 1.0, 1.0)
    s_bsdf.inputs["Metallic"].default_value = 0.94
    s_bsdf.inputs["Roughness"].default_value = 0.16

crys_mat = bpy.data.materials.get("AstreaTiaraCrystal") or bpy.data.materials.new("AstreaTiaraCrystal")
crys_mat.use_nodes = True
nt = crys_mat.node_tree
c_bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
tex_path = os.path.join(OUT_DIR, "astrea_tiara_crystals_texture.png")
if c_bsdf:
    c_bsdf.inputs["Roughness"].default_value = 0.08
    if "Specular IOR Level" in c_bsdf.inputs:
        c_bsdf.inputs["Specular IOR Level"].default_value = 0.9
    if "Emission Strength" in c_bsdf.inputs:
        c_bsdf.inputs["Emission Strength"].default_value = 0.45
    if os.path.exists(tex_path):
        tex_node = nt.nodes.new("ShaderNodeTexImage")
        tex_node.image = bpy.data.images.load(tex_path, check_existing=True)
        nt.links.new(tex_node.outputs["Color"], c_bsdf.inputs["Base Color"])
        if "Emission Color" in c_bsdf.inputs:
            nt.links.new(tex_node.outputs["Color"], c_bsdf.inputs["Emission Color"])

frame_ob = build_obj(bm_frame, FRAME_NAME, smooth=True, mat=silver_mat)
crys_ob = build_obj(bm_crys, CRYSTAL_NAME, smooth=False, mat=crys_mat)

bpy.ops.object.select_all(action="DESELECT")
frame_ob.select_set(True)
crys_ob.select_set(True)
bpy.context.view_layer.objects.active = frame_ob

fbx_path = os.path.join(OUT_DIR, "astrea_tiara.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx_path,
    use_selection=True,
    object_types={"MESH"},
    axis_forward="-Z",
    axis_up="Y",
    apply_unit_scale=True,
    bake_space_transform=True,
)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "astrea_tiara.blend"), copy=True)

for ob, json_stem in ((frame_ob, "astrea_tiara_frame"), (crys_ob, "astrea_tiara_crystals")):
    me = ob.data
    verts = [[round(v.co.x, 4), round(v.co.z, 4), round(-v.co.y, 4)] for v in me.vertices]
    me.calc_loop_triangles()
    with open(os.path.join(OUT_DIR, f"{json_stem}.json"), "w") as f:
        json.dump({"verts": verts, "tris": [list(t.vertices) for t in me.loop_triangles]}, f, separators=(",", ":"))
    centre = [round((min(v[i] for v in verts) + max(v[i] for v in verts)) / 2, 4) for i in range(3)]
    size = [round(max(v[i] for v in verts) - min(v[i] for v in verts), 3) for i in range(3)]
    print(f"ROBLOX_BOUNDS {ob.name}: centre={centre} size={size}")
