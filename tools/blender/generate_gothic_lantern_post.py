"""
=============================================================================
Infinite Towers: Become a Master! - 3D Environment Asset Pipeline
Asset: Gothic Medieval Lantern Post (`GothicLanternPost`)
Target: Blender 4.x / 5.x -> FBX -> Roblox Studio (`ReplicatedStorage.Assets.Props.GothicLanternPost`)
Plan: courtyard_lamp_replacement_plan (1).md
=============================================================================
Generates the Blender-authored Gothic Medieval Lantern Post strictly under
2,200 triangles, with:
  - Origin (0, 0, 0) at exact bottom-center of `Lantern_StoneBase` (Y = 0)
  - Scale: 1 Blender unit = 1 Roblox stud (14.0 studs total height, 2.4x2.4 plinth)
  - Forward axis: -Z (timber crossbeam & hanging lantern project toward -Z)
  - Sub-meshes:
      Lantern_StoneBase    (weathered dark-slate stone plinth + ground pad)
      Lantern_BaseFrame    (notched corner timber posts, top rails & 4 kick-braces)
      Lantern_TimberPost   (vertical grooved dark-timber column & neck)
      Lantern_TimberArm    (overhanging horizontal -Z timber crossbeam)
      Lantern_Ironwork     (straps, bolts, wall-plate, S-scroll bracket, apex finial)
      Lantern_Cage         (suspension loop, stepped pyramidal hood, 4-sided frame, drop)
      Lantern_Glass        (4 translucent smoked amber glass panes)
      Lantern_CandleCore   (pillar candle + emissive flame core)
  - Socket Empty:
      VFX_LanternLight     (parented to Lantern_CandleCore at flame position)
  - Export:
      assets/meshes/GothicLanternPost.fbx

Usage:
  blender --background --python tools/blender/generate_gothic_lantern_post.py
=============================================================================
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_FBX_PATH = os.path.join(REPO_ROOT, "assets", "meshes", "GothicLanternPost.fbx")
COLLECTION_NAME = "GothicLanternPost"
MAX_TRIS_BUDGET = 2200

# Roblox -> Blender coordinate mapping for FBX export with (axis_forward='-Z', axis_up='Y'):
# Blender (+X, +Y, +Z) maps to Roblox (+X, -Z, +Y).
def rbx_to_bl(x: float, y: float, z: float) -> Vector:
    return Vector((x, -z, y))


MATERIAL_SPECS = {
    "Mat_GothicSlateStone": ("#3A3D45", 0.06, 0.86, "#000000", 0.0, 1.0),
    "Mat_DarkGroovedTimber": ("#3D2B1F", 0.02, 0.78, "#000000", 0.0, 1.0),
    "Mat_WroughtIron": ("#18181C", 0.85, 0.42, "#000000", 0.0, 1.0),
    "Mat_SmokedAmberGlass": ("#D99B52", 0.05, 0.14, "#F59E0B", 0.15, 0.35),
    "Mat_LanternCandleGlow": ("#F59E0B", 0.00, 0.25, "#FFF3B0", 3.5, 1.0),
}


def hex_to_rgba(hex_str: str, alpha: float = 1.0):
    h = hex_str.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    # Convert sRGB hex -> linear approximation for Blender Principled BSDF
    lin = tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b))
    return (lin[0], lin[1], lin[2], alpha)


def get_or_create_materials():
    mats = {}
    for name, (hex_col, metallic, roughness, emit_hex, emit_str, alpha) in MATERIAL_SPECS.items():
        mat = bpy.data.materials.get(name) or bpy.data.materials.new(name=name)
        mat.use_nodes = True
        nt = mat.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        bsdf.inputs["Base Color"].default_value = hex_to_rgba(hex_col, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
        if "Alpha" in bsdf.inputs:
            bsdf.inputs["Alpha"].default_value = alpha
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = hex_to_rgba(emit_hex, 1.0)
            bsdf.inputs["Emission Strength"].default_value = emit_str
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        if alpha < 1.0:
            mat.blend_method = "BLEND" if hasattr(mat, "blend_method") else mat.blend_method
        mats[name] = mat
    return mats


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0


def add_rbx_box(bm: bmesh.types.BMesh, center_rbx, size_rbx, rot_euler_rbx=(0.0, 0.0, 0.0), bevel_amt: float = 0.0):
    """Creates an axis-aligned or rotated box in Roblox coords inside bmesh."""
    sx, sy, sz = size_rbx
    bm_tmp = bmesh.new()
    bmesh.ops.create_cube(bm_tmp, size=1.0)
    # Transform from unit cube into Roblox local size -> rotate -> translate -> convert to Blender
    mat_scale = Matrix.Diagonal((sx, sy, sz, 1.0))
    mat_rot = Euler(rot_euler_rbx, "XYZ").to_matrix().to_4x4()
    mat_trans = Matrix.Translation(Vector(center_rbx))
    m_rbx = mat_trans @ mat_rot @ mat_scale

    if bevel_amt > 0.0:
        # Work in Roblox-scaled space before final transform so bevel is uniform in studs
        bmesh.ops.transform(bm_tmp, matrix=mat_scale, verts=bm_tmp.verts)
        bmesh.ops.bevel(
            bm_tmp,
            geom=list(bm_tmp.edges),
            offset=bevel_amt,
            segments=1,
            affect="EDGES",
            clamp_overlap=True,
        )
        m_after = mat_trans @ mat_rot
        bmesh.ops.transform(bm_tmp, matrix=m_after, verts=bm_tmp.verts)
    else:
        bmesh.ops.transform(bm_tmp, matrix=m_rbx, verts=bm_tmp.verts)

    for v in bm_tmp.verts:
        v.co = rbx_to_bl(v.co.x, v.co.y, v.co.z)

    merge_bmesh(bm, bm_tmp)
    bm_tmp.free()


def add_rbx_taper_frustum(
    bm: bmesh.types.BMesh,
    center_xz: tuple,
    y0: float,
    y1: float,
    w0x: float,
    w0z: float,
    w1x: float,
    w1z: float,
    cap_bottom: bool = True,
    cap_top: bool = True,
):
    """Creates a tapered 4-sided frustum between Y=y0 and Y=y1 in Roblox coords."""
    cx, cz = center_xz
    hx0, hz0 = w0x * 0.5, w0z * 0.5
    hx1, hz1 = w1x * 0.5, w1z * 0.5

    pts_bot = [
        rbx_to_bl(cx - hx0, y0, cz - hz0),
        rbx_to_bl(cx + hx0, y0, cz - hz0),
        rbx_to_bl(cx + hx0, y0, cz + hz0),
        rbx_to_bl(cx - hx0, y0, cz + hz0),
    ]
    pts_top = [
        rbx_to_bl(cx - hx1, y1, cz - hz1),
        rbx_to_bl(cx + hx1, y1, cz - hz1),
        rbx_to_bl(cx + hx1, y1, cz + hz1),
        rbx_to_bl(cx - hx1, y1, cz + hz1),
    ]
    vb = [bm.verts.new(p) for p in pts_bot]
    vt = [bm.verts.new(p) for p in pts_top]
    for i in range(4):
        ni = (i + 1) % 4
        bm.faces.new((vb[i], vb[ni], vt[ni], vt[i]))
    if cap_bottom:
        bm.faces.new((vb[3], vb[2], vb[1], vb[0]))
    if cap_top:
        bm.faces.new((vt[0], vt[1], vt[2], vt[3]))


def add_rbx_strut(bm: bmesh.types.BMesh, p0_rbx, p1_rbx, w_thickness: float, h_thickness: float):
    """Creates a rectangular bar connecting two 3D points in Roblox space."""
    v0 = Vector(p0_rbx)
    v1 = Vector(p1_rbx)
    delta = v1 - v0
    length = delta.length
    if length < 1e-5:
        return
    z_axis = delta.normalized()
    up_hint = Vector((1.0, 0.0, 0.0)) if abs(z_axis.x) < 0.8 else Vector((0.0, 1.0, 0.0))
    x_axis = up_hint.cross(z_axis).normalized()
    y_axis = z_axis.cross(x_axis).normalized()

    rot = Matrix((x_axis, y_axis, z_axis)).transposed().to_4x4()
    center = (v0 + v1) * 0.5
    m_rbx = Matrix.Translation(center) @ rot

    hw, hh, hl = w_thickness * 0.5, h_thickness * 0.5, length * 0.5
    corners_local = [
        Vector((-hw, -hh, -hl)),
        Vector((hw, -hh, -hl)),
        Vector((hw, hh, -hl)),
        Vector((-hw, hh, -hl)),
        Vector((-hw, -hh, hl)),
        Vector((hw, -hh, hl)),
        Vector((hw, hh, hl)),
        Vector((-hw, hh, hl)),
    ]
    verts = []
    for c in corners_local:
        wp = m_rbx @ c
        verts.append(bm.verts.new(rbx_to_bl(wp.x, wp.y, wp.z)))
    faces = [
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    ]
    for f in faces:
        bm.faces.new(tuple(verts[i] for i in f))


def add_swept_iron_bar_yz(bm: bmesh.types.BMesh, pts_yz: list, width_x: float, height_t: float, x_center: float = 0.0, closed: bool = False):
    """Sweeps a rectangular wrought-iron strip along a curve in the Roblox (Y, Z) plane."""
    n = len(pts_yz)
    if n < 2:
        return
    rings = []
    hx = width_x * 0.5
    ht = height_t * 0.5

    for i, (py, pz) in enumerate(pts_yz):
        if closed:
            p_prev = pts_yz[(i - 1) % n]
            p_next = pts_yz[(i + 1) % n]
        elif i == 0:
            p_prev = pts_yz[0]
            p_next = pts_yz[1]
        elif i == n - 1:
            p_prev = pts_yz[-2]
            p_next = pts_yz[-1]
        else:
            p_prev = pts_yz[i - 1]
            p_next = pts_yz[i + 1]

        ty = p_next[0] - p_prev[0]
        tz = p_next[1] - p_prev[1]
        t_len = math.hypot(ty, tz) or 1.0
        ty /= t_len
        tz /= t_len
        # Normal perpendicular to tangent in YZ plane: (-tz, ty)
        ny, nz = -tz, ty

        corners = [
            rbx_to_bl(x_center - hx, py - ny * ht, pz - nz * ht),
            rbx_to_bl(x_center + hx, py - ny * ht, pz - nz * ht),
            rbx_to_bl(x_center + hx, py + ny * ht, pz + nz * ht),
            rbx_to_bl(x_center - hx, py + ny * ht, pz + nz * ht),
        ]
        rings.append([bm.verts.new(c) for c in corners])

    seg_count = n if closed else n - 1
    for i in range(seg_count):
        r0 = rings[i]
        r1 = rings[(i + 1) % n]
        for k in range(4):
            nk = (k + 1) % 4
            bm.faces.new((r0[k], r0[nk], r1[nk], r1[k]))

    if not closed:
        bm.faces.new((rings[0][3], rings[0][2], rings[0][1], rings[0][0]))
        bm.faces.new((rings[-1][0], rings[-1][1], rings[-1][2], rings[-1][3]))


def add_extruded_xy_silhouette(bm: bmesh.types.BMesh, pts_xy_half: list, y_offset: float, depth_z: float, z_center: float = 0.0, taper_edge: float = 0.45):
    """Builds a symmetric 3D sculpted Gothic finial blade in Roblox X/Y with chamfered front/back ridge."""
    # pts_xy_half: list of (rx >= 0, ry_local) from base to tip
    # Creates mirrored left (-X) and right (+X) profile around a thick center spine at x=0
    left_pts = [(-x, y + y_offset) for (x, y) in pts_xy_half]
    right_pts = [(x, y + y_offset) for (x, y) in pts_xy_half]
    hz = depth_z * 0.5
    hz_edge = hz * taper_edge

    # Build spine + outer edge slices per row for clean low-poly 3D relief
    rows = []
    for i, ((lx, ly), (rx, _)) in enumerate(zip(left_pts, right_pts)):
        # Row vertices: left-front, spine-front, right-front, right-back, spine-back, left-back
        # Wait: at x=0 tip or base, collapse cleanly or keep slight offset for valid manifold
        if abs(rx) < 1e-4:
            # Apex tip point (single tip vertex or tight cluster)
            v_tip = bm.verts.new(rbx_to_bl(0.0, ly, z_center))
            rows.append(("TIP", v_tip))
        else:
            vf_l = bm.verts.new(rbx_to_bl(lx, ly, z_center - hz_edge))
            vf_m = bm.verts.new(rbx_to_bl(0.0, ly, z_center - hz))
            vf_r = bm.verts.new(rbx_to_bl(rx, ly, z_center - hz_edge))
            vb_r = bm.verts.new(rbx_to_bl(rx, ly, z_center + hz_edge))
            vb_m = bm.verts.new(rbx_to_bl(0.0, ly, z_center + hz))
            vb_l = bm.verts.new(rbx_to_bl(lx, ly, z_center + hz_edge))
            rows.append(("ROW", (vf_l, vf_m, vf_r, vb_r, vb_m, vb_l)))

    # Cap base
    if rows[0][0] == "ROW":
        r0 = rows[0][1]
        bm.faces.new((r0[0], r0[1], r0[4], r0[5]))
        bm.faces.new((r0[1], r0[2], r0[3], r0[4]))

    for i in range(len(rows) - 1):
        kind0, d0 = rows[i]
        kind1, d1 = rows[i + 1]
        if kind0 == "ROW" and kind1 == "ROW":
            for k in range(6):
                nk = (k + 1) % 6
                bm.faces.new((d0[k], d0[nk], d1[nk], d1[k]))
        elif kind0 == "ROW" and kind1 == "TIP":
            for k in range(6):
                nk = (k + 1) % 6
                bm.faces.new((d0[k], d0[nk], d1))


def add_cylinder_y(bm: bmesh.types.BMesh, center_xz: tuple, y0: float, y1: float, r0: float, r1: float, segs: int = 8):
    cx, cz = center_xz
    vb, vt = [], []
    for i in range(segs):
        a = (2.0 * math.pi * i) / segs
        ca, sa = math.cos(a), math.sin(a)
        vb.append(bm.verts.new(rbx_to_bl(cx + ca * r0, y0, cz + sa * r0)))
        vt.append(bm.verts.new(rbx_to_bl(cx + ca * r1, y1, cz + sa * r1)))
    for i in range(segs):
        ni = (i + 1) % segs
        bm.faces.new((vb[i], vb[ni], vt[ni], vt[i]))
    bm.faces.new(tuple(reversed(vb)))
    bm.faces.new(tuple(vt))


def merge_bmesh(dst: bmesh.types.BMesh, src: bmesh.types.BMesh):
    vert_map = {}
    for v in src.verts:
        vert_map[v] = dst.verts.new(v.co)
    for f in src.faces:
        try:
            dst.faces.new(tuple(vert_map[v] for v in f.verts))
        except ValueError:
            pass


# =============================================================================
# SUB-MESH BUILDERS
# =============================================================================

def build_stone_base() -> bmesh.types.BMesh:
    bm = bmesh.new()
    # Ground slate patio slab pad at Y = 0.00 .. 0.14 (matches stepped dark plinth footing in reference)
    add_rbx_box(bm, (0.0, 0.07, 0.0), (2.82, 0.14, 2.82), bevel_amt=0.04)
    # Main weathered dark-slate stone plinth cube at Y = 0.14 .. 2.14 (nested inside 2.4x2.4 timber corner frame)
    add_rbx_box(bm, (0.0, 1.14, 0.0), (2.14, 2.00, 2.14), bevel_amt=0.06)
    # Subtle stepped mortar stone plinth cap shoulder at Y = 2.08 .. 2.22
    add_rbx_box(bm, (0.0, 2.15, 0.0), (1.40, 0.14, 1.40), bevel_amt=0.04)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def build_base_frame() -> bmesh.types.BMesh:
    bm = bmesh.new()
    # 4 vertical notched corner timber posts around the stone block (2.4 x 2.4 footprint)
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            add_rbx_box(bm, (sx * 1.10, 1.16, sz * 1.10), (0.24, 2.12, 0.24), bevel_amt=0.025)

    # 4 horizontal notched timber collar rails wrapping the upper edge of the stone plinth
    for sz in (-1.0, 1.0):
        add_rbx_box(bm, (0.0, 2.18, sz * 1.10), (2.52, 0.24, 0.22), bevel_amt=0.025)
    for sx in (-1.0, 1.0):
        add_rbx_box(bm, (sx * 1.10, 2.18, 0.0), (0.22, 0.24, 2.52), bevel_amt=0.025)

    # 4 diagonal wooden kick-braces meeting the lower vertical post (matches reference Image 4)
    brace_dirs = ((1, 0), (-1, 0), (0, 1), (0, -1))
    for dx, dz in brace_dirs:
        p0 = (dx * 0.94, 2.16, dz * 0.94)
        p1 = (dx * 0.30, 3.04, dz * 0.30)
        add_rbx_strut(bm, p0, p1, 0.20, 0.20)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def build_timber_post() -> bmesh.types.BMesh:
    """Deep-grooved dark vertical timber pillar from Y=2.16 to Y=12.22."""
    bm = bmesh.new()
    # Chamfered fluted square cross-section (16-vertex ring forming subtle woodgrain grooves on all 4 faces!)
    def grooved_ring(half_w: float, groove_in: float):
        hw = half_w
        ch = half_w * 0.84
        g = half_w - groove_in
        gv = half_w * 0.32
        # Ordered CCW around Y-up in (rx, rz)
        return [
            (ch, -hw), (gv, -hw), (gv * 0.45, -g), (-gv * 0.45, -g), (-gv, -hw), (-ch, -hw),
            (-hw, -ch), (-hw, -gv), (-g, -gv * 0.45), (-g, gv * 0.45), (-hw, gv), (-hw, ch),
            (-ch, hw), (-gv, hw), (-gv * 0.45, g), (gv * 0.45, g), (gv, hw), (ch, hw),
            (hw, ch), (hw, gv), (g, gv * 0.45), (g, -gv * 0.45), (hw, -gv), (hw, -ch),
        ]

    # Wait: keep polygon count ultra-lean! 12-vertex grooved octagon keeps grooves visible under < 140 tris!
    def lean_ring(hw: float, ch: float, gi: float):
        return [
            (ch, -hw), (0.0, -hw + gi), (-ch, -hw),
            (-hw, -ch), (-hw + gi, 0.0), (-hw, ch),
            (-ch, hw), (0.0, hw - gi), (ch, hw),
            (hw, ch), (hw - gi, 0.0), (hw, -ch),
        ]

    # Segment 1: main vertical post shaft (Y = 2.16 .. 12.16)
    y_bot, y_top = 2.16, 12.16
    pts_bot = lean_ring(0.39, 0.30, 0.055)
    pts_top = lean_ring(0.37, 0.28, 0.050)
    vb = [bm.verts.new(rbx_to_bl(px, y_bot, pz)) for (px, pz) in pts_bot]
    vt = [bm.verts.new(rbx_to_bl(px, y_top, pz)) for (px, pz) in pts_top]
    n = len(pts_bot)
    for i in range(n):
        ni = (i + 1) % n
        bm.faces.new((vb[i], vb[ni], vt[ni], vt[i]))
    bm.faces.new(tuple(reversed(vb)))
    bm.faces.new(tuple(vt))

    # Segment 2: upper wooden tenon cap above crossbeam (Y = 12.16 .. 12.42)
    add_rbx_box(bm, (0.0, 12.29, 0.0), (0.72, 0.26, 0.72), bevel_amt=0.04)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def build_timber_arm() -> bmesh.types.BMesh:
    """Horizontal overhanging timber crossbeam extending along -Z at Y = 11.78."""
    bm = bmesh.new()
    # Center z = -1.06, length = 3.58 -> spans z = +0.73 (rear tail) to z = -2.85 (front tip along -Z!)
    add_rbx_box(bm, (0.0, 11.78, -1.06), (0.58, 0.66, 3.58), bevel_amt=0.045)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def build_ironwork() -> bmesh.types.BMesh:
    """Wrought-iron bands, bolts, ornate S-scroll bracket, wall-plate & apex fleur-de-lis finial."""
    bm = bmesh.new()

    # 1. Lower wrought-iron collar band clamping vertical post right above kick-braces (Y = 3.06 .. 3.30)
    add_rbx_box(bm, (0.0, 3.18, 0.0), (0.86, 0.24, 0.86), bevel_amt=0.02)
    # Upper wrought-iron strap band right under the crossbeam joint (Y = 11.12 .. 11.34)
    add_rbx_box(bm, (0.0, 11.23, 0.0), (0.84, 0.22, 0.84), bevel_amt=0.02)
    # Bolt studs on collar bands (cardinal faces)
    for y_band in (3.18, 11.23):
        for sx, sz in ((0.44, 0), (-0.44, 0), (0, 0.44), (0, -0.44)):
            add_rbx_box(bm, (sx, y_band, sz), (0.07, 0.07, 0.07))

    # 2. Vertical wrought-iron wall-plate on the -Z face of the post + rivet studs
    add_rbx_box(bm, (0.0, 10.05, -0.42), (0.34, 1.80, 0.09), bevel_amt=0.02)
    add_rbx_box(bm, (0.0, 9.05, -0.43), (0.20, 0.24, 0.09), rot_euler_rbx=(0, 0, math.radians(45)))
    add_rbx_box(bm, (0.0, 11.02, -0.43), (0.20, 0.24, 0.09), rot_euler_rbx=(0, 0, math.radians(45)))

    # 3. Sculpted wrought-iron S-scroll bracket (from post wall plate -> crossbeam -> front spiral hook)
    # Curve authored in Roblox (Y, Z) where Z < 0 projects toward -Z
    s_scroll_pts = [
        (9.38, -0.44),
        (9.85, -0.58),
        (10.35, -0.84),
        (10.82, -1.20),
        (11.16, -1.58),
        (11.25, -1.96),
        (11.08, -2.30),
        (10.74, -2.48),
        (10.36, -2.42),
        (10.16, -2.18),
        (10.22, -1.94),
        (10.45, -1.86),
        (10.64, -1.98),
    ]
    add_swept_iron_bar_yz(bm, s_scroll_pts, width_x=0.11, height_t=0.14, x_center=0.0)

    # Inner reverse C-scroll flourish under the crossbeam corner (matches Image 4!)
    inner_curl_pts = [
        (10.72, -0.44),
        (11.06, -0.56),
        (11.34, -0.82),
        (11.28, -1.08),
        (11.02, -1.16),
        (10.82, -1.02),
    ]
    add_swept_iron_bar_yz(bm, inner_curl_pts, width_x=0.09, height_t=0.11, x_center=0.0)

    # Short iron mount lug bolting top of S-scroll arch into bottom of timber crossbeam
    add_rbx_box(bm, (0.0, 11.36, -1.78), (0.14, 0.28, 0.22))

    # 4. Stepped iron finial base cap on top of post (Y = 12.40 .. 12.66)
    add_rbx_box(bm, (0.0, 12.48, 0.0), (0.78, 0.16, 0.78), bevel_amt=0.025)
    add_rbx_taper_frustum(bm, (0.0, 0.0), 12.56, 12.74, 0.56, 0.56, 0.26, 0.26)

    # 5. Gothic Fleur-de-Lis Apex Finial (Y = 12.74 .. 14.00)
    # Central tall spearhead petal reaching Y = 14.00
    center_petal = [
        (0.11, 0.00),
        (0.08, 0.22),
        (0.20, 0.58),
        (0.16, 0.92),
        (0.07, 1.12),
        (0.00, 1.26),
    ]
    add_extruded_xy_silhouette(bm, center_petal, y_offset=12.74, depth_z=0.16, z_center=0.0)
    # Horizontal iron clasp collar around base of petals
    add_rbx_box(bm, (0.0, 12.92, 0.0), (0.48, 0.10, 0.20), bevel_amt=0.015)

    # Left & Right sweeping fleur-de-lis outer petals (smooth tapered forged curves sprouting from clasp)
    for sx in (-1.0, 1.0):
        # 6-point graceful arch curve in Roblox (X, Y) plane, extruded with slight Z taper
        curve_pts = [
            (sx * 0.06, 12.88, 0.085),
            (sx * 0.24, 12.98, 0.075),
            (sx * 0.41, 13.18, 0.065),
            (sx * 0.45, 13.42, 0.055),
            (sx * 0.34, 13.56, 0.040),
            (sx * 0.20, 13.48, 0.022),
        ]
        rings = []
        for idx, (px, py, rad) in enumerate(curve_pts):
            nxt = curve_pts[min(idx + 1, len(curve_pts) - 1)]
            prv = curve_pts[max(idx - 1, 0)]
            tx, ty = nxt[0] - prv[0], nxt[1] - prv[1]
            tlen = math.hypot(tx, ty) or 1.0
            nx, ny = -ty / tlen, tx / tlen
            hz_seg = rad * 0.85
            ring_coords = [
                rbx_to_bl(px - nx * rad, py - ny * rad, -hz_seg),
                rbx_to_bl(px + nx * rad, py + ny * rad, -hz_seg),
                rbx_to_bl(px + nx * rad, py + ny * rad, hz_seg),
                rbx_to_bl(px - nx * rad, py - ny * rad, hz_seg),
            ]
            rings.append([bm.verts.new(c) for c in ring_coords])
        for j in range(len(rings) - 1):
            r0, r1 = rings[j], rings[j + 1]
            for k in range(4):
                nk = (k + 1) % 4
                bm.faces.new((r0[k], r0[nk], r1[nk], r1[k]))
        bm.faces.new((rings[0][3], rings[0][2], rings[0][1], rings[0][0]))
        bm.faces.new((rings[-1][0], rings[-1][1], rings[-1][2], rings[-1][3]))

        # Lower forged scroll spur curling outward under clasp
        add_rbx_strut(bm, (sx * 0.12, 12.88, 0.0), (sx * 0.36, 12.74, 0.0), 0.08, 0.08)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def build_lantern_cage() -> bmesh.types.BMesh:
    """Hanging 4-sided tapered wrought-iron Gothic lantern housing at Z = -2.20."""
    bm = bmesh.new()
    lz = -2.20

    # Suspension iron link connecting scroll hook (Y=10.16, Z=-2.18) down to lantern hood apex (Y=9.88)
    add_rbx_box(bm, (0.0, 10.14, lz), (0.08, 0.34, 0.22), bevel_amt=0.02)
    add_cylinder_y(bm, (0.0, lz), 9.84, 10.00, 0.15, 0.11, segs=8)

    # Two-tier stepped pyramidal hood roof (overhanging eaves + steep spire cap)
    add_rbx_taper_frustum(bm, (0.0, lz), 9.48, 9.86, 0.94, 0.94, 0.28, 0.28)
    add_rbx_taper_frustum(bm, (0.0, lz), 9.26, 9.50, 1.66, 1.66, 0.92, 0.92)
    # Upper eaves rim collar (just above glass panes)
    add_rbx_box(bm, (0.0, 9.24, lz), (1.50, 0.10, 1.50), bevel_amt=0.015)

    # Bottom cage tray collar & base cup + drop finial (Y = 7.12 .. 7.82)
    add_rbx_box(bm, (0.0, 7.77, lz), (1.06, 0.12, 1.06), bevel_amt=0.015)
    add_rbx_taper_frustum(bm, (0.0, lz), 7.42, 7.72, 0.42, 0.42, 0.98, 0.98)
    add_cylinder_y(bm, (0.0, lz), 7.12, 7.44, 0.03, 0.18, segs=8)

    # 4 slender tapered corner mullions joining upper frame (hw=0.66) to lower frame (hw=0.47)
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            p_top = (sx * 0.66, 9.22, lz + sz * 0.66)
            p_bot = (sx * 0.47, 7.78, lz + sz * 0.47)
            add_rbx_strut(bm, p_top, p_bot, 0.08, 0.08)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def build_lantern_glass() -> bmesh.types.BMesh:
    """4 translucent smoked amber tapered glass panes cleanly inset inside the cage mullions."""
    bm = bmesh.new()
    lz = -2.20
    y_bot, y_top = 7.82, 9.19
    in_bot, in_top = 0.44, 0.62
    out_bot, out_top = 0.46, 0.64

    # 4 panes (+X, -X, +Z, -Z) oriented facing outward cleanly
    panes = [
        # (corner_b0, corner_b1, corner_t1, corner_t0) -> 4 outer + 4 inner faces for solid thin glass slab
        # Front (-Z)
        ((-out_bot + 0.05, y_bot, lz - out_bot), (out_bot - 0.05, y_bot, lz - out_bot),
         (out_top - 0.05, y_top, lz - out_top), (-out_top + 0.05, y_top, lz - out_top), (0, 0, 0.02)),
        # Back (+Z)
        ((out_bot - 0.05, y_bot, lz + out_bot), (-out_bot + 0.05, y_bot, lz + out_bot),
         (-out_top + 0.05, y_top, lz + out_top), (out_top - 0.05, y_top, lz + out_top), (0, 0, -0.02)),
        # Left (-X)
        ((-out_bot, y_bot, lz + out_bot - 0.05), (-out_bot, y_bot, lz - out_bot + 0.05),
         (-out_top, y_top, lz - out_top + 0.05), (-out_top, y_top, lz + out_top - 0.05), (0.02, 0, 0)),
        # Right (+X)
        ((out_bot, y_bot, lz - out_bot + 0.05), (out_bot, y_bot, lz + out_bot - 0.05),
         (out_top, y_top, lz + out_top - 0.05), (out_top, y_top, lz - out_top + 0.05), (-0.02, 0, 0)),
    ]
    for p0, p1, p2, p3, off in panes:
        pts_o = [p0, p1, p2, p3]
        pts_i = [(p[0] + off[0], p[1] + off[1], p[2] + off[2]) for p in pts_o]
        vo = [bm.verts.new(rbx_to_bl(*p)) for p in pts_o]
        vi = [bm.verts.new(rbx_to_bl(*p)) for p in pts_i]
        bm.faces.new(tuple(vo))
        bm.faces.new(tuple(reversed(vi)))
        for k in range(4):
            nk = (k + 1) % 4
            bm.faces.new((vi[k], vi[nk], vo[nk], vo[k]))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def build_candle_core() -> bmesh.types.BMesh:
    """Inner pillar candle and glowing teardrop flame inside lantern housing."""
    bm = bmesh.new()
    lz = -2.20
    # Pillar wax candle body (Y = 7.82 .. 8.50)
    add_cylinder_y(bm, (0.0, lz), 7.82, 8.50, 0.19, 0.175, segs=8)
    # Sculpted teardrop flame (Y = 8.52 .. 8.98)
    add_cylinder_y(bm, (0.0, lz), 8.52, 8.66, 0.06, 0.115, segs=8)
    add_cylinder_y(bm, (0.0, lz), 8.66, 8.98, 0.115, 0.015, segs=8)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    return bm


def mesh_from_bm(name: str, bm: bmesh.types.BMesh, mat: bpy.types.Material, collection: bpy.types.Collection, smooth: bool = False) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def apply_smart_uv(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    try:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
    except Exception as exc:
        print(f"[GothicLanternPost] Smart UV warning: {exc}")
        try:
            bpy.ops.object.mode_set(mode="OBJECT")
        except Exception:
            pass


def apply_auto_smooth(objs):
    for obj in objs:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        try:
            if hasattr(bpy.ops.object, "shade_auto_smooth"):
                bpy.ops.object.shade_auto_smooth(angle=math.radians(35.0))
            elif hasattr(bpy.ops.object, "shade_smooth_by_angle"):
                bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35.0))
            else:
                bpy.ops.object.shade_smooth()
        except Exception:
            pass


def build_gothic_lantern_post(export_fbx_path: str = DEFAULT_FBX_PATH, preview_png_path: str = ""):
    reset_scene()
    mats = get_or_create_materials()
    col = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(col)

    obj_stone = mesh_from_bm("Lantern_StoneBase", build_stone_base(), mats["Mat_GothicSlateStone"], col)
    obj_frame = mesh_from_bm("Lantern_BaseFrame", build_base_frame(), mats["Mat_DarkGroovedTimber"], col)
    obj_post = mesh_from_bm("Lantern_TimberPost", build_timber_post(), mats["Mat_DarkGroovedTimber"], col)
    obj_arm = mesh_from_bm("Lantern_TimberArm", build_timber_arm(), mats["Mat_DarkGroovedTimber"], col)
    obj_iron = mesh_from_bm("Lantern_Ironwork", build_ironwork(), mats["Mat_WroughtIron"], col, smooth=True)
    obj_cage = mesh_from_bm("Lantern_Cage", build_lantern_cage(), mats["Mat_WroughtIron"], col)
    obj_glass = mesh_from_bm("Lantern_Glass", build_lantern_glass(), mats["Mat_SmokedAmberGlass"], col)
    obj_candle = mesh_from_bm("Lantern_CandleCore", build_candle_core(), mats["Mat_LanternCandleGlow"], col, smooth=True)

    mesh_objs = [obj_stone, obj_frame, obj_post, obj_arm, obj_iron, obj_cage, obj_glass, obj_candle]
    apply_smart_uv(mesh_objs)
    apply_auto_smooth([obj_iron, obj_candle])

    # VFX Empty socket placed inside the hanging lantern at the exact candle flame center (0, 8.75, -2.20)
    vfx_empty = bpy.data.objects.new("VFX_LanternLight", None)
    vfx_empty.empty_display_type = "PLAIN_AXES"
    vfx_empty.empty_display_size = 0.45
    vfx_empty.location = rbx_to_bl(0.0, 8.75, -2.20)
    vfx_empty.parent = obj_candle
    col.objects.link(vfx_empty)

    tri_counts = {o.name: len(o.data.polygons) for o in mesh_objs}
    total_tris = sum(tri_counts.values())
    print(f"[GothicLanternPost] Tri counts per mesh: {tri_counts}")
    print(f"[GothicLanternPost] Total triangles: {total_tris} / {MAX_TRIS_BUDGET}")
    assert total_tris < MAX_TRIS_BUDGET, f"Triangle budget exceeded: {total_tris} >= {MAX_TRIS_BUDGET}"

    # Verify bounds (min Y == 0.0, max Y == 14.0, overhang along Blender +Y == Roblox -Z)
    all_ws = [v.co for o in mesh_objs for v in o.data.vertices]
    min_bz = min(v.z for v in all_ws)
    max_bz = max(v.z for v in all_ws)
    max_by = max(v.y for v in all_ws)  # Roblox -Z forward
    print(f"[GothicLanternPost] Bounds Height(Y): {min_bz:.3f}..{max_bz:.3f} studs | Forward(-Z) max reach: {max_by:.3f} studs")

    if export_fbx_path:
        os.makedirs(os.path.dirname(os.path.abspath(export_fbx_path)), exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for o in mesh_objs:
            o.select_set(True)
        vfx_empty.select_set(True)
        bpy.context.view_layer.objects.active = obj_stone
        fbx_kwargs = dict(
            filepath=export_fbx_path,
            use_selection=True,
            object_types={"MESH", "EMPTY"},
            use_mesh_modifiers=True,
            mesh_smooth_type="FACE",
            axis_forward="-Z",
            axis_up="Y",
            apply_unit_scale=True,
            apply_scale_options="FBX_SCALE_UNITS",
            bake_space_transform=False,
        )
        bpy.ops.export_scene.fbx(**fbx_kwargs)
        print(f"[GothicLanternPost] Exported FBX to: {export_fbx_path}")

    if preview_png_path:
        _render_preview(preview_png_path)

    return mesh_objs, tri_counts, total_tris


def _render_preview(out_png: str):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.render.resolution_x = 768
    scene.render.resolution_y = 1152

    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.04, 0.05, 0.08, 1.0)
        bg.inputs["Strength"].default_value = 0.75

    # Moody rim key + warm candle point light
    sun_data = bpy.data.lights.new("MoonSun", type="SUN")
    sun_data.energy = 2.0
    sun_data.color = (0.72, 0.80, 1.0)
    sun = bpy.data.objects.new("MoonSun", sun_data)
    sun.rotation_euler = Euler((math.radians(50), math.radians(15), math.radians(135)), "XYZ")
    scene.collection.objects.link(sun)

    pt_data = bpy.data.lights.new("CandleLight", type="POINT")
    pt_data.energy = 850.0
    pt_data.color = (1.0, 0.58, 0.20)
    pt_data.shadow_soft_size = 0.25
    pt = bpy.data.objects.new("CandleLight", pt_data)
    pt.location = rbx_to_bl(0.0, 8.75, -2.20)
    scene.collection.objects.link(pt)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 38.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    cam.location = rbx_to_bl(-8.5, 8.2, -13.5)
    target = rbx_to_bl(0.0, 7.0, -0.8)
    direction = (target - cam.location).normalized()
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam

    os.makedirs(os.path.dirname(os.path.abspath(out_png)), exist_ok=True)
    scene.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    print(f"[GothicLanternPost] Rendered preview to: {out_png}")


if __name__ == "__main__":
    preview = ""
    if "--preview" in sys.argv:
        idx = sys.argv.index("--preview")
        if idx + 1 < len(sys.argv):
            preview = sys.argv[idx + 1]
    build_gothic_lantern_post(DEFAULT_FBX_PATH, preview)
