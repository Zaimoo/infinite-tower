"""
Verdant Ruins Floor 5 (Mossbound Court) sculpted assets, generated in headless Blender.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Outputs (assets-source/tower/verdant_f5_kit/):
    VerdantF5Kit.blend    the generated scene
    VerdantF5Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             contact-sheet render of the 5 Floor 5 templates
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "verdant_f5_kit")

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
render_previews = kit_mod["render_previews"]


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


DEFAULT_BUDGET = 3500
F5_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F5_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


@template("CenoteColonnadeDome", TRIM=2200, ACCENT=600, GOLD=300, WOOD=800, MOSS=600)
def cenote_colonnade_dome(t):
    """Open semicircular Solmere colonnade + soaring vaulted rib-cage dome framing the Mossbound Dais sky."""
    trim, accent, gold, wood, moss = t.bm("TRIM"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("WOOD"), t.bm("MOSS")

    radius = 60.0
    # Curved base plinth arc & 11 fluted columns in a grand northern semicircle (front open toward -Y)
    cols = 11
    for i in range(cols):
        ang = -0.05 + (i / (cols - 1)) * (math.pi + 0.10)  # 0 = +X east -> pi/2 = +Y north -> pi = -X west
        cx = math.cos(ang) * radius
        cy = math.sin(ang) * radius * 0.62 - 6.0
        box(trim, (5.2, 5.2, 4.0), M((cx, cy, 2.0), rot=(0, 0, -ang)), bevel=0.14)
        box(accent, (5.6, 5.6, 1.4), M((cx, cy, 4.6), rot=(0, 0, -ang)), bevel=0.06)
        cone(trim, 1.9, 1.6, 26.0, 8, M((cx, cy, 5.0)))
        box(accent, (4.8, 4.8, 1.8), M((cx, cy, 31.2), rot=(0, 0, -ang)), bevel=0.08)

        # Arch beam connecting to next column along perimeter ring
        if i < cols - 1:
            ang2 = -0.05 + ((i + 1) / (cols - 1)) * (math.pi + 0.10)
            nx, ny = math.cos(ang2) * radius, math.sin(ang2) * radius * 0.62 - 6.0
            mx, my = (cx + nx) * 0.5, (cy + ny) * 0.5
            seg_len = math.hypot(nx - cx, ny - cy) + 2.0
            yaw = math.atan2(ny - cy, nx - cx)
            box(trim, (seg_len, 4.6, 4.2), M((mx, my, 33.6), rot=(0, 0, yaw)), bevel=0.12)
            box(accent, (seg_len + 0.4, 5.0, 1.5), M((mx, my, 36.2), rot=(0, 0, yaw)), bevel=0.06)
            if i % 2 == 0:
                rock_clean(moss, (8.0, 4.2, 1.6), M((mx, my, 37.2), rot=(0, 0, yaw)), 20 + i, roughness=0.25, subdiv=2)

        # Broken vaulted dome ribs sweeping inward & upward toward the central open skylight oculus
        if i % 2 == 0 or i in (3, 7):
            rib_pts = []
            rib_rads = []
            oculus_r = 16.0
            steps = 5
            for s in range(steps + 1):
                u = s / steps
                # Stop some outer ribs partway (broken dome silhouette)
                if i in (0, cols - 1) and s == steps:
                    continue
                rr = radius * (1.0 - u) + oculus_r * u
                ry = rr * 0.62 - 6.0
                rx = math.cos(ang) * rr
                py = math.sin(ang) * rr * 0.62 - 6.0
                pz = 34.0 + math.sin(u * math.pi * 0.48) * 32.0
                rib_pts.append((rx, py, pz))
                rib_rads.append(1.85 - 0.55 * u)
            tube(trim, rib_pts, rib_rads, 6)

    # Crown oculus stone ring & carved gold sun crest at back center of arch ring
    ring_mesh(trim, 16.0, 1.6, 14, M((0.0, 8.0, 65.5)), tube_segs=5)
    ring_mesh(gold, 3.2, 0.45, 14, M((0.0, radius * 0.62 - 8.8, 33.8), rot=(math.pi / 2, 0, 0)), tube_segs=4)

    # Coiling vines climbing east/west colonnade pillars and draping over dome ribs
    tube(wood, [(-radius + 1.5, 2.0, 0.0), (-radius + 2.0, 5.0, 16.0), (-radius + 6.0, 8.0, 34.0), (-26.0, 12.0, 54.0)], [1.4, 1.1, 0.85, 0.55], 6)
    tube(wood, [(radius - 1.5, 2.0, 0.0), (radius - 2.0, 5.0, 18.0), (radius - 8.0, 8.0, 35.0), (24.0, 11.0, 52.0)], [1.4, 1.1, 0.85, 0.55], 6)


@template("SolmereColonnadeWing", TRIM=1600, ACCENT=500, GOLD=250, WOOD=700, MOSS=500)
def solmere_colonnade_wing(t):
    """Two-tier classical Solmere fluted colonnade gallery wing draped in hanging moss & Heartroot vines."""
    trim, accent, gold, wood, moss = t.bm("TRIM"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("WOOD"), t.bm("MOSS")

    # Stepped amphitheatre foundation plinth
    box(trim, (54.0, 16.0, 4.0), M((0.0, 0.0, 2.0)), bevel=0.16)
    box(accent, (55.0, 17.0, 1.4), M((0.0, 0.0, 4.4)), bevel=0.06)

    # Lower 5 fluted columns & backing recessed wall niches
    box(trim, (50.0, 3.2, 16.0), M((0.0, 4.8, 12.5)), bevel=0.14)
    for k in range(5):
        cx = -20.0 + k * 10.0
        box(trim, (3.4, 3.4, 1.4), M((cx, -4.8, 5.4)), bevel=0.08)
        cone(trim, 1.35, 1.15, 14.5, 8, M((cx, -4.8, 5.9)))
        box(accent, (3.6, 3.6, 1.2), M((cx, -4.8, 20.5)), bevel=0.06)

    # Mid verdigris cornice gallery shelf
    box(trim, (54.0, 13.0, 2.8), M((0.0, -0.5, 22.4)), bevel=0.14)
    box(accent, (55.2, 14.0, 1.2), M((0.0, -0.5, 21.1)), bevel=0.06)
    ring_mesh(gold, 2.0, 0.35, 12, M((0.0, -6.9, 22.4), rot=(math.pi / 2, 0, 0)), tube_segs=4)

    # Upper shorter half-ruined colonnade tier (3 surviving pillars + broken wall)
    box(trim, (32.0, 3.0, 9.0), M((-6.0, 3.8, 28.2)), bevel=0.12)
    for cx in (-16.0, -6.0, 4.0, 14.0):
        h_col = 9.0 if cx < 10.0 else 5.5
        cone(trim, 1.1, 0.95, h_col, 8, M((cx, -3.8, 23.8)))
    box(trim, (34.0, 8.5, 2.2), M((-6.0, -0.8, 33.4)), bevel=0.10)
    box(accent, (35.0, 9.4, 1.0), M((-6.0, -0.8, 32.2)), bevel=0.05)

    # Sweeping Heartroot vine wrapping column & cascading moss mats
    tube(wood, [(-23.0, -6.5, 0.0), (-19.5, -5.5, 11.0), (-15.0, -6.0, 22.5), (-9.0, -4.2, 33.8)], [1.45, 1.15, 0.85, 0.55], 6)
    tube(wood, [(18.0, -6.0, 0.0), (13.0, -6.2, 9.5), (7.0, -5.8, 21.5)], [1.3, 1.0, 0.65], 6)
    rock_clean(moss, (14.0, 5.5, 2.4), M((-6.0, -2.5, 34.6)), 33, roughness=0.28, subdiv=2)
    rock_clean(moss, (12.0, 5.0, 2.2), M((14.0, -3.2, 23.8)), 34, roughness=0.28, subdiv=2)


@template("HeartrootMotherHeart", WOOD=2200, GLOW=400, MOSS=800, FOLIAGE=1400)
def heartroot_mother_heart(t):
    """Colossal glowing Heartroot Mother-Trunk rising behind the Mossbound Dais with sweeping roots and sap heart."""
    wood, glow, moss, foliage = t.bm("WOOD"), t.bm("GLOW"), t.bm("MOSS"), t.bm("FOLIAGE")

    # Massive gnarled central trunk ascending 72+ studs with splayed canopy limbs
    tube(
        wood,
        [(0.0, 4.0, 0.0), (-1.5, 5.0, 22.0), (1.0, 3.0, 44.0), (0.0, 1.0, 62.0), (-2.0, 0.0, 74.0)],
        [9.5, 7.6, 6.2, 5.0, 3.6],
        10,
    )
    # 7 sweeping surface & buttress roots fanning left, right & forward to cradle the Boss Dais
    root_specs = [
        [(0.0, 0.0, 18.0), (-10.0, -4.0, 8.0), (-19.0, -8.5, 2.0), (-24.0, -14.0, 0.0)],
        [(0.0, 0.0, 18.0), (10.0, -4.0, 8.0), (19.0, -8.5, 2.0), (24.0, -14.0, 0.0)],
        [(-3.0, 2.0, 14.0), (-12.0, 4.0, 6.0), (-21.0, 2.0, 0.5)],
        [(3.0, 2.0, 14.0), (12.0, 4.0, 6.0), (21.0, 2.0, 0.5)],
        [(0.0, 6.0, 16.0), (0.0, 16.0, 5.0), (2.0, 20.0, 0.0)],
        [(-4.0, -2.0, 12.0), (-8.0, -12.0, 4.0), (-11.0, -18.0, 0.0)],
        [(4.0, -2.0, 12.0), (8.0, -12.0, 4.0), (11.0, -18.0, 0.0)],
    ]
    for idx, pts in enumerate(root_specs):
        rads = [4.2 - i * 0.8 for i in range(len(pts))]
        tube(wood, pts, rads, 7)

    # Glowing Heartroot sap heart fissure & ascending energy veins on front trunk face (-Y)
    uvsphere(glow, 3.2, M((0.0, -5.2, 24.0), scale=(0.9, 0.55, 1.35)), u=10, v=6)
    tube(glow, [(0.0, -5.8, 14.0), (-1.4, -6.2, 24.0), (0.6, -5.0, 38.0), (-0.5, -4.0, 52.0)], [0.65, 0.9, 0.55, 0.35], 5)
    tube(glow, [(-7.0, -3.5, 10.0), (-2.0, -5.5, 20.0)], [0.45, 0.65], 5)
    tube(glow, [(7.0, -3.5, 10.0), (2.0, -5.5, 20.0)], [0.45, 0.65], 5)

    # Spreading upper boughs + lush canopy clouds at top
    boughs = [
        ((-1.0, 2.0, 52.0), (-18.0, -4.0, 64.0), (-26.0, -6.0, 68.0)),
        ((1.0, 2.0, 52.0), (18.0, -4.0, 64.0), (26.0, -6.0, 68.0)),
        ((0.0, 4.0, 56.0), (-12.0, 14.0, 68.0), (-18.0, 18.0, 72.0)),
        ((0.0, 4.0, 56.0), (12.0, 14.0, 68.0), (18.0, 18.0, 72.0)),
    ]
    for p0, p1, p2 in boughs:
        tube(wood, [p0, p1, p2], [3.2, 2.2, 1.3], 6)
        rock_clean(foliage, (20.0, 18.0, 10.0), M(p2), 40 + int(p2[0]), roughness=0.30, subdiv=2, flat_bottom=False)
    rock_clean(foliage, (28.0, 24.0, 14.0), M((0.0, 1.0, 76.0)), 49, roughness=0.32, subdiv=2, flat_bottom=False)
    rock_clean(moss, (14.0, 8.0, 2.4), M((-12.0, -6.0, 4.5)), 41, roughness=0.25, subdiv=2)
    rock_clean(moss, (14.0, 8.0, 2.4), M((12.0, -6.0, 4.5)), 42, roughness=0.25, subdiv=2)


@template("CenoteCascadeSpillway", TRIM=1000, ACCENT=350, MOSS=400, WOOD=450)
def cenote_cascade_spillway(t):
    """Stepped Solmere amphitheatre spillway channel with battered walls and mossy crown for cenote falls."""
    trim, accent, moss, wood = t.bm("TRIM"), t.bm("ACCENT"), t.bm("MOSS"), t.bm("WOOD")

    # 3 descending wide spillway steps from +Y (outer court) down toward -Y (cenote pool), grounded at z = 0
    for step in range(3):
        sy = 7.0 - step * 7.5
        sz = 21.0 - step * 6.0
        box(trim, (14.0, 9.0, 4.0), M((0.0, sy, sz - 2.0)), bevel=0.14)
        # Battered side cheek walls guiding waterfall chute
        for side in (-1, 1):
            box(trim, (4.0, 10.0, 9.0 + step * 3.0), M((side * 8.5, sy, sz - 1.5)), bevel=0.14)
            box(accent, (4.4, 10.6, 1.4), M((side * 8.5, sy, sz + 3.2 - step * 0.5)), bevel=0.06)

    # Crown cornice ledge & moss cushions
    box(trim, (22.0, 6.0, 3.5), M((0.0, 10.5, 27.5)), bevel=0.14)
    box(accent, (23.0, 6.6, 1.2), M((0.0, 10.5, 29.6)), bevel=0.06)
    for side in (-1, 1):
        rock_clean(moss, (5.0, 9.0, 2.2), M((side * 8.5, 3.0, 20.0)), 60 + side, roughness=0.26, subdiv=2)
        tube(wood, [(side * 10.2, 8.0, 9.0), (side * 9.5, 2.0, 18.0), (side * 8.8, -5.0, 26.0)], [1.1, 0.85, 0.6], 5)


@template("GlowLilyCluster", FOLIAGE=600, GLOW=500, GOLD=300, MOSS=300, WOOD=300)
def glow_lily_cluster(t):
    """Sculpted luminous emerald & gold open lily blossoms atop lush heart-leaf pads."""
    foliage, glow, gold, moss, wood = t.bm("FOLIAGE"), t.bm("GLOW"), t.bm("GOLD"), t.bm("MOSS"), t.bm("WOOD")

    # 3 overlapping mossy foliage pads
    pads = [(0.0, 0.0, 4.2), (-2.6, -1.8, 3.0), (2.4, -1.5, 2.8)]
    for idx, (px, py, r) in enumerate(pads):
        cone(foliage, r, r * 0.96, 0.45, 10, M((px, py, 0.25)))
        if idx == 0:
            rock_clean(moss, (3.2, 2.8, 0.9), M((px + 0.6, py + 0.4, 0.5)), 70, roughness=0.24, subdiv=1)

    # Two open glowing multi-petal blossoms (emerald hero flower + smaller warm gold companion flower)
    flowers = [
        (-1.0, -0.4, 2.8, 1.45, glow),
        (2.1, -1.1, 2.1, 1.05, gold),
    ]
    for fx, fy, fz, sc, petal_bm in flowers:
        tube(wood, [(fx * 0.4, fy * 0.4, 0.3), (fx * 0.85, fy * 0.85, fz * 0.55), (fx, fy, fz - 0.3)], [0.32, 0.25, 0.20], 5)
        uvsphere(gold, 0.42 * sc, M((fx, fy, fz + 0.1)), u=7, v=4)
        for k in range(6):
            ang = k * (math.pi * 2.0 / 6.0)
            px = fx + math.cos(ang) * 0.85 * sc
            py = fy + math.sin(ang) * 0.85 * sc
            box(petal_bm, (1.35 * sc, 0.65 * sc, 0.22 * sc), M((px, py, fz + 0.25), rot=(0.0, -0.42, ang)), bevel=0.04)


def build_f5():
    reset_scene()
    kit = bpy.data.collections.new("VerdantF5Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F5_TEMPLATES.items():
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


def export_f5(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "VerdantF5Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "VerdantF5Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_f5()
    export_f5(kit, manifest)
    # Render preview contact sheet using Workbench (avoids EEVEE Vulkan shader compiler stack overflow on some drivers)
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
    for n in F5_TEMPLATES:
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
        cam.location = ctr + Vector((0.55, -1.0, 0.45)).normalized() * size * 1.9
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
