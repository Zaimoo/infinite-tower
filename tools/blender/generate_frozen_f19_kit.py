"""
Frozen Citadel Floor 19 (Whiteguard Keep) sculpted assets, generated in headless Blender
inspired by media_1795019331333_68aeacfe.jpg (outer glacier cave overhangs with icicles & rimelight,
glowing turquoise rimelight crystal clusters, Whiteguard round battlement tower with frozen banner,
assault siege ladder frozen against gatehouse wall, and heavy siege trebuchet halted in frost).

1 Blender unit = 1 stud, standing on z = 0 (with -1.0 footing), front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>".

Outputs (assets-source/tower/frozen_f19_kit/):
    FrozenF19Kit.blend    the generated scene
    FrozenF19Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the Floor 19 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "frozen_f19_kit")

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
F19_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F19_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("IceCaveOverhang", STONE=1200, MOSS=650, CRYSTAL=700, GLOW=220)
def ice_cave_overhang(t):
    """Outer rocky cavern arch & high cliff overhang (>=20 studs clear underside) fringed with icicles and rimelight."""
    stone, moss, crystal, glow = t.bm("STONE"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Twin heavy craggy cliff buttress piers on outer rock side (-X) & ends (+-Y) supporting high arch brow
    for sy, sd in ((-9.5, 11), (9.5, 12)):
        rock_clean(stone, (8.4, 7.6, 22.0), Matrix.Translation((-3.6, sy, 10.2)), seed=sd, roughness=0.22)
        rock_clean(stone, (7.0, 6.4, 12.0), Matrix.Translation((-5.2, sy * 0.72, 5.2)), seed=sd + 10, roughness=0.20)
    rock_clean(stone, (9.0, 26.0, 7.5), Matrix.Translation((-4.2, 0.0, 22.8)), seed=19, roughness=0.22)
    # High projecting brow canopy leaning inward (+X) over cave rim (>= 20 studs above floor)
    rock_clean(stone, (12.5, 25.0, 5.2), Matrix.Translation((1.6, 0.0, 23.6)) @ Matrix.Rotation(math.radians(8), 4, "Y"), seed=23, roughness=0.20)

    # Drifted alpine snow blanket crowning the top of the overhang
    rock_clean(moss, (14.2, 24.4, 3.4), Matrix.Translation((0.2, 0.0, 25.6)), seed=31, roughness=0.18)

    # Hanging icicle curtain fringe along the inner +X lip (tips stop cleanly >= 18.5 studs above z=0)
    for iy in (-9.6, -7.0, -4.4, -1.8, 0.8, 3.4, 6.0, 8.6):
        ln = 3.2 + (abs(int(iy * 3)) % 3) * 1.1
        tapered_limb(crystal, (6.2, iy, 22.2), (6.1, iy, 22.2 - ln), 0.52, 0.05, segs=5)
    # Ice pillars hugging inner rock wall buttresses
    for py, ph in ((-8.8, 18.0), (8.8, 19.0)):
        tapered_limb(crystal, (-1.8, py, -0.4), (-1.4, py, ph), 1.4, 0.45, segs=6)

    # Embedded glowing rimelight crystals inside pier recesses
    for gy, gz, yaw in ((-5.8, 6.5, 0.3), (-5.2, 12.0, -0.4), (5.6, 7.2, 0.2), (5.0, 13.4, -0.3)):
        tapered_limb(glow, (-2.6, gy, gz), (0.8, gy + math.sin(yaw) * 1.6, gz + 3.2), 0.72, 0.08, segs=5)


@template("RimelightCrystalCluster", STONE=420, MOSS=220, CRYSTAL=500, GLOW=700)
def rimelight_crystal_cluster(t):
    """Splayed cluster of glowing hexagonal rimelight crystal spears bursting from fractured frost rock."""
    stone, moss, crystal, glow = t.bm("STONE"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("GLOW")

    # Grounded dark basalt/granite collar + frost snow crust
    rock_clean(stone, (8.6, 8.2, 2.8), Matrix.Translation((0.0, 0.0, 0.6)), seed=51, roughness=0.25)
    rock_clean(moss, (9.4, 8.8, 1.8), Matrix.Translation((0.2, 0.3, 1.2)), seed=55, roughness=0.18)

    # Main splayed bright glowing rimelight spears (hexagonal crystals)
    glow_spears = (
        ((0.0, 0.0, 0.8), (0.6, -0.8, 14.8), 1.45, 0.14),
        ((-1.6, 0.6, 0.8), (-4.2, -1.6, 11.6), 1.15, 0.12),
        ((1.8, -0.4, 0.8), (4.4, -2.0, 10.8), 1.10, 0.11),
        ((0.4, 1.6, 0.8), (1.4, 3.8, 9.6), 0.95, 0.10),
        ((-1.2, -1.8, 0.8), (-3.0, -4.4, 8.2), 0.85, 0.09),
    )
    for p0, p1, r0, r1 in glow_spears:
        tapered_limb(glow, p0, p1, r0, r1, segs=6)

    # Secondary translucent pale-blue ice crystal shards framing the glowing core
    ice_spears = (
        ((-2.6, 1.4, 0.4), (-5.4, 2.6, 6.8), 0.85, 0.08),
        ((2.6, 1.2, 0.4), (5.2, 2.8, 7.2), 0.82, 0.08),
        ((1.2, -2.2, 0.4), (2.4, -5.0, 6.0), 0.72, 0.07),
    )
    for p0, p1, r0, r1 in ice_spears:
        tapered_limb(crystal, p0, p1, r0, r1, segs=5)


@template("WhiteguardTower", STONE=1400, TRIM=450, MOSS=450, CRYSTAL=400, METAL=240, ALT=320, GLOW=160)
def whiteguard_tower(t):
    """Great round Whiteguard stone tower with corbelled battlement crown, frosted windows, icicles, and frozen banner."""
    stone, trim, moss, crystal, metal, alt, glow = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("MOSS"), t.bm("CRYSTAL"), t.bm("METAL"), t.bm("ALT"), t.bm("GLOW")
    )

    # Battered flared tower base + main cylindrical granite shaft (footing -1.2)
    cone(stone, 10.6, 8.6, 12.0, 14, Matrix.Translation((0.0, 0.0, -1.2)))
    cone(stone, 8.4, 8.0, 34.0, 14, Matrix.Translation((0.0, 0.0, 10.2)))
    # Horizontal iron/stone string-course rings
    for rz in (11.0, 26.0, 42.0):
        cone(metal, 8.65, 8.65, 1.1, 14, Matrix.Translation((0.0, 0.0, rz)))

    # Corbelled parapet cornice & 8 crenellated merlons around top rim
    cone(trim, 8.2, 9.8, 3.6, 14, Matrix.Translation((0.0, 0.0, 43.2)))
    cone(stone, 9.8, 9.8, 3.2, 14, Matrix.Translation((0.0, 0.0, 46.8)))
    for i in range(8):
        ang = i * (math.pi / 4.0)
        mx, my = math.cos(ang) * 8.6, math.sin(ang) * 8.6
        box(trim, (3.2, 2.2, 3.4), Matrix.Translation((mx, my, 51.2)) @ Matrix.Rotation(ang, 4, "Z"))
    # Central upper watch turret cap + snow cap + ward-star flagpole
    cone(stone, 5.4, 4.8, 5.2, 12, Matrix.Translation((0.0, 0.0, 49.0)))
    rock_clean(moss, (14.5, 14.5, 2.2), Matrix.Translation((0.0, 0.0, 50.0)), seed=81, roughness=0.16)
    tapered_limb(metal, (0.0, 0.0, 53.5), (0.0, 0.0, 61.5), 0.25, 0.14, segs=6)

    # Arrow-slit glowing frost windows around shaft
    for ang in (0.0, math.pi * 0.5, math.pi, -math.pi * 0.5):
        wx, wy = math.cos(ang) * 8.15, math.sin(ang) * 8.15
        box(glow, (0.9, 1.2, 5.6), Matrix.Translation((wx, wy, 33.5)) @ Matrix.Rotation(ang, 4, "Z"))

    # Vertical icicle beard hanging below parapet corbel
    for i in range(10):
        ang = i * (math.pi / 5.0)
        ix, iy = math.cos(ang) * 9.5, math.sin(ang) * 9.5
        tapered_limb(crystal, (ix, iy, 43.6), (ix, iy, 37.8 - (i % 3) * 1.4), 0.42, 0.04, segs=5)

    # Banner frozen mid-flutter horizontally on -Y/west flank (+ crossbar pole)
    tapered_limb(metal, (0.0, -7.8, 39.5), (0.0, -14.8, 39.5), 0.28, 0.18, segs=6)
    for b_idx in range(4):
        bx = 0.0
        by = -9.4 - b_idx * 1.35
        bz = 34.0 + math.sin(b_idx * 0.8) * 0.9
        box(alt, (0.45, 1.55, 9.2 - b_idx * 0.9), Matrix.Translation((bx, by, bz)) @ Matrix.Rotation(math.radians(14 + b_idx * 8), 4, "X"))


@template("FrozenSiegeLadder", WOOD=550, METAL=240, MOSS=220, CRYSTAL=260)
def frozen_siege_ladder(t):
    """Heavy oak assault siege ladder pitched at 72 deg with iron grappling hooks and vertical icicles."""
    wood, metal, moss, crystal = t.bm("WOOD"), t.bm("METAL"), t.bm("MOSS"), t.bm("CRYSTAL")

    # Pitched upright assembly (base grounded at z=0, leaning toward +Y wall)
    ladder_m = Matrix.Translation((0.0, 0.0, 0.0)) @ Matrix.Rotation(math.radians(-18), 4, "X")
    for sx in (-2.2, 2.2):
        box(wood, (0.65, 0.75, 27.0), ladder_m @ Matrix.Translation((sx, 0.0, 13.0)))
    # Iron grappling hooks at ladder top
    for sx in (-2.2, 2.2):
        tapered_limb(metal, ladder_m @ Vector((sx, 0.0, 26.2)), ladder_m @ Vector((sx, 2.4, 27.2)), 0.30, 0.16, segs=5)
        tapered_limb(metal, ladder_m @ Vector((sx, 2.4, 27.2)), ladder_m @ Vector((sx, 2.6, 25.4)), 0.16, 0.04, segs=5)
    # 11 oak rungs + snow crust on upper rungs + hanging vertical icicles
    for r in range(11):
        rz = 2.0 + r * 2.25
        box(wood, (4.8, 0.42, 0.48), ladder_m @ Matrix.Translation((0.0, 0.0, rz)))
        if r % 2 == 1:
            p_ic = ladder_m @ Vector(((-1.2 if r % 4 == 1 else 1.1), -0.2, rz))
            tapered_limb(crystal, p_ic, p_ic + Vector((0.0, 0.0, -2.4)), 0.22, 0.03, segs=4)
    rock_clean(moss, (5.4, 3.6, 1.4), Matrix.Translation((0.0, -0.4, 0.4)), seed=94, roughness=0.20)


@template("FrozenTrebuchet", WOOD=1100, STONE=420, METAL=320, MOSS=380, CRYSTAL=340)
def frozen_trebuchet(t):
    """Heavy Whiteguard timber siege trebuchet halted mid-swing in snow and glacier ice."""
    wood, stone, metal, moss, crystal = t.bm("WOOD"), t.bm("STONE"), t.bm("METAL"), t.bm("MOSS"), t.bm("CRYSTAL")

    # Heavy ground sill skid timbers & crossbeams
    for sx in (-5.2, 5.2):
        box(wood, (1.2, 16.4, 1.2), Matrix.Translation((sx, 0.0, 0.4)))
    for sy in (-7.2, 0.0, 7.2):
        box(wood, (11.6, 1.2, 1.1), Matrix.Translation((0.0, sy, 0.4)))
    # Dual A-frame trestle upright standards & angled braces
    for sx in (-5.0, 5.0):
        tapered_limb(wood, (sx, -6.4, 0.8), (sx * 0.72, 0.0, 12.8), 0.72, 0.62, segs=6)
        tapered_limb(wood, (sx, 6.4, 0.8), (sx * 0.72, 0.0, 12.8), 0.72, 0.62, segs=6)
        tapered_limb(wood, (sx, 0.0, 0.8), (sx * 0.72, 0.0, 12.8), 0.68, 0.58, segs=6)
    # Iron main axle
    tapered_limb(metal, (-4.4, 0.0, 12.6), (4.4, 0.0, 12.6), 0.52, 0.52, segs=8)

    # Long throwing arm halted cocked upward at 36 deg
    arm_m = Matrix.Translation((0.0, 0.0, 12.6)) @ Matrix.Rotation(math.radians(36), 4, "X")
    box(wood, (0.95, 19.6, 1.05), arm_m @ Matrix.Translation((0.0, 4.2, 0.0)))
    # Hanging stone-filled counterweight box at short front (-Y) arm end
    cw_pivot = arm_m @ Vector((0.0, -4.6, 0.0))
    box(wood, (4.8, 3.8, 4.2), Matrix.Translation(cw_pivot + Vector((0.0, 0.0, -3.2))))
    rock_clean(stone, (4.2, 3.2, 2.2), Matrix.Translation(cw_pivot + Vector((0.0, 0.0, -1.5))), seed=121, roughness=0.20)
    tapered_limb(metal, cw_pivot + Vector((-2.0, 0.0, 0.0)), cw_pivot + Vector((-2.0, 0.0, -1.6)), 0.18, 0.18, segs=5)
    tapered_limb(metal, cw_pivot + Vector((2.0, 0.0, 0.0)), cw_pivot + Vector((2.0, 0.0, -1.6)), 0.18, 0.18, segs=5)

    # Drifted snow on frame + hanging ice spears off throwing arm tip & counterweight
    rock_clean(moss, (11.2, 14.0, 1.6), Matrix.Translation((0.0, 0.0, 1.2)), seed=125, roughness=0.22)
    tip_pt = arm_m @ Vector((0.0, 13.6, 0.0))
    tapered_limb(crystal, tip_pt, tip_pt + Vector((0.0, 0.0, -4.2)), 0.42, 0.04, segs=5)
    tapered_limb(crystal, cw_pivot + Vector((0.0, 0.0, -5.2)), cw_pivot + Vector((0.0, 0.0, -8.4)), 0.55, 0.06, segs=5)


def build_f19():
    reset_scene()

    kit = bpy.data.collections.new("FrozenF19Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F19_TEMPLATES.items():
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


def export_f19(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "FrozenF19Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "FrozenF19Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f19()
    export_f19(kit, manifest)
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
    for n in F19_TEMPLATES:
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
    n_templates = len(F19_TEMPLATES)
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
