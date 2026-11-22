"""
Corrupted Grove Floor 33 (Briar Labyrinth) sculpted assets, generated in headless Blender.

Inspired by reference/Corrupted Grove 33.jpg and docs/prompts/corrupted-grove-floor-layouts-prompt.md:
a hedge-walled labyrinth suspended over a sunken thorn pit around the central Thornheart Court, with
the Mother Graft's silhouette appearing on the far north horizon for the first time.

Templates (16):
  ThornheartKnot        house-sized briar knot & split blackened stump with blazing magenta cavity (~132 tall; 1.25x -> 165)
  BriarGatehouse        living hawthorn gatehouse arch whose woven briar doors have grown shut toward the Court
  HedgeWallStraight     clipped hawthorn maze wall (18 long, <= 7.8 tall) laced with glowing briar vines
  HedgeWallCorner       L-shaped maze hedge corner with mossy fieldstone pier and trailing thorns
  HedgeWallBroken       breached hedge wall ripped open by erupting black briars and rot-blooms
  WattleCroft           the Mender's timber-framed wattle-and-daub cottage with thatched roof and stone chimney
  ScarecrowProp         the Mender's stitched-bark straw scarecrow on a cross-post with tattered sleeves
  HangingPlanterPergola rustic vine-draped timber pergola hung with 5 blooming flower baskets
  FieldstoneWellhead    mossy circular fieldstone cloister wellhead with timber roof gable (Briar Cloister)
  GibbetCage            gnarled dead-tree gallows branch with two empty wicker-and-iron gibbet cages on chains
  RotRoseBush           ruined mossy stone garden arch draped with giant shield-sized magenta rot-roses
  TopiaryStag           mossy stone plinth supporting an overgrown clipped-hedge stag with twig antlers
  TopiaryGraftKnot      mossy stone plinth crowned with a clipped-hedge triple-ring Hollin graft-knot
  ThreeArmSignpost      weathered trail signpost with two carved arms, one hacked off, and a fluttering Pale Band
  ThornKnotCluster      tangled spiked ground briar knot with glowing magenta heart-thorns (thorn pit floor)
  WardenSkeleton        woven circular briar nest holding a fallen warden's sombre skeleton and torn Pale Band

Reuses `tools/blender/generate_tower_biome_kit.py` helpers and existing colour roles only:
WOOD, TRIM, ALT, FOLIAGE, MOSS, SILK, STONE, GLOW, CANDLE, CAP, CORAL, ACCENT, METAL, STEM.

Run:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_corrupted_f33_kit.py

Outputs (assets-source/tower/corrupted_f33_kit/):
    CorruptedF33Kit.blend    the generated scene
    CorruptedF33Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json            per template: roles, reference size, triangle counts
    previews/                contact-sheet renders
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "corrupted_f33_kit")

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
    cone(bm, radius, radius * 0.98, height, segs, M(centre, rot=tilt))


def trailing_tail(bm, start, length, sway, seed):
    pts = [Vector(start)]
    for k in range(1, 5):
        f = k / 4
        pts.append(Vector(start) + Vector((math.sin(seed + f * 2.5) * sway * f, -0.35 * f, -length * f)))
    tube(bm, pts, [0.28, 0.25, 0.2, 0.14, 0.07], 4)


def giant_rose(bm_cap, bm_glow, center, radius=2.6, tilt=(0, 0, 0)):
    """A sculpted multi-petal shield-sized rot-rose with a glowing magenta heart."""
    mat = M(center, rot=tilt)
    # Outer ring of 7 broad cupped petals.
    for k in range(7):
        a = k * 2 * math.pi / 7
        p_mat = mat @ M((math.cos(a) * radius * 0.58, math.sin(a) * radius * 0.58, radius * 0.12), rot=(0.42, 0, a + math.pi / 2))
        box(bm_cap, (radius * 0.85, radius * 0.65, radius * 0.22), p_mat, bevel=radius * 0.08)
    # Inner tighter ring of 5 petals.
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.35
        p_mat = mat @ M((math.cos(a) * radius * 0.32, math.sin(a) * radius * 0.32, radius * 0.32), rot=(0.72, 0, a + math.pi / 2))
        box(bm_cap, (radius * 0.55, radius * 0.45, radius * 0.18), p_mat, bevel=radius * 0.06)
    uvsphere(bm_glow, radius * 0.26, mat @ M((0, 0, radius * 0.36)), u=7, v=5)


DEFAULT_BUDGET = 3500
F33_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F33_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("ThornheartKnot", WOOD=5200, GLOW=1400, CAP=1200, MOSS=700, STONE=700)
def thornheart_knot(t):
    """The Thornheart (~68 x 54 x 132; placed at 1.25x -> 165 studs): a colossal house-sized knot of
    intertwined black briar coiled around a split blackened cutting of the Mother Graft, with a blazing
    magenta heartrot cavity facing -Y and giant barbed thorn-spears thrusting upward and outward."""
    wood, glow, cap, moss, stone = t.bm("WOOD"), t.bm("GLOW"), t.bm("CAP"), t.bm("MOSS"), t.bm("STONE")
    rng = t.rng

    # Central split blackened elder stump rising from Z 0..108, parted wide at Z 26..64 to reveal the heartrot cavity!
    for s in (-1, 1):
        pts, radii = [], []
        for k in range(11):
            f = k / 10.0
            part = s * (5.5 + 4.5 * math.sin(f * math.pi) + 6.0 * (f ** 1.8))
            pts.append(Vector((part + math.sin(f * 6.0 + s) * 1.4, 4.0 + 3.5 * f, f * 106.0)))
            radii.append(10.0 - 6.2 * f)
        tube(wood, pts, radii, 10)

    # Massive blazing heartrot cavity crystal/core nested inside the split (facing -Y, Z 28..64).
    uvsphere(glow, 8.8, M((0, -2.5, 44.0), scale=(0.92, 0.58, 1.85)), u=12, v=9)
    for k in range(6):
        a = -math.pi / 2 + (k - 2.5) * 0.45
        tube(
            glow,
            [
                (math.cos(a) * 6.0, math.sin(a) * 5.0 - 1.5, 36.0 + (k % 2) * 8.0),
                (math.cos(a) * 14.0, math.sin(a) * 11.0 - 3.5, 44.0 + (k - 2.5) * 4.5),
                (math.cos(a) * 20.0, math.sin(a) * 14.0 - 4.0, 26.0 + k * 3.0),
            ],
            [1.1, 0.75, 0.35],
            5,
        )

    # 12 massive coiled briar hoops & sweeping thorn-spears wrapping the stump and reaching up to Z = 132!
    for idx in range(12):
        ang = idx * 2 * math.pi / 12
        ca, sa = math.cos(ang), math.sin(ang)
        pts, radii = [], []
        reach_r = 24.0 + (idx % 3) * 5.0
        peak_z = 88.0 + (idx % 4) * 14.5
        for step in range(9):
            u = step / 8.0
            twist = ang + u * 1.15 * (1 if idx % 2 == 0 else -1)
            r = 12.0 + reach_r * math.sin(u * math.pi * 0.78) * (1.0 - 0.15 * u)
            z = 6.0 + peak_z * (u ** 1.05)
            # Keep front (-Y) cavity visible by parting lower coils around the cavity!
            y_val = math.sin(twist) * r
            if y_val < -6.0 and z < 60.0:
                y_val = -6.0 - (60.0 - z) * 0.08
            pts.append(Vector((math.cos(twist) * r, y_val, z)))
            radii.append(3.2 * (1.0 - 0.85 * u) + 0.3)
        tube(wood, pts, radii, 6)
        # Sharp barbed thorns jutting off each briar coil.
        for step in (2, 4, 6):
            p = pts[step]
            out = Vector((p.x, p.y, 8.0)).normalized() * 7.5
            tube(wood, [p, p + out], [1.1, 0.12], 4)

    # Heavy buttress roots & mossy fieldstone mound anchoring the base.
    for k in range(8):
        a = k * 2 * math.pi / 8 + 0.2
        reach = rng.uniform(22.0, 30.0)
        tube(
            wood,
            [(math.cos(a) * 8, math.sin(a) * 8, 18), (math.cos(a) * reach * 0.55, math.sin(a) * reach * 0.55, 7.0), (math.cos(a) * reach, math.sin(a) * reach, 0.2)],
            [3.8, 2.5, 0.9],
            6,
        )
        rock_clean(stone, (6.5, 5.5, 4.2), M((math.cos(a + 0.3) * reach * 0.72, math.sin(a + 0.3) * reach * 0.72, 0)), 100 + k, subdiv=1)

    # Dark rot-rose & purple-briar leaf clusters nestled around the waist of the knot.
    for k in range(8):
        a = k * 2 * math.pi / 8 + 0.4
        r = 16.0 + (k % 2) * 5.0
        z = 22.0 + (k % 3) * 14.0
        canopy_blob(cap, Vector((math.cos(a) * r, math.sin(a) * r, z)), (9.5, 8.0, 6.2), 130 + k, subdiv=2)
        rock_clean(moss, (6.5, 5.5, 1.8), M((math.cos(a) * 14, math.sin(a) * 14, 4.0 + (k % 2) * 6.0)), 150 + k, subdiv=1)


@template("BriarGatehouse", WOOD=2800, FOLIAGE=1400, CORAL=1200, GLOW=700, STONE=700, SILK=300)
def briar_gatehouse(t):
    """The Briar Gate (~34 x 12 x 25): a living pleached hawthorn gatehouse arch whose woven timber-and-briar
    doors have grown completely shut with glowing magenta thorns, clearly sealing the crossing toward the Court."""
    wood, leaf, coral, glow, stone, silk = (
        t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("CORAL"), t.bm("GLOW"), t.bm("STONE"), t.bm("SILK")
    )
    half = 14.0
    for s in (-1, 1):
        box(stone, (5.0, 6.0, 4.2), M((s * half, 0, 2.1)), bevel=0.5)
        for j, dy in enumerate((-1.5, 1.5)):
            pts = [
                Vector((s * half, dy, 1.0)),
                Vector((s * (half + 0.6 * (1 if j == 0 else -1)), dy * 0.6, 8.5)),
                Vector((s * (half - 0.8), -dy * 0.3, 15.5)),
            ]
            tube(wood, pts, [1.45, 1.2, 1.0], 7)
        band(silk, (s * half, 0, 6.5), 2.1, 1.3)

    # Thick braided hawthorn arch overhead (crown at Z 23).
    for j, (dy, r) in enumerate(((-1.6, 1.0), (0.0, 1.25), (1.6, 1.0))):
        pts = []
        for k in range(15):
            u = -1.0 + 2.0 * k / 14.0
            pts.append(Vector((u * half, dy + math.sin(u * 8 + j) * 0.7, 14.8 + 8.6 * (1 - u * u))))
        tube(wood, pts, [r] * len(pts), 6)

    # SEALED SHUT DOUBLE DOORS: heavy timber leaves completely choked by criss-crossing black briars & magenta glow!
    for s in (-1, 1):
        box(wood, (half - 1.6, 1.2, 15.8), M((s * (half * 0.5 - 0.2), 0, 7.9)), bevel=0.12)
        # Diagonal woven briar bars growing across the shut doors.
        for k in range(5):
            z0 = 2.0 + k * 3.0
            tube(wood, [(s * 0.4, -0.9, z0), (s * (half - 1.4), -1.1, z0 + 2.6)], [0.45, 0.35], 5)
            tube(glow, [(s * 0.4, -1.0, z0 + 1.4), (s * (half - 2.0), -1.2, z0 + 0.4)], [0.24, 0.16], 4)
    # Central glowing magenta seam pulsing between the sealed door leaves.
    tube(glow, [(0, -1.1, 1.5), (0, -1.2, 9.0), (0, -1.1, 17.5)], [0.55, 0.85, 0.45], 6)

    # Lush flowering hawthorn crown & pink blossoms spilling over the gatehouse top.
    for k in range(9):
        u = -0.9 + k * (1.8 / 8.0)
        x = u * half
        z = 16.5 + 7.5 * (1 - u * u)
        canopy_blob(leaf if k % 2 == 0 else coral, Vector((x, (k % 2 - 0.5) * 2.5, z + 1.2)), (8.2, 7.2, 5.2), 200 + k * 7, subdiv=2)


@template("HedgeWallStraight", FOLIAGE=1400, WOOD=1100, GLOW=300, CAP=450, MOSS=300)
def hedge_wall_straight(t):
    """Clipped hawthorn maze wall (~18 long x 4.6 deep x 7.6 tall — strictly <= 9 studs so the gameplay camera
    reads the labyrinth from above), wrapped in thorny briar canes and glowing magenta blossoms."""
    leaf, wood, glow, cap, moss = t.bm("FOLIAGE"), t.bm("WOOD"), t.bm("GLOW"), t.bm("CAP"), t.bm("MOSS")
    rng = t.rng
    # Core clipped hedge mass built from overlapping organic foliage pillows (Z 0.6..7.2).
    for k in range(5):
        x = -7.2 + k * 3.6
        canopy_blob(leaf, Vector((x, rng.uniform(-0.3, 0.3), 3.9 + (k % 2) * 0.35)), (5.6, 4.4, 6.2), 240 + k * 7, subdiv=2)
    # Braided black-briar vines crawling along both faces of the hedge.
    for sy in (-1, 1):
        pts = [Vector((-8.6 + k * 2.15, sy * (2.1 + math.sin(k * 1.4) * 0.35), 1.4 + math.sin(k * 1.1 + sy) * 1.6 + 2.2)) for k in range(9)]
        tube(wood, pts, [0.34] * len(pts), 5)
        for k in (2, 5, 7):
            uvsphere(glow, 0.36, M(pts[k] + Vector((0, sy * 0.25, 0.3))), u=6, v=4)
            canopy_blob(cap, pts[k] + Vector((0, sy * 0.2, 0.6)), (2.2, 1.4, 1.6), 270 + k + (sy + 1) * 9, subdiv=1)
    rock_clean(moss, (16.5, 4.2, 1.0), M((0, 0, 0)), 290, subdiv=1)


@template("HedgeWallCorner", FOLIAGE=1400, WOOD=1000, STONE=500, GLOW=250, CAP=400)
def hedge_wall_corner(t):
    """L-shaped maze hedge corner (~12 x 12 x 7.8) anchored by a mossy fieldstone corner pier."""
    leaf, wood, stone, glow, cap = t.bm("FOLIAGE"), t.bm("WOOD"), t.bm("STONE"), t.bm("GLOW"), t.bm("CAP")
    box(stone, (3.8, 3.8, 7.2), M((0, 0, 3.6)), bevel=0.35)
    for k in range(3):
        canopy_blob(leaf, Vector((2.6 + k * 3.0, 0, 3.8)), (5.0, 4.2, 6.0), 310 + k, subdiv=2)
        canopy_blob(leaf, Vector((0, -2.6 - k * 3.0, 3.8)), (4.2, 5.0, 6.0), 320 + k, subdiv=2)
    tube(wood, [(10.5, -2.1, 2.5), (4.5, -2.2, 5.4), (0, -2.2, 6.6), (-2.1, -5.0, 4.5), (-2.1, -10.5, 2.2)], [0.38, 0.42, 0.48, 0.42, 0.34], 5)
    for p in (Vector((5.0, -2.2, 5.4)), Vector((-2.1, -5.5, 4.6)), Vector((0.0, -2.2, 6.8))):
        uvsphere(glow, 0.38, M(p), u=6, v=4)
        canopy_blob(cap, p + Vector((0, 0, 0.5)), (2.4, 2.0, 1.8), 335 + int(p.x), subdiv=1)


@template("HedgeWallBroken", FOLIAGE=1100, WOOD=1500, GLOW=400, CAP=500)
def hedge_wall_broken(t):
    """Breached maze hedge (~18 x 5.5 x 7.8) where dark thorns have burst through the middle gap."""
    leaf, wood, glow, cap = t.bm("FOLIAGE"), t.bm("WOOD"), t.bm("GLOW"), t.bm("CAP")
    for x in (-6.8, -4.0, 4.2, 7.0):
        canopy_blob(leaf, Vector((x, 0, 3.7)), (4.8, 4.2, 5.8), 350 + int(x * 3), subdiv=2)
    # Erupting black briar tangle tearing through the center gap (-3..+3).
    for k in range(5):
        a = -0.9 + k * 0.45
        pts = [
            Vector((math.sin(a) * 1.5, 0, 0)),
            Vector((math.sin(a) * 3.4, (k % 2 - 0.5) * 2.2, 3.6)),
            Vector((math.sin(a) * 5.2, (k % 2 - 0.5) * 3.4, 6.8 + (k % 2) * 1.0)),
        ]
        tube(wood, pts, [0.55, 0.38, 0.12], 5)
        uvsphere(glow, 0.36, M(pts[1]), u=6, v=4)
    canopy_blob(cap, Vector((0, -0.8, 2.8)), (4.5, 3.2, 2.6), 370, subdiv=2)


@template("WattleCroft", STONE=1200, WOOD=2000, TRIM=1000, ALT=1600, GLOW=250, MOSS=500)
def wattle_croft(t):
    """The Mender's Croft (~20 x 15 x 17): cozy Hollin wattle-and-daub cottage with thick thatched roof,
    fieldstone fireplace chimney on -X, timber framing, warm glowing mullioned window and mossy plinth."""
    stone, wood, trim, alt, glow, moss = (
        t.bm("STONE"), t.bm("WOOD"), t.bm("TRIM"), t.bm("ALT"), t.bm("GLOW"), t.bm("MOSS")
    )
    rng = t.rng
    # Fieldstone footing.
    box(stone, (17.5, 12.2, 2.4), M((0, 0, 1.2)), bevel=0.35)
    # Daub walls + dark timber framing.
    box(trim, (16.0, 10.8, 7.4), M((0, 0, 6.0)), bevel=0.1)
    for x in (-7.9, -2.6, 2.6, 7.9):
        for y in (-5.35, 5.35):
            box(wood, (0.85, 0.85, 7.8), M((x, y, 6.1)), bevel=0.06)
    for y in (-5.35, 5.35):
        box(wood, (16.8, 0.85, 0.8), M((0, y, 9.6)), bevel=0.06)
        box(wood, (16.8, 0.85, 0.8), M((0, y, 2.5)), bevel=0.06)
    # Front (-Y) arched wooden door & warm glowing window.
    box(wood, (3.2, 0.55, 5.4), M((-3.8, -5.6, 5.0)), bevel=0.08)
    box(glow, (2.6, 0.3, 2.2), M((3.8, -5.55, 6.4)))
    box(wood, (3.1, 0.45, 0.35), M((3.8, -5.65, 7.6)))
    box(wood, (3.1, 0.45, 0.35), M((3.8, -5.65, 5.2)))
    # Thick golden thatched gable roof with overhanging eaves.
    for s in (-1, 1):
        box(alt, (20.4, 8.8, 1.6), M((0, s * 3.6, 12.6), rot=(s * -0.74, 0, 0)), bevel=0.55)
    tube(alt, [(-10.5, 0, 15.8), (0, 0, 16.1), (10.5, 0, 15.8)], [1.15, 1.25, 1.15], 8)
    # Fieldstone chimney rising up the -X gable wall.
    box(stone, (3.4, 3.8, 16.8), M((-9.2, 0.4, 8.4)), bevel=0.3)
    box(stone, (4.0, 4.4, 1.2), M((-9.2, 0.4, 16.6)), bevel=0.15)
    for k in range(4):
        rock_clean(moss, (3.2, 2.6, 0.9), M((-5 + k * 3.6, (k % 2 - 0.5) * 6.0, 13.0)), 400 + k, subdiv=1)


@template("ScarecrowProp", WOOD=700, ALT=900, TRIM=500, SILK=350, GLOW=150)
def scarecrow_prop(t):
    """The Mender's stitched-bark scarecrow (~7.5 x 3.6 x 10.5): weathered cross-post dressed in a tattered
    linen coat, straw-stuffed arms, wide crooked hat, and a glowing sap-lantern hanging from one arm."""
    wood, alt, trim, silk, glow = t.bm("WOOD"), t.bm("ALT"), t.bm("TRIM"), t.bm("SILK"), t.bm("GLOW")
    # Center stake & crooked cross-arm.
    tube(wood, [(0, 0, -0.4), (0.2, 0, 8.6)], [0.35, 0.25], 6)
    tube(wood, [(-3.6, 0, 6.8), (0.1, 0, 7.2), (3.7, 0, 6.5)], [0.22, 0.28, 0.2], 6)
    # Stitched-bark torso & tattered coat.
    cone(silk, 1.6, 1.0, 4.4, 10, M((0.1, 0, 3.0)))
    box(trim, (1.8, 1.2, 2.6), M((0.1, 0, 6.2)), bevel=0.2)
    # Straw tufts bursting from cuffs and collar.
    for sx in (-3.5, 3.6):
        cone(alt, 0.65, 0.2, 1.2, 7, M((sx, 0, 6.6), rot=(0, sx * 0.45, 0)))
    # Stitched burlap head & crooked straw witch-hat.
    uvsphere(alt, 0.95, M((0.15, 0, 8.5), scale=(0.95, 0.95, 1.15)), u=9, v=7)
    cone(wood, 2.2, 0.18, 2.2, 10, M((0.15, 0.05, 9.2), rot=(0.12, -0.15, 0)))
    # Hanging sap-lantern from +X arm.
    tube(trim, [(3.2, 0, 6.5), (3.2, 0, 5.1)], [0.06, 0.06], 4)
    uvsphere(glow, 0.55, M((3.2, 0, 4.6), scale=(0.9, 0.9, 1.2)), u=7, v=5)


@template("HangingPlanterPergola", WOOD=1800, FOLIAGE=1200, CORAL=1200, ALT=700, GLOW=300)
def hanging_planter_pergola(t):
    """Hanging Garden pergola (~24 x 8.5 x 13.5): rustic timber arbor draped with flowering vines and
    5 hanging woven flower baskets overflowing with rose-violet blossoms."""
    wood, leaf, coral, alt, glow = t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("CORAL"), t.bm("ALT"), t.bm("GLOW")
    # 6 stout timber posts + longitudinal top beams + 7 cross-rafters.
    for x in (-10.5, 0.0, 10.5):
        for y in (-3.2, 3.2):
            tube(wood, [(x, y, -0.4), (x, y, 11.2)], [0.5, 0.42], 6)
    for y in (-3.2, 3.2):
        box(wood, (23.6, 0.75, 0.85), M((0, y, 11.2)), bevel=0.08)
    for k in range(7):
        x = -11.0 + k * 3.66
        box(wood, (0.55, 8.2, 0.65), M((x, 0, 11.9)), bevel=0.06)
    # Flowering vine garlands along the roof rafters.
    for k in range(6):
        x = -9.5 + k * 3.8
        canopy_blob(leaf if k % 2 == 0 else coral, Vector((x, (k % 2 - 0.5) * 2.2, 12.6)), (5.6, 4.6, 2.4), 450 + k * 7, subdiv=2)
    # 5 hanging woven planter baskets suspended on cords at Z ~8.2 (well above head height!).
    basket_prof = [(0.55, 0.0), (1.15, 0.9), (1.25, 1.2)]
    for k in range(5):
        x = -8.4 + k * 4.2
        y = (k % 2 - 0.5) * 1.4
        tube(wood, [(x, y, 11.6), (x, y, 8.9)], [0.07, 0.07], 4)
        lathe(alt, basket_prof, 10, M((x, y, 7.8)))
        canopy_blob(coral if k % 2 == 0 else leaf, Vector((x, y, 9.2)), (2.8, 2.6, 1.6), 490 + k * 5, subdiv=1)
        if k % 2 == 1:
            uvsphere(glow, 0.35, M((x, y - 0.5, 9.5)), u=6, v=4)


@template("FieldstoneWellhead", STONE=1600, WOOD=1200, ALT=800, MOSS=500, FOLIAGE=500)
def fieldstone_wellhead(t):
    """Briar Cloister dry wellhead (~9.5 x 9.5 x 11.5): circular mossy fieldstone well with twin timber
    roof posts, wooden windlass roller, shingled cap and creeping vines."""
    stone, wood, alt, moss, leaf = t.bm("STONE"), t.bm("WOOD"), t.bm("ALT"), t.bm("MOSS"), t.bm("FOLIAGE")
    # Circular ring of fieldstone blocks (radius 3.4, Z 0..3.6).
    for k in range(12):
        a = k * 2 * math.pi / 12
        rock_clean(stone, (2.2, 1.8, 3.6), M((math.cos(a) * 3.2, math.sin(a) * 3.2, 0)), 520 + k, roughness=0.14, subdiv=1)
    ring_mesh(stone, 3.4, 0.65, 16, M((0, 0, 3.7)), tube_segs=5)
    # Twin posts + windlass + pitched shingle hood.
    for s in (-1, 1):
        tube(wood, [(s * 3.2, 0, 3.4), (s * 3.2, 0, 9.2)], [0.42, 0.36], 6)
        box(alt, (7.6, 4.4, 0.7), M((0, s * 1.6, 10.2), rot=(s * -0.62, 0, 0)), bevel=0.15)
    tube(wood, [(-3.4, 0, 6.6), (3.4, 0, 6.6)], [0.45, 0.45], 8)
    rock_clean(moss, (5.0, 4.6, 1.0), M((0, 0, 0)), 545, subdiv=1)
    canopy_blob(leaf, Vector((2.6, -1.8, 9.6)), (3.4, 3.0, 2.2), 550, subdiv=2)


@template("GibbetCage", WOOD=2200, METAL=1000, ALT=500, SILK=250)
def gibbet_cage(t):
    """Gibbet Thicket dead tree (~16 x 12 x 28): tall blackened dead elder limb with two empty woven
    iron-and-wicker gibbet cages dangling on chains, Pale Band tied on the trunk."""
    wood, metal, alt, silk = t.bm("WOOD"), t.bm("METAL"), t.bm("ALT"), t.bm("SILK")
    # Tall gnarled dead trunk curving up to two gallows boughs at Z 22..25.
    trunk = [Vector((0, 0, -0.6)), Vector((-0.6, 0.4, 7.0)), Vector((0.8, -0.3, 15.0)), Vector((0.0, 0.0, 22.0))]
    tube(wood, trunk, [2.1, 1.65, 1.35, 1.0], 8)
    for k in range(4):
        a = k * math.pi / 2 + 0.3
        tube(wood, [(math.cos(a) * 1.4, math.sin(a) * 1.4, 2.2), (math.cos(a) * 4.8, math.sin(a) * 4.8, -0.4)], [0.95, 0.28], 5)
    band(silk, trunk[1], 1.85, 1.2)
    trailing_tail(silk, (1.4, -0.4, 7.2), 3.0, 0.5, 1.7)

    # Two sweeping dead boughs holding empty dangling cages.
    for s, bx, bz, drop in ((-1, -7.2, 23.5, 6.2), (1, 6.6, 21.8, 5.5)):
        tube(wood, [trunk[-1], Vector((bx * 0.55, 0.4 * s, bz + 1.2)), Vector((bx, 0, bz))], [0.95, 0.65, 0.38], 6)
        tube(wood, [Vector((bx * 0.6, 0.4 * s, bz + 1.2)), Vector((bx * 0.85, 1.5 * s, bz + 4.8))], [0.45, 0.14], 5)
        # Chain descending to cage top.
        top_z = bz - drop
        tube(metal, [(bx, 0, bz - 0.2), (bx, 0, top_z)], [0.1, 0.1], 4)
        # Empty woven iron/wicker cage (height 4.6, radius 1.4).
        for rz, rr in ((0.0, 1.1), (-1.4, 1.45), (-3.0, 1.4), (-4.4, 1.0)):
            ring_mesh(metal if rz in (0.0, -4.4) else alt, rr, 0.14, 12, M((bx, 0, top_z + rz)), tube_segs=4)
        for j in range(6):
            a = j * math.pi / 3
            tube(
                metal,
                [
                    (bx + math.cos(a) * 1.1, math.sin(a) * 1.1, top_z),
                    (bx + math.cos(a) * 1.45, math.sin(a) * 1.45, top_z - 2.2),
                    (bx + math.cos(a) * 1.0, math.sin(a) * 1.0, top_z - 4.4),
                ],
                [0.11, 0.11, 0.11],
                4,
            )


@template("RotRoseBush", STONE=1200, MOSS=450, WOOD=900, CAP=1800, GLOW=450, FOLIAGE=600)
def rot_rose_bush(t):
    """East Rosary (~12 x 9 x 11.5): ruined mossy stone garden arch draped with three giant shield-sized
    sculpted magenta rot-roses, thorny stems and dark leaves."""
    stone, moss, wood, cap, glow, leaf = (
        t.bm("STONE"), t.bm("MOSS"), t.bm("WOOD"), t.bm("CAP"), t.bm("GLOW"), t.bm("FOLIAGE")
    )
    # Small ruined stone garden arch (span 8.5, height 10.5).
    for s in (-1, 1):
        box(stone, (2.2, 2.4, 7.6), M((s * 4.4, 0, 3.8)), bevel=0.22)
    pts = [Vector((-4.4 + k * 1.1, 0, 7.4 + 3.2 * (1 - ((-1 + k / 4.0) ** 2)))) for k in range(9)]
    tube(stone, pts, [1.1] * len(pts), 6)
    rock_clean(moss, (4.0, 3.2, 1.0), M((-4.2, 0, 7.8)), 600, subdiv=1)
    # Thorny rose bush foliage & climbing canes.
    for x, y, z, sz in ((-3.5, -1.2, 3.6, (5.5, 4.5, 3.8)), (3.2, -1.0, 3.8, (5.8, 4.8, 4.0)), (0.0, 0.6, 10.6, (6.0, 4.2, 3.4))):
        canopy_blob(leaf, Vector((x, y, z)), sz, 610 + int(x * 3), subdiv=2)
    tube(wood, [(-3.8, -1.4, 0.4), (-4.0, -1.6, 6.0), (0, -1.4, 10.8), (3.8, -1.4, 5.5), (3.6, -1.2, 0.4)], [0.4, 0.35, 0.32, 0.35, 0.4], 5)
    # THREE giant shield-sized sculpted rot-roses!
    giant_rose(cap, glow, (-3.4, -2.5, 5.0), radius=2.3, tilt=(1.15, 0.2, -0.3))
    giant_rose(cap, glow, (0.2, -1.8, 10.8), radius=2.6, tilt=(1.05, 0, 0))
    giant_rose(cap, glow, (3.4, -2.4, 5.2), radius=2.8, tilt=(1.2, -0.25, 0.25))


@template("TopiaryStag", STONE=1000, FOLIAGE=1800, WOOD=900, MOSS=450, GLOW=250)
def topiary_stag(t):
    """Thorn pit topiary ruin (~12 x 6.5 x 14.5): mossy stone pedestal supporting an overgrown clipped-hedge
    stag statue with branching wooden antlers and creeping glowing magenta briars."""
    stone, leaf, wood, moss, glow = t.bm("STONE"), t.bm("FOLIAGE"), t.bm("WOOD"), t.bm("MOSS"), t.bm("GLOW")
    # Stepped mossy fieldstone pedestal (Z 0..3.4).
    box(stone, (9.8, 5.6, 2.2), M((0, 0, 1.1)), bevel=0.35)
    box(stone, (8.2, 4.4, 1.2), M((0, 0, 2.8)), bevel=0.2)
    rock_clean(moss, (7.6, 4.2, 0.7), M((0, 0, 3.3)), 650, subdiv=1)
    # Clipped-hedge stag standing along X (facing +X): four legs, barrel body, arched neck, proud head.
    for lx, ly in ((-2.4, -0.9), (-2.4, 0.9), (2.2, -0.9), (2.2, 0.9)):
        tube(leaf, [(lx, ly, 3.2), (lx, ly, 6.8)], [0.58, 0.68], 6)
    canopy_blob(leaf, Vector((0.0, 0, 7.6)), (7.2, 3.4, 3.4), 660, subdiv=2)
    tube(leaf, [(2.4, 0, 8.2), (3.8, 0, 10.6), (4.8, 0, 11.4)], [1.15, 0.9, 0.75], 7)
    canopy_blob(leaf, Vector((5.1, 0, 11.4)), (2.4, 1.6, 1.6), 668, subdiv=2)
    # Branching twig antlers rising to Z 14.5!
    for sy in (-1, 1):
        base = Vector((4.2, sy * 0.5, 12.0))
        mid = Vector((3.4, sy * 1.5, 13.4))
        tip = Vector((2.6, sy * 2.2, 14.6))
        tube(wood, [base, mid, tip], [0.22, 0.16, 0.08], 5)
        tube(wood, [mid, mid + Vector((1.2, sy * 0.4, 1.1))], [0.14, 0.06], 4)
    # Creeping briar vines & glow buds climbing the stag's flank.
    tube(wood, [(-3.0, -1.4, 3.2), (-0.5, -1.6, 7.6), (2.6, -1.2, 9.2)], [0.22, 0.18, 0.14], 4)
    uvsphere(glow, 0.35, M((-0.4, -1.7, 7.6)), u=6, v=4)
    uvsphere(glow, 0.32, M((2.6, -1.2, 9.2)), u=6, v=4)


@template("TopiaryGraftKnot", STONE=1000, FOLIAGE=1800, WOOD=800, MOSS=450, GLOW=300)
def topiary_graft_knot(t):
    """Thorn pit centrepiece topiary (~14 x 7 x 13): mossy stone plinth crowned by an overgrown clipped-hedge
    triple-ring Hollin graft-knot laced with black briars and glowing magenta buds."""
    stone, leaf, wood, moss, glow = t.bm("STONE"), t.bm("FOLIAGE"), t.bm("WOOD"), t.bm("MOSS"), t.bm("GLOW")
    cone(stone, 5.8, 5.2, 2.8, 12, M((0, 0, 0)))
    rock_clean(moss, (9.6, 8.8, 1.0), M((0, 0, 2.6)), 700, subdiv=1)
    # Three interlocked leafy graft-knot rings (two lower flanking rings + one upper crown ring).
    ring_mesh(leaf, 3.1, 1.05, 18, M((-2.6, 0, 6.2), rot=(math.pi / 2, 0, 0.18)), tube_segs=7)
    ring_mesh(leaf, 3.1, 1.05, 18, M((2.6, 0, 6.2), rot=(math.pi / 2, 0, -0.18)), tube_segs=7)
    ring_mesh(leaf, 3.2, 1.08, 18, M((0.0, 0.3, 9.4), rot=(math.pi / 2, 0, 0)), tube_segs=7)
    # Thorny briar vines & magenta rot-buds wrapping the knot rings.
    for cx, cz in ((-2.6, 6.2), (2.6, 6.2), (0.0, 9.4)):
        ring_mesh(wood, 3.2, 0.26, 16, M((cx, -0.4, cz), rot=(math.pi / 2, 0.15, 0.12)), tube_segs=4)
        uvsphere(glow, 0.42, M((cx, -1.1, cz + 2.8)), u=6, v=4)


@template("ThreeArmSignpost", WOOD=900, TRIM=500, SILK=300, STONE=400, MOSS=250)
def three_arm_signpost(t):
    """Nettle Turn trail signpost (~7.5 x 5 x 11.5): mossy rock-footed Hollin post with two carved wooden
    direction arms, one jagged hacked-off arm, and a fluttering Pale Band marking the true west path."""
    wood, trim, silk, stone, moss = t.bm("WOOD"), t.bm("TRIM"), t.bm("SILK"), t.bm("STONE"), t.bm("MOSS")
    rock_clean(stone, (3.8, 3.6, 1.8), M((0, 0, 0)), 730, subdiv=1)
    rock_clean(moss, (4.2, 3.8, 0.8), M((0, 0, 1.3)), 735, subdiv=1)
    box(wood, (1.1, 1.1, 10.6), M((0, 0, 5.5)), bevel=0.14)
    # Two intact pointed direction boards (+X and -Y/+X).
    box(trim, (4.8, 0.35, 1.2), M((2.1, 0, 8.6), rot=(0, 0, 0.08)), bevel=0.06)
    box(trim, (4.4, 0.35, 1.15), M((-1.6, -1.2, 7.1), rot=(0, 0, 0.65)), bevel=0.06)
    # Third arm jaggedly hacked off short!
    box(trim, (1.6, 0.35, 1.0), M((-1.0, 0.5, 9.6), rot=(0, 0.25, -0.45)), bevel=0.04)
    # Fluttering Pale Band tied beneath the intact arms.
    band(silk, (0, 0, 5.4), 0.78, 0.9, segs=8)
    trailing_tail(silk, (0.75, -0.4, 5.4), 2.8, 0.55, 1.2)


@template("ThornKnotCluster", WOOD=1800, GLOW=450, CAP=450, MOSS=300)
def thorn_knot_cluster(t):
    """Thorn pit floor briar knot (~13 x 12 x 6.5): tangled loops of barbed black briar bursting from the
    mud with glowing magenta heart-thorns."""
    wood, glow, cap, moss = t.bm("WOOD"), t.bm("GLOW"), t.bm("CAP"), t.bm("MOSS")
    rng = t.rng
    for k in range(6):
        a = k * math.pi / 3
        pts = [
            Vector((math.cos(a) * 5.8, math.sin(a) * 5.2, -0.3)),
            Vector((math.cos(a + 0.4) * 3.0, math.sin(a + 0.4) * 2.8, 4.4 + (k % 2) * 1.4)),
            Vector((-math.cos(a) * 5.4, -math.sin(a) * 4.8, -0.3)),
        ]
        tube(wood, pts, [0.55, 0.48, 0.45], 5)
        tube(wood, [pts[1], pts[1] + Vector((math.cos(a) * 1.8, math.sin(a) * 1.8, 2.0))], [0.35, 0.08], 4)
    uvsphere(glow, 1.1, M((0, 0, 1.6), scale=(1.2, 1.0, 0.7)), u=8, v=5)
    canopy_blob(cap, Vector((0, 0, 2.2)), (5.2, 4.6, 2.2), 770, subdiv=1)
    rock_clean(moss, (7.0, 6.2, 0.9), M((0, 0, 0)), 778, subdiv=1)


@template("WardenSkeleton", WOOD=2200, TRIM=900, SILK=600, GLOW=250)
def warden_skeleton(t):
    """Thornwrack dead-end landmark (~16 x 16 x 7.5): a circular woven nest of black briar holding the
    sombre remains of a fallen Hollin warden resting against the rim with a torn Pale Band in hand."""
    wood, trim, silk, glow = t.bm("WOOD"), t.bm("TRIM"), t.bm("SILK"), t.bm("GLOW")
    # Circular woven briar basket-nest (radius 7.2, Z 0..5.2).
    for rz, rr in ((1.0, 7.0), (2.4, 7.4), (3.8, 7.2), (5.0, 6.6)):
        pts = [Vector((math.cos(k * math.pi / 8) * rr, math.sin(k * math.pi / 8) * rr, rz + math.sin(k * 2.1 + rz) * 0.35)) for k in range(17)]
        tube(wood, pts, [0.48] * len(pts), 5, cap=False)
    for k in range(10):
        a = k * 2 * math.pi / 10
        tube(wood, [(math.cos(a) * 6.8, math.sin(a) * 6.8, 0), (math.cos(a + 0.15) * 7.6, math.sin(a + 0.15) * 7.6, 5.8 + (k % 2) * 1.2)], [0.42, 0.14], 4)
    # Sombre stylized warden remains resting against the +X rim (pale bone TRIM + torn linen SILK cloak/band).
    uvsphere(trim, 0.9, M((2.2, 0.4, 3.8), scale=(0.9, 1.0, 1.1)), u=8, v=6)  # skull
    tube(trim, [(2.0, 0.3, 2.9), (0.6, 0.1, 1.6), (-1.4, -0.2, 1.0)], [0.35, 0.32, 0.28], 6)  # spine
    for r in range(4):
        ring_mesh(trim, 0.85, 0.14, 10, M((1.6 - r * 0.4, 0.2, 2.6 - r * 0.35), rot=(0.6, 0.5, 0)), tube_segs=4)  # ribs
    # Outstretched arm & torn crimson-pink Pale Band draped across the briar nest.
    tube(trim, [(1.6, -0.6, 2.5), (-0.4, -1.8, 2.2), (-2.6, -2.6, 2.0)], [0.22, 0.18, 0.14], 5)
    box(silk, (4.2, 2.6, 0.45), M((0.4, 0.2, 1.15), rot=(0.15, 0.2, 0.3)), bevel=0.1)
    tube(silk, [(-2.5, -2.5, 2.1), (-4.4, -4.4, 3.8), (-6.2, -5.8, 1.6)], [0.55, 0.48, 0.3], 5)
    uvsphere(glow, 0.45, M((-5.2, 4.8, 2.6)), u=6, v=4)


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("CorruptedF33Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F33_TEMPLATES.items():
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
        filepath=os.path.join(OUT_DIR, "CorruptedF33Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "CorruptedF33Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F33_TEMPLATES.keys()), tile=520, cols=4)
    print(json.dumps(manifest, indent=2))
