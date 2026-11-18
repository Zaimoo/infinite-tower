"""
Ashen Dunes Floor 13 (Glasswind Ravine) sculpted assets, generated in headless Blender.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Outputs (assets-source/tower/ashen_f13_kit/):
    AshenF13Kit.blend     the generated scene
    AshenF13Kit.fbx       FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the 5 Floor 13 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "ashen_f13_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
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
F13_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F13_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("GlassArchSpan", STONE=2200, CRYSTAL=1400, GLOW=400)
def glass_arch_span(t):
    """Colossal jagged obsidian-basalt canyon arch fused with glowing vitrified amber-glass veins."""
    stone, crystal, glow = t.bm("STONE"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Left and right craggy arch limbs sweeping upward into an asymmetrical apex crown (~84W x 54H x 22D),
    # leaving a wide ~62W x 38H clear canyon opening underneath for decks and bridges.
    arch_pts = [
        (-40.0, 0.0, 4.2),
        (-36.5, 1.0, 14.5),
        (-28.0, 0.5, 27.0),
        (-15.5, -0.8, 41.0),
        (-2.5, 0.2, 52.0),
        (10.5, 0.8, 45.0),
        (23.5, 0.0, 32.0),
        (34.0, -0.6, 17.5),
        (40.0, 0.0, 4.2),
    ]
    stone_rads = [7.4, 7.6, 7.2, 6.8, 7.4, 6.4, 6.4, 7.4, 7.2]
    tube(stone, arch_pts, stone_rads, 7)

    # Inner vitrified amber glass core sleeve bulging asymmetrically through fractures along the soffit & flanks
    crystal_pts = [
        (-34.0, -0.4, 8.0),
        (-29.5, -1.2, 19.5),
        (-19.5, -1.5, 33.5),
        (-6.0, -0.5, 46.5),
        (6.5, -0.8, 44.5),
        (19.0, -1.2, 33.0),
        (29.5, -0.6, 19.0),
        (35.0, 0.2, 7.5),
    ]
    crystal_rads = [4.6, 5.6, 6.2, 6.5, 5.9, 5.8, 5.5, 4.4]
    tube(crystal, crystal_pts, crystal_rads, 6)

    # Heavy basalt footing boulders anchored cleanly near z = 0 (Min.Y in [-1.5, 0.0])
    for idx, (sx, sy, rot_z) in enumerate(((-40.0, 0.0, 0.3), (40.0, 0.0, -0.35), (-35.0, 4.5, 0.8), (35.5, -4.2, -0.7))):
        rock_clean(stone, (16.5, 16.0, 8.0), M((sx, sy, 3.8), rot=(0.0, 0.0, rot_z)), seed=130 + idx, roughness=0.22, subdiv=2, flat_bottom=True)

    # Jagged projecting obsidian crag spurs & molten glass shards framing the crest
    crest_spurs = [
        (-21.0, 2.5, 35.5, 0.45, (7.0, 8.5, 12.0)),
        (-6.5, -1.5, 50.0, 0.15, (8.0, 9.0, 14.0)),
        (5.5, 1.5, 49.0, -0.22, (7.5, 8.0, 13.5)),
        (21.5, -2.0, 33.5, -0.48, (6.5, 7.5, 11.5)),
    ]
    for k, (px, py, pz, tilt_y, sz) in enumerate(crest_spurs):
        rock_clean(stone, sz, M((px, py, pz), rot=(0.12 * (k % 2), tilt_y, 0.3 * k)), seed=200 + k, roughness=0.30, subdiv=2, flat_bottom=False)
        cone(crystal, 2.2, 0.15, sz[2] * 0.72, 5, M((px * 0.96, py - 2.6, pz - 3.5), rot=(0.25, tilt_y * 1.15, 0.0)))

    # Hot ember veins tucked deep along the underside throat of the arch
    glow_pts = [
        (-25.0, -0.5, 24.5),
        (-13.0, -0.8, 38.0),
        (-1.5, -0.4, 46.0),
        (11.0, -0.7, 39.5),
        (23.5, -0.5, 25.5),
    ]
    tube(glow, glow_pts, [1.5, 2.1, 2.4, 2.0, 1.4], 5)


@template("FulguriteCluster", CRYSTAL=1600, STONE=900, GLOW=400)
def fulgurite_cluster(t):
    """Fused lightning-glass organ-pipe crystal spires bursting from a cracked basalt crust."""
    crystal, stone, glow = t.bm("CRYSTAL"), t.bm("STONE"), t.bm("GLOW")

    # Flat-bottomed basalt scorch pad
    rock_clean(stone, (12.5, 12.0, 2.8), M((0.0, 0.0, 0.2)), seed=301, roughness=0.24, subdiv=2, flat_bottom=True)
    for k in range(5):
        ang = k * (math.tau / 5) + 0.3
        rock_clean(stone, (4.8, 4.4, 2.2), M((math.cos(ang) * 4.2, math.sin(ang) * 4.0, 0.1), rot=(0, 0, ang)), seed=310 + k, roughness=0.26, subdiv=1, flat_bottom=True)

    # Ring of organ-pipe crystalline fulgurite spires (base sits at z = 0.8)
    spires = [
        (0.0, 0.0, 1.25, 0.95, 14.5, 0.02, -0.03, False),
        (-1.8, 1.2, 1.08, 0.82, 12.5, 0.10, 0.12, False),
        (1.9, -0.9, 1.05, 0.80, 13.0, -0.08, -0.10, False),
        (-1.4, -1.8, 0.92, 0.70, 10.6, -0.12, 0.09, False),
        (1.6, 1.8, 0.90, 0.68, 10.0, 0.13, -0.08, False),
        (3.4, 0.4, 0.82, 0.56, 8.0, 0.05, -0.22, True),
        (-3.5, -0.3, 0.84, 0.58, 8.4, -0.06, 0.24, True),
        (0.2, 3.3, 0.78, 0.54, 7.6, 0.22, 0.04, False),
        (-0.3, -3.4, 0.76, 0.52, 7.2, -0.22, -0.05, False),
        (2.8, 2.9, 0.65, 0.40, 5.8, 0.20, -0.18, True),
        (-2.9, 2.7, 0.64, 0.38, 5.4, 0.21, 0.20, True),
        (3.1, -2.6, 0.62, 0.36, 5.2, -0.18, -0.21, True),
        (-3.0, -2.8, 0.65, 0.40, 5.9, -0.20, 0.18, True),
    ]
    for sx, sy, r0, r1, h, rx, ry, pointed in spires:
        m_pipe = M((sx, sy, 0.4), rot=(rx, ry, sx * 0.3))
        cone(crystal, r0, r1, h, 6, m_pipe)
        if pointed:
            cone(crystal, r1, 0.08, h * 0.24, 6, m_pipe @ M((0, 0, h)))

    # Warm amber core filaments inside the central tallest pipes
    for gx, gy, gh in ((0.0, 0.0, 9.0), (-1.8, 1.2, 7.4), (1.9, -0.9, 7.8)):
        cone(glow, 0.42, 0.12, gh, 5, M((gx, gy, 1.2)))


@template("RavineHorizonSpire", TRIM=1500, ALT=600, STONE=600, GLOW=250)
def ravine_horizon_spire(t):
    """Tall tapered Varrash sandstone desert beacon tower with pilaster ribs and glowing dusk lancets."""
    trim, alt, stone, glow = t.bm("TRIM"), t.bm("ALT"), t.bm("STONE"), t.bm("GLOW")

    # Stepped octagonal basalt plinth (z=0..4)
    cone(stone, 8.8, 7.8, 4.0, 8, M((0, 0, -0.1)))
    cone(alt, 7.4, 6.8, 2.0, 8, M((0, 0, 3.8)))

    # Main tapered sandstone drum tower (z=5.8..37.8)
    cone(trim, 6.4, 4.2, 32.0, 10, M((0, 0, 5.8)))
    for k in range(6):
        ang = k * (math.tau / 6)
        px = math.cos(ang) * 5.2
        py = math.sin(ang) * 5.2
        box(trim, (1.4, 1.6, 28.0), M((px, py, 19.8), rot=(0, 0, ang)), bevel=0.12)

    # Terracotta cornice belt + colonnade lantern tier + cupola cone + spire finial
    cone(alt, 5.2, 5.0, 1.8, 10, M((0, 0, 37.8)))
    for k in range(6):
        ang = k * (math.tau / 6)
        box(trim, (1.1, 1.1, 7.2), M((math.cos(ang) * 3.6, math.sin(ang) * 3.6, 42.8), rot=(0, 0, ang)), bevel=0.08)
    cone(glow, 2.5, 2.3, 6.2, 8, M((0, 0, 39.6)))
    cone(alt, 4.4, 4.8, 1.4, 10, M((0, 0, 46.2)))
    cone(trim, 4.2, 0.35, 9.6, 10, M((0, 0, 47.6)))
    cone(alt, 0.45, 0.08, 3.2, 6, M((0, 0, 57.0)))


@template("VarrashLightningRod", METAL=1300, STONE=900, CRYSTAL=700, GLOW=300)
def varrash_lightning_rod(t):
    """Forged bronze-iron lightning arrestor pylon anchored in fused glass, rimming the Lightning Scar."""
    metal, stone, crystal, glow = t.bm("METAL"), t.bm("STONE"), t.bm("CRYSTAL"), t.bm("GLOW")

    rock_clean(stone, (10.5, 10.5, 3.2), M((0, 0, 1.3)), seed=402, roughness=0.22, subdiv=2, flat_bottom=True)
    cone(stone, 4.6, 3.8, 2.6, 8, M((0, 0, 0.0)))
    for k in range(4):
        ang = k * (math.tau / 4) + 0.4
        cone(crystal, 0.9, 0.12, 4.4, 5, M((math.cos(ang) * 3.5, math.sin(ang) * 3.5, 1.2), rot=(0.28 * math.sin(ang), -0.28 * math.cos(ang), ang)))

    for k in range(3):
        ang = k * (math.tau / 3)
        cx, cy = math.cos(ang), math.sin(ang)
        tube(metal, [(cx * 3.8, cy * 3.8, 1.8), (cx * 2.2, cy * 2.2, 8.0), (cx * 0.7, cy * 0.7, 13.5)], [0.55, 0.46, 0.36], 6)

    cone(metal, 0.75, 0.25, 22.5, 8, M((0, 0, 2.4)))
    for ring_z, ring_r in ((10.5, 1.9), (14.2, 1.55), (17.8, 1.25)):
        tube(metal, [(math.cos(a) * ring_r, math.sin(a) * ring_r, ring_z) for a in [i * (math.tau / 8) for i in range(9)]], [0.28] * 9, 5)

    uvsphere(glow, 1.45, M((0, 0, 19.8)), u=10, v=6)
    # Four slender crystal insulator ribs framing the amber plasma orb
    for k in range(4):
        ca = k * (math.tau / 4)
        cone(crystal, 0.32, 0.14, 3.6, 5, M((math.cos(ca) * 1.7, math.sin(ca) * 1.7, 18.0)))
    for side in (-1, 1):
        tube(metal, [(0.0, 0.0, 22.0), (side * 1.4, 0.0, 24.4), (side * 1.8, 0.0, 27.0)], [0.26, 0.20, 0.10], 5)
    cone(metal, 0.28, 0.04, 5.2, 6, M((0, 0, 24.5)))


@template("GlassCactusCluster", FOLIAGE=1400, ALT=500, STONE=600, MOSS=400)
def glass_cactus_cluster(t):
    """Desert ribbed barrel and prickly-column cacti topped with bright amber blooms."""
    foliage, alt, stone, moss = t.bm("FOLIAGE"), t.bm("ALT"), t.bm("STONE"), t.bm("MOSS")

    rock_clean(moss, (9.5, 8.6, 1.8), M((0, 0, 0.05)), seed=505, roughness=0.16, subdiv=2, flat_bottom=True)
    for k in range(3):
        ang = k * 2.1 + 0.4
        rock_clean(stone, (3.8, 3.2, 1.8), M((math.cos(ang) * 2.8, math.sin(ang) * 2.4, 0.05)), seed=510 + k, roughness=0.25, subdiv=1, flat_bottom=True)

    bodies = [
        (0.0, 0.2, 1.45, 6.2, 0.0, 0.0),
        (-2.1, -1.0, 1.25, 3.4, -0.14, 0.16),
        (2.0, -1.1, 1.15, 2.8, -0.12, -0.18),
        (0.6, 2.1, 0.95, 2.2, 0.16, -0.10),
    ]
    for bx, by, brad, bh, rx, ry in bodies:
        m_body = M((bx, by, 0.4), rot=(rx, ry, 0))
        cone(foliage, brad * 0.92, brad * 0.88, bh, 10, m_body)
        uvsphere(foliage, brad * 0.88, m_body @ M((0, 0, bh)), u=10, v=6)
        for rib_i in range(8):
            ra = rib_i * (math.tau / 8)
            box(foliage, (brad * 0.16, brad * 0.28, bh * 0.86), m_body @ M((math.cos(ra) * brad * 0.88, math.sin(ra) * brad * 0.88, bh * 0.45), rot=(0, 0, ra)), bevel=0.04)
        m_bloom = m_body @ M((0, 0, bh + brad * 0.72))
        cone(alt, brad * 0.22, brad * 0.52, brad * 0.55, 7, m_bloom)
        uvsphere(alt, brad * 0.30, m_bloom @ M((0.25, -0.15, brad * 0.4)), u=7, v=4)


def build_f13():
    reset_scene()
    kit = bpy.data.collections.new("AshenF13Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F13_TEMPLATES.items():
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


def export_f13(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "AshenF13Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "AshenF13Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f13()
    export_f13(kit, manifest)
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
    for n in F13_TEMPLATES:
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
    n_templates = len(F13_TEMPLATES)
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
