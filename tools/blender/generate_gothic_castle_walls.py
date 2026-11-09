"""
=============================================================================
Infinite Towers: Become a Master! - 3D Environment Pipeline
Asset Kit: Gothic Medieval Fortification Walls & Spire Corner Towers
Plan: gothic_castle_walls_spire_towers_implementation_plan.md (Stage 1)
Target: Blender 4.x / 5.x -> FBX -> Roblox Studio (MeshParts)
=============================================================================
Procedurally builds the 4 modular fortification kit pieces, each in its own
collection, with a root Empty at the module origin (bottom-center):

  1. Wall_Gothic_Straight      24W x 22H x 6D   (tiles seamlessly along X)
  2. Wall_Gothic_GateArch      32W x 24H x 8D   (14W x 15H walk-through arch,
                                                 hinged doors, portcullis,
                                                 crest shield, optional stairs)
  3. Tower_Gothic_CornerSpire  20W x 68H x 20D  (stepped base, rampart chamber
                                                 with 4 doorways at Y=18,
                                                 lancet Y-tracery windows,
                                                 machicolation crown, octagonal
                                                 spire + 4 corner pinnacles)
  4. Prop_Wall_Banner_And_Torch                 (heraldic banner + iron sconce)

Coordinate convention (all geometry is authored in ROBLOX space):
  - 1 Blender unit = 1 Roblox stud.
  - Roblox X = right, Y = up, Z = depth. -Z is the courtyard / interior face of
    walls (that is where sockets, banners and torches live).
  - Roblox (x, y, z) -> Blender (x, -z, y). Exported with Blender's default
    FBX axes (forward -Z, up Y) so FBX coordinates == Roblox coordinates.

Roblox MeshParts carry ONE material each, so every module is split into one
mesh object per material, named  <Module>_<Hull|Detail|Part>_<MaterialKey>.
  - "Hull"   objects: structural, CanCollide = true (except Mortar/Glow).
  - "Detail" objects: trim/tracery/voussoirs, CanCollide = false.
A socket + material + collision manifest is written next to the FBX files:
  assets/fbx/gothic_walls/gothic_walls_manifest.json

Run inside Blender (Blender MCP or Text Editor):
  exec(open(r"C:/WORK/infinite-tower/tools/blender/generate_gothic_castle_walls.py").read(),
       {"__name__": "__main__"})
=============================================================================
"""

import json
import math
import os
from contextlib import contextmanager

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO_ROOT = r"C:\WORK\infinite-tower"
EXPORT_DIR = os.path.join(REPO_ROOT, "assets", "fbx", "gothic_walls")

# "BOX" = world-scale cube projection (seamless tiling of stone textures across
# modules, 1 UV tile per UV_TILE_STUDS). "SMART" = bpy Smart UV Project.
UV_MODE = "BOX"
UV_TILE_STUDS = 8.0
SMOOTH_ANGLE_DEG = 35.0
ARCH_SEGS = 6
BUILD_PREVIEW = True

TRI_BUDGETS = {
    "Wall_Gothic_Straight": 1800,
    "Wall_Gothic_GateArch": 2400,
    "Tower_Gothic_CornerSpire": 3800,
}

# key, Blender material name, hex, roughness, metallic, emission strength,
# Roblox material, Roblox transparency
MATERIAL_SPECS = [
    ("Stone", "M_DarkAshlarStone", "#3B4048", 0.85, 0.05, 0.0, "Slate", 0.0),
    ("CapStone", "M_WeatheredCapStone", "#4E555F", 0.80, 0.08, 0.0, "Rock", 0.0),
    ("Mortar", "M_DeepMortarRecess", "#1E2228", 0.95, 0.00, 0.0, "Slate", 0.0),
    ("SpireRoof", "M_SpireSlateRoof", "#232730", 0.70, 0.15, 0.0, "Slate", 0.0),
    ("Timber", "M_DarkGateTimber", "#3A2618", 0.85, 0.00, 0.0, "WoodPlanks", 0.0),
    ("Iron", "M_WroughtIron", "#181A1E", 0.55, 0.80, 0.0, "Metal", 0.0),
    ("Crimson", "M_CrimsonBanner", "#7F1D1D", 0.90, 0.00, 0.0, "Fabric", 0.0),
    ("Gold", "M_BannerGoldTrim", "#D97706", 0.35, 0.85, 0.0, "Metal", 0.0),
    ("Glow", "M_WindowEmberGlow", "#FF7A1A", 0.00, 0.00, 4.5, "Neon", 0.15),
]
STONE, CAP, MORTAR, ROOF, TIMBER, IRON, CRIMSON, GOLD, GLOW = range(9)
MAT_KEYS = [m[0] for m in MATERIAL_SPECS]
NON_COLLIDING_MATS = {"Mortar", "Glow"}

PI = math.pi


# =============================================================================
# 1. MATERIALS & COORDINATES
# =============================================================================
def hex_to_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))


def rbx(p) -> Vector:
    """Roblox (x, y_up, z) -> Blender (x, -z, y)."""
    return Vector((p[0], -p[2], p[1]))


def build_materials() -> list:
    mats = []
    for key, name, hx, rough, metal, emis, _rbx_mat, _tr in MATERIAL_SPECS:
        mat = bpy.data.materials.get(name) or bpy.data.materials.new(name=name)
        mat.use_nodes = True
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        r, g, b = hex_to_rgb(hx)
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
            bsdf.inputs["Roughness"].default_value = rough
            bsdf.inputs["Metallic"].default_value = metal
            if emis > 0.0:
                sock = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
                if sock:
                    sock.default_value = (r, g, b, 1.0)
                if "Emission Strength" in bsdf.inputs:
                    bsdf.inputs["Emission Strength"].default_value = emis
        mat.diffuse_color = (r, g, b, 1.0)
        mats.append(mat)
    return mats


# =============================================================================
# 2. GOTHIC ARCH MATH (2-centred pointed arch, springing at y = ys)
# =============================================================================
def _arch_params(a: float, h: float) -> tuple:
    """Left arc centre x (c) and radius (r) for half-span a and rise h (h >= a)."""
    c = (h * h - a * a) / (2.0 * a)
    return c, a + c


def arch_half(a: float, ys: float, h: float, segs: int = ARCH_SEGS) -> list:
    """Left half of the arch from springing (-a, ys) up to the apex (0, ys + h)."""
    c, r = _arch_params(a, h)
    t_end = math.atan2(h, -c)
    pts = []
    for i in range(segs + 1):
        t = PI + (t_end - PI) * i / segs
        pts.append((c + r * math.cos(t), ys + r * math.sin(t)))
    pts[0] = (-a, ys)
    pts[-1] = (0.0, ys + h)
    return pts


def arch_chain(a: float, ys: float, h: float, segs: int = ARCH_SEGS) -> list:
    """Full arch curve from left springing over the apex to right springing."""
    left = arch_half(a, ys, h, segs)
    return left + [(-x, y) for x, y in reversed(left)][1:]


def arch_y_at(a: float, ys: float, h: float, x: float) -> float:
    c, r = _arch_params(a, h)
    xl = -min(abs(x), a)
    return ys + math.sqrt(max(0.0, r * r - (xl - c) ** 2))


def arch_halfwidth_at(a: float, ys: float, h: float, y: float) -> float:
    if y <= ys:
        return a
    c, r = _arch_params(a, h)
    dy = y - ys
    return max(0.0, -(c - math.sqrt(max(0.0, r * r - dy * dy))))


def pointed_poly(a: float, ys: float, h: float, yb: float, segs: int = ARCH_SEGS) -> list:
    """Closed lancet silhouette: flat bottom at yb, pointed arch top."""
    left = arch_half(a, ys, h, segs)
    right = [(-x, y) for x, y in left]
    return [(-a, yb), (a, yb)] + right + list(reversed(left))[1:]


def shield_poly(w: float, h: float, top: float) -> list:
    """Heater shield silhouette (flat top, curved sides, bottom point)."""
    hw = w * 0.5
    right = [(hw, top), (hw, top - 0.45 * h), (0.84 * hw, top - 0.68 * h), (0.5 * hw, top - 0.86 * h)]
    return right + [(0.0, top - h)] + [(-x, y) for x, y in reversed(right)]


def _dedupe(pts: list) -> list:
    out = []
    for p in pts:
        if not out or (abs(p[0] - out[-1][0]) > 1e-5 or abs(p[1] - out[-1][1]) > 1e-5):
            out.append(p)
    if len(out) > 2 and abs(out[0][0] - out[-1][0]) < 1e-5 and abs(out[0][1] - out[-1][1]) < 1e-5:
        out.pop()
    return out


def rot_matrix(pitch: float = 0.0, yaw: float = 0.0, roll: float = 0.0) -> Matrix:
    return (
        Matrix.Rotation(yaw, 3, "Y") @ Matrix.Rotation(pitch, 3, "X") @ Matrix.Rotation(roll, 3, "Z")
    )


def rot_y4(angle: float) -> Matrix:
    return Matrix.Rotation(angle, 4, "Y")


# =============================================================================
# 3. KIT BUILDER (bmesh primitives authored in Roblox space)
# =============================================================================
class Kit:
    def __init__(self):
        self.bm = bmesh.new()
        self.xf = Matrix.Identity(4)

    @contextmanager
    def at(self, m: Matrix):
        prev = self.xf
        self.xf = prev @ m
        try:
            yield
        finally:
            self.xf = prev

    def _v(self, p):
        q = self.xf @ Vector((p[0], p[1], p[2]))
        return self.bm.verts.new(rbx(q))

    def _f(self, verts, mat: int):
        try:
            f = self.bm.faces.new(verts)
            f.material_index = mat
        except ValueError:
            pass

    def hexa(self, pts, mat: int):
        vs = [self._v(p) for p in pts]
        for a, b, c, d in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            self._f([vs[a], vs[b], vs[c], vs[d]], mat)

    def box(self, c, s, mat: int, bev=(0.0, 0.0), rot=None):
        """Box centred at c with size s; bev = top-face inset along (X, Z) for chamfered caps."""
        hx, hy, hz = s[0] * 0.5, s[1] * 0.5, s[2] * 0.5
        tx, tz = max(0.02, hx - bev[0]), max(0.02, hz - bev[1])
        local = [
            (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
            (-tx, hy, -tz), (tx, hy, -tz), (tx, hy, tz), (-tx, hy, tz),
        ]
        m = rot_matrix(*rot) if rot else None
        pts = []
        for p in local:
            v = Vector(p)
            if m is not None:
                v = m @ v
            pts.append((c[0] + v.x, c[1] + v.y, c[2] + v.z))
        self.hexa(pts, mat)

    def prism(self, poly, z0: float, z1: float, mat: int):
        """Extrude an XY polygon (may be concave) along Z from z0 to z1."""
        pts = _dedupe(poly)
        n = len(pts)
        if n < 3:
            return
        a = [self._v((x, y, z0)) for x, y in pts]
        b = [self._v((x, y, z1)) for x, y in pts]
        for i in range(n):
            j = (i + 1) % n
            self._f([a[i], a[j], b[j], b[i]], mat)
        self._f(list(reversed(a)), mat)
        self._f(b, mat)

    def frustum(self, c, y0: float, y1: float, r0: float, r1: float, mat: int, sides: int = 8, phase=None):
        """Vertical n-gon frustum / cone at (c[0], c[1]) in X/Z."""
        ph = PI / sides if phase is None else phase

        def ring(y, r):
            return [
                (c[0] + math.cos(ph + 2 * PI * i / sides) * r, y, c[1] + math.sin(ph + 2 * PI * i / sides) * r)
                for i in range(sides)
            ]

        a = [self._v(p) for p in ring(y0, r0)]
        if r1 <= 1e-4:
            apex = self._v((c[0], y1, c[1]))
            for i in range(sides):
                self._f([a[i], a[(i + 1) % sides], apex], mat)
        else:
            b = [self._v(p) for p in ring(y1, r1)]
            for i in range(sides):
                j = (i + 1) % sides
                self._f([a[i], a[j], b[j], b[i]], mat)
            self._f(b, mat)
        self._f(list(reversed(a)), mat)

    def wall_arch(self, W, y0, y1, a, ys, h, yb, z0, z1, mat, segs=ARCH_SEGS):
        """Wall slab x in [-W, W], y in [y0, y1] with a pointed-arch opening centred on x = 0."""
        left = [(-W, y0)]
        if yb > y0 + 1e-4:
            left += [(0.0, y0), (0.0, yb), (-a, yb)]
        else:
            left += [(-a, y0)]
        left += arch_half(a, ys, h, segs) + [(0.0, y1), (-W, y1)]
        self.prism(left, z0, z1, mat)
        self.prism([(-x, y) for x, y in reversed(left)], z0, z1, mat)

    def arch_band(self, a_in, h_in, a_out, h_out, ys, z0, z1, mat, segs=ARCH_SEGS, gap=0.0):
        """Arch moulding / voussoir ring between two pointed curves (gap > 0 => separate stones)."""
        inner = arch_chain(a_in, ys, h_in, segs)
        outer = arch_chain(a_out, ys, h_out, segs)
        for i in range(len(inner) - 1):
            q = [inner[i], inner[i + 1], outer[i + 1], outer[i]]
            if gap > 0.0:
                cx = sum(p[0] for p in q) / 4.0
                cy = sum(p[1] for p in q) / 4.0
                k = 1.0 - gap
                q = [(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in q]
            self.hexa([(x, y, z0) for x, y in q] + [(x, y, z1) for x, y in q], mat)

    def bar2d(self, p0, p1, w, z0, z1, mat):
        dx, dy = p1[0] - p0[0], p1[1] - p0[1]
        ln = max(1e-5, math.hypot(dx, dy))
        nx, ny = -dy / ln * w * 0.5, dx / ln * w * 0.5
        q = [(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny), (p1[0] - nx, p1[1] - ny), (p0[0] - nx, p0[1] - ny)]
        self.hexa([(x, y, z0) for x, y in q] + [(x, y, z1) for x, y in q], mat)

    def bar3d(self, p0, p1, sx, sz, mat):
        a, b = Vector(p0), Vector(p1)
        d = b - a
        m = d.normalized().to_track_quat("Y", "Z").to_matrix()
        hx, hy, hz = sx * 0.5, d.length * 0.5, sz * 0.5
        mid = (a + b) * 0.5
        local = [
            (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
            (-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz),
        ]
        self.hexa([tuple(mid + m @ Vector(p)) for p in local], mat)

    def ring(self, cx, cy, r_in, r_out, z0, z1, mat, segs=8):
        for i in range(segs):
            t0, t1 = 2 * PI * i / segs, 2 * PI * (i + 1) / segs
            q = [
                (cx + math.cos(t0) * r_in, cy + math.sin(t0) * r_in),
                (cx + math.cos(t1) * r_in, cy + math.sin(t1) * r_in),
                (cx + math.cos(t1) * r_out, cy + math.sin(t1) * r_out),
                (cx + math.cos(t0) * r_out, cy + math.sin(t0) * r_out),
            ]
            self.hexa([(x, y, z0) for x, y in q] + [(x, y, z1) for x, y in q], mat)


# =============================================================================
# 4. MODULE 1 - Wall_Gothic_Straight (24W x 22H x 6D)
# =============================================================================
WALL_SOCKETS = {
    "TorchSocket_Center": (0.0, 9.5, -2.6),
    "BannerSocket_Left": (-9.0, 13.5, -2.8),
    "BannerSocket_Right": (9.0, 13.5, -2.8),
}


def build_wall_straight():
    hull, det = Kit(), Kit()

    # Stepped bevelled plinth (Y 0..3.5)
    hull.box((0, 0.75, 0), (24, 1.5, 6.0), CAP, bev=(0, 0.25))
    hull.box((0, 2.5, 0), (24, 2.0, 5.4), CAP, bev=(0, 0.3))

    # Core masonry (recess back plane at z = -0.7, exterior back plane at z = 1.6)
    hull.box((0, 10.55, 0.45), (24, 14.1, 2.3), STONE)

    # Interior (courtyard) layer with deep pointed blind arch (1.5 deep)
    hull.wall_arch(12, 3.5, 17.0, 4.4, 10.6, 5.2, 3.5, -2.2, -0.7, STONE)
    # Exterior layer with shallower blind arch + glowing lancet slit
    hull.wall_arch(12, 3.5, 17.0, 3.2, 9.0, 3.8, 5.0, 1.6, 2.4, STONE, segs=5)

    # Pilaster buttresses flanking the arch
    for s in (-1, 1):
        hull.box((s * 9, 10.25, -2.5), (3.0, 13.5, 0.6), STONE)
        hull.box((s * 9, 4.75, -2.6), (3.6, 2.5, 0.8), CAP, bev=(0, 0.15))
        hull.box((s * 9, 10.25, 2.6), (2.6, 13.5, 0.4), STONE)

    # Corbelled cornices (inner + outer)
    hull.box((0, 17.3, -2.55), (24, 0.7, 0.9), CAP)
    hull.box((0, 16.75, 2.55), (24, 0.7, 0.9), CAP)

    # Rampart walkway (top at Y = 18): mortar bed + 4 flagstones with grooves
    hull.box((0, 17.3, -0.75), (24, 0.6, 4.5), MORTAR)
    for x in (-9, -3, 3, 9):
        hull.box((x, 17.8, -0.75), (5.85, 0.4, 4.5), CAP)
    hull.box((0, 18.3, -2.8), (24, 0.6, 0.4), CAP)  # inner kerb lip

    # Outer parapet, crenel coping stones and 4 merlons with chamfered caps
    hull.box((0, 17.9, 2.2), (24, 1.8, 1.4), STONE)
    for x in (-9, -3, 3, 9):
        hull.box((x, 20.0, 2.2), (3.5, 2.4, 1.6), STONE)
        hull.box((x, 21.6, 2.2), (3.9, 0.8, 2.0), CAP, bev=(0.35, 0.35))
    for cx, w in ((-11.375, 1.25), (-6, 2.5), (0, 2.5), (6, 2.5), (11.375, 1.25)):
        hull.box((cx, 19.05, 2.2), (w - 0.08, 0.5, 1.8), CAP, bev=(0, 0.2))

    # ---- Detail (non-colliding) ----
    det.arch_band(4.4, 5.2, 5.1, 6.0, 10.6, -2.45, -2.2, CAP, segs=5)
    for s in (-1, 1):
        det.box((s * 4.75, 7.05, -2.32), (0.7, 7.1, 0.25), CAP)
    det.box((0, 16.25, -2.5), (0.9, 1.3, 0.4), CAP, bev=(0.1, 0))  # keystone
    det.prism(pointed_poly(4.4, 10.6, 5.2, 3.5), -0.8, -0.7, MORTAR)  # dark recess back
    for x in (-6, -2, 2, 6):
        det.box((x, 16.6, -2.45), (0.9, 0.9, 0.5), CAP)
    for x in (-6, -3, 0, 3, 6):
        det.box((x, 15.95, 2.65), (0.8, 0.9, 0.5), CAP)
    det.arch_band(3.2, 3.8, 3.8, 4.5, 9.0, 2.4, 2.6, CAP, segs=4)
    det.prism(pointed_poly(0.75, 9.6, 1.3, 6.4), 1.55, 1.65, GLOW)  # exterior lancet slit
    det.box((0, 6.2, 1.9), (1.9, 0.3, 0.6), CAP)
    # Proud ashlar blocks on the piers
    for j, y in enumerate((4.7, 6.9, 9.1, 11.3, 13.5)):
        w = 1.9 if j % 2 == 0 else 1.6
        for s in (-1, 1):
            det.box((s * 6.3, y, -2.27), (w, 2.0, 0.14), CAP if (j % 2 == 0) else STONE)
    for j, y in enumerate((6.0, 8.4, 10.8, 13.2)):
        w = 2.6 if j % 2 == 0 else 2.0
        for s in (-1, 1):
            det.box((s * 5.75, y, 2.47), (w, 2.0, 0.14), CAP if (j % 2 == 1) else STONE)

    return {"Hull": hull, "Detail": det}, {}, WALL_SOCKETS


# =============================================================================
# 5. MODULE 2 - Wall_Gothic_GateArch (32W x 24H x 8D, 14W x 15H opening)
# =============================================================================
GATE_A, GATE_YS, GATE_H = 7.0, 7.0, 8.0
GATE_SOCKETS = {
    "TorchSocket_Left": (-10.6, 10.5, -5.1),
    "TorchSocket_Right": (10.6, 10.5, -5.1),
    "TorchSocket_OuterLeft": (-10.6, 10.5, 5.1),
    "TorchSocket_OuterRight": (10.6, 10.5, 5.1),
    "VFX_GateCrest": (0.0, 19.6, -4.4),
}


def _build_gate_door(side: int) -> Kit:
    hinge_x = side * GATE_A
    k = Kit()
    k.xf = Matrix.Translation(Vector((-hinge_x, 0.0, 0.0)))  # mesh origin at hinge
    a2, h2 = GATE_A - 0.05, GATE_H - 0.05
    left = arch_half(a2, GATE_YS, h2)
    pts = [(-a2, 0.32), (-0.05, 0.32), (-0.05, arch_y_at(a2, GATE_YS, h2, -0.05))]
    pts += [p for p in reversed(left) if p[0] < -0.06]
    if side > 0:
        pts = [(-x, y) for x, y in reversed(pts)]
    k.prism(pts, -0.3, 0.3, TIMBER)
    cx = side * 3.5
    for y in (2.2, 6.2, 10.2):
        k.box((cx, y, -0.36), (6.4, 0.45, 0.12), IRON)
        k.box((cx, y, 0.36), (6.4, 0.45, 0.12), IRON)
    k.box((side * 1.0, 6.0, -0.42), (0.55, 0.55, 0.14), IRON)
    k.ring(side * 1.0, 5.35, 0.32, 0.46, -0.5, -0.4, IRON, segs=8)
    return k


def build_gate():
    W = 16
    hull, det = Kit(), Kit()

    # Threshold + stepped side plinths (opening floor stays walkable)
    hull.box((0, 0.15, 0), (14.2, 0.3, 8.0), CAP)
    for s in (-1, 1):
        hull.box((s * 11.5, 0.6, 0), (9.0, 1.2, 8.0), CAP, bev=(0, 0.2))
        hull.box((s * 11.25, 2.35, 0), (8.5, 2.3, 7.2), CAP, bev=(0, 0.3))

    # Through-arch in 3 stepped orders
    hull.wall_arch(W, 0, 17.0, GATE_A, GATE_YS, GATE_H, 0, -2.8, 2.8, STONE)
    hull.wall_arch(W, 0, 17.0, 8.2, GATE_YS, 9.0, 0, -3.4, -2.8, STONE)
    hull.wall_arch(W, 0, 17.0, 8.2, GATE_YS, 9.0, 0, 2.8, 3.4, STONE)

    # Flanking twin buttresses
    for s in (-1, 1):
        x = s * 14
        hull.box((x, 6.0, 0), (4.0, 12.0, 8.0), STONE)
        hull.box((x, 12.3, 0), (4.0, 0.6, 8.0), CAP, bev=(0.3, 0.5))
        hull.box((x, 14.8, 0), (3.4, 4.4, 7.2), STONE)
        hull.box((x, 17.3, 0), (4.0, 0.6, 8.0), CAP)

    # Cornices + walkway (top at Y = 18)
    hull.box((0, 17.3, -3.55), (32, 0.7, 0.9), CAP)
    hull.box((0, 16.75, 3.55), (32, 0.7, 0.9), CAP)
    hull.box((0, 17.3, -0.95), (32, 0.6, 6.1), MORTAR)
    for i in range(5):
        hull.box((-12.8 + i * 6.4, 17.8, -0.95), (6.25, 0.4, 6.1), CAP)

    # Inner kerb + raised crest panel
    hull.box((0, 18.3, -3.8), (32, 0.6, 0.4), CAP)
    hull.box((0, 19.5, -3.65), (8.0, 3.0, 0.7), STONE)
    hull.box((0, 21.2, -3.65), (8.6, 0.4, 0.9), CAP, bev=(0.2, 0.2))

    # Outer parapet + raised double-merlon gatehouse crown
    hull.box((0, 17.9, 2.9), (32, 1.8, 1.6), STONE)
    hull.box((0, 20.2, 2.9), (10, 2.8, 1.6), STONE)
    for s in (-1, 1):
        hull.box((s * 3, 22.4, 2.9), (3.2, 1.6, 1.6), STONE)
        hull.box((s * 3, 23.6, 2.9), (3.6, 0.8, 2.0), CAP, bev=(0.35, 0.35))
        for xm in (8.4, 13.6):
            hull.box((s * xm, 20.0, 2.9), (3.5, 2.4, 1.6), STONE)
            hull.box((s * xm, 21.6, 2.9), (3.9, 0.8, 2.0), CAP, bev=(0.35, 0.35))
        for cx, w in ((5.825, 1.65), (11.0, 1.7), (15.675, 0.65)):
            hull.box((s * cx, 19.05, 2.9), (w - 0.06, 0.5, 1.8), CAP, bev=(0, 0.2))
    hull.box((0, 21.85, 2.9), (2.7, 0.5, 1.8), CAP, bev=(0, 0.2))

    # ---- Detail: radial voussoirs + raised keystones on both faces ----
    for z0, z1 in ((-3.7, -3.4), (3.4, 3.7)):
        det.arch_band(8.2, 9.0, 9.5, 10.3, GATE_YS, z0, z1, CAP, segs=5, gap=0.06)
    for z0, z1 in ((-3.0, -2.8), (2.8, 3.0)):
        det.arch_band(GATE_A, GATE_H, 8.2, 9.0, GATE_YS, z0, z1, CAP, segs=4, gap=0.06)
    for zc in (-3.75, 3.75):
        det.box((0, 16.6, zc), (1.3, 1.8, 0.5), CAP, bev=(0.15, 0))

    # ---- Separate toggleable parts ----
    portcullis = Kit()
    zc = -2.2
    for i in range(-5, 6):
        x = i * 1.25
        top = arch_y_at(GATE_A, GATE_YS, GATE_H, x) - 0.15
        portcullis.box((x, top * 0.5, zc), (0.32, top, 0.32), IRON)
    for y in (1.6, 4.2, 6.8, 9.4, 12.0):
        hw = arch_halfwidth_at(GATE_A, GATE_YS, GATE_H, y) - 0.1
        portcullis.box((0, y, zc), (hw * 2, 0.28, 0.4), IRON)

    crest = Kit()
    cy = 19.6
    crest.prism(shield_poly(2.7, 2.9, cy + 1.45), -4.16, -4.0, GOLD)
    crest.prism(shield_poly(2.25, 2.45, cy + 1.22), -4.3, -4.16, CRIMSON)
    crest.box((0, cy + 0.1, -4.34), (0.32, 1.6, 0.08), GOLD)
    crest.box((0, cy + 0.45, -4.34), (1.2, 0.32, 0.08), GOLD)

    stairs = Kit()  # Variant B (north alcove) 4-step threshold, interior side
    for i in range(4):
        z_far = -7.4 + i
        stairs.box((0, 0.2 * (i + 1), (z_far - 2.0) * 0.5), (12.5 - i * 0.4, 0.4 * (i + 1), -2.0 - z_far), CAP)

    parts = {
        "Gate_Door_Left": ((-GATE_A, 0.0, 0.0), {"Part": _build_gate_door(-1)}, True),
        "Gate_Door_Right": ((GATE_A, 0.0, 0.0), {"Part": _build_gate_door(1)}, True),
        "Gate_Portcullis": ((0.0, 0.0, 0.0), {"Part": portcullis}, True),
        "Gate_CrestShield": ((0.0, 0.0, 0.0), {"Part": crest}, False),
        "Gate_StairThreshold": ((0.0, 0.0, 0.0), {"Part": stairs}, True),
    }
    return {"Hull": hull, "Detail": det}, parts, GATE_SOCKETS


# =============================================================================
# 6. MODULE 3 - Tower_Gothic_CornerSpire (20W x 68H x 20D)
# =============================================================================
TOWER_SOCKETS = {
    "VFX_TowerWindow_N": (0.0, 33.0, -8.5),
    "VFX_TowerWindow_S": (0.0, 33.0, 8.5),
    "VFX_TowerWindow_E": (8.5, 33.0, 0.0),
    "VFX_TowerWindow_W": (-8.5, 33.0, 0.0),
    "VFX_RampartArch_Glow": (0.0, 20.0, 0.0),
}


def build_tower():
    hull, det, spire = Kit(), Kit(), Kit()
    corners = [(sx, sz) for sx in (-1, 1) for sz in (-1, 1)]

    # 5 wrap-around exterior steps (Y 0..4) + fortress base (Y 4..18)
    for i in range(5):
        s = 20 - i * 0.5
        hull.box((0, i * 0.8 + 0.4, 0), (s, 0.8, s), CAP)
    hull.box((0, 11.0, 0), (18, 14, 18), STONE)
    hull.box((0, 17.75, 0), (18.6, 0.5, 18.6), CAP)

    # Rampart chamber (floor Y = 18) with a doorway on all 4 faces
    for sx, sz in corners:
        hull.box((sx * 7.5, 21.0, sz * 7.5), (3, 6, 3), STONE)
    for k in range(4):
        with hull.at(rot_y4(k * PI / 2)):
            hull.wall_arch(6.0, 18.0, 24.0, 2.0, 21.4, 2.4, 18.0, 7.0, 9.0, STONE, segs=4)
        with det.at(rot_y4(k * PI / 2)):
            det.arch_band(2.0, 2.4, 2.55, 3.0, 21.4, 9.0, 9.2, CAP, segs=3)
            for s in (-1, 1):
                det.box((s * 2.28, 19.7, 9.1), (0.55, 3.4, 0.2), CAP)
    hull.box((0, 24.3, 0), (18.8, 0.6, 18.8), CAP)  # belt course / chamber ceiling

    # Gothic shaft (Y 24.6..44) with corner buttresses and lancet windows
    hull.box((0, 34.3, 0), (14, 19.4, 14), STONE)
    for sx, sz in corners:
        hull.box((sx * 8, 34.3, sz * 8), (3, 19.4, 3), STONE)
        for j in range(5):
            s = 3.35 if j % 2 == 0 else 3.15
            det.box((sx * 8, 26.0 + j * 3.9, sz * 8), (s, 1.1, s), CAP, bev=(0.12, 0.12))
    for k in range(4):
        with hull.at(rot_y4(k * PI / 2)):
            hull.wall_arch(6.5, 24.6, 44.0, 2.2, 33.0, 4.5, 28.0, 7.0, 8.5, STONE)
        with det.at(rot_y4(k * PI / 2)):
            det.prism(pointed_poly(2.2, 33.0, 4.5, 28.0), 6.98, 7.15, GLOW)
            det.box((0, 31.2, 7.55), (0.4, 6.4, 0.5), CAP)  # central mullion
            det.bar2d((0, 34.2), (-1.55, 35.65), 0.36, 7.35, 7.75, CAP)  # Y-tracery
            det.bar2d((0, 34.2), (1.55, 35.65), 0.36, 7.35, 7.75, CAP)
            det.ring(0, 35.9, 0.42, 0.65, 7.35, 7.75, CAP, segs=8)  # rose cut-out
            det.box((0, 27.8, 8.4), (5.4, 0.45, 1.0), CAP)  # sill
            det.arch_band(2.2, 4.5, 2.75, 5.15, 33.0, 8.5, 8.75, CAP, segs=4)  # hood mould
            # Machicolation shadow band + corbels
            det.box((0, 43.4, 8.56), (12.6, 1.6, 0.12), MORTAR)
            for x in (-5.2, -2.6, 0.0, 2.6, 5.2):
                det.box((x, 43.4, 9.15), (1.0, 1.6, 1.3), CAP)

    # Crown: overhanging slab + parapet ring + merlons (Y 44.2..48)
    hull.box((0, 44.7, 0), (20, 1.0, 20), CAP)
    for k in range(4):
        with hull.at(rot_y4(k * PI / 2)):
            hull.box((0, 46.0, 9.4), (20, 1.6, 1.2), STONE)
            for x in (-4.6, 0.0, 4.6):
                hull.box((x, 47.4, 9.4), (2.4, 1.2, 1.3), CAP, bev=(0.25, 0.25))

    # Central octagonal slate spire with shingle-course ribs (Y 45.2..68)
    y0, apex, r0, tiers = 45.2, 66.2, 7.4, 5
    for t in range(tiers):
        ya = y0 + (apex - y0) * t / tiers
        yb = y0 + (apex - y0) * (t + 1) / tiers
        rb = r0 * (1 - (ya - y0) / (apex - y0)) + (0.35 if t > 0 else 0.2)
        rt = r0 * (1 - (yb - y0) / (apex - y0)) if t < tiers - 1 else 0.0
        spire.frustum((0, 0), ya, yb, rb, rt, ROOF)
    spire.frustum((0, 0), apex - 0.6, 68.0, 0.35, 0.0, IRON, sides=6)  # finial

    # 4 corner turret pinnacles with needle spires
    for sx, sz in corners:
        c = (sx * 8.9, sz * 8.9)
        spire.frustum(c, 45.2, 52.5, 0.95, 0.85, STONE)
        spire.frustum(c, 52.5, 53.1, 1.2, 1.2, CAP)
        spire.frustum(c, 53.1, 60.5, 1.05, 0.0, ROOF)
        spire.frustum(c, 60.0, 61.6, 0.14, 0.0, IRON, sides=4)

    parts = {"Tower_Spire": ((0.0, 0.0, 0.0), {"Part": spire}, False)}
    return {"Hull": hull, "Detail": det}, parts, TOWER_SOCKETS


# =============================================================================
# 7. MODULE 4 - Prop_Wall_Banner_And_Torch
# =============================================================================
def build_banner() -> Kit:
    """Origin = wall mount point (top-centre). Wall is at +Z, banner hangs toward -Z."""
    b = Kit()
    b.box((0, -0.1, -0.42), (3.4, 0.2, 0.2), IRON)
    for s in (-1, 1):
        b.box((s * 1.8, -0.1, -0.42), (0.32, 0.32, 0.32), IRON)
        b.box((s * 1.2, -0.1, -0.2), (0.16, 0.16, 0.44), IRON)
    b.prism([(-1.4, -0.25), (1.4, -0.25), (1.4, -6.35), (0, -7.75), (-1.4, -6.35)], -0.36, -0.30, GOLD)
    b.prism([(-1.2, -0.4), (1.2, -0.4), (1.2, -6.25), (0, -7.4), (-1.2, -6.25)], -0.42, -0.36, CRIMSON)
    b.prism(shield_poly(1.1, 1.4, -2.6), -0.46, -0.42, GOLD)
    b.box((0, -1.0, -0.44), (2.4, 0.22, 0.04), GOLD)
    return b


def build_torch() -> Kit:
    """Origin = flame base (matches TorchSocket_*). Wall plate sits 1.75 studs behind (+Z)."""
    t = Kit()
    t.box((0, -1.35, 1.72), (0.7, 1.3, 0.12), IRON)
    t.bar3d((0, -1.5, 1.66), (0, -0.78, 0.25), 0.16, 0.16, IRON)
    t.frustum((0, 0), -0.95, -0.5, 0.24, 0.34, IRON)
    t.frustum((0, 0), -2.0, -0.45, 0.11, 0.15, TIMBER, sides=6)
    t.frustum((0, 0), -0.45, 0.0, 0.2, 0.25, MORTAR)
    t.frustum((0, 0), 0.0, 0.45, 0.17, 0.0, GLOW, sides=6)
    return t


# =============================================================================
# 8. OBJECT ASSEMBLY (split per material), SOCKETS, EXPORT
# =============================================================================
def _box_uv(b: bmesh.types.BMesh):
    uv = b.loops.layers.uv.verify()
    s = 1.0 / UV_TILE_STUDS
    for f in b.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            co = loop.vert.co
            if ax == 0:
                loop[uv].uv = (co.y * s, co.z * s)
            elif ax == 1:
                loop[uv].uv = (co.x * s, co.z * s)
            else:
                loop[uv].uv = (co.x * s, co.y * s)


def _smart_uv(obj):
    try:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")


def kit_to_objects(kit: Kit, prefix: str, col, parent, mats, collide: bool, registry: dict) -> list:
    bm = kit.bm
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    used = sorted({f.material_index for f in bm.faces})
    objs = []
    for idx in used:
        b2 = bm.copy()
        bmesh.ops.delete(b2, geom=[f for f in b2.faces if f.material_index != idx], context="FACES")
        b2.normal_update()
        for f in b2.faces:
            f.material_index = 0
            f.smooth = True
        lim = math.radians(SMOOTH_ANGLE_DEG)
        for e in b2.edges:
            e.smooth = e.is_manifold and e.calc_face_angle(PI) <= lim
        if UV_MODE == "BOX":
            _box_uv(b2)
        key = MAT_KEYS[idx]
        name = f"{prefix}_{key}"
        me = bpy.data.meshes.new(f"{name}_Mesh")
        b2.to_mesh(me)
        b2.free()
        me.materials.append(mats[idx])
        ob = bpy.data.objects.new(name, me)
        col.objects.link(ob)
        ob.parent = parent
        if UV_MODE == "SMART":
            _smart_uv(ob)
        spec = MATERIAL_SPECS[idx]
        registry[name] = {
            "material": spec[6],
            "color": spec[2],
            "transparency": spec[7],
            "canCollide": bool(collide and key not in NON_COLLIDING_MATS),
            "castShadow": key != "Glow",
        }
        objs.append(ob)
    bm.free()
    return objs


def _new_empty(name, col, parent=None, loc=(0, 0, 0), kind="PLAIN_AXES", size=2.0):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = kind
    e.empty_display_size = size
    col.objects.link(e)
    e.parent = parent
    e.location = rbx(loc)
    return e


def _clear_collection(name: str):
    col = bpy.data.collections.get(name)
    if not col:
        return
    for ob in list(col.all_objects):
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if data is not None and data.users == 0 and isinstance(data, bpy.types.Mesh):
            bpy.data.meshes.remove(data)
    for child in list(col.children):
        bpy.data.collections.remove(child)
    bpy.data.collections.remove(col)


def _new_collection(name: str):
    _clear_collection(name)
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def assemble_module(name, builder, offset, mats, manifest):
    kits, parts, sockets = builder()
    col = _new_collection(name)
    root = _new_empty(name, col, loc=offset, size=4.0)
    registry = {}
    for role, kit in kits.items():
        kit_to_objects(kit, f"{name}_{role}", col, root, mats, collide=(role == "Hull"), registry=registry)
    part_info = {}
    for pname, (pivot, pkits, collide) in parts.items():
        proot = _new_empty(pname, col, parent=root, loc=pivot, size=1.5)
        for role, kit in pkits.items():
            kit_to_objects(kit, f"{pname}_{role}", col, proot, mats, collide=collide, registry=registry)
        part_info[pname] = {"pivot": list(pivot)}
    for sname, p in sockets.items():
        _new_empty(sname, col, parent=root, loc=p, kind="ARROWS", size=0.8)
    manifest["modules"][name] = {
        "objects": registry,
        "parts": part_info,
        "sockets": {k: list(v) for k, v in sockets.items()},
    }
    return root


def count_tris(root) -> int:
    total = 0
    for ob in [root] + list(root.children_recursive):
        if ob.type == "MESH":
            ob.data.calc_loop_triangles()
            total += len(ob.data.loop_triangles)
    return total


def export_root(root, path: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    saved = root.location.copy()
    root.location = (0, 0, 0)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in [root] + list(root.children_recursive):
        ob.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH", "EMPTY"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=False,
        add_leaf_bones=False,
    )
    root.location = saved
    bpy.ops.object.select_all(action="DESELECT")


# =============================================================================
# 9. PREVIEW: a fortress corner assembled from linked duplicates (not exported)
# =============================================================================
PREVIEW_COLLECTION = "GothicWalls_PreviewCorner"


def _instance(root, pos, yaw, col):
    root_inv = root.matrix_world.inverted()
    place = Matrix.Translation(rbx(pos)) @ Matrix.Rotation(yaw, 4, "Z")
    for ob in root.children_recursive:
        if ob.type != "MESH":
            continue
        dup = ob.copy()
        dup.parent = None
        col.objects.link(dup)
        dup.matrix_world = place @ (root_inv @ ob.matrix_world)


def _place_point(pos, yaw, p):
    c, s = math.cos(yaw), math.sin(yaw)
    return (pos[0] + p[0] * c + p[2] * s, pos[1] + p[1], pos[2] - p[0] * s + p[2] * c)


def build_preview(roots: dict):
    bpy.context.view_layer.update()
    col = _new_collection(PREVIEW_COLLECTION)
    P = (0.0, 0.0, 90.0)
    wall, gate, tower = roots["Wall_Gothic_Straight"], roots["Wall_Gothic_GateArch"], roots["Tower_Gothic_CornerSpire"]
    banner, torch = roots["Prop_WallBanner"], roots["Prop_WallTorchSconce"]
    _instance(tower, P, 0.0, col)
    walls = [((P[0] + 22, 0, P[2]), 0.0), ((P[0] + 46, 0, P[2]), 0.0),
             ((P[0], 0, P[2] - 22), -PI / 2), ((P[0], 0, P[2] - 46), -PI / 2)]
    for pos, yaw in walls:
        _instance(wall, pos, yaw, col)
        _instance(torch, _place_point(pos, yaw, WALL_SOCKETS["TorchSocket_Center"]), yaw, col)
        for sk in ("BannerSocket_Left", "BannerSocket_Right"):
            _instance(banner, _place_point(pos, yaw, WALL_SOCKETS[sk]), yaw, col)
    gpos = (P[0] + 74, 0, P[2])
    _instance(gate, gpos, 0.0, col)
    for sk in ("TorchSocket_Left", "TorchSocket_Right"):
        _instance(torch, _place_point(gpos, 0.0, GATE_SOCKETS[sk]), 0.0, col)


# =============================================================================
# 10. MAIN
# =============================================================================
def build_all(export: bool = True) -> dict:
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    cube = bpy.data.objects.get("Cube")
    if cube and cube.type == "MESH" and len(cube.data.polygons) == 6:
        bpy.data.objects.remove(cube, do_unlink=True)
    _clear_collection(PREVIEW_COLLECTION)

    mats = build_materials()
    manifest = {
        "kit": "GothicFortification",
        "units": "1 Blender unit = 1 Roblox stud",
        "space": "Roblox local space of each module; origin = bottom-centre; -Z = courtyard/interior face",
        "fbxAxes": "forward -Z, up Y (FBX coordinates == Roblox coordinates)",
        "modules": {},
    }
    roots = {}
    roots["Tower_Gothic_CornerSpire"] = assemble_module("Tower_Gothic_CornerSpire", build_tower, (-45, 0, 0), mats, manifest)
    roots["Wall_Gothic_Straight"] = assemble_module("Wall_Gothic_Straight", build_wall_straight, (0, 0, 0), mats, manifest)
    roots["Wall_Gothic_GateArch"] = assemble_module("Wall_Gothic_GateArch", build_gate, (40, 0, 0), mats, manifest)

    # Module 4: one collection, two independently pivoted props
    prop_col = _new_collection("Prop_Wall_Banner_And_Torch")
    for pname, builder, off in (("Prop_WallBanner", build_banner, (70, 10, 0)),
                                ("Prop_WallTorchSconce", build_torch, (76, 6, 0))):
        root = _new_empty(pname, prop_col, loc=off, size=1.0)
        reg = {}
        kit_to_objects(builder(), pname, prop_col, root, mats, collide=False, registry=reg)
        manifest["modules"][pname] = {"objects": reg, "parts": {}, "sockets": {}}
        roots[pname] = root

    sizes = {
        "Wall_Gothic_Straight": [24, 22, 6],
        "Wall_Gothic_GateArch": [32, 24, 8],
        "Tower_Gothic_CornerSpire": [20, 68, 20],
        "Prop_WallBanner": [3.4, 7.75, 0.5],
        "Prop_WallTorchSconce": [0.7, 2.45, 1.8],
    }
    report = {}
    for name, root in roots.items():
        tris = count_tris(root)
        budget = TRI_BUDGETS.get(name)
        manifest["modules"][name]["size"] = sizes[name]
        manifest["modules"][name]["tris"] = tris
        manifest["modules"][name]["fbx"] = f"assets/fbx/gothic_walls/{name}.fbx"
        report[name] = (tris, budget)
        flag = "" if budget is None else (" OK" if tris <= budget else " OVER BUDGET")
        print(f"[GothicWalls] {name}: {tris} tris" + (f" / {budget}{flag}" if budget else ""))

    if export:
        for name, root in roots.items():
            path = os.path.join(EXPORT_DIR, f"{name}.fbx")
            export_root(root, path)
            print(f"[GothicWalls] Exported {path}")
        os.makedirs(EXPORT_DIR, exist_ok=True)
        with open(os.path.join(EXPORT_DIR, "gothic_walls_manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent=2)
        print(f"[GothicWalls] Manifest written to {EXPORT_DIR}")

    if BUILD_PREVIEW:
        build_preview(roots)
    return report


if __name__ == "__main__":
    build_all(export=True)
