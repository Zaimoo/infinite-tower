"""
Raid assets generator (docs/raid-boss-plan.md, Appendix): the hub Raid Portal and the four Raid Bosses.

Run headless (all assets, or name some):
  blender -b -P tools/blender/generate_raid_assets.py
  blender -b -P tools/blender/generate_raid_assets.py -- portal hollow_king

Outputs per asset:
  assets/models/raid/<asset>/<Asset>.fbx + <Asset>.json   (meshes + rig/placement metadata, Roblox axes)
  assets/models/raid/previews/<asset>_<view>.png
  assets-source/raid/<Asset>.blend
  assets/models/raid/raid_palette.png                      (shared swatch texture)
Conventions live in raid_kit.py (studs, faces +Y in Blender, palette swatches, glow meshes).
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import raid_kit as K
importlib.reload(K)
from mathutils import Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(REPO, "assets", "models", "raid")
SRC = os.path.join(REPO, "assets-source", "raid")
PREV = os.path.join(OUT, "previews")
V = Vector


# ============================================================================ helpers
def arch_points(a, spring, R, base_z=None, n=12, y=0.0):
    """Pointed (lancet) arch centreline in the XZ plane. a = half span, R = arc radius (>= a)."""
    cx = -a + R
    apex_h = math.sqrt(R * R - (R - a) ** 2)
    a0, a1 = math.pi, math.atan2(apex_h, a - R)
    left = []
    if base_z is not None:
        left.append(V((-a, y, base_z)))
    for i in range(n + 1):
        t = a0 + (a1 - a0) * i / n
        left.append(V((cx + R * math.cos(t), y, spring + R * math.sin(t))))
    right = [V((-p.x, p.y, p.z)) for p in reversed(left[:-1])]
    return left + right, spring + apex_h


def arc_samples(a, spring, R, count, y=0.0, skip_ends=1):
    """Evenly spaced points + outward normals along the two arcs (not the legs)."""
    cx = -a + R
    apex_h = math.sqrt(R * R - (R - a) ** 2)
    a0, a1 = math.pi, math.atan2(apex_h, a - R)
    out = []
    for i in range(skip_ends, count + 1):
        t = a0 + (a1 - a0) * i / (count + 1)
        p = V((cx + R * math.cos(t), y, spring + R * math.sin(t)))
        nrm = V((math.cos(t), 0, math.sin(t)))
        out.append((p, nrm, t))
        out.append((V((-p.x, y, p.z)), V((-nrm.x, 0, nrm.z)), t))
    return out


# ============================================================================ portal
def build_portal():
    A = K.Asset("RaidPortal")
    frame = A.segment("Frame")
    runes = A.segment("Runes")
    vortex = A.segment("Vortex")
    shards = A.segment("Shards", pivot=(0, 0, 15.5))
    G_RUNE, G_VORTEX, G_SHARD = "glow:crimson", "glow:violet", "glow:crimson"

    # --- stepped octagonal dais
    for r, z, d, col in ((15.5, 0.45, 0.9, "stone_dark"), (13.6, 1.3, 0.8, "stone_mid"), (11.8, 2.05, 0.7, "obsidian")):
        frame.cyl(r, r, d, col, loc=(0, 0, z), rot=(0, 0, 22.5), segs=8)
        frame.cyl(r + 0.12, r + 0.12, 0.2, "gold_dark", loc=(0, 0, z), rot=(0, 0, 22.5), segs=8)  # band, caps hidden inside
    top = 2.4
    # rune channel ring + radial runes on the dais
    runes.torus(10.4, 0.28, G_RUNE, loc=(0, 0, top + 0.02), major=48, minor=6, scale_minor=(1.6, 0.35))
    for i in range(16):
        ang = math.radians(i * 22.5 + 11.25)
        p = V((math.cos(ang) * 8.6, math.sin(ang) * 8.6, top + 0.04))
        runes.box((0.45, 1.6, 0.12), G_RUNE, loc=p, rot=(0, 0, math.degrees(ang) + 90))
    for i in range(7):  # step runes, front
        x = (i - 3) * 2.6
        runes.box((1.1, 0.3, 0.12), G_RUNE, loc=(x, 13.4, 0.92))

    # --- the lancet arch
    a, spring, R = 9.5, 12.5, 15.5
    path, apex = arch_points(a, spring, R, base_z=top, n=14)
    frame.tube(path, (1.75, 2.1), "obsidian", rect=True, up=(0, 1, 0))
    # inner and outer gold trims, front and back
    for off in (-1.95, 1.95):
        pts, _ = arch_points(a + off, spring, R + off, base_z=top + 2.2, n=14)
        for yy in (2.0, -2.0):
            frame.tube([p + V((0, yy, 0)) for p in pts], (0.22, 0.32), "gold", rect=True, up=(0, 1, 0))
    # stone facing panels between the trims (slightly proud), so the arch reads layered
    pts, _ = arch_points(a, spring, R, base_z=top + 2.2, n=14)
    frame.tube([p + V((0, 2.15, 0)) for p in pts], (1.55, 0.12), "stone_mid", rect=True, up=(0, 1, 0))
    frame.tube([p + V((0, -2.15, 0)) for p in pts], (1.55, 0.12), "stone_mid", rect=True, up=(0, 1, 0))
    # pillar bases and capitals
    for s in (1, -1):
        frame.box((5.0, 5.6, 2.2), "stone_mid", loc=(s * a, 0, top + 1.1), bevel=0.25)
        frame.box((5.4, 6.0, 0.4), "gold", loc=(s * a, 0, top + 2.3), bevel=0.08)
        frame.box((4.8, 5.4, 1.2), "stone_light", loc=(s * a, 0, spring - 0.2), bevel=0.2)
        frame.box((5.2, 5.8, 0.3), "gold", loc=(s * a, 0, spring + 0.5), bevel=0.06)
        # gargoyle-ish claws gripping the base
        for dy in (-1.8, 1.8):
            frame.spike((s * (a + 2.4), dy, top + 0.6), (s * (a + 3.6), dy * 1.2, top + 0.05), 0.45, "bone_dark", segs=5)
    # runes inlaid along the arch faces
    for p, nrm, t in arc_samples(a, spring, R, 7):
        tang = V((-nrm.z, 0, nrm.x))
        rotz = math.degrees(math.atan2(tang.z, tang.x))
        for yy in (2.3, -2.3):
            runes.box((0.9, 0.18, 0.5), G_RUNE, loc=p + V((0, yy, 0)), rot=(0, -rotz, 0))
    for s in (1, -1):
        for z in (5.5, 8.0, 10.5):
            for yy in (2.3, -2.3):
                runes.box((0.5, 0.18, 1.1), G_RUNE, loc=(s * a, yy, z))
    # crockets: obsidian thorns along the outer edge
    for p, nrm, t in arc_samples(a + 1.75, spring, R + 1.75, 6):
        frame.spike(p, p + nrm * 2.6 + V((0, 0, 0.9)), 0.55, "obsidian", segs=5)
    # horns sweeping out of the shoulders
    for s in (1, -1):
        pts = [V((s * (a + 0.8), 0, spring + 7.5)), V((s * (a + 3.2), 0.4, spring + 9.5)), V((s * (a + 5.4), 1.0, spring + 13.0)),
               V((s * (a + 5.6), 1.2, spring + 17.0)), V((s * (a + 4.0), 0.8, spring + 19.6))]
        frame.tube(pts, [1.5, 1.35, 1.05, 0.65, 0.0], "bone", sides=9)
        for i in range(1, 4):  # ridges on the horn
            q = pts[i]
            frame.torus([1.38, 1.08, 0.7][i - 1], 0.16, "bone_dark", mat=K.look_matrix(q, pts[i + 1]))
    # skull keystone
    sk = V((0, 1.2, apex + 0.6))
    frame.sphere(2.2, "bone", loc=sk + V((0, 0, 0.35)), scale=(1.0, 0.92, 1.05), segs=16, rings=10)
    frame.box((3.4, 1.0, 0.7), "bone_dark", loc=sk + V((0, 1.55, 0.75)), bevel=0.2)  # brow
    frame.box((2.4, 1.6, 1.3), "bone_dark", loc=sk + V((0, 0.9, -1.55)), bevel=0.3)  # jaw
    for x in (-0.9, -0.3, 0.3, 0.9):
        frame.spike(sk + V((x, 1.7, -1.05)), sk + V((x, 1.75, -1.75)), 0.2, "tooth", segs=4)
    for s in (1, -1):
        frame.sphere(0.62, "black", loc=sk + V((s * 0.8, 1.55, 0.05)), segs=10, rings=6)
        runes.sphere(0.32, G_RUNE, loc=sk + V((s * 0.8, 1.95, 0.05)), segs=8, rings=5)
    frame.spike(sk + V((0, 1.95, -0.45)), sk + V((0, 2.25, -0.85)), 0.32, "black", segs=4)  # nose cavity
    # gold crown of thorns over the skull
    for i in range(7):
        ang = math.radians(-60 + i * 20)
        base = sk + V((math.sin(ang) * 1.6, math.cos(ang) * 0.3, 1.9))
        frame.spike(base, base + V((math.sin(ang) * 0.8, 0, 2.0 - abs(i - 3) * 0.35)), 0.3, "gold", segs=5)
    frame.torus(1.65, 0.2, "gold", loc=sk + V((0, 0.2, 1.95)), rot=(0, 0, 0), major=20, minor=6)

    # --- side obelisks
    for s in (1, -1):
        x = s * 15.2
        frame.box((3.6, 3.6, 1.6), "stone_mid", loc=(x, -2.0, top - 0.2 + 0.8), bevel=0.2)
        frame.cyl(1.7, 1.0, 13.0, "obsidian", loc=(x, -2.0, top + 0.6 + 6.5), rot=(0, 0, 45), segs=4)
        frame.cyl(1.25, 0.0, 1.8, "gold", loc=(x, -2.0, top + 13.1 + 0.9), rot=(0, 0, 45), segs=4)
        for z in (5.0, 8.0, 11.0):
            face_y = -2.0 + 0.7071 * (1.7 - 0.7 * ((z - 0.6) / 13.0))
            runes.box((0.35, 0.2, 1.4), G_RUNE, loc=(x, face_y + 0.04, top + z))
        runes.crystal((x, -2.0, top + 16.4), (x, -2.0, top + 19.8), 0.8, G_SHARD, sides=6)
        frame.torus(1.1, 0.14, "gold", loc=(x, -2.0, top + 15.4), major=16, minor=5)

    # --- braziers on the dais front corners
    for s in (1, -1):
        b = V((s * 7.6, 6.4, top))
        frame.cyl(0.55, 0.75, 2.6, "iron_dark", loc=b + V((0, 0, 1.3)), segs=6)
        frame.cyl(1.6, 0.9, 1.1, "iron", loc=b + V((0, 0, 3.1)), segs=8)
        frame.torus(1.6, 0.14, "gold", loc=b + V((0, 0, 3.65)), major=16, minor=5)
        for k in range(4):
            ang = math.radians(k * 90 + 45)
            frame.spike(b + V((math.cos(ang) * 1.5, math.sin(ang) * 1.5, 3.6)), b + V((math.cos(ang) * 1.9, math.sin(ang) * 1.9, 4.6)), 0.18, "gold", segs=4)
        runes.cyl(1.15, 0.0, 2.6, "glow:orange", loc=b + V((0, 0, 4.6)), segs=7)
        runes.cyl(0.6, 0.0, 3.4, "glow:orange", loc=b + V((0.2 * s, 0.1, 5.0)), segs=5)

    # --- vortex membrane filling the inner arch
    inner, _ = arch_points(a - 1.75, spring, R - 1.75, base_z=top, n=18)
    poly = [(p.x, p.z) for p in inner]
    vortex.prism(poly, 0.3, G_VORTEX, loc=(0, 0, 0))
    vortex.prism([(x * 0.62, top + (z - top) * 0.62 + 2.4) for x, z in poly], 0.5, G_VORTEX, loc=(0, 0.3, 0))

    # --- floating shards (the client spins this whole segment about its pivot)
    rnd = random.Random(7)
    for i in range(9):
        ang = math.radians(i * 40 + 10)
        r = 15.5 + rnd.uniform(-1.0, 1.5)
        c = V((math.cos(ang) * r, rnd.uniform(-3.0, 3.0), 15.5 + math.sin(ang) * r * 0.85))
        if c.z < top + 3:
            c.z = top + 3 + rnd.uniform(0, 2)
        d = V((rnd.uniform(-0.4, 0.4), rnd.uniform(-0.3, 0.3), 1)).normalized()
        L = rnd.uniform(1.6, 2.8)
        shards.crystal(c - d * L * 0.5, c + d * L * 0.5, 0.42 + rnd.uniform(0, 0.25), G_SHARD, sides=5, shaft=0.55)
        shards.spike(c - d * L * 0.5, c - d * L * 1.0, 0.3, G_SHARD, segs=5)
    return A, {"Roles": {"Frame": "PALETTE", "Runes": "NEON", "Vortex": "NEON", "Shards": "NEON (spin about pivot)"},
               "TriggerRingCentreY": round(spring + 3.0, 2), "Apex": round(apex, 2)}


# ============================================================================ boss 1: Vorthak, the Hollow King
def build_hollow_king():
    A = K.Asset("HollowKing")
    RED = "glow:crimson"
    hips = A.segment("Hips", (0, 0, 15.5))
    torso = A.segment("Torso", (0, 0, 17.4), hips)
    head = A.segment("Head", (0, 0, 26.6), torso)
    cape = A.segment("Cape", (0, -2.6, 25.6), torso)
    # hips: pelvis, belt, tassets, tabard
    hips.box((6.4, 3.8, 2.8), "iron_dark", loc=(0, 0, 15.6), bevel=0.3)
    hips.box((6.9, 4.3, 0.9), "leather", loc=(0, 0, 16.7), bevel=0.15)
    hips.box((1.8, 0.5, 1.4), "gold", loc=(0, 2.25, 16.7), bevel=0.15)
    hips.sphere(0.45, RED, loc=(0, 2.55, 16.7), segs=8, rings=6)
    for s in (1, -1):
        hips.box((2.5, 0.5, 3.4), "iron", loc=(s * 1.6, 2.05, 14.2), rot=(-12, 0, s * 4), bevel=0.15)
        hips.box((0.5, 3.0, 3.2), "iron", loc=(s * 3.45, 0, 14.4), rot=(0, s * 12, 0), bevel=0.15)
        hips.box((2.5, 0.5, 3.0), "iron", loc=(s * 1.5, -2.05, 14.4), rot=(12, 0, 0), bevel=0.15)
        hips.box((2.6, 0.12, 0.3), "gold", loc=(s * 1.6, 2.38, 12.65), rot=(-12, 0, s * 4))
    hips.box((2.4, 0.3, 7.6), "cloth_red", loc=(0, 2.45, 12.4), rot=(-4, 0, 0))
    hips.box((2.5, 0.34, 0.35), "gold", loc=(0, 2.73, 8.75), rot=(-4, 0, 0))
    hips.spike((0, 2.75, 8.6), (0, 2.85, 7.6), 0.6, "cloth_red", segs=4)
    # legs
    for s, side in ((1, "R"), (-1, "L")):
        up = A.segment(f"UpperLeg{side}", (s * 2.0, 0, 14.4), hips)
        lo = A.segment(f"LowerLeg{side}", (s * 2.3, 0.3, 8.3), up)
        up.tube([(s * 2.0, 0, 14.6), (s * 2.15, 0.15, 11.4), (s * 2.3, 0.3, 8.6)], [1.45, 1.35, 1.15], "iron_dark", sides=10)
        up.box((2.3, 0.6, 4.0), "iron", loc=(s * 2.15, 1.25, 11.4), rot=(-3, 0, 0), bevel=0.2)
        up.box((0.6, 2.2, 3.6), "iron", loc=(s * 3.35, 0.1, 11.6), bevel=0.15)
        lo.sphere(1.3, "iron", loc=(s * 2.3, 0.45, 8.3), segs=12, rings=8)
        lo.spike((s * 2.3, 1.55, 8.4), (s * 2.3, 2.9, 8.9), 0.45, "gold", segs=5)
        lo.tube([(s * 2.3, 0.3, 8.0), (s * 2.35, 0.2, 5.0), (s * 2.4, 0.0, 2.0)], [1.2, 1.3, 1.0], "iron_dark", sides=10)
        lo.box((2.0, 0.6, 4.6), "iron", loc=(s * 2.35, 1.2, 4.9), rot=(-2, 0, 0), bevel=0.2)
        lo.box((2.1, 0.14, 0.3), "gold", loc=(s * 2.35, 1.52, 7.0))
        lo.box((2.5, 4.6, 1.6), "iron_dark", loc=(s * 2.4, 0.9, 0.8), bevel=0.35)
        lo.box((2.3, 1.6, 1.1), "iron", loc=(s * 2.4, 3.3, 0.6), rot=(10, 0, 0), bevel=0.25)
        lo.spike((s * 2.4, 4.0, 0.6), (s * 2.4, 5.0, 0.35), 0.4, "obsidian", segs=4)
    # torso: abdomen, barrel breastplate, gorget, core, back spikes
    torso.tube([(0, 0, 17.2), (0, 0.1, 19.0), (0, 0.15, 20.6)], [(2.9, 2.0), (2.7, 2.0), (3.0, 2.2)], "iron_dark", sides=10, up=(0, 1, 0))
    for i, z in enumerate((17.9, 19.0, 20.1)):
        torso.box((3.6 - i * 0.1, 0.5, 1.0), "iron", loc=(0, 1.95 + i * 0.05, z), rot=(-6, 0, 0), bevel=0.2)
    torso.tube([(0, 0.1, 20.4), (0, 0.25, 22.6), (0, 0.15, 24.6), (0, 0, 25.9)], [(3.4, 2.4), (4.3, 2.8), (4.5, 2.8), (3.6, 2.4)], "iron", sides=10, up=(0, 1, 0))
    torso.box((0.6, 0.6, 1.6), "gold", loc=(0, 2.95, 25.0), bevel=0.15)
    torso.box((0.6, 0.6, 1.4), "gold", loc=(0, 2.8, 21.2), rot=(-4, 0, 0), bevel=0.15)
    torso.torus(1.45, 0.32, "gold", mat=K.M((0, 3.05, 23.3), (90, 0, 0)), major=20, minor=6)
    torso.sphere(1.15, RED, loc=(0, 3.0, 23.3), scale=(1, 0.65, 1), segs=12, rings=8)
    for ang in (30, 150, 210, 330):
        r = math.radians(ang)
        torso.box((1.6, 0.25, 0.22), RED, loc=(math.cos(r) * 2.3, 2.75 - abs(math.cos(r)) * 0.3, 23.3 + math.sin(r) * 1.6), rot=(0, -ang, 0))
    torso.cyl(2.2, 2.0, 1.2, "iron_dark", loc=(0, 0, 26.2), segs=12)
    torso.torus(2.15, 0.22, "gold", loc=(0, 0, 25.75), major=20, minor=6)
    for i, (x, z) in enumerate(((0, 25.0), (-1.8, 23.8), (1.8, 23.8), (0, 21.8))):
        torso.spike((x, -2.4, z), (x * 1.3, -4.6, z + 1.6), 0.55, "obsidian", segs=5)
    # cape: tattered royal mantle
    cape.tube([(0, -2.75, 25.8), (0, -3.6, 21.5), (0, -4.5, 14.0), (0, -5.3, 6.5), (0, -5.7, 3.2)],
              [(3.8, 0.22), (4.6, 0.22), (5.3, 0.22), (5.8, 0.22), (6.0, 0.22)], "cloth_red", rect=True, up=(0, 1, 0))
    cape.tube([(0, -2.5, 26.0), (0, -3.0, 24.2)], [(4.0, 0.35), (4.6, 0.35)], "gold", rect=True, up=(0, 1, 0))
    rnd = random.Random(3)
    for i in range(7):
        x = -5.2 + i * 1.73
        L = rnd.uniform(1.4, 3.0)
        cape.prism([(-0.75, 0), (0.75, 0), (rnd.uniform(-0.3, 0.3), -L)], 0.4, "cloth_red", loc=(x, -5.72, 3.25))
    cape.box((1.8, 0.4, 1.8), "gold", loc=(0, -2.3, 26.6), rot=(0, 45, 0), bevel=0.1)
    # head: great helm with visor, crown, swept horns
    head.tube([(0, 0, 26.6), (0, 0.1, 28.2), (0, 0.05, 30.0), (0, 0, 30.8)], [(1.8, 1.95), (2.0, 2.15), (1.95, 2.05), (1.6, 1.7)], "iron_dark", sides=12, up=(0, 1, 0))
    head.sphere(1.62, "iron_dark", loc=(0, 0, 30.6), scale=(1, 1.05, 0.62), segs=14, rings=8)
    head.box((3.2, 0.6, 2.9), "iron", loc=(0, 1.95, 28.6), rot=(-4, 0, 0), bevel=0.3)
    head.box((0.36, 0.5, 2.6), "gold", loc=(0, 2.3, 28.4), bevel=0.08)
    head.box((2.5, 0.3, 0.32), RED, loc=(0, 2.3, 29.25))
    for s in (1, -1):
        head.sphere(0.32, RED, loc=(s * 0.75, 2.42, 29.25), segs=8, rings=5)
        for k in range(3):
            head.box((0.16, 0.3, 0.7), "black", loc=(s * (0.5 + k * 0.38), 2.28, 27.9))
        head.tube([(s * 1.8, -0.2, 30.0), (s * 3.0, -0.9, 31.0), (s * 3.6, -2.2, 32.4), (s * 3.4, -3.6, 33.4)], [0.55, 0.45, 0.3, 0.0], "bone_dark", sides=7)
    head.torus(1.9, 0.3, "gold", loc=(0, 0, 31.1), major=24, minor=6)
    for i in range(9):
        ang = math.radians(90 + (i - 4) * 32)
        h = 2.6 - abs(i - 4) * 0.35
        p = V((math.cos(ang) * 1.9, math.sin(ang) * 1.9, 31.1))
        head.spike(p, p + V((math.cos(ang) * 0.35, math.sin(ang) * 0.35, h)), 0.34, "gold", segs=5)
    head.sphere(0.42, RED, loc=(0, 2.1, 31.35), segs=8, rings=6)
    # arms
    for s, side in ((1, "R"), (-1, "L")):
        ua = A.segment(f"UpperArm{side}", (s * 4.6, 0, 25.0), torso)
        la = A.segment(f"LowerArm{side}", (s * 5.9, 0.3, 19.6), ua)
        ua.sphere(2.6, "iron", loc=(s * 5.4, 0, 25.6), scale=(1.1, 1.05, 0.82), segs=16, rings=10)
        ua.torus(2.55, 0.22, "gold", mat=K.M((s * 5.45, 0, 25.0), (0, s * 18, 0)), major=24, minor=6)
        for k, z in enumerate((24.1, 23.3)):
            ua.box((4.0 - k * 0.5, 4.6 - k * 0.4, 0.6), "iron_dark", loc=(s * (5.9 + k * 0.3), 0, z), rot=(0, s * (24 + k * 6), 0), bevel=0.2)
        for k, (dy, h) in enumerate(((0, 3.2), (1.4, 2.3), (-1.4, 2.3))):
            b = V((s * 5.9, dy, 26.9))
            ua.spike(b, b + V((s * 1.3, dy * 0.3, h)), 0.5, "obsidian", segs=5)
        ua.tube([(s * 5.2, 0, 24.6), (s * 5.6, 0.15, 22.0), (s * 5.9, 0.3, 19.9)], [1.25, 1.15, 1.05], "iron_dark", sides=10)
        la.sphere(1.15, "iron", loc=(s * 5.9, 0.3, 19.6), segs=12, rings=8)
        la.tube([(s * 5.9, 0.3, 19.4), (s * 6.05, 0.65, 17.4), (s * 6.2, 1.0, 15.6)], [1.1, 1.05, 1.0], "iron_dark", sides=10)
        la.tube([(s * 6.15, 0.9, 17.2), (s * 6.2, 1.0, 15.7)], [1.25, 1.55], "iron", sides=10)
        la.torus(1.5, 0.14, "gold", loc=(s * 6.2, 1.0, 15.75), major=16, minor=5)
        la.box((2.0, 2.2, 2.1), "iron_dark", loc=(s * 6.3, 1.1, 14.4), bevel=0.35)
        for k in range(3):
            la.spike((s * 6.3, 1.8 + k * 0.0, 15.0 - k * 0.6), (s * 6.3, 2.6, 15.0 - k * 0.6), 0.22, "gold", segs=4)
    # sword in the right hand (+X), edge forward, point down
    sword = A.segment("Sword", (6.3, 1.1, 14.4), A.segments[[s.name for s in A.segments].index("LowerArmR")])
    hand = V((6.3, 1.1, 14.4))
    d = V((0.03, 0.22, -1)).normalized()
    up_end = hand - d * 1.9
    sword.sphere(0.65, "gold", loc=up_end - d * 0.3, segs=10, rings=6)
    sword.sphere(0.32, RED, loc=up_end - d * 0.9, segs=6, rings=4)
    sword.rod(up_end, hand + d * 1.3, 0.38, "leather", segs=8)
    guard = hand + d * 1.5
    gm = K.look_matrix(guard, guard + d, up=(0, 1, 0))  # local X = sideways: flat of the blade faces front
    fwd = (gm.to_3x3() @ V((1, 0, 0))).normalized()
    sword.box((0.9, 0.9, 0.9), "gold", mat=gm, bevel=0.1)
    for sg in (1, -1):
        tip = guard + fwd * sg * 2.8 + d * 0.9
        sword.tube([guard, guard + fwd * sg * 1.6 - d * 0.2, tip], [0.42, 0.36, 0.0], "gold", sides=6)
    blade = [(-0.95, 0), (-1.1, 2.6), (-0.8, 3.8), (-1.2, 5.2), (-0.85, 6.8), (-1.05, 8.3), (-0.7, 10.3), (0, 12.6),
             (0.7, 10.3), (1.05, 8.3), (0.85, 6.8), (1.2, 5.2), (0.8, 3.8), (1.1, 2.6), (0.95, 0)]
    bm = K.look_matrix(guard + d * 0.45, guard + d * 2, up=(0, 1, 0))
    # prism profiles are (x, z): local Z runs down the blade, local X across its width
    sword.prism(blade, 0.42, "iron_light", mat=bm)
    sword.prism([(x * 0.22, z * 0.82 + 0.6) for x, z in blade], 0.56, RED, mat=bm)
    return A, {"Boss": "HOLLOW_KING", "DisplayName": "Vorthak, the Hollow King", "Root": "Hips", "GlowAccent": list(K.GLOW["crimson"])}


def sph(centre, r, theta, phi):
    """Point and outward normal on a sphere. theta = azimuth from +Y (front) toward +X, phi = elevation."""
    t, p = math.radians(theta), math.radians(phi)
    n = V((math.sin(t) * math.cos(p), math.cos(t) * math.cos(p), math.sin(p)))
    return V(centre) + n * r, n


def bezier(p0, p1, p2, p3, n=6):
    p0, p1, p2, p3 = V(p0), V(p1), V(p2), V(p3)
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(p0 * u ** 3 + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t ** 3)
    return out


# ============================================================================ boss 2: Ozrith, the Thousand-Eyed
def build_thousand_eyed():
    A = K.Asset("ThousandEyed")
    VIO, TEAL = "glow:violet", "glow:teal"
    C = V((0, 0, 17))
    body = A.segment("Body", C)
    eye = A.segment("Eye", (0, 4.6, 17), body)
    halo_in = A.segment("HaloInner", C, body)
    halo_out = A.segment("HaloOuter", C, body)
    eyelets = A.segment("Eyelets", C, body)
    rnd = random.Random(11)
    # fleshy core, eye socket rim and lids
    body.sphere(6.5, "flesh_purple", loc=C, scale=(1, 0.95, 0.92), segs=24, rings=16)
    body.torus(4.55, 1.0, "flesh_dark", mat=K.M(C + V((0, 4.35, 0)), (90, 0, 0)), major=28, minor=8)
    body.torus(4.2, 0.55, "flesh_pink", mat=K.M(C + V((0, 5.05, 0)), (90, 0, 0)), major=28, minor=6)
    # bone carapace plates over the crown and back, each with a spike
    for theta, phi, w in ((180, 20, 4.2), (150, 35, 3.4), (210, 35, 3.4), (180, 55, 3.8), (120, 15, 3.0), (240, 15, 3.0),
                          (90, 45, 2.6), (270, 45, 2.6), (30, 62, 2.8), (330, 62, 2.8), (180, -10, 3.2)):
        p, n = sph(C, 6.05, theta, phi)
        m = K.look_matrix(p, p + n)
        body.box((w, w * 1.15, 0.9), "bone_dark", mat=m, bevel=0.25)
        body.spike(p + n * 0.3, p + n * (2.4 + rnd.uniform(0, 1.6)) + V((0, -0.6, 0.6)), 0.55, "bone", segs=6)
    # maw underneath: a ring of teeth around a dark throat
    maw = C + V((0, 1.2, -5.5))
    body.sphere(2.6, "black", loc=maw + V((0, 0, 0.2)), scale=(1, 1, 0.45), segs=16, rings=8)
    body.torus(2.7, 0.5, "flesh_dark", loc=maw, major=20, minor=6)
    for i in range(14):
        a = 2 * math.pi * i / 14
        b = maw + V((math.cos(a) * 2.5, math.sin(a) * 2.5, -0.2))
        body.spike(b, b + V((-math.cos(a) * 0.9, -math.sin(a) * 0.9, -1.4)), 0.35, "tooth", segs=4)
    # small eyes scattered over the body
    for theta, phi in ((60, 10), (300, 10), (95, -20), (265, -20), (130, 40), (230, 40), (40, -35), (320, -35), (180, 75)):
        p, n = sph(C, 6.0, theta, phi)
        body.sphere(0.85, "eye_white", loc=p + n * 0.25, segs=10, rings=7)
        body.torus(0.82, 0.22, "flesh_dark", mat=K.look_matrix(p + n * 0.35, p + n), major=12, minor=5)
        body.sphere(0.4, TEAL, loc=p + n * 0.82, segs=8, rings=5)
    # glowing veins
    for theta0 in (40, 140, 220, 320):
        pts = [sph(C, 6.3, theta0 + k * 9, -50 + k * 22)[0] for k in range(6)]
        body.tube(pts, [0.16, 0.2, 0.2, 0.18, 0.14, 0.08], VIO, sides=5)
    # the great eye
    eye.sphere(4.3, "eye_white", loc=(0, 3.6, 17), segs=24, rings=16)
    eye.sphere(2.35, TEAL, loc=(0, 7.2, 17), scale=(1, 0.45, 1), segs=20, rings=10)
    eye.box((0.75, 0.6, 3.4), "black", loc=(0, 8.1, 17), bevel=0.25)
    for k in range(10):
        a = 2 * math.pi * k / 10
        eye.box((0.12, 0.2, 0.6), "teal_dark", loc=(math.cos(a) * 1.7, 7.95, 17 + math.sin(a) * 1.7), rot=(0, -math.degrees(a) + 90, 0))
    # tentacles: two segments each, hanging and curling outward
    for i in range(8):
        a = math.radians(i * 45 + 22.5)
        dx, dy = math.cos(a), math.sin(a)
        B = C + V((dx * 4.4, dy * 4.4, -3.9))
        Mid = B + V((dx * 2.6, dy * 2.6, -4.6)) + V((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 0))
        T = Mid + V((dx * 2.8, dy * 2.8, -4.4))
        Tip = T + V((dx * 2.2, dy * 2.2, 1.6))
        sa = A.segment(f"Tentacle{i + 1}A", B, body)
        sb = A.segment(f"Tentacle{i + 1}B", Mid, sa)
        pa = bezier(B, B + V((dx * 1.2, dy * 1.2, -1.5)), Mid - V((dx * 1.0, dy * 1.0, -1.4)), Mid, 5)
        sa.tube(pa, [1.25, 1.18, 1.1, 1.0, 0.92, 0.86], "flesh_purple", sides=9)
        for k in (1, 3):
            sa.torus([1.17, 0.97][k // 2], 0.16, "flesh_pink", mat=K.look_matrix(pa[k], pa[k + 1]), major=12, minor=4)
        pb = bezier(Mid, Mid + (Mid - pa[-2]).normalized() * 1.8, T, Tip, 7)
        sb.tube(pb, [0.86, 0.8, 0.72, 0.62, 0.5, 0.38, 0.22, 0.0], "flesh_purple", sides=8)
        for k in (1, 3, 5):
            sb.sphere(0.24, "flesh_pink", loc=pb[k] + V((-dx * 0.55, -dy * 0.55, -0.3)), segs=6, rings=4)
        sb.spike(pb[4], pb[4] + V((0, 0, 1.2)) + V((dx, dy, 0)) * 0.6, 0.22, "bone", segs=4)
    # rune halos
    halo_in.torus(9.5, 0.36, "gold", mat=K.M(C, (72, 0, 18)), major=56, minor=7)
    m_in = K.M(C, (72, 0, 18))
    for k in range(12):
        a = 2 * math.pi * k / 12
        p = m_in @ V((math.cos(a) * 9.5, math.sin(a) * 9.5, 0))
        halo_in.box((0.9, 0.9, 0.9), VIO, mat=K.look_matrix(p, C) @ K.M(rot=(0, 0, 45)), bevel=0.0)
    m_out = K.M(C, (104, 0, -32))
    halo_out.torus(12.0, 0.3, "iron", mat=m_out, major=64, minor=6)
    halo_out.torus(11.2, 0.12, "gold", mat=m_out, major=64, minor=5)
    for k in range(8):
        a = 2 * math.pi * k / 8
        p = m_out @ V((math.cos(a) * 12.0, math.sin(a) * 12.0, 0))
        out = (p - C).normalized()
        halo_out.crystal(p - out * 0.4, p + out * 1.9, 0.42, VIO, sides=5, shaft=0.5)
        q = m_out @ V((math.cos(a + 0.39) * 12.0, math.sin(a + 0.39) * 12.0, 0))
        halo_out.spike(q, q + (q - C).normalized() * 1.1, 0.22, "iron_light", segs=4)
    # orbiting eyelets
    for k, (ang, dz) in enumerate(((50, 3.0), (140, -2.0), (230, 2.0), (320, -3.0))):
        a = math.radians(ang)
        p = C + V((math.cos(a) * 10.5, math.sin(a) * 10.5, dz))
        eyelets.sphere(1.25, "eye_white", loc=p, segs=12, rings=8)
        eyelets.torus(1.15, 0.32, "flesh_dark", mat=K.M(p + V((0, 0.45, 0)), (90, 0, 0)), major=14, minor=5)
        eyelets.sphere(0.62, TEAL, loc=p + V((0, 1.0, 0)), scale=(1, 0.5, 1), segs=10, rings=6)
        eyelets.tube(bezier(p - V((0, 1.0, 0)), p - V((0, 2.4, 0.4)), p - V((0.6, 3.0, 1.4)), p - V((0.2, 3.6, 2.6)), 4), [0.7, 0.5, 0.35, 0.2, 0.0], "flesh_purple", sides=6)
    return A, {"Boss": "THOUSAND_EYED", "DisplayName": "Ozrith, the Thousand-Eyed", "Root": "Body", "HoverHeight": 17, "GlowAccent": list(K.GLOW["violet"])}


# ============================================================================ boss 3: Xal'Zhara, the Rift Broodmother
def build_broodmother():
    A = K.Asset("Broodmother")
    GRN = "glow:green"
    thorax = A.segment("Thorax", (0, 4.0, 8.6))
    abdomen = A.segment("Abdomen", (0, 0.4, 10.0), thorax)
    rnd = random.Random(5)
    # cephalothorax and head
    thorax.sphere(1.0, "chitin_black", loc=(0, 4.4, 8.6), scale=(4.2, 5.0, 2.7), segs=20, rings=12)
    thorax.sphere(1.0, "chitin_green", loc=(0, 4.2, 9.5), scale=(3.4, 4.3, 2.1), segs=18, rings=10)
    thorax.sphere(1.0, "chitin_black", loc=(0, 9.0, 9.1), scale=(2.7, 2.5, 2.1), segs=16, rings=10)
    thorax.sphere(1.0, "chitin_mid", loc=(0, 9.2, 9.9), scale=(2.1, 1.9, 1.4), segs=14, rings=8)
    for k in range(5):
        y = 1.8 + k * 1.3
        thorax.spike((0, y, 11.4 - abs(k - 2) * 0.15), (0, y - 0.9, 13.0 - abs(k - 2) * 0.3), 0.42, "bone_green", segs=5)
    for (x, y, z, r) in ((0.85, 11.0, 9.9, 0.55), (-0.85, 11.0, 9.9, 0.55), (1.75, 10.5, 10.4, 0.4), (-1.75, 10.5, 10.4, 0.4),
                         (0.6, 10.2, 10.9, 0.3), (-0.6, 10.2, 10.9, 0.3), (2.2, 9.6, 10.0, 0.3), (-2.2, 9.6, 10.0, 0.3)):
        thorax.sphere(r * 1.25, "black", loc=(x, y - 0.1, z), segs=10, rings=6)
        thorax.sphere(r, GRN, loc=(x, y + 0.12, z), segs=10, rings=6)
    for s in (1, -1):  # pedipalps
        thorax.tube(bezier((s * 1.9, 10.0, 8.0), (s * 2.6, 11.8, 8.6), (s * 2.9, 13.0, 6.8), (s * 2.5, 13.4, 4.8), 5),
                    [0.5, 0.45, 0.42, 0.38, 0.3, 0.0], "chitin_black", sides=7)
    # fangs (chelicerae)
    for s, side in ((1, "R"), (-1, "L")):
        fang = A.segment(f"Fang{side}", (s * 1.15, 10.7, 7.9), thorax)
        fang.sphere(1.0, "chitin_mid", loc=(s * 1.15, 10.8, 7.9), scale=(0.9, 1.0, 1.2), segs=12, rings=8)
        pts = bezier((s * 1.2, 11.2, 7.3), (s * 1.6, 12.6, 6.4), (s * 1.3, 12.6, 4.6), (s * 0.55, 11.7, 3.9), 6)
        fang.tube(pts, [0.62, 0.6, 0.52, 0.42, 0.3, 0.16, 0.0], "bone_green", sides=8)
        fang.sphere(0.28, GRN, loc=pts[-1] + V((0, 0, -0.35)), segs=8, rings=5)
    # abdomen with skull marking, ridged bands and rift crystals
    AC, AR = V((0, -7.6, 12.2)), V((6.4, 8.4, 6.0))  # abdomen ellipsoid centre and radii

    def shell(theta, phi, lift=0.0):
        """Point and normal on the abdomen ellipsoid; theta from -Y (rear) toward +X, phi = elevation."""
        t, ph = math.radians(theta), math.radians(phi)
        d = V((math.sin(t) * math.cos(ph), -math.cos(t) * math.cos(ph), math.sin(ph)))
        p = V((AC.x + d.x * AR.x, AC.y + d.y * AR.y, AC.z + d.z * AR.z))
        n = V((d.x / AR.x, d.y / AR.y, d.z / AR.z)).normalized()
        return p + n * lift, n

    abdomen.sphere(1.0, "chitin_black", loc=AC, scale=tuple(AR), segs=24, rings=16)
    for y in (-2.8, -5.4, -9.8, -12.6):  # ridged bands hugging the shell
        f = math.sqrt(max(0.0, 1 - ((y - AC.y) / AR.y) ** 2))
        abdomen.torus(1.0, 0.09, "chitin_mid", mat=K.M((0, y, AC.z), (90, 0, 0)) @ K.M(scale=(AR.x * f + 0.05, AR.z * f + 0.05, 1)), major=32, minor=5)
    # overlapping armour plates along the back, and dorsal spines
    for row, phi in enumerate((62, 42, 22)):
        for theta in range(-60 + row * 10, 61 - row * 10, 30):
            p, n = shell(theta, phi)
            m = K.look_matrix(p, p + n)
            abdomen.sphere(1.0, "chitin_green", mat=m @ K.M(scale=(1.9 - row * 0.2, 2.3 - row * 0.2, 0.42)), segs=10, rings=6)
    for phi in (78, 66, 52, 36, 20):
        p, n = shell(0, phi)
        abdomen.spike(p, p + n * 1.5 + V((0, -0.4, 0.3)), 0.32, "bone_green", segs=5)
    # glowing rift fissures running from the crystal cluster down the flanks
    for s in (1, -1):
        for theta0, phi0 in ((40, 60), (75, 40)):
            pts = [shell(s * (theta0 + k * 9), phi0 - k * 11, 0.04)[0] + V((0, (k % 2) * 0.5 - 0.25, 0)) for k in range(6)]
            abdomen.tube(pts, [0.24, 0.26, 0.22, 0.18, 0.12, 0.05], GRN, sides=5)
    # crimson hourglass on the front of the abdomen, lying on the shell
    p, n = shell(180, 58, 0.05)
    hour = [(-1.3, 1.7), (1.3, 1.7), (0.25, 0.0), (1.3, -1.7), (-1.3, -1.7), (-0.25, 0.0)]
    abdomen.prism(hour, 0.3, "crimson", mat=K.look_matrix(p, p + n, up=(0, 1, 0)) @ K.M(rot=(90, 0, 0)))
    for k, (x, y, z, tx, ty, tz, r) in enumerate(((0.0, -10.4, 17.2, 0.0, -11.6, 23.4, 1.2), (1.6, -11.6, 16.5, 3.4, -13.2, 21.0, 0.9),
                                                   (-1.8, -11.0, 16.8, -3.6, -12.2, 21.8, 1.0), (0.8, -13.8, 15.4, 1.8, -16.8, 19.0, 0.8),
                                                   (-1.2, -9.0, 17.6, -2.4, -9.4, 21.2, 0.7), (2.6, -9.6, 16.8, 4.6, -10.0, 19.6, 0.6),
                                                   (-0.6, -14.6, 14.6, -1.4, -17.8, 16.8, 0.6))):
        abdomen.crystal((x, y, z), (tx, ty, tz), r, GRN, sides=6)
        abdomen.ico(r * 1.2, "rock_dark", loc=(x, y, z - 0.2), scale=(1.2, 1.2, 0.6), subdiv=1, jitter=0.15, seed=k)
    for s in (1, -1):  # spinnerets
        abdomen.spike((s * 0.7, -15.4, 10.6), (s * 0.9, -16.8, 10.0), 0.55, "chitin_mid", segs=6)
    # eight legs: upper (hip to knee) and lower (knee to foot)
    attach = ((7.0, 5.0), (5.3, 1.8), (3.6, -1.6), (1.9, -4.8))
    for s, side in ((1, "R"), (-1, "L")):
        for i, (y, spread) in enumerate(attach):
            hip = V((s * 2.9, y, 8.4))
            knee = V((s * 9.6, y + spread * 1.0, 14.8 - abs(i - 1.5) * 0.6))
            foot = V((s * 15.2, y + spread * 1.9, 0.0))
            up = A.segment(f"Leg{side}{i + 1}Upper", hip, thorax)
            lo = A.segment(f"Leg{side}{i + 1}Lower", knee, up)
            mid = hip.lerp(knee, 0.5) + V((0, 0, 1.4))
            up.sphere(1.05, "chitin_mid", loc=hip, segs=10, rings=6)
            up.tube(bezier(hip, hip.lerp(mid, 0.6), mid.lerp(knee, 0.4), knee, 4), [0.95, 0.92, 0.88, 0.82, 0.78], "chitin_black", sides=8)
            for k in (0.35, 0.65):
                p = hip.lerp(knee, k) + V((0, 0, 0.9))
                up.spike(p, p + V((s * 0.3, 0, 1.3)), 0.24, "bone_green", segs=4)
            lo.sphere(0.95, "chitin_mid", loc=knee, segs=10, rings=6)
            lo.torus(0.82, 0.16, "bone_green", mat=K.look_matrix(knee.lerp(foot, 0.12), foot), major=10, minor=4)
            lp = bezier(knee, knee + V((s * 2.4, spread * 0.4, 0.6)), foot + V((-s * 1.0, 0, 6.0)), foot, 6)
            lo.tube(lp, [0.78, 0.72, 0.62, 0.5, 0.38, 0.24, 0.0], "chitin_black", sides=8)
            for k in (2, 4):
                lo.spike(lp[k], lp[k] + V((s * 0.6, 0, 0.8)), 0.16, "bone_green", segs=4)
    return A, {"Boss": "BROODMOTHER", "DisplayName": "Xal'Zhara, the Rift Broodmother", "Root": "Thorax", "GlowAccent": list(K.GLOW["green"])}


# ============================================================================ boss 4: Aurelith, the Shardbound Colossus
def build_shardbound():
    A = K.Asset("Shardbound")
    CY = "glow:cyan"
    pelvis = A.segment("Pelvis", (0, -3.0, 10.5))
    torso = A.segment("Torso", (0, -2.6, 12.2), pelvis)
    head = A.segment("Head", (0, 5.0, 22.2), torso)
    seed = [0]

    def rock(seg, r, col, loc, scale=(1, 1, 1), rot=(0, 0, 0), jitter=0.12):
        seed[0] += 1
        return seg.ico(r, col, loc=loc, scale=scale, rot=rot, subdiv=1, jitter=jitter, seed=seed[0])

    # pelvis
    rock(pelvis, 3.3, "rock_dark", (0, -3.2, 10.4), (1.35, 1.0, 0.8))
    rock(pelvis, 2.0, "rock_blue", (0, -0.6, 9.8), (1.2, 0.8, 0.7))
    # torso: hunched chest, belly, gold veins, core, back crystal ridge
    rock(torso, 6.0, "rock_blue", (0, 0.6, 18.4), (1.28, 0.95, 1.0), (8, 0, 0), 0.08)
    rock(torso, 4.2, "rock_dark", (0, -1.2, 13.8), (1.1, 0.95, 0.85))
    rock(torso, 2.6, "rock_light", (2.8, 4.6, 21.0), (1.2, 0.8, 0.7), (0, 0, 20))
    rock(torso, 2.6, "rock_light", (-2.8, 4.6, 21.0), (1.2, 0.8, 0.7), (0, 0, -20))
    rock(torso, 2.4, "rock_light", (0, 5.4, 14.6), (1.6, 0.6, 0.9))
    for s in (1, -1):  # gold seams set into the shoulder rocks
        torso.box((3.4, 0.4, 0.4), "gold", loc=(s * 2.9, 5.6, 21.3), rot=(0, s * -20, 0), bevel=0.1)
    core = V((0, 6.4, 18.4))
    torso.ico(1.75, CY, loc=core, subdiv=1, jitter=0.06, seed=99)
    torso.torus(2.1, 0.36, "gold", mat=K.M(core + V((0, -0.3, 0)), (90, 0, 0)), major=16, minor=6)
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        b = core + V((math.cos(a) * 2.2, -0.5, math.sin(a) * 2.2))
        torso.crystal(b, b + V((math.cos(a) * 1.4, 0.9, math.sin(a) * 1.4)), 0.32, "crystal_deep", sides=5)
    ridge = [(0, -3.0, 24.0, 0, -5.6, 30.0, 1.3), (2.6, -2.2, 23.4, 4.4, -4.0, 28.6, 1.0), (-2.6, -2.2, 23.4, -4.6, -3.6, 28.4, 1.0),
             (0.8, -5.0, 21.4, 1.6, -9.0, 25.4, 1.0), (-1.4, -5.2, 20.6, -2.6, -9.2, 23.6, 0.9), (4.4, -1.2, 22.6, 7.0, -2.6, 26.4, 0.8),
             (-4.4, -1.2, 22.6, -7.0, -2.4, 26.0, 0.8), (0.0, -6.0, 17.4, 0.4, -9.8, 19.6, 0.9), (2.4, -5.4, 17.8, 4.2, -8.6, 20.4, 0.7),
             (-2.6, -5.4, 18.2, -4.4, -8.4, 21.0, 0.7), (1.2, -1.0, 25.0, 1.8, -1.8, 29.0, 0.7)]
    for k, (x, y, z, tx, ty, tz, r) in enumerate(ridge):
        col = CY if k % 3 != 2 else "crystal_deep"
        torso.crystal((x, y, z), (tx, ty, tz), r, col, sides=6)
        rock(torso, r * 1.3, "rock_dark", (x, y, z - 0.3), (1.2, 1.2, 0.6))
    # head: small, sunk between the shoulders
    rock(head, 2.3, "rock_dark", (0, 6.6, 22.6), (1.2, 1.1, 0.95))
    head.box((4.0, 1.4, 1.0), "rock_light", loc=(0, 8.4, 23.6), rot=(-14, 0, 0), bevel=0.3)
    head.box((3.0, 1.6, 1.3), "rock_blue", loc=(0, 8.0, 21.2), rot=(10, 0, 0), bevel=0.35)
    for s in (1, -1):
        head.box((1.0, 0.4, 0.35), CY, loc=(s * 0.85, 9.0, 22.9), rot=(0, s * -12, 0))
    head.crystal((0, 6.4, 24.4), (0, 4.6, 28.0), 0.7, CY, sides=6)
    head.crystal((1.2, 6.2, 24.0), (2.6, 4.8, 26.6), 0.45, CY, sides=5)
    head.crystal((-1.2, 6.2, 24.0), (-2.6, 4.8, 26.6), 0.45, CY, sides=5)
    # arms: shoulder boulder + upper arm, forearm with crystals, ground-planted fist
    for s, side in ((1, "R"), (-1, "L")):
        ua = A.segment(f"UpperArm{side}", (s * 7.6, 1.4, 21.4), torso)
        la = A.segment(f"LowerArm{side}", (s * 9.8, 3.0, 14.8), ua)
        fist = A.segment(f"Fist{side}", (s * 10.4, 5.0, 6.4), la)
        rock(ua, 3.8, "rock_light", (s * 7.8, 1.2, 22.0), (1.05, 1.0, 0.9))
        rock(ua, 1.6, "rock_blue", (s * 9.2, 0.0, 24.6), (1, 1, 0.8))
        ua.crystal((s * 8.4, -0.6, 24.6), (s * 10.0, -2.2, 28.0), 0.8, CY, sides=6)
        ua.crystal((s * 9.6, 1.4, 24.0), (s * 12.0, 1.0, 26.4), 0.55, "crystal_deep", sides=5)
        ua.tube([(s * 8.0, 1.6, 20.0), (s * 9.0, 2.4, 17.4), (s * 9.8, 3.0, 15.0)], [2.3, 2.1, 2.0], "rock_blue", sides=7)
        rock(ua, 2.0, "rock_dark", (s * 9.2, 2.6, 17.6), (1.1, 1.0, 1.0))
        rock(la, 2.3, "rock_dark", (s * 9.8, 3.0, 14.8))
        la.tube([(s * 9.9, 3.2, 14.2), (s * 10.2, 4.2, 10.8), (s * 10.4, 5.0, 7.0)], [2.2, 2.8, 2.6], "rock_blue", sides=7)
        rock(la, 2.1, "rock_light", (s * 10.6, 4.2, 10.8), (1.15, 1.1, 1.2))
        for k, (dz, ln) in enumerate(((12.2, 2.6), (10.4, 3.4), (8.8, 2.2))):
            b = V((s * 12.0, 3.6 - k * 0.2, dz))
            la.crystal(b, b + V((s * ln, -0.8, 0.8)), 0.5 + 0.1 * (k == 1), CY if k != 2 else "crystal_deep", sides=5)
        la.torus(2.55, 0.26, "gold", mat=K.look_matrix(V((s * 10.35, 4.85, 7.6)), V((s * 10.4, 5.0, 6.0))), major=16, minor=5)
        rock(fist, 3.2, "rock_dark", (s * 10.6, 5.6, 3.3), (1.1, 1.25, 1.0))
        for k in range(4):
            fist.box((1.25, 1.4, 1.6), "rock_light", loc=(s * (9.1 + k * 1.05), 8.6, 2.0), rot=(0, 0, 0), bevel=0.3)
        fist.box((4.6, 0.5, 0.5), "gold", loc=(s * 10.65, 8.4, 3.2), bevel=0.1)
    # legs: short, heavy
    for s, side in ((1, "R"), (-1, "L")):
        ul = A.segment(f"UpperLeg{side}", (s * 4.2, -3.6, 9.6), pelvis)
        ll = A.segment(f"LowerLeg{side}", (s * 4.8, -3.0, 5.4), ul)
        rock(ul, 2.5, "rock_blue", (s * 4.4, -3.4, 8.2), (1.0, 1.0, 1.15))
        ll.tube([(s * 4.8, -3.0, 5.6), (s * 5.0, -2.8, 2.4)], [2.0, 2.3], "rock_dark", sides=7)
        rock(ll, 2.0, "rock_light", (s * 4.9, -2.6, 5.0), (1.0, 0.9, 0.9))
        rock(ll, 2.2, "rock_dark", (s * 5.0, -1.8, 1.1), (1.3, 1.7, 0.55))
        ll.crystal((s * 6.2, -4.2, 6.0), (s * 7.6, -6.2, 8.4), 0.45, CY, sides=5)
    return A, {"Boss": "SHARDBOUND", "DisplayName": "Aurelith, the Shardbound Colossus", "Root": "Pelvis", "GlowAccent": list(K.GLOW["cyan"])}


BUILDERS = {"portal": build_portal, "hollow_king": build_hollow_king, "thousand_eyed": build_thousand_eyed,
            "broodmother": build_broodmother, "shardbound": build_shardbound}


def run(names):
    for key in names:
        K.reset_scene()
        K.setup_preview()
        build = BUILDERS[key]
        asset, extra = build()
        objs = asset.build()
        out_dir = os.path.join(OUT, key)
        os.makedirs(OUT, exist_ok=True)
        K.make_palette_image(os.path.join(OUT, "raid_palette.png"))  # saved first so the FBX can embed it
        asset.export(out_dir, extra)
        os.makedirs(SRC, exist_ok=True)
        import bpy
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, f"{asset.name}.blend"), compress=True)
        K.render_views(objs, PREV, key)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    run(argv or list(BUILDERS))
