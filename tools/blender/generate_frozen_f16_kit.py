"""
Frozen Citadel Floor 16 (Rimefall Approach) sculpted assets, generated in headless Blender
inspired by media_1795004738725_8fee07e8.jpg (Rimefall, Hunters' Lodge, Fisher's Hut,
Ice Floes, and the Ward-Star Shield waymarker).

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>".

Outputs (assets-source/tower/frozen_f16_kit/):
    FrozenF16Kit.blend    the generated scene
    FrozenF16Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the Floor 16 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "frozen_f16_kit")

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
F16_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F16_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("RimefallIcefall", STONE=2200, MOSS=1200, CRYSTAL=2400, GLOW=450)
def rimefall_icefall(t):
    """Towering Rimefall: craggy granite gorge flanking an immense frozen waterfall with hanging icicle curtains and internal blue glow."""
    stone, moss, crystal, glow = t.bm("STONE"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Left and right flanking granite gorge cliffs
    flanks = [
        (-28, 3, 24, (28, 22, 58), 11),
        (-36, 6, 14, (22, 20, 42), 12),
        (28, 3, 24, (28, 22, 58), 13),
        (36, 6, 14, (22, 20, 42), 14),
        (0, 12, 26, (44, 18, 62), 15),
    ]
    for cx, cy, cz, sz, sd in flanks:
        rock_clean(stone, sz, Matrix.Translation((cx, cy, cz)), seed=sd, roughness=0.22, subdiv=2)
        # Snow drift caps perched on cliff shoulders
        rock_clean(moss, (sz[0] * 0.88, sz[1] * 0.78, 6.5), Matrix.Translation((cx, cy - 1.5, cz + sz[2] * 0.45)), seed=sd + 40, roughness=0.16, subdiv=2)

    # Central sculpted frozen cascade wall and foaming ice dome at base
    rock_clean(crystal, (34, 14, 54), Matrix.Translation((0, 0, 23)), seed=201, roughness=0.15, subdiv=2)
    rock_clean(crystal, (42, 16, 14), Matrix.Translation((0, -4, 3)), seed=202, roughness=0.18, subdiv=2)
    rock_clean(moss, (26, 12, 7), Matrix.Translation((-10, -5, 0.2)), seed=203, roughness=0.15, subdiv=2)
    rock_clean(moss, (24, 12, 6.5), Matrix.Translation((12, -5, -0.2)), seed=204, roughness=0.15, subdiv=2)

    # Tiered cascading frozen ribs & curtain columns across -22..+22
    for idx in range(13):
        u = (idx - 6) / 6.0
        x = u * 22.0
        y = -5.5 + abs(u) * 3.5 + ((idx % 2) - 0.5) * 1.8
        top_z = 54.0 - abs(u) * 8.0 + (idx % 3) * 2.5
        bot_z = 2.0 + (idx % 2) * 3.0
        tapered_limb(crystal, (x, y, top_z), (x, y - 1.6, bot_z), 3.4 - abs(u) * 0.9, 2.2, segs=7)

    # Sharp hanging icicle teeth along upper waterfall lip and flank ledges
    for idx in range(18):
        u = (idx - 8.5) / 8.5
        x = u * 29.0
        y = -6.8 + abs(u) * 3.0
        top_z = 51.0 - abs(u) * 9.0
        drop = 12.0 + ((idx * 7) % 15)
        tapered_limb(crystal, (x, y, top_z), (x, y - 0.3, top_z - drop), 1.65, 0.18, segs=6)

    # Internal Rimelight glacier glow shafts radiating from inside the frozen cascade
    for gx, gy, gz, rad, h in [
        (0, -1.5, 26, 4.2, 42),
        (-9, -0.5, 24, 2.4, 34),
        (9, -0.5, 24, 2.4, 34),
    ]:
        tapered_limb(glow, (gx, gy, gz - h * 0.5), (gx, gy, gz + h * 0.5), rad, rad * 0.72, segs=8)


@template("HuntersLodge", STONE=900, WOOD=1400, TRIM=350, MOSS=1000, GLOW=120)
def hunters_lodge(t):
    """Alpine timber-and-granite Hunters' Lodge with steep snow-laden gable roof, eaves icicles, antler mount, and drying rack."""
    stone, wood, trim, moss, glow = t.bm("STONE"), t.bm("WOOD"), t.bm("TRIM"), t.bm("MOSS"), t.bm("GLOW")

    # Granite plinth & chimney
    box(stone, (22, 18, 3.2), Matrix.Translation((0, 0, 1.6)))
    box(stone, (3.6, 3.6, 20), Matrix.Translation((-7.5, 5.5, 10)))
    box(moss, (4.2, 4.2, 1.1), Matrix.Translation((-7.5, 5.5, 20.3)))

    # Main log walls
    box(wood, (20, 16, 8.8), Matrix.Translation((0, 0, 7.6)))

    # Corner timber posts & front gable beams
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(wood, (1.1, 1.1, 9.6), Matrix.Translation((sx * 9.8, sy * 7.8, 7.8)))

    # Steep pitched A-frame roof slopes (^+ peak at x=0, eaves down at +-X) + thick snow layer
    pitch = math.radians(38)
    for sx in (-1, 1):
        tilt = pitch * sx
        rmat = Matrix.Translation((sx * 5.6, 0, 15.2)) @ Matrix.Rotation(tilt, 4, "Y")
        box(wood, (14.8, 19.6, 0.9), rmat)
        smat = Matrix.Translation((sx * 5.6, 0, 16.05)) @ Matrix.Rotation(tilt, 4, "Y")
        box(moss, (14.4, 19.4, 1.1), smat)
        # Hanging icicles along side eaves
        for k in range(-3, 4):
            ex = sx * 11.2
            ey = k * 2.4
            tapered_limb(trim, (ex, ey, 11.0), (ex, ey, 9.2 - (k % 2) * 0.7), 0.24, 0.04, segs=5)
    # Snow ridge cap along peak
    box(moss, (2.4, 19.4, 1.2), Matrix.Translation((0, 0, 20.1)))

    # Gable triangle infills (front -Y and back +Y)
    for sy in (-1, 1):
        for step in range(4):
            w = 17.0 - step * 3.8
            z = 12.6 + step * 1.9
            box(wood, (w, 0.7, 2.0), Matrix.Translation((0, sy * 7.85, z)))

    # Front porch overhang, plank door, glowing frost-paned windows & antler mount
    box(stone, (7.6, 4.2, 2.8), Matrix.Translation((0, -10.2, 1.4)))
    box(wood, (3.2, 0.5, 6.0), Matrix.Translation((0, -8.1, 6.2)))
    box(glow, (2.2, 0.45, 2.6), Matrix.Translation((-5.2, -8.1, 7.6)))
    box(glow, (2.2, 0.45, 2.6), Matrix.Translation((5.2, -8.1, 7.6)))
    # Stag skull + branched antlers above doorway
    uvsphere(trim, 0.9, Matrix.Translation((0, -8.6, 12.2)), 6, 4)
    for sx in (-1, 1):
        p0 = (sx * 0.4, -8.7, 12.6)
        p1 = (sx * 2.2, -9.2, 14.4)
        p2 = (sx * 3.4, -9.0, 16.2)
        tapered_limb(trim, p0, p1, 0.26, 0.16, segs=5)
        tapered_limb(trim, p1, p2, 0.16, 0.08, segs=5)
        tapered_limb(trim, p1, (sx * 1.8, -9.5, 16.0), 0.14, 0.06, segs=5)

    # Wooden hide/game drying rack beside right wall
    rx = 14.5
    for sy in (-3.2, 3.2):
        tapered_limb(wood, (rx - 1.4, sy, 0.4), (rx, sy, 6.0), 0.28, 0.22, segs=5)
        tapered_limb(wood, (rx + 1.4, sy, 0.4), (rx, sy, 6.0), 0.28, 0.22, segs=5)
    tapered_limb(wood, (rx, -4.0, 5.7), (rx, 4.0, 5.7), 0.25, 0.25, segs=5)


@template("FisherHut", STONE=450, WOOD=1200, ALT=350, MOSS=700, GLOW=90)
def fisher_hut(t):
    """Compact lakeside Ice-Fisher's Hut with snow roof, net drying frame, and beached wooden skiffs."""
    stone, wood, alt, moss, glow = t.bm("STONE"), t.bm("WOOD"), t.bm("ALT"), t.bm("MOSS"), t.bm("GLOW")

    # Timber shack on stone pilings
    for sx in (-4.8, 4.8):
        for sy in (-3.8, 3.8):
            box(stone, (1.4, 1.4, 2.2), Matrix.Translation((sx, sy, 1.1)))
    box(wood, (11.2, 9.2, 0.8), Matrix.Translation((0, 0, 2.4)))
    box(wood, (10.4, 8.4, 5.8), Matrix.Translation((0, 0, 5.5)))
    box(wood, (2.4, 0.4, 4.8), Matrix.Translation((-2.0, -4.3, 4.8)))
    box(glow, (1.8, 0.4, 1.8), Matrix.Translation((2.4, -4.3, 5.4)))

    # Gable roof (^+ A-frame) + drifted snow
    pitch = math.radians(32)
    for sx in (-1, 1):
        tilt = pitch * sx
        box(wood, (7.6, 10.6, 0.7), Matrix.Translation((sx * 3.0, 0, 9.9)) @ Matrix.Rotation(tilt, 4, "Y"))
        box(moss, (7.3, 10.5, 0.9), Matrix.Translation((sx * 3.0, 0, 10.6)) @ Matrix.Rotation(tilt, 4, "Y"))
    box(moss, (1.8, 10.5, 0.9), Matrix.Translation((0, 0, 12.6)))

    # Frozen net drying rack on left shore
    for sy in (-3.2, 3.2):
        tapered_limb(wood, (-9.0, sy, 0.0), (-9.0, sy, 5.6), 0.25, 0.2, segs=5)
    tapered_limb(wood, (-9.0, -3.6, 5.4), (-9.0, 3.6, 5.4), 0.22, 0.22, segs=5)
    box(alt, (0.25, 5.6, 3.4), Matrix.Translation((-9.0, 0, 3.6)))

    # Beached wooden rowboat resting beside the hut (+X shore)
    bx = 9.4
    box(wood, (3.2, 8.8, 1.1), Matrix.Translation((bx, -1.0, 0.7)) @ Matrix.Rotation(math.radians(-14), 4, "Z"))
    for sx in (-1, 1):
        box(wood, (0.4, 8.4, 1.3), Matrix.Translation((bx + sx * 1.45, -1.0, 1.3)) @ Matrix.Rotation(math.radians(sx * 16), 4, "Y") @ Matrix.Rotation(math.radians(-14), 4, "Z"))
    box(alt, (2.6, 0.7, 0.35), Matrix.Translation((bx, -1.0, 1.55)) @ Matrix.Rotation(math.radians(-14), 4, "Z"))


@template("IceFloeSlab", CRYSTAL=1100, MOSS=900, STONE=500)
def ice_floe_slab(t):
    """Jagged lake ice floe slab with translucent undercut glacier rim and thick snow drift cap."""
    crystal, moss, stone = t.bm("CRYSTAL"), t.bm("MOSS"), t.bm("STONE")

    rock_clean(crystal, (24, 20, 4.4), Matrix.Translation((0, 0, 0.2)), seed=301, roughness=0.16, subdiv=2)
    rock_clean(crystal, (15, 13, 3.4), Matrix.Translation((-5.5, 3.0, 0.5)), seed=302, roughness=0.18, subdiv=2)
    rock_clean(moss, (21, 17, 2.6), Matrix.Translation((0.5, -0.5, 2.5)), seed=303, roughness=0.12, subdiv=2)
    # Small frozen shoreline stone cairn accent (inspired by Heart Floe cairn)
    for idx, r in enumerate((1.5, 1.15, 0.85, 0.55)):
        rock_clean(stone, (r * 2.1, r * 1.9, r * 1.1), Matrix.Translation((0, 0, 3.8 + idx * 0.85)), seed=310 + idx, roughness=0.2, subdiv=1)


@template("WardStarShieldMarker", STONE=700, METAL=500, CRYSTAL=500, MOSS=450)
def ward_star_shield_marker(t):
    """Whiteguard granite-and-iron heater shield with six-pointed snowflake ward-star relief planted tilted in snow."""
    stone, metal, crystal, moss = t.bm("STONE"), t.bm("METAL"), t.bm("CRYSTAL"), t.bm("MOSS")

    # Snowdrift base mound
    rock_clean(moss, (8.8, 5.8, 2.4), Matrix.Translation((0, 0.2, 0.0)), seed=401, roughness=0.14, subdiv=2)

    # Tilted heater shield body + iron rim + 6-pointed snowflake ward-star relief
    sh_mat = Matrix.Translation((0, 0, 4.6)) @ Matrix.Rotation(math.radians(-12), 4, "X") @ Matrix.Rotation(math.radians(8), 4, "Z")
    # Upper rectangular shield plate & tapered lower heater tip
    box(stone, (5.8, 1.1, 4.2), sh_mat @ Matrix.Translation((0, 0, 1.2)))
    box(stone, (4.0, 1.05, 3.2), sh_mat @ Matrix.Translation((0, 0, -1.6)) @ Matrix.Rotation(math.radians(45), 4, "Y"))
    # Iron edge border bands & studs
    box(metal, (6.2, 1.25, 0.6), sh_mat @ Matrix.Translation((0, 0, 3.2)))
    for sx in (-1, 1):
        box(metal, (0.55, 1.25, 4.6), sh_mat @ Matrix.Translation((sx * 2.9, 0, 1.0)))
        box(metal, (0.55, 1.22, 3.6), sh_mat @ Matrix.Translation((sx * 1.5, 0, -2.0)) @ Matrix.Rotation(math.radians(sx * -38), 4, "Y"))

    # Six-pointed snowflake ward-star relief proud on the front face (-Y local)
    for k in range(3):
        ang = math.radians(k * 60.0)
        arm_mat = sh_mat @ Matrix.Translation((0, -0.62, 0.4)) @ Matrix.Rotation(ang, 4, "Y")
        box(crystal, (0.48, 0.45, 4.2), arm_mat)
        for sz in (-1, 1):
            for sside in (-1, 1):
                branch = arm_mat @ Matrix.Translation((sside * 0.45, 0, sz * 1.25)) @ Matrix.Rotation(math.radians(sside * sz * 45), 4, "Y")
                box(crystal, (0.34, 0.36, 1.1), branch)
    uvsphere(crystal, 0.65, sh_mat @ Matrix.Translation((0, -0.65, 0.4)), 6, 4)


def build_f16():
    reset_scene()

    kit = bpy.data.collections.new("FrozenF16Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F16_TEMPLATES.items():
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


def export_f16(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FrozenF16Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FrozenF16Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f16()
    export_f16(kit, manifest)
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
    for n in F16_TEMPLATES:
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
    n_templates = len(F16_TEMPLATES)
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
