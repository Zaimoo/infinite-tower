"""
Fungal Hollow Floor 10 (Matriarch's Hollow) sculpted assets for the funnel-web redesign: the silk nest,
generated in Blender.

The Spore Matriarch's nest is a made thing: it should look woven, not grown. Same conventions as
generate_fungal_f6_kit.py (1 unit = 1 stud, standing on z = 0, front -Y in Blender / +Z in Roblox, one
mesh per colour role named "<Template>__<ROLE>"); it reuses that script's helpers. Adds one role, SILK
(bone-white web, tinted and made slightly translucent at placement).

Not to be confused with fungal_f10_kit, the kit an earlier session made for the previous Floor 10 design.

    ShroudSpire  a tall Velmari spire shrouded in silk: a landmark round the dais (named apart from fungal_f10_kit's SilkSpire)
    EggRack      a pointed-arch Velmari window frame hung with rows of translucent egg-sacs
    SilkSpool    the Spinneret's wooden winch winding a fat spool of silk
    SilkDrape    a sagging, torn sheet of web strung between two posts on anchor lines
    CocoonLamp   a stolen Lampkeeper lamp: a slate post, the lamp wrapped in a silk cocoon, a warm glow inside

Outputs (assets-source/tower/fungal_f10_nest_kit/): FungalF10NestKit.blend, FungalF10NestKit.fbx,
manifest.json, previews/.

Run headless:  blender --background --python tools/blender/generate_fungal_f10_nest_kit.py
"""
import bpy, bmesh, math, os, json, random, runpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "fungal_f10_nest_kit")

f6 = runpy.run_path(os.path.join(HERE, "generate_fungal_f6_kit.py"), init_globals={"RUN_F6": False})
Template = f6["Template"]
M = f6["M"]
box = f6["box"]
cone = f6["cone"]
ico = f6["ico"]
uvsphere = f6["uvsphere"]
lathe = f6["lathe"]
tube = f6["tube"]
displace = f6["displace"]
rock = f6["rock"]
ring_mesh = f6["ring_mesh"]
reset_scene = f6["reset_scene"]
finalize = f6["finalize"]
render_previews = f6["render_previews"]
ROLE_PREVIEW = f6["ROLE_PREVIEW"]
SMOOTH_ROLES = f6["SMOOTH_ROLES"]
ROLE_PREVIEW.update({"SILK": (0.92, 0.90, 0.96), "WOOD": (0.40, 0.30, 0.22)})
SMOOTH_ROLES.update({"SILK"})

DEFAULT_BUDGET = 3500
F10_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F10_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def strand(bm, p0, p1, sag, r=0.06, segs=6):
    """A silk thread from p0 to p1, sagging by `sag` at its middle."""
    p0, p1 = Vector(p0), Vector(p1)
    pts = [p0.lerp(p1, i / segs) - Vector((0, 0, sag * math.sin(math.pi * i / segs))) for i in range(segs + 1)]
    tube(bm, pts, [r] * len(pts), 3, cap=False)


def sheet(bm, a0, a1, b0, b1, cols, rows, sag, seed, holes=0.18, jitter=0.0):
    """A sagging web sheet over the quad a0-a1 (top edge) / b0-b1 (bottom edge), with torn holes; `jitter`
    shakes the inner vertices so the weave reads as web, not cloth."""
    rng = random.Random(seed)
    grid = []
    for r in range(rows + 1):
        v = r / rows
        row = []
        for c in range(cols + 1):
            u = c / cols
            top = Vector(a0).lerp(Vector(a1), u)
            bot = Vector(b0).lerp(Vector(b1), u)
            p = top.lerp(bot, v)
            p.y -= sag * math.sin(math.pi * u) * math.sin(math.pi * (0.25 + 0.75 * v))
            p.z -= sag * 0.6 * math.sin(math.pi * u) * v
            if jitter > 0 and 0 < r < rows and 0 < c < cols:
                p += Vector((rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter) * 0.3, rng.uniform(-jitter, jitter)))
            row.append(bm.verts.new(p))
        grid.append(row)
    for r in range(rows):
        for c in range(cols):
            if rng.random() < holes:
                continue
            bm.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))


@template("ShroudSpire", TRIM=3000, SILK=3000, GLOW=400)
def silk_spire(t):
    """A Velmari spire (~62 tall) shrouded in silk: tiered octagonal body, buttress ribs, a needle top."""
    rng = t.rng
    trim, silk, glow = t.bm("TRIM"), t.bm("SILK"), t.bm("GLOW")
    # Body: three tapering octagonal tiers with cornices, then the needle.
    tiers = [(9.0, 0, 18), (7.2, 18, 34), (5.4, 34, 46)]
    for r, z0, z1 in tiers:
        lathe(trim, [(r * 1.08, z0), (r, z0 + 1.2), (r * 0.94, z1 - 1.0), (r * 1.06, z1 - 0.6), (r * 1.06, z1)], 8, M(), cap_bottom=True, cap_top=True)
        # Pointed-arch window slits round each tier.
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 8
            c = Vector((math.cos(a) * r * 0.98, math.sin(a) * r * 0.98, (z0 + z1) / 2))
            box(glow, (0.9, 0.3, (z1 - z0) * 0.45), M(c, rot=(0, 0, a + math.pi / 2)))
    cone(trim, 4.4, 0.2, 16, 8, M((0, 0, 46)))
    # Buttress ribs at the base, and finials at the tier corners.
    for k in range(8):
        a = k * math.pi / 4
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(trim, [d * 12.5 + Vector((0, 0, 0)), d * 10.2 + Vector((0, 0, 7)), d * 8.8 + Vector((0, 0, 14))], [1.1, 0.85, 0.6], 5)
        for r, z0, z1 in tiers[:2]:
            cone(trim, 0.5, 0.05, 3.2, 5, M(d * r * 1.02 + Vector((0, 0, z1))))
    # The shroud: strands from the needle down to the ground in a wide skirt, torn sheets between some of
    # them, and web rings round the tiers.
    tip = Vector((0, 0, 58))
    feet = []
    for k in range(14):
        a = k * 2 * math.pi / 14 + rng.uniform(-0.1, 0.1)
        foot = Vector((math.cos(a) * rng.uniform(15, 19), math.sin(a) * rng.uniform(15, 19), 0.2))
        feet.append(foot)
        mid = Vector((math.cos(a) * 9.2, math.sin(a) * 9.2, 30))
        tube(silk, [tip, tip.lerp(mid, 0.5) + Vector((math.cos(a), math.sin(a), 0)) * 2.4, mid, mid.lerp(foot, 0.5) + Vector((math.cos(a), math.sin(a), 0)) * 1.5, foot], [0.08, 0.1, 0.12, 0.1, 0.14], 3, cap=False)
    for k in range(0, 14, 2):
        a0, a1 = k * 2 * math.pi / 14, (k + 1) * 2 * math.pi / 14
        top0 = Vector((math.cos(a0) * 7.8, math.sin(a0) * 7.8, 32))
        top1 = Vector((math.cos(a1) * 7.8, math.sin(a1) * 7.8, 32))
        sheet(silk, top0, top1, feet[k] + Vector((0, 0, 2)), feet[k + 1] + Vector((0, 0, 2)), 6, 7, 0.0, 11 + k, holes=0.35, jitter=0.5)
    for z, r in ((16, 11.8), (30, 9.4), (44, 7.0)):
        pts = [Vector((math.cos(2 * math.pi * i / 16) * r, math.sin(2 * math.pi * i / 16) * r, z - 0.6 * (i % 2))) for i in range(17)]
        tube(silk, pts, [0.1] * len(pts), 3, cap=False)


@template("EggRack", TRIM=1600, CRYSTAL=1600, SILK=900, WOOD=400, BULB=300)
def egg_rack(t):
    """A pointed-arch window frame (~14 wide, 20 tall) with three rods of hanging egg-sacs and web in its corners."""
    rng = t.rng
    trim, sacs, silk, wood, bulb = t.bm("TRIM"), t.bm("CRYSTAL"), t.bm("SILK"), t.bm("WOOD"), t.bm("BULB")
    w, h = 13.0, 16.0
    for sx in (-1, 1):
        box(trim, (1.6, 2.4, h - 3.0), M((sx * (w / 2 - 0.8), 0, (h - 3.0) / 2)), bevel=0.12)
        box(trim, (2.2, 2.8, 1.0), M((sx * (w / 2 - 0.8), 0, 0.5)), bevel=0.08)
    # Pointed (Gothic) arch: each side an arc centred on the opposite pilaster, meeting at the apex.
    half = w / 2 - 0.8
    spring = h - 4.5
    for sx in (-1, 1):
        cx = -sx * half * 0.35  # each arc's centre sits across the opening
        rad = abs(sx * half - cx)
        apex = math.sqrt(max(rad * rad - cx * cx, 0.01))
        pts = []
        for i in range(11):
            x = sx * half + (0 - sx * half) * i / 10
            z = spring + math.sqrt(max(rad * rad - (x - cx) ** 2, 0.0))
            pts.append(Vector((x, 0, z)))
        tube(trim, pts, [0.7] * len(pts), 5, cap=False)
        box(trim, (1.2, 2.2, 1.6), M((0, 0, spring + apex + 0.4)), bevel=0.1)
    box(trim, (w + 0.6, 2.8, 0.8), M((0, 0, 1.4)), bevel=0.08)  # sill
    # Three rods across the opening, each with a row of hanging egg-sacs on threads.
    for r, z in enumerate((12.0, 8.6, 5.2)):
        tube(wood, [Vector((-w / 2 + 1.6, -0.2, z)), Vector((w / 2 - 1.6, -0.2, z))], [0.18, 0.18], 5, cap=False)
        n = 5 - (r % 2)
        for k in range(n):
            x = -w / 2 + 2.6 + (w - 5.2) * k / max(1, n - 1) + rng.uniform(-0.3, 0.3)
            ln = rng.uniform(0.4, 1.0)
            tube(silk, [Vector((x, -0.2, z)), Vector((x, -0.25, z - ln))], [0.04, 0.04], 3, cap=False)
            s = rng.uniform(0.55, 0.8)
            c = Vector((x, -0.25, z - ln - s * 1.25))
            v = uvsphere(sacs, s, M(c, scale=(1.0, 1.0, 1.6)), u=10, v=7)
            displace(sacs, v, 0.03, 1.5, r * 7 + k)
            ico(bulb, s * 0.3, M(c), 1)
    # Web in the upper corners, and a few threads slung across the opening.
    sheet(silk, (-w / 2 + 1.6, -0.6, h - 3.2), (-w / 2 + 4.2, -0.6, h - 1.0), (-w / 2 + 1.6, -0.8, h - 6.4), (-w / 2 + 2.4, -0.8, h - 6.0), 3, 3, 0.3, 5, holes=0.25)
    sheet(silk, (w / 2 - 4.2, -0.6, h - 1.0), (w / 2 - 1.6, -0.6, h - 3.2), (w / 2 - 2.4, -0.8, h - 6.0), (w / 2 - 1.6, -0.8, h - 6.4), 3, 3, 0.3, 6, holes=0.25)
    for z in (13.6, 10.2, 6.8):
        strand(silk, (-w / 2 + 1.6, -0.8, z + rng.uniform(-0.4, 0.4)), (w / 2 - 1.6, -0.8, z + rng.uniform(-0.4, 0.4)), 0.9, r=0.04)


@template("SilkSpool", WOOD=1500, SILK=1200, TRIM=300)
def silk_spool(t):
    """A wooden A-frame winch winding a fat spool of silk, its crank to one side (~12 x 10, 8 tall)."""
    wood, silk, trim = t.bm("WOOD"), t.bm("SILK"), t.bm("TRIM")
    axle_z, half = 5.0, 4.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            tube(wood, [Vector((sx * half, sy * 2.6, 0)), Vector((sx * half, sy * 0.3, axle_z + 0.4))], [0.3, 0.24], 6)
        box(wood, (0.6, 5.6, 0.5), M((sx * half, 0, 0.9)), bevel=0.05)
    tube(wood, [Vector((-half - 1.2, 0, axle_z)), Vector((half + 1.2, 0, axle_z))], [0.3, 0.3], 8, cap=True)
    # The spool: flanged drum, then a fat, lumpy winding of silk.
    for sx in (-1, 1):
        cone(wood, 2.6, 2.6, 0.35, 14, M((sx * 2.9, 0, axle_z), rot=(0, math.pi / 2, 0)) @ M((0, 0, -0.17)))
    v = lathe(silk, [(1.0, -2.6), (2.1, -2.3), (2.35, -1.0), (2.4, 0.6), (2.2, 2.2), (1.0, 2.6)], 16, M((0, 0, axle_z), rot=(0, math.pi / 2, 0)), cap_bottom=False, cap_top=False)
    displace(silk, v, 0.12, 1.2, 3)
    # Crank handle and stone weights at the feet.
    tube(wood, [Vector((half + 1.2, 0, axle_z)), Vector((half + 1.2, 0, axle_z - 1.8)), Vector((half + 2.2, 0, axle_z - 1.8))], [0.18, 0.18, 0.18], 5, cap=False)
    for sx in (-1, 1):
        box(trim, (1.4, 1.2, 0.9), M((sx * half, 2.4, 0.45)), bevel=0.1)
    # Strands paying off the spool toward the front, down to the ground.
    for k in range(4):
        x = -1.8 + k * 1.2
        strand(silk, (x, -2.3, axle_z - 0.4), (x * 1.6, -6.5, 0.2), 0.3, r=0.07)


@template("SilkDrape", SILK=1600, STEM=600, MOSS=200)
def silk_drape(t):
    """A sagging, torn web sheet (~18 wide, 9 tall) between two silk-wound posts, on anchor lines."""
    rng = t.rng
    silk, post, moss = t.bm("SILK"), t.bm("STEM"), t.bm("MOSS")
    half, h = 9.0, 9.0
    for sx in (-1, 1):
        base = Vector((sx * half, 0, 0))
        v = tube(post, [base + Vector((0, 0, -0.3)), base + Vector((sx * 0.3, 0.2, h * 0.5)), base + Vector((0, 0, h))], [0.6, 0.45, 0.32], 6)
        displace(post, v, 0.05, 1.0, int(sx + 3))
        for k in range(3):
            ring_mesh(silk, 0.55 - k * 0.05, 0.07, 10, M(base + Vector((0, 0, 2.5 + k * 2.1))), tube_segs=3)
        rock(moss, (2.2, 2.0, 0.6), M(base + Vector((0, 0, -0.2))), int(sx + 7), roughness=0.3, subdiv=2)
    sheet(silk, (-half, 0, h - 0.4), (half, 0, h - 0.4), (-half, 0, 2.4), (half, 0, 2.4), 12, 7, 2.2, 21, holes=0.34, jitter=0.35)
    strand(silk, (-half, 0, h - 0.2), (half, 0, h - 0.2), 1.6, r=0.1)
    # Anchor lines from the posts out and down to the ground, and a few threads across the sheet.
    for sx in (-1, 1):
        strand(silk, (sx * half, 0, h), (sx * (half + 3.0), -1.5, 0.2), 0.4, r=0.06)
        strand(silk, (sx * half, 0, h * 0.6), (sx * (half + 2.2), 1.8, 0.2), 0.3, r=0.05)
    for z in (7.4, 5.2, 3.4):
        strand(silk, (-half, -0.3, z), (half, -0.3, z + rng.uniform(-0.6, 0.6)), 1.8, r=0.05)
    for k in range(6):
        x = rng.uniform(-half * 0.7, half * 0.7)
        z = rng.uniform(2.0, 4.0)
        ln = rng.uniform(0.8, 1.8)
        tube(silk, [Vector((x, -1.0, z)), Vector((x + 0.1, -1.1, z - ln))], [0.05, 0.03], 3, cap=False)


@template("CocoonLamp", TRIM=800, SILK=900, CANDLE=300, WOOD=200)
def cocoon_lamp(t):
    """A stolen Lampkeeper lamp: a slate post and crook, the lamp wound in a silk cocoon, a dim warm glow inside."""
    trim, silk, flame, wood = t.bm("TRIM"), t.bm("SILK"), t.bm("CANDLE"), t.bm("WOOD")
    box(trim, (2.2, 2.2, 0.7), M((0, 0, 0.35)), bevel=0.12)
    cone(trim, 0.6, 0.5, 9.0, 8, M((0, 0, 0.7)))
    tube(trim, [Vector((0, 0, 9.3)), Vector((0, -1.0, 10.4)), Vector((0, -2.4, 10.5))], [0.35, 0.3, 0.26], 6, cap=False)
    hook = Vector((0, -2.4, 10.2))
    tube(wood, [hook, hook + Vector((0, 0, -0.8))], [0.06, 0.06], 3, cap=False)
    c = hook + Vector((0, 0, -2.6))
    v = uvsphere(silk, 1.0, M(c, scale=(1.05, 1.05, 1.75)), u=12, v=9)
    displace(silk, v, 0.08, 1.6, 9)
    uvsphere(flame, 0.45, M(c, scale=(1.0, 1.0, 1.5)), u=8, v=6)
    # Silk winding down the post and strands anchoring the cocoon.
    pts = [Vector((math.cos(i * 0.9) * 0.66, math.sin(i * 0.9) * 0.66, 1.2 + i * 0.55)) for i in range(15)]
    tube(silk, pts, [0.06] * len(pts), 3, cap=False)
    strand(silk, c + Vector((0, 0, -1.7)), (0.4, -3.4, 0.2), 0.2, r=0.05)
    strand(silk, c + Vector((0.6, 0, -1.2)), (1.6, -2.0, 0.2), 0.2, r=0.05)


def build_f10():
    reset_scene()
    kit = bpy.data.collections.new("FungalF10NestKit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F10_TEMPLATES.items():
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
            "Size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
            "Min": [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)],
        }
    return kit, manifest


def export_f10(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FungalF10NestKit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FungalF10NestKit.blend"))


if __name__ == "__main__" or globals().get("RUN_F10", False):
    kit, manifest = build_f10()
    export_f10(kit, manifest)
    if globals().get("PREVIEWS", True):
        render_previews(kit, os.path.join(OUT_DIR, "previews"), list(F10_TEMPLATES.keys()), tile=520, cols=5)
    result = {"templates": len(manifest), "manifest": manifest}
    print(json.dumps(manifest, indent=2))
