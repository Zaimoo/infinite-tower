"""
Infinite Tower: Become a Master! - Berserker greataxes (AXE artifacts, batch 4 remodel).

Builds all 14 two-handed greataxes as separate semantic parts (Handle, GripWrap, Pommel,
HeadCollar, Blade, BladeEdge, BackSpike, RuneInlay), exports one FBX per artifact to
assets/artifacts/axes/, and writes greataxes_manifest.json (grip points, VFX points, part
list, triangle counts) that tests/studio-greataxe-import.luau reads back in Studio.

Run headless:
    blender --background --factory-startup --python tools/blender/generate_berserker_greataxes.py
Optional args after "--":  --preview <png>   render a contact sheet of every axe
                           --only <id,id>    build a subset

Authoring frame (1 Blender unit = 1 stud):
    haft along +Z, centred on the origin (so the Handle part's centre is the origin)
    main cutting edge towards -X, blade flats facing +/-Y
    Grip      = upper (right) hand, below the beard
    OffhandGrip = lower (left) hand, 1.7 studs towards the butt
"""

import json
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(REPO, "assets", "artifacts", "axes")
HAND_GAP = 1.7  # studs between the two hands along the haft
I4 = Matrix.Identity(4)
MIRROR_X = Matrix.Scale(-1, 4, Vector((1, 0, 0)))


def V2(u, z):
    return Vector((u, z))


# --------------------------------------------------------------------------------------
# Part: one bmesh that becomes one MeshPart
# --------------------------------------------------------------------------------------
class Part:
    def __init__(self):
        self.bm = bmesh.new()

    def v(self, co, M=I4):
        return self.bm.verts.new(M @ Vector(co))

    def f(self, verts):
        if len(set(verts)) < 3:
            return None
        try:
            return self.bm.faces.new(verts)
        except ValueError:
            return None

    @property
    def empty(self):
        return len(self.bm.faces) == 0


def lathe(part, profile, segs, M=I4, sx=1.0, sy=1.0, phase=0.0):
    """Revolve (radius, z) pairs about Z. A radius of 0 closes to a point."""
    rings = []
    for r, z in profile:
        if r < 1e-5:
            rings.append([part.v((0, 0, z), M)])
        else:
            ring = []
            for i in range(segs):
                a = phase + 2 * math.pi * i / segs
                ring.append(part.v((r * sx * math.cos(a), r * sy * math.sin(a), z), M))
            rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                part.f([a[0], b[i], b[j]])
            elif len(b) == 1:
                part.f([a[i], a[j], b[0]])
            else:
                part.f([a[i], a[j], b[j], b[i]])
    if len(rings[0]) > 1:
        part.f(rings[0][::-1])
    if len(rings[-1]) > 1:
        part.f(rings[-1])


def box(part, c, size, M=I4):
    cx, cy, cz = c
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    vs = [part.v((cx + dx * hx, cy + dy * hy, cz + dz * hz), M) for dx in (-1, 1) for dy in (-1, 1) for dz in (-1, 1)]
    for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        part.f([vs[i] for i in q])


def torus(part, R, r, n_major, n_minor, M=I4):
    rings = []
    for i in range(n_major):
        a = 2 * math.pi * i / n_major
        ring = []
        for j in range(n_minor):
            b = 2 * math.pi * j / n_minor
            rr = R + r * math.cos(b)
            ring.append(part.v((rr * math.cos(a), rr * math.sin(a), r * math.sin(b)), M))
        rings.append(ring)
    for i in range(n_major):
        a, b = rings[i], rings[(i + 1) % n_major]
        for j in range(n_minor):
            k = (j + 1) % n_minor
            part.f([a[j], b[j], b[k], a[k]])


def sphere(part, c, r, segs=10, rings=6):
    prof = [(r * math.sin(math.pi * i / rings), -r * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
    lathe(part, prof, segs, Matrix.Translation(Vector(c)))


def gem(part, c, r, h, segs=6, M=I4, tilt=(0.0, 0.0)):
    """Crystal shard: a lopsided bipyramid standing on its local Z."""
    T = M @ Matrix.Translation(Vector(c)) @ Matrix.Rotation(tilt[0], 4, "X") @ Matrix.Rotation(tilt[1], 4, "Y")
    lathe(part, [(0, -h * 0.35), (r, -h * 0.05), (r * 0.8, h * 0.2), (0, h * 0.65)], segs, T)


# --------------------------------------------------------------------------------------
# 2D outline helpers (u = distance out from the haft axis, z = along the haft)
# --------------------------------------------------------------------------------------
def signed_area(pts):
    return 0.5 * sum(pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y for i in range(len(pts)))


def inside(p, pts):
    hit = False
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        if (a.y > p.y) != (b.y > p.y):
            x = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
            if x > p.x:
                hit = not hit
    return hit


def inset_poly(pts, depths):
    n = len(pts)
    ccw = signed_area(pts) > 0
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        e1, e2 = (p1 - p0), (p2 - p1)
        if e1.length < 1e-6 or e2.length < 1e-6:
            out.append(p1.copy())
            continue
        e1.normalize()
        e2.normalize()
        n1 = Vector((-e1.y, e1.x)) if ccw else Vector((e1.y, -e1.x))
        n2 = Vector((-e2.y, e2.x)) if ccw else Vector((e2.y, -e2.x))
        m = n1 + n2
        if m.length < 1e-6:
            m = n1.copy()
        m.normalize()
        k = 1.0 / max(0.4, m.dot(n1))
        s = 1.0
        q = p1 + m * depths[i] * k
        while not inside(q, pts) and s > 0.04:
            s *= 0.5
            q = p1 + m * depths[i] * k * s
        if not inside(q, pts):
            q = p1 + m * 0.002
        out.append(q)
    return out


def plate(part, pts, t, inset, M=I4, neck_u=0.3):
    """Blade plate in the XZ plane: full thickness inside, bevelled to a sharp rim. Vertices
    near the haft (u < neck_u) keep almost no bevel so the blade stays thick in the eye."""
    depths = [inset * max(0.06, min(1.0, p.x / neck_u)) for p in pts]
    inner = inset_poly(pts, depths)
    rim = [part.v((p.x, 0, p.y), M) for p in pts]
    front = [part.v((p.x, t / 2, p.y), M) for p in inner]
    back = [part.v((p.x, -t / 2, p.y), M) for p in inner]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        part.f([rim[i], rim[j], front[j], front[i]])
        part.f([rim[j], rim[i], back[i], back[j]])
    part.f(front)
    part.f(back[::-1])


def bezier(a, c, b, n):
    return [(a * (1 - s) ** 2 + c * 2 * s * (1 - s) + b * s * s) for s in (i / n for i in range(n + 1))]


def axe_outline(z0, neck, reach, top, bot, res, tip_top=0.9, tip_bot=0.86, bulge=0.1, sag_t=0.42, sag_b=0.48, jag=0.0, rng=None, u0=-0.02):
    """Crescent / bearded axe blade. Returns (points, (first, last) index of the cutting edge)."""
    A, D = V2(u0, z0 + neck), V2(u0, z0 - neck)
    T, B = V2(reach * tip_top, z0 + top), V2(reach * tip_bot, z0 - bot)
    ct = V2(T.x * 0.6, z0 + neck + (top - neck) * (0.6 - sag_t))
    cb = V2(B.x * 0.6, z0 - neck - (bot - neck) * (0.6 - sag_b))
    pts = bezier(A, ct, T, res)
    first = len(pts) - 1
    n_edge = res + 2
    for i in range(1, n_edge):
        s = i / n_edge
        p = T.lerp(B, s)
        p.x += bulge * reach * math.sin(math.pi * s)
        if jag and rng:
            p.x += (1 if i % 2 else -1) * jag * reach * rng.uniform(0.5, 1.0)
            p.y += jag * reach * rng.uniform(-0.4, 0.4)
        pts.append(p)
    pts.append(B)
    last = len(pts) - 1
    pts += bezier(B, cb, D, res)[1:]
    return pts, (first, last)


def poly_outline(z0, rel, edge, res):
    """Hard-edged slab blade from (u, dz) corners; `edge` = (first, last) corner of the cutting
    edge, which is subdivided so the edge strip has enough spans."""
    pts, first, last = [], 0, 0
    for i, (u, dz) in enumerate(rel):
        if i == edge[0]:
            first = len(pts)
        pts.append(V2(u, z0 + dz))
        if edge[0] <= i < edge[1]:
            nu, ndz = rel[i + 1]
            for k in range(1, res):
                s = k / res
                pts.append(V2(u + (nu - u) * s, z0 + dz + (ndz - dz) * s))
        if i == edge[1]:
            last = len(pts) - 1
    return pts, (first, last)


def edge_strip(part, arc, centre, w, te, M=I4, proud=0.02):
    """Honed cutting edge laid over the blade's rim: sharp outside, raised ridge inside."""
    n = len(arc)
    outer, front, back = [], [], []
    for i, p in enumerate(arc):
        tan = arc[min(n - 1, i + 1)] - arc[max(0, i - 1)]
        if tan.length < 1e-6:
            tan = V2(0, 1)
        tan.normalize()
        nrm = V2(-tan.y, tan.x)
        if nrm.dot(centre - p) < 0:
            nrm = -nrm
        s = i / (n - 1)
        wi = w * (0.35 + 0.65 * math.sin(math.pi * s))
        o, q = p - nrm * proud, p + nrm * wi
        outer.append(part.v((o.x, 0, o.y), M))
        front.append(part.v((q.x, te / 2, q.y), M))
        back.append(part.v((q.x, -te / 2, q.y), M))
    for i in range(n - 1):
        part.f([outer[i], outer[i + 1], front[i + 1], front[i]])
        part.f([outer[i + 1], outer[i], back[i], back[i + 1]])
        part.f([front[i], front[i + 1], back[i + 1], back[i]])
    part.f([outer[0], front[0], back[0]])
    part.f([outer[-1], back[-1], front[-1]])


def stroke(part, a, b, width, t, M=I4, depth=0.022):
    """Inlay line between two blade-face points, on both faces of a blade of thickness t."""
    d = b - a
    if d.length < 1e-5:
        return
    d.normalize()
    n = V2(-d.y, d.x) * (width / 2)
    for side in (1, -1):
        y = side * t / 2
        vs = []
        for yy in (y - depth, y + depth):
            for p in (a - n, a + n, b + n, b - n):
                vs.append(part.v((p.x, yy, p.y), M))
        for q in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            part.f([vs[i] for i in q])


def vein(part, a, b, width, t, rng, kinks, wobble, M=I4):
    prev = a
    d = b - a
    n = V2(-d.y, d.x)
    for i in range(1, kinks + 1):
        s = i / kinks
        p = a.lerp(b, s)
        if i < kinks:
            p += n * rng.uniform(-wobble, wobble)
        stroke(part, prev, p, width * (1.0 - 0.5 * s), t, M)
        prev = p


def leaf(base, angle, length, width, n):
    """Feather outline starting at `base`, pointing along `angle` (radians from +u towards +z)."""
    c, s = math.cos(angle), math.sin(angle)
    pts = []
    for i in range(n + 1):
        k = i / n
        pts.append((length * k, width * math.sin(math.pi * k ** 0.7) * 0.5 + 0.02))
    for i in range(n - 1, 0, -1):
        k = i / n
        pts.append((length * k, -width * math.sin(math.pi * k ** 0.85) * 0.28))
    return [V2(base.x + x * c - y * s, base.y + x * s + y * c) for x, y in pts]


# --------------------------------------------------------------------------------------
# Specs
# --------------------------------------------------------------------------------------
def rgb(r, g, b):
    return (r / 255, g / 255, b / 255, 1)


IRON, STEEL, EDGE = rgb(130, 135, 145), rgb(145, 150, 160), rgb(210, 215, 225)
SPECS = [
    dict(id="art_miner_pickaxe", tier=1, L=5.2, r=0.105, blade=dict(kind="axe", neck=0.3, reach=1.25, top=0.55, bot=1.0, t=0.16, sag_b=0.3),
         back="poll", pommel="cap", finial=None, inlay=None,
         col=dict(Handle=rgb(115, 85, 55), GripWrap=rgb(70, 48, 32), Pommel=rgb(95, 100, 108), HeadCollar=rgb(110, 115, 125), Blade=STEEL, BladeEdge=EDGE, BackSpike=IRON)),
    dict(id="art_heavy_hewing_axe", tier=1, L=5.3, r=0.115, blade=dict(kind="axe", neck=0.42, reach=1.4, top=0.85, bot=1.05, t=0.2, sag_t=0.3, sag_b=0.32, bulge=0.07),
         back="poll_heavy", pommel="ball", finial=None, inlay=None, langets=True,
         col=dict(Handle=rgb(90, 65, 42), GripWrap=rgb(52, 38, 28), Pommel=rgb(80, 85, 92), HeadCollar=rgb(100, 105, 115), Blade=rgb(135, 140, 150), BladeEdge=rgb(215, 220, 230), BackSpike=rgb(95, 100, 110))),
    dict(id="art_canyon_splitter", tier=2, L=5.4, r=0.12, blade=dict(kind="axe", neck=0.4, reach=1.45, top=0.8, bot=1.25, t=0.22, sag_t=0.25, sag_b=0.5, bulge=0.06),
         back="spike", pommel="ring", finial=None, inlay="geode", bands=2,
         col=dict(Handle=rgb(82, 80, 88), GripWrap=rgb(60, 44, 34), Pommel=rgb(165, 120, 65), HeadCollar=rgb(180, 135, 75), Blade=rgb(120, 125, 135), BladeEdge=rgb(195, 200, 215), BackSpike=rgb(135, 140, 150), RuneInlay=rgb(185, 105, 255))),
    dict(id="art_quakestone_greataxe", tier=2, L=5.5, r=0.13, haft="hex", blade=dict(kind="axe", neck=0.4, reach=1.5, top=1.05, bot=1.3, t=0.22, bulge=0.13),
         back="spike", pommel="cap", finial="spike", inlay="chevrons", bands=2,
         col=dict(Handle=rgb(190, 150, 65), GripWrap=rgb(74, 52, 36), Pommel=rgb(170, 130, 50), HeadCollar=rgb(115, 118, 125), Blade=rgb(140, 145, 155), BladeEdge=rgb(210, 215, 225), BackSpike=rgb(125, 130, 140), RuneInlay=rgb(245, 205, 90))),
    dict(id="art_battleaxe_cleaver", tier=3, L=5.6, r=0.125, blade=dict(kind="axe", neck=0.36, reach=1.45, top=1.0, bot=1.1, t=0.22, bulge=0.12),
         back="blade", pommel="spike", finial="spear", inlay="lines", bands=3, rivets=True,
         col=dict(Handle=rgb(65, 70, 78), GripWrap=rgb(48, 36, 30), Pommel=rgb(195, 145, 60), HeadCollar=rgb(175, 125, 45), Blade=rgb(110, 115, 128), BladeEdge=rgb(215, 222, 235), BackSpike=rgb(120, 125, 138), RuneInlay=rgb(60, 210, 255))),
    dict(id="art_iron_juggernaut_cleaver", tier=3, L=5.6, r=0.135, blade=dict(kind="slab", reach=1.6, top=1.15, bot=1.35, t=0.3, neck=0.5),
         back="hammer", pommel="ball", finial=None, inlay="slots", bands=3, rivets=True, langets=True,
         col=dict(Handle=rgb(55, 58, 64), GripWrap=rgb(40, 32, 28), Pommel=rgb(75, 78, 86), HeadCollar=rgb(90, 94, 102), Blade=rgb(125, 130, 140), BladeEdge=rgb(200, 205, 218), BackSpike=rgb(85, 88, 96), RuneInlay=rgb(255, 140, 30))),
    dict(id="art_magma_behemoth", tier=4, L=5.7, r=0.14, haft="stone", blade=dict(kind="axe", neck=0.45, reach=1.7, top=1.1, bot=1.45, t=0.3, jag=0.045, bulge=0.1),
         back="spike_big", pommel="shard", finial="spike", inlay="veins", bands=2,
         col=dict(Handle=rgb(40, 38, 44), GripWrap=rgb(58, 34, 30), Pommel=rgb(30, 28, 35), HeadCollar=rgb(70, 50, 50), Blade=rgb(48, 44, 52), BladeEdge=rgb(90, 75, 85), BackSpike=rgb(35, 32, 40), RuneInlay=rgb(255, 70, 15))),
    dict(id="art_obsidian_hell_splitter", tier=4, L=5.8, r=0.135, blade=dict(kind="axe", neck=0.4, reach=1.6, top=1.15, bot=1.3, t=0.24, jag=0.06, bulge=0.08),
         back="blade", pommel="shard", finial="spear", inlay="veins_core", bands=3,
         col=dict(Handle=rgb(45, 40, 48), GripWrap=rgb(62, 36, 34), Pommel=rgb(60, 45, 50), HeadCollar=rgb(80, 55, 55), Blade=rgb(30, 28, 36), BladeEdge=rgb(150, 40, 45), BackSpike=rgb(35, 30, 38), RuneInlay=rgb(255, 180, 20))),
    dict(id="art_titan_earthshaker", tier=5, L=6.0, r=0.145, blade=dict(kind="axe", neck=0.42, reach=1.8, top=1.35, bot=1.45, t=0.26, sag_t=0.5, sag_b=0.52, bulge=0.14),
         back="blade", pommel="ornate", finial="spear_tall", inlay="rune_ring", bands=4, rivets=True,
         col=dict(Handle=rgb(235, 235, 240), GripWrap=rgb(120, 82, 46), Pommel=rgb(235, 185, 50), HeadCollar=rgb(245, 195, 60), Blade=rgb(210, 215, 225), BladeEdge=rgb(255, 220, 80), BackSpike=rgb(225, 175, 45), RuneInlay=rgb(255, 230, 110))),
    dict(id="art_mountain_breaker", tier=5, L=6.0, r=0.16, haft="stone", blade=dict(kind="monolith", reach=1.9, top=1.4, bot=1.6, t=0.42, neck=0.6),
         back="hammer_stone", pommel="ornate", finial="spike", inlay="rune_column", bands=4, langets=True,
         col=dict(Handle=rgb(85, 80, 88), GripWrap=rgb(96, 68, 40), Pommel=rgb(190, 140, 50), HeadCollar=rgb(220, 165, 55), Blade=rgb(70, 68, 75), BladeEdge=rgb(240, 190, 70), BackSpike=rgb(110, 105, 115), RuneInlay=rgb(255, 175, 40))),
    dict(id="art_valkyrie_waraxe", tier=6, L=6.1, r=0.13, haft="braided", blade=dict(kind="axe", neck=0.34, reach=1.75, top=1.6, bot=1.5, t=0.22, sag_t=0.56, sag_b=0.56, bulge=0.16, tip_top=0.8, tip_bot=0.8),
         back="wings", pommel="ornate", finial="spear_tall", inlay="teardrops", bands=5,
         col=dict(Handle=rgb(225, 230, 245), GripWrap=rgb(70, 110, 160), Pommel=rgb(245, 205, 70), HeadCollar=rgb(250, 210, 80), Blade=rgb(230, 235, 250), BladeEdge=rgb(255, 225, 95), BackSpike=rgb(235, 240, 252), RuneInlay=rgb(0, 235, 255))),
    dict(id="art_world_shaper", tier=6, L=6.2, r=0.15, blade=dict(kind="axe", neck=0.5, reach=1.9, top=1.4, bot=1.6, t=0.3, sag_t=0.36, sag_b=0.46, bulge=0.12),
         back="hammer_forge", pommel="ornate", finial="orb_ring", inlay="conduits", bands=5, rivets=True,
         col=dict(Handle=rgb(150, 160, 175), GripWrap=rgb(84, 58, 40), Pommel=rgb(225, 170, 50), HeadCollar=rgb(235, 180, 60), Blade=rgb(175, 185, 200), BladeEdge=rgb(245, 195, 75), BackSpike=rgb(215, 160, 45), RuneInlay=rgb(255, 205, 30))),
    dict(id="art_world_carver", tier=7, L=6.4, r=0.155, haft="stone", blade=dict(kind="axe", neck=0.5, reach=2.3, top=1.9, bot=2.0, t=0.3, sag_t=0.55, sag_b=0.58, bulge=0.15, jag=0.02, tip_top=0.82, tip_bot=0.78),
         back="rift_hook", pommel="shard", finial="spear_tall", inlay="rift", bands=6,
         col=dict(Handle=rgb(25, 20, 32), GripWrap=rgb(70, 50, 110), Pommel=rgb(195, 200, 218), HeadCollar=rgb(205, 210, 228), Blade=rgb(35, 28, 45), BladeEdge=rgb(220, 225, 245), BackSpike=rgb(30, 24, 38), RuneInlay=rgb(195, 70, 255))),
    dict(id="art_genesis_sunderer", tier=7, L=6.4, r=0.16, blade=dict(kind="axe", neck=0.46, reach=2.1, top=1.6, bot=1.7, t=0.3, sag_t=0.5, sag_b=0.52, bulge=0.14),
         back="quad", pommel="ornate", finial="core", inlay="genesis", bands=6, rivets=True,
         col=dict(Handle=rgb(45, 35, 60), GripWrap=rgb(120, 60, 110), Pommel=rgb(250, 200, 65), HeadCollar=rgb(255, 210, 75), Blade=rgb(65, 50, 85), BladeEdge=rgb(255, 225, 90), BackSpike=rgb(55, 42, 72), RuneInlay=rgb(255, 100, 180))),
]


# --------------------------------------------------------------------------------------
# Weapon assembly
# --------------------------------------------------------------------------------------
def build_blade_outline(b, z0, res, rng):
    if b["kind"] == "axe":
        return axe_outline(z0, b["neck"], b["reach"], b["top"], b["bot"], res, tip_top=b.get("tip_top", 0.9), tip_bot=b.get("tip_bot", 0.86),
                           bulge=b.get("bulge", 0.1), sag_t=b.get("sag_t", 0.42), sag_b=b.get("sag_b", 0.48), jag=b.get("jag", 0.0), rng=rng)
    R, top, bot, neck = b["reach"], b["top"], b["bot"], b["neck"]
    if b["kind"] == "slab":  # executioner: square top, raked chin
        rel = [(-0.02, neck), (R * 0.22, top), (R * 0.96, top * 0.92), (R, -bot * 0.62), (R * 0.72, -bot), (R * 0.3, -bot * 0.5), (-0.02, -neck)]
        return poly_outline(z0, rel, (2, 4), res)
    # monolith: a chunky hewn stone wedge
    rel = [(-0.02, neck), (R * 0.3, top), (R * 0.88, top * 0.78), (R, top * 0.1), (R * 0.94, -bot * 0.8), (R * 0.42, -bot), (R * 0.2, -bot * 0.55), (-0.02, -neck)]
    return poly_outline(z0, rel, (2, 4), res)


def add_blade(parts, spec, z0, res, rng, M, into="Blade", scale=1.0, inlay=True):
    b = dict(spec["blade"])
    for k in ("neck", "reach", "top", "bot"):
        b[k] = b[k] * scale
    pts, (e0, e1) = build_blade_outline(b, z0, res, rng)
    t = b["t"]
    inset = min(0.34, b["reach"] * 0.2)
    plate(parts[into], pts, t, inset, M)
    centre = V2(b["reach"] * 0.45, z0)
    w = inset * 0.55
    edge_strip(parts["BladeEdge"], pts[e0:e1 + 1], centre, w, t * min(1.0, w / inset) + 0.035, M)
    if inlay:
        add_inlay(parts, spec, b, z0, rng, M)
    return pts, (e0, e1), b


def add_inlay(parts, spec, b, z0, rng, M):
    kind, P, t, R = spec.get("inlay"), parts["RuneInlay"], b["t"], b["reach"]
    top, bot, neck = b["top"], b["bot"], b["neck"]
    if kind == "chevrons":
        for i in range(3):
            u = R * (0.3 + 0.16 * i)
            h = 0.16 + 0.07 * i
            stroke(P, V2(u, z0 + h), V2(u + 0.14, z0), 0.05, t, M)
            stroke(P, V2(u + 0.14, z0), V2(u, z0 - h), 0.05, t, M)
    elif kind == "lines":
        for dz in (0.2, 0.0, -0.2):
            stroke(P, V2(R * 0.24, z0 + dz * 0.6), V2(R * 0.66, z0 + dz * 1.9), 0.045, t, M)
    elif kind == "slots":
        for i in range(4):
            dz = 0.55 - i * 0.42
            stroke(P, V2(R * 0.34, z0 + dz), V2(R * 0.72, z0 + dz - 0.12), 0.09, t, M)
    elif kind in ("veins", "veins_core", "rift"):
        n = {"veins": 7, "veins_core": 6, "rift": 9}[kind]
        for i in range(n):
            s = (i + 0.5) / n
            dz = (top * 0.62) * (1 - s) - (bot * 0.62) * s
            vein(P, V2(R * 0.14, z0 + dz * 0.3), V2(R * 0.74, z0 + dz), 0.075 if kind != "rift" else 0.06, t, rng, 5, 0.07, M)
        if kind == "rift":  # one long fissure following the edge
            prev = None
            for i in range(9):
                s = i / 8
                p = V2(R * (0.62 + 0.1 * math.sin(math.pi * s)), z0 + top * 0.7 - (top + bot) * 0.7 * s)
                if prev:
                    stroke(P, prev, p, 0.09, t, M)
                prev = p
    elif kind in ("rune_ring", "genesis"):
        n = 9 if kind == "rune_ring" else 11
        for i in range(n):  # glyph ticks on an arc that follows the edge
            s = (i + 0.5) / n
            ang = math.radians(-62 + 124 * s)
            c = V2(R * 0.08 + R * 0.56 * math.cos(ang), z0 + (top if ang > 0 else bot) * 0.62 * math.sin(ang))
            d = V2(math.cos(ang), math.sin(ang))
            nrm = V2(-d.y, d.x)
            stroke(P, c - d * 0.09, c + d * 0.09, 0.05, t, M)
            if i % 2 == 0:
                stroke(P, c + d * 0.09 - nrm * 0.07, c + d * 0.09 + nrm * 0.07, 0.045, t, M)
            else:
                stroke(P, c - nrm * 0.08, c + nrm * 0.02 - d * 0.06, 0.04, t, M)
        prev = None
        for i in range(13):  # inner arc line
            ang = math.radians(-58 + 116 * i / 12)
            p = V2(R * 0.06 + R * 0.4 * math.cos(ang), z0 + (top if ang > 0 else bot) * 0.46 * math.sin(ang))
            if prev:
                stroke(P, prev, p, 0.04, t, M)
            prev = p
    elif kind == "rune_column":
        for i in range(5):
            dz = 0.8 - i * 0.42
            u = R * 0.5
            stroke(P, V2(u - 0.16, z0 + dz), V2(u + 0.16, z0 + dz), 0.06, t, M)
            stroke(P, V2(u + (0.16 if i % 2 else -0.16), z0 + dz), V2(u + (0.16 if i % 2 else -0.16), z0 + dz - 0.24), 0.06, t, M)
            if i % 2 == 0:
                stroke(P, V2(u, z0 + dz - 0.08), V2(u + 0.12, z0 + dz - 0.2), 0.05, t, M)
    elif kind == "teardrops":
        for dz, r in ((0.0, 0.11), (top * 0.42, 0.075), (-bot * 0.42, 0.075)):
            for side in (1, -1):
                T = M @ Matrix.Translation(Vector((R * 0.38, side * t / 2, z0 + dz))) @ Matrix.Rotation(math.pi / 2, 4, "Y")
                lathe(P, [(0, -r * 1.9), (r * 0.6, -r * 0.8), (r, 0), (r * 0.7, r * 0.7), (0, r)], 8, T, sy=0.5)
        stroke(P, V2(R * 0.16, z0), V2(R * 0.3, z0), 0.035, t, M)
    elif kind == "conduits":
        for dz in (0.38, 0.0, -0.38):
            stroke(P, V2(R * 0.12, z0 + dz * 0.5), V2(R * 0.5, z0 + dz * 1.5), 0.06, t, M)
            stroke(P, V2(R * 0.5, z0 + dz * 1.5), V2(R * 0.7, z0 + dz * 1.5), 0.06, t, M)


def build_weapon(spec):
    tier, L, r = spec["tier"], spec["L"], spec["r"]
    rng = random.Random(hash(spec["id"]) & 0xFFFF)
    rng = random.Random(sum(ord(c) for c in spec["id"]))
    b = spec["blade"]
    res = 4 + 2 * tier
    segs = {"hex": 6, "stone": 7}.get(spec.get("haft"), 8 + 2 * (tier // 2))
    parts = {n: Part() for n in ("Handle", "GripWrap", "Pommel", "HeadCollar", "Blade", "BladeEdge", "BackSpike", "RuneInlay")}
    half = L / 2
    z0 = half - max(b["top"] * 0.62, b["neck"] + 0.22)  # head centre
    grip_z = z0 - b["bot"] - 0.5
    off_z = grip_z - HAND_GAP

    # Haft ------------------------------------------------------------------------------
    H = parts["Handle"]
    haft = spec.get("haft", "round")
    if haft == "braided":
        prof, n = [], 46
        for i in range(n + 1):
            z = -half + L * i / n
            prof.append((r * (0.9 + 0.14 * (i % 2)), z))
        lathe(H, prof, segs)
    elif haft == "stone":
        prof, n = [], 12
        for i in range(n + 1):
            z = -half + L * i / n
            prof.append((r * rng.uniform(0.9, 1.1), z))
        lathe(H, prof, segs, phase=0.3)
    else:
        lathe(H, [(r * 0.92, -half), (r, -half + 0.4), (r * 0.94, 0.0), (r, z0 - b["neck"]), (r * 0.96, half)], segs)

    # Grip wraps under each hand: ribbed leather sleeves --------------------------------
    G = parts["GripWrap"]
    for gz, length in ((grip_z, 0.66), (off_z, 0.66)):
        prof, ribs = [], 6 + tier
        prof.append((r * 1.02, gz - length / 2 - 0.03))
        for i in range(ribs * 2 + 1):
            prof.append((r * (1.2 if i % 2 else 1.1), gz - length / 2 + length * i / (ribs * 2)))
        prof.append((r * 1.02, gz + length / 2 + 0.03))
        lathe(G, prof, max(8, segs))

    # Pommel ----------------------------------------------------------------------------
    P = parts["Pommel"]
    kind = spec["pommel"]
    zb = -half
    if kind == "cap":
        lathe(P, [(0, zb - 0.16), (r * 1.3, zb - 0.1), (r * 1.5, zb + 0.02), (r * 1.25, zb + 0.16), (r * 1.02, zb + 0.2)], max(8, segs))
    elif kind == "ball":
        sphere(P, (0, 0, zb - 0.06), r * 1.75, max(8, segs), 6)
        lathe(P, [(r * 1.35, zb + 0.02), (r * 1.35, zb + 0.16), (r * 1.02, zb + 0.2)], max(8, segs))
    elif kind == "ring":
        torus(P, r * 1.9, r * 0.55, 14, 6, Matrix.Translation(Vector((0, 0, zb - r * 1.9))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
        lathe(P, [(r * 1.4, zb - 0.04), (r * 1.4, zb + 0.14), (r * 1.02, zb + 0.18)], max(8, segs))
    elif kind == "spike":
        lathe(P, [(0, zb - 0.55), (r * 0.9, zb - 0.18), (r * 1.6, zb - 0.05), (r * 1.6, zb + 0.08), (r * 1.05, zb + 0.2)], max(8, segs))
    elif kind == "shard":
        gem(P, (0, 0, zb - 0.12), r * 1.7, 0.75, 6, I4, (math.pi, 0.0))
        lathe(P, [(r * 1.45, zb - 0.02), (r * 1.3, zb + 0.18), (r * 1.02, zb + 0.22)], max(8, segs))
    else:  # ornate: flared cap, collar ring and a butt spike
        lathe(P, [(0, zb - 0.6), (r * 0.7, zb - 0.3), (r * 1.9, zb - 0.16), (r * 2.0, zb - 0.06), (r * 1.3, zb + 0.04), (r * 1.5, zb + 0.14), (r * 1.05, zb + 0.26)], max(10, segs))
        torus(P, r * 1.75, r * 0.3, 16, 6, Matrix.Translation(Vector((0, 0, zb + 0.14))))

    # Head collar, bands, langets, rivets -----------------------------------------------
    C = parts["HeadCollar"]
    neck = b["neck"]
    eye = r * (1.75 + 0.06 * tier)
    lathe(C, [(r * 1.05, z0 - neck - 0.2), (eye * 0.92, z0 - neck - 0.08), (eye, z0 - neck * 0.5), (eye, z0 + neck * 0.5), (eye * 0.92, z0 + neck + 0.08), (r * 1.05, z0 + neck + 0.2)],
          max(8, segs), sy=0.92)
    n_bands = spec.get("bands", 1)
    for i in range(n_bands):  # reinforcing bands down the haft, clear of both hands
        zs = [z0 - neck - 0.42, (grip_z + off_z) / 2, off_z - 0.62, grip_z + 0.52, off_z - 0.95, -half + 0.42]
        z = zs[i % len(zs)]
        lathe(C, [(r * 1.04, z - 0.09), (r * 1.3, z - 0.05), (r * 1.3, z + 0.05), (r * 1.04, z + 0.09)], max(8, segs))
    if spec.get("langets"):
        for side in (1, -1):
            box(C, (0, side * r * 1.02, z0 - neck - 0.62), (r * 0.9, 0.05, 0.95))
    if spec.get("rivets"):
        for side in (1, -1):
            for dz in (-neck * 0.55, 0.0, neck * 0.55):
                sphere(C, (0, side * eye * 0.92, z0 + dz), 0.05 + 0.004 * tier, 6, 4)

    # Main blade (-X) ---------------------------------------------------------------------
    pts, (e0, e1), _ = add_blade(parts, spec, z0, res, rng, MIRROR_X)
    tip, base = pts[e0], pts[e1]

    # Back of the head (+X) ---------------------------------------------------------------
    S = parts["BackSpike"]
    back = spec["back"]
    if back in ("poll", "poll_heavy"):
        w = 0.3 if back == "poll" else 0.5
        box(S, (r + w / 2, 0, z0), (w, r * 2.3, neck * (1.3 if back == "poll" else 1.7)))
        box(S, (r + w + 0.04, 0, z0), (0.08, r * 2.7, neck * (1.5 if back == "poll" else 1.95)))
    elif back in ("spike", "spike_big"):
        k = 1.0 if back == "spike" else 1.6
        outline = [V2(-0.02, z0 + neck * 0.8), V2(0.45 * k, z0 + neck * 0.5), V2(0.95 * k, z0 - neck * 0.5 * k), V2(0.4 * k, z0 - neck * 0.35), V2(-0.02, z0 - neck * 0.8)]
        plate(S, outline, b["t"] * 0.9, 0.12)
    elif back in ("hammer", "hammer_stone", "hammer_forge"):
        w, hgt, dep = (0.62, neck * 2.0, r * 3.6) if back == "hammer" else (0.75, neck * 2.1, r * 4.2)
        box(S, (r + w * 0.3, 0, z0), (w * 0.6, dep * 0.7, hgt * 0.7))
        box(S, (r + w * 0.8, 0, z0), (w * 0.5, dep, hgt))
        if back == "hammer_forge":
            for dy in (-1, 1):
                for dz in (-1, 1):
                    gem(S, (r + w * 1.05, dy * dep * 0.3, z0 + dz * hgt * 0.3), 0.09, 0.3, 4, I4, (0, math.pi / 2))
    elif back == "blade":
        add_blade(parts, spec, z0, res, rng, I4, into="BackSpike")
    elif back == "wings":
        for i, (ang, ln, wd) in enumerate(((62, 1.75, 0.5), (36, 1.45, 0.44), (10, 1.1, 0.38), (-22, 0.8, 0.3))):
            plate(S, leaf(V2(0.02, z0 + 0.12 - i * 0.14), math.radians(ang), ln, wd, 6 + tier), 0.1, 0.09, neck_u=0.1)
    elif back == "rift_hook":
        outline = [V2(-0.02, z0 + neck), V2(0.7, z0 + neck * 1.5), V2(1.55, z0 + neck * 0.2), V2(1.2, z0 - neck * 1.9), V2(0.75, z0 - neck * 0.5), V2(-0.02, z0 - neck)]
        plate(S, outline, b["t"], 0.16)
        for i in range(5):  # shards torn loose, drifting off the back of the head
            gem(S, (1.5 + 0.22 * i + rng.uniform(-0.1, 0.1), rng.uniform(-0.12, 0.12), z0 + 1.1 - 0.62 * i), 0.1 + 0.02 * (i % 3), 0.5 + 0.12 * (i % 2), 5, I4,
                (rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6)))
    elif back == "quad":
        add_blade(parts, spec, z0, res, rng, I4, into="BackSpike")
        for sign in (1, -1):  # two lesser blades across the haft
            add_blade(parts, spec, z0, res, rng, Matrix.Rotation(sign * math.pi / 2, 4, "Z"), into="BackSpike", scale=0.62, inlay=False)

    # Finial ------------------------------------------------------------------------------
    fin = spec.get("finial")
    if fin == "spike":
        lathe(S, [(r * 1.25, half - 0.03), (r * 1.25, half + 0.05), (0, half + 0.5)], max(6, segs))
    elif fin in ("spear", "spear_tall"):
        h = 0.95 if fin == "spear" else 1.4
        lathe(C, [(r * 1.05, half - 0.06), (r * 1.5, half), (r * 1.1, half + 0.1)], max(8, segs))
        plate(S, [V2(0, half + 0.02), V2(0.2, half + h * 0.3), V2(0, half + h), V2(-0.2, half + h * 0.3)], 0.12, 0.09, neck_u=0.01)
    elif fin == "orb_ring":
        zc = half + 0.55
        torus(C, 0.46, 0.07, 20, 6, Matrix.Translation(Vector((0, 0, zc))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
        lathe(C, [(r * 1.05, half - 0.06), (r * 1.6, half + 0.02), (r * 0.8, half + 0.1)], max(8, segs))
        sphere(parts["RuneInlay"], (0, 0, zc), 0.26, 12, 8)
        for i in range(3):  # brass conduit rings floating down the haft below the head
            torus(C, r * 2.4 + 0.05 * i, 0.045, 18, 6, Matrix.Translation(Vector((0, 0, z0 - neck - 0.5 - 0.3 * i))))
    elif fin == "core":
        zc = half + 0.5
        lathe(C, [(r * 1.05, half - 0.06), (r * 1.7, half + 0.02), (r * 0.9, half + 0.12)], max(8, segs))
        sphere(parts["RuneInlay"], (0, 0, zc), 0.3, 14, 9)
        torus(C, 0.48, 0.045, 24, 6, Matrix.Translation(Vector((0, 0, zc))) @ Matrix.Rotation(math.radians(64), 4, "X"))
        torus(C, 0.58, 0.04, 24, 6, Matrix.Translation(Vector((0, 0, zc))) @ Matrix.Rotation(math.radians(64), 4, "Y"))

    # Whole-head inlays that are not tied to one blade -------------------------------------
    R = parts["RuneInlay"]
    inlay = spec.get("inlay")
    if inlay == "geode":  # raw amethyst chips bedded along the spine of the head
        for i in range(6):
            s = i / 5
            p = bezier(V2(0.02, z0 + neck), V2(b["reach"] * 0.5, z0 + neck + (b["top"] - neck) * 0.2), V2(b["reach"] * 0.8, z0 + b["top"]), 5)[i]
            gem(R, (-p.x, 0, p.y + 0.02), 0.085 + 0.03 * ((i * 7) % 3) / 2, 0.36 + 0.1 * (i % 2), 5, I4, (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5)))
    if inlay in ("lines", "veins_core", "rune_ring", "genesis", "teardrops"):  # gem set in each cheek of the eye
        for side in (1, -1):
            gem(R, (0, side * eye * 0.9, z0), 0.1 + 0.012 * tier, 0.26, 6, I4, (side * -math.pi / 2, 0))
    if inlay in ("rift", "genesis"):  # glowing band where the haft meets the head
        lathe(R, [(r * 1.12, z0 - neck - 0.34), (r * 1.22, z0 - neck - 0.3), (r * 1.12, z0 - neck - 0.26)], max(8, segs))

    info = dict(
        id=spec["id"], tier=tier, haft_length=L,
        grip=[0, 0, grip_z], offhand=[0, 0, off_z],
        tip=[-tip.x, 0, tip.y], base=[-base.x, 0, base.y], core=[-b["reach"] * 0.45, 0, z0],
    )
    return parts, info


# --------------------------------------------------------------------------------------
# Scene output
# --------------------------------------------------------------------------------------
def material(name, color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def realise(spec, parts, offset_x=0.0):
    coll = bpy.data.collections.new(spec["id"])
    bpy.context.scene.collection.children.link(coll)
    objs, tris, names = [], 0, []
    for name, part in parts.items():
        if part.empty:
            part.bm.free()
            continue
        bm = part.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for face in bm.faces:
            face.smooth = True
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(32):
                e.smooth = False
        me = bpy.data.meshes.new(f"{spec['id']}_{name}")
        bm.to_mesh(me)
        tris += len(bm.faces)
        bm.free()
        me.materials.append(material(f"{spec['id']}_{name}", spec["col"].get(name, (0.6, 0.6, 0.6, 1))))
        obj = bpy.data.objects.new(name, me)
        obj.location.x = offset_x
        coll.objects.link(obj)
        objs.append(obj)
        names.append(name)
    return objs, tris, names


def export_fbx(spec, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path = os.path.join(OUT_DIR, spec["id"] + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, mesh_smooth_type="EDGE",
                             add_leaf_bones=False, bake_anim=False, use_mesh_modifiers=True)
    return path


def render_preview(path, width_units, height_units):
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = width_units
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = (width_units / 2 - 2.6, -30, 0.25)
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 2800
    scene.render.resolution_y = int(2800 * height_units / width_units)
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("W")
    scene.world.color = (0.22, 0.23, 0.26)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    preview = argv[argv.index("--preview") + 1] if "--preview" in argv else None
    only = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None

    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    os.makedirs(OUT_DIR, exist_ok=True)

    manifest, spacing, built = {}, 5.2, 0
    for spec in SPECS:
        if only and spec["id"] not in only:
            continue
        parts, info = build_weapon(spec)
        objs, tris, names = realise(spec, parts)
        export_fbx(spec, objs)
        for o in objs:  # lay the row out for the contact sheet after exporting at the origin
            o.location.x = built * spacing
            o.name = f"{spec['id']}_{o.name}"  # frees the bare part name for the next axe's export
        info["parts"], info["tris"] = names, tris
        manifest[spec["id"]] = info
        print(f"[greataxe] {spec['id']:32s} tier {spec['tier']} tris {tris:6d} parts {len(names)} grip z {info['grip'][2]:.2f} offhand z {info['offhand'][2]:.2f}")
        built += 1

    if not only:
        with open(os.path.join(OUT_DIR, "greataxes_manifest.json"), "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, indent="\t")
    if preview:
        render_preview(preview, built * spacing, 9.2)


main()
