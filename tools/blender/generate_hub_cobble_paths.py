import bpy
import bmesh
import json
import math
import os
from mathutils import Vector, Matrix, geometry

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
RIM_WALL_DEPTH = 2.50  # RimWall EdgeWall inner face at v = 2.50 (matches IslandBridge z_local = -29.0)

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
PLAZA_APRON_RIGHT = (0.741351, -0.671118)
PLAZA_APRON_BACK = (0.671118, 0.741351)

OVERLOOK_POS = (-150.0, 4.92, 280.0)
OVERLOOK_TOP_Y = 5.04
OVERLOOK_BOT_Y = 4.80
OVERLOOK_SIZE_X = 52.8
OVERLOOK_SIZE_Z = 36.0
OVERLOOK_BALUSTRADE_THICK = 1.2

# IslandBridge_1..8 local space: centered at (0, -0.90, 0) relative to HubCentre -> world deck top = 12.10 = +1.00 local
# Note: Hub gate threshold (v = 2.5, z_local = -29.0) has Hub deck top 12.34 = +1.24 local;
# bridge deck eases gently from +1.24 down to +1.00 over z_local = -29.0..-25.0 for zero threshold bump!
PLOT_BRIDGE_WIDTH = 18.0
PLOT_BRIDGE_LENGTH = 58.0
PLOT_BRIDGE_TOP_Y = 1.00
PLOT_BRIDGE_HUB_TOP_Y = 1.24
PLOT_BRIDGE_BOT_Y = -0.75
PLOT_BRIDGE_RAIL_INNER_HALF = 8.00

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
PARAPET_STONE_RGB = (104, 106, 110)
SPIRE_ROCK_RGB = PARAPET_STONE_RGB  # Match the bridge parapet stone color seamlessly
MOSS_RGB = (86, 104, 52)


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
    for i in range(m):
        if i == 0:
            t = _v2_norm(_v2_sub(pts[1], pts[0]))
            n_in = (-t[1] * sign, t[0] * sign)
            miter_dirs.append(n_in)
            miter_scales.append(1.0)
        elif i == m - 1:
            t = _v2_norm(_v2_sub(pts[-1], pts[-2]))
            n_in = (-t[1] * sign, t[0] * sign)
            miter_dirs.append(n_in)
            miter_scales.append(1.0)
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

    t_start = _v2_norm(_v2_sub(pts[1], pts[0]))
    t_end = _v2_norm(_v2_sub(pts[-1], pts[-2]))

    rings = []
    cap_start = [
        bm.verts.new(r2b(pts[0][0] + miter_dirs[0][0] * s * miter_scales[0], y, pts[0][1] + miter_dirs[0][1] * s * miter_scales[0]))
        for (s, y) in prof_cap
    ]
    rings.append(cap_start)

    p0_step = _v2_add(pts[0], _v2_scale(t_start, b))
    for i in range(m):
        base_pt = pts[i]
        if i == 0 and _v2_len(_v2_sub(pts[1], pts[0])) > 2.5 * b:
            base_pt = p0_step
        elif i == m - 1 and _v2_len(_v2_sub(pts[-1], pts[-2])) > 2.5 * b:
            base_pt = _v2_sub(pts[-1], _v2_scale(t_end, b))
        mdir = miter_dirs[i]
        mscale = miter_scales[i]
        rings.append([
            bm.verts.new(r2b(base_pt[0] + mdir[0] * s * mscale, y, base_pt[1] + mdir[1] * s * mscale))
            for (s, y) in prof
        ])

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


def _finalize_bmesh_object(name, bm, material, uv_scale=0.25, roblox_mat="Cobblestone", roblox_rgb=COBBLE_RGB):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _assign_box_uvs(bm, scale=uv_scale)

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    for poly in mesh.polygons:
        poly.use_smooth = False

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    obj["roblox_material"] = roblox_mat
    obj["roblox_rgb"] = list(roblox_rgb)
    return obj


def _gate_local_to_hub(slot, u, v):
    gx, gz = slot["gate"]
    ix, iz = slot["inward"]
    ax, az = slot["along"]
    return (gx + u * ax + v * ix, gz + u * az + v * iz)


def _dais_circle_hit(pt, direction, radius=DAIS_CURB_RADIUS):
    a = direction[0] ** 2 + direction[1] ** 2
    b = 2.0 * (pt[0] * direction[0] + pt[1] * direction[1])
    c = pt[0] ** 2 + pt[1] ** 2 - radius ** 2
    disc = max(0.0, b * b - 4 * a * c)
    s = (-b + math.sqrt(disc)) / (2 * a)
    return _v2_add(pt, _v2_scale(direction, s))


def _hermite_pt(p0, t0, p1, t1, u):
    u2 = u * u
    u3 = u2 * u
    h00 = 2 * u3 - 3 * u2 + 1
    h10 = u3 - 2 * u2 + u
    h01 = -2 * u3 + 3 * u2
    h11 = u3 - u2
    return (
        h00 * p0[0] + h10 * t0[0] + h01 * p1[0] + h11 * t1[0],
        h00 * p0[1] + h10 * t0[1] + h01 * p1[1] + h11 * t1[1],
    )


def _sweep_curved_road_and_curbs(bm, spine_pts_xz, half_w=PATH_WIDTH * 0.5, y_bot=DECK_BOT_Y, y_top=DECK_TOP_Y):
    """Sweep a beveled cobblestone deck + continuous 0.56-wide +0.38-tall beveled curbs along spine_pts_xz."""
    n = len(spine_pts_xz)
    assert n >= 2
    normals = []
    for i in range(n):
        if i == 0:
            dx = spine_pts_xz[1][0] - spine_pts_xz[0][0]
            dz = spine_pts_xz[1][1] - spine_pts_xz[0][1]
        elif i == n - 1:
            dx = spine_pts_xz[-1][0] - spine_pts_xz[-2][0]
            dz = spine_pts_xz[-1][1] - spine_pts_xz[-2][1]
        else:
            dx = spine_pts_xz[i + 1][0] - spine_pts_xz[i - 1][0]
            dz = spine_pts_xz[i + 1][1] - spine_pts_xz[i - 1][1]
        l = math.hypot(dx, dz)
        tx, tz = dx / l, dz / l
        normals.append((-tz, tx))

    def _safe_face(vs):
        try:
            bm.faces.new(vs)
        except ValueError:
            pass

    b = DECK_BEVEL
    deck_prof = [
        (-half_w + b, y_bot),
        (-half_w, y_bot + b),
        (-half_w, y_top - b),
        (-half_w + b, y_top),
        (half_w - b, y_top),
        (half_w, y_top - b),
        (half_w, y_bot + b),
        (half_w - b, y_bot),
    ]
    k = len(deck_prof)
    rings = []
    for i in range(n):
        cx, cz = spine_pts_xz[i]
        nx, nz = normals[i]
        rings.append([bm.verts.new(r2b(cx + nx * s, y, cz + nz * s)) for (s, y) in deck_prof])

    for i in range(n - 1):
        ra, rb = rings[i], rings[i + 1]
        for j in range(k):
            jn = (j + 1) % k
            _safe_face([ra[j], ra[jn], rb[jn], rb[j]])
    _safe_face(list(reversed(rings[0])))
    _safe_face(rings[-1])

    # Swept 0.56-wide +0.38-tall beveled side curbs along left & right edges
    cb = CURB_BEVEL
    y0 = y_top + CURB_BOT_OFFSET
    y1 = y_top + CURB_PROUD
    for sign in (-1.0, 1.0):
        s_in = sign * (half_w - CURB_WIDTH)
        s_out = sign * half_w
        lo_s, hi_s = min(s_in, s_out), max(s_in, s_out)
        c_prof = [
            (lo_s + cb, y0),
            (lo_s, y0 + cb),
            (lo_s, y1 - cb),
            (lo_s + cb, y1),
            (hi_s - cb, y1),
            (hi_s, y1 - cb),
            (hi_s, y0 + cb),
            (hi_s - cb, y0),
        ]
        ck = len(c_prof)
        crings = []
        for i in range(n):
            cx, cz = spine_pts_xz[i]
            nx, nz = normals[i]
            crings.append([bm.verts.new(r2b(cx + nx * s, y, cz + nz * s)) for (s, y) in c_prof])
        for i in range(n - 1):
            ra, rb = crings[i], crings[i + 1]
            for j in range(ck):
                jn = (j + 1) % ck
                _safe_face([ra[j], ra[jn], rb[jn], rb[j]])
        _safe_face(list(reversed(crings[0])))
        _safe_face(crings[-1])


def build_gate_spoke(slot, material):
    """Build smooth Hermite-curved radial path from Hub RimWall opening (v=2.5) to WayfinderDais circle (r=55.8)."""
    bm = bmesh.new()
    gx, gz = slot["gate"]
    d_hub = _v2_norm((-gx, -gz))
    inward_dir = slot["inward"]

    # Straight throat v = 2.50..5.20 strictly perpendicular to rim between RimWall & BannerPylons
    p_gate = _gate_local_to_hub(slot, 0.0, RIM_WALL_DEPTH)
    p_throat_end = _gate_local_to_hub(slot, 0.0, 5.20)
    # Dais point on the NEAR side of WayfinderDais along centerline ray (-d_hub * r)
    p_dais_end = _v2_scale(d_hub, -(DAIS_CURB_RADIUS - 0.8))

    angle_diff = math.acos(max(-1.0, min(1.0, _v2_dot(inward_dir, d_hub))))
    spine = [p_gate, p_throat_end]
    if angle_diff < 1e-3:
        spine.append(p_dais_end)
    else:
        p0 = p_throat_end
        t_mag = 26.0
        t0 = _v2_scale(inward_dir, t_mag)
        p1 = _v2_add((gx, gz), _v2_scale(d_hub, 44.0))
        t1 = _v2_scale(d_hub, t_mag)
        n_curve = 18
        for i in range(1, n_curve + 1):
            spine.append(_hermite_pt(p0, t0, p1, t1, i / n_curve))
        spine.append(p_dais_end)

    _sweep_curved_road_and_curbs(bm, spine, half_w=PATH_WIDTH * 0.5, y_bot=DECK_BOT_Y, y_top=DECK_TOP_Y)

    name = f"Hub_GateSpoke_{slot['index']}"
    return _finalize_bmesh_object(name, bm, material, uv_scale=0.25, roblox_mat="Cobblestone", roblox_rgb=COBBLE_RGB)


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
    hw = BOULEVARD_WIDTH * 0.5
    z_dais_edge = math.sqrt(DAIS_CURB_RADIUS ** 2 - hw ** 2)
    z_deck_start = 53.5
    z_end = HUB_HALF_Z

    poly = [(-hw, z_deck_start), (hw, z_deck_start), (hw, z_end), (-hw, z_end)]
    _add_beveled_slab_from_poly(bm, poly, DECK_BOT_Y, DECK_TOP_Y, DECK_BEVEL)

    spur_dir = _v2_norm(_v2_sub(SPUR_B, SPUR_A))
    slope_zx = spur_dir[1] / spur_dir[0]
    half_z_span = (PATH_WIDTH * 0.5) / abs(spur_dir[0])
    z_spur_mid_at_14 = SPUR_A[1] + slope_zx * (hw - SPUR_A[0])
    z_gap_north = z_spur_mid_at_14 - half_z_span
    z_gap_south = z_spur_mid_at_14 + half_z_span

    west_chain = [(-hw, z_dais_edge), (-hw, z_end)]
    east_north_chain = [(hw, z_dais_edge), (hw, z_gap_north)]
    east_south_chain = [(hw, z_gap_south), (hw, z_end)]

    _add_mitered_curb_chain(bm, west_chain, inward_left=_inward_flag(west_chain, poly))
    _add_mitered_curb_chain(bm, east_north_chain, inward_left=_inward_flag(east_north_chain, poly))
    _add_mitered_curb_chain(bm, east_south_chain, inward_left=_inward_flag(east_south_chain, poly))

    return _finalize_bmesh_object("Hub_PilgrimsWay", bm, material, uv_scale=0.25, roblox_mat="Cobblestone", roblox_rgb=COBBLE_RGB)


def _plaza_local_to_hub(u, v):
    cx, _, cz = PLAZA_APRON_POS
    rx, rz = PLAZA_APRON_RIGHT
    bx, bz = PLAZA_APRON_BACK
    return (cx + u * rx + v * bx, cz + u * rz + v * bz)


def build_spur_path(material):
    bm = bmesh.new()
    spur_dir = _v2_norm(_v2_sub(SPUR_B, SPUR_A))
    hw = PATH_WIDTH * 0.5
    slope_zx = spur_dir[1] / spur_dir[0]
    z_gap_north = SPUR_A[1] + slope_zx * (14.0 - SPUR_A[0]) - hw / abs(spur_dir[0])
    z_gap_south = SPUR_A[1] + slope_zx * (14.0 - SPUR_A[0]) + hw / abs(spur_dir[0])

    west_n = (14.0, z_gap_north)
    west_s = (14.0, z_gap_south)

    def intersect_plaza_v(start_pt, v_target):
        p0 = _plaza_local_to_hub(0.0, v_target)
        bx, bz = PLAZA_APRON_BACK
        num = _v2_dot(_v2_sub(p0, start_pt), (bx, bz))
        den = _v2_dot(spur_dir, (bx, bz))
        return _v2_add(start_pt, _v2_scale(spur_dir, num / den))

    east_n_deck = intersect_plaza_v(west_n, -14.0)
    east_s_deck = intersect_plaza_v(west_s, -14.0)
    east_n_curb = intersect_plaza_v(west_n, -15.1)
    east_s_curb = intersect_plaza_v(west_s, -15.1)

    poly = _ensure_pos_area([west_n, east_n_deck, east_s_deck, west_s])
    _add_beveled_slab_from_poly(bm, poly, DECK_BOT_Y, DECK_TOP_Y, DECK_BEVEL)

    chain_n = [west_n, east_n_curb]
    chain_s = [west_s, east_s_curb]
    _add_mitered_curb_chain(bm, chain_n, inward_left=_inward_flag(chain_n, poly))
    _add_mitered_curb_chain(bm, chain_s, inward_left=_inward_flag(chain_s, poly))

    return _finalize_bmesh_object("Hub_SpurPath", bm, material, uv_scale=0.25, roblox_mat="Cobblestone", roblox_rgb=COBBLE_RGB)


def build_plaza_apron_deck(material):
    bm = bmesh.new()
    hu = PLAZA_APRON_SIZE_X * 0.5
    hv = PLAZA_APRON_SIZE_Z * 0.5
    corners = [
        _plaza_local_to_hub(-hu, -hv),
        _plaza_local_to_hub(hu, -hv),
        _plaza_local_to_hub(hu, hv),
        _plaza_local_to_hub(-hu, hv),
    ]
    poly = _ensure_pos_area(corners)
    _add_beveled_slab_from_poly(bm, poly, PLAZA_APRON_BOT_Y, PLAZA_APRON_TOP_Y, DECK_BEVEL)

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

    front_left = [_plaza_local_to_hub(-34.6, -hv), _plaza_local_to_hub(u_open_min, -hv)]
    front_right = [_plaza_local_to_hub(u_open_max, -hv), _plaza_local_to_hub(34.6, -hv)]
    back_u_chain = [
        _plaza_local_to_hub(-hu, -8.6),
        _plaza_local_to_hub(-hu, hv),
        _plaza_local_to_hub(hu, hv),
        _plaza_local_to_hub(hu, -8.6),
    ]

    for ch in (front_left, front_right, back_u_chain):
        _add_mitered_curb_chain(bm, ch, inward_left=_inward_flag(ch, poly), y_deck_top=PLAZA_APRON_TOP_Y)

    return _finalize_bmesh_object("Hub_PlazaApronDeck", bm, material, uv_scale=0.25, roblox_mat="Cobblestone", roblox_rgb=COBBLE_RGB)


def build_overlook_terrace_top(material):
    bm = bmesh.new()
    cx, _, cz = OVERLOOK_POS
    hx = OVERLOOK_SIZE_X * 0.5
    hz = OVERLOOK_SIZE_Z * 0.5
    poly = _ensure_pos_area([
        (cx - hx, cz - hz),
        (cx + hx, cz - hz),
        (cx + hx, cz + hz),
        (cx - hx, cz + hz),
    ])
    _add_beveled_slab_from_poly(bm, poly, OVERLOOK_BOT_Y, OVERLOOK_TOP_Y, DECK_BEVEL)

    north_lip = [
        (cx - hx + OVERLOOK_BALUSTRADE_THICK, cz - hz),
        (cx + hx - OVERLOOK_BALUSTRADE_THICK, cz - hz),
    ]
    _add_mitered_curb_chain(bm, north_lip, inward_left=_inward_flag(north_lip, poly), y_deck_top=OVERLOOK_TOP_Y)

    return _finalize_bmesh_object("Hub_OverlookTerraceTop", bm, material, uv_scale=0.25, roblox_mat="Cobblestone", roblox_rgb=COBBLE_RGB)


def _add_beveled_box(bm, center_r, size_r, bevel=0.04):
    cx, cy, cz = center_r
    sx, sy, sz = size_r
    mat = Matrix.Translation(Vector(r2b(cx, cy, cz))) @ Matrix.Diagonal(Vector((sx, sz, sy, 1.0)))
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=mat)
    verts = res["verts"]
    if bevel > 0.0:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=1, affect="EDGES")
    return verts


def _add_pyramidal_cap(bm, center_r, base_x, base_z, base_h, apex_h):
    cx, cy, cz = center_r
    hx, hz = base_x * 0.5, base_z * 0.5
    tx, tz = base_x * 0.36, base_z * 0.36
    b0 = bm.verts.new(r2b(cx - hx, cy, cz - hz))
    b1 = bm.verts.new(r2b(cx + hx, cy, cz - hz))
    b2 = bm.verts.new(r2b(cx + hx, cy, cz + hz))
    b3 = bm.verts.new(r2b(cx - hx, cy, cz + hz))
    m0 = bm.verts.new(r2b(cx - tx, cy + base_h, cz - tz))
    m1 = bm.verts.new(r2b(cx + tx, cy + base_h, cz - tz))
    m2 = bm.verts.new(r2b(cx + tx, cy + base_h, cz + tz))
    m3 = bm.verts.new(r2b(cx - tx, cy + base_h, cz + tz))
    tip = bm.verts.new(r2b(cx, cy + base_h + apex_h, cz))
    bm.faces.new([b3, b2, b1, b0])
    for a, b, c, d in [(b0, b1, m1, m0), (b1, b2, m2, m1), (b2, b3, m3, m2), (b3, b0, m0, m3)]:
        bm.faces.new([a, b, c, d])
    for a, b in [(m0, m1), (m1, m2), (m2, m3), (m3, m0)]:
        bm.faces.new([a, b, tip])


def _add_pointed_gothic_arch_spandrel(bm, z_center, arch_span, z_start, z_end, x_center, width_x, y_spring, y_crown, y_deck_bot, rib_depth=0.26):
    half_s = arch_span * 0.5
    steps = 6
    prof_pts = []
    if z_center - half_s > z_start + 0.05:
        prof_pts.append((z_start, y_spring))
    for i in range(steps + 1):
        u = i / steps
        t_ang = u * (math.pi * 0.5)
        z = (z_center - half_s) + half_s * (1.0 - math.cos(t_ang))
        y = y_spring + (y_crown - y_spring) * (math.sin(t_ang) ** 0.85)
        prof_pts.append((z, y))
    for i in range(1, steps + 1):
        u = i / steps
        t_ang = u * (math.pi * 0.5)
        z = z_center + half_s * math.sin(t_ang)
        y = y_spring + (y_crown - y_spring) * (math.cos(t_ang) ** 0.85)
        prof_pts.append((z, y))
    if z_end > z_center + half_s + 0.05:
        prof_pts.append((z_end, y_spring))

    hx = width_x * 0.5
    front_top = [bm.verts.new(r2b(x_center + hx, y_deck_bot, z)) for (z, _) in prof_pts]
    front_bot = [bm.verts.new(r2b(x_center + hx, y, z)) for (z, y) in prof_pts]
    back_top = [bm.verts.new(r2b(x_center - hx, y_deck_bot, z)) for (z, _) in prof_pts]
    back_bot = [bm.verts.new(r2b(x_center - hx, y, z)) for (z, y) in prof_pts]

    n = len(prof_pts)
    for i in range(n - 1):
        bm.faces.new([front_top[i], front_top[i + 1], front_bot[i + 1], front_bot[i]])
        bm.faces.new([back_top[i + 1], back_top[i], back_bot[i], back_bot[i + 1]])
        bm.faces.new([front_top[i + 1], front_top[i], back_top[i], back_top[i + 1]])
        bm.faces.new([front_bot[i], front_bot[i + 1], back_bot[i + 1], back_bot[i]])
    bm.faces.new([back_top[0], front_top[0], front_bot[0], back_bot[0]])
    bm.faces.new([front_top[-1], back_top[-1], back_bot[-1], front_bot[-1]])

    if rib_depth > 0.01:
        arch_only = [(z, y) for (z, y) in prof_pts if z_center - half_s - 0.02 <= z <= z_center + half_s + 0.02]
        m_out = 0.40
        for xo0, xo1 in [(x_center + hx, x_center + hx + rib_depth), (x_center - hx - rib_depth, x_center - hx)]:
            f_in, f_out, b_in, b_out = [], [], [], []
            for (z, y) in arch_only:
                dz = z - z_center
                dy = y - y_spring
                ln = math.hypot(dz, dy)
                nz = dz / ln if ln > 1e-4 else 0.0
                ny = dy / ln if ln > 1e-4 else 1.0
                oz, oy = z + nz * m_out, min(y_deck_bot - 0.05, y + ny * m_out)
                f_in.append(bm.verts.new(r2b(xo1, y, z)))
                f_out.append(bm.verts.new(r2b(xo1, oy, oz)))
                b_in.append(bm.verts.new(r2b(xo0, y, z)))
                b_out.append(bm.verts.new(r2b(xo0, oy, oz)))
            na = len(arch_only)
            for i in range(na - 1):
                bm.faces.new([f_out[i], f_out[i + 1], f_in[i + 1], f_in[i]])
                bm.faces.new([b_in[i], b_in[i + 1], b_out[i + 1], b_out[i]])
                bm.faces.new([f_out[i + 1], f_out[i], b_out[i], b_out[i + 1]])
                bm.faces.new([f_in[i], f_in[i + 1], b_in[i + 1], b_in[i]])
            bm.faces.new([b_out[0], f_out[0], f_in[0], b_in[0]])
            bm.faces.new([f_out[-1], b_out[-1], b_in[-1], f_in[-1]])


def _add_faceted_hanging_spire(bm, top_center_r, radius_x, radius_z, drop_len, seed_val=1):
    cx, cy, cz = top_center_r
    rings_def = [
        (0.00, radius_x, radius_z, 0.0, 0.0),
        (0.18, radius_x * 0.85, radius_z * 0.87, 0.14 * ((seed_val % 3) - 1), -0.09),
        (0.45, radius_x * 0.54, radius_z * 0.55, -0.17, 0.12 * ((seed_val % 2) * 2 - 1)),
        (0.76, radius_x * 0.24, radius_z * 0.23, 0.08, -0.06),
    ]
    n_seg = 7
    rings = []
    for frac, rx, rz, ox, oz in rings_def:
        ring = []
        y = cy - drop_len * frac
        for i in range(n_seg):
            ang = 2.0 * math.pi * i / n_seg + seed_val * 0.37
            jitter = 0.83 + 0.31 * abs(math.sin(ang * 2.5 + frac * 4.0 + seed_val))
            ring.append(bm.verts.new(r2b(cx + ox + math.cos(ang) * rx * jitter, y, cz + oz + math.sin(ang) * rz * jitter)))
        rings.append(ring)

    bm.faces.new(rings[0])
    for ri in range(len(rings) - 1):
        ra, rb = rings[ri], rings[ri + 1]
        for i in range(n_seg):
            jn = (i + 1) % n_seg
            bm.faces.new([ra[jn], ra[i], rb[i], rb[jn]])
    tip = bm.verts.new(r2b(cx, cy - drop_len, cz))
    last = rings[-1]
    for i in range(n_seg):
        jn = (i + 1) % n_seg
        bm.faces.new([last[jn], last[i], tip])

    for k, (dx_f, dz_f, len_f) in enumerate([(-0.62, 0.32, 0.58), (0.58, -0.36, 0.48)]):
        scx = cx + dx_f * radius_x * 0.72
        scz = cz + dz_f * radius_z * 0.72
        scy = cy - drop_len * 0.08
        sr = min(radius_x, radius_z) * 0.42
        s_top, s_mid = [], []
        for i in range(5):
            ang = 2.0 * math.pi * i / 5 + k + seed_val * 0.5
            s_top.append(bm.verts.new(r2b(scx + math.cos(ang) * sr, scy, scz + math.sin(ang) * sr)))
            s_mid.append(bm.verts.new(r2b(scx + math.cos(ang) * sr * 0.46, scy - drop_len * len_f * 0.55, scz + math.sin(ang) * sr * 0.46)))
        s_tip = bm.verts.new(r2b(scx + 0.1 * dx_f, scy - drop_len * len_f, scz + 0.1 * dz_f))
        bm.faces.new(s_top)
        for i in range(5):
            jn = (i + 1) % 5
            bm.faces.new([s_top[jn], s_top[i], s_mid[i], s_mid[jn]])
            bm.faces.new([s_mid[jn], s_mid[i], s_tip])


def build_plot_bridge_kit(cobble_mat, parapet_mat, spire_mat):
    """Build 3-mesh reusable Fantasy Floating Castle Bridge centered on IslandBridge_i frame."""
    objects = []

    # 1. Hub_PlotBridgeDeck: smooth threshold ease (+1.24 @ z=-29 -> +1.00 @ z=-25 -> +1.00 @ z=+29) + inner curbs
    bm_deck = bmesh.new()
    hw = PLOT_BRIDGE_WIDTH * 0.5
    spine_z = [-29.0, -27.7, -26.4, -25.0, 20.5]
    spine_y = [PLOT_BRIDGE_HUB_TOP_Y, 1.18, 1.07, PLOT_BRIDGE_TOP_Y, PLOT_BRIDGE_TOP_Y]

    def _deck_top_y(z):
        if z <= -25.0:
            t = max(0.0, min(1.0, (z + 29.0) / 4.0))
            smooth_t = t * t * (3.0 - 2.0 * t)
            return PLOT_BRIDGE_HUB_TOP_Y + (PLOT_BRIDGE_TOP_Y - PLOT_BRIDGE_HUB_TOP_Y) * smooth_t
        return PLOT_BRIDGE_TOP_Y

    # Main roadway slab [-29.0 .. +29.0] with gentle ramp lead on Hub end [-29.0..-25.0]
    zs_slab = [-29.0, -27.7, -26.3, -25.0, 29.0]
    rings_d = []
    b = DECK_BEVEL
    for z in zs_slab:
        yt = _deck_top_y(z)
        yb = PLOT_BRIDGE_BOT_Y
        prof = [
            (-hw + b, yb), (-hw, yb + b), (-hw, yt - b), (-hw + b, yt),
            (hw - b, yt), (hw, yt - b), (hw, yb + b), (hw - b, yb),
        ]
        rings_d.append([bm_deck.verts.new(r2b(x, y, z)) for (x, y) in prof])
    kd = len(rings_d[0])
    for i in range(len(rings_d) - 1):
        ra, rb = rings_d[i], rings_d[i + 1]
        for j in range(kd):
            jn = (j + 1) % kd
            bm_deck.faces.new([ra[j], ra[jn], rb[jn], rb[j]])
    bm_deck.faces.new(list(reversed(rings_d[0])))
    bm_deck.faces.new(rings_d[-1])

    # Signature 0.56-wide +0.38-tall beveled inner curbs along [-29.0 .. +20.5]
    zs_curb = [-29.0, -27.7, -26.3, -25.0, 20.5]
    cb = CURB_BEVEL
    for sx in (-1.0, 1.0):
        lo_x = min(sx * (PLOT_BRIDGE_RAIL_INNER_HALF - CURB_WIDTH), sx * PLOT_BRIDGE_RAIL_INNER_HALF)
        hi_x = max(sx * (PLOT_BRIDGE_RAIL_INNER_HALF - CURB_WIDTH), sx * PLOT_BRIDGE_RAIL_INNER_HALF)
        crings = []
        for z in zs_curb:
            yt = _deck_top_y(z)
            y0 = yt + CURB_BOT_OFFSET
            y1 = yt + CURB_PROUD
            cprof = [
                (lo_x + cb, y0), (lo_x, y0 + cb), (lo_x, y1 - cb), (lo_x + cb, y1),
                (hi_x - cb, y1), (hi_x, y1 - cb), (hi_x, y0 + cb), (hi_x - cb, y0),
            ]
            crings.append([bm_deck.verts.new(r2b(x, y, z)) for (x, y) in cprof])
        ck = len(crings[0])
        for i in range(len(crings) - 1):
            ra, rb = crings[i], crings[i + 1]
            for j in range(ck):
                jn = (j + 1) % ck
                bm_deck.faces.new([ra[j], ra[jn], rb[jn], rb[j]])
        bm_deck.faces.new(list(reversed(crings[0])))
        bm_deck.faces.new(crings[-1])

    objects.append(_finalize_bmesh_object("Hub_PlotBridgeDeck", bm_deck, cobble_mat, uv_scale=0.25, roblox_mat="Cobblestone", roblox_rgb=COBBLE_RGB))

    # 2. Hub_PlotBridgeParapets: Gothic ashlar parapets, buttress piers, finials & 3 pointed under-arches
    bm_para = bmesh.new()
    # Piers aligned flush from Hub RimWall (-27.85) to Plot GatePlinth (+19.5)
    PIER_ZS = [-27.85, -12.05, 3.75, 19.5]
    BASE_Y = PLOT_BRIDGE_TOP_Y

    # Outer corbel cornice ledges running continuously under parapet edge (-29.0..+20.5)
    for sx in (-1.0, 1.0):
        _add_beveled_box(bm_para, (sx * 8.65, BASE_Y - 0.35, -4.25), (1.36, 0.90, 49.5), bevel=0.05)
        _add_beveled_box(bm_para, (sx * 8.85, BASE_Y - 0.98, -4.25), (1.02, 0.52, 48.8), bevel=0.04)

    # Parapet bays between piers
    for b_idx in range(len(PIER_ZS) - 1):
        za, zb = PIER_ZS[b_idx], PIER_ZS[b_idx + 1]
        zmid = 0.5 * (za + zb)
        span_len = (zb - za) - 1.6
        for sx in (-1.0, 1.0):
            px = sx * 8.62
            _add_beveled_box(bm_para, (px, BASE_Y + 0.42, zmid), (1.26, 0.84, span_len), bevel=0.04)
            _add_beveled_box(bm_para, (px, BASE_Y + 3.55, zmid), (1.36, 0.54, span_len), bevel=0.05)
            _add_beveled_box(bm_para, (px, BASE_Y + 3.16, zmid), (1.16, 0.28, span_len), bevel=0.03)
            n_mullions = 5
            for k in range(n_mullions):
                mz = (za + 1.0) + (span_len - 0.4) * (k / (n_mullions - 1))
                _add_beveled_box(bm_para, (px, BASE_Y + 1.95, mz), (1.08, 2.25, 0.72), bevel=0.0)
            _add_beveled_box(bm_para, (px, BASE_Y + 1.95, zmid), (0.48, 2.20, span_len), bevel=0.0)
            for k in range(n_mullions - 1):
                az = (za + 1.0) + (span_len - 0.4) * ((k + 0.5) / (n_mullions - 1))
                _add_beveled_box(bm_para, (px, BASE_Y + 2.86, az), (0.98, 0.42, (span_len / (n_mullions - 1)) * 0.86), bevel=0.0)

    # 4 pairs of Projecting Gothic Pier Buttresses + Finials ABOVE + Upper Pier Shafts BELOW
    for p_idx, pz in enumerate(PIER_ZS):
        is_hub_end = (p_idx == 0)
        is_inner = (p_idx in (1, 2))
        col_depth = 12.0 if is_inner else 9.4
        col_top = PLOT_BRIDGE_BOT_Y + 0.2
        y_spire_top = col_top - col_depth
        for sx in (-1.0, 1.0):
            # Hub-end pier flares outward cleanly to |x|=10.05 so RimWall (±10.0) meets bridge pier with zero gap!
            pier_x = sx * (9.02 if is_hub_end else 8.78)
            pier_w = 2.08 if is_hub_end else 2.24
            _add_beveled_box(bm_para, (pier_x, BASE_Y + 2.35, pz), (pier_w, 4.75, 2.35), bevel=0.05)
            _add_beveled_box(bm_para, (pier_x, BASE_Y + 4.78, pz), (pier_w + 0.28, 0.42, 2.62), bevel=0.04)
            _add_pyramidal_cap(bm_para, (pier_x, BASE_Y + 4.99, pz), pier_w - 0.1, 2.1, 0.45, 1.35)
            _add_beveled_box(bm_para, (sx * 9.55, BASE_Y + 1.4, pz), (0.95, 3.6, 1.25), bevel=0.05)

            _add_beveled_box(bm_para, (sx * 8.40, col_top - col_depth * 0.5, pz), (2.6, col_depth, 2.6), bevel=0.06)
            _add_beveled_box(bm_para, (sx * 9.45, col_top - col_depth * 0.42, pz), (1.35, col_depth * 0.84, 1.50), bevel=0.05)
            _add_beveled_box(bm_para, (sx * 8.40, y_spire_top + 0.45, pz), (3.0, 0.9, 3.0), bevel=0.06)

    for p_idx in (1, 2):
        _add_beveled_box(bm_para, (0.0, PLOT_BRIDGE_BOT_Y - 2.4, PIER_ZS[p_idx]), (16.2, 4.8, 2.2), bevel=0.06)

    # 3 Pointed Gothic Under-Deck Arches & Double Archivolt Ribs centered cleanly between PIER_ZS
    arch_spans = [
        (0.5 * (PIER_ZS[i] + PIER_ZS[i + 1]), 13.4, PIER_ZS[i] + 0.95, PIER_ZS[i + 1] - 0.95)
        for i in range(len(PIER_ZS) - 1)
    ]
    for zc, span_w, zs, ze in arch_spans:
        for sx in (-1.0, 1.0):
            _add_pointed_gothic_arch_spandrel(bm_para, zc, span_w, zs, ze, sx * 8.15, 1.75, -8.8, -1.65, PLOT_BRIDGE_BOT_Y + 0.15, rib_depth=0.28)
        _add_pointed_gothic_arch_spandrel(bm_para, zc, span_w - 0.6, zs, ze, 0.0, 14.6, -6.2, -1.20, PLOT_BRIDGE_BOT_Y + 0.15, rib_depth=0.0)

    objects.append(_finalize_bmesh_object("Hub_PlotBridgeParapets", bm_para, parapet_mat, uv_scale=0.16, roblox_mat="Slate", roblox_rgb=PARAPET_STONE_RGB))

    # 3. Hub_PlotBridgeSpires: Tapered hanging stone crag stalactite spires beneath every pier
    bm_spires = bmesh.new()
    for p_idx, pz in enumerate(PIER_ZS):
        is_inner = (p_idx in (1, 2))
        col_depth = 12.0 if is_inner else 9.4
        y_spire_top = (PLOT_BRIDGE_BOT_Y + 0.2) - col_depth
        spire_drop = 15.5 if is_inner else 10.5
        for s_idx, sx in enumerate((-1.0, 1.0)):
            _add_faceted_hanging_spire(
                bm_spires,
                (sx * 8.45, y_spire_top, pz),
                radius_x=1.55 if is_inner else 1.25,
                radius_z=1.55 if is_inner else 1.25,
                drop_len=spire_drop,
                seed_val=p_idx * 7 + s_idx * 3 + 1,
            )
    for p_idx in (1, 2):
        _add_faceted_hanging_spire(bm_spires, (0.0, PLOT_BRIDGE_BOT_Y - 4.7, PIER_ZS[p_idx]), radius_x=1.6, radius_z=1.3, drop_len=9.5, seed_val=p_idx + 19)

    objects.append(_finalize_bmesh_object("Hub_PlotBridgeSpires", bm_spires, spire_mat, uv_scale=0.14, roblox_mat="Slate", roblox_rgb=SPIRE_ROCK_RGB))

    return objects


def pack_luau_mesh_data(objects):
    shards = []
    manifest_parts = []
    for obj in objects:
        depsgraph = bpy.context.evaluated_depsgraph_get()
        eval_obj = obj.evaluated_get(depsgraph)
        mesh = eval_obj.to_mesh()
        mesh.calc_loop_triangles()

        world_mat = obj.matrix_world
        uv_layer = mesh.uv_layers.active.data if mesh.uv_layers.active else None

        rx_verts = [b2r(*(world_mat @ v.co)) for v in mesh.vertices]
        xs = [p[0] for p in rx_verts]
        ys = [p[1] for p in rx_verts]
        zs = [p[2] for p in rx_verts]
        center = (0.5 * (min(xs) + max(xs)), 0.5 * (min(ys) + max(ys)), 0.5 * (min(zs) + max(zs)))
        size = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))

        norm_map, norms = {}, []
        uv_map, uvs = {}, []

        def intern_norm(nx, ny, nz):
            key = (round(nx, 3), round(ny, 3), round(nz, 3))
            idx = norm_map.get(key)
            if idx is None:
                idx = len(norms) // 3 + 1
                norm_map[key] = idx
                norms.extend(key)
            return idx

        def intern_uv(u, v):
            key = (round(u, 3), round(1.0 - v, 3))
            idx = uv_map.get(key)
            if idx is None:
                idx = len(uvs) // 2 + 1
                uv_map[key] = idx
                uvs.extend(key)
            return idx

        vb = []
        for p in rx_verts:
            vb.extend([round(p[0] - center[0], 3), round(p[1] - center[1], 3), round(p[2] - center[2], 3)])

        tb, ntb, uvtb = [], [], []
        for tri in mesh.loop_triangles:
            tb.extend([vi + 1 for vi in tri.vertices])
            fn_r = b2r(*tri.normal)
            p0, p1, p2 = rx_verts[tri.vertices[0]], rx_verts[tri.vertices[1]], rx_verts[tri.vertices[2]]
            e1 = (p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2])
            e2 = (p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2])
            cr = (e1[1]*e2[2] - e1[2]*e2[1], e1[2]*e2[0] - e1[0]*e2[2], e1[0]*e2[1] - e1[1]*e2[0])
            assert (cr[0]*fn_r[0] + cr[1]*fn_r[1] + cr[2]*fn_r[2]) >= -1e-4, f"Inverted winding in {obj.name}"

            nid = intern_norm(*fn_r)
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

        rmat = str(obj.get("roblox_material", "Cobblestone"))
        rrgb = [int(c) for c in obj.get("roblox_rgb", COBBLE_RGB)]

        shards.append({
            "name": obj.name,
            "part_name": obj.name,
            "material": rmat,
            "color": rrgb,
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
            "material": rmat,
            "colorRGB": rrgb,
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

    mesh_ids_path = os.path.join(FBX_OUT_DIR, "mesh_ids.json")
    mesh_ids = {}
    if os.path.isfile(mesh_ids_path):
        with open(mesh_ids_path, "r", encoding="utf-8") as mf:
            mesh_ids = json.load(mf)
    mesh_id_lines = [f'\t\t["{k}"] = "{v}",' for k, v in sorted(mesh_ids.items())]
    mesh_id_block = "\n".join(mesh_id_lines)

    data_luau = f"""--!strict
-- HubPathMeshData.luau
-- Aggregator for packed Blender cobblestone path & fantasy castle bridge geometry.

local HubPathMeshesFolder = script.Parent:WaitForChild("HubPathMeshes")

export type HubPathShard = {{
\tname: string,
\tpartName: string,
\tmaterial: string,
\tcolor: {{ number }},
\tcenter: {{ number }},
\tsize: {{ number }},
\tvb: {{ number }},
\tnb: {{ number }},
\tub: {{ number }},
\ttb: {{ number }},
\tntb: {{ number }},
\tuvtb: {{ number }},
}}

local shards: {{ HubPathShard }} = require(HubPathMeshesFolder:WaitForChild("hub_cobble_paths")) :: {{ HubPathShard }}

local byPartName: {{ [string]: HubPathShard }} = {{}}
for _, shard in ipairs(shards) do
\tbyPartName[shard.partName] = shard
end

local meshIds: {{ [string]: string }} = {{
{mesh_id_block}
}}

return {{
\tPartCount = #shards,
\tShards = shards,
\tByPartName = byPartName,
\tMeshIds = meshIds,
}}
"""
    with open(LUAU_DATA_PATH, "w", encoding="utf-8", newline="\n") as f:
        f.write(data_luau)

    manifest = {
        "fbx": "assets/models/environment/HubCobblePaths.fbx",
        "uvScaleCobble": 0.25,
        "uvScaleParapetSlate": 0.16,
        "uvScaleSpireSlate": 0.14,
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


def main():
    clear_scene()
    cobble_mat = bpy.data.materials.new("BridgeCobbleMat")
    cobble_mat.diffuse_color = (COBBLE_RGB[0] / 255.0, COBBLE_RGB[1] / 255.0, COBBLE_RGB[2] / 255.0, 1.0)
    parapet_mat = bpy.data.materials.new("GothicParapetSlateMat")
    parapet_mat.diffuse_color = (PARAPET_STONE_RGB[0] / 255.0, PARAPET_STONE_RGB[1] / 255.0, PARAPET_STONE_RGB[2] / 255.0, 1.0)
    spire_mat = bpy.data.materials.new("HangingSpireSlateMat")
    spire_mat.diffuse_color = (SPIRE_ROCK_RGB[0] / 255.0, SPIRE_ROCK_RGB[1] / 255.0, SPIRE_ROCK_RGB[2] / 255.0, 1.0)
    moss_mat = bpy.data.materials.new("BridgeMossMat")
    moss_mat.diffuse_color = (MOSS_RGB[0] / 255.0, MOSS_RGB[1] / 255.0, MOSS_RGB[2] / 255.0, 1.0)

    objects = []
    for slot in PLOT_SLOTS:
        objects.append(build_gate_spoke(slot, cobble_mat))
    objects.append(build_pilgrims_way(cobble_mat))
    objects.append(build_spur_path(cobble_mat))
    objects.append(build_plaza_apron_deck(cobble_mat))
    objects.append(build_overlook_terrace_top(cobble_mat))
    objects.extend(build_plot_bridge_kit(cobble_mat, parapet_mat, spire_mat))

    export_fbx(objects)
    shards, manifest_parts = pack_luau_mesh_data(objects)
    write_luau_files(shards, manifest_parts)

    total_tris = sum(p["triCount"] for p in manifest_parts)
    print(f"[generate_hub_cobble_paths] Exported {len(objects)} meshes, total triangles = {total_tris}")
    for p in manifest_parts:
        print(f"  - {p['name']}: mat={p['material']} rgb={p['colorRGB']} tris={p['triCount']} verts={p['vertCount']} size={p['size']} center={p['center']}")


if __name__ == "__main__":
    main()
