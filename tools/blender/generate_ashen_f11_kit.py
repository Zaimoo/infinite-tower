"""
Ashen Dunes Floor 11 (Cinder Gate) sculpted assets, generated in headless Blender.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Outputs (assets-source/tower/ashen_f11_kit/):
    AshenF11Kit.blend     the generated scene
    AshenF11Kit.fbx       FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             Workbench contact-sheet render of the 5 Floor 11 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "ashen_f11_kit")

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


F11_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F11_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("CinderGateArch", TRIM=2200, STONE=1100, ALT=900, ACCENT=400, GLOW=400, METAL=300)
def cinder_gate_arch(t):
    """Towering semicircular Varrash portal arch set into columnar basalt cliffs with molten flame crest."""
    trim, stone, alt = t.bm("TRIM"), t.bm("STONE"), t.bm("ALT")
    accent, glow, metal = t.bm("ACCENT"), t.bm("GLOW"), t.bm("METAL")

    # Wide stepped sandstone approach stairs (front -Y rising cleanly from z = 0 threshold)
    for s in range(5):
        sw = 34.0 - s * 1.4
        sy = -9.5 + s * 1.8
        sh = 1.0 + s * 0.55
        box(trim if s % 2 == 0 else alt, (sw, 2.2, sh), M((0, sy, sh * 0.5)), bevel=0.06)

    # Dark columnar basalt framing cliff ribs beside the arch piers
    for side in (-1, 1):
        for col_i in range(4):
            cx = side * (17.5 + col_i * 3.1)
            cy = 1.5 + (col_i % 2) * 1.8
            ch = 36.0 + ((col_i * 7 + (1 if side > 0 else 0)) % 4) * 4.5
            w_col = 4.6 - col_i * 0.25
            box(stone, (w_col, 7.5, ch), M((cx, cy, ch * 0.5), rot=(0, 0, side * 0.04 * col_i)), bevel=0.18)

    # Flanking stepped Varrash sandstone gatehouse piers
    for side in (-1, 1):
        px = side * 14.5
        box(stone, (8.2, 10.5, 4.0), M((px, 0, 2.0)), bevel=0.14)
        courses = [
            (4.0, 5.0, 7.8, 10.0, trim),
            (9.0, 3.2, 7.6, 9.6, alt),
            (12.2, 5.2, 7.2, 9.2, trim),
            (17.4, 3.0, 7.0, 8.8, alt),
            (20.4, 5.6, 6.8, 8.6, trim),
            (26.0, 2.2, 7.6, 9.4, alt),  # springline capital cornice
        ]
        for z0, h, wx, dy, role in courses:
            box(role, (wx, dy, h), M((px, 0, z0 + h * 0.5)), bevel=0.10)

        # Torch brazier bracket + amber ember bowl on front pier plinth
        bx = px - side * 2.2
        box(metal, (1.4, 1.6, 2.4), M((bx, -5.0, 8.2)), bevel=0.05)
        cone(metal, 1.2, 0.7, 1.4, 8, M((bx, -5.2, 9.4)))
        uvsphere(glow, 0.85, M((bx, -5.2, 10.6)), 8, 6)

    # Shadowed deep basalt passage backing behind the archway
    for side in (-1, 1):
        box(stone, (3.2, 4.5, 29.0), M((side * 10.8, 2.2, 14.5)), bevel=0.10)
    box(stone, (22.0, 2.4, 32.0), M((0, 4.2, 16.0)), bevel=0.12)

    # Concentric semicircular banded Varrash arch voussoirs (springline z = 27)
    spring_z = 27.0
    n_seg = 20
    inner_r = 11.4
    mid_r = 15.2
    outer_r = 17.6
    for i in range(n_seg):
        t0 = (i + 0.5) / n_seg
        ang = math.pi * t0  # 0 (right) -> pi (left)
        cx = math.cos(ang) * ((inner_r + mid_r) * 0.5)
        cz = spring_z + math.sin(ang) * ((inner_r + mid_r) * 0.5)
        role = trim if i % 2 == 0 else alt
        arc_len = (math.pi * (inner_r + mid_r) * 0.5) / n_seg + 0.65
        box(role, (4.2, 7.6, arc_len), M((cx, 0, cz), rot=(0, -(ang - math.pi * 0.5), 0)), bevel=0.10)

        ox = math.cos(ang) * outer_r
        oz = spring_z + math.sin(ang) * outer_r
        brow_len = (math.pi * outer_r) / n_seg + 1.05
        box(trim if i % 3 != 0 else accent, (2.2, 8.6, brow_len), M((ox, -0.2, oz), rot=(0, -(ang - math.pi * 0.5), 0)), bevel=0.08)

    # Pointed teardrop flame keystone & glowing cinder at the very apex
    crest_z = spring_z + outer_r + 1.2
    cone(trim, 4.8, 1.0, 7.2, 6, M((0, -0.8, crest_z - 1.5), scale=(1.0, 0.72, 1.0)))
    cone(accent, 3.6, 0.6, 5.8, 6, M((0, -1.6, crest_z - 0.8), scale=(1.0, 0.65, 1.0)))
    uvsphere(glow, 1.55, M((0, -2.5, crest_z + 1.4), scale=(0.85, 0.65, 1.45)), 10, 8)


@template("VarrashWaystone", TRIM=320, STONE=240, ALT=180, METAL=360, GLOW=220)
def varrash_waystone(t):
    """Short square sandstone milepost pillar topped with a wrought-iron lantern cage and amber flame."""
    trim, stone, alt = t.bm("TRIM"), t.bm("STONE"), t.bm("ALT")
    metal, glow = t.bm("METAL"), t.bm("GLOW")

    box(stone, (3.8, 3.8, 1.2), M((0, 0, 0.6)), bevel=0.10)
    box(trim, (2.8, 2.8, 2.2), M((0, 0, 2.3)), bevel=0.08)
    box(alt, (2.4, 2.4, 1.5), M((0, 0, 4.15)), bevel=0.06)
    box(trim, (3.2, 3.2, 1.1), M((0, 0, 5.45)), bevel=0.08)
    box(metal, (2.6, 2.6, 0.45), M((0, 0, 6.2)), bevel=0.04)

    # Four corner iron cage bars converging slightly toward top finial
    for sx in (-1, 1):
        for sy in (-1, 1):
            p0 = (sx * 0.95, sy * 0.95, 6.4)
            p1 = (sx * 0.42, sy * 0.42, 9.2)
            tube(metal, [p0, p1], [0.16, 0.12], 6)
    cone(metal, 1.1, 0.15, 1.3, 4, M((0, 0, 9.0), rot=(0, 0, math.pi * 0.25)))
    uvsphere(glow, 0.85, M((0, 0, 7.65), scale=(0.85, 0.85, 1.35)), 8, 6)


@template("BuriedWagon", WOOD=1200, FOLIAGE=900, METAL=360, MOSS=600)
def buried_wagon(t):
    """Covered Varrash merchant wagon tilted into a windblown sand bank, wheels half-submerged."""
    wood, canvas, metal, sand = t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("METAL"), t.bm("MOSS")

    # Tilted matrix pivoting cleanly above z = 0 (rolled right ~16 deg, pitched slightly forward ~8 deg)
    tilt = M((0, 0, 4.2), rot=(math.radians(8), math.radians(16), math.radians(-12)))

    # Sand drift apron hugging the lower edge (grounded flat on z = 0)
    rock_clean(sand, (13.5, 18.0, 4.8), M((1.6, 0.5, 1.6)), 11, roughness=0.20, subdiv=2, flat_bottom=True)

    # Slatted timber wagon chassis & bed sides
    box(wood, (7.6, 15.0, 1.1), tilt @ M((0, 0, 0)), bevel=0.08)
    for side in (-1, 1):
        box(wood, (0.7, 14.6, 2.8), tilt @ M((side * 3.45, 0, 1.85)), bevel=0.06)
        box(wood, (0.9, 15.0, 0.55), tilt @ M((side * 3.55, 0, 3.3)), bevel=0.04)

    # Spoked wooden wagon wheels (left high wheel prominent, right half buried in sand drift)
    for wy in (-4.4, 4.4):
        for side in (-1, 1):
            wx = side * 4.25
            w_rot = tilt @ M((wx, wy, -0.4), rot=(0, math.pi * 0.5, 0))
            ring_mesh(metal, 2.35, 0.28, 14, w_rot)
            ring_mesh(wood, 2.05, 0.34, 14, w_rot)
            box(wood, (1.1, 1.1, 1.2), w_rot, bevel=0.05)
            for sp in range(4):
                ang = sp * math.pi * 0.25
                box(wood, (3.8, 0.26, 0.26), w_rot @ M((0, 0, 0), rot=(0, ang, 0)), bevel=0.02)

    # 5 arched timber canopy ribs + taut grey-tan ribbed canvas cloth roof
    n_ribs = 5
    for i in range(n_ribs):
        ry = -6.4 + i * 3.2
        pts = []
        rads = []
        for k in range(9):
            ang = math.pi * (k / 8.0)
            px = math.cos(ang) * 3.65
            pz = 3.3 + math.sin(ang) * 3.9
            v = tilt @ Vector((px, ry, pz))
            pts.append(v)
            rads.append(0.24)
        tube(wood, pts, rads, 6)

    # Draped canvas roof panels between ribs
    for k in range(8):
        a0 = math.pi * (k / 8.0)
        a1 = math.pi * ((k + 1) / 8.0)
        am = (a0 + a1) * 0.5
        px = math.cos(am) * 3.55
        pz = 3.3 + math.sin(am) * 3.8
        seg_w = 3.8 * (math.pi / 8.0) + 0.32
        box(canvas, (seg_w, 13.4, 0.45), tilt @ M((px, 0, pz), rot=(0, -(am - math.pi * 0.5), 0)), bevel=0.06)

    # Rolled front & rear canvas valance flaps
    box(canvas, (5.8, 0.8, 1.6), tilt @ M((0, -6.5, 6.2)), bevel=0.08)
    box(canvas, (6.2, 0.7, 2.4), tilt @ M((0, 6.6, 5.3)), bevel=0.08)


@template("TollHouseRuins", TRIM=1600, STONE=900, ALT=900, METAL=500, GLOW=220, MOSS=500)
def toll_house_ruins(t):
    """Roofless banded sandstone and basalt Varrash toll-station ruin with barred windows."""
    trim, stone, alt = t.bm("TRIM"), t.bm("STONE"), t.bm("ALT")
    metal, glow, sand = t.bm("METAL"), t.bm("GLOW"), t.bm("MOSS")

    # Grounded perimeter courtyard sand drifts along outer ruined skirt
    rock_clean(sand, (16.0, 8.0, 2.6), M((-8.0, -13.0, 0.8)), 31, roughness=0.22, subdiv=2, flat_bottom=True)
    rock_clean(sand, (12.0, 14.0, 2.8), M((15.0, 4.0, 0.9)), 32, roughness=0.22, subdiv=2, flat_bottom=True)

    # Helper: banded wall segment supporting an optional bottom z_start (for open barred windows)
    def banded_wall(x, y, wx, dy, h_total, rot_z=0.0, z_start=0.0):
        # Layers: dark basalt base (0..2.8), terracotta (2.8..5.2), cream (5.2..7.8), terracotta (7.8..10.2), cream (10.2..13.5)
        bands = [
            (0.0, 2.8, stone),
            (2.8, 5.2, alt),
            (5.2, 7.8, trim),
            (7.8, 10.2, alt),
            (10.2, 13.6, trim),
        ]
        for z0, z1, role in bands:
            lo_z = max(z0, z_start)
            top = min(z1, h_total)
            bh = top - lo_z
            if bh > 0.25:
                box(role, (wx, dy, bh), M((x, y, lo_z + bh * 0.5), rot=(0, 0, rot_z)), bevel=0.08)

    # South ruined frontage wall (facing -Y across caravan road) with breach & open barred window bay
    banded_wall(-15.0, -11.0, 4.0, 3.0, 12.2)
    banded_wall(-11.0, -11.0, 4.2, 3.0, 5.6)                # sill under barred window
    banded_wall(-11.0, -11.0, 4.2, 3.0, 12.4, z_start=9.6)   # header above barred window
    banded_wall(-6.9, -11.0, 4.0, 3.0, 12.2)
    banded_wall(1.5, -11.0, 7.5, 3.0, 6.2)     # breached low sill gap
    banded_wall(11.5, -11.0, 11.0, 3.0, 13.0)

    # Window opening + dark iron vertical bars in west-south bay
    box(metal, (4.4, 1.2, 0.45), M((-11.0, -11.0, 5.75)))
    box(metal, (4.4, 1.2, 0.45), M((-11.0, -11.0, 9.5)))
    for bi in range(-2, 3):
        box(metal, (0.28, 0.55, 3.8), M((-11.0 + bi * 0.9, -11.0, 7.6)))

    # West long wall (-X) with jagged stepped collapse profile
    banded_wall(-15.5, -5.5, 3.0, 9.0, 13.4)
    banded_wall(-15.5, 5.0, 3.0, 10.0, 10.0)
    banded_wall(-15.5, 11.5, 3.0, 5.0, 7.4)

    # East long wall (+X) facing central Dune & Ash Flats, with main doorway + open barred window
    banded_wall(15.5, -6.5, 3.0, 7.0, 12.4)
    banded_wall(15.5, 4.2, 3.0, 2.4, 11.4)
    banded_wall(15.5, 7.6, 3.0, 4.4, 5.6)                    # sill under east barred window
    banded_wall(15.5, 7.6, 3.0, 4.4, 11.2, z_start=9.2)      # header above east barred window
    banded_wall(15.5, 11.4, 3.0, 3.2, 10.6)
    box(metal, (1.2, 4.5, 0.45), M((15.5, 7.6, 5.75)))
    box(metal, (1.2, 4.5, 0.45), M((15.5, 7.6, 9.1)))
    for bi in range(-2, 3):
        box(metal, (0.55, 0.28, 3.4), M((15.5, 7.6 + bi * 0.9, 7.4)))

    # North wall (+Y) broken across center
    banded_wall(-10.0, 12.0, 10.5, 3.0, 9.6)
    banded_wall(9.0, 12.0, 13.0, 3.0, 12.8)

    # Interior dividing partition wall stub & fallen sandstone masonry blocks
    banded_wall(-2.0, 2.0, 2.6, 12.0, 9.2)
    for rx, ry, rot in [(-6.0, -14.2, 0.3), (4.5, -13.5, -0.4), (17.5, -1.5, 0.6), (0.5, 4.5, 0.2)]:
        box(trim if rot > 0 else alt, (2.8, 2.2, 1.5), M((rx, ry, 0.75), rot=(0.08, -0.05, rot)), bevel=0.10)

    # Wall brazier sconce inside ruin courtyard
    cone(metal, 1.2, 0.6, 1.2, 8, M((-2.0, -4.0, 9.4)))
    uvsphere(glow, 0.85, M((-2.0, -4.0, 10.5)), 8, 6)


@template("WatchKilnTower", TRIM=1500, STONE=850, ALT=800, METAL=450, GLOW=300, MOSS=450)
def watch_kiln_tower(t):
    """Cylindrical Varrash kiln watchtower with banded sandstone drum, round amber portholes & roof cage."""
    trim, stone, alt = t.bm("TRIM"), t.bm("STONE"), t.bm("ALT")
    metal, glow, sand = t.bm("METAL"), t.bm("GLOW"), t.bm("MOSS")

    # Volcanic rock mound plinth + wind-drifted skirt (grounded at z = 0)
    rock_clean(stone, (20.5, 20.5, 4.2), M((0, 0, 1.8)), 41, roughness=0.24, subdiv=2, flat_bottom=True)
    rock_clean(sand, (18.0, 12.0, 2.6), M((-4.5, -6.5, 0.9)), 42, roughness=0.18, subdiv=2, flat_bottom=True)

    # Small arched doorway vestibule jutting toward front-left (-Y, -X)
    door_mat = M((-5.8, -5.8, 0), rot=(0, 0, math.radians(-40)))
    box(trim, (5.2, 4.6, 6.2), door_mat @ M((0, 0, 3.1)), bevel=0.12)
    box(stone, (2.6, 5.0, 4.4), door_mat @ M((0, -0.2, 2.2)), bevel=0.06)

    # Banded cylindrical tapered sandstone drum (z = 2.6 .. 16.2)
    drum_layers = [
        (2.6, 3.2, 8.6, 8.2, stone),
        (5.8, 3.4, 8.2, 7.8, trim),
        (9.2, 2.4, 7.8, 7.5, alt),
        (11.6, 3.2, 7.5, 7.1, trim),
        (14.8, 1.2, 7.6, 7.6, alt),  # lower frieze band
    ]
    for z0, h, r1, r2, role in drum_layers:
        cone(role, r1, r2, h, 14, M((0, 0, z0)))

    # Upper lantern drum (z = 16.0 .. 22.8) + upper parapet cornice
    cone(trim, 7.3, 7.3, 6.2, 14, M((0, 0, 16.0)))
    cone(alt, 7.8, 7.6, 1.3, 14, M((0, 0, 22.2)))
    cone(trim, 7.6, 7.2, 1.2, 14, M((0, 0, 23.5)))

    # 4 circular metal-framed glowing amber porthole windows on the upper lantern drum
    for k in range(4):
        ang = k * (math.pi * 0.5) + math.radians(25)
        px = math.cos(ang) * 7.25
        py = math.sin(ang) * 7.25
        frame_mat = M((px, py, 19.1), rot=(0, math.pi * 0.5, ang))
        ring_mesh(metal, 1.65, 0.32, 12, frame_mat)
        cone(glow, 1.32, 1.32, 0.45, 12, M((px * 0.96, py * 0.96, 19.1), rot=(0, math.pi * 0.5, ang)))

    # Rooftop wrought-iron signal fire basket & glowing ember core
    cone(stone, 3.2, 2.6, 1.4, 10, M((0, 0, 24.4)))
    ring_mesh(metal, 2.2, 0.18, 10, M((0, 0, 27.6)))
    ring_mesh(metal, 1.7, 0.16, 10, M((0, 0, 26.0)))
    for k in range(6):
        ang = k * (math.pi / 3.0)
        p0 = (math.cos(ang) * 1.5, math.sin(ang) * 1.5, 25.5)
        p1 = (math.cos(ang) * 2.2, math.sin(ang) * 2.2, 27.8)
        tube(metal, [p0, p1], [0.14, 0.12], 5)
    uvsphere(glow, 1.35, M((0, 0, 26.8), scale=(1.0, 1.0, 0.85)), 8, 6)


DEFAULT_BUDGET = 3500


def build_f11():
    reset_scene()
    kit = bpy.data.collections.new("AshenF11Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F11_TEMPLATES.items():
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


def export_f11(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "AshenF11Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "AshenF11Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f11()
    export_f11(kit, manifest)
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
    for n in F11_TEMPLATES:
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
    sheet = bpy.data.images.new("PreviewSheet", width=520 * 5, height=520, alpha=True)
    buf = np.zeros((520, 520 * 5, 4), dtype=np.float32)
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
