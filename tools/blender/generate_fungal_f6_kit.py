"""
Fungal Hollow Floor 6 (Sporelit Entry) sculpted assets, generated in Blender.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>"). Roles are tinted in Roblox by
TowerKitProps (biome palette in Shared/Config/TowerBiomeKit.luau, per-placement overrides in
TowerBiomeAssets). Fungal adds two roles: BULB (violet spore-bulbs) and CANDLE (Chanter flames).

The Velmari lamp-masons' motif is the gill-wheel: a disc carved with radiating gill lines round a
hanging bulb (a lantern seen from below).

Outputs (assets-source/tower/fungal_f6_kit/):
    FungalF6Kit.blend    the generated scene
    FungalF6Kit.fbx      FBX for File > Import 3D in Studio (tests/studio-tower-biome-kit-import.luau)
    manifest.json        per template: roles, reference size, triangle counts
    previews/            contact-sheet render of the templates

Run headless:  blender --background --python tools/blender/generate_fungal_f6_kit.py
"""
import bpy, bmesh, math, os, json, random, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "fungal_f6_kit")

# Load helper primitives from generate_tower_biome_kit without running its main build.
kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
ico = kit_mod["ico"]
uvsphere = kit_mod["uvsphere"]
lathe = kit_mod["lathe"]
tube = kit_mod["tube"]
displace = kit_mod["displace"]
rock = kit_mod["rock"]
ring_mesh = kit_mod["ring_mesh"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]
render_previews = kit_mod["render_previews"]
ROLE_PREVIEW = kit_mod["ROLE_PREVIEW"]
SMOOTH_ROLES = kit_mod["SMOOTH_ROLES"]

# Preview colours close to the in-game Fungal palette, so the contact sheet reads like the floor.
ROLE_PREVIEW.update({
    "CAP": (0.32, 0.16, 0.62), "STEM": (0.66, 0.64, 0.78), "GLOW": (0.30, 0.95, 0.92), "MOSS": (0.20, 0.18, 0.36),
    "TRIM": (0.24, 0.22, 0.38), "ACCENT": (0.44, 0.30, 0.80), "WOOD": (0.20, 0.15, 0.18), "CRYSTAL": (0.45, 0.92, 0.86),
    "BULB": (0.78, 0.42, 1.0), "CANDLE": (1.0, 0.78, 0.45),
})
SMOOTH_ROLES.update({"BULB", "CANDLE"})

DEFAULT_BUDGET = 3500
F6_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F6_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def _cap(t, top, r, h, seed, gill_role="GLOW", spot_role="BULB", spots=9, lip=0.6, segs=24, displace_amp=None):
    """A mushroom dome centred at `top` (the stem's top): lathe dome with a curled lip, gill disc beneath."""
    cap, gills = t.bm("CAP"), t.bm(gill_role)
    rng = random.Random(seed)
    prof = [(0.01, h), (r * 0.35, h * 0.95), (r * 0.65, h * 0.76), (r * 0.88, h * 0.46), (r * 1.0, h * 0.16),
            (r * 0.98, 0.0), (r * 0.90, -lip)]
    v = lathe(cap, prof, segs, M(top), cap_bottom=False, cap_top=False)
    displace(cap, v, displace_amp if displace_amp is not None else r * 0.035, 0.5 / max(r, 1.0), seed)
    # Gill disc: radial ribs read as gills from below.
    lathe(gills, [(r * 0.92, -lip * 0.8), (r * 0.55, -lip * 0.15), (r * 0.2, lip * 0.35), (0.01, lip * 0.5)], segs,
          M(top), cap_bottom=False, cap_top=False)
    if r > 3:
        for k in range(segs):
            a = 2 * math.pi * k / segs
            p0 = top + Vector((math.cos(a) * r * 0.22, math.sin(a) * r * 0.22, lip * 0.1))
            p1 = top + Vector((math.cos(a) * r * 0.9, math.sin(a) * r * 0.9, -lip * 0.9))
            tube(gills, [p0, p1], [r * 0.012, r * 0.02], 3, cap=False)
    if spots and spot_role:
        sp = t.bm(spot_role)
        for k in range(spots):
            a = k * 2 * math.pi / spots + rng.uniform(-0.25, 0.25)
            rr = r * rng.uniform(0.3, 0.8)
            z = h * (0.95 - 0.8 * (rr / r) ** 2)
            ico(sp, 1.0, M(top + Vector((math.cos(a) * rr, math.sin(a) * rr, z + r * 0.01)),
                           scale=(r * 0.07, r * 0.07, r * 0.02)), 1)


# ---------------------------------------------------------------------------------------------------------
# The Elder Cap: the colossal mushroom on the glowpool island (~100 studs tall).
# ---------------------------------------------------------------------------------------------------------
@template("ElderCap", STEM=3200, CAP=3600, GLOW=3200, BULB=1600, MOSS=1400)
def elder_cap(t):
    rng = t.rng
    stem, moss, glow, bulb = t.bm("STEM"), t.bm("MOSS"), t.bm("GLOW"), t.bm("BULB")
    height, cap_r = 84.0, 44.0
    # A slight S-bend so it reads as grown, not turned on a lathe.
    pts = [Vector((0, 0, -1.0)), Vector((1.5, 0.8, height * 0.25)), Vector((-1.0, 1.2, height * 0.5)),
           Vector((-2.5, 0.0, height * 0.75)), Vector((-1.0, -0.8, height))]
    v = tube(stem, pts, [11.0, 8.6, 7.6, 7.2, 7.8], 16, cap=False)
    displace(stem, v, 0.7, 0.18, 3)
    top = pts[-1]
    # Root-foot: buttress roots splaying into the island.
    for k in range(9):
        a = k * 2 * math.pi / 9 + rng.uniform(-0.15, 0.15)
        d = Vector((math.cos(a), math.sin(a), 0))
        ln = rng.uniform(14, 22)
        root = [d * 6 + Vector((0, 0, 10)), d * (ln * 0.55) + Vector((0, 0, 3.5)), d * ln + Vector((0, 0, -0.5)),
                d * (ln + 4) + Vector((0, 0, -2.0))]
        tube(stem, root, [3.4, 2.6, 1.6, 0.8], 7)
        # Glowing mycelium threads running out along each root.
        tube(glow, [p + Vector((0, 0, 0.9)) for p in root[1:]], [0.35, 0.3, 0.2], 3, cap=False)
    # Moss mound round the foot.
    rock(moss, (36, 34, 7), M((0, 0, -2.2)), 11, roughness=0.25, subdiv=3)
    # Skirt ring (annulus) partway up the stem: torn veil, glowing at its edge.
    skirt_at = pts[3] + Vector((0, 0, -6))
    lathe(stem, [(7.6, 0), (12.5, -3.0), (13.5, -5.5), (12.0, -6.5)], 20, M(skirt_at), cap_bottom=False, cap_top=False)
    ring_mesh(glow, 12.6, 0.45, 20, M(skirt_at + Vector((0, 0, -6.2))), tube_segs=4)
    # The dome.
    _cap(t, top, cap_r, 24.0, 7, spots=16, lip=2.4, segs=32, displace_amp=1.4)
    # Spore-bulb tendrils hanging from the rim, at staggered lengths.
    for k in range(16):
        a = k * 2 * math.pi / 16 + rng.uniform(-0.1, 0.1)
        rr = cap_r * rng.uniform(0.7, 0.92)
        p0 = top + Vector((math.cos(a) * rr, math.sin(a) * rr, -1.8))
        ln = rng.uniform(10, 26)
        sway = Vector((rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2), 0))
        tube(glow, [p0, p0 + sway * 0.5 + Vector((0, 0, -ln * 0.5)), p0 + sway + Vector((0, 0, -ln))], [0.45, 0.38, 0.3], 4, cap=False)
        uvsphere(bulb, 1.0, M(p0 + sway + Vector((0, 0, -ln - 1.4)), scale=(1.5, 1.5, 2.0)), u=10, v=7)


# ---------------------------------------------------------------------------------------------------------
# Ground cover: glowcap turf (the biome's "grass").
# ---------------------------------------------------------------------------------------------------------
def _turf(t, seed, n, spread, mound):
    rng = random.Random(seed)
    stem, moss = t.bm("STEM"), t.bm("MOSS")
    rock(moss, mound, M((0, 0, -0.35)), seed, roughness=0.3, subdiv=2)
    for k in range(n):
        a = rng.uniform(0, 2 * math.pi)
        d = spread * math.sqrt(rng.uniform(0.02, 1.0))
        x, y = math.cos(a) * d, math.sin(a) * d
        h = rng.uniform(0.6, 2.4) * (1.15 - d / spread * 0.5)
        r = rng.uniform(0.35, 0.85) * (0.6 + h * 0.3)
        lean = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0)) * h
        base = Vector((x, y, 0.15))
        top = base + Vector((0, 0, h)) + lean
        tube(stem, [base, base + Vector((0, 0, h * 0.5)) + lean * 0.4, top], [r * 0.28, r * 0.22, r * 0.2], 5, cap=False)
        _cap(t, top, r, r * 0.55, seed * 31 + k, spots=0, lip=r * 0.12, segs=8, displace_amp=0.0)


@template("GlowcapTuftA", STEM=500, CAP=700, GLOW=500, MOSS=300)
def glowcap_tuft_a(t):
    """A dense patch of tiny glow-gilled caps on a spore-moss mound (~6 studs across)."""
    _turf(t, 41, 14, 2.6, (6.4, 5.6, 1.3))


@template("GlowcapTuftB", STEM=400, CAP=600, GLOW=400, MOSS=300)
def glowcap_tuft_b(t):
    """A long, low drift of caps for edges and banks (~8 x 4 studs)."""
    _turf(t, 57, 12, 2.2, (8.6, 4.2, 1.0))


@template("SporeMoss", MOSS=400, BULB=300, GLOW=200)
def spore_moss(t):
    """A flat cushion of spore-moss studded with tiny violet bulbs and cyan threads (~7 studs across)."""
    rng = t.rng
    rock(t.bm("MOSS"), (7.2, 6.0, 0.9), M((0, 0, -0.25)), 61, roughness=0.35, subdiv=2)
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        d = 2.6 * math.sqrt(rng.uniform(0.0, 1.0))
        ico(t.bm("BULB"), 0.22, M((math.cos(a) * d, math.sin(a) * d * 0.85, 0.55)), 1)
    for k in range(5):
        a = rng.uniform(0, 2 * math.pi)
        p0 = Vector((math.cos(a) * 0.6, math.sin(a) * 0.6, 0.45))
        p1 = Vector((math.cos(a) * 3.4, math.sin(a) * 2.8, 0.15))
        tube(t.bm("GLOW"), [p0, (p0 + p1) / 2 + Vector((0, 0, 0.12)), p1], [0.08, 0.07, 0.05], 3, cap=False)


# ---------------------------------------------------------------------------------------------------------
# The Veinweb's nerves: a branching vein network that lies flat against a cliff face (front -Y).
# ---------------------------------------------------------------------------------------------------------
@template("MyceliumVein", STEM=1400, GLOW=1400)
def mycelium_vein(t):
    rng = t.rng
    stem, glow = t.bm("STEM"), t.bm("GLOW")

    def grow(p, d, length, radius, depth):
        pts, radii = [p.copy()], [radius]
        steps = max(3, int(length / 2.2))
        cur, dir_ = p.copy(), d.copy()
        for i in range(steps):
            dir_ = (dir_ + Vector((rng.uniform(-0.35, 0.35), 0, rng.uniform(-0.35, 0.35)))).normalized()
            cur = cur + dir_ * (length / steps)
            cur.y = -0.15 - radius * 0.3
            pts.append(cur.copy())
            radii.append(radius * (1 - 0.7 * (i + 1) / steps))
        tube(stem, pts, radii, 4, cap=False)
        tube(glow, [q + Vector((0, -radius * 0.55, 0)) for q in pts], [r * 0.45 for r in radii], 3, cap=False)
        if depth > 0:
            for k in range(1, len(pts) - 1, 2):
                if rng.random() < 0.6:
                    side = 1 if rng.random() < 0.5 else -1
                    nd = Vector((dir_.x + side * 0.9, 0, dir_.z + rng.uniform(-0.4, 0.6))).normalized()
                    grow(pts[k], nd, length * rng.uniform(0.35, 0.55), radii[k] * 0.7, depth - 1)

    for k in range(4):
        a = math.radians(rng.uniform(55, 125))
        grow(Vector((rng.uniform(-4, 4), -0.2, 0.0)), Vector((math.cos(a), 0, math.sin(a))), rng.uniform(18, 26), 0.75, 3)


# ---------------------------------------------------------------------------------------------------------
# Velmari stonework: the Chanters' candle altar and the lamp-post.
# ---------------------------------------------------------------------------------------------------------
def _gill_wheel(t, centre, radius, facing_rot):
    """The Velmari motif: a disc with radiating gill lines round a glowing bulb (faces -Y by default)."""
    accent, glow, bulb = t.bm("ACCENT"), t.bm("GLOW"), t.bm("BULB")
    mat = M(centre, rot=facing_rot)
    ring_mesh(accent, radius, radius * 0.1, 20, mat @ M(rot=(math.pi / 2, 0, 0)), tube_segs=5)
    for k in range(14):
        a = 2 * math.pi * k / 14
        p0 = Vector((math.cos(a) * radius * 0.32, 0, math.sin(a) * radius * 0.32))
        p1 = Vector((math.cos(a) * radius * 0.92, 0, math.sin(a) * radius * 0.92))
        tube(glow, [mat @ p0, mat @ p1], [radius * 0.035, radius * 0.05], 3, cap=False)
    uvsphere(bulb, radius * 0.24, mat, u=12, v=8)


@template("CandleAltar", TRIM=1600, ACCENT=900, GLOW=700, BULB=300, STEM=900, CANDLE=700, MOSS=500)
def candle_altar(t):
    """A stepped indigo-slate altar: candle clusters on every step and a gill-wheel lantern at its back."""
    rng = t.rng
    trim, stem, candle, moss = t.bm("TRIM"), t.bm("STEM"), t.bm("CANDLE"), t.bm("MOSS")
    for i, (w, d, h) in enumerate(((15.0, 11.0, 1.4), (11.6, 8.0, 1.4), (8.2, 5.2, 1.4))):
        box(trim, (w, d, h), M((0, 1.0 * i, 0.7 + 1.4 * i)), bevel=0.2)
    # The back slab carrying the gill-wheel.
    box(trim, (7.6, 1.6, 8.2), M((0, 4.0, 4.2 + 4.0)), bevel=0.25)
    _gill_wheel(t, Vector((0, 3.0, 9.6)), 3.0, (0, 0, 0))
    # Candles: clusters of stubs with flames, on each step.
    for (cx, cy, cz, n) in ((-6.0, -3.6, 1.4, 6), (6.0, -3.6, 1.4, 6), (-4.4, -1.4, 2.8, 4), (4.4, -1.4, 2.8, 4),
                            (-3.0, 1.2, 4.2, 3), (3.0, 1.2, 4.2, 3), (0, -4.6, 1.4, 5)):
        for k in range(n):
            x = cx + rng.uniform(-1.2, 1.2)
            y = cy + rng.uniform(-0.8, 0.8)
            h = rng.uniform(0.6, 1.8)
            cone(stem, 0.22, 0.2, h, 6, M((x, y, cz)))
            uvsphere(candle, 0.16, M((x, y, cz + h + 0.22), scale=(1.0, 1.0, 1.7)), u=6, v=5)
    # Wax pooled on the steps, and spore-moss creeping over the lowest one.
    for (x, y) in ((-6.4, -3.4), (5.8, -3.8), (0.2, -4.4)):
        cone(stem, 1.3, 1.1, 0.12, 10, M((x, y, 1.38), scale=(1.0, 0.8, 1.0)))
    for (x, y, s) in ((-7.2, 3.8, 2.6), (7.0, 3.4, 2.2), (-2.0, -5.4, 1.8)):
        rock(moss, (s * 1.6, s, 0.8), M((x, y, 0.2)), int(s * 13), roughness=0.3, subdiv=2)


@template("VelmariLampPost", TRIM=900, ACCENT=500, GLOW=400, BULB=300)
def velmari_lamp_post(t):
    """A slate post under a gill-wheel hood with one hanging glowing bulb (~12 studs tall)."""
    trim, accent, glow, bulb = t.bm("TRIM"), t.bm("ACCENT"), t.bm("GLOW"), t.bm("BULB")
    box(trim, (2.6, 2.6, 0.8), M((0, 0, 0.4)), bevel=0.15)
    cone(trim, 0.7, 0.55, 9.0, 8, M((0, 0, 0.8)))
    # Crook arm and the cap-shaped hood with gill ribs beneath.
    tube(trim, [Vector((0, 0, 9.4)), Vector((0, -1.2, 10.6)), Vector((0, -2.6, 10.8))], [0.4, 0.35, 0.3], 6, cap=False)
    hood = Vector((0, -2.6, 10.6))
    lathe(accent, [(0.01, 1.3), (1.0, 1.1), (1.9, 0.4), (2.1, 0.0), (1.9, -0.25)], 14, M(hood), cap_bottom=False, cap_top=False)
    for k in range(14):
        a = 2 * math.pi * k / 14
        tube(glow, [hood + Vector((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.05)), hood + Vector((math.cos(a) * 1.8, math.sin(a) * 1.8, -0.2))],
             [0.06, 0.08], 3, cap=False)
    tube(glow, [hood, hood + Vector((0, 0, -1.2))], [0.08, 0.08], 3, cap=False)
    uvsphere(bulb, 0.75, M(hood + Vector((0, 0, -1.9)), scale=(1.0, 1.0, 1.3)), u=10, v=8)


# ---------------------------------------------------------------------------------------------------------
# The oculus: dangling cavern roots in an arc (lowest tips at z = 0, so the template stands, not hangs).
# ---------------------------------------------------------------------------------------------------------
@template("HangingRootFringe", WOOD=1800, MOSS=900, GLOW=300)
def hanging_root_fringe(t):
    rng = t.rng
    wood, moss, glow = t.bm("WOOD"), t.bm("MOSS"), t.bm("GLOW")
    top_z = 30.0
    # An arc of 34 studs chord along X, bowed toward -Y (into the oculus).
    for k in range(18):
        u = (k + rng.uniform(-0.3, 0.3)) / 17
        x = -17 + 34 * u
        y = -3.0 * math.sin(math.pi * u)
        ln = rng.uniform(12, top_z)
        sway = Vector((rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5), 0))
        p0 = Vector((x, y, top_z))
        pts = [p0, p0 + sway * 0.3 + Vector((0, 0, -ln * 0.4)), p0 + sway * 0.8 + Vector((0, 0, -ln * 0.8)), p0 + sway + Vector((0, 0, -ln))]
        r = rng.uniform(0.5, 1.1)
        tube(wood, pts, [r, r * 0.8, r * 0.55, r * 0.3], 5)
        if k % 3 == 0:
            # Hanging moss strands.
            q0 = p0 + Vector((rng.uniform(-1, 1), 0, -rng.uniform(1, 4)))
            ml = rng.uniform(6, 14)
            tube(moss, [q0, q0 + Vector((0.3, 0, -ml * 0.5)), q0 + Vector((0, 0.3, -ml))], [0.5, 0.35, 0.15], 4, cap=False)
        if k % 4 == 1:
            ico(glow, 0.35, M(pts[-1] + Vector((0, 0, -0.2))), 1)
    # The rim the roots grow from: a lumpy band of earth along the top.
    for k in range(6):
        x = -15 + 6 * k
        rock(wood, (8.0, 4.5, 3.0), M((x, -3.0 * math.sin(math.pi * (x + 17) / 34), top_z - 1.2)), 70 + k, roughness=0.3, subdiv=2, flat_bottom=False)


# ---------------------------------------------------------------------------------------------------------
# Skitter Warren and the glowpool.
# ---------------------------------------------------------------------------------------------------------
@template("EggSacCluster", CRYSTAL=1200, STEM=700, MOSS=400, BULB=300)
def egg_sac_cluster(t):
    """Translucent Spore Skitter egg-sacs clumped on a silk-wrapped stump (~7 studs across)."""
    rng = t.rng
    sacs, stem, moss, bulb = t.bm("CRYSTAL"), t.bm("STEM"), t.bm("MOSS"), t.bm("BULB")
    rock(moss, (6.4, 5.6, 1.2), M((0, 0, -0.3)), 81, roughness=0.3, subdiv=2)
    for k in range(9):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.4, 2.4)
        s = rng.uniform(0.9, 1.6)
        c = Vector((math.cos(a) * d, math.sin(a) * d, 0.6 + s * 0.9 + rng.uniform(0, 1.6)))
        v = uvsphere(sacs, s, M(c, scale=(1.0, 1.0, 1.25)), u=12, v=8)
        displace(sacs, v, 0.08, 1.4, k)
        ico(bulb, s * 0.35, M(c), 1)
    # Silk strands from the sacs down to the mound.
    for k in range(10):
        a = rng.uniform(0, 2 * math.pi)
        p0 = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, rng.uniform(2.5, 4.5)))
        p1 = Vector((math.cos(a) * 3.0, math.sin(a) * 2.6, 0.3))
        tube(stem, [p0, (p0 + p1) / 2 + Vector((0, 0, 0.6)), p1], [0.07, 0.06, 0.05], 3, cap=False)


@template("PadCap", CAP=500, GLOW=400)
def pad_cap(t):
    """A flat glowing mushroom cap floating on the water (~5 studs across)."""
    cap, glow = t.bm("CAP"), t.bm("GLOW")
    v = lathe(cap, [(0.01, 0.55), (1.2, 0.5), (2.2, 0.3), (2.5, 0.08), (2.3, -0.08)], 16, M((0, 0, 0.1)), cap_bottom=False, cap_top=False)
    displace(cap, v, 0.06, 0.8, 3)
    lathe(glow, [(2.35, -0.05), (1.4, 0.05), (0.01, 0.1)], 16, M((0, 0, 0.1)), cap_bottom=False, cap_top=False)
    ring_mesh(glow, 2.0, 0.08, 16, M((0, 0, 0.45)), tube_segs=3)


def build_f6():
    reset_scene()
    kit = bpy.data.collections.new("FungalF6Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F6_TEMPLATES.items():
        coll = bpy.data.collections.new(name)
        kit.children.link(coll)
        t = Template(name)
        t.rng = random.Random(sum(map(ord, name)))
        fn(t)
        roles = {}
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for role, bm in t.meshes.items():
            if len(bm.verts) == 0:
                bm.free()
                continue
            obj, tris = finalize(name, role, bm, budget.get(role, DEFAULT_BUDGET), coll)
            for v in obj.data.vertices:
                lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
                hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
            roles[role] = tris
        manifest[name] = {
            "Roles": roles,
            "Triangles": sum(roles.values()),
            # Roblox axes (X, Y up, Z): Blender (x, z, -y).
            "Size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
            "Min": [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)],
        }
    return kit, manifest


def export_f6(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FungalF6Kit.fbx"),
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        use_mesh_modifiers=True,
        bake_space_transform=True,
        object_types={"MESH"},
    )
    with open(os.path.join(OUT_DIR, "manifest.json"), "w") as f:
        json.dump({"Templates": manifest, "Unit": "studs", "Front": "-Y in Blender, +Z in Roblox"}, f, indent=2, sort_keys=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FungalF6Kit.blend"))


if __name__ == "__main__" or globals().get("RUN_F6", False):
    kit, manifest = build_f6()
    export_f6(kit, manifest)
    if globals().get("PREVIEWS", True):
        render_previews(kit, os.path.join(OUT_DIR, "previews"), list(F6_TEMPLATES.keys()), tile=520, cols=5)
    result = {"templates": len(manifest), "manifest": manifest}
    print(json.dumps(manifest, indent=2))
