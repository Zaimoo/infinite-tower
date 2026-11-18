"""
Frozen Citadel Floor 17 (Frozen Barracks) sculpted assets, generated in headless Blender
inspired by media_1795013043673_6f636e12.jpg (steep granite barracks with snow drifts & icicles,
frozen drill company in ice, iron ice braziers, kennel cages with frozen chains, and boiled soup cauldron).

1 Blender unit = 1 stud, standing on z = 0 (with -1.2 footing), front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>".

Outputs (assets-source/tower/frozen_f17_kit/):
    FrozenF17Kit.blend    the generated scene
    FrozenF17Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the Floor 17 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "frozen_f17_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
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
F17_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F17_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("BarracksBlock", STONE=1400, MOSS=800, WOOD=500, METAL=500, CRYSTAL=500, TRIM=260, GLOW=120)
def barracks_block(t):
    """Granite Whiteguard garrison barracks with buttresses, drifted slate gable roof, eaves icicles, banners, and weapon racks."""
    stone, moss, wood, metal, crystal, trim, glow = (
        t.bm("STONE"), t.bm("MOSS"), t.bm("WOOD"), t.bm("METAL"), t.bm("CRYSTAL"), t.bm("TRIM"), t.bm("GLOW")
    )

    # 1. Coursed stone hall body + deeper -1.2 granite plinth footing (no gaps on slopes)
    box(stone, (34.0, 22.0, 2.8), Matrix.Translation((0, 0, 0.2)))
    box(stone, (32.0, 20.0, 12.0), Matrix.Translation((0, 0, 7.6)))

    # Corner & side buttress piers along front (-Y) and sides
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(stone, (3.2, 3.2, 14.4), Matrix.Translation((sx * 15.6, sy * 9.8, 6.2)))
    for bx in (-6.0, 6.0):
        box(stone, (2.6, 2.2, 13.8), Matrix.Translation((bx, -10.1, 6.1)))

    # 2. Front (-Y) projecting stone entry porch with arched doorway, oak door, banner & warm windows
    box(stone, (9.6, 3.0, 13.2), Matrix.Translation((0, -10.8, 6.0)))
    box(wood, (4.4, 0.7, 7.6), Matrix.Translation((0, -12.1, 4.6)))
    box(metal, (4.8, 0.4, 0.55), Matrix.Translation((0, -12.35, 3.2)))
    box(metal, (4.8, 0.4, 0.55), Matrix.Translation((0, -12.35, 6.2)))
    # Hanging Whiteguard snowflake banner on front gable porch & flanking lancet windows
    box(trim, (2.6, 0.35, 5.2), Matrix.Translation((0, -12.45, 11.4)))
    box(wood, (3.2, 0.5, 0.45), Matrix.Translation((0, -12.4, 14.1)))
    for wx in (-10.8, 10.8):
        box(glow, (2.4, 0.45, 3.8), Matrix.Translation((wx, -10.1, 7.2)))
        box(stone, (3.1, 0.65, 0.5), Matrix.Translation((wx, -10.2, 5.1)))
        box(stone, (3.1, 0.65, 0.5), Matrix.Translation((wx, -10.2, 9.3)))

    # 3. Steep gable infill + slate roof slopes + heavy north-drifted snow blanket + hanging icicles
    for sy in (-9.6, 9.6):
        for step in range(5):
            gw = 29.0 - step * 5.2
            gz = 14.6 + step * 1.9
            box(stone, (gw, 1.4, 2.1), Matrix.Translation((0, sy, gz)))
    pitch = math.radians(36)
    for sx in (-1, 1):
        tilt = pitch * sx
        box(stone, (21.5, 24.4, 1.1), Matrix.Translation((sx * 8.6, 0, 18.6)) @ Matrix.Rotation(tilt, 4, "Y"))
        # Heavier snow drift on the north/right slope & lighter drift on the south/left slope
        snow_thick = 1.65 if sx > 0 else 1.1
        snow_w = 19.8 if sx > 0 else 16.0
        box(moss, (snow_w, 24.2, snow_thick), Matrix.Translation((sx * 8.6, 0, 19.6)) @ Matrix.Rotation(tilt, 4, "Y"))
        # Hanging eave icicles along both outer roof edges
        for k in range(-4, 5):
            ex = sx * 17.6
            ey = k * 2.5
            ic_len = 2.6 + (abs(k) % 3) * 0.9
            tapered_limb(crystal, (ex, ey, 12.8), (ex, ey, 12.8 - ic_len), 0.34, 0.04, segs=5)
    box(moss, (3.2, 24.2, 1.4), Matrix.Translation((0, 0, 24.8)))
    # Stone chimney rising out of roof shoulder
    box(stone, (3.4, 3.4, 9.0), Matrix.Translation((-8.5, 4.5, 22.8)))
    box(moss, (3.8, 3.8, 0.9), Matrix.Translation((-8.5, 4.5, 27.6)))

    # 4. Leaning spears & heater shields weapon rack beside left & right front bays
    for wx_base in (-10.6, 10.6):
        box(wood, (6.2, 1.2, 0.5), Matrix.Translation((wx_base, -11.0, 4.6)))
        for s_idx in range(-2, 3):
            px = wx_base + s_idx * 1.15
            tapered_limb(metal, (px, -11.6, 1.0), (px, -10.8, 7.6), 0.14, 0.08, segs=5)
        for sh_off in (-1.6, 1.6):
            box(metal, (1.8, 0.4, 2.8), Matrix.Translation((wx_base + sh_off, -11.4, 2.6)) @ Matrix.Rotation(math.radians(-12), 4, "X"))


@template("FrozenSoldier", CRYSTAL=700, METAL=550, STONE=350)
def frozen_soldier(t):
    """Armored Whiteguard spearman sealed mid-march inside a jagged pale-blue ice column."""
    crystal, metal, stone = t.bm("CRYSTAL"), t.bm("METAL"), t.bm("STONE")

    # Frozen snow/stone pad at feet
    rock_clean(stone, (4.0, 3.8, 1.2), Matrix.Translation((0, 0, 0.1)), seed=501, roughness=0.16, subdiv=1)

    # Armored soldier silhouette inside the ice (legs, breastplate, pauldrons, helm, heater shield, vertical pike)
    for sx in (-0.5, 0.5):
        tapered_limb(metal, (sx, sx * 0.25, 0.5), (sx, -sx * 0.15, 3.0), 0.36, 0.32, segs=6)
    box(metal, (1.8, 1.05, 2.2), Matrix.Translation((0, 0, 4.1)))
    for sx in (-1, 1):
        uvsphere(metal, 0.52, Matrix.Translation((sx * 1.15, 0, 4.9)), 6, 4)
    uvsphere(metal, 0.62, Matrix.Translation((0, 0, 5.85)), 7, 5)
    # Left-side heater shield & right-side raised spear/halberd
    box(metal, (0.35, 2.1, 2.8), Matrix.Translation((-1.2, -0.4, 3.9)) @ Matrix.Rotation(math.radians(15), 4, "Z"))
    tapered_limb(metal, (1.25, -0.3, 0.6), (1.25, -0.5, 7.8), 0.13, 0.10, segs=5)
    cone(metal, 0.24, 0.02, 1.0, 4, Matrix.Translation((1.25, -0.5, 7.8)))

    # Encasing jagged clear-ice block & jutting crystal shoulder shards
    rock_clean(crystal, (3.6, 3.2, 6.9), Matrix.Translation((0, -0.1, 3.5)), seed=511, roughness=0.20, subdiv=2)
    tapered_limb(crystal, (-0.9, 0.5, 0.4), (-1.4, 0.9, 5.4), 0.65, 0.16, segs=5)
    tapered_limb(crystal, (1.0, 0.4, 0.5), (1.45, 0.8, 6.2), 0.55, 0.14, segs=5)


@template("KennelRow", STONE=500, WOOD=600, METAL=650, MOSS=450, CRYSTAL=400)
def kennel_row(t):
    """East Barracks hound kennel run with stone back wall, snow shed roof, iron cage bars, and frozen chains mid-swing."""
    stone, wood, metal, moss, crystal = t.bm("STONE"), t.bm("WOOD"), t.bm("METAL"), t.bm("MOSS"), t.bm("CRYSTAL")

    # Stone footing & low kennel walls
    box(stone, (22.0, 10.8, 1.8), Matrix.Translation((0, 0, 0.1)))
    box(stone, (21.0, 1.6, 8.2), Matrix.Translation((0, 4.4, 4.6)))
    for sx in (-10.0, -3.3, 3.3, 10.0):
        box(stone, (1.4, 9.6, 7.8), Matrix.Translation((sx, 0, 4.5)))

    # Iron cage fronts (3 bays) with heavy vertical bars & horizontal latch beams
    for bay_x in (-6.65, 0.0, 6.65):
        box(metal, (5.4, 0.4, 0.45), Matrix.Translation((bay_x, -4.4, 1.4)))
        box(metal, (5.4, 0.4, 0.45), Matrix.Translation((bay_x, -4.4, 6.8)))
        for k in range(-2, 3):
            tapered_limb(metal, (bay_x + k * 1.1, -4.4, 1.2), (bay_x + k * 1.1, -4.4, 7.0), 0.12, 0.12, segs=5)

    # Sloped timber shed roof + thick drifted snow + eaves icicles
    pitch = math.radians(-16)
    box(wood, (22.8, 11.8, 0.7), Matrix.Translation((0, -0.1, 9.0)) @ Matrix.Rotation(pitch, 4, "X"))
    box(moss, (22.4, 11.4, 1.1), Matrix.Translation((0, -0.1, 9.8)) @ Matrix.Rotation(pitch, 4, "X"))
    for k in range(-4, 5):
        tapered_limb(crystal, (k * 2.4, -5.6, 7.4), (k * 2.4, -5.6, 5.4 - (abs(k) % 2) * 0.6), 0.24, 0.04, segs=5)

    # Timber hitching post & two iron chains frozen curved mid-swing
    tapered_limb(wood, (-12.5, -3.5, 0.0), (-12.5, -3.5, 5.8), 0.45, 0.38, segs=6)
    for c_idx, end_x in enumerate((-8.8, -15.4)):
        p0 = Vector((-12.5, -3.5, 4.8 - c_idx * 0.7))
        p1 = Vector(((p0.x + end_x) * 0.5, -3.8 - c_idx * 0.6, 3.2))
        p2 = Vector((end_x, -4.2, 3.8))
        tapered_limb(metal, p0, p1, 0.16, 0.16, segs=5)
        tapered_limb(metal, p1, p2, 0.16, 0.14, segs=5)
        rock_clean(crystal, (1.1, 1.1, 1.1), Matrix.Translation(p2), seed=620 + c_idx, roughness=0.22, subdiv=1)


@template("IceBrazier", METAL=450, WOOD=180, CRYSTAL=500, GLOW=160)
def ice_brazier(t):
    """Wrought-iron garrison street brazier whose fire has frozen into jagged blue ice crystal shards."""
    metal, wood, crystal, glow = t.bm("METAL"), t.bm("WOOD"), t.bm("CRYSTAL"), t.bm("GLOW")

    box(metal, (3.2, 3.2, 0.6), Matrix.Translation((0, 0, 0.3)))
    for a_deg in (45, 135, 225, 315):
        a = math.radians(a_deg)
        p0 = (math.cos(a) * 1.2, math.sin(a) * 1.2, 0.4)
        p1 = (math.cos(a) * 1.7, math.sin(a) * 1.7, 3.4)
        tapered_limb(metal, p0, p1, 0.22, 0.18, segs=5)
    cone(metal, 1.35, 2.05, 1.6, 8, Matrix.Translation((0, 0, 2.5)))
    for k in range(6):
        ang = k * math.pi / 3.0
        bx, by = math.cos(ang) * 1.85, math.sin(ang) * 1.85
        tapered_limb(metal, (bx, by, 3.3), (bx * 1.08, by * 1.08, 4.5), 0.14, 0.10, segs=5)
    box(wood, (2.2, 2.2, 0.7), Matrix.Translation((0, 0, 3.6)))
    # Crystal heart + frozen jagged flame tongues
    uvsphere(glow, 0.95, Matrix.Translation((0, 0, 4.35)), 6, 5)
    for k in range(5):
        ang = k * math.pi * 2.0 / 5.0
        ox, oy = math.cos(ang) * 0.75, math.sin(ang) * 0.75
        tapered_limb(crystal, (ox * 0.6, oy * 0.6, 3.9), (ox * 1.25, oy * 1.25, 5.9 + (k % 2) * 0.7), 0.48, 0.06, segs=5)
    tapered_limb(crystal, (0, 0, 4.0), (0, 0, 6.7), 0.56, 0.05, segs=5)


@template("MessCauldron", METAL=700, STONE=450, CRYSTAL=600, MOSS=350)
def mess_cauldron(t):
    """Mess Hall iron soup cauldron frozen mid-boil with a crown of pale-blue ice bubbles and protruding ladle."""
    metal, stone, crystal, moss = t.bm("METAL"), t.bm("STONE"), t.bm("CRYSTAL"), t.bm("MOSS")

    # Hearth stone ring & drifted snow apron
    rock_clean(moss, (8.6, 8.6, 0.9), Matrix.Translation((0, 0, 0.1)), seed=701, roughness=0.14, subdiv=1)
    for k in range(8):
        ang = k * math.pi / 4.0
        rock_clean(stone, (1.8, 1.5, 1.3), Matrix.Translation((math.cos(ang) * 3.1, math.sin(ang) * 3.1, 0.6)), seed=710 + k, roughness=0.22, subdiv=1)

    # Riveted iron cauldron belly & rim
    cone(metal, 2.1, 3.1, 2.6, 12, Matrix.Translation((0, 0, 1.2)))
    cone(metal, 3.1, 2.65, 1.6, 12, Matrix.Translation((0, 0, 3.8)))
    cone(metal, 2.95, 2.95, 0.45, 12, Matrix.Translation((0, 0, 5.15)))

    # Frozen soup surface + crown of ice bubbles & splashing spikes fused mid-boil + ladle sticking out
    cone(crystal, 2.55, 2.55, 0.35, 10, Matrix.Translation((0, 0, 5.1)))
    bubbles = [
        (0.0, 0.0, 5.4, 0.95), (-1.1, 0.7, 5.35, 0.72), (1.15, -0.5, 5.38, 0.68),
        (0.5, 1.25, 5.3, 0.62), (-0.8, -1.15, 5.3, 0.58), (1.5, 0.85, 5.25, 0.48),
    ]
    for bx, by, bz, br in bubbles:
        uvsphere(crystal, br, Matrix.Translation((bx, by, bz)), 7, 5)
    tapered_limb(crystal, (1.8, 0.2, 5.1), (2.4, 0.3, 6.6), 0.35, 0.05, segs=5)
    tapered_limb(metal, (-0.4, -0.2, 4.9), (-2.6, -2.1, 7.1), 0.14, 0.16, segs=5)


def build_f17():
    reset_scene()

    kit = bpy.data.collections.new("FrozenF17Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F17_TEMPLATES.items():
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


def export_f17(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FrozenF17Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FrozenF17Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f17()
    export_f17(kit, manifest)
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
    for n in F17_TEMPLATES:
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
    n_templates = len(F17_TEMPLATES)
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
