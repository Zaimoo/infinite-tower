"""
=============================================================================
Infinite Tower: Become a Master! - Central tower remodel (grey gothic stone, crimson windows)
Target: Blender 5.x (headless) -> FBX -> Roblox Studio (MeshParts)
=============================================================================
Rebuilds the hub's `CentralCrimsonTower` shell as meshes, styled after the key-art tower: a tall
grey-stone gothic drum, tier upon tier of pointed lancet windows with two-light tracery and an oculus,
glowing crimson glass, a corbelled cornice and a balustraded balcony at the top of every tier, then a
lantern drum, eight pinnacle turrets and a great spire.

Scale is the live tower's (TowerBuilder.Config), 1 Blender metre = 1 stud, origin at the tower's
bottom centre (Roblox (0, 16, 0) in the hub):
  * base drum   0 -> 84,  radius 325, plinth steps 339 / 332, gate porch facing -Z (Roblox)
  * stage 1     84 -> 468     radius 325, 4 tiers of 96
  * stage 2     468 -> 852    radius 301, 4 tiers
  * stage 3     852 -> 1236   radius 277, 4 tiers
  * stage 4     1236 -> 1620  radius 253, 4 tiers
  * crown       1620 -> 1724  lantern drum radius 217, 8 pinnacle turrets at radius 225
  * spire       1724 -> 2144, finial to ~2198 (the SkyBeacon part sits above it)
The entrance opening is 40 wide; the EntrancePortalTrigger part (36 x 46 at Z = -332) sits inside it.

Instancing: the tiers of one stage are identical, so each stage's tier is exported once (at that
stage's first tier) and GothicTowerShell.luau clones it up the stage. Objects carry the stage in their
name (`Tier1` .. `Tier4`).

Output
  assets/models/central_tower/GothicTowerRemodel.fbx       (import into ReplicatedStorage.Assets.TowerMeshes,
                                                             Model named GothicTower)
  assets/models/central_tower/GothicTowerRemodel_manifest.json
  assets-source/tower/gothic_tower/GothicTowerRemodel.blend
  previews (Workbench) into --renders <dir> when given

Coordinates
  Roblox (x, y, z) -> Blender (x, -z, y). Exported like bake_scenery_meshes.py (forward -Z, up Y,
  bake_space_transform), so FBX space is Roblox space. Marker cubes TowerOrigin, TowerAxisX and
  TowerAxisY (10 studs along Roblox +X and +Y) let the game recover the frame however the import lands.

Run
  blender.exe --background --factory-startup --python tools/blender/generate_gothic_tower_remodel.py -- --renders <dir>
=============================================================================
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
FBX_PATH = os.path.join(REPO_ROOT, "assets", "models", "central_tower", "GothicTowerRemodel.fbx")
MANIFEST_PATH = os.path.join(REPO_ROOT, "assets", "models", "central_tower", "GothicTowerRemodel_manifest.json")
BLEND_PATH = os.path.join(REPO_ROOT, "assets-source", "tower", "gothic_tower", "GothicTowerRemodel.blend")

# ---------------------------------------------------------------------------------------------
# Scale (mirrors TowerBuilder.Config)
# ---------------------------------------------------------------------------------------------
BASE_H = 84.0
TIER_H = 96.0
STAGES = [  # (radius, tier count): four gentle setbacks keep the drum slender, like the key art
    (325.0, 4),
    (301.0, 4),
    (277.0, 4),
    (253.0, 4),
]
STACK_TOP = BASE_H + TIER_H * sum(n for _, n in STAGES)  # 1620
LANTERN_R = STAGES[-1][0] - 36.0  # 217
LANTERN_H = 104.0
SPIRE_H = 420.0
TURRET_RING_R = LANTERN_R + 8.0
TURRET_COUNT = 8
BAYS = 20
LATHE_SEGS = 96
MAX_TRIS = 19000  # Roblox caps a MeshPart at 20,000 triangles

PORCH_FRONT = 340.0  # Roblox Z = -340
PORCH_HALF = 34.0
GATE_HALF = 20.0
GATE_SPRING = 46.0

COLORS = {
    "Stone": (0.42, 0.43, 0.46),
    "Trim": (0.58, 0.59, 0.62),
    "Glass": (1.0, 0.13, 0.13),
    "Marker": (0.1, 0.9, 0.3),
}

UP = Vector((0, 0, 1))


# ---------------------------------------------------------------------------------------------
# Mesh accumulation
# ---------------------------------------------------------------------------------------------
class Acc:
    def __init__(self):
        self.verts = []
        self.faces = []

    def face(self, pts, hint):
        pts = [Vector(p) for p in pts]
        # drop consecutive duplicates (degenerate lathe poles)
        clean = []
        for p in pts:
            if not clean or (p - clean[-1]).length > 1e-5:
                clean.append(p)
        if len(clean) > 2 and (clean[0] - clean[-1]).length < 1e-5:
            clean.pop()
        if len(clean) < 3:
            return
        n = Vector((0, 0, 0))
        for i, a in enumerate(clean):
            b = clean[(i + 1) % len(clean)]
            n.x += (a.y - b.y) * (a.z + b.z)
            n.y += (a.z - b.z) * (a.x + b.x)
            n.z += (a.x - b.x) * (a.y + b.y)
        if n.length < 1e-9:
            return
        if hint is not None and n.dot(Vector(hint)) < 0:
            clean.reverse()
        base = len(self.verts)
        self.verts.extend(clean)
        self.faces.append(tuple(range(base, base + len(clean))))

    def extend(self, other):
        base = len(self.verts)
        self.verts.extend(other.verts)
        self.faces.extend(tuple(i + base for i in f) for f in other.faces)


def cp(r, theta, z, cx=0.0, cy=0.0):
    """Cylinder point in Blender space. theta = 0 faces Blender +Y (Roblox -Z, the hub bridge)."""
    return Vector((cx + r * math.sin(theta), cy + r * math.cos(theta), z))


def radial(theta):
    return Vector((math.sin(theta), math.cos(theta), 0))


def cyl_mapper(R, theta_c):
    def m(u, v, d):
        return cp(R + d, theta_c + u / R, v)
    return m


def plane_mapper(origin, right, up, out):
    origin, right, up, out = Vector(origin), Vector(right), Vector(up), Vector(out)

    def m(u, v, d):
        return origin + right * u + up * v + out * d
    return m


def lathe(acc, profile, segs=LATHE_SEGS, cx=0.0, cy=0.0, a0=0.0, a1=2 * math.pi):
    """Revolve (r, z) points, listed bottom-to-top along the outside, so faces point outward."""
    for k in range(segs):
        t0 = a0 + (a1 - a0) * k / segs
        t1 = a0 + (a1 - a0) * (k + 1) / segs
        tm = (t0 + t1) * 0.5
        for (r0, z0), (r1, z1) in zip(profile, profile[1:]):
            dr, dz = r1 - r0, z1 - z0
            hint = radial(tm) * dz + UP * (-dr)
            acc.face([cp(r0, t0, z0, cx, cy), cp(r0, t1, z0, cx, cy), cp(r1, t1, z1, cx, cy), cp(r1, t0, z1, cx, cy)], hint)


def prism_u(acc, m, u0, u1, profile_vd, caps=(True, True)):
    """Extrude a convex (v, d) profile from u0 to u1 through mapper m."""
    vc = sum(p[0] for p in profile_vd) / len(profile_vd)
    dc = sum(p[1] for p in profile_vd) / len(profile_vd)
    um = (u0 + u1) * 0.5
    n = len(profile_vd)
    for i in range(n):
        (va, da), (vb, db) = profile_vd[i], profile_vd[(i + 1) % n]
        mid = m(um, (va + vb) * 0.5, (da + db) * 0.5)
        acc.face([m(u0, va, da), m(u1, va, da), m(u1, vb, db), m(u0, vb, db)], mid - m(um, vc, dc))
    if caps[0]:
        acc.face([m(u0, v, d) for v, d in profile_vd], m(u0, vc, dc) - m(u1, vc, dc))
    if caps[1]:
        acc.face([m(u1, v, d) for v, d in profile_vd], m(u1, vc, dc) - m(u0, vc, dc))


def wbox(acc, m, u0, u1, v0, v1, d0, d1, back=False):
    prism_u(acc, m, u0, u1, [(v0, d0), (v0, d1), (v1, d1), (v1, d0)] if back else [(v0, d0), (v0, d1), (v1, d1), (v1, d0)])


def band(acc, m, pts, hw, d_front, d_back, closed=False):
    """A tracery bar / moulding along a (u, v) polyline: front face plus both sides."""
    n = len(pts)
    lefts, rights = [], []
    for i in range(n):
        if closed:
            a, b = pts[(i - 1) % n], pts[(i + 1) % n]
        else:
            a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, ty) or 1.0
        nx, ny = -ty / ln, tx / ln
        lefts.append((pts[i][0] + nx * hw, pts[i][1] + ny * hw))
        rights.append((pts[i][0] - nx * hw, pts[i][1] - ny * hw))
    count = n if closed else n - 1
    for i in range(count):
        j = (i + 1) % n
        p_mid = m((pts[i][0] + pts[j][0]) * 0.5, (pts[i][1] + pts[j][1]) * 0.5, d_front)
        out = m(pts[i][0], pts[i][1], d_front + 1) - m(pts[i][0], pts[i][1], d_front)
        acc.face([m(*lefts[i], d_front), m(*rights[i], d_front), m(*rights[j], d_front), m(*lefts[j], d_front)], out)
        for side in (lefts, rights):
            s_mid = m((side[i][0] + side[j][0]) * 0.5, (side[i][1] + side[j][1]) * 0.5, d_front)
            acc.face([m(*side[i], d_front), m(*side[j], d_front), m(*side[j], d_back), m(*side[i], d_back)], s_mid - p_mid)


# ---------------------------------------------------------------------------------------------
# Gothic window geometry in a wall's (u, v) plane
# ---------------------------------------------------------------------------------------------
def arch_outline(w, ys, yk, rho, arc_steps=7, jamb_steps=3, sill_steps=2):
    """Pointed arch opening, counter-clockwise from the bottom-left corner."""
    cx = w - rho  # right arc centre u (left arc centre is -cx)
    phi_apex = math.acos(max(-1.0, min(1.0, -cx / rho)))
    pts = []
    for i in range(sill_steps * 2):
        pts.append((-w + 2 * w * i / (sill_steps * 2), ys))
    for i in range(jamb_steps):
        pts.append((w, ys + (yk - ys) * i / jamb_steps))
    for i in range(arc_steps):
        phi = phi_apex * i / arc_steps
        pts.append((cx + rho * math.cos(phi), yk + rho * math.sin(phi)))
    apex_v = yk + rho * math.sin(phi_apex)
    pts.append((0.0, apex_v))
    for i in range(arc_steps - 1, -1, -1):
        phi = phi_apex * i / arc_steps
        pts.append((-(cx + rho * math.cos(phi)), yk + rho * math.sin(phi)))
    for i in range(1, jamb_steps):
        pts.append((-w, yk - (yk - ys) * i / jamb_steps))
    return pts, apex_v


def arch_curve(cu, w, yk, rho, steps=6, extend_down=0.0):
    """Open polyline over a pointed arch head: left springing -> apex -> right springing."""
    cx = w - rho
    phi_apex = math.acos(max(-1.0, min(1.0, -cx / rho)))
    pts = []
    if extend_down > 0:
        pts.append((cu - w, yk - extend_down))
    for i in range(steps + 1):
        phi = phi_apex * i / steps
        pts.append((cu - (cx + rho * math.cos(phi)), yk + rho * math.sin(phi)))
    for i in range(1, steps + 1):
        phi = phi_apex * (steps - i) / steps
        pts.append((cu + cx + rho * math.cos(phi), yk + rho * math.sin(phi)))
    if extend_down > 0:
        pts.append((cu + w, yk - extend_down))
    # remove the duplicated apex
    out = []
    for p in pts:
        if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > 1e-6:
            out.append(p)
    return out, yk + rho * math.sin(phi_apex)


def ray_hit(c, ang, poly):
    dx, dy = math.cos(ang), math.sin(ang)
    best = None
    n = len(poly)
    for i in range(n):
        px, py = poly[i]
        qx, qy = poly[(i + 1) % n]
        ex, ey = qx - px, qy - py
        den = dx * ey - dy * ex
        if abs(den) < 1e-12:
            continue
        t = ((px - c[0]) * ey - (py - c[1]) * ex) / den
        s = ((px - c[0]) * dy - (py - c[1]) * dx) / den
        if t > 1e-9 and -1e-9 <= s <= 1 + 1e-9 and (best is None or t < best):
            best = t
    if best is None:
        raise RuntimeError("ray missed polygon")
    return (c[0] + dx * best, c[1] + dy * best)


def window_wall(stone, glass, m, half_u, v0, v1, opening, depth, centre, extra_u=4):
    """Wall panel (u in [-half_u, half_u], v in [v0, v1]) with a pointed opening, its reveal and
    a glass pane at the back. Returns the opening's inner point loop."""
    rect = [(-half_u, v0), (half_u, v0), (half_u, v1), (-half_u, v1)]
    angs = set()
    for p in opening:
        angs.add(round(math.atan2(p[1] - centre[1], p[0] - centre[0]), 9))
    for p in rect:
        angs.add(round(math.atan2(p[1] - centre[1], p[0] - centre[0]), 9))
    for i in range(1, extra_u):
        u = -half_u + 2 * half_u * i / extra_u
        for v in (v0, v1):
            angs.add(round(math.atan2(v - centre[1], u - centre[0]), 9))
    angs = sorted(angs)
    inner = [ray_hit(centre, a, opening) for a in angs]
    outer = [ray_hit(centre, a, rect) for a in angs]
    n = len(angs)
    for i in range(n):
        j = (i + 1) % n
        out = m(0, centre[1], 1) - m(0, centre[1], 0)
        stone.face([m(*outer[i], 0), m(*outer[j], 0), m(*inner[j], 0), m(*inner[i], 0)], out)
        mid = ((inner[i][0] + inner[j][0]) * 0.5, (inner[i][1] + inner[j][1]) * 0.5)
        stone.face([m(*inner[i], 0), m(*inner[j], 0), m(*inner[j], -depth), m(*inner[i], -depth)],
                   m(*centre, -depth * 0.5) - m(*mid, -depth * 0.5))
    glass.face([m(u, v, -depth) for u, v in inner], m(*centre, 1) - m(*centre, 0))
    return inner


def gothic_window(stone, trim, glass, m, half_u, v0, v1, w, ys, yk, rho, depth, tracery=True, hood=True):
    opening, apex = arch_outline(w, ys, yk, rho)
    centre = (0.0, (ys + apex) * 0.5)
    window_wall(stone, glass, m, half_u, v0, v1, opening, depth, centre)
    if tracery:
        df, db = -depth * 0.3, -depth * 0.8
        bar = max(0.9, w * 0.07)
        sub_w = w * 0.5
        sub_spring = yk + (apex - yk) * 0.05
        sub_rho = sub_w * 1.7
        for cu in (-sub_w, sub_w):
            curve, sub_apex = arch_curve(cu, sub_w, sub_spring, sub_rho, steps=4)
            band(trim, m, curve, bar * 0.8, df, db)
        band(trim, m, [(0.0, ys), (0.0, sub_spring)], bar, df, db)
        sub_apex = sub_spring + sub_rho * math.sin(math.acos(max(-1.0, min(1.0, -(sub_w - sub_rho) / sub_rho))))
        oc_r = min(w * 0.42, (apex - sub_apex) * 0.42)
        oc_v = sub_apex + oc_r + bar * 0.6
        circle = [(oc_r * math.cos(2 * math.pi * i / 12), oc_v + oc_r * math.sin(2 * math.pi * i / 12)) for i in range(12)]
        band(trim, m, circle, bar * 0.75, df, db, closed=True)
        # struts from the sub-arch apexes up into the oculus
        band(trim, m, [(0.0, sub_spring), (0.0, oc_v - oc_r)], bar * 0.7, df, db)
    if hood:
        hood_curve, _ = arch_curve(0.0, w + 2.2, yk, rho + 2.2, steps=7)
        hood_curve = [(hood_curve[0][0] - 3.0, yk)] + hood_curve + [(hood_curve[-1][0] + 3.0, yk)]
        band(trim, m, hood_curve, 1.1, 1.8, -0.2)
    return apex


# ---------------------------------------------------------------------------------------------
# Tier (one window storey with cornice, corbel table and balustraded balcony)
# ---------------------------------------------------------------------------------------------
def build_ring_wall(stone, trim, glass, R, y0, wall_v0, wall_v1, bays, window, skip_bays=(), pilaster=True,
                    buttress=None, glow_markers=None, glow_bays=()):
    bay_angle = 2 * math.pi / bays
    half_u = R * bay_angle * 0.5
    for b in range(bays):
        theta = b * bay_angle
        m = cyl_mapper(R, theta)
        if b in skip_bays:
            # plain wall panel, in strips so it follows the curve
            steps = 6
            for k in range(steps):
                ua = -half_u + 2 * half_u * k / steps
                ub = -half_u + 2 * half_u * (k + 1) / steps
                stone.face([m(ua, wall_v0, 0), m(ub, wall_v0, 0), m(ub, wall_v1, 0), m(ua, wall_v1, 0)], radial(theta))
        else:
            w, ys, yk, rho, depth = window
            apex = gothic_window(stone, trim, glass, m, half_u, wall_v0, wall_v1, w, ys, yk, rho, depth)
            if glow_markers is not None and b in glow_bays:
                glow_markers.append(m(0.0, (ys + apex) * 0.5, -depth + 2.0))
        mj = cyl_mapper(R, theta + bay_angle * 0.5)
        if buttress:
            bw, bd, btop = buttress
            prism_u(stone, mj, -bw / 2, bw / 2,
                    [(wall_v0 - 6, -1), (wall_v0 - 6, bd), (btop - bd * 1.4, bd), (btop, 1.0), (btop, -1)])
        elif pilaster:
            prism_u(stone, mj, -5.0, 5.0, [(wall_v0, -0.5), (wall_v0, 4.0), (wall_v1 - 4.5, 4.0), (wall_v1 - 4.5, -0.5)])
            prism_u(trim, mj, -6.4, 6.4, [(wall_v1 - 4.5, -0.5), (wall_v1 - 4.5, 4.0), (wall_v1 - 2.0, 5.6), (wall_v1, 5.6), (wall_v1, -0.5)])


def corbel_table(trim, R, v_bottom, v_top, count, protrude):
    for i in range(count):
        theta = (i + 0.5) * 2 * math.pi / count
        m = cyl_mapper(R, theta)
        prism_u(trim, m, -1.6, 1.6, [(v_bottom, -0.3), (v_bottom + 1.5, protrude * 0.45), (v_top, protrude), (v_top, -0.3)])


def balustrade(trim, R_out, y, post_spacing=11.0, height=8.0):
    lathe(trim, [(R_out, y), (R_out, y + 1.6), (R_out - 2.6, y + 1.6), (R_out - 2.6, y)])
    lathe(trim, [(R_out + 0.4, y + height - 1.6), (R_out + 0.4, y + height), (R_out - 3.0, y + height),
                 (R_out - 3.0, y + height - 1.6), (R_out + 0.4, y + height - 1.6)])
    count = int(2 * math.pi * R_out / post_spacing)
    for i in range(count):
        theta = i * 2 * math.pi / count
        m = cyl_mapper(R_out - 1.3, theta)
        prism_u(trim, m, -0.75, 0.75, [(y + 1.6, -0.75), (y + 1.6, 0.75), (y + height - 1.6, 0.75), (y + height - 1.6, -0.75)])


def build_tier(R, y0, glow_markers):
    stone, trim, glass = Acc(), Acc(), Acc()
    H = TIER_H
    overhang = 11.0
    # plinth course
    lathe(stone, [(R - 1, y0), (R + 2.2, y0), (R + 2.2, y0 + 3.0), (R + 1.0, y0 + 4.6), (R, y0 + 5.2)])
    # walls with tall windows: 38 wide, sill 9, spring 46, apex ~ 79 (hood mould to ~ 82.5)
    build_ring_wall(stone, trim, glass, R, y0, y0 + 5.2, y0 + H - 8.0, BAYS,
                    (19.0, y0 + 9.0, y0 + 46.0, 38.0, 7.0),
                    glow_markers=glow_markers, glow_bays=(0, 10))
    # corbel table and cornice
    corbel_table(trim, R, y0 + H - 12.5, y0 + H - 8.0, BAYS * 3, 5.0)
    lathe(stone, [(R, y0 + H - 8.0), (R + 5.5, y0 + H - 8.0), (R + 5.5, y0 + H - 6.4), (R + overhang - 1.5, y0 + H - 3.6),
                  (R + overhang, y0 + H - 2.6), (R + overhang, y0 + H), (0.0, y0 + H)])
    balustrade(trim, R + overhang - 0.5, y0 + H)
    return stone, trim, glass


def build_base(glow_markers):
    stone, trim, glass, porch = Acc(), Acc(), Acc(), Acc()
    R = STAGES[0][0]
    # stepped foundation plinth (678 / 664 diameters of the part tower)
    lathe(stone, [(339.0, 0.0), (339.0, 10.0), (332.0, 10.0), (332.0, 22.0), (R, 22.0)])
    build_ring_wall(stone, trim, glass, R, 0.0, 22.0, 77.0, BAYS, (13.0, 27.0, 46.0, 26.0, 6.0),
                    skip_bays=(0,), buttress=(12.0, 8.0, 70.0), glow_markers=glow_markers, glow_bays=(5, 10, 15))
    corbel_table(trim, R, 72.0, 77.0, BAYS * 3, 4.0)
    lathe(stone, [(R, 77.0), (R + 4.0, 77.0), (R + 4.0, 78.5), (R + 8.0, 81.5), (R + 8.0, BASE_H), (R - 2.0, BASE_H)])
    build_porch(porch, trim, glass)
    return stone, trim, glass, porch


def build_porch(porch, trim, glass):
    back = 316.0
    top = 96.0
    gable = 128.0
    front = plane_mapper((0, PORCH_FRONT, 0), (1, 0, 0), (0, 0, 1), (0, 1, 0))
    opening, apex = arch_outline(GATE_HALF, 0.0, GATE_SPRING, 36.0, arc_steps=9, jamb_steps=4, sill_steps=3)
    window_wall(porch, glass, front, PORCH_HALF, 0.0, top, opening, PORCH_FRONT - 326.0, (0.0, (GATE_SPRING + apex) * 0.5 - 8.0),
                extra_u=2)
    # sides and flat top
    for sx in (-1, 1):
        porch.face([(sx * PORCH_HALF, back, 0), (sx * PORCH_HALF, PORCH_FRONT, 0), (sx * PORCH_HALF, PORCH_FRONT, top),
                    (sx * PORCH_HALF, back, top)], (sx, 0, 0))
    # gable end and roof
    porch.face([(-PORCH_HALF, PORCH_FRONT, top), (PORCH_HALF, PORCH_FRONT, top), (0, PORCH_FRONT, gable)], (0, 1, 0))
    for sx in (-1, 1):
        porch.face([(sx * (PORCH_HALF + 2), PORCH_FRONT + 2, top - 1.5), (0, PORCH_FRONT + 2, gable + 2.0),
                    (0, back, gable + 2.0), (sx * (PORCH_HALF + 2), back, top - 1.5)], (sx * 0.7, 0, 0.7))
        porch.face([(sx * (PORCH_HALF + 2), PORCH_FRONT + 2, top - 1.5), (0, PORCH_FRONT + 2, gable + 2.0),
                    (0, PORCH_FRONT, gable), (sx * PORCH_HALF, PORCH_FRONT, top)], (0, 1, 0))
    # hood mould over the gate, a cornice and an oculus in the gable
    hood_curve, _ = arch_curve(0.0, GATE_HALF + 3.0, GATE_SPRING, 39.0, steps=9)
    hood_curve = [(hood_curve[0][0] - 4.0, GATE_SPRING)] + hood_curve + [(hood_curve[-1][0] + 4.0, GATE_SPRING)]
    band(trim, front, hood_curve, 1.6, 2.6, -0.2)
    band(trim, front, [(-PORCH_HALF - 1, top - 2.0), (PORCH_HALF + 1, top - 2.0)], 2.0, 2.4, -0.2)
    ring = [(9.0 * math.cos(2 * math.pi * i / 16), 110.0 + 9.0 * math.sin(2 * math.pi * i / 16)) for i in range(16)]
    band(trim, front, ring, 1.4, 1.8, -0.2, closed=True)
    glass.face([front(u * 0.85, 110.0 + (v - 110.0) * 0.85, 0.3) for u, v in ring], (0, 1, 0))
    # flanking pinnacle buttresses
    for sx in (-1, 1):
        cx = sx * (PORCH_HALF + 5.0)
        side = plane_mapper((cx, 0, 0), (1, 0, 0), (0, 0, 1), (0, 1, 0))
        prism_u(porch, side, -5.0, 5.0, [(0.0, back + 4), (0.0, PORCH_FRONT + 4), (88.0, PORCH_FRONT + 4), (104.0, PORCH_FRONT - 4),
                                          (104.0, back + 4)])
        # pyramid cap
        cy = (PORCH_FRONT + back + 8) * 0.5 - 4
        lathe(porch, [(7.5, 104.0), (7.5, 108.0), (0.0, 138.0)], segs=4, cx=cx, cy=cy, a0=math.pi / 4, a1=math.pi / 4 + 2 * math.pi)
        lathe(trim, [(1.6, 138.0), (0.0, 150.0)], segs=6, cx=cx, cy=cy)


def build_crown(glow_markers):
    stone, trim, glass = Acc(), Acc(), Acc()
    y0 = STACK_TOP
    R = LANTERN_R
    top = y0 + LANTERN_H
    lathe(stone, [(R - 1, y0), (R + 2.5, y0), (R + 2.5, y0 + 4.0), (R, y0 + 5.0)])
    build_ring_wall(stone, trim, glass, R, y0, y0 + 5.0, top - 10.0, 16, (13.0, y0 + 14.0, y0 + 62.0, 26.0, 5.0),
                    glow_markers=glow_markers, glow_bays=(0, 4, 8, 12))
    corbel_table(trim, R, top - 16.0, top - 10.0, 16 * 4, 4.5)
    lathe(stone, [(R, top - 10.0), (R + 5.0, top - 10.0), (R + 5.0, top - 8.0), (R + 9.0, top - 4.0), (R + 9.0, top), (0.0, top)])
    balustrade(trim, R + 8.5, top)

    # great spire: concave 16-sided cone with banding, tipped with a finial
    spire_r = R - 8.0
    prof = []
    steps = 14
    for i in range(steps + 1):
        t = i / steps
        prof.append((spire_r * (1 - t) ** 1.25 if i < steps else 0.0, top + SPIRE_H * t))
    lathe(stone, prof, segs=16, a0=math.pi / 16, a1=math.pi / 16 + 2 * math.pi)
    for t in (0.16, 0.36, 0.56, 0.74, 0.88):
        r = spire_r * (1 - t) ** 1.25
        y = top + SPIRE_H * t
        lathe(trim, [(r - 1, y - 2.5), (r + 3.0, y - 2.5), (r + 3.0, y + 2.5), (r - 1, y + 2.5)], segs=16,
              a0=math.pi / 16, a1=math.pi / 16 + 2 * math.pi)
    tip = top + SPIRE_H
    lathe(trim, [(0.0, tip - 6.0), (4.5, tip - 2.0), (4.5, tip + 4.0), (2.0, tip + 6.0), (2.0, tip + 16.0), (6.0, tip + 20.0),
                 (6.0, tip + 26.0), (1.5, tip + 30.0), (0.0, tip + 54.0)], segs=12)

    # lucarnes: gabled dormers with crimson lancets on the spire's lower slope
    for k in range(4):
        theta = k * math.pi / 2
        rr = spire_r * (1 - 6.0 / SPIRE_H) ** 1.25 - 4.0
        o = cp(rr, theta, top + 6.0)
        rgt = Vector((math.cos(theta), -math.sin(theta), 0))
        out = radial(theta)
        m = plane_mapper(o, rgt, UP, out)
        prism_u(stone, m, -14.0, 14.0, [(0.0, -30.0), (0.0, 6.0), (34.0, 6.0), (34.0, -30.0)])
        dm = plane_mapper(o + out * 6.0, rgt, UP, out)
        for sx in (-1, 1):
            stone.face([dm(sx * 16.0, 32.0, 0.6), dm(0.0, 54.0, 0.6), dm(0.0, 54.0, -36.0), dm(sx * 16.0, 32.0, -36.0)],
                       out * 0.3 + rgt * sx + UP)
        stone.face([dm(-14.0, 34.0, 0.0), dm(14.0, 34.0, 0.0), dm(0.0, 52.0, 0.0)], out)
        lancet, _ = arch_outline(5.0, 6.0, 22.0, 10.0, arc_steps=5, jamb_steps=1, sill_steps=1)
        glass.face([dm(u, v, 0.2) for u, v in lancet], out)
        band(trim, dm, arch_curve(0.0, 7.0, 22.0, 12.0, steps=5, extend_down=16.0)[0], 1.0, 1.4, -0.2)

    # pinnacle turrets around the lantern, each with crimson slits and a spire
    t_r = 17.0
    t_top = y0 + LANTERN_H + 34.0
    for k in range(TURRET_COUNT):
        theta = (k + 0.5) * 2 * math.pi / TURRET_COUNT
        c = cp(TURRET_RING_R, theta, 0.0)
        lathe(stone, [(t_r + 2.0, y0), (t_r + 2.0, y0 + 4.0), (t_r, y0 + 5.0), (t_r, t_top - 6.0)], segs=16, cx=c.x, cy=c.y)
        lathe(trim, [(t_r, t_top - 6.0), (t_r + 3.0, t_top - 6.0), (t_r + 3.0, t_top), (t_r - 1.0, t_top)], segs=16, cx=c.x, cy=c.y)
        lathe(stone, [(t_r + 1.5, t_top), (t_r * 0.55, t_top + 50.0), (0.0, t_top + 84.0)], segs=16, cx=c.x, cy=c.y)
        lathe(trim, [(0.0, t_top + 82.0), (1.4, t_top + 84.0), (0.0, t_top + 106.0)], segs=6, cx=c.x, cy=c.y)
        lathe(trim, [(t_r - 0.5, y0 + 46.0), (t_r + 2.0, y0 + 46.0), (t_r + 2.0, y0 + 49.0), (t_r - 0.5, y0 + 49.0)], segs=16,
              cx=c.x, cy=c.y)
        # four slit windows, facing outward and to the sides
        for s in range(4):
            phi = theta + s * math.pi / 2
            sm = plane_mapper(cp(t_r + 0.15, phi, 0.0, c.x, c.y), (math.cos(phi), -math.sin(phi), 0), UP, radial(phi))
            slit, _ = arch_outline(2.2, y0 + 60.0, y0 + 84.0, 4.4, arc_steps=3, jamb_steps=1, sill_steps=1)
            glass.face([sm(u, v, 0.0) for u, v in slit], radial(phi))
    return stone, trim, glass


# ---------------------------------------------------------------------------------------------
# Blender objects
# ---------------------------------------------------------------------------------------------
def material(name):
    mat = bpy.data.materials.get("M_" + name)
    if mat:
        return mat
    mat = bpy.data.materials.new("M_" + name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    col = COLORS[name]
    bsdf.inputs["Base Color"].default_value = (*col, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    if name == "Glass":
        bsdf.inputs["Emission Color"].default_value = (*col, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    mat.diffuse_color = (*col, 1.0)
    return mat


def make_object(name, acc, mat_name, collection):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in acc.verts], [], acc.faces)
    mesh.validate(clean_customdata=False)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material(mat_name))
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    try:
        mesh.set_sharp_from_angle(angle=math.radians(35))
    except Exception:
        pass
    # origin at the bounding-box centre, like the Roblox importer
    bb = [Vector(c) for c in obj.bound_box]
    centre = sum(bb, Vector()) / 8
    mesh.transform(__import__("mathutils").Matrix.Translation(-centre))
    obj.location = centre
    return obj


def split_acc(acc, parts):
    """Split faces into angular sectors around the tower axis."""
    out = [Acc() for _ in range(parts)]
    for f in acc.faces:
        pts = [acc.verts[i] for i in f]
        c = sum(pts, Vector()) / len(pts)
        a = (math.atan2(c.x, c.y) + 2 * math.pi) % (2 * math.pi)
        k = min(parts - 1, int(a / (2 * math.pi) * parts))
        base = len(out[k].verts)
        out[k].verts.extend(pts)
        out[k].faces.append(tuple(range(base, base + len(pts))))
    return out


def tri_count(acc):
    return sum(len(f) - 2 for f in acc.faces)


def emit(name, acc, mat_name, collection, report):
    tris = tri_count(acc)
    if tris == 0:
        return []
    parts = 1
    while tris / parts > MAX_TRIS:
        parts += 1
    pieces = [acc] if parts == 1 else split_acc(acc, parts)
    objs = []
    for i, piece in enumerate(pieces):
        nm = name if parts == 1 else f"{name}_{chr(65 + i)}"
        obj = make_object(nm, piece, mat_name, collection)
        n = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        report[nm] = {"Material": mat_name, "Triangles": n}
        objs.append(obj)
    return objs


def marker(name, pos_blender, collection, size=1.0):
    acc = Acc()
    h = size / 2
    x, y, z = pos_blender
    c = [Vector((x + sx * h, y + sy * h, z + sz * h)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    for axis in range(3):
        for sgn in (-1, 1):
            quad = [p for p in c if (p[axis] - pos_blender[axis]) * sgn > 0]
            others = [i for i in range(3) if i != axis]
            centre = Vector(pos_blender)
            quad.sort(key=lambda p: math.atan2(p[others[1]] - centre[others[1]], p[others[0]] - centre[others[0]]))
            hint = Vector((0, 0, 0))
            hint[axis] = sgn
            acc.face(quad, hint)
    return make_object(name, acc, "Marker", collection)


def rbx_to_blender(x, y, z):
    return (x, -z, y)


# ---------------------------------------------------------------------------------------------
# Previews
# ---------------------------------------------------------------------------------------------
def look_at(cam, target):
    d = Vector(target) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def render_previews(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_WORKBENCH"
    except TypeError:
        pass
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.show_shadows = True
    scene.display.shadow_focus = 0.0
    shading.background_type = "VIEWPORT"
    shading.background_color = (0.06, 0.07, 0.09)
    world = bpy.data.worlds.new("Preview") if not scene.world else scene.world
    scene.world = world
    world.color = (0.06, 0.07, 0.09)
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 1400
    for o in bpy.data.objects:
        if o.name.startswith(("Tower", "VFX_")):
            o.hide_render = True
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.clip_end = 20000
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    shots = {
        "tower_full": ((1700, 3400, 700), (0, 0, 1080), 30),
        "tower_reference_angle": ((560, 860, 140), (-60, 0, 900), 22),
        "tower_tiers_close": ((330, 560, 330), (120, 230, 430), 40),
        "tower_gate": ((90, 470, 30), (0, 330, 55), 35),
        "tower_crown": ((420, 760, 1680), (0, 0, 1840), 38),
    }
    for name, (loc, target, lens) in shots.items():
        cam.location = Vector(loc)
        look_at(cam, target)
        cam_data.lens = lens
        scene.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
        print("rendered", scene.render.filepath)


# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------
def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    renders = None
    if "--renders" in argv:
        renders = argv[argv.index("--renders") + 1]

    bpy.ops.wm.read_factory_settings(use_empty=True)
    col = bpy.data.collections.new("GothicTower")
    bpy.context.scene.collection.children.link(col)
    report = {}

    glow = []
    stone, trim, glass, porch = build_base(glow)
    emit("GT_Base_Stone", stone, "Stone", col, report)
    emit("GT_Base_Trim", trim, "Trim", col, report)
    emit("GT_Base_Glass", glass, "Glass", col, report)
    emit("GT_Porch_Stone", porch, "Stone", col, report)
    markers = {"Base": glow}

    y = BASE_H
    tiers = []
    for idx, (R, count) in enumerate(STAGES, start=1):
        glow = []
        stone, trim, glass = build_tier(R, y, glow)
        emit(f"GT_Tier{idx}_Stone", stone, "Stone", col, report)
        emit(f"GT_Tier{idx}_Trim", trim, "Trim", col, report)
        emit(f"GT_Tier{idx}_Glass", glass, "Glass", col, report)
        markers[f"Tier{idx}"] = glow
        tiers.append({"Stage": idx, "Radius": R, "FirstTierY": y, "Count": count, "Step": TIER_H})
        y += TIER_H * count

    glow = []
    stone, trim, glass = build_crown(glow)
    emit("GT_Crown_Stone", stone, "Stone", col, report)
    emit("GT_Crown_Trim", trim, "Trim", col, report)
    emit("GT_Crown_Glass", glass, "Glass", col, report)
    markers["Crown"] = glow

    for group, points in markers.items():
        for i, p in enumerate(points, start=1):
            marker(f"VFX_Window_Glow_{group}_{i:02d}", p, col)
    marker("TowerOrigin", rbx_to_blender(0, 0, 0), col)
    marker("TowerAxisX", rbx_to_blender(10, 0, 0), col)
    marker("TowerAxisY", rbx_to_blender(0, 10, 0), col)

    total_unique = sum(r["Triangles"] for r in report.values())
    rendered = total_unique
    for t in tiers:
        per = sum(r["Triangles"] for k, r in report.items() if k.startswith(f"GT_Tier{t['Stage']}_"))
        rendered += per * (t["Count"] - 1)
    print(f"[GothicTower] unique triangles {total_unique}, rendered with tier instancing {rendered}")
    for k, r in sorted(report.items()):
        print(f"  {k:24s} {r['Material']:6s} {r['Triangles']:6d}")

    os.makedirs(os.path.dirname(FBX_PATH), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in col.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = col.objects[0]
    bpy.ops.export_scene.fbx(
        filepath=FBX_PATH,
        use_selection=True,
        object_types={"MESH"},
        use_mesh_modifiers=False,
        mesh_smooth_type="OFF",
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=True,
        add_leaf_bones=False,
    )
    with open(MANIFEST_PATH, "w", encoding="utf-8") as fh:
        json.dump({
            "Fbx": os.path.relpath(FBX_PATH, REPO_ROOT).replace("\\", "/"),
            "Meshes": report,
            "Tiers": tiers,
            "UniqueTriangles": total_unique,
            "RenderedTriangles": rendered,
            "Height": STACK_TOP + LANTERN_H + SPIRE_H + 54.0,
        }, fh, indent=2)
    os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)

    if renders:
        # preview the whole stack: clone the instanced tiers up their stages
        for t in tiers:
            for k in range(1, t["Count"]):
                for o in list(col.objects):
                    if o.name.startswith(f"GT_Tier{t['Stage']}_"):
                        dup = o.copy()
                        dup.location.z += t["Step"] * k
                        col.objects.link(dup)
        render_previews(renders)


main()
