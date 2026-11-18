"""
Infinite Towers: Become a Master! - Redesigned Gothic Medieval Leaderboard Monuments
===================================================================================
Sculpts the 3-leaderboard monument architecture in Blender using clean BMesh geometry
with beveled stone edges, split normals (> 34 deg), and Smart UV projection:

1. `leaderboard_pediment_frame` (used for Left: Top Robux Donated & Right: Top Playtime)
   - Gothic medieval dark-slate stepped plinth, fluted pilasters with capitals,
     pointed gothic gable pediment roof (NO crown), and obsidian rear masonry backing.
   - Encloses a 9.4 x 12.4 x 0.5 stud screen aperture centered at (0, 8.2, 0), facing -Z.

2. `leaderboard_power_monolith` (used for Middle: Top Power centerpiece)
   - Segmented obsidian stone arch monolith with chunky stepped base blocks, 13 beveled
     arch voussoir blocks, and 3 prominent carved runic keystone housings (left, apex, right).
   - Han Islate (`hero_han`) glitchy cold electric-blue neon pillar channels & arch seam
     (`Primary = rgb(70, 140, 255)`) + high-contrast ice-blue glowing keystone & arch runes
     (`Core = rgb(170, 215, 255)`) against smoky obsidian `#161822` (`rgb(22, 24, 34)`).
   - Encloses the identical 9.4 x 12.4 x 0.5 stud screen aperture at (0, 8.2, 0) for
     uniform typography across all 3 boards, while rising taller (apex y = 20.75).

Coordinate Convention:
  - Authored in Roblox Y-up space: +X east, +Y up, -Z forward toward viewer, origin at
    bottom-center ground plane (y = 0).
  - Converted to Blender Z-up via `r2b(rx, ry, rz) = (rx, -rz, ry)`.
  - Exported to FBX with `axis_forward="-Z", axis_up="Y", bake_space_transform=True`
    (matching `generate_gilded_anvil_weapons.py`), plus packed int16/uint16 BMesh shards
    into `src/ReplicatedStorage/Assets/LeaderboardMeshData.luau`.

Outputs:
  - assets/models/leaderboards/leaderboard_monuments.blend
  - assets/models/leaderboards/leaderboard_pediment_frame.fbx
  - assets/models/leaderboards/leaderboard_power_monolith.fbx
  - assets/models/leaderboards/manifest.json
  - assets/models/leaderboards/leaderboards_workbench_preview.png
  - assets/models/leaderboards/leaderboards_eevee_preview.png
  - src/ReplicatedStorage/Assets/LeaderboardMeshData.luau

Usage:
  blender -b --factory-startup --python tools/blender/generate_leaderboard_monuments.py
"""

import base64
import json
import math
import os
import re
import struct

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(REPO, "assets", "models", "leaderboards")
LUAU_DATA_PATH = os.path.join(REPO, "src", "ReplicatedStorage", "Assets", "LeaderboardMeshData.luau")
SHARDS_DIR = os.path.join(REPO, "src", "ReplicatedStorage", "Assets", "LeaderboardMeshes")


# ---------------------------------------------------------------------------
# Coordinate conversion & scene helpers
# ---------------------------------------------------------------------------

def r2b(p):
    """Roblox Y-up (rx, ry, rz) -> Blender Z-up (rx, -rz, ry)."""
    return Vector((p[0], -p[2], p[1]))


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def get_or_create_collection(name, parent=None):
    col = bpy.data.collections.get(name)
    if not col:
        col = bpy.data.collections.new(name)
        if parent is None:
            bpy.context.scene.collection.children.link(col)
        else:
            parent.children.link(col)
    return col


def make_material(name, rgb, material_enum="Slate", metallic=0.08, roughness=0.82, emit_rgb=None, emit_strength=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")

    lin = tuple((c / 255.0) ** 2.2 for c in rgb)
    bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness

    if emit_rgb and emit_strength > 0.0:
        elin = tuple((c / 255.0) ** 2.2 for c in emit_rgb)
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (elin[0], elin[1], elin[2], 1.0)
            bsdf.inputs["Emission Strength"].default_value = emit_strength
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    mat["rbx_material"] = material_enum
    mat["rbx_color"] = list(rgb)
    mat["rbx_transparency"] = 0.0
    return mat


def create_materials():
    return {
        "ped_plinth": make_material("M_PedimentPlinth", (42, 46, 58), "Slate", metallic=0.10, roughness=0.80),
        "ped_pillar": make_material("M_PedimentPillar", (54, 59, 74), "Slate", metallic=0.12, roughness=0.76),
        "ped_roof": make_material("M_PedimentRoof", (46, 50, 64), "Slate", metallic=0.10, roughness=0.78),
        "ped_back": make_material("M_PedimentBack", (24, 27, 36), "Basalt", metallic=0.08, roughness=0.86),
        "mono_base": make_material("M_MonolithBase", (34, 38, 50), "Basalt", metallic=0.12, roughness=0.80),
        "mono_arch": make_material("M_MonolithArch", (30, 34, 46), "Basalt", metallic=0.14, roughness=0.76),
        "mono_keystone": make_material("M_MonolithKeystone", (44, 49, 66), "Basalt", metallic=0.18, roughness=0.70),
        "han_blue": make_material(
            "M_HanGlitchBlue",
            (46, 128, 255),
            "Neon",
            metallic=0.0,
            roughness=0.15,
            emit_rgb=(46, 128, 255),
            emit_strength=2.2,
        ),
        "han_core": make_material(
            "M_HanIceCore",
            (130, 200, 255),
            "Neon",
            metallic=0.0,
            roughness=0.10,
            emit_rgb=(130, 200, 255),
            emit_strength=3.0,
        ),
    }


# ---------------------------------------------------------------------------
# BMesh sculptural primitives (in Roblox Y-up coordinates, converted on commit)
# ---------------------------------------------------------------------------

def merge_bmesh(dst: bmesh.types.BMesh, src: bmesh.types.BMesh):
    vmap = {}
    for v in src.verts:
        vmap[v.index] = dst.verts.new(v.co)
    for f in src.faces:
        try:
            dst.faces.new([vmap[v.index] for v in f.verts])
        except ValueError:
            pass


def add_box(bm: bmesh.types.BMesh, center, size, rot_deg=(0.0, 0.0, 0.0), bevel=0.05, segments=1):
    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.transform(tmp, matrix=Matrix.Diagonal((size[0], size[1], size[2], 1.0)), verts=tmp.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(
            tmp,
            geom=list(tmp.edges),
            offset=min(bevel, min(size) * 0.35),
            segments=segments,
            affect="EDGES",
            clamp_overlap=True,
        )
    rot = Euler([math.radians(a) for a in rot_deg], "XYZ").to_matrix().to_4x4()
    trans = Matrix.Translation(Vector(center))
    bmesh.ops.transform(tmp, matrix=trans @ rot, verts=tmp.verts)
    for v in tmp.verts:
        v.co = r2b(v.co)
    merge_bmesh(bm, tmp)
    tmp.free()


def add_prism(bm: bmesh.types.BMesh, pts_xy, z0, z1, bevel=0.04):
    """Extrudes a 2D polygon in Roblox (X, Y) from z0 to z1 with optional edge bevel."""
    tmp = bmesh.new()
    v_front = [tmp.verts.new((x, y, z0)) for (x, y) in pts_xy]
    v_back = [tmp.verts.new((x, y, z1)) for (x, y) in pts_xy]
    n = len(pts_xy)
    tmp.faces.new(list(reversed(v_front)))
    tmp.faces.new(v_back)
    for i in range(n):
        ni = (i + 1) % n
        tmp.faces.new((v_front[i], v_front[ni], v_back[ni], v_back[i]))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    if bevel > 0.0:
        bmesh.ops.bevel(
            tmp,
            geom=list(tmp.edges),
            offset=bevel,
            segments=1,
            affect="EDGES",
            clamp_overlap=True,
        )
    for v in tmp.verts:
        v.co = r2b(v.co)
    merge_bmesh(bm, tmp)
    tmp.free()


def add_strut(bm: bmesh.types.BMesh, p0, p1, width, depth, bevel=0.0):
    """Creates a clean rectangular rune/trim stroke between two Roblox 3D points."""
    a, b = Vector(p0), Vector(p1)
    delta = b - a
    length = delta.length
    if length < 1e-4:
        return
    z_axis = delta.normalized()
    hint = Vector((0, 0, 1)) if abs(z_axis.z) < 0.9 else Vector((1, 0, 0))
    x_axis = hint.cross(z_axis).normalized()
    y_axis = z_axis.cross(x_axis).normalized()
    rot = Matrix((x_axis, y_axis, z_axis)).transposed().to_4x4()
    mid = (a + b) * 0.5

    tmp = bmesh.new()
    bmesh.ops.create_cube(tmp, size=1.0)
    bmesh.ops.transform(tmp, matrix=Matrix.Diagonal((width, depth, length + width * 0.35, 1.0)), verts=tmp.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, segments=1, affect="EDGES", clamp_overlap=True)
    bmesh.ops.transform(tmp, matrix=Matrix.Translation(mid) @ rot, verts=tmp.verts)
    for v in tmp.verts:
        v.co = r2b(v.co)
    merge_bmesh(bm, tmp)
    tmp.free()


def finalize_mesh(name, bm: bmesh.types.BMesh, col, mat, collidable=True):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Split crisp edges (> 34 deg) so stylized gothic stone bevels read cleanly in Roblox
    sharp_edges = [
        e for e in bm.edges
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(34.0)
    ]
    if sharp_edges:
        bmesh.ops.split_edges(bm, edges=sharp_edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()

    # Smooth polygon flags on faceted chunks while preserving split sharp edges
    mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))

    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(mat)
    obj["rbx_collidable"] = collidable
    col.objects.link(obj)

    # Smart UV Project so Studio importer gets clean non-degenerate UVs
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.select_set(False)
    return obj


# ---------------------------------------------------------------------------
# Monument 1: Gothic Pediment Frame (Top Robux Donated & Top Playtime)
# ---------------------------------------------------------------------------

def build_pediment_frame(root_col, pal):
    col = get_or_create_collection("leaderboard_pediment_frame", root_col)

    # 1. Stepped gothic plinth & carved sill
    bm_plinth = bmesh.new()
    add_box(bm_plinth, (0, 0.36, 0.12), (13.8, 0.72, 3.30), bevel=0.08)
    add_box(bm_plinth, (0, 1.04, 0.18), (12.6, 0.64, 2.65), bevel=0.07)
    add_box(bm_plinth, (0, 1.68, 0.20), (10.9, 0.64, 2.05), bevel=0.06)
    # Decorative recessed gothic dado bosses along front plinth
    for x in (-4.4, -2.2, 0.0, 2.2, 4.4):
        add_box(bm_plinth, (x, 1.04, -1.16), (1.35, 0.36, 0.18), bevel=0.03)
    finalize_mesh("Pediment_PlinthBase", bm_plinth, col, pal["ped_plinth"], collidable=True)

    # 2. Fluted gothic pilasters, capitals, bases, and inner bevel molding
    bm_pillars = bmesh.new()
    for side in (-1.0, 1.0):
        px = side * 5.55
        # Molded pilaster foot
        add_box(bm_pillars, (px, 2.45, 0.16), (1.92, 0.90, 2.15), bevel=0.06)
        add_box(bm_pillars, (px, 3.05, 0.16), (1.72, 0.32, 1.94), bevel=0.04)
        # Main pilaster core + 4 vertical ribs creating 3 crisp carved flutes on the front
        add_box(bm_pillars, (px, 8.25, 0.25), (1.50, 10.20, 1.56), bevel=0.05)
        for rx_off in (-0.54, -0.18, 0.18, 0.54):
            add_box(bm_pillars, (px + rx_off, 8.25, -0.56), (0.18, 9.75, 0.20), bevel=0.03)
        # Side outer buttress step
        add_box(bm_pillars, (px + side * 0.74, 6.20, 0.25), (0.38, 6.20, 1.35), bevel=0.04)
        # Mid & top gothic collar bands
        add_box(bm_pillars, (px, 13.30, 0.16), (1.72, 0.30, 1.94), bevel=0.04)
        add_box(bm_pillars, (px, 13.95, 0.16), (1.96, 0.94, 2.18), bevel=0.06)
        # Inner bevel molding framing the 9.4-wide screen cleanly (inner edge at +/- 4.74)
        add_box(bm_pillars, (side * 4.84, 8.20, -0.12), (0.20, 12.46, 0.86), bevel=0.03)
    # Inner bottom & top bezel strips enclosing y = 1.98 .. 14.42
    add_box(bm_pillars, (0.0, 1.94, -0.14), (9.80, 0.20, 0.84), bevel=0.03)
    add_box(bm_pillars, (0.0, 14.46, -0.14), (9.80, 0.20, 0.84), bevel=0.03)
    finalize_mesh("Pediment_Pillars", bm_pillars, col, pal["ped_pillar"], collidable=True)

    # 3. Pointed gothic pediment roof (NO crown on top)
    bm_roof = bmesh.new()
    # Cornice & lower architrave
    add_box(bm_roof, (0.0, 14.55, 0.12), (13.0, 0.34, 2.15), bevel=0.04)
    add_box(bm_roof, (0.0, 14.94, 0.08), (13.9, 0.52, 2.45), bevel=0.06)
    # Recessed triangular tympanum back slab
    add_prism(
        bm_roof,
        [(-6.45, 15.10), (6.45, 15.10), (0.0, 18.85)],
        z0=-0.22,
        z1=1.08,
        bevel=0.04,
    )
    # Gothic pointed relief ribs inside tympanum
    add_strut(bm_roof, (-2.6, 15.20, -0.24), (0.0, 17.65, -0.24), 0.34, 0.22, bevel=0.03)
    add_strut(bm_roof, (2.6, 15.20, -0.24), (0.0, 17.65, -0.24), 0.34, 0.22, bevel=0.03)
    add_box(bm_roof, (0.0, 16.05, -0.24), (0.34, 1.65, 0.22), bevel=0.03)

    # Sloped raking cornice beams meeting at pointed apex (y = 19.35)
    for side in (-1.0, 1.0):
        p_eave = Vector((side * 7.25, 14.88, -0.02))
        p_peak = Vector((0.0, 19.22, -0.02))
        span = p_peak - p_eave
        mid = (p_eave + p_peak) * 0.5
        ang_z = math.degrees(math.atan2(span.y, span.x))
        add_box(bm_roof, (mid.x, mid.y, -0.02), (span.length + 0.55, 0.72, 2.48), rot_deg=(0, 0, ang_z), bevel=0.06)
        # Upper stepped cap trim molding
        add_box(bm_roof, (mid.x, mid.y + 0.42, -0.06), (span.length + 0.72, 0.28, 2.66), rot_deg=(0, 0, ang_z), bevel=0.04)
    # Apex stone cap block
    add_box(bm_roof, (0.0, 19.36, -0.04), (1.05, 0.72, 2.58), rot_deg=(0, 0, 45), bevel=0.05)
    finalize_mesh("Pediment_GableRoof", bm_roof, col, pal["ped_roof"], collidable=True)

    # 4. Solid obsidian backing behind screen + rear gothic buttress ribs
    bm_back = bmesh.new()
    add_box(bm_back, (0.0, 8.20, 0.78), (10.10, 12.60, 1.02), bevel=0.05)
    for bx in (-3.0, 0.0, 3.0):
        add_box(bm_back, (bx, 8.20, 1.24), (0.68, 12.10, 0.36), bevel=0.04)
    finalize_mesh("Pediment_ObsidianBacking", bm_back, col, pal["ped_back"], collidable=True)

    return col


# ---------------------------------------------------------------------------
# Monument 2: Power Runic Arch Monolith (Top Power — Han Islate Glitchy Blue)
# ---------------------------------------------------------------------------

def _arch_point(theta_deg: float, radius: float, center_y: float = 12.5):
    rad = math.radians(theta_deg)
    return Vector((math.sin(rad) * radius, center_y + math.cos(rad) * radius))


def build_power_monolith(root_col, pal):
    col = get_or_create_collection("leaderboard_power_monolith", root_col)
    arch_cy = 14.05

    # 1. Chunky segmented obsidian stepped base (matches Reference Image 3 silhouette)
    bm_base = bmesh.new()
    add_box(bm_base, (0.0, 0.40, 0.16), (14.4, 0.80, 3.55), bevel=0.07)
    add_box(bm_base, (0.0, 1.15, 0.22), (10.6, 0.72, 2.55), bevel=0.06)
    add_box(bm_base, (0.0, 1.78, 0.22), (9.80, 0.54, 2.05), bevel=0.05)
    # Flanking pillar channel base blocks (split left/right of the glowing channel at x = +/-5.75)
    for side in (-1.0, 1.0):
        px = side * 5.75
        add_box(bm_base, (px - side * 0.62, 1.18, 0.14), (0.86, 1.48, 2.85), bevel=0.05)
        add_box(bm_base, (px + side * 0.62, 1.18, 0.14), (0.86, 1.48, 2.85), bevel=0.05)
        add_box(bm_base, (px, 1.18, 0.65), (1.95, 1.48, 1.75), bevel=0.05)
        add_box(bm_base, (side * 6.95, 0.75, 0.18), (1.10, 1.45, 2.95), bevel=0.06)
    finalize_mesh("Monolith_SteppedBase", bm_base, col, pal["mono_base"], collidable=True)

    # 2. Segmented obsidian pillar courses, arched voussoirs & spandrel backing
    bm_arch = bmesh.new()
    # 7 individually beveled stone blocks per pillar rising cleanly to arch spring (y = 14.05)
    for side in (-1.0, 1.0):
        px = side * 5.75
        for row in range(7):
            y0 = 2.05 + row * 1.72
            yc = y0 + 0.83
            w_scale = 1.0 - row * 0.012
            add_box(bm_arch, (px - 0.60 * w_scale, yc, -0.02), (0.76 * w_scale, 1.62, 2.15), bevel=0.06)
            add_box(bm_arch, (px + 0.60 * w_scale, yc, -0.02), (0.76 * w_scale, 1.62, 2.15), bevel=0.06)
            add_box(bm_arch, (px, yc, 0.54), (1.92 * w_scale, 1.64, 1.08), bevel=0.05)

    # 13 segmented arched stone blocks curving from -84 deg to +84 deg around center (0, 14.05)
    num_arch = 13
    for i in range(num_arch):
        t = -84.0 + i * (168.0 / (num_arch - 1))
        pt = _arch_point(t, 5.75, arch_cy)
        pt_in = _arch_point(t, 5.20, arch_cy)
        pt_out = _arch_point(t, 6.30, arch_cy)
        add_box(bm_arch, (pt_in.x, pt_in.y, -0.02), (1.12, 0.78, 2.08), rot_deg=(0, 0, -t), bevel=0.05)
        add_box(bm_arch, (pt_out.x, pt_out.y, -0.02), (1.28, 0.82, 2.08), rot_deg=(0, 0, -t), bevel=0.05)
        add_box(bm_arch, (pt.x, pt.y, 0.56), (1.22, 1.84, 1.04), rot_deg=(0, 0, -t), bevel=0.05)

    # Arched obsidian backing slab behind the screen (curves seamlessly behind screen top)
    add_box(bm_arch, (0.0, 8.20, 0.82), (10.10, 12.60, 1.08), bevel=0.05)
    spandrel_pts = [(-4.85, 13.95)]
    for k in range(13):
        ang = -75.0 + k * (150.0 / 12)
        p = _arch_point(ang, 5.05, arch_cy)
        spandrel_pts.append((p.x, p.y))
    spandrel_pts.append((4.85, 13.95))
    add_prism(bm_arch, spandrel_pts, z0=0.28, z1=1.32, bevel=0.04)

    # Inner dark bezel frame around the screen (left/right/bottom; arch spandrel frames top seamlessly)
    for side in (-1.0, 1.0):
        add_box(bm_arch, (side * 4.82, 8.20, -0.08), (0.20, 12.46, 0.76), bevel=0.03)
    add_box(bm_arch, (0.0, 1.94, -0.08), (9.80, 0.22, 0.76), bevel=0.03)

    # Rear gothic stone buttress ribs on +Z face
    for bx in (-2.8, 0.0, 2.8):
        add_box(bm_arch, (bx, 9.60, 1.38), (0.72, 15.00, 0.36), bevel=0.04)
    finalize_mesh("Monolith_ArchStones", bm_arch, col, pal["mono_arch"], collidable=True)

    # 3. Three Prominent Carved Keystone Housings (uniform 2.55 depth so recessed socket z = -1.355 matches all 3)
    bm_keys = bmesh.new()
    key_specs = [
        (-46.0, 6.12, (2.25, 2.55, 2.55), (1.65, 1.85, 0.25)),
        (0.0, 6.40, (2.45, 2.95, 2.55), (1.75, 2.15, 0.25)),
        (46.0, 6.12, (2.25, 2.55, 2.55), (1.65, 1.85, 0.25)),
    ]
    for ang_deg, rad_dist, outer_sz, inner_sz in key_specs:
        pt = _arch_point(ang_deg, rad_dist, arch_cy)
        add_box(bm_keys, (pt.x, pt.y, -0.08), outer_sz, rot_deg=(0, 0, -ang_deg), bevel=0.10, segments=2)
        rad_r = math.radians(ang_deg)
        ux, uy = math.cos(rad_r), -math.sin(rad_r)
        vx, vy = math.sin(rad_r), math.cos(rad_r)
        bx, by = pt.x, pt.y
        hw, hh = inner_sz[0] * 0.5 + 0.14, inner_sz[1] * 0.5 + 0.14
        for sx in (-hw, hw):
            add_box(bm_keys, (bx + ux * sx, by + uy * sx, -1.34), (0.28, inner_sz[1] + 0.45, 0.24), rot_deg=(0, 0, -ang_deg), bevel=0.04)
        for sy in (-hh, hh):
            add_box(bm_keys, (bx + vx * sy, by + vy * sy, -1.34), (inner_sz[0] + 0.45, 0.28, 0.24), rot_deg=(0, 0, -ang_deg), bevel=0.04)
    finalize_mesh("Monolith_Keystones", bm_keys, col, pal["mono_keystone"], collidable=True)

    # 4. Han Islate Glitchy Electric-Blue Channels (segmented broken glitch pulses + jagged shards)
    bm_glitch = bmesh.new()
    for side in (-1.0, 1.0):
        px = side * 5.75
        # Segmented vertical energy pulses (with crisp dark gaps between glitch segments)
        segments_y = [
            (0.45, 2.35, 0.00),
            (2.55, 4.65, -0.05),
            (4.85, 6.95, 0.06),
            (7.15, 9.45, -0.04),
            (9.65, 11.75, 0.05),
            (11.95, 13.95, 0.00),
        ]
        for y0, y1, gx in segments_y:
            yc = (y0 + y1) * 0.5
            add_box(bm_glitch, (px + side * gx, yc, -0.58), (0.30, y1 - y0, 0.50), bevel=0.02)
        # Sharp stepped Han Islate digital/arcane glitch shards along the trench edges
        glitch_shards = [
            (1.6, 0.16, 0.36, 0.22),
            (3.1, -0.18, 0.48, 0.32),
            (5.3, 0.18, 0.42, 0.24),
            (6.5, -0.16, 0.52, 0.36),
            (8.2, 0.19, 0.44, 0.28),
            (10.3, -0.17, 0.50, 0.34),
            (12.6, 0.15, 0.38, 0.26),
        ]
        for gy, gx_off, gw, gh in glitch_shards:
            add_box(bm_glitch, (px + side * gx_off, gy, -0.84), (gw, gh, 0.18), bevel=0.01)

    # Curved glowing arch channel segments running cleanly between keystones
    arch_arc_ranges = [(-83.0, -56.0, 5), (-35.0, -11.0, 5), (11.0, 35.0, 5), (56.0, 83.0, 5)]
    for t0, t1, steps in arch_arc_ranges:
        for s in range(steps):
            a0 = t0 + (t1 - t0) * (s / steps)
            a1 = t0 + (t1 - t0) * ((s + 0.78) / steps)
            p0 = _arch_point(a0, 5.75, arch_cy)
            p1 = _arch_point(a1, 5.75, arch_cy)
            add_strut(bm_glitch, (p0.x, p0.y, -0.62), (p1.x, p1.y, -0.62), 0.28, 0.42, bevel=0.01)
            if s % 2 == 1:
                pm = _arch_point((a0 + a1) * 0.5, 5.84, arch_cy)
                add_box(bm_glitch, (pm.x, pm.y, -0.86), (0.38, 0.18, 0.16), rot_deg=(0, 0, -(a0 + a1) * 0.5), bevel=0.01)
    finalize_mesh("Monolith_GlitchChannels", bm_glitch, col, pal["han_blue"], collidable=False)

    # 5. Han Islate High-Contrast Ice-Blue Keystone Runes (Core = rgb(130, 200, 255))
    bm_runes = bmesh.new()

    def add_local_rune_stroke(ang_deg, rad_dist, p0_loc, p1_loc, w=0.14):
        c = _arch_point(ang_deg, rad_dist, arch_cy)
        rad_r = math.radians(ang_deg)
        ux, uy = math.cos(rad_r), -math.sin(rad_r)
        vx, vy = math.sin(rad_r), math.cos(rad_r)
        # All 3 keystones have front face at z = -1.355; inset rune proud at z = -1.39
        a = (c.x + ux * p0_loc[0] + vx * p0_loc[1], c.y + uy * p0_loc[0] + vy * p0_loc[1], -1.39)
        b = (c.x + ux * p1_loc[0] + vx * p1_loc[1], c.y + uy * p1_loc[0] + vy * p1_loc[1], -1.39)
        add_strut(bm_runes, a, b, w, 0.18, bevel=0.01)

    # Left keystone glyph
    for p0, p1 in [
        ((-0.38, 0.55), (-0.38, -0.45)),
        ((-0.38, -0.45), (0.36, -0.15)),
        ((0.36, -0.15), (0.0, 0.62)),
        ((-0.10, 0.10), (0.40, 0.45)),
    ]:
        add_local_rune_stroke(-46.0, 6.12, p0, p1, w=0.14)

    # Apex centerpiece glyph (Han Islate sharp lightning / power sigil)
    for p0, p1 in [
        ((-0.44, 0.72), (0.44, 0.72)),
        ((0.44, 0.72), (-0.34, 0.05)),
        ((-0.34, 0.05), (0.38, 0.05)),
        ((0.38, 0.05), (-0.30, -0.75)),
        ((0.0, 0.92), (0.0, -0.88)),
    ]:
        add_local_rune_stroke(0.0, 6.40, p0, p1, w=0.16)

    # Right keystone glyph
    for p0, p1 in [
        ((-0.42, 0.48), (0.42, 0.48)),
        ((-0.36, 0.48), (-0.36, -0.52)),
        ((0.0, 0.48), (0.0, -0.25)),
        ((0.36, 0.48), (0.36, -0.52)),
        ((-0.36, -0.10), (0.36, -0.10)),
    ]:
        add_local_rune_stroke(46.0, 6.12, p0, p1, w=0.14)

    # Subtle glowing runic glyphs etched cleanly on the inner arch spandrel stone (clear of the channel)
    for sub_ang in (-26.0, -17.0, 17.0, 26.0, -68.0, 68.0):
        c = _arch_point(sub_ang, 5.18, arch_cy)
        rad_r = math.radians(sub_ang)
        ux, uy = math.cos(rad_r), -math.sin(rad_r)
        vx, vy = math.sin(rad_r), math.cos(rad_r)
        z_f = -1.07
        pts = [
            ((-0.09, -0.20), (-0.09, 0.20)),
            ((-0.09, 0.20), (0.13, 0.05)),
            ((-0.09, -0.02), (0.11, -0.18)),
        ]
        for s0, s1 in pts:
            pa = (c.x + ux * s0[0] + vx * s0[1], c.y + uy * s0[0] + vy * s0[1], z_f)
            pb = (c.x + ux * s1[0] + vx * s1[1], c.y + uy * s1[0] + vy * s1[1], z_f)
            add_strut(bm_runes, pa, pb, 0.065, 0.08, bevel=0.0)

    finalize_mesh("Monolith_KeystoneRunes", bm_runes, col, pal["han_core"], collidable=False)

    return col


# ---------------------------------------------------------------------------
# Export (FBX + Manifest + Packed BMesh Luau Data + Dual Blender Renders)
# ---------------------------------------------------------------------------

def extract_part_geometry(obj, root_col):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.verts.ensure_lookup_table()

    # Convert Blender Z-up back to Roblox Y-up: (bx, by, bz) -> (bx, bz, -by)
    pts = [(v.co.x, v.co.z, -v.co.y) for v in bm.verts]
    xs, ys, zs = [p[0] for p in pts], [p[1] for p in pts], [p[2] for p in pts]
    cx, cy, cz = (min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5

    flat_verts = []
    for px, py, pz in pts:
        flat_verts.extend([round(px - cx, 4), round(py - cy, 4), round(pz - cz, 4)])
    flat_tris = []
    for f in bm.faces:
        if len(f.verts) == 3:
            flat_tris.extend([f.verts[0].index + 1, f.verts[1].index + 1, f.verts[2].index + 1])
    bm.free()

    mat = obj.data.materials[0] if obj.data.materials else None
    clean_name = re.sub(r"\.\d+$", "", obj.name)
    return {
        "Name": clean_name,
        "SubCollection": root_col.name,
        "Offset": [round(cx, 4), round(cy, 4), round(cz, 4)],
        "Size": [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)],
        "Material": mat.get("rbx_material", "Slate") if mat else "Slate",
        "Color": list(mat.get("rbx_color", [34, 38, 49])) if mat else [34, 38, 49],
        "Collidable": bool(obj.get("rbx_collidable", True)),
        "MeshId": "",
        "Verts": flat_verts,
        "Tris": flat_tris,
    }


def load_uploaded_mesh_ids():
    path = os.path.join(OUT_DIR, "mesh_ids.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def export_monument(name, col):
    os.makedirs(OUT_DIR, exist_ok=True)
    objs = [o for o in col.all_objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active = objs[0]
    fbx_path = os.path.join(OUT_DIR, f"{name}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="EDGE",
        add_leaf_bones=False,
        bake_anim=False,
        use_mesh_modifiers=True,
        bake_space_transform=True,
    )
    uploaded = load_uploaded_mesh_ids().get(name, {})
    parts_full, parts_summary, tri_count = [], [], 0
    for obj in objs:
        pinfo = extract_part_geometry(obj, col)
        pinfo["MeshId"] = uploaded.get(pinfo["Name"], "")
        tri_count += len(pinfo["Tris"]) // 3
        parts_full.append(pinfo)
        parts_summary.append({k: v for k, v in pinfo.items() if k not in ("Verts", "Tris")})
    return (
        {"TemplateId": name, "FBX": os.path.basename(fbx_path), "Triangles": tri_count, "Parts": parts_summary},
        parts_full,
    )


def _encode_part_buffers(p):
    verts, tris = p["Verts"], p["Tris"]
    sx, sy, sz = p["Size"]
    hx, hy, hz = max(1e-5, sx * 0.5), max(1e-5, sy * 0.5), max(1e-5, sz * 0.5)
    vbuf = bytearray()
    for i in range(0, len(verts), 3):
        qx = max(-32767, min(32767, round((verts[i] / hx) * 32767.0)))
        qy = max(-32767, min(32767, round((verts[i + 1] / hy) * 32767.0)))
        qz = max(-32767, min(32767, round((verts[i + 2] / hz) * 32767.0)))
        vbuf.extend(struct.pack("<hhh", qx, qy, qz))
    tbuf = bytearray()
    for i in range(0, len(tris), 3):
        tbuf.extend(struct.pack("<HHH", tris[i], tris[i + 1], tris[i + 2]))
    return base64.b64encode(bytes(vbuf)).decode("ascii"), base64.b64encode(bytes(tbuf)).decode("ascii")


def write_luau_mesh_modules(all_parts_by_id):
    os.makedirs(SHARDS_DIR, exist_ok=True)
    for tid, parts in all_parts_by_id.items():
        shard_path = os.path.join(SHARDS_DIR, f"{tid}.luau")
        lines = [
            "--!nocheck",
            f"-- ReplicatedStorage/Assets/LeaderboardMeshes/{tid}.luau",
            "-- Generated directly from Blender geometry (tools/blender/generate_leaderboard_monuments.py).",
            "",
            "return {",
        ]
        for p in parts:
            c, o, s = p["Color"], p["Offset"], p["Size"]
            vb, tb = _encode_part_buffers(p)
            col_lit = "true" if p["Collidable"] else "false"
            mesh_lit = f'"{p.get("MeshId", "")}"'
            lines.extend([
                "\t{",
                f'\t\tName = "{p["Name"]}", SubCollection = "{p["SubCollection"]}",',
                f"\t\tOffset = Vector3.new({o[0]}, {o[1]}, {o[2]}), Size = Vector3.new({s[0]}, {s[1]}, {s[2]}),",
                f'\t\tMaterial = Enum.Material.{p["Material"]}, Color = Color3.fromRGB({c[0]}, {c[1]}, {c[2]}),',
                f"\t\tCollidable = {col_lit}, MeshId = {mesh_lit},",
                f'\t\tVB = "{vb}",',
                f'\t\tTB = "{tb}",',
                "\t},",
            ])
        lines.append("}")
        with open(shard_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")
        print(f"Wrote leaderboard shard: {shard_path} ({os.path.getsize(shard_path)} bytes)")

    model_keys = ",\n".join(f'\t{tid} = unpackModel(MeshesFolder:WaitForChild("{tid}"))' for tid in all_parts_by_id.keys())
    loader_src = f"""--!strict
-- ReplicatedStorage/Assets/LeaderboardMeshData.luau
-- Decodes Blender-authored monument geometry shards from ReplicatedStorage.Assets.LeaderboardMeshes.

local LeaderboardMeshData = {{}}

export type PartMeshSpec = {{
\tName: string,
\tSubCollection: string,
\tOffset: Vector3,
\tSize: Vector3,
\tMaterial: Enum.Material,
\tColor: Color3,
\tCollidable: boolean,
\tMeshId: string,
\tVB: string?,
\tTB: string?,
\tVerts: {{ number }}?,
\tTris: {{ number }}?,
}}

local B64_LOOKUP = table.create(256, -1)
do
\tlocal alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
\tfor i = 1, #alphabet do
\t\tB64_LOOKUP[string.byte(alphabet, i)] = i - 1
\tend
end

local function decodeBase64(str: string): buffer
\tlocal len = #str
\tlocal pad = if len >= 2 and string.sub(str, len - 1, len) == "==" then 2 elseif len >= 1 and string.sub(str, len, len) == "=" then 1 else 0
\tlocal outLen = (len // 4) * 3 - pad
\tlocal buf = buffer.create(outLen)
\tlocal outPos = 0
\tfor i = 1, len, 4 do
\t\tlocal a = B64_LOOKUP[string.byte(str, i)] or 0
\t\tlocal b = B64_LOOKUP[string.byte(str, i + 1)] or 0
\t\tlocal c = B64_LOOKUP[string.byte(str, i + 2)]
\t\tlocal d = B64_LOOKUP[string.byte(str, i + 3)]
\t\tlocal bits = bit32.lshift(a, 18) + bit32.lshift(b, 12) + bit32.lshift(if c and c >= 0 then c else 0, 6) + (if d and d >= 0 then d else 0)
\t\tif outPos < outLen then
\t\t\tbuffer.writeu8(buf, outPos, bit32.band(bit32.rshift(bits, 16), 255))
\t\t\toutPos += 1
\t\tend
\t\tif outPos < outLen then
\t\t\tbuffer.writeu8(buf, outPos, bit32.band(bit32.rshift(bits, 8), 255))
\t\t\toutPos += 1
\t\tend
\t\tif outPos < outLen then
\t\t\tbuffer.writeu8(buf, outPos, bit32.band(bits, 255))
\t\t\toutPos += 1
\t\tend
\tend
\treturn buf
end

local function unpackVerts(vb: string, size: Vector3): {{ number }}
\tlocal buf = decodeBase64(vb)
\tlocal nBytes = buffer.len(buf)
\tlocal verts = table.create(nBytes // 2)
\tlocal hx = math.max(1e-5, size.X * 0.5) / 32767
\tlocal hy = math.max(1e-5, size.Y * 0.5) / 32767
\tlocal hz = math.max(1e-5, size.Z * 0.5) / 32767
\tfor off = 0, nBytes - 6, 6 do
\t\tverts[#verts + 1] = buffer.readi16(buf, off) * hx
\t\tverts[#verts + 1] = buffer.readi16(buf, off + 2) * hy
\t\tverts[#verts + 1] = buffer.readi16(buf, off + 4) * hz
\tend
\treturn verts
end

local function unpackTris(tb: string): {{ number }}
\tlocal buf = decodeBase64(tb)
\tlocal nBytes = buffer.len(buf)
\tlocal tris = table.create(nBytes // 2)
\tfor off = 0, nBytes - 2, 2 do
\t\ttris[#tris + 1] = buffer.readu16(buf, off)
\tend
\treturn tris
end

local function unpackModel(shardModule: Instance): {{ PartMeshSpec }}
\tlocal rawList = require(shardModule :: ModuleScript) :: {{ any }}
\tlocal unpacked = table.create(#rawList)
\tfor _, raw in ipairs(rawList) do
\t\tunpacked[#unpacked + 1] = {{
\t\t\tName = raw.Name,
\t\t\tSubCollection = raw.SubCollection,
\t\t\tOffset = raw.Offset,
\t\t\tSize = raw.Size,
\t\t\tMaterial = raw.Material,
\t\t\tColor = raw.Color,
\t\t\tCollidable = raw.Collidable,
\t\t\tMeshId = raw.MeshId or "",
\t\t\tVB = raw.VB,
\t\t\tTB = raw.TB,
\t\t\tVerts = raw.Verts,
\t\t\tTris = raw.Tris,
\t\t}}
\tend
\treturn unpacked
end

function LeaderboardMeshData.GetGeometry(spec: PartMeshSpec): ({{ number }}, {{ number }})
\tif not spec.Verts then
\t\tspec.Verts = if spec.VB then unpackVerts(spec.VB, spec.Size) else {{}}
\tend
\tif not spec.Tris then
\t\tspec.Tris = if spec.TB then unpackTris(spec.TB) else {{}}
\tend
\treturn spec.Verts :: {{ number }}, spec.Tris :: {{ number }}
end

local MeshesFolder = (script.Parent :: Instance):WaitForChild("LeaderboardMeshes")

LeaderboardMeshData.Models = {{
{model_keys}
}} :: {{ [string]: {{ PartMeshSpec }} }}

return LeaderboardMeshData
"""
    os.makedirs(os.path.dirname(LUAU_DATA_PATH), exist_ok=True)
    with open(LUAU_DATA_PATH, "w", encoding="utf-8") as f:
        f.write(loader_src)
    print(f"Wrote Luau mesh data loader: {LUAU_DATA_PATH}")


def setup_preview_and_save(ped_col, mono_col):
    # Clone pediment for right wing so preview showcases the full 3-board crescent
    right_col = get_or_create_collection("leaderboard_pediment_right_preview")
    for obj in ped_col.objects:
        dup = obj.copy()
        dup.data = obj.data
        right_col.objects.link(dup)

    def place_col(col, rx, ry, rz, yaw_deg):
        loc = r2b((rx, ry, rz))
        rot = Euler((0.0, 0.0, math.radians(yaw_deg)), "XYZ")
        for obj in col.objects:
            obj.location = loc
            obj.rotation_euler = rot

    # Left: Top Robux Donated, Center: Top Power (+0.6 lift), Right: Top Playtime
    place_col(ped_col, -15.2, 0.0, 2.5, 18.0)
    place_col(mono_col, 0.0, 0.6, 0.0, 0.0)
    place_col(right_col, 15.2, 0.0, 2.5, -18.0)

    # Save .blend file first
    blend_path = os.path.join(OUT_DIR, "leaderboard_monuments.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"Saved Blender file: {blend_path}")

    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 30
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    # Camera sits in front (-Z Roblox -> +Y Blender) looking at center monument
    cam.location = r2b((0.0, 11.2, -52.0))
    target = r2b((0.0, 10.2, 0.0))
    cam.rotation_euler = (target - cam.location).normalized().to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam

    # 1. Workbench Cavity Preview
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 920
    world = bpy.data.worlds.new("LBPreviewWorld")
    scene.world = world
    world.color = (0.10, 0.11, 0.15)
    wb_png = os.path.join(OUT_DIR, "leaderboards_workbench_preview.png")
    scene.render.filepath = wb_png
    bpy.ops.render.render(write_still=True)
    print(f"Rendered Workbench preview: {wb_png}")

    # 2. EEVEE Emission Preview
    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.03, 0.035, 0.055, 1.0)
        bg.inputs[1].default_value = 1.0
    for lname, rpos, energy, col_rgb in [
        ("KeyLight", (-14, 28, -36), 8500, (0.92, 0.95, 1.0)),
        ("FillLight", (18, 18, -32), 4500, (0.76, 0.88, 1.0)),
        ("BlueRim", (0, 24, 18), 5500, (0.32, 0.58, 1.0)),
    ]:
        ld = bpy.data.lights.new(lname, type="AREA")
        ld.energy = energy
        ld.color = col_rgb
        ld.size = 14.0
        lo = bpy.data.objects.new(lname, ld)
        lo.location = r2b(rpos)
        lo.rotation_euler = (target - lo.location).normalized().to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lo)
    eevee_png = os.path.join(OUT_DIR, "leaderboards_eevee_preview.png")
    scene.render.filepath = eevee_png
    bpy.ops.render.render(write_still=True)
    print(f"Rendered EEVEE preview: {eevee_png}")


def main():
    clear_scene()
    root_col = get_or_create_collection("LeaderboardMonuments")
    pal = create_materials()

    ped_col = build_pediment_frame(root_col, pal)
    mono_col = build_power_monolith(root_col, pal)

    manifest, all_parts = {}, {}
    for tid, col in [
        ("leaderboard_pediment_frame", ped_col),
        ("leaderboard_power_monolith", mono_col),
    ]:
        summary, full_parts = export_monument(tid, col)
        manifest[tid] = summary
        all_parts[tid] = full_parts
        print(f"[leaderboards] {tid:28s} tris={summary['Triangles']:5d} parts={len(summary['Parts'])}")

    with open(os.path.join(OUT_DIR, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    write_luau_mesh_modules(all_parts)
    setup_preview_and_save(ped_col, mono_col)


if __name__ == "__main__":
    main()
