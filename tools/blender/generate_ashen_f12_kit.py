"""
Ashen Dunes Floor 12 (Buried Caravan) sculpted assets, generated in headless Blender.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Outputs (assets-source/tower/ashen_f12_kit/):
    AshenF12Kit.blend     the generated scene
    AshenF12Kit.fbx       FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the 6 Floor 12 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "ashen_f12_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
tube = kit_mod["tube"]
rock = kit_mod["rock"]
ring_mesh = kit_mod["ring_mesh"]
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
F12_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F12_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("SandStriderRibs", TRIM=2400, STONE=900, MOSS=600)
def sand_strider_ribs(t):
    """Colossal fossilized Sand-Strider ribcage archway straddling the caravan ramp."""
    bone, joint, sand = t.bm("TRIM"), t.bm("STONE"), t.bm("MOSS")

    n_ribs = 9
    span_y = 46.0
    # Dorsal vertebral spine curving down gently at head/tail ends
    spine_pts = []
    spine_rads = []
    for i in range(n_ribs):
        u = (i / (n_ribs - 1)) * 2.0 - 1.0  # -1..1
        y = u * (span_y * 0.5)
        arch_z = 26.5 - (u * u) * 3.8
        spine_pts.append((0.0, y, arch_z))
        spine_rads.append(1.55 - 0.35 * abs(u))
    tube(joint, spine_pts, spine_rads, 10)

    for i in range(n_ribs):
        u = (i / (n_ribs - 1)) * 2.0 - 1.0
        y = u * (span_y * 0.5)
        top_z = 26.5 - (u * u) * 3.8
        half_w = 18.0 - (u * u) * 3.2

        # Dorsal neural spine neural crest fin above each vertebra
        box(bone, (1.4, 2.6, 3.8 - abs(u) * 1.1), M((0.0, y, top_z + 1.8), rot=(u * 0.14, 0, 0)), bevel=0.14)
        box(joint, (3.2, 2.2, 2.2), M((0.0, y, top_z)), bevel=0.12)

        # Pair of sweeping tapered curved ribs arching outward & planting cleanly into sand
        for side in (-1, 1):
            pts = []
            rads = []
            segs = 7
            for k in range(segs + 1):
                s = k / segs
                ang = s * math.pi * 0.52  # 0 (top) -> ~94 deg (ground anchor)
                rx = side * math.sin(ang) * half_w
                # Slightly flare outward mid-arch then tuck slightly at root
                rx *= (1.0 + 0.12 * math.sin(s * math.pi))
                rz = max(0.0, top_z * math.cos(s * math.pi * 0.48))
                if k == segs:
                    rz = 0.0
                pts.append((rx, y + side * 0.4 * math.sin(s * math.pi), rz))
                rads.append(1.15 - s * 0.35 - abs(u) * 0.18)
            tube(bone, pts, rads, 8)
            # Ground sand drift hugging rib foot
            if i % 2 == 0:
                rock_clean(sand, (5.2, 5.8, 2.0), M((side * half_w * 0.96, y, 0.7)), 10 + i * 3 + (1 if side > 0 else 0), roughness=0.18, subdiv=2, flat_bottom=True)


@template("SandStriderSkull", TRIM=2200, STONE=900, MOSS=600)
def sand_strider_skull(t):
    """Giant fossilized desert behemoth skull half-buried in sand beside the ribcage."""
    bone, dark, sand = t.bm("TRIM"), t.bm("STONE"), t.bm("MOSS")

    tilt = M((0, 0, 4.2), rot=(math.radians(8), math.radians(-18), math.radians(14)))
    rock_clean(sand, (22.0, 26.0, 4.4), M((0.0, 1.0, 1.6)), 23, roughness=0.20, subdiv=2, flat_bottom=True)

    # Broad domed cranium & cheekbones
    uvsphere(bone, 7.6, tilt @ M((0, 4.5, 2.6), scale=(1.15, 1.05, 0.78)), 14, 10)
    # Tapered elongate rostrum / upper snout projecting toward -Y
    cone(bone, 5.6, 2.4, 14.5, 10, tilt @ M((0, -3.5, 1.4), rot=(math.radians(92), 0, 0), scale=(1.05, 0.68, 1.0)))
    # Zygomatic brow ridges & twin backward-sweeping temporal horns
    for side in (-1, 1):
        box(bone, (3.2, 6.8, 2.6), tilt @ M((side * 6.2, 2.4, 2.4), rot=(0, side * 0.25, side * -0.22)), bevel=0.35)
        cone(bone, 2.1, 0.55, 7.8, 8, tilt @ M((side * 5.8, 7.2, 4.6), rot=(math.radians(-58), side * math.radians(-22), 0)))
        # Deep hollow eye socket cavities (set prominently outside zygomatic cheek arch)
        uvsphere(dark, 2.55, tilt @ M((side * 5.2, 0.8, 2.5), scale=(0.9, 1.35, 1.05)), 10, 8)
    # Nasal cavity hollow & open lower jaw trough
    uvsphere(dark, 2.1, tilt @ M((0, -8.8, 2.0), scale=(0.92, 1.75, 0.72)), 10, 8)
    cone(dark, 1.4, 0.9, 3.2, 8, tilt @ M((0, -10.8, 1.4), rot=(math.radians(90), 0, 0)))
    box(bone, (6.4, 12.0, 2.4), tilt @ M((0, -1.8, -1.6)), bevel=0.30)


@template("DesertCaravanWagon", WOOD=1400, FOLIAGE=900, METAL=450, MOSS=400)
def desert_caravan_wagon(t):
    """Varrash wooden merchant wagon with spoked wheels, hitch shafts and strung nomad side-awning."""
    wood, canvas, metal, sand = t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("METAL"), t.bm("MOSS")

    # Bed raised to axle height (wheels R = 2.45 standing on z = 0)
    axle_z = 2.45
    rock_clean(sand, (11.5, 14.0, 2.2), M((0, 0, 0.6)), 33, roughness=0.18, subdiv=2, flat_bottom=True)

    # Heavy planked chassis & high slatted wooden sides
    box(wood, (7.4, 14.4, 0.95), M((0, 0, axle_z + 0.3)), bevel=0.06)
    for side in (-1, 1):
        box(wood, (0.65, 14.2, 3.2), M((side * 3.4, 0, axle_z + 2.2)), bevel=0.06)
        box(wood, (0.85, 14.6, 0.55), M((side * 3.45, 0, axle_z + 3.85)), bevel=0.04)
        # Forward draft hitch poles reaching toward -Y
        box(wood, (0.45, 6.2, 0.45), M((side * 1.9, -9.8, axle_z - 0.55), rot=(math.radians(14), 0, 0)), bevel=0.04)
    # Curved rear sideboard gate
    box(wood, (6.8, 0.65, 3.8), M((0, 7.0, axle_z + 2.5)), bevel=0.06)
    box(wood, (5.2, 0.65, 1.4), M((0, 7.0, axle_z + 4.8)), bevel=0.18)

    # Four 8-spoke iron-rimmed wagon wheels cleanly touching z = 0
    for wy in (-4.4, 4.4):
        for side in (-1, 1):
            wx = side * 4.15
            w_rot = M((wx, wy, axle_z), rot=(0, math.pi * 0.5, 0))
            ring_mesh(metal, 2.28, 0.22, 14, w_rot)
            ring_mesh(wood, 2.02, 0.28, 14, w_rot)
            box(wood, (0.95, 0.95, 1.15), w_rot, bevel=0.05)
            for sp in range(4):
                ang = sp * math.pi * 0.25
                box(wood, (3.7, 0.22, 0.22), w_rot @ M((0, 0, 0), rot=(0, ang, 0)), bevel=0.02)

    # Tattered nomad canvas sun-awning pitched off +X side with timber prop poles
    for py in (-5.6, 5.6):
        cone(wood, 0.28, 0.22, 6.8, 6, M((9.2, py, 0.0)))
    box(canvas, (7.6, 13.8, 0.38), M((6.4, 0, 7.35), rot=(0, math.radians(-14), 0)), bevel=0.06)
    box(canvas, (5.2, 12.6, 0.35), M((2.1, 0, 7.6), rot=(0, math.radians(22), 0)), bevel=0.06)


@template("SpiceVaultRuins", TRIM=1600, STONE=800, ALT=900, GOLD=600, CORAL=600, METAL=300)
def spice_vault_ruins(t):
    """Collapsed banded sandstone warehouse facade with burst saffron & crimson spice amphorae."""
    trim, stone, alt = t.bm("TRIM"), t.bm("STONE"), t.bm("ALT")
    saffron, crimson, metal = t.bm("GOLD"), t.bm("CORAL"), t.bm("METAL")

    # Ruined banded sandstone warehouse facade (back +Y half, doorway arch opening toward -Y)
    def course_wall(x, y, wx, dy, h_total):
        bands = [(0.0, 2.8, stone), (2.8, 5.6, trim), (5.6, 8.2, alt), (8.2, 11.4, trim), (11.4, 15.0, alt)]
        for z0, z1, role in bands:
            if z0 >= h_total:
                break
            bh = min(z1, h_total) - z0
            if bh > 0.25:
                box(role, (wx, dy, bh), M((x, y, z0 + bh * 0.5)), bevel=0.08)

    course_wall(-10.5, 4.0, 11.0, 3.2, 14.2)
    course_wall(10.5, 4.0, 11.0, 3.2, 12.8)
    course_wall(0.0, 4.0, 10.0, 3.2, 14.8)  # arch header beam above doorway gap
    # Flanking ruined wing walls jutting forward toward -Y
    course_wall(-14.5, -3.5, 3.0, 11.5, 11.6)
    course_wall(14.5, -4.5, 3.0, 9.5, 9.2)
    # Recessed dark vault portal
    box(stone, (8.2, 2.2, 9.8), M((0, 4.8, 4.9)), bevel=0.08)

    # Three giant overturned terracotta & sandstone spice amphorae spilling saffron & crimson mounds
    urn_specs = [
        (-8.2, -5.8, -0.45, 1.2, saffron),
        (0.8, -7.8, 0.25, 1.35, crimson),
        (9.2, -4.4, 0.72, 1.15, saffron),
    ]
    for idx, (ux, uy, uyaw, usc, spill_role) in enumerate(urn_specs):
        u_rot = M((ux, uy, 2.1 * usc), rot=(math.radians(78), 0, uyaw))
        uvsphere(alt if idx % 2 == 0 else trim, 2.4 * usc, u_rot @ M((0, 0, 0), scale=(0.88, 0.88, 1.25)), 12, 8)
        cone(trim, 1.45 * usc, 1.75 * usc, 1.6 * usc, 10, u_rot @ M((0, 0, 2.2 * usc)))
        ring_mesh(metal, 1.6 * usc, 0.16, 12, u_rot @ M((0, 0, 1.4 * usc)))
        # Wide spilled conical spice pile flowing out onto ground z = 0
        sx = ux + math.sin(uyaw) * (3.6 * usc)
        sy = uy - math.cos(uyaw) * (3.6 * usc)
        rock_clean(spill_role, (7.6 * usc, 7.2 * usc, 1.75), M((sx, sy, 0.45), rot=(0, 0, uyaw)), 50 + idx * 7, roughness=0.14, subdiv=2, flat_bottom=True)


@template("CaravanseraiSkylight", TRIM=600, METAL=900, STONE=400, GLOW=220)
def caravanserai_skylight(t):
    """Square sandstone curb skylight grate set flush atop the buried Caravanserai Roof."""
    trim, metal, stone, glow = t.bm("TRIM"), t.bm("METAL"), t.bm("STONE"), t.bm("GLOW")

    # Grounded perimeter beveled sandstone curb frame (11.5 x 11.5 x 2.0)
    box(stone, (11.6, 11.6, 0.55), M((0, 0, 0.28)), bevel=0.06)
    for sx in (-1, 1):
        box(trim, (1.4, 11.2, 1.4), M((sx * 4.9, 0, 0.95)), bevel=0.08)
        box(trim, (11.2, 1.4, 1.4), M((0, sx * 4.9, 0.95)), bevel=0.08)
    # Shadowed deep well + warm inner glow below grate
    box(stone, (8.4, 8.4, 0.45), M((0, 0, 0.45)))
    box(glow, (6.8, 6.8, 0.25), M((0, 0, 0.65)))
    # Decorative wrought-iron cross-lattice grille bars
    for k in range(-3, 4):
        off = k * 1.22
        box(metal, (0.28, 8.8, 0.36), M((off, 0, 1.38)), bevel=0.02)
        box(metal, (8.8, 0.28, 0.36), M((0, off, 1.42)), bevel=0.02)
    box(metal, (4.2, 4.2, 0.22), M((0, 0, 1.56), rot=(0, 0, math.pi * 0.25)), bevel=0.02)


@template("MasterTombPavilion", TRIM=1600, FOLIAGE=1400, GOLD=600, METAL=450, STONE=700, GLOW=250)
def master_tomb_pavilion(t):
    """Tented Caravan Master tomb-pavilion with torn awnings on bronze poles and flanking lanterns."""
    trim, canvas, gold = t.bm("TRIM"), t.bm("FOLIAGE"), t.bm("GOLD")
    metal, stone, glow = t.bm("METAL"), t.bm("STONE"), t.bm("GLOW")

    # Three wide ceremonial approach stairs & tiered basalt/sandstone podium
    for s in range(3):
        box(stone if s == 0 else trim, (36.0 - s * 2.4, 24.0 - s * 1.8, 1.2), M((0, 0, 0.6 + s * 1.2)), bevel=0.08)

    base_z = 3.6
    # Inner carved sandstone sarcophagus dais & bronze corner posts
    box(stone, (10.5, 7.6, 1.8), M((0, 0, base_z + 0.9)), bevel=0.10)
    box(trim, (8.4, 5.4, 2.8), M((0, 0, base_z + 3.2)), bevel=0.12)
    box(gold, (8.8, 5.8, 0.7), M((0, 0, base_z + 4.8)), bevel=0.08)

    # Four tall bronze-capped sandstone canopy columns + peaked central spire finial
    for sx in (-1, 1):
        for sy in (-1, 1):
            px, py = sx * 9.5, sy * 7.2
            cone(trim, 1.1, 0.85, 13.5, 10, M((px, py, base_z)))
            box(gold, (2.4, 2.4, 1.0), M((px, py, base_z + 13.5)), bevel=0.06)
            cone(metal, 0.5, 0.1, 3.2, 6, M((px, py, base_z + 14.0)))

    # Central peaked tent canopy + swept wing awnings out to angled side anchor poles
    cone(canvas, 13.2, 1.2, 6.2, 4, M((0, 0, base_z + 14.0), rot=(0, 0, math.pi * 0.25), scale=(1.0, 0.82, 1.0)))
    for side in (-1, 1):
        # Angled outer anchor guy-pole + stretched wind-billowed awning flap
        cone(metal, 0.35, 0.22, 11.5, 6, M((side * 16.5, 0, base_z - 0.2), rot=(0, side * math.radians(-16), 0)))
        box(canvas, (10.5, 15.8, 0.42), M((side * 13.2, 0, base_z + 12.2), rot=(0, side * math.radians(24), 0)), bevel=0.06)

    # Twin tall filigree bronze tomb cage lanterns flanking the front approach stairs
    for side in (-1, 1):
        lx, ly = side * 15.2, -10.5
        box(stone, (3.4, 3.4, 1.4), M((lx, ly, 0.7)), bevel=0.08)
        box(trim, (2.6, 2.6, 4.2), M((lx, ly, 3.5)), bevel=0.08)
        box(metal, (2.8, 2.8, 0.5), M((lx, ly, 5.85)), bevel=0.04)
        for csx in (-1, 1):
            for csy in (-1, 1):
                tube(metal, [(lx + csx * 1.1, ly + csy * 1.1, 6.1), (lx + csx * 0.45, ly + csy * 0.45, 9.6)], [0.16, 0.12], 5)
        cone(gold, 1.4, 0.18, 1.6, 6, M((lx, ly, 9.5)))
        uvsphere(glow, 1.05, M((lx, ly, 7.8), scale=(0.88, 0.88, 1.35)), 10, 8)


def build_f12():
    reset_scene()
    kit = bpy.data.collections.new("AshenF12Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F12_TEMPLATES.items():
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


def export_f12(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "AshenF12Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "AshenF12Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f12()
    export_f12(kit, manifest)
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
    for n in F12_TEMPLATES:
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
    n_templates = len(F12_TEMPLATES)
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
