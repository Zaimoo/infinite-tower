"""
Fungal Hollow Floor 10 (Matriarch's Hollow) primary sculpted kit (`fungal_f10_kit`), generated in Blender.

Matches the 7 templates registered in TowerBiomeKit.ExtraTemplates and the preview tiles in
assets-source/tower/fungal_f10_kit/previews/tiles/:
  WebbedArchway      three-pillar Velmari lintel archway draped in silk cables, cocoons and shelf caps
  SilkSpire          tall tapered Velmari spire wound in silk strands, hanging cocoons and shelf caps
  BroodEggClutch     mossy brood pad cradling four clustered egg sacs bound by silk cords and flanking caps
  StolenLampCocoon   stone plinth with angled iron hanger suspending a silk-wrapped glowing lamp cocoon
  SilkWindlass       stone-based timber winch winding a fat ribbed silk drum with metal crank & taut cords
  LastLampShrine     open-front Velmari stone gable pavilion housing the Lampkeepers' warm burning Last Lamp
  SilkWebCurtain     twin capped stalk-posts strung with sagging silk strands and three hanging cocoons

Run headless:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_fungal_f10_kit.py
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "fungal_f10_kit")

f6 = runpy.run_path(os.path.join(HERE, "generate_fungal_f6_kit.py"), init_globals={"RUN_F6": False})
Template = f6["Template"]
M = f6["M"]
box = f6["box"]
cone = f6["cone"]
uvsphere = f6["uvsphere"]
lathe = f6["lathe"]
tube = f6["tube"]
ring_mesh = f6["ring_mesh"]
reset_scene = f6["reset_scene"]
finalize = f6["finalize"]
render_previews = f6["render_previews"]
ROLE_PREVIEW = f6["ROLE_PREVIEW"]
ROLE_PREVIEW.update({"WOOD": (0.44, 0.34, 0.26), "METAL": (0.36, 0.36, 0.42)})

DEFAULT_BUDGET = 2200
F10_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F10_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


def strand(bm, p0, p1, sag, r=0.14, segs=8):
    p0, p1 = Vector(p0), Vector(p1)
    pts = [p0.lerp(p1, i / segs) - Vector((0, 0, sag * math.sin(math.pi * i / segs))) for i in range(segs + 1)]
    tube(bm, pts, [r] * len(pts), 5)


def cap_disc(bm_cap, bm_glow, center, r=1.5, h=0.6):
    uvsphere(bm_cap, 1.0, M(center, scale=(r, r * 0.85, h)), u=10, v=6)
    ring_mesh(bm_glow, r * 0.82, 0.10, 10, M((center[0], center[1], center[2] - h * 0.35)), tube_segs=4)


def hanging_cocoon(bm_bulb, bm_glow, bm_stem, top, drop=2.2, rx=0.85, rz=1.65):
    cx, cy, cz = top[0], top[1], top[2] - drop
    tube(bm_stem, [top, (cx, cy, cz + rz * 0.85)], [0.14, 0.12], 5)
    uvsphere(bm_bulb, 1.0, M((cx, cy, cz), scale=(rx, rx, rz)), u=10, v=7)
    ring_mesh(bm_glow, rx * 1.02, 0.13, 10, M((cx, cy, cz - rz * 0.15)), tube_segs=4)


@template("WebbedArchway", STONE=1200, TRIM=900, STEM=900, BULB=900, CAP=600, GLOW=450)
def webbed_archway(t):
    stone, trim, stem, bulb, cap, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("STEM"), t.bm("BULB"), t.bm("CAP"), t.bm("GLOW")
    # Three Velmari pillars at x = -7.6, 0, +7.6 with plinth bases & capitals.
    for px in (-7.6, 0.0, 7.6):
        box(trim, (3.0, 3.4, 1.4), M((px, 0, 0.7)))
        box(stone, (2.2, 2.6, 10.6), M((px, 0, 6.7)))
        box(trim, (3.0, 3.4, 1.2), M((px, 0, 12.6)))
        cap_disc(cap, glow, (px, -1.65, 11.4), r=1.35, h=0.5)
    # Stepped Velmari lintel beam & diagonal knee braces.
    box(stone, (18.2, 4.0, 1.7), M((0, 0, 14.0)))
    box(trim, (17.2, 3.2, 1.1), M((0, 0, 15.35)))
    for bx in (-7.6, 0.0, 7.6):
        box(trim, (2.4, 2.4, 0.4), M((bx, 0, 15.7)))
    for sx in (-1, 1):
        tube(stone, [(sx * 7.2, 0, 10.6), (sx * 4.2, 0, 13.4)], [0.65, 0.65], 5)
        tube(stone, [(sx * 0.6, 0, 10.6), (sx * 3.4, 0, 13.4)], [0.65, 0.65], 5)
    # Sagging silk strands & 4 hanging brood cocoons across both bays.
    for bay_x0, bay_x1 in [(-7.0, -0.5), (0.5, 7.0)]:
        for idx, z_h in enumerate([12.4, 11.4, 10.3, 9.2]):
            strand(stem, (bay_x0, -0.7, z_h), (bay_x1, -0.7, z_h), sag=1.7 + idx * 0.15, r=0.14)
        for cx in (bay_x0 + 2.1, bay_x1 - 2.1):
            hanging_cocoon(bulb, glow, stem, (cx, -0.2, 13.2), drop=3.6, rx=0.9, rz=1.9)


@template("SilkSpire", STONE=1200, TRIM=900, STEM=900, BULB=700, CAP=650, GLOW=450)
def silk_spire(t):
    stone, trim, stem, bulb, cap, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("STEM"), t.bm("BULB"), t.bm("CAP"), t.bm("GLOW")
    # Octagonal stepped Velmari spire rising Z 0..25.4.
    lathe(trim, [(4.8, 0.0), (4.6, 1.6), (4.2, 2.2)], 8, M(), cap_bottom=True, cap_top=True)
    lathe(stone, [(4.0, 2.0), (3.4, 10.0), (2.5, 17.5), (1.3, 22.8), (0.2, 25.4)], 8, M(), cap_bottom=True, cap_top=True)
    for rz, rr in [(9.8, 3.65), (17.2, 2.75)]:
        ring_mesh(trim, rr, 0.35, 8, M((0, 0, rz)), tube_segs=5)
    # Spiral silk cords & glowing bands wrapping the spire + 3 hanging cocoons + shelf caps.
    pts = []
    for i in range(18):
        f = i / 17.0
        a = f * 4.5 * math.pi
        r = 4.5 * (1.0 - f * 0.78) + 0.3
        pts.append(Vector((math.cos(a) * r, math.sin(a) * r, 2.4 + f * 19.5)))
    tube(stem, pts, [0.22] * len(pts), 5)
    for k in range(3):
        a = k * 2 * math.pi / 3 + 0.4
        hanging_cocoon(bulb, glow, stem, (math.cos(a) * 3.6, math.sin(a) * 3.6, 15.5 - k * 2.5), drop=2.8, rx=0.78, rz=1.55)
        cap_disc(cap, glow, (math.cos(a + 1.1) * 3.8, math.sin(a + 1.1) * 3.8, 6.2 + k * 4.6), r=1.45, h=0.52)


@template("BroodEggClutch", BULB=1400, MOSS=800, STEM=800, CAP=600, GLOW=450)
def brood_egg_clutch(t):
    bulb, moss, stem, cap, glow = t.bm("BULB"), t.bm("MOSS"), t.bm("STEM"), t.bm("CAP"), t.bm("GLOW")
    # Flat spore-moss nest cushion.
    uvsphere(moss, 1.0, M((0, 0, 1.0), scale=(4.6, 3.9, 0.85)), u=10, v=6)
    # Four clustered ovoid brood eggs with glowing equatorial bands.
    eggs = [
        (0.0, 0.2, 2.4, 1.45, 2.15),
        (-1.8, -0.6, 1.9, 1.15, 1.65),
        (1.4, -1.2, 1.85, 1.18, 1.68),
        (1.8, 1.1, 1.8, 1.05, 1.55),
    ]
    for ex, ey, ez, er, eh in eggs:
        uvsphere(bulb, 1.0, M((ex, ey, ez), scale=(er, er, eh)), u=10, v=7)
        ring_mesh(glow, er * 1.02, 0.10, 10, M((ex, ey, ez - 0.35)), tube_segs=4)
    # Thick silk root-collar wrapping the front & sides + 2 flanking shelf caps.
    collar = [(-3.6, -1.0, 1.4), (-2.0, -2.8, 1.3), (0.0, -3.1, 1.35), (2.2, -2.5, 1.3), (3.6, -0.8, 1.4)]
    tube(stem, collar, [0.42, 0.48, 0.52, 0.48, 0.42], 6)
    for sx, sy in [(-2.2, -2.8), (0.0, -3.1), (2.2, -2.5)]:
        tube(stem, [(sx, sy, 0.3), (sx, sy + 0.4, 2.4)], [0.22, 0.16], 5)
    cap_disc(cap, glow, (-3.7, 0.2, 1.85), r=1.15, h=0.42)
    cap_disc(cap, glow, (3.2, -1.6, 1.7), r=1.1, h=0.40)


@template("StolenLampCocoon", TRIM=800, METAL=800, BULB=900, STEM=600, CAP=500, GLOW=450)
def stolen_lamp_cocoon(t):
    trim, metal, bulb, stem, cap, glow = t.bm("TRIM"), t.bm("METAL"), t.bm("BULB"), t.bm("STEM"), t.bm("CAP"), t.bm("GLOW")
    # Square chamfered Velmari stone plinth base.
    box(trim, (4.2, 5.0, 1.4), M((0, 0, 0.7)))
    # Angled forged-iron lamp post & curved hook arm rising to Z 12.4.
    tube(metal, [(0, 1.4, 1.2), (0, 1.2, 7.6), (0, 0.4, 10.6), (0, -1.2, 12.3), (0, -2.0, 11.4)], [0.36, 0.32, 0.28, 0.22, 0.16], 6)
    ring_mesh(metal, 0.45, 0.10, 10, M((0, -2.0, 10.9), rot=(0, math.pi / 2, 0)), tube_segs=4)
    # Silk-wrapped glowing stolen lamp cocoon hanging from the hook + cap on plinth.
    hanging_cocoon(bulb, glow, stem, (0, -2.0, 10.8), drop=4.4, rx=1.4, rz=2.1)
    tube(stem, [(0, -0.7, 7.2), (0, 1.1, 8.2)], [0.14, 0.12], 4)
    cap_disc(cap, glow, (0, -1.3, 1.75), r=1.1, h=0.38)


@template("SilkWindlass", TRIM=900, WOOD=900, STEM=1200, METAL=700, BULB=600, GLOW=350)
def silk_windlass(t):
    trim, wood, stem, metal, bulb, glow = t.bm("TRIM"), t.bm("WOOD"), t.bm("STEM"), t.bm("METAL"), t.bm("BULB"), t.bm("GLOW")
    # Stepped Velmari stone base slab.
    box(trim, (9.2, 5.6, 0.9), M((0, 0, 0.45)))
    box(trim, (8.4, 4.6, 0.6), M((0, 0.1, 1.2)))
    # Twin timber A-frame trestles at x = -3.4 and +3.4 + central wooden axle.
    for sx in (-3.4, 3.4):
        tube(wood, [(sx, -1.6, 1.3), (sx, 0, 4.8), (sx, 1.6, 1.3)], [0.34, 0.36, 0.34], 5)
        box(wood, (0.65, 3.0, 0.5), M((sx, 0, 2.7)))
    tube(wood, [(-4.4, 0, 4.3), (4.8, 0, 4.3)], [0.46, 0.46], 8)
    # Metal ratchet wheels & hand crank on +X end.
    for sx in (-4.1, 4.1):
        ring_mesh(metal, 1.35, 0.16, 12, M((sx, 0, 4.3), rot=(0, math.pi / 2, 0)), tube_segs=4)
    tube(metal, [(4.8, 0, 4.3), (5.0, 0, 6.2), (6.1, 0, 6.2)], [0.16, 0.16, 0.16], 5)
    # Fat ribbed wound silk drum on the axle + 3 taut silk cords running down-front.
    for i in range(6):
        dx = -2.5 + i * 1.0
        uvsphere(stem, 1.0, M((dx, 0, 4.3), scale=(0.68, 1.85, 1.85)), u=10, v=7)
    for cx in (-1.8, 0.0, 1.8):
        tube(stem, [(cx, -1.6, 3.4), (cx, -2.7, 0.5)], [0.16, 0.15], 5)
    # Two brood bulbs resting on the base under the spool + subtle glow ring.
    uvsphere(bulb, 0.85, M((-1.3, -1.3, 1.9)), u=8, v=6)
    uvsphere(bulb, 0.65, M((1.4, -1.4, 1.75)), u=8, v=6)
    ring_mesh(glow, 1.9, 0.08, 12, M((0, 0, 4.3), rot=(0, math.pi / 2, 0)), tube_segs=4)


@template("LastLampShrine", STONE=1200, TRIM=1000, WOOD=600, CANDLE=500, BULB=400, GLOW=450, STEM=350)
def last_lamp_shrine(t):
    stone, trim, wood, candle, bulb, glow, stem = t.bm("STONE"), t.bm("TRIM"), t.bm("WOOD"), t.bm("CANDLE"), t.bm("BULB"), t.bm("GLOW"), t.bm("STEM")
    # Raised Velmari stone floor plinth (12.8 x 9.6).
    box(trim, (12.8, 9.6, 1.0), M((0, 0, 0.5)))
    # Four heavy corner pillars + recessed back wall.
    for sx in (-5.2, 5.2):
        for sy in (-3.6, 3.6):
            box(stone, (1.8, 1.8, 6.6), M((sx, sy, 4.3)))
    box(stone, (10.2, 1.2, 6.6), M((0, 3.8, 4.3)))
    # Radial stained rose-window medallion on the back wall.
    ring_mesh(trim, 1.7, 0.30, 12, M((0, 3.1, 5.4), rot=(math.pi / 2, 0, 0)), tube_segs=4)
    for k in range(6):
        a = k * math.pi / 3
        tube(glow, [(0, 3.1, 5.4), (math.cos(a) * 1.45, 3.1, 5.4 + math.sin(a) * 1.45)], [0.12, 0.10], 4)
    # Pitched stone gable roof & timber wall-plates.
    for sx in (-1, 1):
        box(trim, (7.6, 9.8, 0.85), M((sx * 3.15, 0, 8.7), rot=(0, sx * 0.44, 0)))
        box(wood, (0.55, 8.8, 0.55), M((sx * 5.2, 0, 7.6)))
    # Central stone pedestal housing the Lampkeepers' warm burning Last Lamp (CANDLE)!
    box(stone, (2.2, 2.2, 2.8), M((0, -0.4, 2.4)))
    uvsphere(candle, 1.0, M((0, -0.4, 4.6), scale=(0.95, 0.95, 1.15)), u=10, v=7)
    box(trim, (2.4, 2.4, 0.55), M((0, -0.4, 5.95)))
    # Small cobweb threads & brood bulb tucked under the eaves.
    strand(stem, (-4.4, -3.2, 7.2), (-1.4, -3.2, 9.2), sag=0.45, r=0.10)
    uvsphere(bulb, 0.55, M((4.2, 2.8, 6.8)), u=7, v=5)


@template("SilkWebCurtain", STEM=1000, CAP=700, BULB=800, GLOW=450)
def silk_web_curtain(t):
    stem, cap, bulb, glow = t.bm("STEM"), t.bm("CAP"), t.bm("BULB"), t.bm("GLOW")
    # Twin tapered mushroom-stalk posts at x = -7.4 and +7.4 standing flush on z = 0.
    for px in (-7.4, 7.4):
        cone(stem, 1.25, 0.95, 5.6, segs=10, mat=M((px, 0, 0.0)))
        cap_disc(cap, glow, (px, 0, 5.85), r=1.55, h=0.52)
    # Four sagging silk curtain strands & 3 hanging brood cocoons.
    for idx, z_h in enumerate([5.2, 4.5, 3.8, 3.1]):
        strand(stem, (-6.5, 0, z_h), (6.5, 0, z_h), sag=1.45 + idx * 0.12, r=0.14)
    for cx, cz_top in [(-3.6, 4.7), (0.0, 4.1), (3.6, 4.7)]:
        hanging_cocoon(bulb, glow, stem, (cx, 0.0, cz_top), drop=1.7, rx=0.72, rz=1.35)


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("FungalF10Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F10_TEMPLATES.items():
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
        filepath=os.path.join(OUT_DIR, "FungalF10Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FungalF10Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F10_TEMPLATES.keys()), tile=520, cols=4)
    print(json.dumps(manifest, indent=2))
