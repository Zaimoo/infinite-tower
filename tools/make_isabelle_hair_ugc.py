"""
Isabelle's hair, UGC-accessory style (run inside Blender: exec(open(path, encoding="utf-8").read())).

From her reference art: straight platinum-blonde hair with a blunt, eyebrow-length fringe cut
straight across, long locks framing the face (longer on her left, to the collar), and
everything else falling to the nape and gathered behind her right ear into one thick plaited
braid that hangs behind her right shoulder down her back to the waist. Built UGC style: thick,
rounded clumps that taper to soft points (a fringe of staggered clumps over a second layer,
fuller framing clumps, a pointed back layer) over a lightly grooved base sheet. The braid's gilt cuff is a costume piece (BraidCuff), not part of
this mesh. Textured with assets/hair/isabelle_hair_texture.png
(assets/hair/make_isabelle_hair_texture.py): every lock, every braid plait and the braid's core
are mapped along their own length (V from 1 at the root to 0 at the tip, U across, a random slice
per lock), so the strand lines follow the hair; the base sheet maps V down from the crown.

Derived from tools/make_aeli_hair_ugc.py (ponytail/braid base, docs/hero-art-pipeline.md 4.4):
the same helpers and stylised braid (stacked teardrop lobes over a filled core), with the braid
turned to face forward. Roblox head space (Y up, -Z front, +X the hero's right) on a 1.2-stud
reference head. Export with the hero-remodel skill's scripts/blender_export_hair.py.
"""

import bpy, bmesh, math, os, random
from mathutils import Vector

OUT_DIR = r"D:\Programming shi\infinite-tower\assets\hair"
NAME = "IsabelleHair"
rng = random.Random(2027)

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
RX, RY, RZ = 0.7, 0.76, 0.71

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

# --- Scalp cap: full coverage under the locks; the face opening stops at the hairline ------
def cap():
    rings, segs = 22, 44
    verts = {}
    for i in range(rings + 1):
        y = CY + RY - (RY + 0.95) * i / rings
        for j in range(segs):
            th = 2 * math.pi * j / segs
            c = math.cos(th)
            if c > 0.2:
                limit = -0.14 + 0.46 * min(1.0, (c - 0.2) / 0.55) ** 1.4
            else:
                limit = -0.14 - 0.12 * min(1.0, (0.2 - c) / 0.8)
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
# A plump, rounded clump profile (UGC hair reads as thick soft clumps, not flat strips).
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

# Texture coordinates per vertex, filled as the hair is built (VERT_UV), then written to the
# loops before vertices are merged. PROFILE_U places each profile point across a lock; each lock
# uses its own slice of the texture so neighbours don't match.
VERT_UV = {}
PROFILE_U = [1.0, 0.86, 0.5, 0.14, 0.0, 0.19, 0.5, 0.81]
uv_rng = random.Random(778)  # separate from rng, so texture choices never change the shape

def zigzag(x):
    """0..1 back and forth (continuous, so a wrapped strip has no seam)."""
    return 0.02 + 0.96 * abs((x % 2) - 1)

def ribbon(ctrl, width, thick=0.035, segs=16, tip=2.5, root=0.6, end_tie=False, twist=0.0):
    pts = smooth_path(ctrl, segs)
    u_lo = uv_rng.uniform(0.02, 0.5)
    rings = []
    for s, p in enumerate(pts):
        t = s / segs
        a = pts[max(0, s - 1)]; b = pts[min(segs, s + 1)]
        tan = (b - a).normalized()
        nrm = out_normal(p)
        side = tan.cross(nrm)
        if side.length < 1e-5:
            side = tan.cross(Vector((0, 0, 1)))
        side.normalize()
        nrm = side.cross(tan).normalized()
        ang = twist * t
        side, nrm = side * math.cos(ang) + nrm * math.sin(ang), nrm * math.cos(ang) - side * math.sin(ang)
        grow = root + (1 - root) * min(1.0, t / 0.18)
        if end_tie:
            shape = grow * (1 - 0.7 * t ** 2)  # gathers into the tie instead of a point
        else:
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

def jitter(v, a=0.03):
    return Vector(v) + Vector((rng.uniform(-a, a), rng.uniform(-a, a), rng.uniform(-a, a)))

def lock(pts, width, thick=0.036, segs=14, tip=2.6, end_tie=False, twist=0.0):
    ribbon([jitter(p, 0.01) for p in pts], width, thick, segs=segs, tip=tip, root=0.7, end_tie=end_tie, twist=twist)

# Where the back hair gathers into the braid: low behind her right ear.
GATHER = Vector((0.36, -0.46, 0.52))

def curtain(th0, th1, y_top, y_end, off_top, off_bot, thick=0.045, nth=72, ny=12, grooves=17, depth=0.014):
    """A blunt-cut sheet of hair over the scalp between azimuths th0..th1: from y_top down to
    y_end(theta), standing off the head from off_top to off_bot. Shallow vertical grooves give
    it strand clumps, and the bottom edge is cut straight (the anime 'hime' fringe), which
    separate ribbon locks can't do without a sawtooth edge."""
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
    for i in range(nth):  # top and bottom edges
        bm.faces.new([outer[i][0], inner[i][0], inner[i + 1][0], outer[i + 1][0]])
        bm.faces.new([outer[i + 1][ny], inner[i + 1][ny], inner[i][ny], outer[i][ny]])
    for j in range(ny):  # side edges
        bm.faces.new([outer[0][j + 1], inner[0][j + 1], inner[0][j], outer[0][j]])
        bm.faces.new([outer[nth][j], inner[nth][j], inner[nth][j + 1], outer[nth][j + 1]])

# 1. Base sheet: a smooth, lightly grooved shell over the whole head that stops above the
#    fringe in front and hangs to the nape at the sides and back. The clumps below sit on it, so
#    no scalp shows between them.
FRONT = math.radians(76)

def hem(th):
    a = abs(th)
    if a <= FRONT:
        return 0.5
    t = min(1.0, (a - FRONT) / math.radians(30))
    t = t * t * (3 - 2 * t)
    return 0.5 + (-0.42 - 0.5) * t

curtain(-math.pi, math.pi, 0.915, hem, 0.05, 0.08, thick=0.04, nth=64, ny=8, grooves=26, depth=0.01)

def clump(pts, width, thick=0.06, segs=14, tip=3.2, twist=0.0):
    """One UGC-style hair clump: thick and rounded, keeping its width most of the way and
    narrowing to a soft point at the end."""
    ribbon([jitter(p, 0.004) for p in pts], width, thick, segs=segs, tip=tip, root=0.75, twist=twist)

crown = bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=0.1)
for v in crown["verts"]:
    v.co = B(Vector((v.co.x * 1.4, v.co.z * 0.5, v.co.y * 1.4)) + shell(0, CY + RY, 0.0) + Vector((0, -0.01, 0.02)))

# 2. Fringe: thick clumps from the front of the crown, arching over the forehead and tucking in
#    toward it at the tips, which sit just above the brows (the decal's brows are near y 0.1).
#    Shorter in the middle and longer toward the temples, like UGC hime bangs, with the tip
#    heights staggered. A second, narrower layer behind, offset by half a clump, fills the gaps.
for k, th_deg in enumerate(range(-66, 67, 12)):
    th = math.radians(th_deg + rng.uniform(-1.5, 1.5))
    edge = abs(th_deg) / 66
    y_end = 0.14 - 0.07 * edge ** 2 + (0.012 if k % 2 else -0.004)
    lean = math.radians(3) * (1 if th_deg > 0 else -1 if th_deg < 0 else 0)
    pts = [shell(th * 0.3, 0.86, -0.01), shell(th * 0.7, 0.74, 0.06), shell(th * 0.95, 0.52, 0.1),
           shell(th + lean, (0.52 + y_end) / 2, 0.1), shell(th + lean * 1.6, y_end, 0.07)]
    clump(pts, 0.17, 0.06, segs=14, tip=5.0)
for th_deg in range(-60, 61, 12):
    th = math.radians(th_deg)
    edge = abs(th_deg) / 64
    y_end = 0.19 - 0.1 * edge ** 2
    pts = [shell(th * 0.3, 0.84, -0.02), shell(th * 0.7, 0.72, 0.04), shell(th * 0.95, 0.5, 0.075), shell(th, y_end, 0.055)]
    clump(pts, 0.13, 0.045, segs=12, tip=4.0)

# 3. Face-framing clumps: from the temples, falling in front of the ears, curving in a little
#    toward the jaw and ending in soft points. Her right side ends past the jaw; her left
#    falls to the collar (as in the art). Two per side, the outer one longer.
for side, y_end in [(1, -0.62), (-1, -0.82)]:
    for th_deg, w, dy, off in [(64, 0.2, 0.0, 0.09), (80, 0.21, -0.12, 0.105)]:
        th = math.radians(th_deg) * side
        pts = [shell(th * 0.85, 0.55, off - 0.03), shell(th, 0.22, off + 0.01), shell(th, -0.1, off + 0.03),
               shell(th * 0.97, (y_end + dy) * 0.7, off + 0.02), shell(th * 0.93, y_end + dy, off - 0.01)]
        clump(pts, w, 0.065, segs=15, tip=2.3, twist=0.08 * side)

# 4. Back layer: clumps from the crown down the back of the head, each varying in width, depth,
#    point and sway. On the braid's side and across the middle they fall straight, then curve
#    and draw together into the braid's root (ending inside its first plaits), so the braid
#    grows out of the hair instead of sitting beside it, with the volume of hair pulled into it.
#    On her far (left) side they end in staggered points at the nape. Depth alternates so
#    neighbours overlap cleanly.
GATHER_TH = math.radians(145)
INTO_BRAID = GATHER + Vector((0.04, -0.14, 0.04))
for k, th_deg in enumerate(range(94, 267, 15)):
    th = math.radians(th_deg + rng.uniform(-3, 3))
    off = 0.09 + (0.022 if k % 2 else 0.0) + rng.uniform(-0.005, 0.01)
    sway = rng.uniform(-0.05, 0.05)
    head = [shell(th * 0.5 + math.pi * 0.5, 0.93, 0.03), shell(th, 0.8, off), shell(th + sway, 0.55, off + 0.01),
            shell(th - sway * 0.5, 0.2, off + 0.01)]
    if th_deg <= 214:
        # Ends land in order across the braid's root (her right side to the right of it), so
        # no two clumps cross; clumps from further away ride a little higher so they lie over
        # the nearer ones instead of passing through them.
        i = (th_deg - 94) / (214 - 94)
        pull = GATHER_TH - th
        layer = 0.035 * min(1.0, abs(pull) / math.radians(70))
        end = INTO_BRAID + Vector((0.07 - 0.14 * i, 0.03 * abs(0.5 - i), 0.02 + layer))
        bend = shell(th + pull * 0.3, -0.12, off + 0.03 + layer)
        near = shell(th + pull * 0.7, -0.36, off + 0.06 + layer).lerp(end, 0.5)
        ribbon(head + [bend, near, end], rng.uniform(0.15, 0.19), rng.uniform(0.05, 0.06), segs=18, root=0.75, end_tie=True)
    else:
        y_end = rng.uniform(-0.6, -0.36)
        drift = (GATHER_TH - th) * rng.uniform(0.06, 0.14)
        pts = head + [shell(th + drift * 0.5, -0.1, off + 0.01), shell(th + drift, (y_end - 0.05) * 0.8, off + 0.02),
                      shell(th + drift * 1.2, y_end, off + rng.uniform(0.03, 0.07))]
        clump(pts, rng.uniform(0.14, 0.2), rng.uniform(0.05, 0.065), segs=14, tip=rng.uniform(2.0, 3.0))

# 5. A shorter top layer over the back of the crown, set between the long clumps and ending at
#    different heights, for the layered UGC look.
for th_deg in range(110, 251, 28):
    th = math.radians(th_deg + rng.uniform(-6, 6))
    y_end = rng.uniform(-0.05, 0.28)
    pts = [shell(th * 0.5 + math.pi * 0.5, 0.92, 0.05), shell(th, 0.76, 0.13), shell(th, 0.45, 0.145),
           shell(th + rng.uniform(-0.06, 0.06), y_end, 0.15)]
    clump(pts, rng.uniform(0.13, 0.17), 0.055, segs=12, tip=rng.uniform(2.0, 2.6))

# --- Braid -----------------------------------------------------------------------------------
# Centre line: out of the gather at the back of her neck, behind her right shoulder, then
# hanging down her back to the waist, outside the coat and the quiver (which sits further to
# her left). Head space, 1.2-stud units: the shoulders are about 0.7 below the head centre and
# the waist about 2.0 below; the back of the coat is at z ~0.35.
BRAID_PATH = [GATHER, Vector((0.48, -0.66, 0.6)), Vector((0.58, -0.98, 0.72)),
              Vector((0.62, -1.42, 0.76)), Vector((0.62, -1.8, 0.75))]
BRAID_END = Vector((0.62, -1.98, 0.74))  # the gilt cuff sits here (costume piece BraidCuff)

def braid(path, end, width0=0.5, width1=0.16, spacing=0.14, slant=34.0, facing=(0.4, 0, 1)):
    """A plaited braid as stacked plump lobes, the stylised UGC/anime braid of the art: each
    plait is a teardrop that slants down from one edge into the middle, the lobes alternate
    left and right and overlap the one above, so the outer face reads as a herringbone of Vs.
    A filled core behind them keeps any gap between lobes from showing through."""
    centre = smooth_path(path + [end], 120)
    s = [0.0]
    for a, b in zip(centre, centre[1:]):
        s.append(s[-1] + (b - a).length)
    total = s[-1]
    def at(dist):
        for i in range(1, len(s)):
            if s[i] >= dist:
                f = (dist - s[i - 1]) / max(1e-9, s[i] - s[i - 1])
                return centre[i - 1].lerp(centre[i], f), (centre[i] - centre[i - 1]).normalized()
        return centre[-1], (centre[-1] - centre[-2]).normalized()
    def frame(tan):
        # Face the plait outward, away from the body (facing: +Z back, -Z front).
        out = Vector(facing).normalized()
        out = (out - tan * out.dot(tan)).normalized()
        return out, tan.cross(out).normalized()

    # Core: a plain tube along the centre line, a little narrower than the lobes.
    rings, n, sides = [], 60, 8
    for k in range(n + 1):
        d = total * k / n
        c, tan = at(d)
        out, side = frame(tan)
        w = width1 + (width0 - width1) * (1 - d / total) ** 1.5  # full at the root, thinning to the tie
        r = 0.24 * w * (1 - 0.35 * max(0.0, (d / total - 0.94) / 0.06))
        ring = [bm.verts.new(B(c + side * (math.cos(2 * math.pi * j / sides) * r * 1.2)
                               + out * (math.sin(2 * math.pi * j / sides) * r * 0.8))) for j in range(sides)]
        for j, vert in enumerate(ring):
            VERT_UV[vert] = (zigzag(2 * j / sides), 0.98 - 0.96 * d / total)
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(sides):
            bm.faces.new([r0[j], r0[(j + 1) % sides], r1[(j + 1) % sides], r1[j]])
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])

    # Lobes.
    count = int((total - 0.1) / spacing)
    a_s = math.radians(slant)
    for k in range(count):
        d = 0.08 + k * spacing
        c, tan = at(d)
        out, side = frame(tan)
        w = width1 + (width0 - width1) * (1 - d / total) ** 1.5  # full at the root, thinning to the tie
        sgn = 1 if k % 2 == 0 else -1
        # Long axis runs down the braid and in toward the middle; the lobe sits on its own side.
        L = (tan * math.cos(a_s) - side * sgn * math.sin(a_s)).normalized()
        Wd = L.cross(out).normalized()
        half_len = spacing * 1.35
        half_w = 0.29 * w
        half_d = 0.21 * w
        centre_pt = c + side * sgn * 0.2 * w + out * 0.06 * w
        # A teardrop: rounder at the outer, upper end and tapering into the middle.
        segs_l, segs_r = 7, 8
        grid = []
        u_lo = uv_rng.uniform(0.02, 0.5)
        for i in range(segs_l + 1):
            v = i / segs_l                      # 0 top (outer edge) -> 1 bottom (middle)
            along = (v - 0.5) * 2 * half_len
            prof = math.sin(math.pi * min(0.999, max(0.001, v))) ** 0.5 * (1.1 - 0.25 * v)
            ring = []
            for j in range(segs_r):
                a = 2 * math.pi * j / segs_r
                pnt = centre_pt + L * along + Wd * (math.cos(a) * half_w * prof) + out * (math.sin(a) * half_d * prof)
                vert = bm.verts.new(B(pnt))
                # Each plait: strands across it, and its place along the braid sets the shade.
                VERT_UV[vert] = (u_lo + 0.46 * zigzag(2 * j / segs_r), max(0.02, 0.98 - 0.96 * min(1.0, (d + along) / total)))
                ring.append(vert)
            grid.append(ring)
        for r0, r1 in zip(grid, grid[1:]):
            for j in range(segs_r):
                bm.faces.new([r0[j], r0[(j + 1) % segs_r], r1[(j + 1) % segs_r], r1[j]])
        bm.faces.new(list(reversed(grid[0])))
        bm.faces.new(grid[-1])

braid(BRAID_PATH, BRAID_END, facing=(0.4, 0, 1))

# Tuft below the cuff: a few short straight locks.
down = (BRAID_END - BRAID_PATH[-1]).normalized()
for k in range(5):
    a = 2 * math.pi * k / 5
    off = Vector((math.cos(a) * 0.045, 0, math.sin(a) * 0.045))
    pts = [BRAID_END + off * 0.5, BRAID_END + down * 0.14 + off, BRAID_END + down * 0.32 + off * 1.4 + Vector((0, rng.uniform(-0.03, 0.03), 0))]
    ribbon(pts, 0.07, 0.03, segs=8, tip=2.2, root=0.9)

# Write the texture coordinates to the loops (before merging vertices, which would drop the
# per-vertex table's keys). Anything not recorded (the scalp cap, the crown dome) takes the root.
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

mat = bpy.data.materials.get("IsabelleHairPlatinum") or bpy.data.materials.new("IsabelleHairPlatinum")
mat.use_nodes = True
bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
col = (0.76, 0.72, 0.62, 1)  # about rgb(226, 220, 204)
tex_path = os.path.join(OUT_DIR, "isabelle_hair_texture.png")
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
