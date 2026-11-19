import bpy
import bmesh
import json
import math
import os
from mathutils import Vector, geometry

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
FBX_OUT_DIR = os.path.join(REPO_ROOT, "assets", "models", "environment")
FBX_OUT_PATH = os.path.join(FBX_OUT_DIR, "HubCobblePaths.fbx")
MANIFEST_OUT_PATH = os.path.join(FBX_OUT_DIR, "hub_cobble_paths_manifest.json")
LUAU_DATA_PATH = os.path.join(REPO_ROOT, "src", "ReplicatedStorage", "Assets", "HubPathMeshData.luau")
LUAU_SHARD_PATH = os.path.join(REPO_ROOT, "src", "ReplicatedStorage", "Assets", "HubPathMeshes", "hub_cobble_paths.luau")
RENDER_DIR = os.path.join("C:", os.sep, "Users", "enter", ".gemini", "antigravity", "brain", "86c00e23-61e2-4a48-8e33-1a7f16f8ecb6")

# Hub layout constants matching src/ReplicatedStorage/Shared/Config/HubLayout.luau (origin = HubCentre (0, 12, -796))
HUB_HALF_X = 240.0
HUB_HALF_Z = 320.0
DAIS_CURB_RADIUS = 55.8
PATH_WIDTH = 16.0
BOULEVARD_WIDTH = 28.0
APRON_WIDTH = 26.0
APRON_DEPTH = 16.0
RIM_WALL_DEPTH = 2.45  # RimWall EdgeWall spans v = 0.5..2.5 along |u| >= 10; tuck 0.05 inside wall face
RIM_OPENING_HALF = 10.0

# Bridge deck visual standards matching Bridge_WalkwayDeck in generate_runesmith_sanctuary.py
DECK_TOP_Y = 0.34
DECK_BOT_Y = -0.10
DECK_BEVEL = 0.04

CURB_WIDTH = 0.56
CURB_PROUD = 0.38
CURB_BOT_OFFSET = -0.04
CURB_BEVEL = 0.03

PLAZA_APRON_POS = (85.328857, 0.650000, 155.258667)
PLAZA_APRON_TOP_Y = 0.85
PLAZA_APRON_BOT_Y = 0.45
PLAZA_APRON_SIZE_X = 73.0
PLAZA_APRON_SIZE_Z = 25.0
PLAZA_APRON_RIGHT = (0.741351, -0.671118)   # +X_local in (x, z)
PLAZA_APRON_BACK = (0.671118, 0.741351)     # +Z_local in (x, z); front entrance is -Z_local

OVERLOOK_POS = (-150.0, 4.92, 280.0)
OVERLOOK_TOP_Y = 5.04
OVERLOOK_BOT_Y = 4.80
OVERLOOK_SIZE_X = 52.8
OVERLOOK_SIZE_Z = 36.0
OVERLOOK_BALUSTRADE_THICK = 1.2

PLOT_BRIDGE_WIDTH = 18.0
PLOT_BRIDGE_LENGTH = 58.0
PLOT_BRIDGE_TOP_Y = 1.00
PLOT_BRIDGE_BOT_Y = -1.00
PLOT_BRIDGE_RAIL_INNER_HALF = 8.00  # Rails occupy |x| = 8..9 over z = -24..24

SPUR_A = (6.0, 116.0)
SPUR_B = (86.0, 156.0)

PLOT_SLOTS = [
    {"index": 1, "gate": (-240.0, 208.0), "inward": (1.0, 0.0), "along": (0.0, -1.0)},
    {"index": 2, "gate": (-240.0, 0.0),   "inward": (1.0, 0.0), "along": (0.0, -1.0)},
    {"index": 3, "gate": (-240.0, -208.0),"inward": (1.0, 0.0), "along": (0.0, -1.0)},
    {"index": 4, "gate": (-104.0, -320.0),"inward": (0.0, 1.0), "along": (1.0, 0.0)},
    {"index": 5, "gate": (104.0, -320.0), "inward": (0.0, 1.0), "along": (1.0, 0.0)},
    {"index": 6, "gate": (240.0, -208.0), "inward": (-1.0, 0.0),"along": (0.0, 1.0)},
    {"index": 7, "gate": (240.0, 0.0),    "inward": (-1.0, 0.0),"along": (0.0, 1.0)},
    {"index": 8, "gate": (240.0, 208.0),  "inward": (-1.0, 0.0),"along": (0.0, 1.0)},
]

COBBLE_RGB = (116, 112, 98)


def r2b(rx, ry, rz):
    return (rx, -rz, ry)


def b2r(bx, by, bz):
    return (bx, bz, -by)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _v2_add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def _v2_sub(a, b):
    return (a[0] - b[0], a[1] - b[1])


def _v2_scale(a, s):
    return (a[0] * s, a[1] * s)


def _v2_dot(a, b):
    return a[0] * b[0] + a[1] * b[1]


def _v2_cross(a, b):
    return a[0] * b[1] - a[1] * b[0]


def _v2_len(a):
    return math.hypot(a[0], a[1])


def _v2_norm(a):
    l = _v2_len(a)
    if l < 1e-9:
        return (0.0, 0.0)
    return (a[0] / l, a[1] / l)


def _poly_signed_area(poly):
    s = 0.0
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        s += x0 * y1 - x1 * y0
    return 0.5 * s


def _ensure_pos_area(poly):
    if _poly_signed_area(poly) < 0:
        return list(reversed(poly))
    return list(poly)


def _inset_polygon(poly, offset):
    poly = _ensure_pos_area(poly)
    n = len(poly)
    out = []
    for i in range(n):
        p_prev = poly[(i - 1) % n]
        p_curr = poly[i]
        p_next = poly[(i + 1) % n]
        e0 = _v2_norm(_v2_sub(p_curr, p_prev))
        e1 = _v2_norm(_v2_sub(p_next, p_curr))
        n0 = (-e0[1], e0[0])
        n1 = (-e1[1], e1[0])
        bis = _v2_add(n0, n1)
        blen = _v2_len(bis)
        if blen < 1e-6:
            m = n0
            scale = 1.0
        else:
            m = (bis[0] / blen, bis[1] / blen)
            denom = max(0.35, _v2_dot(m, n0))
            scale = min(2.5, 1.0 / denom)
        out.append(_v2_add(p_curr, _v2_scale(m, offset * scale)))
    return out


def _dedup_poly(poly, eps=1e-4):
    res = []
    for p in poly:
        if not res or _v2_len(_v2_sub(p, res[-1])) > eps:
            res.append(p)
    while len(res) > 2 and _v2_len(_v2_sub(res[0], res[-1])) <= eps:
        res.pop()
    # Remove strictly collinear vertices
    cleaned = []
    n = len(res)
    for i in range(n):
        a = res[(i - 1) % n]
        b = res[i]
        c = res[(i + 1) % n]
        d1 = _v2_norm(_v2_sub(b, a))
        d2 = _v2_norm(_v2_sub(c, b))
        if abs(_v2_cross(d1, d2)) > 1e-4 or _v2_dot(d1, d2) < 0.0:
            cleaned.append(b)
    return cleaned if len(cleaned) >= 3 else res


def _add_beveled_slab_from_poly(bm, poly_xz, y_bot, y_top, bevel=DECK_BEVEL):
    poly = _dedup_poly(_ensure_pos_area(poly_xz))
    n = len(poly)
    assert n >= 3
    inset = _inset_polygon(poly, bevel)
    yb0 = y_bot
    yb1 = y_bot + bevel
    yt0 = y_top - bevel
    yt1 = y_top

    ring_bot = [bm.verts.new(r2b(x, yb0, z)) for (x, z) in inset]
    ring_low = [bm.verts.new(r2b(x, yb1, z)) for (x, z) in poly]
    ring_hi = [bm.verts.new(r2b(x, yt0, z)) for (x, z) in poly]
    ring_top = [bm.verts.new(r2b(x, yt1, z)) for (x, z) in inset]

    def _safe_face(vs):
        try:
            bm.faces.new(vs)
        except ValueError:
            pass

    for i in range(n):
        j = (i + 1) % n
        _safe_face([ring_bot[j], ring_bot[i], ring_low[i], ring_low[j]])
        _safe_face([ring_low[j], ring_low[i], ring_hi[i], ring_hi[j]])
        _safe_face([ring_hi[j], ring_hi[i], ring_top[i], ring_top[j]])

    tris = geometry.tessellate_polygon([[Vector((x, z)) for (x, z) in inset]])
    for i0, i1, i2 in tris:
        _safe_face([ring_top[i0], ring_top[i1], ring_top[i2]])
        _safe_face([ring_bot[i0], ring_bot[i2], ring_bot[i1]])


def _add_mitered_curb_chain(bm, points_xz, inward_left=True, y_deck_top=DECK_TOP_Y, width=CURB_WIDTH, proud=CURB_PROUD, bot_off=CURB_BOT_OFFSET, bevel=CURB_BEVEL):
    """Sweep an 8-point chamfered octagonal stone curb inward along a 2D polyline."""
    pts = []
    for p in points_xz:
        if not pts or _v2_len(_v2_sub(p, pts[-1])) > 1e-4:
            pts.append(p)
    if len(pts) < 2:
        return

    sign = 1.0 if inward_left else -1.0
    y0 = y_deck_top + bot_off
    y1 = y_deck_top + proud
    b = bevel
    w = width

    # Cross-section: (across_inward_distance, y)
    # Trim both longitudinal ends by `bevel` inside endcap plane to bevel caps
    prof = [
        (0.0, y0 + b),
        (0.0, y1 - b),
        (b, y1),
        (w - b, y1),
        (w, y1 - b),
        (w, y0 + b),
        (w - b, y0),
        (b, y0),
    ]
    prof_cap = [
        (b, y0 + b),
        (b, y1 - b),
        (2 * b, y1 - b),
        (w - 2 * b, y1 - b),
        (w - b, y1 - b),
        (w - b, y0 + b),
        (w - 2 * b, y0 + b),
        (2 * b, y0 + b),
    ]

    m = len(pts)
    miter_dirs = []
    miter_scales = []
    end_tangents = []
    for i in range(m):
        if i == 0:
            t = _v2_norm(_v2_sub(pts[1], pts[0]))
            n_in = (-t[1] * sign, t[0] * sign)
            miter_dirs.append(n_in)
            miter_scales.append(1.0)
            end_tangents.append(t)
        elif i == m - 1:
            t = _v2_norm(_v2_sub(pts[-1], pts[-2]))
            n_in = (-t[1] * sign, t[0] * sign)
            miter_dirs.append(n_in)
            miter_scales.append(1.0)
            end_tangents.append(t)
        else:
            t0 = _v2_norm(_v2_sub(pts[i], pts[i - 1]))
            t1 = _v2_norm(_v2_sub(pts[i + 1], pts[i]))
            n0 = (-t0[1] * sign, t0[0] * sign)
            n1 = (-t1[1] * sign, t1[0] * sign)
            bis = _v2_add(n0, n1)
            bl = _v2_len(bis)
            if bl < 1e-6:
                miter_dirs.append(n0)
                miter_scales.append(1.0)
            else:
                mdir = (bis[0] / bl, bis[1] / bl)
                denom = max(0.35, _v2_dot(mdir, n0))
                miter_dirs.append(mdir)
                miter_scales.append(min(2.5, 1.0 / denom))
            end_tangents.append(t1)

    t_start = _v2_norm(_v2_sub(pts[1], pts[0]))
    t_end = _v2_norm(_v2_sub(pts[-1], pts[-2]))

    rings = []
    # Start beveled cap ring
    p0_in = _v2_add(pts[0], _v2_scale(t_start, 0.0))
    p0_step = _v2_add(pts[0], _v2_scale(t_start, b))
    cap_start = [
        bm.verts.new(r2b(p0_in[0] + miter_dirs[0][0] * s * miter_scales[0], y, p0_in[1] + miter_dirs[0][1] * s * miter_scales[0]))
        for (s, y) in prof_cap
    ]
    rings.append(cap_start)

    for i in range(m):
        base_pt = pts[i]
        if i == 0 and _v2_len(_v2_sub(pts[1], pts[0])) > 2.5 * b:
            base_pt = p0_step
        elif i == m - 1 and _v2_len(_v2_sub(pts[-1], pts[-2])) > 2.5 * b:
            base_pt = _v2_sub(pts[-1], _v2_scale(t_end, b))
        mdir = miter_dirs[i]
        mscale = miter_scales[i]
        ring = [
            bm.verts.new(r2b(base_pt[0] + mdir[0] * s * mscale, y, base_pt[1] + mdir[1] * s * mscale))
            for (s, y) in prof
        ]
        rings.append(ring)

    # End beveled cap ring
    cap_end = [
        bm.verts.new(r2b(pts[-1][0] + miter_dirs[-1][0] * s * miter_scales[-1], y, pts[-1][1] + miter_dirs[-1][1] * s * miter_scales[-1]))
        for (s, y) in prof_cap
    ]
    rings.append(cap_end)

    def _safe_face(vs):
        try:
            bm.faces.new(vs)
        except ValueError:
            pass

    k = len(prof)
    for r_idx in range(len(rings) - 1):
        ra = rings[r_idx]
        rb = rings[r_idx + 1]
        for j in range(k):
            jn = (j + 1) % k
            if inward_left:
                _safe_face([ra[j], ra[jn], rb[jn], rb[j]])
            else:
                _safe_face([ra[jn], ra[j], rb[j], rb[jn]])

    if inward_left:
        _safe_face(list(reversed(rings[0])))
        _safe_face(rings[-1])
    else:
        _safe_face(rings[0])
        _safe_face(list(reversed(rings[-1])))


def _assign_box_uvs(bm, scale=0.25):
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in face.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u, v = co.x * scale, co.y * scale
            elif ax >= ay and ax >= az:
                u, v = co.y * scale, co.z * scale
            else:
                u, v = co.x * scale, co.z * scale
            loop[uv_layer].uv = (u, v)


def _finalize_bmesh_object(name, bm, material):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _assign_box_uvs(bm, scale=0.25)

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    for poly in mesh.polygons:
        poly.use_smooth = False

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def _ray_rect_exit(origin, direction, u_min, u_max, v_min, v_max):
    """Find smallest positive t >= 0 where ray(t) = origin + t * direction exits [u_min, u_max] x [v_min, v_max]."""
    ou, ov = origin
    du, dv = direction
    candidates = []
    if abs(du) > 1e-9:
        for edge_name, u_edge in (("u_min", u_min), ("u_max", u_max)):
            t = (u_edge - ou) / du
            if t >= -1e-6:
                v_hit = ov + t * dv
                if v_min - 1e-5 <= v_hit <= v_max + 1e-5:
                    candidates.append((max(0.0, t), (u_edge, max(v_min, min(v_max, v_hit))), edge_name))
    if abs(dv) > 1e-9:
        for edge_name, v_edge in (("v_min", v_min), ("v_max", v_max)):
            t = (v_edge - ov) / dv
            if t >= -1e-6:
                u_hit = ou + t * du
                if u_min - 1e-5 <= u_hit <= u_max + 1e-5:
                    candidates.append((max(0.0, t), (max(u_min, min(u_max, u_hit)), v_edge), edge_name))
    # Filter out starting wall v_min
    valid = [c for c in candidates if c[0] > 1e-4 and c[2] != "v_min"]
    if not valid:
        valid = [c for c in candidates if c[0] > 1e-4]
    valid.sort(key=lambda c: c[0])
    return valid[0]


def _gate_local_to_hub(slot, u, v):
    gx, gz = slot["gate"]
    ix, iz = slot["inward"]
    ax, az = slot["along"]
    return (gx + u * ax + v * ix, gz + u * az + v * iz)


def _hub_to_gate_local(slot, x, z):
    gx, gz = slot["gate"]
    dx, dz = x - gx, z - gz
    ix, iz = slot["inward"]
    ax, az = slot["along"]
    return (dx * ax + dz * az, dx * ix + dz * iz)


def _gate_dir_to_local(slot, vx, vz):
    ix, iz = slot["inward"]
    ax, az = slot["along"]
    return (vx * ax + vz * az, vx * ix + vz * iz)


def _dais_circle_hit(pt, direction, radius=DAIS_CURB_RADIUS):
    """Intersection of ray pt + s * direction (s > 0) with circle |P| = radius."""
    a = direction[0] ** 2 + direction[1] ** 2
    b = 2.0 * (pt[0] * direction[0] + pt[1] * direction[1])
    c = pt[0] ** 2 + pt[1] ** 2 - radius ** 2
    disc = max(0.0, b * b - 4 * a * c)
    s = (-b + math.sqrt(disc)) / (2 * a)
    return _v2_add(pt, _v2_scale(direction, s))


def build_gate_spoke(slot, material):
    """Build seamless union of Gate_i Apron + GardenPath_i clipped to Hub interior & Dais."""
    bm = bmesh.new()
    gx, gz = slot["gate"]
    # Spoke vector pointing from gate toward hub origin (inward)
    d_hub = _v2_norm((-gx, -gz))
    # Left relative to d_hub (pointing inward along spoke) in XZ plane
    n_left_hub = (-d_hub[1], d_hub[0])
    half_w = PATH_WIDTH * 0.5

    # Convert spoke boundary rays to gate-local (u, v) where u in [-13, 13], v in [0, 16]
    p_spoke_outer_L_hub = _v2_add((gx, gz), _v2_scale(n_left_hub, half_w))
    p_spoke_outer_R_hub = _v2_add((gx, gz), _v2_scale(n_left_hub, -half_w))

    oL_loc = _hub_to_gate_local(slot, *p_spoke_outer_L_hub)
    oR_loc = _hub_to_gate_local(slot, *p_spoke_outer_R_hub)
    d_loc = _gate_dir_to_local(slot, *d_hub)

    u_half = APRON_WIDTH * 0.5
    v_apron = APRON_DEPTH

    _, L_exit_loc, L_edge = _ray_rect_exit(oL_loc, d_loc, -u_half, u_half, 0.0, v_apron)
    _, R_exit_loc, R_edge = _ray_rect_exit(oR_loc, d_loc, -u_half, u_half, 0.0, v_apron)

    L_exit_hub = _gate_local_to_hub(slot, *L_exit_loc)
    R_exit_hub = _gate_local_to_hub(slot, *R_exit_loc)

    # Inner endpoints at Dais Curb circle (55.8) and deck tuck radius (54.0)
    L_dais_hub = _dais_circle_hit(p_spoke_outer_L_hub, d_hub, DAIS_CURB_RADIUS)
    R_dais_hub = _dais_circle_hit(p_spoke_outer_R_hub, d_hub, DAIS_CURB_RADIUS)
    L_deck_hub = _dais_circle_hit(p_spoke_outer_L_hub, d_hub, DAIS_CURB_RADIUS - 1.8)
    R_deck_hub = _dais_circle_hit(p_spoke_outer_R_hub, d_hub, DAIS_CURB_RADIUS - 1.8)

    # Verify spoke orientation relative to apron rectangle CCW perimeter in gate-local coords:
    # Apron CCW vertices in (u, v): A=(-13, 0), B=(+13, 0), C=(+13, 16), D=(-13, 16)
    # Parameterize boundary points along A->B->C->D->A (u_half=13, v_apron=16)
    def rect_perim_param(pt_loc):
        u, v = pt_loc
        if abs(v) < 1e-4:
            return u + u_half
        elif abs(u - u_half) < 1e-4:
            return 2 * u_half + v
        elif abs(v - v_apron) < 1e-4:
            return 2 * u_half + v_apron + (u_half - u)
        else:
            return 4 * u_half + v_apron + (v_apron - v)

    # Check which side of the spoke hits earlier on perimeter A->B->C->D->A
    pL = rect_perim_param(L_exit_loc)
    pR = rect_perim_param(R_exit_loc)
    # Corners around apron: A(0), B(26), C(42), D(68)
    corners_loc = [(-u_half, 0.0), (u_half, 0.0), (u_half, v_apron), (-u_half, v_apron)]
    corners_param = [0.0, 2 * u_half, 2 * u_half + v_apron, 4 * u_half + v_apron]

    # Walk around apron from B (+u_half, 0) forward to first spoke exit, through spoke to second exit, back to A (-u_half, 0)
    if pR < pL:
        first_exit_loc, first_p, first_dais, first_deck = R_exit_loc, pR, R_dais_hub, R_deck_hub
        second_exit_loc, second_p, second_dais, second_deck = L_exit_loc, pL, L_dais_hub, L_deck_hub
    else:
        first_exit_loc, first_p, first_dais, first_deck = L_exit_loc, pL, L_dais_hub, L_deck_hub
        second_exit_loc, second_p, second_dais, second_deck = R_exit_loc, pR, R_dais_hub, R_deck_hub

    deck_poly = [
        _gate_local_to_hub(slot, -u_half, 0.0),
        _gate_local_to_hub(slot, u_half, 0.0),
    ]
    for ci in range(1, 4):
        if corners_param[ci] < first_p - 1e-4:
            deck_poly.append(_gate_local_to_hub(slot, *corners_loc[ci]))
    deck_poly.append(_gate_local_to_hub(slot, *first_exit_loc))
    deck_poly.append(first_deck)
    deck_poly.append(second_deck)
    deck_poly.append(_gate_local_to_hub(slot, *second_exit_loc))
    for ci in range(1, 4):
        if corners_param[ci] > second_p + 1e-4:
            deck_poly.append(_gate_local_to_hub(slot, *corners_loc[ci]))

    deck_poly = _ensure_pos_area(deck_poly)
    _add_beveled_slab_from_poly(bm, deck_poly, DECK_BOT_Y, DECK_TOP_Y, DECK_BEVEL)

    # Check whether inward_left applies to the ensured-positive polygon
    area_test = _poly_signed_area([
        (-u_half, 0.0), (u_half, 0.0), (u_half, v_apron), (-u_half, v_apron)
    ])
    # Wait: test directly whether chain direction (-u_half, 0)->(u_half, 0) goes +v or -v with inward_left!
    # In hub coords, let's build the two exposed curb polylines explicitly starting from v = RIM_WALL_DEPTH (2.55)
    # up to R_dais_hub / L_dais_hub, using exact dot-product test for inward direction!
    # Right wing (along u = +u_half) starts at (+u_half, 2.55) -> walks around corners strictly < first_p -> first_exit -> first_dais
    right_chain = [_gate_local_to_hub(slot, u_half, RIM_WALL_DEPTH)]
    for ci in range(2, 4):
        if corners_param[ci] < first_p - 1e-4:
            right_chain.append(_gate_local_to_hub(slot, *corners_loc[ci]))
    if first_p > 2 * u_half + RIM_WALL_DEPTH + 0.2:
        right_chain.append(_gate_local_to_hub(slot, *first_exit_loc))
    else:
        # Spoke already entered side edge before or right at RIM_WALL_DEPTH (clamp start to max(v, RIM_WALL_DEPTH))
        ex_u, ex_v = first_exit_loc
        right_chain = [_gate_local_to_hub(slot, ex_u, max(ex_v, RIM_WALL_DEPTH))]
    right_chain.append(first_dais)

    # Left chain walks backwards from (-u_half, RIM_WALL_DEPTH) along corners > second_p -> second_exit -> second_dais
    left_chain = [_gate_local_to_hub(slot, -u_half, RIM_WALL_DEPTH)]
    for ci in range(3, 1, -1):
        if corners_param[ci] > second_p + 1e-4:
            left_chain.append(_gate_local_to_hub(slot, *corners_loc[ci]))
    max_perim = 4 * u_half + 2 * v_apron
    if second_p < max_perim - RIM_WALL_DEPTH - 0.2:
        left_chain.append(_gate_local_to_hub(slot, *second_exit_loc))
    else:
        ex_u, ex_v = second_exit_loc
        left_chain = [_gate_local_to_hub(slot, ex_u, max(ex_v, RIM_WALL_DEPTH))]
    left_chain.append(second_dais)

    def _inward_side_is_left(chain):
        p0, p1 = chain[0], chain[1]
        t = _v2_norm(_v2_sub(p1, p0))
        mid = _v2_scale(_v2_add(p0, p1), 0.5)
        nL = (-t[1], t[0])
        test_pt = _v2_add(mid, _v2_scale(nL, 0.25))
        # Check point-in-polygon against deck_poly
        inside = False
        m = len(deck_poly)
        j = m - 1
        for idx in range(m):
            xi, zi = deck_poly[idx]
            xj, zj = deck_poly[j]
            if ((zi > test_pt[1]) != (zj > test_pt[1])) and (
                test_pt[0] < (xj - xi) * (test_pt[1] - zi) / ((zj - zi) if abs(zj - zi) > 1e-12 else 1e-12) + xi
            ):
                inside = not inside
            j = idx
        return inside

    _add_mitered_curb_chain(bm, right_chain, inward_left=_inward_side_is_left(right_chain))
    _add_mitered_curb_chain(bm, left_chain, inward_left=_inward_side_is_left(left_chain))

    name = f"Hub_GateSpoke_{slot['index']}"
    return _finalize_bmesh_object(name, bm, material)


def _point_in_poly(pt, poly):
    inside = False
    m = len(poly)
    j = m - 1
    for i in range(m):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if ((zi > pt[1]) != (zj > pt[1])) and (
            pt[0] < (xj - xi) * (pt[1] - zi) / ((zj - zi) if abs(zj - zi) > 1e-12 else 1e-12) + xi
        ):
            inside = not inside
        j = i
    return inside


def _inward_flag(chain, poly):
    p0, p1 = chain[0], chain[1]
    t = _v2_norm(_v2_sub(p1, p0))
    mid = _v2_scale(_v2_add(p0, p1), 0.5)
    nL = (-t[1], t[0])
    return _point_in_poly(_v2_add(mid, _v2_scale(nL, 0.25)), poly)


def build_pilgrims_way(material):
    bm = bmesh.new()
    hw = BOULEVARD_WIDTH * 0.5  # 14.0
    z_dais_edge = math.sqrt(DAIS_CURB_RADIUS ** 2 - hw ** 2)  # 54.01
    z_deck_start = 53.5
    z_end = HUB_HALF_Z  # 320.0

    poly = [(-hw, z_deck_start), (hw, z_deck_start), (hw, z_end), (-hw, z_end)]
    _add_beveled_slab_from_poly(bm, poly, DECK_BOT_Y, DECK_TOP_Y, DECK_BEVEL)

    # Spur intersection along x = 14.0
    spur_dir = _v2_norm(_v2_sub(SPUR_B, SPUR_A))
    spur_nL = (-spur_dir[1], spur_dir[0])
    slope_zx = spur_dir[1] / spur_dir[0]
    half_z_span = (PATH_WIDTH * 0.5) / abs(spur_dir[0])
    z_spur_mid_at_14 = SPUR_A[1] + slope_zx * (hw - SPUR_A[0])  # 120.0
    z_gap_north = z_spur_mid_at_14 - half_z_span  # 111.0557
    z_gap_south = z_spur_mid_at_14 + half_z_span  # 128.9443

    west_chain = [(-hw, z_dais_edge), (-hw, z_end)]
    east_north_chain = [(hw, z_dais_edge), (hw, z_gap_north)]
    east_south_chain = [(hw, z_gap_south), (hw, z_end)]

    _add_mitered_curb_chain(bm, west_chain, inward_left=_inward_flag(west_chain, poly))
    _add_mitered_curb_chain(bm, east_north_chain, inward_left=_inward_flag(east_north_chain, poly))
    _add_mitered_curb_chain(bm, east_south_chain, inward_left=_inward_flag(east_south_chain, poly))

    return _finalize_bmesh_object("Hub_PilgrimsWay", bm, material)


def _plaza_local_to_hub(u, v):
    cx, _, cz = PLAZA_APRON_POS
    rx, rz = PLAZA_APRON_RIGHT
    bx, bz = PLAZA_APRON_BACK
    return (cx + u * rx + v * bx, cz + u * rz + v * bz)


def build_spur_path(material):
    bm = bmesh.new()
    spur_dir = _v2_norm(_v2_sub(SPUR_B, SPUR_A))
    spur_nL = (-spur_dir[1], spur_dir[0])
    hw = PATH_WIDTH * 0.5
    slope_zx = spur_dir[1] / spur_dir[0]
    z_gap_north = SPUR_A[1] + slope_zx * (14.0 - SPUR_A[0]) - hw / abs(spur_dir[0])
    z_gap_south = SPUR_A[1] + slope_zx * (14.0 - SPUR_A[0]) + hw / abs(spur_dir[0])

    # Meet Pilgrim's Way cleanly at x = 14.0 with 0.0 overlap at y_top = 0.34, and end tucked under PlazaApronBase (v_plaza = -14.0)
    west_n = (14.0, z_gap_north)
    west_s = (14.0, z_gap_south)

    # Intersect Spur north/south edges with Plaza front line v_plaza = -14.2 (under PlazaApronBase)
    # Plane normal is PLAZA_APRON_BACK, point on line is _plaza_local_to_hub(0, -14.2)
    def intersect_plaza_v(start_pt, v_target):
        p0 = _plaza_local_to_hub(0.0, v_target)
        bx, bz = PLAZA_APRON_BACK
        num = _v2_dot(_v2_sub(p0, start_pt), (bx, bz))
        den = _v2_dot(spur_dir, (bx, bz))
        return _v2_add(start_pt, _v2_scale(spur_dir, num / den))

    east_n_deck = intersect_plaza_v(west_n, -14.0)
    east_s_deck = intersect_plaza_v(west_s, -14.0)
    east_n_curb = intersect_plaza_v(west_n, -15.1)  # Just outside PlazaApronBase front face (-15.0)
    east_s_curb = intersect_plaza_v(west_s, -15.1)

    poly = _ensure_pos_area([west_n, east_n_deck, east_s_deck, west_s])
    _add_beveled_slab_from_poly(bm, poly, DECK_BOT_Y, DECK_TOP_Y, DECK_BEVEL)

    # Curb chains meet Pilgrim's Way curbs right at x = 14.0 and PlazaApronBase front at v = -15.1
    if _v2_dot(spur_nL, (0, 1)) > 0:
        # south vs north check via point-in-poly
        pass
    chain_n = [west_n, east_n_curb]
    chain_s = [west_s, east_s_curb]
    _add_mitered_curb_chain(bm, chain_n, inward_left=_inward_flag(chain_n, poly))
    _add_mitered_curb_chain(bm, chain_s, inward_left=_inward_flag(chain_s, poly))

    return _finalize_bmesh_object("Hub_SpurPath", bm, material)


def build_plaza_apron_deck(material):
    bm = bmesh.new()
    hu = PLAZA_APRON_SIZE_X * 0.5   # 36.5
    hv = PLAZA_APRON_SIZE_Z * 0.5   # 12.5
    corners = [
        _plaza_local_to_hub(-hu, -hv),
        _plaza_local_to_hub(hu, -hv),
        _plaza_local_to_hub(hu, hv),
        _plaza_local_to_hub(-hu, hv),
    ]
    poly = _ensure_pos_area(corners)
    _add_beveled_slab_from_poly(bm, poly, PLAZA_APRON_BOT_Y, PLAZA_APRON_TOP_Y, DECK_BEVEL)

    # Determine Spur entry interval along front face v = -12.5
    spur_dir = _v2_norm(_v2_sub(SPUR_B, SPUR_A))
    spur_nL = (-spur_dir[1], spur_dir[0])
    bx, bz = PLAZA_APRON_BACK
    rx, rz = PLAZA_APRON_RIGHT
    p_front = _plaza_local_to_hub(0.0, -hv)

    def spur_hit_u(edge_offset):
        p_edge = _v2_add(SPUR_A, _v2_scale(spur_nL, edge_offset))
        num = _v2_dot(_v2_sub(p_front, p_edge), (bx, bz))
        den = _v2_dot(spur_dir, (bx, bz))
        hit = _v2_add(p_edge, _v2_scale(spur_dir, num / den))
        return _v2_dot(_v2_sub(hit, p_front), (rx, rz))

    u0 = spur_hit_u(-PATH_WIDTH * 0.5)
    u1 = spur_hit_u(PATH_WIDTH * 0.5)
    u_open_min = max(-hu + 2.5, min(u0, u1) - 0.5)
    u_open_max = min(hu - 2.5, max(u0, u1) + 0.5)

    # Front corners at u = +/- 36.5, v = -10.5 host the 2.82x2.82 Lantern_StoneBase pedestals (v = -11.9..-9.0, |u| >= 35.0)
    # Keep front curb cleanly gapped around both Spur entrance AND corner lantern pedestals
    front_left = [_plaza_local_to_hub(-34.6, -hv), _plaza_local_to_hub(u_open_min, -hv)]
    front_right = [_plaza_local_to_hub(u_open_max, -hv), _plaza_local_to_hub(34.6, -hv)]
    # Back + ends chain wrapping cleanly around back corners up to behind the Lantern pedestals (v = -8.6)
    back_u_chain = [
        _plaza_local_to_hub(-hu, -8.6),
        _plaza_local_to_hub(-hu, hv),
        _plaza_local_to_hub(hu, hv),
        _plaza_local_to_hub(hu, -8.6),
    ]

    for ch in (front_left, front_right, back_u_chain):
        _add_mitered_curb_chain(bm, ch, inward_left=_inward_flag(ch, poly), y_deck_top=PLAZA_APRON_TOP_Y)

    return _finalize_bmesh_object("Hub_PlazaApronDeck", bm, material)


def build_overlook_terrace_top(material):
    bm = bmesh.new()
    cx, _, cz = OVERLOOK_POS
    hx = OVERLOOK_SIZE_X * 0.5  # 26.4
    hz = OVERLOOK_SIZE_Z * 0.5  # 18.0
    poly = _ensure_pos_area([
        (cx - hx, cz - hz),
        (cx + hx, cz - hz),
        (cx + hx, cz + hz),
        (cx - hx, cz + hz),
    ])
    _add_beveled_slab_from_poly(bm, poly, OVERLOOK_BOT_Y, OVERLOOK_TOP_Y, DECK_BEVEL)

    # Balustrades cover west/east edges (z in [262..275.2], [284.8..298], thick 1.2 -> |x| edge 1.2 inward)
    # North overlook edge (z = cz - hz = 262.0) is open between balustrades! Add signature curb across north overlook lip
    # plus short curb shoulders flanking the west/east ramp portals inside the 9.6-wide doorway gap? Keep ramp doorways clear!
    north_lip = [
        (cx - hx + OVERLOOK_BALUSTRADE_THICK, cz - hz),
        (cx + hx - OVERLOOK_BALUSTRADE_THICK, cz - hz),
    ]
    _add_mitered_curb_chain(bm, north_lip, inward_left=_inward_flag(north_lip, poly), y_deck_top=OVERLOOK_TOP_Y)

    return _finalize_bmesh_object("Hub_OverlookTerraceTop", bm, material)


def build_plot_bridge_deck(material):
    """Single reusable 18x2x58 bridge deck centered at (0,0,0), curbs tucked just inside IslandBridge_*_Rail (|x|=8..9)."""
    bm = bmesh.new()
    hw = PLOT_BRIDGE_WIDTH * 0.5   # 9.0
    hl = PLOT_BRIDGE_LENGTH * 0.5  # 29.0
    poly = _ensure_pos_area([(-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl)])
    _add_beveled_slab_from_poly(bm, poly, PLOT_BRIDGE_BOT_Y, PLOT_BRIDGE_TOP_Y, DECK_BEVEL)

    # Rails sit at |x| = 8.0..9.0 over z = [-24..24]. Terminate curbs flush at |z| = 24.0 inside the rail ends.
    curb_outer_x = PLOT_BRIDGE_RAIL_INNER_HALF  # 8.00
    curb_z = 24.0
    west_curb = [(-curb_outer_x, -curb_z), (-curb_outer_x, curb_z)]
    east_curb = [(curb_outer_x, -curb_z), (curb_outer_x, curb_z)]

    _add_mitered_curb_chain(bm, west_curb, inward_left=_inward_flag(west_curb, poly), y_deck_top=PLOT_BRIDGE_TOP_Y)
    _add_mitered_curb_chain(bm, east_curb, inward_left=_inward_flag(east_curb, poly), y_deck_top=PLOT_BRIDGE_TOP_Y)

    return _finalize_bmesh_object("Hub_PlotBridgeDeck", bm, material)


def pack_luau_mesh_data(objects):
    """Pack every mesh (Vertices, Normals, UVs, Triangles) into compact Luau shards matching Hub coordinates."""
    shards = []
    manifest_parts = []
    for obj in objects:
        depsgraph = bpy.context.evaluated_depsgraph_get()
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()
        mesh.calc_loop_triangles()

        world_mat = obj.matrix_world
        uv_layer = mesh.uv_layers.active.data if mesh.uv_layers.active else None

        # Compute Roblox tight AABB center so local vertices sit cleanly around (0, 0, 0)
        rx_verts = []
        for v in mesh.vertices:
            bco = world_mat @ v.co
            rx_verts.append(b2r(bco.x, bco.y, bco.z))

        xs = [p[0] for p in rx_verts]
        ys = [p[1] for p in rx_verts]
        zs = [p[2] for p in rx_verts]
        min_v = (min(xs), min(ys), min(zs))
        max_v = (max(xs), max(ys), max(zs))
        center = (
            0.5 * (min_v[0] + max_v[0]),
            0.5 * (min_v[1] + max_v[1]),
            0.5 * (min_v[2] + max_v[2]),
        )
        size = (
            max_v[0] - min_v[0],
            max_v[1] - min_v[1],
            max_v[2] - min_v[2],
        )

        # Quantized unique normals & UVs for crisp flat edges & matching scale=0.25 UVs
        norm_map = {}
        norms = []
        uv_map = {}
        uvs = []

        def intern_norm(nx, ny, nz):
            key = (round(nx, 3), round(ny, 3), round(nz, 3))
            idx = norm_map.get(key)
            if idx is None:
                idx = len(norms) // 3 + 1  # 1-based for Luau!
                norm_map[key] = idx
                norms.extend(key)
            return idx

        def intern_uv(u, v):
            key = (round(u, 3), round(1.0 - v, 3))  # Standard FBX/Roblox V flip
            idx = uv_map.get(key)
            if idx is None:
                idx = len(uvs) // 2 + 1  # 1-based for Luau!
                uv_map[key] = idx
                uvs.extend(key)
            return idx

        vb = []
        for p in rx_verts:
            vb.extend([round(p[0] - center[0], 3), round(p[1] - center[1], 3), round(p[2] - center[2], 3)])

        tb = []
        ntb = []
        uvtb = []
        for tri in mesh.loop_triangles:
            v_ids = [vi + 1 for vi in tri.vertices]  # 1-based Luau indices
            tb.extend(v_ids)

            fn_b = tri.normal
            fn_r = b2r(fn_b.x, fn_b.y, fn_b.z)
            # Check winding consistency
            p0 = rx_verts[tri.vertices[0]]
            p1 = rx_verts[tri.vertices[1]]
            p2 = rx_verts[tri.vertices[2]]
            e1 = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
            e2 = (p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2])
            cr = (
                e1[1] * e2[2] - e1[2] * e2[1],
                e1[2] * e2[0] - e1[0] * e2[2],
                e1[0] * e2[1] - e1[1] * e2[0],
            )
            assert (cr[0] * fn_r[0] + cr[1] * fn_r[1] + cr[2] * fn_r[2]) >= -1e-4, f"Inverted winding in {obj.name}"

            nid = intern_norm(fn_r[0], fn_r[1], fn_r[2])
            ntb.extend([nid, nid, nid])

            if uv_layer:
                for li in tri.loops:
                    uv = uv_layer[li].uv
                    uvtb.append(intern_uv(uv.x, uv.y))
            else:
                uvid = intern_uv(0.0, 0.0)
                uvtb.extend([uvid, uvid, uvid])

        tri_count = len(mesh.loop_triangles)
        assert tri_count <= 9500, f"Shard {obj.name} exceeded 9500 tris: {tri_count}"

        shards.append({
            "name": obj.name,
            "part_name": obj.name,
            "shard_index": 1,
            "shard_count": 1,
            "material": "Cobblestone",
            "color": list(COBBLE_RGB),
            "center": [round(center[0], 4), round(center[1], 4), round(center[2], 4)],
            "size": [round(size[0], 4), round(size[1], 4), round(size[2], 4)],
            "vb": vb,
            "nb": norms,
            "ub": uvs,
            "tb": tb,
            "ntb": ntb,
            "uvtb": uvtb,
            "tri_count": tri_count,
        })
        manifest_parts.append({
            "name": obj.name,
            "center": [round(center[0], 4), round(center[1], 4), round(center[2], 4)],
            "size": [round(size[0], 4), round(size[1], 4), round(size[2], 4)],
            "triCount": tri_count,
            "vertCount": len(mesh.vertices),
        })
        eval_obj.to_mesh_clear()

    return shards, manifest_parts


def write_luau_files(shards, manifest_parts):
    os.makedirs(os.path.dirname(LUAU_SHARD_PATH), exist_ok=True)
    os.makedirs(FBX_OUT_DIR, exist_ok=True)

    lines = [
        "--!strict",
        "-- Auto-generated by tools/blender/generate_hub_cobble_paths.py",
        "return {",
    ]
    for s in shards:
        lines.append("\t{")
        lines.append(f"\t\tname = \"{s['name']}\",")
        lines.append(f"\t\tpartName = \"{s['part_name']}\",")
        lines.append(f"\t\tmaterial = \"{s['material']}\",")
        c = s["color"]
        lines.append(f"\t\tcolor = {{ {c[0]}, {c[1]}, {c[2]} }},")
        ctr = s["center"]
        lines.append(f"\t\tcenter = {{ {ctr[0]}, {ctr[1]}, {ctr[2]} }},")
        sz = s["size"]
        lines.append(f"\t\tsize = {{ {sz[0]}, {sz[1]}, {sz[2]} }},")
        lines.append("\t\tvb = { " + ", ".join(str(x) for x in s["vb"]) + " },")
        lines.append("\t\tnb = { " + ", ".join(str(x) for x in s["nb"]) + " },")
        lines.append("\t\tub = { " + ", ".join(str(x) for x in s["ub"]) + " },")
        lines.append("\t\ttb = { " + ", ".join(str(x) for x in s["tb"]) + " },")
        lines.append("\t\tntb = { " + ", ".join(str(x) for x in s["ntb"]) + " },")
        lines.append("\t\tuvtb = { " + ", ".join(str(x) for x in s["uvtb"]) + " },")
        lines.append("\t},")
    lines.append("}")

    with open(LUAU_SHARD_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    data_luau = """--!strict
-- HubPathMeshData.luau
-- Aggregator for packed Blender cobblestone path geometry.

local HubPathMeshesFolder = script.Parent:WaitForChild("HubPathMeshes")

export type HubPathShard = {
\tname: string,
\tpartName: string,
\tmaterial: string,
\tcolor: { number },
\tcenter: { number },
\tsize: { number },
\tvb: { number },
\tnb: { number },
\tub: { number },
\ttb: { number },
\tntb: { number },
\tuvtb: { number },
}

local shards: { HubPathShard } = require(HubPathMeshesFolder:WaitForChild("hub_cobble_paths")) :: { HubPathShard }

local byPartName: { [string]: HubPathShard } = {}
for _, shard in ipairs(shards) do
\tbyPartName[shard.partName] = shard
end

return {
\tPartCount = #shards,
\tShards = shards,
\tByPartName = byPartName,
}
"""
    with open(LUAU_DATA_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(data_luau)

    manifest = {
        "fbx": "assets/models/environment/HubCobblePaths.fbx",
        "material": "Cobblestone",
        "colorRGB": list(COBBLE_RGB),
        "uvScale": 0.25,
        "curbWidth": CURB_WIDTH,
        "curbProudHeight": CURB_PROUD,
        "parts": manifest_parts,
    }
    with open(MANIFEST_OUT_PATH, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2)


def export_fbx(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(
        filepath=FBX_OUT_PATH,
        use_selection=True,
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        axis_forward="Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=False,
    )


def render_verification_previews(objects):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720

    # Add crisp procedural stone visualization shader on Blender preview material (only for Cycles render)
    mat = bpy.data.materials["CobblestonePathPreview"]
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.85

    texcoord = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 4.0  # ~0.25 UV tiling feel in Cycles preview
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.04
    ramp.color_ramp.elements[0].color = (0.14, 0.14, 0.13, 1.0)
    ramp.color_ramp.elements[1].position = 0.14
    ramp.color_ramp.elements[1].color = (0.45, 0.44, 0.39, 1.0)
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35

    nt.links.new(texcoord.outputs["UV"], vor.inputs["Vector"])
    nt.links.new(vor.outputs["Distance"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(vor.outputs["Distance"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    # Sun + sky lighting
    world = bpy.data.worlds.new("HubSky")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.55, 0.65, 0.78, 1.0)
        bg.inputs["Strength"].default_value = 0.7

    sun_data = bpy.data.lights.new("Sun", type="SUN")
    sun_data.energy = 3.2
    sun_obj = bpy.data.objects.new("Sun", sun_data)
    bpy.context.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(52), 0.0, math.radians(-38))

    # Add temporary preview WayfinderDais circle + Grass base plane (NOT exported!)
    bm_ref = bmesh.new()
    bmesh.ops.create_circle(bm_ref, cap_ends=True, radius=55.8, segments=48)
    for v in bm_ref.verts:
        v.co.z = 0.45
    mesh_ref = bpy.data.meshes.new("DaisRef")
    bm_ref.to_mesh(mesh_ref)
    bm_ref.free()
    dais_ref = bpy.data.objects.new("DaisRef", mesh_ref)
    bpy.context.collection.objects.link(dais_ref)
    m_dais = bpy.data.materials.new("MarbleDais")
    m_dais.diffuse_color = (0.78, 0.77, 0.74, 1.0)
    dais_ref.data.materials.append(m_dais)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam

    def look_at(cam_pos_r, target_r):
        cp = Vector(r2b(*cam_pos_r))
        tp = Vector(r2b(*target_r))
        cam.location = cp
        direction = (tp - cp).normalized()
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bridge_obj = bpy.data.objects.get("Hub_PlotBridgeDeck")
    if bridge_obj:
        bridge_obj.hide_render = True

    # Shot 1: Pilgrim's Way + Spur Junction + PlazaApron closeup
    look_at((-18.0, 22.0, 178.0), (42.0, 0.5, 132.0))
    scene.render.filepath = os.path.join(RENDER_DIR, "verify_hub_paths_junctions.png")
    bpy.ops.render.render(write_still=True)

    # Shot 2: Looking straight down PilgrimsWay toward WayfinderDais + Spur opening (matching user closeup perspective!)
    look_at((0.0, 4.2, 165.0), (0.0, 0.5, 95.0))
    scene.render.filepath = os.path.join(RENDER_DIR, "verify_hub_paths_closeup.png")
    bpy.ops.render.render(write_still=True)

    # Shot 3: PlotBridgeDeck closeup looking down bridge showing both 0.56-wide +0.38-proud inner curbs
    dais_ref.hide_render = True
    if bridge_obj:
        bridge_obj.hide_render = False
    look_at((0.0, 4.2, -26.0), (0.0, 1.0, 8.0))
    scene.render.filepath = os.path.join(RENDER_DIR, "verify_hub_paths_bridge.png")
    bpy.ops.render.render(write_still=True)


def main():
    clear_scene()
    mat = bpy.data.materials.new("CobblestonePathPreview")
    mat.diffuse_color = (COBBLE_RGB[0] / 255.0, COBBLE_RGB[1] / 255.0, COBBLE_RGB[2] / 255.0, 1.0)

    objects = []
    for slot in PLOT_SLOTS:
        objects.append(build_gate_spoke(slot, mat))
    objects.append(build_pilgrims_way(mat))
    objects.append(build_spur_path(mat))
    objects.append(build_plaza_apron_deck(mat))
    objects.append(build_overlook_terrace_top(mat))
    objects.append(build_plot_bridge_deck(mat))

    # Export FBX and Luau BEFORE modifying shader nodes / preview objects
    export_fbx(objects)
    shards, manifest_parts = pack_luau_mesh_data(objects)
    write_luau_files(shards, manifest_parts)

    total_tris = sum(p["triCount"] for p in manifest_parts)
    print(f"[generate_hub_cobble_paths] Exported {len(objects)} meshes, total triangles = {total_tris}")
    for p in manifest_parts:
        print(f"  - {p['name']}: tris={p['triCount']} verts={p['vertCount']} size={p['size']} center={p['center']}")

    render_verification_previews(objects)


if __name__ == "__main__":
    main()
