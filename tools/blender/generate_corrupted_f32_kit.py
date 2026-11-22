"""
Corrupted Grove Floor 32 (Twisted Orchard) sculpted assets, generated in headless Blender.

Inspired by reference/Corrupted Grove 32.jpg and docs/prompts/corrupted-grove-floor-layouts-prompt.md:
the Hollin's grafting orchard climbing a rose-dusk south slope to the Graft Ridge and descending into the
hidden Pressing Hollow behind it.

Templates (15):
  GreatCiderPress   colossal circular oak screw-press with 108-stud central screw and oozing magenta must
  PressHouseRoof    open-ribbed pleached-willow domed press-house arbor with smoke collar
  GraftedCrownTree  the five-species grafted ridge beacon (pink, gold, olive, plum, white + dead limb)
  GraftedFruitTreeA leaning blossom-and-fruit grafted orchard tree with crutch prop and Pale Band
  GraftedFruitTreeB forked double-crown amber/plum grafted orchard tree with Pale Band
  GraftedFruitTreeC hunched Crookback pear tree bent double by its own heavy graft
  PleachedArch      flowering pleached-sapling arch (40-stud inner span, 22+ clear) with hanging rot-fruit
  EspalierWall      mossy fieldstone orchard wall with fan-trained trees pulling away with rot
  BeeSkepBench      timber bench holding five coiled-straw wicker bee-skeps (two glowing)
  CiderVatSplit     burst stave-built oak cider vat pouring glowing magenta must
  GraftingBench     grafter's trestle bench with clay rootstock pots, shoots and glowing wax cauldron
  FruitBasketPile   heaped windfall mound of wicker baskets, oak barrels, crates and glowing overripe fruit
  CrutchPoleProp    wooden orchard ladder, forked crutch pole and brimming fruit basket
  ThornBrambleArch  tangled black-rose hawthorn briar arch for Thorn Saddle
  HollinBench       weathered Hollin curved timber garden bench with graft-knot armrests

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>"). Uses only existing roles so no new
role types are needed: WOOD, TRIM, ALT, FOLIAGE, MOSS, SILK, STONE, GLOW, CANDLE, CAP, CORAL, ACCENT, METAL.

Run:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_corrupted_f32_kit.py

Outputs (assets-source/tower/corrupted_f32_kit/):
    CorruptedF32Kit.blend    the generated scene
    CorruptedF32Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json            per template: roles, reference size, triangle counts
    previews/                contact-sheet renders
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "corrupted_f32_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
lathe = kit_mod["lathe"]
tube = kit_mod["tube"]
rock = kit_mod["rock"]
ring_mesh = kit_mod["ring_mesh"]
branch_path = kit_mod["branch_path"]
canopy_blob = kit_mod["_canopy_blob"]
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


def band(bm, centre, radius, height, segs=12, tilt=(0, 0, 0)):
    """A linen Pale Band hugging a trunk or limb."""
    cone(bm, radius, radius * 0.98, height, segs, M(centre, rot=tilt))


def trailing_tail(bm, start, length, sway, seed):
    """A loose linen tail hanging from a Pale Band knot."""
    pts = [Vector(start)]
    for k in range(1, 5):
        f = k / 4
        pts.append(Vector(start) + Vector((math.sin(seed + f * 2.5) * sway * f, -0.35 * f, -length * f)))
    tube(bm, pts, [0.28, 0.26, 0.22, 0.16, 0.08], 4)


def hanging_fruit(bm_wood, bm_glow, anchor, drop=2.2, radius=0.65):
    """A glowing overripe rot-fruit hanging on a slender stem below a bough."""
    a = Vector(anchor)
    tip = a + Vector((0, 0, -drop))
    tube(bm_wood, [a, tip + Vector((0, 0, radius * 0.8))], [0.08, 0.06], 4)
    uvsphere(bm_glow, radius, M(tip, scale=(0.95, 0.95, 1.18)), u=8, v=6)


DEFAULT_BUDGET = 3500
F32_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F32_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("GreatCiderPress", STONE=1400, WOOD=3400, TRIM=1400, METAL=800, GLOW=1200, CAP=900)
def great_cider_press(t):
    """Colossal circular oak screw-press (~36 x 38 x 108): stone base, stave tub, giant threaded oak screw
    rising through the dome, capstan bars, and glowing magenta must pouring down the front (-Y) trough."""
    stone, wood, trim, metal, glow, cap = (
        t.bm("STONE"), t.bm("WOOD"), t.bm("TRIM"), t.bm("METAL"), t.bm("GLOW"), t.bm("CAP")
    )
    rng = t.rng

    # Circular fieldstone footing plinth (radius 17, Z 0..5).
    cone(stone, 17.5, 16.5, 5.0, 20, M((0, 0, 0)))
    for k in range(16):
        a = k * 2 * math.pi / 16
        rock_clean(
            stone,
            (rng.uniform(3.4, 5.0), rng.uniform(3.0, 4.4), rng.uniform(2.6, 4.2)),
            M((math.cos(a) * 16.8, math.sin(a) * 16.8, 0)),
            100 + k,
            subdiv=1,
        )

    # Stave-built press tub (radius 13.5, Z 4.8..19.5): 24 individual vertical oak staves with gaps for must.
    for k in range(24):
        a = k * 2 * math.pi / 24
        x, y = math.cos(a) * 13.2, math.sin(a) * 13.2
        box(wood, (2.6, 1.1, 14.8), M((x, y, 12.2), rot=(0, 0, a + math.pi / 2)), bevel=0.1)
    # Three iron hoops & dark-timber bands around the stave vat.
    for z in (7.0, 12.2, 17.6):
        ring_mesh(metal, 13.9, 0.48, 28, M((0, 0, z)), tube_segs=6)
    # Heavy circular oak pressing disc inside the tub (Z 15.5..18.0).
    cone(trim, 12.2, 12.2, 2.4, 20, M((0, 0, 15.6)))

    # Massive four-post oak press frame & crosshead beam (Z 5..46) straddling the tub along X.
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(wood, (2.8, 2.8, 42.0), M((sx * 14.5, sy * 3.8, 25.0)), bevel=0.2)
        # Diagonal buttress struts bracing the posts.
        tube(wood, [(sx * 19.5, 0, 2.0), (sx * 14.8, 0, 24.0)], [1.5, 1.2], 6)
    # Double crosshead beam clamping the central screw at Z 42..48.
    box(wood, (35.0, 9.6, 5.4), M((0, 0, 44.5)), bevel=0.35)
    for sx in (-1, 1):
        box(metal, (1.4, 10.2, 6.0), M((sx * 11.0, 0, 44.5)), bevel=0.08)

    # Colossal central oak screw shaft rising straight up through the press-house roof to Z = 108!
    cone(wood, 3.4, 3.0, 90.0, 16, M((0, 0, 17.5)))
    # Sculpted helical screw threads (stacked tilted rings from Z 20..92).
    for k in range(22):
        z = 20.0 + k * 3.3
        r = 3.55 - k * 0.015
        ring_mesh(trim, r, 0.65, 16, M((0, 0, z), rot=(0.08, 0.0, k * 0.5)), tube_segs=5)
    # Heavy capstan turning wheel & four radial lever beams at Z 31 (visible through the open willow dome).
    ring_mesh(trim, 8.8, 0.9, 20, M((0, 0, 31.0)), tube_segs=6)
    for k in range(4):
        a = k * math.pi / 2 + 0.35
        tube(wood, [(0, 0, 31.0), (math.cos(a) * 15.5, math.sin(a) * 15.5, 31.0)], [1.1, 0.75], 6)
    # Finial cap at the very top of the screw beam (Z 105..108).
    cone(trim, 3.8, 1.4, 3.6, 12, M((0, 0, 104.5)))
    ring_mesh(metal, 3.3, 0.45, 16, M((0, 0, 104.2)), tube_segs=5)

    # Front (-Y) wooden catch spout, stone drainage basin, and oozing glowing magenta cider must!
    box(wood, (6.2, 7.5, 1.8), M((0, -15.6, 5.8), rot=(-0.18, 0, 0)), bevel=0.12)
    for sx in (-1, 1):
        box(wood, (0.9, 7.5, 2.2), M((sx * 2.8, -15.6, 6.7), rot=(-0.18, 0, 0)), bevel=0.08)
    # Stone trough under the spout.
    box(stone, (10.5, 7.2, 2.6), M((0, -19.2, 1.3)), bevel=0.35)
    # Glowing magenta must oozing through tub staves & streaming down the front spout into a glowing pool.
    for k in range(7):
        a = -math.pi / 2 + (k - 3) * 0.24
        x, y = math.cos(a) * 13.7, math.sin(a) * 13.7
        pts = [
            Vector((x, y, 16.5 - abs(k - 3) * 0.7)),
            Vector((x * 1.03, y * 1.03, 10.5)),
            Vector((x * 1.05, y * 1.05, 5.2)),
        ]
        tube(glow, pts, [0.55, 0.45, 0.65], 5)
    # Thick glossy cascade pouring from spout into trough and spilling forward onto ground.
    tube(glow, [(0, -13.0, 7.2), (0, -17.5, 5.4), (0, -19.2, 2.5)], [2.1, 1.8, 1.6], 8)
    uvsphere(glow, 4.4, M((0, -19.2, 2.2), scale=(1.1, 0.75, 0.22)), u=12, v=6)
    # Overflowing dark-plum & magenta must puddles around the front base.
    uvsphere(cap, 6.2, M((0, -21.0, 0.35), scale=(1.2, 0.9, 0.16)), u=12, v=6)
    uvsphere(glow, 3.8, M((2.0, -20.5, 0.45), scale=(1.0, 0.75, 0.14)), u=10, v=5)
    # Pressed pomace / fruit pulp rim inside the top of the vat.
    ring_mesh(cap, 11.4, 1.6, 20, M((0, 0, 18.2)), tube_segs=6)


@template("PressHouseRoof", STONE=1400, WOOD=3400, ALT=2200, MOSS=1000, FOLIAGE=1400)
def press_house_roof(t):
    """Open-ribbed pleached-willow beehive dome (~62 x 62 x 52) arching wide over the Great Cider Press,
    matching the painting's broad woven willow dome with stone footings, thatched upper ribs and smoke collar."""
    stone, wood, alt, moss, leaf = t.bm("STONE"), t.bm("WOOD"), t.bm("ALT"), t.bm("MOSS"), t.bm("FOLIAGE")

    # 12 arched pleached-willow ribs curving broadly from radius 29.5 at ground to radius 6.4 at Z 47.
    # Leave a wider front archway at -Y so the oak press tub and glowing magenta must cascade read clearly!
    rib_angles = []
    for k in range(12):
        a = -math.pi / 2 + 0.36 + k * (2 * math.pi - 0.72) / 11
        rib_angles.append(a)

    for idx, a in enumerate(rib_angles):
        ca, sa = math.cos(a), math.sin(a)
        rock_clean(stone, (5.4, 5.0, 4.6), M((ca * 29.5, sa * 29.5, 0)), 140 + idx, subdiv=1)
        pts, radii = [], []
        for step in range(11):
            u = step / 10.0
            # Broad beehive dome curve: wide waist, sweeping inward to the smoke collar at Z 47.
            r = 29.5 * (math.cos(u * math.pi * 0.5) ** 0.78) + 6.4 * (u ** 1.4)
            if step == 10:
                r = 6.4
            z = 2.0 + 45.0 * (math.sin(u * math.pi * 0.5) ** 0.88)
            wob = math.sin(u * 8.0 + idx) * 0.7
            pts.append(Vector((ca * r - sa * wob, sa * r + ca * wob, z)))
            radii.append(1.7 - 0.75 * u)
        tube(wood, pts, radii, 7)
        if idx % 2 == 0:
            pts2 = [p + Vector((math.cos(a + k) * 0.9, math.sin(a + k) * 0.9, 0.35)) for k, p in enumerate(pts[1:-1])]
            tube(wood, pts2, [0.55] * len(pts2), 5)

    # Woven horizontal willow-and-thatch bands circling the dome (open over the -Y archway at lower rings).
    for ring_idx, (z, r, thick) in enumerate((
        (14.0, 28.4, 0.85), (23.0, 26.2, 0.9), (31.5, 22.4, 1.05), (38.5, 17.5, 1.1), (43.5, 12.2, 1.15)
    )):
        segs = 26
        pts = []
        start_k = 2 if ring_idx < 2 else 0
        end_k = segs - 1 if ring_idx < 2 else segs + 1
        for k in range(start_k, end_k):
            a = -math.pi / 2 + k * 2 * math.pi / segs
            pts.append(Vector((math.cos(a) * r, math.sin(a) * r, z + math.sin(k * 2.2 + ring_idx) * 0.45)))
        tube(alt if ring_idx >= 1 else wood, pts, [thick] * len(pts), 5, cap=False)

    # Front grand arched lintel framing the -Y opening into the press tub.
    a0, a1 = rib_angles[0], rib_angles[-1]
    lintel = []
    for step in range(9):
        u = step / 8.0
        x = math.cos(a0) * 28.8 * (1 - u) + math.cos(a1) * 28.8 * u
        y = math.sin(a0) * 28.8 * (1 - u) + math.sin(a1) * 28.8 * u - 1.5 * math.sin(u * math.pi)
        z = 18.0 + 9.5 * math.sin(u * math.pi)
        lintel.append(Vector((x, y, z)))
    tube(wood, lintel, [1.35] * len(lintel), 6)

    # Crowned timber-and-stone smoke-flue collar at Z 46..53 (the 108-stud screw rises straight through!).
    ring_mesh(wood, 6.8, 1.45, 20, M((0, 0, 47.0)), tube_segs=6)
    ring_mesh(stone, 6.2, 1.35, 18, M((0, 0, 50.6)), tube_segs=6)
    ring_mesh(alt, 9.2, 1.25, 20, M((0, 0, 44.5)), tube_segs=5)

    # Lush moss & vine garlands draped over the dome's broad shoulders.
    for k in range(10):
        a = k * 2 * math.pi / 10 + 0.4
        r = 22.0 - (k % 2) * 5.0
        z = 30.0 + (k % 2) * 9.0
        rock_clean(moss, (6.2, 5.2, 2.0), M((math.cos(a) * r, math.sin(a) * r, z)), 180 + k, subdiv=1)
        canopy_blob(leaf, Vector((math.cos(a) * (r + 1.4), math.sin(a) * (r + 1.4), z - 1.5)), (8.5, 7.5, 5.2), 195 + k, subdiv=2)


@template(
    "GraftedCrownTree",
    WOOD=4400, CORAL=1600, ALT=1600, FOLIAGE=1800, CAP=1600, ACCENT=1400, SILK=600, GLOW=700, MOSS=600, STONE=600,
)
def grafted_crown_tree(t):
    """The Grafted Crown (~78 x 48 x 60): colossal ancient grafted orchard tree on the ridge crest with
    five lush seasonal/species limbs (pink blossom, golden amber, olive fruiting, plum-crimson,
    pale white blossom) plus one bare blackened dead eastern limb, every living limb wrapped in a Pale Band."""
    wood = t.bm("WOOD")
    coral = t.bm("CORAL")     # limb 1 (far west): pink cherry blossom
    alt = t.bm("ALT")         # limb 2 (upper west): golden amber
    foliage = t.bm("FOLIAGE") # limb 3 (centre crown): olive green fruiting
    cap = t.bm("CAP")         # limb 4 (upper east): crimson-plum
    accent = t.bm("ACCENT")   # limb 5 (lower east): pale white blossom
    silk = t.bm("SILK")       # Pale Bands around trunk & every limb
    glow = t.bm("GLOW")       # glowing rot-seams in graft union + hanging fruits
    moss = t.bm("MOSS")
    stone = t.bm("STONE")
    rng = t.rng

    # Braided, thick gnarled trunk rising to the great graft-knuckle at Z 20.
    trunk_pts = [
        Vector((0, 0, -1.0)),
        Vector((-0.5, 0.4, 5.0)),
        Vector((0.6, -0.3, 11.5)),
        Vector((-0.3, 0.2, 17.5)),
        Vector((0.0, 0.0, 22.5)),
    ]
    tube(wood, trunk_pts, [6.4, 5.4, 4.9, 5.6, 4.6], 12)

    # 8 sweeping root buttresses gripping mossy boulders at the foot.
    for k in range(8):
        a = k * 2 * math.pi / 8 + rng.uniform(-0.15, 0.15)
        reach = rng.uniform(13.5, 20.0)
        tube(
            wood,
            [
                (math.cos(a) * 3.8, math.sin(a) * 3.8, 7.2),
                (math.cos(a) * reach * 0.55, math.sin(a) * reach * 0.55, 2.8),
                (math.cos(a) * reach, math.sin(a) * reach, -0.9),
            ],
            [2.7, 1.85, 0.72],
            7,
        )
        if k % 2 == 0:
            rock_clean(stone, (5.0, 4.4, 2.8), M((math.cos(a + 0.3) * reach * 0.72, math.sin(a + 0.3) * reach * 0.72, 0)), 210 + k, subdiv=1)
    for k in range(5):
        a = k * 2 * math.pi / 5
        rock_clean(moss, (5.8, 5.0, 1.4), M((math.cos(a) * 7.5, math.sin(a) * 7.5, 0.2)), 230 + k, subdiv=1)

    # Great Pale Band around the main trunk below the graft union, plus glowing magenta rot seams!
    band(silk, (0.3, -0.1, 11.8), 5.2, 2.1, segs=14)
    trailing_tail(silk, (5.0, -1.2, 12.0), 5.4, 1.0, 1.4)
    for k in range(4):
        a = -math.pi / 2 + (k - 1.5) * 0.65
        tube(
            glow,
            [
                (math.cos(a) * 4.7, math.sin(a) * 4.7, 14.0),
                (math.cos(a + 0.15) * 5.4, math.sin(a + 0.15) * 5.4, 18.5),
                (math.cos(a - 0.1) * 4.8, math.sin(a - 0.1) * 4.8, 22.8),
            ],
            [0.45, 0.64, 0.38],
            5,
        )

    def add_limb(pts, radii, bm_leaf, blobs, seed_base, add_fruits=True):
        vpts = [Vector(p) for p in pts]
        tube(wood, vpts, radii, 8)
        mid = vpts[1]
        d = (vpts[2] - vpts[0]).normalized()
        pitch = math.atan2(math.sqrt(d.x * d.x + d.y * d.y), d.z)
        yaw = math.atan2(d.y, d.x)
        band(silk, mid, radii[1] + 0.25, 1.5, segs=10, tilt=(0, pitch, yaw))
        fork_tip = vpts[-1] + Vector((d.x * 5.0, d.y * 5.0 + 2.5, 3.5))
        tube(wood, [vpts[-2], fork_tip], [radii[-2] * 0.75, 0.45], 6)
        if bm_leaf is not None:
            for idx, (off, sz) in enumerate(blobs):
                c = vpts[-1] + Vector(off)
                canopy_blob(bm_leaf, c, sz, seed_base + idx * 7, subdiv=2)
            if add_fruits:
                for f_idx in range(3):
                    p = vpts[-1] + Vector(((f_idx - 1) * 4.8, -2.8 + (f_idx % 2) * 3.0, -2.0))
                    hanging_fruit(wood, glow, p, drop=2.8 + (f_idx % 2) * 0.8, radius=0.82)

    # 1. Far-west limb (-X): lush pink cherry blossom (CORAL).
    add_limb(
        [(-2.2, 0.0, 20.5), (-11.0, -2.5, 25.5), (-20.0, -3.5, 30.5), (-26.5, -2.0, 34.5)],
        [2.6, 2.1, 1.5, 0.8],
        coral,
        [
            ((0, 0, 3.0), (19.0, 16.0, 11.5)),
            ((6.5, -2.5, 5.5), (15.0, 13.0, 9.5)),
            ((-5.0, 3.0, 0.5), (14.0, 12.5, 8.8)),
        ],
        250,
    )
    # 2. Upper-west limb (-X, high): golden-amber autumn crown (ALT).
    add_limb(
        [(-1.5, 1.2, 22.0), (-8.0, 2.5, 31.5), (-13.5, 3.0, 40.5), (-16.0, 1.5, 45.5)],
        [2.5, 2.0, 1.4, 0.75],
        alt,
        [
            ((0, 0, 3.0), (20.0, 17.0, 12.5)),
            ((5.5, -3.0, 4.5), (15.5, 13.5, 10.5)),
            ((-4.0, 3.0, 1.5), (14.5, 12.5, 9.5)),
        ],
        280,
    )
    # 3. Central crown (0, highest): olive-green fruiting canopy (FOLIAGE).
    add_limb(
        [(0.0, 0.0, 22.5), (0.5, -1.5, 32.5), (-0.5, 0.5, 42.0), (1.0, 0.0, 48.0)],
        [2.8, 2.2, 1.5, 0.8],
        foliage,
        [
            ((0, 0, 4.0), (22.0, 19.0, 13.5)),
            ((-6.0, -2.5, 1.5), (16.0, 14.0, 10.0)),
            ((6.5, 2.5, 2.0), (16.5, 14.5, 10.0)),
        ],
        310,
    )
    # 4. Upper-east limb (+X, high): deep crimson-plum canopy (CAP).
    add_limb(
        [(1.8, 1.0, 22.0), (8.5, 2.0, 31.0), (14.5, 2.5, 39.5), (18.5, 1.5, 44.0)],
        [2.4, 1.9, 1.35, 0.7],
        cap,
        [
            ((0, 0, 3.0), (19.0, 16.5, 12.0)),
            ((-4.5, -2.5, 4.0), (15.0, 13.0, 10.0)),
            ((4.0, 2.5, 1.0), (14.0, 12.0, 9.0)),
        ],
        340,
    )
    # 5. Lower-east limb (+X, front-right): pale white blossom canopy (ACCENT).
    add_limb(
        [(2.5, -1.2, 20.0), (10.5, -3.5, 24.0), (17.5, -4.0, 26.5), (22.5, -2.5, 28.5)],
        [2.2, 1.75, 1.25, 0.65],
        accent,
        [
            ((0, 0, 2.5), (16.5, 14.5, 10.5)),
            ((-5.0, 2.0, 3.5), (13.5, 12.0, 8.5)),
        ],
        370,
        add_fruits=False,
    )
    # 6. Far-east bare blackened dead limb (WOOD only, reaching dramatically east like the guide image).
    dead_pts = [Vector((2.6, 0.6, 20.5)), Vector((12.5, 1.5, 26.5)), Vector((23.0, 2.5, 32.0)), Vector((33.5, 1.0, 37.5))]
    tube(wood, dead_pts, [2.1, 1.55, 1.0, 0.4], 7)
    for k, (idx, ang, z_up, length) in enumerate(((1, 0.5, 7.5, 9.5), (2, -0.4, 7.0, 10.5), (2, 0.8, 3.2, 9.0), (3, 0.2, 6.0, 8.0))):
        p0 = dead_pts[idx]
        p1 = p0 + Vector((math.cos(ang) * length * 0.6, math.sin(ang) * length * 0.6, z_up * 0.55))
        p2 = p0 + Vector((math.cos(ang) * length, math.sin(ang) * length, z_up))
        tube(wood, [p0, p1, p2], [0.75, 0.45, 0.14], 5)


@template("GraftedFruitTreeA", WOOD=2200, TRIM=500, FOLIAGE=1800, CORAL=1600, SILK=300, GLOW=450, MOSS=300)
def grafted_fruit_tree_a(t):
    """Orchard row tree A (~27 x 24 x 28): twisted apple/pear trunk leaning under heavy fruit, propped on a
    forked wooden crutch pole, tied with a stained Pale Band, lush rose-blossom & amber crown, glowing fruit."""
    wood, trim, leaf, coral, silk, glow, moss = (
        t.bm("WOOD"), t.bm("TRIM"), t.bm("FOLIAGE"), t.bm("CORAL"), t.bm("SILK"), t.bm("GLOW"), t.bm("MOSS")
    )
    trunk = [
        Vector((0, 0, -0.6)),
        Vector((0.8, -0.3, 4.0)),
        Vector((2.2, 0.4, 8.5)),
        Vector((1.6, 0.6, 13.0)),
        Vector((0.4, 0.2, 16.5)),
    ]
    tube(wood, trunk, [2.2, 1.85, 2.05, 1.5, 1.05], 9)
    for k in range(4):
        a = k * math.pi / 2 + 0.3
        tube(wood, [(math.cos(a) * 1.4, math.sin(a) * 1.4, 2.0), (math.cos(a) * 4.5, math.sin(a) * 4.5, -0.4)], [0.95, 0.3], 5)
    band(silk, trunk[2], 2.25, 1.35)
    trailing_tail(silk, (trunk[2].x + 2.1, trunk[2].y - 0.5, trunk[2].z), 3.0, 0.55, 1.1)

    boughs = [
        (trunk[3], Vector((9.5, -2.5, 17.5)), True),
        (trunk[3], Vector((-8.5, -2.0, 18.5)), False),
        (trunk[4], Vector((-5.5, 7.0, 20.5)), True),
        (trunk[4], Vector((6.5, 6.5, 19.8)), False),
        (trunk[4], Vector((0.5, -1.0, 22.0)), True),
    ]
    for idx, (start, end, is_coral) in enumerate(boughs):
        mid = (start + end) * 0.5 + Vector((0, 0, 1.8))
        tube(wood, [start, mid, end], [1.05, 0.72, 0.35], 6)
        bm_f = coral if is_coral else leaf
        canopy_blob(bm_f, end + Vector((0, 0, 2.0)), (11.5, 10.5, 7.2), 410 + idx * 11, subdiv=2)
        canopy_blob(bm_f, mid + Vector((0, 0, 3.0)), (8.0, 7.5, 5.2), 415 + idx * 11, subdiv=2)
        hanging_fruit(wood, glow, mid + Vector((0, -0.6, -0.4)), drop=2.1, radius=0.68)
        hanging_fruit(wood, glow, end + Vector((0, 0, -0.8)), drop=2.4, radius=0.75)

    prop_top = Vector((6.8, -1.6, 15.6))
    prop_bot = Vector((9.2, -2.2, -0.4))
    tube(trim, [prop_bot, prop_top], [0.42, 0.34], 6)
    for sy in (-1, 1):
        tube(trim, [prop_top + Vector((0, 0, -1.2)), prop_top + Vector((0, sy * 1.4, 1.1))], [0.28, 0.2], 5)
    rock_clean(moss, (5.2, 4.6, 0.9), M((0, 0, 0)), 450, subdiv=1)


@template("GraftedFruitTreeB", WOOD=2200, TRIM=400, FOLIAGE=1800, CAP=1600, SILK=300, GLOW=450, MOSS=300)
def grafted_fruit_tree_b(t):
    """Orchard row tree B (~32 x 24 x 31): double-forked grafted fruit tree — one lush crown golden-amber
    (FOLIAGE), the grafted sister crown bruised plum-rose (CAP), bound with a Pale Band and glowing fruit."""
    wood, trim, leaf, cap, silk, glow, moss = (
        t.bm("WOOD"), t.bm("TRIM"), t.bm("FOLIAGE"), t.bm("CAP"), t.bm("SILK"), t.bm("GLOW"), t.bm("MOSS")
    )
    trunk = [Vector((0, 0, -0.6)), Vector((-0.6, 0.3, 4.5)), Vector((0.4, -0.2, 9.5)), Vector((0.0, 0.0, 12.5))]
    tube(wood, trunk, [2.4, 2.0, 2.2, 1.9], 9)
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.2
        tube(wood, [(math.cos(a) * 1.5, math.sin(a) * 1.5, 2.2), (math.cos(a) * 5.0, math.sin(a) * 5.0, -0.4)], [1.0, 0.3], 5)
    band(silk, (0.2, -0.1, 8.8), 2.35, 1.4)
    trailing_tail(silk, (2.4, -0.5, 9.0), 3.4, 0.6, 2.3)
    ring_mesh(trim, 2.3, 0.22, 14, M((0.2, -0.1, 10.6)), tube_segs=4)

    fork_a = [trunk[-1], Vector((-5.5, -1.5, 17.5)), Vector((-10.0, -2.5, 22.0))]
    tube(wood, fork_a, [1.5, 1.1, 0.55], 7)
    canopy_blob(leaf, fork_a[-1] + Vector((0, 0, 2.5)), (15.0, 13.5, 9.2), 480, subdiv=2)
    canopy_blob(leaf, fork_a[1] + Vector((-2.5, 3.8, 3.5)), (12.0, 10.5, 7.6), 487, subdiv=2)

    fork_b = [trunk[-1], Vector((5.5, 1.2, 18.5)), Vector((10.5, 2.0, 23.5))]
    tube(wood, fork_b, [1.55, 1.15, 0.6], 7)
    band(silk, fork_b[1], 1.3, 1.0, tilt=(0, 0.5, 0.2))
    canopy_blob(cap, fork_b[-1] + Vector((0, 0, 2.5)), (15.5, 13.8, 9.5), 495, subdiv=2)
    canopy_blob(cap, fork_b[1] + Vector((2.5, -3.8, 3.0)), (12.5, 11.0, 7.8), 503, subdiv=2)

    for p in (
        Vector((-8.5, -2.5, 18.5)), Vector((-4.5, 2.5, 17.5)),
        Vector((8.5, 1.0, 19.5)), Vector((11.0, -1.5, 20.0)), Vector((5.0, -3.0, 17.0)),
    ):
        hanging_fruit(wood, glow, p, drop=2.3, radius=0.72)
    rock_clean(moss, (5.6, 5.2, 1.0), M((0, 0, 0)), 515, subdiv=1)


@template("GraftedFruitTreeC", WOOD=2200, FOLIAGE=1600, CORAL=1600, SILK=300, GLOW=400, MOSS=300)
def grafted_fruit_tree_c(t):
    """Crookback pear tree (~26 x 18 x 22): a lone, gnarled pear tree bent double to +X by its own heavy graft,
    arching gracefully over a bench or trail, banded with a stained Pale Band and glowing fruit."""
    wood, leaf, coral, silk, glow, moss = (
        t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("CORAL"), t.bm("SILK"), t.bm("GLOW"), t.bm("MOSS")
    )
    trunk = [
        Vector((-7.0, 0, -0.6)),
        Vector((-6.5, 0.4, 5.5)),
        Vector((-4.2, 0.2, 11.5)),
        Vector((0.5, -0.3, 15.0)),
        Vector((5.8, -0.2, 14.5)),
        Vector((9.8, 0.4, 12.0)),
    ]
    tube(wood, trunk, [2.5, 2.1, 1.9, 1.7, 1.2, 0.65], 9)
    for k in range(5):
        a = k * 2 * math.pi / 5
        tube(wood, [(-7.0 + math.cos(a) * 1.4, math.sin(a) * 1.4, 2.2), (-7.0 + math.cos(a) * 4.8, math.sin(a) * 4.8, -0.4)], [1.0, 0.3], 5)
    band(silk, trunk[1], 2.25, 1.35)
    trailing_tail(silk, (trunk[1].x + 2.0, trunk[1].y - 0.5, trunk[1].z), 3.2, 0.6, 0.9)

    canopy_blob(leaf, Vector((-1.5, 1.5, 17.8)), (14.0, 12.0, 8.2), 530, subdiv=2)
    canopy_blob(coral, Vector((5.5, -1.5, 16.8)), (13.5, 11.5, 7.8), 539, subdiv=2)
    canopy_blob(leaf, Vector((10.0, 1.0, 14.2)), (11.5, 10.5, 7.0), 547, subdiv=2)

    for p in (Vector((1.0, -1.5, 14.2)), Vector((6.0, -1.0, 13.5)), Vector((9.5, 0.2, 11.5)), Vector((-2.5, -1.8, 13.8))):
        hanging_fruit(wood, glow, p, drop=2.2, radius=0.7)
    rock_clean(moss, (6.0, 5.0, 1.1), M((-7.0, 0, 0)), 555, subdiv=1)


@template("PleachedArch", STONE=800, WOOD=2600, FOLIAGE=1800, CORAL=1800, GLOW=450, SILK=400, TRIM=400)
def pleached_arch(t):
    """Living orchard arch (40-stud inner clear span, 22+ studs clear overhead, total ~50 x 13 x 34):
    stone-footed braided sapling piers arching overhead into a lush blossom canopy with a carved graft-knot
    keystone and hanging glowing magenta rot-fruits. Used for Orchard Gate and Grafters' Stair tunnel."""
    stone, wood, leaf, coral, glow, silk, trim = (
        t.bm("STONE"), t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("CORAL"), t.bm("GLOW"), t.bm("SILK"), t.bm("TRIM")
    )
    half = 21.5
    for s in (-1, 1):
        box(stone, (5.2, 5.2, 4.4), M((s * half, 0, 2.2)), bevel=0.55)
        rock_clean(stone, (4.2, 4.0, 2.6), M((s * (half + 1.8), -1.4, 0)), 580 + s, subdiv=1)
        for j, dy in enumerate((-1.2, 1.2)):
            pts = [
                Vector((s * half, dy, 1.0)),
                Vector((s * (half + 0.6 * (1 if j == 0 else -1)), dy * 0.6, 10.0)),
                Vector((s * (half - 0.5), -dy * 0.4, 19.5)),
            ]
            tube(wood, pts, [1.25, 1.05, 0.95], 7)
        band(silk, (s * half, 0, 8.5), 1.85, 1.4)
        trailing_tail(silk, (s * half, -1.8, 8.5), 3.8, 0.7, s + 2)

    for j, (dy, r) in enumerate(((-1.4, 0.85), (0.0, 1.05), (1.4, 0.85))):
        pts = []
        for k in range(15):
            u = -1.0 + 2.0 * k / 14.0
            x = u * half
            y = dy + math.sin(u * 8.0 + j * 2.0) * 0.8
            z = 19.5 + 9.2 * (1.0 - u * u) + math.cos(u * 6.0 + j) * 0.4
            pts.append(Vector((x, y, z)))
        tube(wood, pts, [r] * len(pts), 6)

    for s in (-1, 1):
        tube(wood, [(-3.4 * s, -1.8, 26.2), (0, -1.8, 29.0), (3.4 * s, -1.8, 31.8)], [0.55, 0.65, 0.4], 6)
    ring_mesh(trim, 2.0, 0.42, 16, M((0, -1.8, 29.0), rot=(math.pi / 2, 0, 0)), tube_segs=5)

    # Lush blossoms & foliage garland along the upper arch (strictly Z >= 23, clear of walkway!).
    for k in range(9):
        u = -0.88 + k * (1.76 / 8.0)
        x = u * half
        z = 21.8 + 8.5 * (1.0 - u * u)
        bm_target = coral if k % 2 == 0 else leaf
        canopy_blob(bm_target, Vector((x, (k % 2 - 0.5) * 2.4, z + 1.8)), (10.5, 9.0, 6.0), 600 + k * 7, subdiv=2)
        if abs(u) < 0.72 and k % 2 == 1:
            hanging_fruit(wood, glow, Vector((x, -1.2 + (k % 2) * 2.4, z - 1.2)), drop=2.4, radius=0.75)


@template("EspalierWall", STONE=2200, MOSS=600, WOOD=1800, FOLIAGE=900, CORAL=900, GLOW=450, SILK=250)
def espalier_wall(t):
    """West Espalier (~28 x 6 x 15): mossy fieldstone orchard wall with flat fan-trained fruit trees grafted
    against the -Y face; the east half twists off the stone with glowing rot-fruits and torn Pale Bands."""
    stone, moss, wood, leaf, coral, glow, silk = (
        t.bm("STONE"), t.bm("MOSS"), t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("CORAL"), t.bm("GLOW"), t.bm("SILK")
    )
    rng = t.rng

    # Stepped fieldstone wall body along X (-13.5..+13.5) with arched stone coping.
    box(stone, (26.5, 3.0, 12.0), M((0, 0.4, 6.0)), bevel=0.35)
    for k in range(11):
        x = -12.5 + k * 2.5
        rock_clean(stone, (3.2, 3.8, rng.uniform(1.8, 2.8)), M((x, 0.4, 11.4 + math.sin(k * 0.7) * 0.5)), 650 + k, subdiv=1)
        if k % 2 == 0:
            rock_clean(stone, (3.4, 4.0, 2.6), M((x, 0.4, 0)), 670 + k, subdiv=1)
    for k in range(5):
        rock_clean(moss, (4.8, 3.4, 1.0), M((-10.0 + k * 5.0, 0.2, 12.8)), 690 + k, subdiv=1)

    # Left half (-X): tidy fan-trained espalier pear tree pinned flat against the -Y wall face.
    base_l = Vector((-6.5, -1.3, 0))
    tube(wood, [base_l, Vector((-6.5, -1.3, 4.0))], [0.95, 0.75], 6)
    band(silk, (-6.5, -1.3, 2.4), 0.95, 0.85, segs=8)
    for ang_deg in (-65, -35, 0, 35, 65):
        rad = math.radians(ang_deg)
        tip = Vector((-6.5 + math.sin(rad) * 6.5, -1.45, 4.0 + math.cos(rad) * 7.2))
        tube(wood, [Vector((-6.5, -1.3, 4.0)), tip], [0.45, 0.18], 5)
        canopy_blob(leaf if ang_deg % 2 == 0 else coral, tip + Vector((0, -0.5, 0.4)), (4.4, 2.6, 3.8), 710 + ang_deg, subdiv=2)

    # Right half (+X): blighted fan tree pulling violently forward (-Y) off the wall with glowing magenta rot!
    base_r = Vector((6.5, -1.3, 0))
    tube(wood, [base_r, Vector((6.5, -2.0, 4.5)), Vector((7.2, -3.8, 8.8))], [1.1, 0.9, 0.65], 7)
    for k, (dx, dy, dz) in enumerate(((-4.2, -3.5, 9.8), (1.0, -4.6, 11.5), (5.0, -3.2, 10.2), (-2.0, -4.2, 6.2))):
        tip = Vector((6.5 + dx, dy, dz))
        tube(wood, [Vector((6.8, -2.6, 5.8)), tip], [0.55, 0.22], 5)
        canopy_blob(coral, tip, (4.8, 3.4, 4.0), 740 + k, subdiv=2)
        hanging_fruit(wood, glow, tip + Vector((0, -0.5, -0.4)), drop=1.5, radius=0.55)
    # Glowing rot-fissure where the roots tore the wall stones apart.
    tube(glow, [(6.5, -1.2, 1.0), (5.5, -1.4, 5.2), (8.2, -1.4, 9.0)], [0.45, 0.35, 0.25], 5)


@template("BeeSkepBench", WOOD=1200, STONE=600, ALT=1800, TRIM=600, GLOW=400, CANDLE=250)
def bee_skep_bench(t):
    """Skep Terrace (~22 x 6.5 x 9.5): long timber apiary bench with a back rail holding 5 coiled-straw
    wicker bee-skeps. Three are dark/tilted dead hives; two glow warmly with amber/magenta light."""
    wood, stone, alt, trim, glow, candle = (
        t.bm("WOOD"), t.bm("STONE"), t.bm("ALT"), t.bm("TRIM"), t.bm("GLOW"), t.bm("CANDLE")
    )
    # Three stone supports and long timber bench plank.
    for x in (-9.2, 0.0, 9.2):
        rock_clean(stone, (2.6, 4.4, 3.0), M((x, 0, 0)), 780 + int(x), subdiv=1)
    box(wood, (21.5, 4.6, 0.9), M((0, 0, 3.1)), bevel=0.1)
    # Rustic shed back-posts and narrow rain-board overhang above the skeps.
    for x in (-9.6, 9.6):
        tube(wood, [(x, 1.8, 0), (x, 1.8, 8.8)], [0.42, 0.36], 6)
    box(wood, (21.6, 3.8, 0.65), M((0, 0.6, 8.9), rot=(-0.22, 0, 0)), bevel=0.08)

    # Five coiled wicker bee-skeps standing on the bench (Z 3.5..7.5).
    skep_profile = [(1.65, 0.0), (1.78, 0.9), (1.65, 1.9), (1.3, 2.8), (0.75, 3.5), (0.18, 3.85)]
    specs = [
        (-7.6, 0.0, 0.14, False),   # tilted dead
        (-3.8, 0.1, -0.05, False),  # dead
        (0.0, -0.1, 0.0, True),     # humming & glowing!
        (3.8, 0.0, 0.03, True),     # humming & glowing!
        (7.6, -0.1, -0.18, False),  # toppled/dead
    ]
    for idx, (x, y, tilt_y, alive) in enumerate(specs):
        mat_skep = M((x, y, 3.55), rot=(0, tilt_y, 0))
        lathe(alt, skep_profile, 14, mat_skep)
        # Coiled straw ribs around each skep.
        for rz, rr in ((0.6, 1.76), (1.4, 1.74), (2.2, 1.54), (3.0, 1.15)):
            ring_mesh(trim, rr, 0.14, 14, mat_skep @ M((0, 0, rz)), tube_segs=4)
        # Entrance arch on front (-Y).
        if alive:
            uvsphere(glow, 0.52, mat_skep @ M((0, -1.62, 0.85), scale=(1.0, 0.45, 1.1)), u=8, v=5)
            uvsphere(candle, 0.28, mat_skep @ M((0, -1.72, 0.85), scale=(1.0, 0.5, 1.0)), u=6, v=4)
            # Swarm motes hovering above the live skep.
            for m in range(5):
                ma = m * 1.25 + idx
                uvsphere(glow, 0.16, M((x + math.cos(ma) * 1.1, y - 0.8 + math.sin(ma) * 0.9, 6.2 + (m % 3) * 0.65)), u=5, v=4)
        else:
            box(wood, (0.75, 0.4, 0.85), mat_skep @ M((0, -1.62, 0.8)))


@template("CiderVatSplit", WOOD=2200, METAL=600, TRIM=500, GLOW=900, CAP=700)
def cider_vat_split(t):
    """Split oak cider vat (~17 x 18 x 12) bursting open on the -Y side and spilling glowing magenta must,
    with a wooden step-ladder and two cooperage oak barrels beside it."""
    wood, metal, trim, glow, cap = t.bm("WOOD"), t.bm("METAL"), t.bm("TRIM"), t.bm("GLOW"), t.bm("CAP")

    # Open-topped oak stave vat (radius 6.2, Z 0..9.2); front two staves busted outward!
    for k in range(20):
        a = k * 2 * math.pi / 20
        front = abs(((a + math.pi / 2 + math.pi) % (2 * math.pi)) - math.pi) < 0.36
        r = 6.2 if not front else 7.2
        pitch = 0.0 if not front else 0.38
        x, y = math.cos(a) * r, math.sin(a) * r
        box(wood, (1.85, 0.72, 9.2), M((x, y, 4.6), rot=(pitch, 0, a + math.pi / 2)), bevel=0.07)
    for z in (1.8, 5.2, 8.0):
        ring_mesh(metal, 6.65, 0.28, 22, M((0, 0, z)), tube_segs=5)
    # Liquid glowing must filling the vat top and pouring violently out the split!
    cone(cap, 5.8, 5.8, 0.6, 18, M((0, 0, 7.6)))
    uvsphere(glow, 4.8, M((0, -1.0, 8.1), scale=(1.0, 0.95, 0.14)), u=12, v=5)
    for sx in (-1.3, 0.0, 1.3):
        tube(
            glow,
            [(sx, -5.6, 8.0), (sx * 1.15, -7.8, 4.6), (sx * 1.4, -9.8, 0.5)],
            [0.75, 0.65, 0.95],
            6,
        )
    uvsphere(glow, 4.4, M((0, -10.2, 0.28), scale=(1.3, 0.95, 0.12)), u=12, v=5)
    uvsphere(cap, 5.6, M((0.6, -10.8, 0.18), scale=(1.35, 1.0, 0.1)), u=12, v=5)

    # Two oak cooperage barrels (one upright, one tipped) on the +X side.
    barrel_prof = [(1.5, 0.0), (1.85, 1.2), (1.92, 2.2), (1.85, 3.2), (1.5, 4.4)]
    lathe(wood, barrel_prof, 12, M((8.6, 1.5, 0)))
    ring_mesh(metal, 1.88, 0.12, 12, M((8.6, 1.5, 1.1)), tube_segs=4)
    ring_mesh(metal, 1.88, 0.12, 12, M((8.6, 1.5, 3.3)), tube_segs=4)
    lathe(wood, barrel_prof, 12, M((8.2, -3.8, 1.85), rot=(0, math.pi / 2, 0.45)))

    # Wooden inspection step-ladder leaning on -X side.
    for sy in (-0.8, 0.8):
        tube(trim, [(-8.6, sy, 0), (-6.4, sy, 8.6)], [0.22, 0.2], 5)
    for k in range(5):
        f = (k + 1) / 6.0
        x = -8.6 + 2.2 * f
        z = 8.6 * f
        tube(trim, [(x, -0.85, z), (x, 0.85, z)], [0.16, 0.16], 4)


@template("GraftingBench", WOOD=1600, TRIM=600, ALT=1200, CORAL=600, STONE=500, GLOW=300)
def grafting_bench(t):
    """Grafters' Yard workbench (~15 x 7.5 x 8.5): timber trestle table with clay rootstock pots holding
    pink grafted shoots, a glowing wax-melting cauldron on a stone tripod, and a whetstone."""
    wood, trim, alt, coral, stone, glow = (
        t.bm("WOOD"), t.bm("TRIM"), t.bm("ALT"), t.bm("CORAL"), t.bm("STONE"), t.bm("GLOW")
    )
    # Trestle workbench (X -6..+4, Z 0..3.6).
    box(wood, (10.5, 4.2, 0.7), M((-1.0, 0, 3.5)), bevel=0.08)
    for x in (-4.8, 2.8):
        for y in (-1.5, 1.5):
            box(wood, (0.7, 0.7, 3.5), M((x, y, 1.75)), bevel=0.06)
        box(wood, (0.55, 3.4, 0.55), M((x, 0, 1.1)))
    # Tool rack back-board.
    for x in (-5.6, 3.6):
        box(wood, (0.55, 0.55, 4.4), M((x, 1.85, 5.6)))
    box(trim, (10.0, 0.45, 0.9), M((-1.0, 1.85, 6.8)), bevel=0.05)

    # Row of terracotta clay pots on the bench and ground holding grafted cuttings with pink shoots!
    pot_prof = [(0.6, 0.0), (0.85, 1.1), (0.95, 1.35), (0.82, 1.35)]
    for idx, (x, y, z) in enumerate((
        (-4.2, -0.4, 3.85), (-2.2, 0.5, 3.85), (-0.2, -0.5, 3.85),
        (-5.2, -2.9, 0.0), (-3.1, -3.1, 0.0), (-1.1, -2.8, 0.0),
    )):
        lathe(alt, pot_prof, 10, M((x, y, z)))
        tube(wood, [(x, y, z + 1.0), (x + 0.15, y - 0.1, z + 2.6)], [0.14, 0.08], 5)
        canopy_blob(coral, Vector((x + 0.15, y - 0.1, z + 2.85)), (1.4, 1.3, 1.0), 820 + idx * 5, subdiv=1)

    # Whetstone wheel on the right end of the bench.
    cone(stone, 1.1, 1.1, 0.6, 14, M((2.2, 0.0, 4.6), rot=(math.pi / 2, 0, 0)))
    box(trim, (1.6, 1.4, 0.7), M((2.2, 0.0, 4.1)), bevel=0.05)

    # Bubbling grafting-wax cauldron on a stone fire-ring beside the bench (+X).
    for k in range(6):
        a = k * math.pi / 3
        rock_clean(stone, (1.2, 1.1, 0.9), M((6.2 + math.cos(a) * 1.6, 0.0 + math.sin(a) * 1.6, 0)), 860 + k, subdiv=1)
    uvsphere(stone, 1.45, M((6.2, 0.0, 2.2), scale=(1.0, 1.0, 0.85)), u=12, v=8)
    uvsphere(glow, 1.15, M((6.2, 0.0, 2.95), scale=(1.0, 1.0, 0.25)), u=10, v=5)
    uvsphere(glow, 0.9, M((6.2, 0.0, 0.45), scale=(1.0, 1.0, 0.35)), u=8, v=4)


@template("FruitBasketPile", WOOD=1200, ALT=1200, CAP=1200, CORAL=1000, GLOW=800, TRIM=400)
def fruit_basket_pile(t):
    """Windfall Hollow heaped fruit pile (~13 x 11 x 6): slatted timber crate, wicker baskets, oak barrel,
    and a brimming heap of overripe red-pink apples and glowing magenta rot-fruits."""
    wood, alt, cap, coral, glow, trim = (
        t.bm("WOOD"), t.bm("ALT"), t.bm("CAP"), t.bm("CORAL"), t.bm("GLOW"), t.bm("TRIM")
    )
    rng = t.rng

    # Low slatted drying pallet base.
    for k in range(5):
        box(wood, (10.5, 1.1, 0.45), M((0, -3.2 + k * 1.6, 0.35)), bevel=0.05)
    # Brimming central mound of individual overripe windfall apples over a low pulp core.
    canopy_blob(cap, Vector((0, 0, 1.3)), (7.2, 6.0, 1.8), 900, subdiv=1)
    for k in range(42):
        a = rng.uniform(0, 2 * math.pi)
        r = rng.uniform(0.2, 4.4)
        x, y = math.cos(a) * r, math.sin(a) * r * 0.85
        z = 1.0 + max(0.0, (1.0 - r / 4.8)) * 2.4 + rng.uniform(-0.15, 0.3)
        bm_f = glow if k % 4 == 0 else (coral if k % 2 == 0 else cap)
        uvsphere(bm_f, rng.uniform(0.62, 0.92), M((x, y, z)), u=7, v=5)

    # Two wicker harvest baskets overflowing beside the heap.
    basket_prof = [(1.1, 0.0), (1.5, 1.8), (1.6, 2.0)]
    for bx, by in ((-5.2, -2.0), (5.0, -2.4)):
        lathe(alt, basket_prof, 12, M((bx, by, 0)))
        ring_mesh(trim, 1.55, 0.16, 12, M((bx, by, 1.95)), tube_segs=4)
        for j in range(5):
            a = j * 1.25
            uvsphere(glow if j == 0 else coral, 0.55, M((bx + math.cos(a) * 0.65, by + math.sin(a) * 0.65, 2.15)), u=6, v=5)

    # Oak cider barrel behind the pile.
    barrel_prof = [(1.35, 0.0), (1.65, 1.1), (1.72, 2.0), (1.65, 2.9), (1.35, 4.0)]
    lathe(wood, barrel_prof, 12, M((-4.2, 3.2, 0)))
    # Glowing must seeping off the front of the pallet.
    uvsphere(glow, 2.8, M((1.4, -4.6, 0.18), scale=(1.2, 0.75, 0.1)), u=10, v=4)


@template("CrutchPoleProp", WOOD=1200, TRIM=700, ALT=500, CORAL=400, GLOW=250)
def crutch_pole_prop(t):
    """Orchard work vignette (~8 x 6 x 11): wooden orchard ladder, forked bough crutch pole,
    and a wicker fruit basket brimming with glowing rot-apples."""
    wood, trim, alt, coral, glow = t.bm("WOOD"), t.bm("TRIM"), t.bm("ALT"), t.bm("CORAL"), t.bm("GLOW")

    # Leaning wooden orchard ladder (height ~10.5).
    for sx in (-1.0, 1.0):
        tube(wood, [(sx, -1.8, 0), (sx * 0.85, 1.6, 10.6)], [0.24, 0.2], 5)
    for k in range(6):
        f = (k + 1) / 7.0
        y = -1.8 + 3.4 * f
        z = 10.6 * f
        w_half = 1.0 - 0.15 * f
        tube(trim, [(-w_half, y, z), (w_half, y, z)], [0.16, 0.16], 4)

    # Forked crutch pole leaning crosswise beside the ladder.
    tube(trim, [(2.8, -1.0, 0), (1.2, 1.2, 8.2)], [0.28, 0.22], 5)
    for sy in (-1, 1):
        tube(trim, [(1.4, 0.9, 7.2), (1.1 + sy * 0.7, 1.3, 8.9)], [0.18, 0.12], 4)

    # Wicker harvest basket at the ladder's foot.
    lathe(alt, [(1.0, 0.0), (1.35, 1.6), (1.45, 1.8)], 12, M((-2.2, -1.2, 0)))
    for k in range(4):
        a = k * math.pi / 2
        uvsphere(glow if k == 0 else coral, 0.5, M((-2.2 + math.cos(a) * 0.5, -1.2 + math.sin(a) * 0.5, 1.95)), u=6, v=4)


@template("ThornBrambleArch", WOOD=2800, CAP=1000, GLOW=450, MOSS=500, SILK=250)
def thorn_bramble_arch(t):
    """Thorn Saddle briar arch (~36 x 12 x 23): dense tangled arch of thorny dark rose-briars choked with
    rot-blooms and a warden-cut gap through the middle (inner span ~24, clear height ~16)."""
    wood, cap, glow, moss, silk = t.bm("WOOD"), t.bm("CAP"), t.bm("GLOW"), t.bm("MOSS"), t.bm("SILK")
    rng = t.rng

    half = 15.0
    # 5 interlocking twisted briar canes sweeping up and over the arch.
    for j in range(5):
        dy = (j - 2) * 1.4
        z_off = (j % 2) * 1.8
        pts, radii = [], []
        for k in range(15):
            u = -1.0 + 2.0 * k / 14.0
            x = u * (half + (j % 2) * 1.4) + math.sin(u * 7.0 + j) * 0.9
            y = dy + math.cos(u * 6.0 + j * 1.5) * 1.4
            z = max(-0.4, (1.0 - u * u) * (20.5 + z_off) + math.sin(u * 10.0 + j) * 0.7)
            pts.append(Vector((x, y, z)))
            radii.append(1.15 - 0.35 * abs(u) + (j == 2) * 0.25)
        tube(wood, pts, radii, 6)
        # Sharp thorns jutting outward along the arch.
        for k in range(2, 13, 2):
            p = pts[k]
            out = Vector((p.x * 0.12, rng.uniform(-1.5, 1.5), 1.8))
            tube(wood, [p, p + out], [0.42, 0.06], 4)

    # Tangle of lower briar roots & dark moss mounds at both feet.
    for s in (-1, 1):
        rock_clean(moss, (6.5, 5.8, 2.0), M((s * half, 0, 0)), 940 + s, subdiv=1)
        band(silk, (s * half, -0.5, 5.0), 1.4, 1.1, segs=8)
    # Dark crimson-plum briar leaves & glowing rot-roses woven across the crown.
    for k in range(7):
        u = -0.78 + k * (1.56 / 6.0)
        x = u * half
        z = 16.0 + 6.0 * (1.0 - u * u)
        canopy_blob(cap, Vector((x, (k % 2 - 0.5) * 2.4, z)), (7.6, 6.2, 4.8), 960 + k, subdiv=2)
        if k % 2 == 1:
            uvsphere(glow, 0.75, M((x, -1.6, z - 1.2)), u=7, v=5)


@template("HollinBench", WOOD=1200, TRIM=500, MOSS=350, SILK=200)
def hollin_bench(t):
    """Crookback Ridge Hollin wooden bench (~10 x 4.5 x 5.2): curved weathered timber seat and backrest
    with carved graft-knot armrests and mossy feet, looking out over the orchard."""
    wood, trim, moss, silk = t.bm("WOOD"), t.bm("TRIM"), t.bm("MOSS"), t.bm("SILK")

    # Seat planks & sturdy timber legs.
    box(wood, (9.4, 2.8, 0.55), M((0, 0, 2.2)), bevel=0.08)
    for sx in (-1, 1):
        box(wood, (0.8, 2.8, 2.2), M((sx * 3.8, 0, 1.1)), bevel=0.06)
        # Armrest with carved graft-knot ring!
        box(wood, (0.7, 3.0, 0.5), M((sx * 4.2, 0.1, 3.6)), bevel=0.06)
        box(wood, (0.6, 0.6, 1.5), M((sx * 4.2, -1.1, 2.9)), bevel=0.05)
        ring_mesh(trim, 0.72, 0.16, 12, M((sx * 4.2, -1.1, 3.6), rot=(0, math.pi / 2, 0)), tube_segs=4)
        rock_clean(moss, (2.2, 3.2, 0.6), M((sx * 3.8, 0, 0)), 990 + sx, subdiv=1)

    # Slatted backrest tilted gently back (+Y).
    for x in (-3.8, 0.0, 3.8):
        box(wood, (0.65, 0.55, 3.1), M((x, 1.35, 3.6), rot=(0.18, 0, 0)), bevel=0.05)
    for z in (3.4, 4.5):
        box(trim, (9.2, 0.38, 0.72), M((0, 1.4 + (z - 3.4) * 0.2, z), rot=(0.18, 0, 0)), bevel=0.05)
    # A faded linen band tied to one backrest post.
    band(silk, (3.8, 1.45, 4.1), 0.5, 0.6, segs=8)


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("CorruptedF32Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F32_TEMPLATES.items():
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
        filepath=os.path.join(OUT_DIR, "CorruptedF32Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "CorruptedF32Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F32_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
