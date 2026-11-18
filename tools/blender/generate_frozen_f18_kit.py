"""
Frozen Citadel Floor 18 (Shattered Iceway) sculpted assets, generated in headless Blender
inspired by media_1795016381755_4ec5e256.jpg (supply cart frozen mid-fall atop a crevasse ice pillar,
towering wind-fluted glacier serac blades, half-swallowed roadside shrine, and collapsed toll shelter ruins).

1 Blender unit = 1 stud, standing on z = 0 (with -0.8 footing), front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>".

Outputs (assets-source/tower/frozen_f18_kit/):
    FrozenF18Kit.blend    the generated scene
    FrozenF18Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the Floor 18 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "frozen_f18_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
rock = kit_mod["rock"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def tapered_limb(bm, p0, p1, r0, r1, segs=7):
    d = Vector(p1) - Vector(p0)
    length = d.length
    if length < 1e-4:
        return
    q = d.normalized().to_track_quat("Z", "Y")
    mat = Matrix.Translation(p0) @ q.to_matrix().to_4x4()
    cone(bm, r0, r1, length, segs, mat)


DEFAULT_BUDGET = 3500
F18_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F18_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("CrevasseCartPillar", CRYSTAL=1400, WOOD=900, METAL=500, MOSS=600, STONE=400)
def crevasse_cart_pillar(t):
    """Wooden Whiteguard supply cart frozen mid-fall at 38 degrees atop a fluted icicle column rising from the crevasse."""
    crystal, wood, metal, moss, stone = (
        t.bm("CRYSTAL"), t.bm("WOOD"), t.bm("METAL"), t.bm("MOSS"), t.bm("STONE")
    )

    # 1. Grounded glacier rubble & ice foot on z = 0..-0.8
    for bx, by, sx, sy, sz, sd in (
        (-2.2, 0.8, 5.4, 4.6, 3.0, 11),
        (2.4, -0.9, 4.8, 4.4, 2.8, 22),
        (0.2, 2.6, 4.6, 3.8, 2.4, 33),
    ):
        rock_clean(stone, (sx, sy, sz), Matrix.Translation((bx, by, sz * 0.35 - 0.6)), seed=sd, roughness=0.22)
    rock_clean(moss, (9.8, 9.2, 2.2), Matrix.Translation((0.0, 0.0, 0.4)), seed=41, roughness=0.20)

    # 2. Fluted glacier ice cascade column reaching z = 17.5 to grip the falling cart
    tapered_limb(crystal, (0.0, 0.4, -0.4), (0.0, -0.2, 16.5), 4.1, 2.6, segs=8)
    rib_specs = (
        (-2.4, -1.2, 1.4, 0.6, 15.6, 6),
        (2.3, -1.3, 1.3, 0.55, 14.8, 6),
        (-1.6, 2.0, 1.6, 0.7, 17.2, 6),
        (1.8, 1.9, 1.5, 0.65, 16.4, 6),
        (0.0, -2.5, 1.2, 0.35, 13.8, 6),
        (-3.1, 0.5, 1.0, 0.25, 11.4, 5),
        (3.0, 0.4, 1.0, 0.25, 12.2, 5),
    )
    for rx, ry, r0, r1, h, segs in rib_specs:
        tapered_limb(crystal, (rx, ry, -0.2), (rx * 0.72, ry * 0.72, h), r0, r1, segs=segs)

    # Hanging icicle spurs dripping below frozen spray ledge
    for ix, iy, iz, ln in (
        (-2.5, -2.2, 13.2, 4.8), (-0.8, -2.8, 12.6, 5.4), (1.1, -2.6, 13.0, 4.5), (2.5, -1.9, 12.2, 3.8),
        (-2.8, 0.2, 14.0, 4.2), (2.7, 0.5, 13.8, 4.0),
    ):
        tapered_limb(crystal, (ix, iy, iz), (ix, iy, iz - ln), 0.48, 0.04, segs=5)

    # 3. Tilted wooden supply coach/wagon pitched nose-down toward -Y (X-rotation = -38 deg)
    cart_m = Matrix.Translation((0.0, -0.6, 18.0)) @ Matrix.Rotation(math.radians(-38), 4, "X") @ Matrix.Rotation(math.radians(8), 4, "Z")

    # Undercarriage beams & front shafts
    for sx in (-1.9, 1.9):
        box(wood, (0.55, 10.6, 0.6), cart_m @ Matrix.Translation((sx, 0.0, -1.35)))
        box(wood, (0.38, 4.4, 0.38), cart_m @ Matrix.Translation((sx * 0.65, -6.8, -1.2)))
    for sy in (-3.2, 0.0, 3.2):
        box(wood, (4.8, 0.55, 0.55), cart_m @ Matrix.Translation((0.0, sy, -1.55)))

    # Planked wagon bed & upright timber body walls
    box(wood, (5.2, 8.6, 0.5), cart_m @ Matrix.Translation((0.0, 0.2, -0.8)))
    for sx in (-2.4, 2.4):
        box(wood, (0.4, 8.4, 3.4), cart_m @ Matrix.Translation((sx, 0.2, 1.1)))
        for py in (-3.6, -1.2, 1.2, 3.6):
            box(wood, (0.52, 0.48, 3.8), cart_m @ Matrix.Translation((sx, py, 1.2)))
    box(wood, (5.0, 0.4, 3.4), cart_m @ Matrix.Translation((0.0, 4.2, 1.1)))
    box(wood, (5.0, 0.4, 2.2), cart_m @ Matrix.Translation((0.0, -3.9, 0.4)))

    # Arched covered wagon canopy ribs + ridged roof panels + roof snow
    for py in (-3.4, -1.1, 1.2, 3.6):
        tapered_limb(wood, cart_m @ Vector((-2.35, py, 2.8)), cart_m @ Vector((-1.4, py, 4.45)), 0.24, 0.22, segs=5)
        tapered_limb(wood, cart_m @ Vector((-1.4, py, 4.45)), cart_m @ Vector((1.4, py, 4.45)), 0.22, 0.22, segs=5)
        tapered_limb(wood, cart_m @ Vector((1.4, py, 4.45)), cart_m @ Vector((2.35, py, 2.8)), 0.22, 0.24, segs=5)
    box(wood, (3.4, 8.0, 0.38), cart_m @ Matrix.Translation((0.0, 0.2, 4.35)))
    for sx in (-1.0, 1.0):
        box(wood, (2.2, 8.0, 0.35), cart_m @ Matrix.Translation((sx * 1.65, 0.2, 3.5)) @ Matrix.Rotation(math.radians(sx * -46), 4, "Y"))
    rock_clean(moss, (4.2, 7.6, 1.1), cart_m @ Matrix.Translation((0.0, 0.3, 4.85)), seed=52, roughness=0.18)

    # 4 spoked wheels (two large rear wheels, two slightly smaller front wheels) with iron tires
    for sy, rad in ((2.6, 2.05), (-2.4, 1.75)):
        for sx in (-2.95, 2.95):
            w_hub = cart_m @ Matrix.Translation((sx, sy, -1.55)) @ Matrix.Rotation(math.radians(90), 4, "Y")
            tapered_limb(metal, cart_m @ Vector((sx - 0.35, sy, -1.55)), cart_m @ Vector((sx + 0.35, sy, -1.55)), 0.45, 0.45, segs=7)
            for sp in range(8):
                ang = sp * (math.pi / 4.0)
                dx_w, dz_w = math.cos(ang) * rad, math.sin(ang) * rad
                p_in = cart_m @ Vector((sx, sy, -1.55))
                p_out = cart_m @ Vector((sx, sy + dx_w, -1.55 + dz_w))
                tapered_limb(wood, p_in, p_out, 0.16, 0.14, segs=5)
                ang2 = (sp + 1) * (math.pi / 4.0)
                p_next = cart_m @ Vector((sx, sy + math.cos(ang2) * rad, -1.55 + math.sin(ang2) * rad))
                tapered_limb(metal, p_out, p_next, 0.24, 0.24, segs=5)

    # Frozen spray crystal collar grabbing axle & front rail
    rock_clean(crystal, (6.2, 5.2, 3.6), Matrix.Translation((0.0, 0.2, 16.0)), seed=61, roughness=0.25)


@template("SeracCluster", CRYSTAL=1600, MOSS=600, STONE=500, GLOW=180)
def serac_cluster(t):
    """Towering asymmetrical cluster of wind-fluted glacier serac spires leaning dramatically forward over crevasse rims."""
    crystal, moss, stone, glow = t.bm("CRYSTAL"), t.bm("MOSS"), t.bm("STONE"), t.bm("GLOW")

    # Basal dark granite moraine boulders + heavy drifted snow skirt (anchored below z = 0)
    for bx, by, sx, sy, sz, sd in (
        (-3.6, 1.8, 7.2, 5.8, 3.6, 101),
        (3.4, -1.2, 6.8, 5.4, 3.4, 102),
        (0.0, 2.8, 8.0, 5.0, 4.0, 103),
    ):
        rock_clean(stone, (sx, sy, sz), Matrix.Translation((bx, by, sz * 0.34 - 0.8)), seed=sd, roughness=0.24)
    rock_clean(moss, (14.8, 12.2, 3.0), Matrix.Translation((-0.6, 0.8, 0.6)), seed=107, roughness=0.20)

    # 6 jagged canted glacier serac spike blades leaning forward-west (-X, -Y)
    blades = (
        ((-1.2, 0.8, -0.4), (-6.8, -5.0, 29.5), 3.6, 0.40, 5),
        ((2.2, 1.2, -0.4), (-2.8, -3.4, 24.5), 3.0, 0.32, 5),
        ((-3.8, -0.8, -0.3), (-8.2, -5.2, 18.8), 2.4, 0.22, 5),
        ((4.2, -1.0, -0.3), (0.8, -4.0, 15.6), 2.1, 0.20, 5),
        ((0.4, 3.0, -0.3), (-3.0, 0.0, 17.2), 2.3, 0.22, 5),
        ((-5.2, 1.2, -0.3), (-9.6, -2.6, 12.8), 1.8, 0.16, 5),
    )
    for p0, p1, r0, r1, segs in blades:
        tapered_limb(crystal, p0, p1, r0, r1, segs=segs)
        # Sharp mid-flank dorsal facet ridge
        mid = tuple((p0[i] * 0.55 + p1[i] * 0.45) for i in range(3))
        top_sub = (p1[0] + 0.8, p1[1] + 0.6, p1[2] - 4.5)
        tapered_limb(crystal, (p0[0] + 1.0, p0[1] + 0.8, 1.2), mid, r0 * 0.65, r0 * 0.42, segs=5)
        tapered_limb(crystal, mid, top_sub, r0 * 0.42, 0.18, segs=5)

    # Subtle glowing rimelight veins trapped deep inside basal cleft
    for gx, gy, gz, hr in ((-0.4, -0.6, 5.2, 1.4), (1.5, 0.4, 3.8, 1.1)):
        tapered_limb(glow, (gx, gy, 0.8), (gx - 0.8, gy - 0.6, gz + 3.0), hr * 0.5, 0.12, segs=5)


@template("GlacierShrine", STONE=900, TRIM=400, CRYSTAL=600, MOSS=350, GLOW=220)
def glacier_shrine(t):
    """Whiteguard stone roadside shrine tilted in surging glacier ice, housing a glowing ward-star crest."""
    stone, trim, crystal, moss, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("CRYSTAL"), t.bm("MOSS"), t.bm("GLOW")

    # Stepped octagonal base planted cleanly
    box(stone, (7.6, 7.6, 1.8), Matrix.Translation((0.0, 0.0, 0.3)))
    box(stone, (6.0, 6.0, 1.6), Matrix.Translation((0.0, 0.0, 1.8)))

    # Tilted shrine body (7 deg frost heave)
    shrine_m = Matrix.Translation((0.0, 0.0, 2.2)) @ Matrix.Rotation(math.radians(7), 4, "Y") @ Matrix.Rotation(math.radians(-4), 4, "X")
    for sx in (-1.85, 1.85):
        box(stone, (1.4, 2.8, 6.8), shrine_m @ Matrix.Translation((sx, 0.0, 3.4)))
    box(stone, (5.2, 2.4, 6.6), shrine_m @ Matrix.Translation((0.0, 0.65, 3.3)))
    # Carved peaked arch gable & coping trim
    for sx in (-1, 1):
        box(trim, (3.2, 3.5, 0.9), shrine_m @ Matrix.Translation((sx * 1.4, 0.0, 7.6)) @ Matrix.Rotation(math.radians(sx * 36), 4, "Y"))
    box(stone, (3.4, 2.8, 2.0), shrine_m @ Matrix.Translation((0.0, 0.2, 7.2)))
    box(trim, (5.8, 3.4, 0.8), shrine_m @ Matrix.Translation((0.0, 0.0, 6.5)))

    # Recessed ward-star crystal emblem in the front niche (-Y)
    star_center = shrine_m @ Vector((0.0, -0.75, 4.4))
    for i in range(3):
        ang = i * (math.pi / 3.0)
        box(glow, (0.35, 0.38, 2.7), Matrix.Translation(star_center) @ Matrix.Rotation(ang, 4, "Y"))
    uvsphere(glow, 0.55, Matrix.Translation(star_center), 6, 5)

    # Surging glacier wedge climbing right flank + drifted snow hood + icicle teeth
    tapered_limb(crystal, (3.6, 1.2, -0.4), (0.8, 0.2, 10.6), 2.1, 0.22, segs=6)
    tapered_limb(crystal, (2.2, -1.6, -0.3), (0.5, -0.8, 7.4), 1.4, 0.14, segs=5)
    tapered_limb(crystal, (-2.6, 0.8, -0.3), (-1.4, 0.2, 5.2), 1.2, 0.12, segs=5)
    rock_clean(moss, (5.2, 3.2, 1.3), shrine_m @ Matrix.Translation((0.0, 0.5, 7.65)), seed=145, roughness=0.18)


@template("TollShelterRuins", STONE=950, WOOD=750, METAL=320, MOSS=650, CRYSTAL=450)
def toll_shelter_ruins(t):
    """Half-collapsed timber-and-granite Whiteguard tollhouse pinned under wind-drifted snow with broken canted rafters."""
    stone, wood, metal, moss, crystal = t.bm("STONE"), t.bm("WOOD"), t.bm("METAL"), t.bm("MOSS"), t.bm("CRYSTAL")

    # Granite plinth + shattered low stone half-walls (open on -Y road face)
    box(stone, (20.4, 14.0, 2.2), Matrix.Translation((0.0, 0.0, 0.3)))
    box(stone, (19.0, 2.4, 6.2), Matrix.Translation((0.0, 5.4, 3.2)))
    box(stone, (2.4, 10.6, 5.8), Matrix.Translation((-8.3, 0.4, 3.0)))
    box(stone, (2.4, 7.6, 4.4), Matrix.Translation((8.3, 2.0, 2.3)))
    # Fallen masonry pier & iron chain bollard at front right
    box(stone, (2.8, 2.8, 3.6), Matrix.Translation((8.2, -5.2, 1.6)))
    tapered_limb(metal, (8.2, -5.2, 3.2), (8.2, -5.2, 5.0), 0.45, 0.42, segs=6)
    tapered_limb(metal, (8.2, -5.2, 4.6), (-7.8, -4.6, 2.4), 0.16, 0.16, segs=5)

    # Collapsed canted timber roof truss & shattered rafters leaning east-south
    roof_m = Matrix.Translation((-0.6, 0.4, 6.6)) @ Matrix.Rotation(math.radians(-16), 4, "Y") @ Matrix.Rotation(math.radians(10), 4, "X")
    box(wood, (18.6, 0.8, 0.8), roof_m @ Matrix.Translation((0.0, -4.8, -0.4)))
    for rx in (-7.2, -2.6, 2.2, 6.8):
        tapered_limb(wood, roof_m @ Vector((rx, -5.2, 0.0)), roof_m @ Vector((rx, 0.0, 4.6)), 0.42, 0.36, segs=5)
        tapered_limb(wood, roof_m @ Vector((rx, 5.2, 0.0)), roof_m @ Vector((rx, 0.0, 4.6)), 0.42, 0.36, segs=5)
        tapered_limb(wood, roof_m @ Vector((rx, -2.8, 2.2)), roof_m @ Vector((rx, 2.8, 2.2)), 0.32, 0.32, segs=5)
    box(wood, (16.4, 0.7, 0.7), roof_m @ Matrix.Translation((0.0, 0.0, 4.6)))
    # Broken roof plank sheets on west/north half
    box(stone, (10.5, 6.2, 0.65), roof_m @ Matrix.Translation((-3.5, 2.8, 2.4)) @ Matrix.Rotation(math.radians(-40), 4, "X"))

    # Drifted snow pile burying the north wall + hanging eaves icicles
    rock_clean(moss, (18.4, 7.0, 3.8), Matrix.Translation((-1.2, 5.0, 2.4)), seed=201, roughness=0.22)
    rock_clean(moss, (10.2, 6.0, 1.8), roof_m @ Matrix.Translation((-3.5, 2.6, 3.1)) @ Matrix.Rotation(math.radians(-40), 4, "X"), seed=205, roughness=0.20)
    for ix in (-6.0, -3.5, -0.8, 2.2, 4.8):
        p_eave = roof_m @ Vector((ix, -5.1, -0.2))
        tapered_limb(crystal, p_eave, p_eave + Vector((0.0, 0.0, -3.2 - (abs(ix) % 2.1))), 0.34, 0.04, segs=5)


@template("FrozenBareTree", WOOD=950, MOSS=350, CRYSTAL=500)
def frozen_bare_tree(t):
    """Wind-blasted leafless alpine deadwood tree with gnarled skeletal boughs, drifted snow collars, and encrusting ice spikes."""
    wood, moss, crystal = t.bm("WOOD"), t.bm("MOSS"), t.bm("CRYSTAL")

    # Flared gnarled roots anchored into snow/rock (-0.9 footing)
    for rx, ry in ((-2.6, -1.4), (2.5, -1.6), (-1.4, 2.8), (1.8, 2.4)):
        tapered_limb(wood, (rx * 1.4, ry * 1.4, -0.9), (rx * 0.28, ry * 0.28, 2.6), 0.72, 1.15, segs=6)
    rock_clean(moss, (5.8, 5.4, 1.6), Matrix.Translation((0.0, 0.2, 0.2)), seed=301, roughness=0.22)

    # Sinuous wind-leaned main trunk splitting upward (no foliage anywhere)
    p0 = (0.0, 0.0, -0.8)
    p1 = (0.4, -0.4, 6.2)
    p2 = (0.9, -1.1, 13.4)
    p3 = (1.5, -1.9, 20.6)
    p4 = (2.1, -2.5, 25.4)
    tapered_limb(wood, p0, p1, 1.65, 1.25, segs=7)
    tapered_limb(wood, p1, p2, 1.25, 0.88, segs=7)
    tapered_limb(wood, p2, p3, 0.88, 0.48, segs=6)
    tapered_limb(wood, p3, p4, 0.48, 0.14, segs=5)

    # Bare skeletal boughs & forked twigs reaching out
    limbs = (
        (p1, (-4.2, -2.0, 9.8), (-6.8, -3.4, 12.6), 0.62, 0.28, 0.08),
        (p1, (4.8, 0.6, 10.2), (7.6, -0.6, 13.0), 0.58, 0.26, 0.08),
        (p2, (-3.6, 2.8, 17.0), (-5.8, 3.8, 20.4), 0.50, 0.24, 0.07),
        (p2, (5.2, -3.2, 17.6), (7.9, -4.6, 20.8), 0.48, 0.22, 0.07),
        (p3, (-2.8, -3.8, 23.4), (-4.4, -5.2, 25.2), 0.34, 0.16, 0.06),
        (p3, (4.2, 0.8, 23.8), (6.0, 0.4, 25.6), 0.32, 0.15, 0.06),
    )
    for base_pt, mid_pt, tip_pt, r0, r1, r2 in limbs:
        tapered_limb(wood, base_pt, mid_pt, r0, r1, segs=6)
        tapered_limb(wood, mid_pt, tip_pt, r1, r2, segs=5)
        uvsphere(moss, r1 * 1.45, Matrix.Translation((mid_pt[0], mid_pt[1], mid_pt[2] + r1 * 0.8)), 5, 4)
        tapered_limb(crystal, (mid_pt[0], mid_pt[1], mid_pt[2] - 0.1), (mid_pt[0] + 0.15, mid_pt[1] - 0.2, mid_pt[2] - 2.6), 0.24, 0.03, segs=4)

    # Sharp windward ice-rime fins encrusting the north/left side of trunk
    for rz, rlen in ((4.5, 4.2), (10.8, 3.8), (16.5, 3.2)):
        tapered_limb(crystal, (-0.3, 0.9, rz), (-1.4, 2.2, rz + rlen), 0.55, 0.06, segs=5)


def build_f18():
    reset_scene()

    kit = bpy.data.collections.new("FrozenF18Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F18_TEMPLATES.items():
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


def export_f18(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FrozenF18Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FrozenF18Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f18()
    export_f18(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    tiles = os.path.join(preview_dir, "tiles")
    os.makedirs(tiles, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    lc = next(c for c in bpy.context.view_layer.layer_collection.children if c.collection == kit)
    lc.exclude = False
    stage = bpy.data.collections.new("PreviewStage")
    scene.collection.children.link(stage)
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    stage.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 320
    all_kit_objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in all_kit_objs:
        o.hide_render = True
    tile_imgs = []
    for n in F18_TEMPLATES:
        c = bpy.data.collections[n]
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for o in c.objects:
            o.hide_render = False
            for v in o.data.vertices:
                lo = Vector(map(min, lo, v.co))
                hi = Vector(map(max, hi, v.co))
        size = max(hi - lo)
        ctr = (lo + hi) / 2
        cam.location = ctr + Vector((0.55, -1.0, 0.42)).normalized() * size * 1.9
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        p_path = os.path.join(tiles, n + ".png")
        scene.render.filepath = p_path
        bpy.ops.render.render(write_still=True)
        for o in c.objects:
            o.hide_render = True
        tile_imgs.append(bpy.data.images.load(p_path))
    import numpy as np
    n_templates = len(F18_TEMPLATES)
    sheet = bpy.data.images.new("PreviewSheet", width=320 * n_templates, height=320, alpha=True)
    buf = np.zeros((320, 320 * n_templates, 4), dtype=np.float32)
    for idx, img in enumerate(tile_imgs):
        arr = np.asarray(img.pixels[:], dtype=np.float32).reshape(320, 320, 4)
        buf[:, idx * 320:(idx + 1) * 320, :] = arr
        bpy.data.images.remove(img)
    sheet.pixels.foreach_set(buf.ravel())
    sheet.filepath_raw = os.path.join(preview_dir, "kit_sheet_1.png")
    sheet.file_format = "PNG"
    sheet.save()
    bpy.data.images.remove(sheet)
    print(json.dumps(manifest, indent=2))
