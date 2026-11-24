"""
Sunken Sanctuary Floor 36 (Drowned Steps) sculpted assets, generated in headless Blender.

The Nereth tide-priests' sea-front at low tide: the first great Tidebell and the golden scallop canopy of its
shrine on the Bell Stack, lancet-arched limestone bays (whole and broken), the bell arches of the pilgrim way,
the fallen middle flight of the Pilgrim Stair, the wrecked Hollin river barge, floating votive lamp bowls,
the Tide Claws' shell midden, aqua rune tablets, cantors' lecterns, tidepool rock rings, giant clams, kelp,
sea fans, anemones and seagrass.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>"). Roles used here: STONE (pale limestone),
TRIM (white marble), METAL (bronze), ACCENT (verdigris), GOLD (gilding), GLOW (aqua rune light), CANDLE
(lamp flame), WOOD (barge timber), SILK (rags and banners), FOLIAGE (kelp and seagrass), MOSS (weed at the
waterline), CORAL (coral, carapaces, anemones), ALT (shell and nacre) and CRYSTAL (pearl and still water).
Floor 36 tints every role itself (TowerSetPieces/SunkenSanctuary).

Run:
    PYTHONHASHSEED=0 /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_sunken_f36_kit.py

Outputs (assets-source/tower/sunken_f36_kit/):
    SunkenF36Kit.blend    the generated scene
    SunkenF36Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             contact-sheet renders
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "sunken_f36_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
tube = kit_mod["tube"]
lathe = kit_mod["lathe"]
rock = kit_mod["rock"]
ring_mesh = kit_mod["ring_mesh"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]
render_previews = kit_mod["render_previews"]


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def surface(bm, fn, nu, nv, mat=Matrix.Identity(4), close_u=False):
    """A quad grid surface through fn(u, v) -> Vector, u and v in [0, 1]."""
    cols = nu if close_u else nu + 1
    rows = []
    for j in range(nv + 1):
        row = []
        for i in range(cols):
            row.append(bm.verts.new(mat @ fn(i / nu, j / nv)))
        rows.append(row)
    for j in range(nv):
        for i in range(nu):
            i1 = (i + 1) % cols
            bm.faces.new((rows[j][i], rows[j][i1], rows[j + 1][i1], rows[j + 1][i]))


def lancet(bm, half_span, rise, thick, depth, mat, segs=8):
    """A pointed (two-centred) lancet arch over x in [-half_span, half_span], springing at z = 0."""
    for s in (-1, 1):
        pts = []
        # Each half is an arc centred on the opposite springer, radius = span (equilateral-ish), scaled to rise.
        for k in range(segs + 1):
            a = k / segs * (math.pi / 3)
            x = s * half_span - s * 2 * half_span * (1 - math.cos(a))
            z = 2 * half_span * math.sin(a) * (rise / (2 * half_span * math.sin(math.pi / 3)))
            pts.append(Vector((x, 0, z)))
        for k in range(segs):
            p0, p1 = pts[k], pts[k + 1]
            mid = (p0 + p1) / 2
            d = p1 - p0
            ang = math.atan2(d.z, d.x)
            box(bm, (d.length + thick * 0.35, depth, thick), mat @ M((mid.x, 0, mid.z), rot=(0, -ang, 0)))


def tide_spiral(bm, centre, radius, turns, width, mat, axis="Y"):
    """The Nereth sigil: a nautilus spiral of little blocks lying in the XZ plane (facing -Y)."""
    steps = int(18 * turns)
    for k in range(steps):
        f = k / steps
        a = f * turns * 2 * math.pi
        r = radius * (0.18 + 0.82 * f)
        x, z = math.cos(a) * r, math.sin(a) * r
        size = width * (0.5 + 0.5 * f)
        box(bm, (size, size * 0.6, size), mat @ M((centre[0] + x, centre[1], centre[2] + z), rot=(0, -a, 0)), bevel=0.04)


DEFAULT_BUDGET = 3500
F36_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F36_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


BELL_PROFILE = [(6.6, 0.0), (6.9, 0.5), (6.5, 1.3), (5.6, 2.6), (4.7, 4.8), (4.2, 7.6), (4.0, 10.0), (3.7, 11.8),
                (3.0, 12.9), (1.6, 13.5), (0.0, 13.7)]


@template("GreatTidebell", METAL=2600, ACCENT=1400, GOLD=900, GLOW=600, WOOD=500)
def great_tidebell(t):
    """The first great Tidebell: a bronze bell (13.8 across, 13.7 tall) hung from a yoke on a bronze crown loop,
    verdigris streaks down its waist, a gilt lip and a band of aqua tide-spiral runes. Origin at the lip's centre;
    the yoke rises to ~18.5."""
    metal, acc, gold, glow, wood = t.bm("METAL"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("GLOW"), t.bm("WOOD")
    lathe(metal, BELL_PROFILE, 32, M((0, 0, 0)), cap_bottom=False, cap_top=True)
    # The dark mouth inside, so the bell reads hollow from below.
    lathe(metal, [(6.2, 0.4), (5.0, 2.6), (3.9, 7.2), (2.0, 11.6), (0.0, 12.2)], 24, M((0, 0, 0)), cap_bottom=False, cap_top=True)
    ring_mesh(gold, 6.75, 0.35, 32, M((0, 0, 0.55)), tube_segs=5)
    ring_mesh(gold, 4.1, 0.22, 28, M((0, 0, 9.6)), tube_segs=4)
    ring_mesh(gold, 4.25, 0.22, 28, M((0, 0, 6.8)), tube_segs=4)
    # Rune band: small glowing spirals round the waist.
    for k in range(8):
        a = k * math.pi / 4
        r = 4.25
        tide_spiral(glow, (0, 0, 0), 0.85, 1.6, 0.26, M((math.cos(a) * r, math.sin(a) * r, 8.2), rot=(0, 0, a + math.pi / 2)))
    # Verdigris streaks running down from the crown.
    for k in range(12):
        a = k * 2 * math.pi / 12 + 0.13
        for j, (r, z) in enumerate(((3.85, 11.2), (4.05, 9.2), (4.3, 6.4), (4.8, 4.2))):
            box(acc, (1.0 - j * 0.12, 0.25, 2.2), M((math.cos(a) * (r + 0.08), math.sin(a) * (r + 0.08), z), rot=(0, 0.15 * j, a + math.pi / 2)))
    # Crown loops (canons) and the yoke.
    for s in (-1, 1):
        tube(metal, [(s * 1.6, 0, 13.4), (s * 1.8, 0, 15.6), (0, 0, 16.6), (-s * 0.1, 0, 16.6)], [0.45, 0.45, 0.45, 0.45], 6, cap=False)
    box(wood, (16.0, 2.2, 2.0), M((0, 0, 17.6)), bevel=0.3)
    for s in (-1, 1):
        box(gold, (0.6, 2.4, 2.2), M((s * 6.8, 0, 17.6)), bevel=0.08)
    # Clapper hanging inside the mouth.
    tube(metal, [(0, 0, 12.2), (0, 0, 2.6)], [0.35, 0.35], 6)
    uvsphere(metal, 1.25, M((0, 0, 1.8)), u=10, v=6)


def scallop_point(u, v, radius, rise, ribs):
    """Point on a scallop-shell dome: u around the fan (0..1 over 200 degrees), v from the hinge (0) to the rim (1)."""
    a = math.radians(-100 + 200 * u)
    rib = 0.5 + 0.5 * math.cos(u * ribs * 2 * math.pi)
    r = radius * v * (1 + 0.05 * rib * v)
    z = rise * (1 - v ** 1.6) + 0.9 * rib * v
    return Vector((math.sin(a) * r, -math.cos(a) * r + radius * 0.18, z))


@template("GoldenShellCanopy", GOLD=4200, TRIM=1800, GLOW=500, ACCENT=500)
def golden_shell_canopy(t):
    """The Bell Stack shrine's golden canopy: a great scallop shell (~58 across) arched over a marble ring beam,
    its hinge to the back (+Y) and its fluted fan to the front, a gilt trident finial and a glowing pearl under
    the crown. Stands on its ring beam's underside at z = 0; ~31 tall."""
    gold, trim, glow, acc = t.bm("GOLD"), t.bm("TRIM"), t.bm("GLOW"), t.bm("ACCENT")
    R, base = 27.0, 6.0
    ribs = 13
    surface(gold, lambda u, v: scallop_point(u, v, R, 15.0, ribs) + Vector((0, 0, base)), 52, 12)
    # Underside (so it is solid from below).
    surface(gold, lambda u, v: scallop_point(1 - u, v, R * 0.985, 14.2, ribs) + Vector((0, 0, base - 0.6)), 52, 12)
    # The fan's ribs as raised tubes.
    for k in range(ribs + 1):
        u = k / ribs
        pts = [scallop_point(u, v, R, 15.0, ribs) + Vector((0, 0, base + 0.5)) for v in (0.05, 0.3, 0.55, 0.8, 1.0)]
        tube(gold, pts, [0.6, 0.55, 0.5, 0.45, 0.4], 5)
    # The hinge "ears" at the back.
    for s in (-1, 1):
        box(gold, (9.0, 4.0, 2.4), M((s * 6.0, R * 0.18 + 2.0, base + 14.6), rot=(0.2, 0, s * 0.25)), bevel=0.5)
    # Marble ring beam the shell rests on, with corbels.
    ring_mesh(trim, R * 0.86, 1.6, 40, M((0, R * 0.12, base - 2.4), scale=(1, 0.86, 1)), tube_segs=6)
    for k in range(10):
        a = k * 2 * math.pi / 10
        x, y = math.cos(a) * R * 0.86, math.sin(a) * R * 0.86 * 0.86 + R * 0.12
        box(trim, (2.6, 2.6, 4.0), M((x, y, 2.0)), bevel=0.25)
        box(acc, (2.9, 2.9, 0.5), M((x, y, 0.25)), bevel=0.1)
    # Trident finial on the crown.
    top = scallop_point(0.5, 0.0, R, 15.0, ribs) + Vector((0, 0, base))
    tube(gold, [top, top + Vector((0, 0, 9.0))], [0.55, 0.5], 8)
    for s in (-1, 0, 1):
        tube(gold, [top + Vector((s * 1.6, 0, 8.0)), top + Vector((s * 2.0, 0, 10.0)), top + Vector((s * 1.8, 0, 12.8))], [0.4, 0.35, 0.05], 6)
    box(gold, (4.4, 0.8, 0.8), M((top.x, top.y, top.z + 8.2)), bevel=0.15)
    # Pearl light under the crown.
    uvsphere(glow, 2.2, M((0, R * 0.12, base + 8.5)), u=14, v=10)


@template("LancetArchBay", STONE=2600, TRIM=1400, ACCENT=500, GLOW=400, MOSS=600)
def lancet_arch_bay(t):
    """One bay of a Nereth colonnade (~22 wide, ~47 tall, 5 deep): two limestone columns with marble bases and
    capitals, a pointed lancet arch with a shell-niche keystone and a glowing tide-spiral, weed at the foot."""
    stone, trim, acc, glow, moss = t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("GLOW"), t.bm("MOSS")
    span = 9.0
    for s in (-1, 1):
        x = s * span
        box(trim, (5.2, 5.2, 2.4), M((x, 0, 1.2)), bevel=0.3)
        lathe(stone, [(2.2, 2.4), (2.0, 6), (1.95, 20), (1.85, 30), (1.8, 32.6)], 14, M((x, 0, 0)))
        ring_mesh(acc, 2.05, 0.3, 14, M((x, 0, 12.0)), tube_segs=4)
        box(trim, (5.0, 5.0, 1.6), M((x, 0, 33.4)), bevel=0.3)
        box(trim, (4.0, 4.0, 1.2), M((x, 0, 34.8)), bevel=0.2)
        rock_clean(moss, (5.6, 5.6, 1.6), M((x, 0, 0)), 40 + s, subdiv=1)
    lancet(stone, span, 11.5, 2.2, 3.4, M((0, 0, 35.4)), segs=8)
    # Spandrel fill above the arch and a coping.
    box(stone, (22.6, 3.0, 1.6), M((0, 0, 47.6)), bevel=0.25)
    for s in (-1, 1):
        box(stone, (5.4, 2.6, 8.0), M((s * 8.6, 0, 42.8)), bevel=0.2)
    # Shell niche keystone with the tide-spiral.
    box(trim, (3.4, 3.6, 4.2), M((0, 0, 46.2)), bevel=0.35)
    tide_spiral(glow, (0, -1.9, 46.2), 1.3, 1.8, 0.32, Matrix.Identity(4))


@template("BrokenLancetColumn", STONE=1800, TRIM=900, MOSS=600, ACCENT=300)
def broken_lancet_column(t):
    """A Nereth column snapped off at ~19 studs, its capital and two drums fallen beside it (~16 x 20 x 10)."""
    stone, trim, moss, acc = t.bm("STONE"), t.bm("TRIM"), t.bm("MOSS"), t.bm("ACCENT")
    box(trim, (5.2, 5.2, 2.4), M((0, 0, 1.2)), bevel=0.3)
    lathe(stone, [(2.2, 2.4), (2.0, 6), (1.95, 16.5), (1.7, 18.2), (1.2, 19.0), (0.4, 19.3)], 14, M((0, 0, 0)))
    ring_mesh(acc, 2.05, 0.3, 14, M((0, 0, 12.0)), tube_segs=4)
    for k, (x, y, ang) in enumerate(((5.6, -2.0, 0.4), (9.6, 1.4, -0.3))):
        cone(stone, 1.95, 1.95, 5.2, 14, M((x, y, 1.95), rot=(math.pi / 2, 0, ang)))
    box(trim, (5.0, 5.0, 1.6), M((-5.2, 3.0, 0.8), rot=(0.1, 0.2, 0.7)), bevel=0.3)
    rock_clean(moss, (6.2, 6.2, 1.6), M((0, 0, 0)), 7, subdiv=1)
    rock_clean(moss, (5.0, 3.6, 1.0), M((7.6, 0, 0)), 8, subdiv=1)


@template("BellArch", STONE=2400, TRIM=1200, METAL=1200, ACCENT=500, GOLD=300, GLOW=300, MOSS=500)
def bell_arch(t):
    """A bell arch of the pilgrim way (~30 wide, ~35 tall, 6 deep): two battered limestone piers, a round arch
    with a tide-spiral keystone, and a bronze bell hung in the crown (its lip ~19 over the ground, so a 24-stud
    lane walks clear under it)."""
    stone, trim, metal, acc, gold, glow, moss = (t.bm("STONE"), t.bm("TRIM"), t.bm("METAL"), t.bm("ACCENT"),
                                                 t.bm("GOLD"), t.bm("GLOW"), t.bm("MOSS"))
    inner = 12.4
    for s in (-1, 1):
        x = s * (inner + 2.4)
        box(stone, (5.0, 6.2, 22.0), M((x, 0, 11.0)), bevel=0.35)
        box(trim, (6.0, 7.0, 1.4), M((x, 0, 0.7)), bevel=0.2)
        box(trim, (5.8, 6.8, 1.2), M((x, 0, 22.4)), bevel=0.2)
        rock_clean(moss, (6.4, 7.0, 1.4), M((x, 0, 0)), 60 + s, subdiv=1)
    segs = 12
    R = inner + 2.4
    for k in range(segs):
        a0, a1 = math.pi * k / segs, math.pi * (k + 1) / segs
        p0 = Vector((math.cos(a0) * R, 0, 23.0 + math.sin(a0) * R * 0.78))
        p1 = Vector((math.cos(a1) * R, 0, 23.0 + math.sin(a1) * R * 0.78))
        mid, d = (p0 + p1) / 2, p1 - p0
        box(stone, (d.length + 0.6, 6.0, 4.6), M((mid.x, 0, mid.z), rot=(0, -math.atan2(d.z, d.x), 0)))
    box(trim, (4.0, 6.6, 5.4), M((0, 0, 23.0 + R * 0.78 + 0.6)), bevel=0.4)
    tide_spiral(glow, (0, -3.4, 23.0 + R * 0.78 + 0.6), 1.5, 1.8, 0.34, Matrix.Identity(4))
    # The bell under the crown, on a bronze bar.
    bar_z = 23.0 + R * 0.78 - 3.2
    box(metal, (inner * 2 - 1, 0.9, 0.9), M((0, 0, bar_z)), bevel=0.1)
    s = 0.42
    prof = [(r * s, z * s) for (r, z) in BELL_PROFILE]
    lathe(metal, prof, 20, M((0, 0, bar_z - 13.7 * s - 0.8)), cap_bottom=False, cap_top=True)
    ring_mesh(gold, 6.75 * s, 0.18, 20, M((0, 0, bar_z - 13.7 * s - 0.6)), tube_segs=4)
    tube(metal, [(0, 0, bar_z), (0, 0, bar_z - 0.8)], [0.3, 0.3], 6)
    for k in range(6):
        a = k * math.pi / 3
        box(acc, (0.7, 0.18, 1.6), M((math.cos(a) * 1.9, math.sin(a) * 1.9, bar_z - 3.2), rot=(0, 0, a + math.pi / 2)))


@template("FallenStairFlight", STONE=2600, TRIM=1200, MOSS=800, ACCENT=300)
def fallen_stair_flight(t):
    """The Pilgrim Stair's fallen middle flight (~26 wide, ~38 long, ~11 tall): runs of limestone treads tumbled
    and tilted into the surf, a snapped stringer, marble nosings and weed. Lies along the Y axis."""
    stone, trim, moss, acc = t.bm("STONE"), t.bm("TRIM"), t.bm("MOSS"), t.bm("ACCENT")
    rng = t.rng
    runs = [((-4.0, -12.0, 3.2), (0.35, 0.18, 0.2), 5), ((5.0, 2.0, 2.4), (-0.25, -0.3, -0.15), 4), ((-2.0, 13.0, 1.4), (0.1, 0.4, 0.5), 3)]
    for (cx, cy, cz), (rx, ry, rz), n in runs:
        frame = M((cx, cy, cz), rot=(rx, ry, rz))
        for k in range(n):
            box(stone, (18.0, 3.4, 1.6), frame @ M((0, k * 3.2, k * 1.6)), bevel=0.25)
            box(trim, (18.2, 0.8, 0.5), frame @ M((0, k * 3.2 - 1.5, k * 1.6 + 0.85)), bevel=0.08)
        box(stone, (1.6, n * 3.4, n * 1.6 + 1.6), frame @ M((9.4, (n - 1) * 1.6, (n - 1) * 0.8 - 0.6)), bevel=0.2)
    for k in range(9):
        rock_clean(stone, (rng.uniform(2.4, 4.6), rng.uniform(2.0, 3.8), rng.uniform(1.4, 2.6)), M((rng.uniform(-12, 12), rng.uniform(-18, 18), 0)), 90 + k, subdiv=1)
    for k in range(7):
        rock_clean(moss, (rng.uniform(4, 7), rng.uniform(3, 5), 1.0), M((rng.uniform(-11, 11), rng.uniform(-17, 17), 0)), 120 + k, subdiv=1)
    box(acc, (0.6, 7.0, 0.6), M((6.0, -4.0, 0.4), rot=(0, 0, 0.5)), bevel=0.1)
    # What lies deeper than ~2 studs is buried in the seabed: flatten it there (the kit's origin rule).
    for bm in t.meshes.values():
        for v in bm.verts:
            if v.co.z < -2.2:
                v.co.z = -2.2


@template("HollinBarge", WOOD=3600, TRIM=1400, SILK=600, METAL=600, GOLD=200, MOSS=500)
def hollin_barge(t):
    """The wrecked Hollin river barge (~46 long, ~15 wide, ~27 tall with its mast): a flat-bottomed hull listing on
    its keel, stove-in ribs at the stern, a broken mast with a Pale Band rag, and a graft-knot cider barrel in
    the hold. Lies along the X axis, bow to +X."""
    wood, trim, silk, metal, gold, moss = (t.bm("WOOD"), t.bm("TRIM"), t.bm("SILK"), t.bm("METAL"), t.bm("GOLD"),
                                           t.bm("MOSS"))
    L, Wd = 40.0, 13.0
    tilt = M((0, 0, 0), rot=(0.14, 0, 0))
    # Hull sides: planked strakes bowing out, a raked bow and a flat stern.
    for s in (-1, 1):
        for k in range(4):
            z = 1.0 + k * 1.7
            pts = []
            for i in range(9):
                f = i / 8
                x = -L / 2 + f * L
                y = s * (Wd / 2) * (0.82 + 0.18 * math.sin(f * math.pi)) * (1 - max(0.0, f - 0.8) * 2.2)
                pts.append(tilt @ Vector((x, y, z + max(0.0, f - 0.75) * 6)))
            tube(wood if k % 2 else trim, pts, [0.85] * len(pts), 5)
    # Ribs, some snapped at the stern.
    for i in range(10):
        x = -L / 2 + 2.5 + i * 3.9
        top = 7.6 if i > 2 else 3.4 + i
        for s in (-1, 1):
            tube(wood, [tilt @ Vector((x, 0, 0.4)), tilt @ Vector((x, s * Wd * 0.42, 1.2)), tilt @ Vector((x, s * Wd * 0.48, top))], [0.45, 0.45, 0.4], 5)
    # Keel and the deck boards still in place amidships.
    tube(wood, [tilt @ Vector((-L / 2 - 1, 0, 0.3)), tilt @ Vector((L / 2 + 3, 0, 4.0))], [0.8, 0.8], 6)
    for i in range(7):
        box(trim, (2.4, Wd * 0.8, 0.4), tilt @ M((-4 + i * 2.6, 0, 6.6)), bevel=0.05)
    # Broken mast with a rag.
    tube(wood, [tilt @ Vector((2, 0, 1)), tilt @ Vector((2.6, 0.4, 26.0))], [0.7, 0.55], 8)
    tube(wood, [tilt @ Vector((-4.5, 0.3, 19.0)), tilt @ Vector((8.8, 0.6, 21.0))], [0.32, 0.3], 6)
    surface(silk, lambda u, v: tilt @ Vector((-3.5 + u * 9.0, 0.7 + math.sin(u * 3.0 + v * 2) * 0.6, 20.6 - v * (6.5 + 2.5 * math.sin(u * 4.4)))), 8, 5)
    surface(silk, lambda u, v: tilt @ Vector((-3.5 + u * 9.0, 0.6 + math.sin(u * 3.0 + v * 2) * 0.6, 20.6 - v * (6.5 + 2.5 * math.sin(u * 4.4)))), 8, 5)
    # The cider barrel, banded, the graft-knot burned into its head.
    cone(wood, 1.8, 1.8, 4.2, 14, tilt @ M((-8, -1.0, 1.6), rot=(math.pi / 2, 0, 0.3)))
    for dy in (-1.2, 1.2):
        ring_mesh(metal, 1.86, 0.14, 14, tilt @ M((-8 + dy * 0.3, -1.0 + dy, 3.4), rot=(math.pi / 2, 0, 0.3)), tube_segs=4)
    box(gold, (1.2, 0.2, 1.2), tilt @ M((-7.4, -3.2, 3.4), rot=(0, 0, 0.3)))
    rock_clean(moss, (L * 0.9, Wd * 0.8, 1.0), tilt @ M((0, 0, 0)), 140, subdiv=2)


@template("VotiveLampBowl", METAL=300, GOLD=150, CANDLE=120)
def votive_lamp_bowl(t):
    """A floating bronze votive bowl (2.6 across): a shallow dish with a gilt rim and a lamp flame."""
    metal, gold, flame = t.bm("METAL"), t.bm("GOLD"), t.bm("CANDLE")
    lathe(metal, [(0.6, 0.0), (1.1, 0.15), (1.3, 0.55), (1.35, 0.8)], 16, M((0, 0, 0)), cap_bottom=True, cap_top=False)
    ring_mesh(gold, 1.32, 0.09, 16, M((0, 0, 0.82)), tube_segs=4)
    lathe(flame, [(0.0, 0.7), (0.3, 0.9), (0.22, 1.4), (0.0, 1.95)], 8, M((0, 0, 0)))


@template("ShellMidden", ALT=2400, CORAL=1400, STONE=800)
def shell_midden(t):
    """The Tide Claws' midden (~15 x 5 x 13): a heap of cracked scallop shells, molted carapaces and stones."""
    alt, coral, stone = t.bm("ALT"), t.bm("CORAL"), t.bm("STONE")
    rng = t.rng
    rock_clean(stone, (13.0, 11.0, 2.6), M((0, 0, 0)), 200, subdiv=2)
    for k in range(26):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 5.4)
        x, y = math.cos(a) * r, math.sin(a) * r
        z = 1.0 + (5.4 - r) * 0.5 + rng.uniform(0, 0.6)
        sz = rng.uniform(1.0, 2.0)
        frame = M((x, y, z), rot=(rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), rng.uniform(0, 6.28)))
        surface(alt, lambda u, v, sz=sz: scallop_point(u, v, sz, sz * 0.35, 7) * 1.0, 10, 3, frame)
    for k in range(6):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(1.0, 5.0)
        frame = M((math.cos(a) * r, math.sin(a) * r, 1.4 + (5 - r) * 0.4), rot=(rng.uniform(-0.4, 0.4), 0, rng.uniform(0, 6.28)), scale=(1.6, 1.2, 0.7))
        uvsphere(coral, 1.4, frame, u=12, v=6)
        for s in (-1, 1):
            tube(coral, [frame @ Vector((s * 0.9, -1.0, 0)), frame @ Vector((s * 1.6, -2.4, 0.2)), frame @ Vector((s * 1.2, -3.2, 0.3))], [0.25, 0.2, 0.1], 4)


@template("RuneTablet", STONE=700, GLOW=500, MOSS=300, TRIM=200)
def rune_tablet(t):
    """An upright limestone tablet (~4.4 wide, ~9.5 tall) carved with a glowing tide-spiral and rune lines."""
    stone, glow, moss, trim = t.bm("STONE"), t.bm("GLOW"), t.bm("MOSS"), t.bm("TRIM")
    box(trim, (5.2, 2.6, 1.0), M((0, 0, 0.5)), bevel=0.2)
    box(stone, (4.4, 1.4, 8.0), M((0, 0, 5.0)), bevel=0.25)
    lathe(stone, [(2.2, 0), (2.0, 0.6), (1.2, 1.2), (0.0, 1.4)], 16, M((0, 0, 9.0), scale=(1, 0.32, 1)))
    tide_spiral(glow, (0, -0.75, 6.6), 1.2, 1.7, 0.28, Matrix.Identity(4))
    for k in range(3):
        box(glow, (2.8 - k * 0.5, 0.2, 0.22), M((0, -0.72, 4.0 - k * 0.8)))
    rock_clean(moss, (5.4, 3.0, 0.9), M((0, 0, 0)), 220, subdiv=1)


@template("CantorLectern", STONE=600, TRIM=400, ACCENT=200, ALT=400)
def cantor_lectern(t):
    """A cantor's stone lectern (~3.6 x 5.2 x 3): a fluted pillar, a slanted marble reading slab and a conch."""
    stone, trim, acc, alt = t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("ALT")
    box(stone, (3.0, 3.0, 0.8), M((0, 0, 0.4)), bevel=0.15)
    lathe(stone, [(0.95, 0.8), (0.8, 1.6), (0.75, 3.6), (1.1, 4.1)], 10, M((0, 0, 0)))
    box(trim, (3.6, 2.6, 0.45), M((0, 0, 4.5), rot=(0.42, 0, 0)), bevel=0.1)
    box(acc, (3.7, 0.3, 0.3), M((0, -1.2, 4.05), rot=(0.42, 0, 0)))
    # The conch lying on the slab.
    pts = [Vector((math.cos(k * 0.6) * (0.9 - k * 0.09), 0.2 + k * 0.06, 5.0 + k * 0.02)) for k in range(10)]
    tube(alt, pts, [0.55 - k * 0.045 for k in range(10)], 8)


@template("TidepoolRockRing", STONE=2200, CRYSTAL=300, CORAL=700, ALT=300, MOSS=500)
def tidepool_rock_ring(t):
    """A rockpool (~17 x 4 x 15): a ring of weathered limestone rocks round still water, anemones and starfish."""
    stone, water, coral, alt, moss = t.bm("STONE"), t.bm("CRYSTAL"), t.bm("CORAL"), t.bm("ALT"), t.bm("MOSS")
    rng = t.rng
    for k in range(13):
        a = k / 13 * 2 * math.pi + rng.uniform(-0.1, 0.1)
        rx, ry = 6.8 + rng.uniform(-0.6, 0.6), 5.8 + rng.uniform(-0.6, 0.6)
        rock_clean(stone, (rng.uniform(3.0, 4.6), rng.uniform(2.6, 3.6), rng.uniform(1.8, 3.6)), M((math.cos(a) * rx, math.sin(a) * ry, 0), rot=(0, 0, a)), 240 + k, subdiv=2)
    lathe(water, [(6.2, 1.0), (0.0, 1.0)], 24, M((0, 0, 0), scale=(1, 0.85, 1)), cap_bottom=True, cap_top=False)
    for k in range(6):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(4.6, 6.8)
        base = Vector((math.cos(a) * r, math.sin(a) * r * 0.85, 1.4))
        for j in range(7):
            ja = j * 2 * math.pi / 7
            tube(coral, [base, base + Vector((math.cos(ja) * 0.5, math.sin(ja) * 0.5, 0.9))], [0.14, 0.05], 4)
        uvsphere(coral, 0.42, M(tuple(base)), u=8, v=5)
    for k in range(3):
        a = rng.uniform(0, 2 * math.pi)
        c = Vector((math.cos(a) * 5.4, math.sin(a) * 4.6, 2.6))
        for j in range(5):
            ja = j * 2 * math.pi / 5 + a
            tube(alt, [c, c + Vector((math.cos(ja) * 1.1, math.sin(ja) * 1.1, -0.1))], [0.3, 0.08], 4)
    rock_clean(moss, (15.0, 13.0, 1.0), M((0, 0, 0)), 260, subdiv=2)


@template("GiantClam", ALT=1600, CORAL=600, CRYSTAL=200)
def giant_clam(t):
    """A giant clam gaping on the sand (~9 x 6 x 8), fluted valves, a coloured mantle lip and a pearl."""
    alt, coral, pearl = t.bm("ALT"), t.bm("CORAL"), t.bm("CRYSTAL")
    lower = M((0, 0, 0.2), rot=(0, 0, 0))
    surface(alt, lambda u, v: Vector((math.sin(math.radians(-80 + 160 * u)) * 4.4 * v, -math.cos(math.radians(-80 + 160 * u)) * 3.6 * v + 1.4, 1.6 * (1 - v ** 2) * 0 + 0.9 * abs(math.cos(u * 6 * math.pi)) * v - 1.2 * v * v + 1.2)), 24, 6, lower)
    upper = M((0, 1.4, 1.2), rot=(-0.85, 0, 0))
    surface(alt, lambda u, v: Vector((math.sin(math.radians(-80 + 160 * u)) * 4.4 * v, -math.cos(math.radians(-80 + 160 * u)) * 3.6 * v, 0.9 * abs(math.cos(u * 6 * math.pi)) * v + 1.4 * (1 - v * v))), 24, 6, upper)
    for k in range(9):
        a = math.radians(-70 + 140 * k / 8)
        uvsphere(coral, 0.7, M((math.sin(a) * 3.2, -math.cos(a) * 2.4 + 1.2, 1.5), scale=(1.4, 1, 0.6)), u=8, v=5)
    uvsphere(pearl, 1.0, M((0, 0.4, 1.8)), u=14, v=10)


@template("KelpStand", FOLIAGE=1800, GLOW=200, MOSS=300)
def kelp_stand(t):
    """A stand of giant kelp (~7 across, ~26 tall): five swaying stipes with blade fronds and glowing float tips."""
    leaf, glow, moss = t.bm("FOLIAGE"), t.bm("GLOW"), t.bm("MOSS")
    rng = t.rng
    for k in range(5):
        a = k * 2 * math.pi / 5 + rng.uniform(-0.3, 0.3)
        base = Vector((math.cos(a) * 1.4, math.sin(a) * 1.4, 0))
        h = rng.uniform(17, 26)
        pts = [base + Vector((math.sin(f * 3 + k) * 1.4 * f, math.cos(f * 2.6 + k) * 1.0 * f, h * f)) for f in (0, 0.25, 0.5, 0.75, 1.0)]
        tube(leaf, pts, [0.3, 0.28, 0.24, 0.2, 0.12], 4)
        for j in range(1, 8):
            f = j / 8
            p = pts[0].lerp(pts[-1], f) + Vector((math.sin(f * 3 + k) * 1.4 * f, 0, 0))
            side = 1 if j % 2 else -1
            box(leaf, (0.12, 1.1, 3.4), M((p.x + side * 0.6, p.y, p.z), rot=(0, side * 0.5, a)), bevel=0.0)
        uvsphere(glow, 0.45, M(tuple(pts[-1])), u=8, v=5)
    rock_clean(moss, (5.2, 5.2, 1.2), M((0, 0, 0)), 280, subdiv=1)


@template("SeaFan", CORAL=1400, STONE=300)
def sea_fan(t):
    """A gorgonian sea fan (~8 wide, ~10 tall, 1.5 deep): a branching lattice fan on a rock foot."""
    coral, stone = t.bm("CORAL"), t.bm("STONE")
    rng = t.rng

    def grow(p, d, length, radius, depth):
        q = p + d * length
        tube(coral, [p, q], [radius, radius * 0.8], 4, cap=depth == 0)
        if depth > 0:
            for s in (-1, 1):
                a = math.atan2(d.x, d.z) + s * rng.uniform(0.3, 0.6)
                nd = Vector((math.sin(a), rng.uniform(-0.05, 0.05), math.cos(a))).normalized()
                grow(q, nd, length * 0.72, radius * 0.75, depth - 1)

    grow(Vector((0, 0, 0.8)), Vector((0, 0, 1)), 3.2, 0.32, 4)
    rock_clean(stone, (3.0, 2.4, 1.4), M((0, 0, 0)), 300, subdiv=1)


@template("AnemoneCluster", CORAL=900, GLOW=300, STONE=200)
def anemone_cluster(t):
    """Glowing anemones on a stone (~4.5 across, ~2.6 tall): fat columns crowned with tentacles and aqua tips."""
    coral, glow, stone = t.bm("CORAL"), t.bm("GLOW"), t.bm("STONE")
    rng = t.rng
    rock_clean(stone, (4.4, 3.8, 1.0), M((0, 0, 0)), 320, subdiv=1)
    for k in range(4):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.2, 1.5)
        c = Vector((math.cos(a) * r, math.sin(a) * r, 0.5))
        cone(coral, 0.55, 0.65, 1.0, 10, M(tuple(c)))
        for j in range(9):
            ja = j * 2 * math.pi / 9
            tip = c + Vector((math.cos(ja) * 0.9, math.sin(ja) * 0.9, 1.6))
            tube(coral, [c + Vector((0, 0, 1.0)), tip], [0.12, 0.06], 4, cap=False)
            uvsphere(glow, 0.11, M(tuple(tip)), u=4, v=3)


@template("SeagrassTuft", FOLIAGE=500)
def seagrass_tuft(t):
    """A tuft of seagrass (~3.5 across, ~2.6 tall): long, curling blades."""
    leaf = t.bm("FOLIAGE")
    rng = t.rng
    for k in range(14):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0, 1.4)
        x, y = math.cos(a) * r, math.sin(a) * r
        h = rng.uniform(1.6, 2.8)
        lean = rng.uniform(0.4, 1.2)
        tube(leaf, [(x, y, 0), (x + math.cos(a) * lean * 0.4, y + math.sin(a) * lean * 0.4, h * 0.6), (x + math.cos(a) * lean, y + math.sin(a) * lean, h)], [0.14, 0.09, 0.02], 3, cap=False)


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("SunkenF36Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F36_TEMPLATES.items():
        coll = bpy.data.collections.new(name)
        kit.children.link(coll)
        t = Template(name)
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
            "Size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
            "Min": [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)],
        }
    return kit, manifest


def export_kit(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "SunkenF36Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "SunkenF36Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F36_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
