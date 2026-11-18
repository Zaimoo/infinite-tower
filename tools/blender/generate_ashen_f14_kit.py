"""
Ashen Dunes Floor 14 (Sunscar Fortress) sculpted assets, generated in headless Blender.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Outputs (assets-source/tower/ashen_f14_kit/):
    AshenF14Kit.blend     the generated scene
    AshenF14Kit.fbx       FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the 4 Floor 14 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "ashen_f14_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
lathe = kit_mod["lathe"]
uvsphere = kit_mod["uvsphere"]
tube = kit_mod["tube"]
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


DEFAULT_BUDGET = 3500
F14_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F14_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("KilnTower", STONE=1200, TRIM=1200, ALT=500, METAL=500, GLOW=300)
def kiln_tower(t):
    """Bottle-shaped Varrash furnace kiln tower with arched basalt firebox and glowing crown chimney."""
    stone, trim, alt, metal, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("ALT"), t.bm("METAL"), t.bm("GLOW")

    # Heavy octagonal basalt hearth base (z=0..10)
    cone(stone, 13.5, 12.0, 10.0, 8, M((0, 0, -0.1)))
    for k in range(4):
        ang = k * (math.tau / 4)
        bx, by = math.cos(ang) * 11.2, math.sin(ang) * 11.2
        box(stone, (5.2, 4.6, 12.0), M((bx, by, 6.0), rot=(0, 0, ang)), bevel=0.14)
    # Glowing furnace stoke throat facing front (-Y) & sides
    box(glow, (5.4, 1.4, 5.2), M((0.0, -11.4, 4.0)), bevel=0.08)
    box(metal, (6.4, 1.8, 1.2), M((0.0, -11.6, 6.8)), bevel=0.06)

    # Bottle-kiln brick belly & tall tapered chimney neck (z=10..56) via lathe profile
    profile = [
        (11.6, 9.8),
        (12.2, 16.0),
        (10.8, 23.0),
        (7.4, 31.0),
        (5.6, 40.0),
        (4.8, 52.0),
        (5.4, 55.5),
        (4.0, 56.0),
    ]
    lathe(trim, profile, 12, M((0, 0, 0)), cap_bottom=True, cap_top=False)

    # Terracotta brick belts & forged iron tension bands clamping the bottle belly
    for z_ring, r_ring in ((15.5, 12.4), (22.5, 11.1), (30.5, 7.8)):
        cone(alt, r_ring, r_ring * 0.98, 1.6, 12, M((0, 0, z_ring)))
        tube(metal, [(math.cos(a) * (r_ring + 0.2), math.sin(a) * (r_ring + 0.2), z_ring + 0.8) for a in [i * (math.tau / 12) for i in range(13)]], [0.32] * 13, 5)

    # Top chimney iron crown ribs + glowing molten kiln mouth
    cone(glow, 4.2, 3.4, 3.0, 10, M((0, 0, 52.8)))
    for k in range(6):
        ang = k * (math.tau / 6)
        box(metal, (0.9, 1.2, 6.5), M((math.cos(ang) * 5.2, math.sin(ang) * 5.2, 55.5), rot=(0, 0, ang)), bevel=0.05)


@template("SignalLensTower", STONE=1000, TRIM=1400, METAL=600, CRYSTAL=500, GLOW=300)
def signal_lens_tower(t):
    """East Bastion sandstone signal tower crowned by an iron gimbal ring holding a glowing amber focus lens."""
    stone, trim, metal, crystal, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("METAL"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Battered basalt bastion base (z=0..10)
    cone(stone, 13.0, 10.8, 10.0, 8, M((0, 0, -0.1)))
    for k in range(4):
        ang = k * (math.tau / 4) + math.pi / 4
        box(stone, (4.8, 4.8, 14.0), M((math.cos(ang) * 9.8, math.sin(ang) * 9.8, 7.0), rot=(0, 0, ang)), bevel=0.14)

    # Tapered square-buttressed sandstone watchtower shaft (z=10..42)
    cone(trim, 9.8, 7.0, 32.0, 8, M((0, 0, 9.8)))
    for k in range(4):
        ang = k * (math.tau / 4)
        box(trim, (3.0, 2.6, 30.0), M((math.cos(ang) * 8.2, math.sin(ang) * 8.2, 24.5), rot=(0, 0, ang)), bevel=0.12)

    # Lookout gallery deck (z=41.5..44)
    cone(stone, 8.8, 9.4, 2.5, 8, M((0, 0, 41.5)))
    for k in range(8):
        ang = k * (math.tau / 8)
        box(trim, (2.2, 1.4, 2.6), M((math.cos(ang) * 8.4, math.sin(ang) * 8.4, 45.2), rot=(0, 0, ang)), bevel=0.08)

    # Twin forged iron gimbal forks cradling a colossal convex amber glass lens facing south (-Y)
    for side in (-1, 1):
        box(metal, (1.8, 2.2, 14.5), M((side * 7.2, 0.0, 51.0), rot=(0, side * 0.14, 0)), bevel=0.1)
    # Outer gimbal hoop in X-Z plane (radius 6.2 centered at z=54)
    hoop_pts = [(math.cos(a) * 6.4, 0.0, 54.0 + math.sin(a) * 6.4) for a in [i * (math.tau / 16) for i in range(17)]]
    tube(metal, hoop_pts, [0.75] * 17, 6)
    # Convex amber crystal lens & radiant inner focal ember
    uvsphere(crystal, 5.4, M((0, 0, 54.0)) @ Matrix.Diagonal((1.0, 0.35, 1.0, 1.0)), u=14, v=8)
    cone(glow, 3.2, 3.2, 1.2, 10, M((0, -0.6, 54.0), rot=(math.pi / 2, 0, 0)))


@template("PortcullisGate", STONE=1100, TRIM=1300, METAL=800, ALT=400, GLOW=300)
def portcullis_gate(t):
    """Varrash Kiln Gate barbican arch spanning wide roadways with an iron portcullis jammed half-open."""
    stone, trim, metal, alt, glow = t.bm("STONE"), t.bm("TRIM"), t.bm("METAL"), t.bm("ALT"), t.bm("GLOW")

    # Twin heavy gatehouse flanking towers outside roadway (x = +-26, span ~66W total, ~38W open gate throat)
    for side in (-1, 1):
        px = side * 27.0
        box(stone, (14.0, 18.0, 10.0), M((px, 0.0, 4.9)), bevel=0.2)
        box(trim, (12.2, 16.0, 28.0), M((px, 0.0, 23.5)), bevel=0.18)
        box(alt, (13.4, 17.2, 2.2), M((px, 0.0, 38.0)), bevel=0.1)
        # Crenellated tower merlons
        for mx in (-4.4, 0.0, 4.4):
            for my in (-6.5, 6.5):
                box(trim, (2.6, 2.2, 3.2), M((px + mx, my, 40.6)), bevel=0.08)
        # Amber kiln sconce lanterns facing road approach (-Y)
        box(metal, (2.4, 2.2, 4.0), M((px - side * 3.0, -8.5, 14.0)), bevel=0.08)
        uvsphere(glow, 1.35, M((px - side * 3.0, -8.8, 14.0)), u=8, v=6)

    # Overhead barbican lintel beam & crenellated bridge parapet (>= 24 studs clear overhead above ground!)
    box(stone, (44.0, 14.0, 5.5), M((0.0, 0.0, 27.5)), bevel=0.16)
    box(trim, (46.0, 15.2, 7.0), M((0.0, 0.0, 33.5)), bevel=0.16)
    box(alt, (47.0, 16.0, 1.8), M((0.0, 0.0, 37.8)), bevel=0.08)
    for mx in range(-18, 22, 6):
        for my in (-6.2, 6.2):
            box(trim, (3.2, 2.0, 3.0), M((float(mx), my, 40.0)), bevel=0.08)

    # Iron portcullis grille jammed half-open (tilted slightly, teeth stopping at z = 18.5 for full player clearance!)
    tilt = (0.04, 0.06, 0.0)
    for gx in range(-18, 21, 6):
        box(metal, (0.95, 1.1, 10.5), M((float(gx), 0.0, 23.0 + (gx % 2) * 0.4), rot=tilt), bevel=0.04)
        # Sharpened portcullis spike foot
        cone(metal, 0.65, 0.08, 2.2, 4, M((float(gx), 0.0, 17.8 + (gx % 2) * 0.4), rot=(math.pi, 0, 0)))
    for gz in (20.2, 24.4):
        box(metal, (39.0, 1.4, 0.9), M((0.0, 0.0, gz), rot=tilt), bevel=0.04)


@template("AshmarketStall", WOOD=1000, FOLIAGE=900, TRIM=700, ALT=500, STONE=400)
def ashmarket_stall(t):
    """Varrash Ashmarket bazaar stall with charred timber poles, sun-bleached ash-draped awning, and wares."""
    wood, foliage, trim, alt, stone = t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("TRIM"), t.bm("ALT"), t.bm("STONE")

    # Sandstone curb base & counter slab (z=0..3.6)
    box(stone, (14.5, 9.0, 0.8), M((0.0, 0.0, 0.35)), bevel=0.1)
    box(trim, (12.8, 3.4, 3.2), M((0.0, -2.0, 2.0)), bevel=0.1)
    box(alt, (13.4, 3.8, 0.5), M((0.0, -2.0, 3.7)), bevel=0.06)

    # Charred timber corner posts
    for px in (-6.4, 6.4):
        for py, ph in ((-3.4, 9.4), (3.4, 11.2)):
            cone(wood, 0.48, 0.36, ph, 6, M((px, py, 0.4)))

    # Sloped ash-heavy cloth canopy strung over crossbeams
    box(wood, (14.4, 0.5, 0.5), M((0.0, -3.4, 9.5)), bevel=0.04)
    box(wood, (14.4, 0.5, 0.5), M((0.0, 3.4, 11.3)), bevel=0.04)
    box(foliage, (14.8, 8.6, 0.45), M((0.0, 0.0, 10.4), rot=(0.24, 0.0, 0.0)), bevel=0.06)
    # Terracotta market valance banner strip
    box(alt, (14.8, 0.35, 1.6), M((0.0, -3.8, 8.6)), bevel=0.04)

    # Stacked spice jars & merchant crates behind/on counter
    for idx, (jx, jy, jz, r) in enumerate(((-4.2, -2.0, 3.9, 0.75), (-2.6, -1.8, 3.9, 0.62), (3.8, 1.8, 0.7, 1.05))):
        uvsphere(trim if idx % 2 == 0 else alt, r, M((jx, jy, jz + r * 0.8)), u=8, v=6)
    box(wood, (3.2, 2.8, 2.4), M((3.8, -1.0, 1.8), rot=(0, 0, 0.28)), bevel=0.06)


def build_f14():
    reset_scene()
    kit = bpy.data.collections.new("AshenF14Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F14_TEMPLATES.items():
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


def export_f14(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "AshenF14Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "AshenF14Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f14()
    export_f14(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    tiles = os.path.join(preview_dir, "tiles")
    os.makedirs(tiles, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    lc = next(c for c in bpy.context.view_layer.layer_collection.children if c.collection == kit)
    lc.exclude = True
    stage = bpy.data.collections.new("PreviewStage")
    scene.collection.children.link(stage)
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    stage.objects.link(cam)
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 520
    tile_imgs = []
    for n in F14_TEMPLATES:
        c = bpy.data.collections[n]
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for o in c.objects:
            for v in o.data.vertices:
                lo = Vector(map(min, lo, v.co))
                hi = Vector(map(max, hi, v.co))
        e = bpy.data.objects.new("PreviewInstance", None)
        e.instance_type = "COLLECTION"
        e.instance_collection = c
        stage.objects.link(e)
        size = max(hi - lo)
        ctr = (lo + hi) / 2
        cam.location = ctr + Vector((0.55, -1.0, 0.42)).normalized() * size * 1.9
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        p_path = os.path.join(tiles, n + ".png")
        scene.render.filepath = p_path
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(e, do_unlink=True)
        tile_imgs.append(bpy.data.images.load(p_path))
    import numpy as np
    n_templates = len(F14_TEMPLATES)
    sheet = bpy.data.images.new("PreviewSheet", width=520 * n_templates, height=520, alpha=True)
    buf = np.zeros((520, 520 * n_templates, 4), dtype=np.float32)
    for idx, img in enumerate(tile_imgs):
        arr = np.asarray(img.pixels[:], dtype=np.float32).reshape(520, 520, 4)
        buf[:, idx * 520:(idx + 1) * 520, :] = arr
        bpy.data.images.remove(img)
    sheet.pixels.foreach_set(buf.ravel())
    sheet.filepath_raw = os.path.join(preview_dir, "kit_sheet_1.png")
    sheet.file_format = "PNG"
    sheet.save()
    bpy.data.images.remove(sheet)
    print(json.dumps(manifest, indent=2))
