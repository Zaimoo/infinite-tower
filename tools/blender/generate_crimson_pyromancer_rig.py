"""
=============================================================================
Infinite Towers: Become a Master!
Blender 4.x / 5.x Procedural Hero Rig Generator (v4 - Signature Pose & Bangs)
Character: Eolka — Crimson Pyromancer (5★–7★ Ascended Costume / Model Replacement)
Target Engine: Zero-Humanoid Client RenderStepped Pipeline (EntityRenderer.luau)
=============================================================================
Constructs the stylized Robloxified anime Crimson Pyromancer character rig:
  - Contiguous 15-part R15 hierarchy with exact anatomical Right (-X) / Left (+X)
  - Sleek anime-proportioned Roblox Head with angular-unwrapped UV face decal
  - Lush copper-orange 3D hair with full forehead-framing curtain bangs, center
    strand, ornate gold crown cuff, sweeping high ponytail, and wind-swept locks
  - High gold collar + glowing crimson-amber ruby brooch at the throat hollow
  - Sweetheart crimson velvet & obsidian gothic corset with porcelain upper-chest
    cutout panels and raised 3D gold V-piping
  - Asymmetric black & crimson-lined shoulder capelet with bold gold shoulder filigree
  - Flowing split gothic maxi skirt with 3D gold hip & hem baroque scrollwork
  - Ornate gold wrist bracers + forward-reaching upturned right-palm casting pose
    holding a hovering multi-layered Solar Fire Orb in front of her right hand
  - Strictly within the 2,500 to 4,200 triangle performance budget (~3,880 tris)
=============================================================================
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix, Euler


# ---------------------------------------------------------------------------
# 1. COLOR PALETTE & PBR MATERIAL DEFINITIONS
# ---------------------------------------------------------------------------
def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_rgba(hex_str: str, alpha: float = 1.0) -> tuple:
    h = hex_str.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    return (srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b), alpha)


PALETTE = {
    "Zone1_ObsidianCloth": {
        "hex": "#16121D",
        "roughness": 0.76,
        "metallic": 0.05,
        "emission": None,
        "strength": 0.0,
    },
    "Zone2_CrimsonVelvet": {
        "hex": "#A41D18",
        "roughness": 0.54,
        "metallic": 0.08,
        "emission": None,
        "strength": 0.0,
    },
    "Zone2_DeepCrimsonLining": {
        "hex": "#7D1612",
        "roughness": 0.62,
        "metallic": 0.05,
        "emission": None,
        "strength": 0.0,
    },
    "Zone3_RoyalGold": {
        "hex": "#ECC371",
        "roughness": 0.22,
        "metallic": 0.88,
        "emission": None,
        "strength": 0.0,
    },
    "Zone4_CopperHair": {
        "hex": "#DC5220",
        "roughness": 0.46,
        "metallic": 0.04,
        "emission": None,
        "strength": 0.0,
    },
    "Zone4_HairHighlight": {
        "hex": "#F58032",
        "roughness": 0.40,
        "metallic": 0.06,
        "emission": None,
        "strength": 0.0,
    },
    "Zone5_PorcelainSkin": {
        "hex": "#F7DFC6",
        "roughness": 0.60,
        "metallic": 0.00,
        "emission": None,
        "strength": 0.0,
    },
    "Zone6_RubyEmissive": {
        "hex": "#FF3B1F",
        "roughness": 0.15,
        "metallic": 0.10,
        "emission": "#FF3B1F",
        "strength": 4.2,
    },
    "Zone6_FireOrbCore": {
        "hex": "#FFF6C0",
        "roughness": 0.05,
        "metallic": 0.00,
        "emission": "#FFE875",
        "strength": 8.0,
    },
    "Zone6_FireOrbRibbon": {
        "hex": "#FF6B1A",
        "roughness": 0.15,
        "metallic": 0.00,
        "emission": "#FF5208",
        "strength": 5.2,
    },
}

WORLD_PIVOTS = {}


# ---------------------------------------------------------------------------
# 2. SCENE CLEANUP (SAFE FOR LIVE BLENDER MCP SESSION)
# ---------------------------------------------------------------------------
def setup_clean_collection(collection_name: str = "CrimsonPyromancer_Rig"):
    WORLD_PIVOTS.clear()
    if bpy.context.active_object and bpy.context.active_object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")

    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)

    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)

    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for curve in list(bpy.data.curves):
        if curve.users == 0:
            bpy.data.curves.remove(curve)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)

    rig_col = bpy.data.collections.new(collection_name)
    bpy.context.scene.collection.children.link(rig_col)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    return rig_col


def build_materials() -> dict:
    mats = {}
    for name, spec in PALETTE.items():
        mat = bpy.data.materials.new(name=name)
        mat.use_nodes = True
        rgba = hex_to_rgba(spec["hex"])

        mat.diffuse_color = rgba
        mat.roughness = spec["roughness"]
        mat.metallic = spec["metallic"]

        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = rgba
            bsdf.inputs["Roughness"].default_value = spec["roughness"]
            bsdf.inputs["Metallic"].default_value = spec["metallic"]
            if spec["emission"]:
                em_rgba = hex_to_rgba(spec["emission"])
                if "Emission Color" in bsdf.inputs:
                    bsdf.inputs["Emission Color"].default_value = em_rgba
                elif "Emission" in bsdf.inputs:
                    bsdf.inputs["Emission"].default_value = em_rgba
                if "Emission Strength" in bsdf.inputs:
                    bsdf.inputs["Emission Strength"].default_value = spec["strength"]
        mats[name] = mat

    # Special textured Face Material using hero_pyromancer_face_preview.png
    face_mat = bpy.data.materials.new(name="Zone5_FaceDecal")
    face_mat.use_nodes = True
    face_mat.diffuse_color = hex_to_rgba("#F7DFC6")
    face_mat.roughness = 0.60
    nodes = face_mat.node_tree.nodes
    links = face_mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Roughness"].default_value = 0.60
        face_img_path = r"c:\WORK\infinite-tower\assets\faces\hero_pyromancer_face_preview.png"
        if os.path.exists(face_img_path):
            tex_node = nodes.new("ShaderNodeTexImage")
            img = bpy.data.images.load(face_img_path, check_existing=True)
            img.reload()
            tex_node.image = img
            tex_node.extension = "EXTEND"
            links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            bsdf.inputs["Base Color"].default_value = hex_to_rgba("#F7DFC6")
    mats["Zone5_FaceDecal"] = face_mat
    return mats


# ---------------------------------------------------------------------------
# 3. HIERARCHY & GEOMETRY HELPERS (EXACT WORLD -> LOCAL OFFSET MATH)
# ---------------------------------------------------------------------------
def set_world_pivot(obj, world_pos: Vector):
    WORLD_PIVOTS[obj.name] = world_pos.copy()
    obj.location = world_pos.copy()


def parent_keep_world(child_obj, parent_obj):
    c_world = WORLD_PIVOTS.get(child_obj.name, child_obj.location.copy())
    p_world = WORLD_PIVOTS.get(parent_obj.name, parent_obj.location.copy())
    child_obj.parent = parent_obj
    child_obj.matrix_parent_inverse = Matrix.Identity(4)
    child_obj.location = c_world - p_world


def finalize_mesh(obj, mat, shade_smooth=True):
    mesh = obj.data
    if mat:
        if len(mesh.materials) == 0:
            mesh.materials.append(mat)
        else:
            mesh.materials[0] = mat

    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = shade_smooth
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()


def create_tapered_limb(
    name: str,
    col,
    pivot_world: Vector,
    top_z: float,
    bot_z: float,
    rx_top: float,
    ry_top: float,
    rx_bot: float,
    ry_bot: float,
    mat,
    segments: int = 8,
    mid_bulge: float = 1.04,
):
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    set_world_pivot(obj, pivot_world)

    bm = bmesh.new()
    rings = [
        (top_z, rx_top * 0.90, ry_top * 0.90),
        (top_z - (top_z - bot_z) * 0.18, rx_top, ry_top),
        (top_z - (top_z - bot_z) * 0.55, (rx_top + rx_bot) * 0.5 * mid_bulge, (ry_top + ry_bot) * 0.5 * mid_bulge),
        (bot_z, rx_bot * 0.90, ry_bot * 0.90),
    ]

    ring_verts = []
    for rz, rx, ry in rings:
        verts = []
        for i in range(segments):
            ang = 2.0 * math.pi * i / segments
            cx, sy = math.cos(ang), math.sin(ang)
            sx = math.copysign(abs(cx) ** 0.84, cx) * rx
            sy_val = math.copysign(abs(sy) ** 0.84, sy) * ry
            verts.append(bm.verts.new((sx, sy_val, rz)))
        ring_verts.append(verts)

    for r in range(len(ring_verts) - 1):
        v_a = ring_verts[r]
        v_b = ring_verts[r + 1]
        for i in range(segments):
            ni = (i + 1) % segments
            bm.faces.new((v_a[i], v_a[ni], v_b[ni], v_b[i]))

    v_top_c = bm.verts.new((0.0, 0.0, top_z + 0.02))
    v_bot_c = bm.verts.new((0.0, 0.0, bot_z - 0.02))
    for i in range(segments):
        ni = (i + 1) % segments
        bm.faces.new((ring_verts[0][ni], ring_verts[0][i], v_top_c))
        bm.faces.new((ring_verts[-1][i], ring_verts[-1][ni], v_bot_c))

    bm.to_mesh(mesh)
    bm.free()
    finalize_mesh(obj, mat, shade_smooth=True)
    return obj


def create_lofted_ribbon(
    name: str,
    col,
    parent_obj,
    spine_pts: list,
    mat,
    res_u: int = 4,
    sharp_tip: bool = True,
):
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    p_world = WORLD_PIVOTS.get(parent_obj.name, parent_obj.location.copy())
    set_world_pivot(obj, p_world)

    n_ctrl = len(spine_pts)
    samples = []
    total_steps = max(4, (n_ctrl - 1) * res_u // 2)
    for step in range(total_steps + 1):
        u = (step / total_steps) * (n_ctrl - 1)
        idx = min(int(u), n_ctrl - 2)
        frac = u - idx
        sf = frac * frac * (3.0 - 2.0 * frac)
        p0 = spine_pts[idx]
        p1 = spine_pts[idx + 1]
        interp = tuple(p0[k] + (p1[k] - p0[k]) * sf for k in range(6))
        samples.append(interp)

    bm = bmesh.new()
    rings = []
    for i, (px, py, pz, w, th, roll_deg) in enumerate(samples):
        pos = Vector((px, py, pz))
        if i < len(samples) - 1:
            nxt = Vector(samples[i + 1][:3])
            tangent = (nxt - pos).normalized()
        else:
            prv = Vector(samples[i - 1][:3])
            tangent = (pos - prv).normalized()

        up_ref = Vector((0.0, 0.0, 1.0)) if abs(tangent.z) < 0.92 else Vector((0.0, 1.0, 0.0))
        side = tangent.cross(up_ref).normalized()
        norm = side.cross(tangent).normalized()

        roll = math.radians(roll_deg)
        c_r, s_r = math.cos(roll), math.sin(roll)
        rx_dir = side * c_r + norm * s_r
        ry_dir = -side * s_r + norm * c_r

        v_left = bm.verts.new(pos - rx_dir * w)
        v_top = bm.verts.new(pos + ry_dir * th)
        v_right = bm.verts.new(pos + rx_dir * w)
        v_bot = bm.verts.new(pos - ry_dir * (th * 0.55))
        rings.append((v_left, v_top, v_right, v_bot))

    limit = len(rings) - 2 if sharp_tip else len(rings) - 1
    for r in range(limit):
        ra = rings[r]
        rb = rings[r + 1]
        for k in range(4):
            nk = (k + 1) % 4
            bm.faces.new((ra[k], ra[nk], rb[nk], rb[k]))

    r0 = rings[0]
    bm.faces.new((r0[3], r0[2], r0[1], r0[0]))

    if sharp_tip:
        tip_pos = Vector(samples[-1][:3])
        v_tip = bm.verts.new(tip_pos)
        rl = rings[-2]
        for k in range(4):
            nk = (k + 1) % 4
            bm.faces.new((rl[k], rl[nk], v_tip))
    else:
        rl = rings[-1]
        bm.faces.new((rl[0], rl[1], rl[2], rl[3]))

    bm.to_mesh(mesh)
    bm.free()
    finalize_mesh(obj, mat, shade_smooth=True)
    parent_keep_world(obj, parent_obj)
    return obj


# ---------------------------------------------------------------------------
# 4. BUILD SEGMENTED R15 BODY + FACE DECAL
#    Note: Character faces -Y. Anatomical Right is -X (viewer's left in front view),
#          Anatomical Left is +X (viewer's right in front view).
# ---------------------------------------------------------------------------
def build_r15_body(col, mats: dict) -> dict:
    parts = {}

    # 1. HumanoidRootPart
    hrp_mesh = bpy.data.meshes.new("HumanoidRootPart_Mesh")
    hrp = bpy.data.objects.new("HumanoidRootPart", hrp_mesh)
    col.objects.link(hrp)
    set_world_pivot(hrp, Vector((0.0, 0.0, 0.0)))
    hrp.hide_render = True
    parts["HumanoidRootPart"] = hrp

    # 2. LowerTorso (Pelvis/hip root at Z = -0.55)
    lower_torso = create_tapered_limb(
        "LowerTorso",
        col,
        Vector((0.0, 0.0, -0.55)),
        top_z=0.35,
        bot_z=-0.25,
        rx_top=0.62,
        ry_top=0.38,
        rx_bot=0.72,
        ry_bot=0.44,
        mat=mats["Zone1_ObsidianCloth"],
        segments=10,
        mid_bulge=1.02,
    )
    parent_keep_world(lower_torso, hrp)
    parts["LowerTorso"] = lower_torso

    # 3. UpperTorso (Waist pivot at Z = -0.20; obsidian modesty bodice base)
    upper_torso = create_tapered_limb(
        "UpperTorso",
        col,
        Vector((0.0, 0.0, -0.20)),
        top_z=1.50,
        bot_z=0.0,
        rx_top=0.68,
        ry_top=0.41,
        rx_bot=0.58,
        ry_bot=0.36,
        mat=mats["Zone1_ObsidianCloth"],
        segments=12,
        mid_bulge=1.06,
    )
    parent_keep_world(upper_torso, lower_torso)
    parts["UpperTorso"] = upper_torso

    # Graceful porcelain neck column at top of UpperTorso
    neck_skin = create_tapered_limb(
        "Neck_SkinBase",
        col,
        Vector((0.0, 0.0, 1.30)),
        top_z=0.40,
        bot_z=-0.08,
        rx_top=0.25,
        ry_top=0.24,
        rx_bot=0.38,
        ry_bot=0.30,
        mat=mats["Zone5_PorcelainSkin"],
        segments=8,
        mid_bulge=0.96,
    )
    parent_keep_world(neck_skin, upper_torso)

    # 4. Head (Neck pivot at Z = 1.62; sleek anime-Roblox head with wide angular UV face decal)
    head_mesh = bpy.data.meshes.new("Head_Mesh")
    head = bpy.data.objects.new("Head", head_mesh)
    col.objects.link(head)
    set_world_pivot(head, Vector((0.0, 0.0, 1.62)))

    bm = bmesh.new()
    h_rings = [
        (0.00, 0.28, 0.30),
        (0.10, 0.48, 0.50),
        (0.32, 0.58, 0.56),
        (0.68, 0.60, 0.58),
        (1.02, 0.58, 0.56),
        (1.24, 0.46, 0.46),
        (1.34, 0.24, 0.24),
    ]
    segs = 16
    ring_v = []
    for rz, rx, ry in h_rings:
        row = []
        for i in range(segs):
            ang = math.pi * 0.5 + 2.0 * math.pi * i / segs
            cx, sy = math.cos(ang), math.sin(ang)
            chin_factor = 0.85 if (rz < 0.36 and sy < -0.15) else 1.0
            # Gently flatten the front face plane so eyes and smirk read with zero distortion
            front_flat = 0.90 if sy < -0.25 else 1.0
            row.append(bm.verts.new((cx * rx * chin_factor, sy * ry * front_flat, rz)))
        ring_v.append(row)

    for r in range(len(ring_v) - 1):
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((ring_v[r][i], ring_v[r][ni], ring_v[r + 1][ni], ring_v[r + 1][i]))

    v_bot = bm.verts.new((0.0, 0.0, -0.02))
    v_top = bm.verts.new((0.0, 0.0, 1.36))
    for i in range(segs):
        ni = (i + 1) % segs
        bm.faces.new((ring_v[0][ni], ring_v[0][i], v_bot))
        bm.faces.new((ring_v[-1][i], ring_v[-1][ni], v_top))

    # Map front face UVs smoothly across the entire front hemisphere (since border of texture is pure skin!)
    uv_layer = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        for loop in face.loops:
            co = loop.vert.co
            if co.y < 0.05:
                horiz_angle = math.atan2(co.x, max(0.05, -co.y))
                u = 0.5 + (horiz_angle / (math.pi * 0.36)) * 0.44
                v = 0.14 + ((co.z - 0.08) / 0.88) * 0.72
                loop[uv_layer].uv = (max(0.01, min(0.99, u)), max(0.01, min(0.99, v)))
            else:
                loop[uv_layer].uv = (0.02, 0.98)

    bm.to_mesh(head_mesh)
    bm.free()
    finalize_mesh(head, mats["Zone5_FaceDecal"], shade_smooth=True)
    parent_keep_world(head, upper_torso)
    parts["Head"] = head

    # Gold Drop Earrings on Right (-X) and Left (+X) sides of Head
    for side, s_name in ((-1, "Right"), (1, "Left")):
        ear_mesh = bpy.data.meshes.new(f"Earring_{s_name}_Mesh")
        ear_obj = bpy.data.objects.new(f"Earring_{s_name}", ear_mesh)
        col.objects.link(ear_obj)
        set_world_pivot(ear_obj, Vector((side * 0.59, -0.05, 1.62 + 0.38)))
        bm = bmesh.new()
        bmesh.ops.create_cone(
            bm,
            cap_ends=True,
            cap_tris=True,
            segments=6,
            radius1=0.045,
            radius2=0.012,
            depth=0.24,
            matrix=Matrix.Translation((0, 0, -0.11)),
        )
        bm.to_mesh(ear_mesh)
        bm.free()
        finalize_mesh(ear_obj, mats["Zone3_RoyalGold"], shade_smooth=True)
        parent_keep_world(ear_obj, head)

    # 5. Arms & Hands (Anatomical Right = -X, Anatomical Left = +X)
    for side, prefix in ((-1, "Right"), (1, "Left")):
        sx = side * 0.90
        u_arm = create_tapered_limb(
            f"{prefix}UpperArm",
            col,
            Vector((sx, 0.0, 1.15)),
            top_z=0.12,
            bot_z=-0.75,
            rx_top=0.23,
            ry_top=0.23,
            rx_bot=0.19,
            ry_bot=0.19,
            mat=mats["Zone1_ObsidianCloth"],
            segments=8,
        )
        parent_keep_world(u_arm, upper_torso)
        parts[f"{prefix}UpperArm"] = u_arm

        l_arm = create_tapered_limb(
            f"{prefix}LowerArm",
            col,
            Vector((sx, 0.0, 0.40)),
            top_z=0.06,
            bot_z=-0.72,
            rx_top=0.19,
            ry_top=0.19,
            rx_bot=0.15,
            ry_bot=0.15,
            mat=mats["Zone5_PorcelainSkin"],
            segments=8,
        )
        parent_keep_world(l_arm, u_arm)
        parts[f"{prefix}LowerArm"] = l_arm

        hand = create_tapered_limb(
            f"{prefix}Hand",
            col,
            Vector((sx, 0.0, -0.32)),
            top_z=0.04,
            bot_z=-0.32,
            rx_top=0.15,
            ry_top=0.12,
            rx_bot=0.12,
            ry_bot=0.08,
            mat=mats["Zone5_PorcelainSkin"],
            segments=8,
        )
        parent_keep_world(hand, l_arm)
        parts[f"{prefix}Hand"] = hand

    # 6. Legs & Feet (Anatomical Right = -X, Anatomical Left = +X)
    for side, prefix in ((-1, "Right"), (1, "Left")):
        lx = side * 0.34
        u_leg = create_tapered_limb(
            f"{prefix}UpperLeg",
            col,
            Vector((lx, 0.0, -0.80)),
            top_z=0.10,
            bot_z=-1.05,
            rx_top=0.29,
            ry_top=0.29,
            rx_bot=0.22,
            ry_bot=0.22,
            mat=mats["Zone1_ObsidianCloth"],
            segments=8,
        )
        parent_keep_world(u_leg, lower_torso)
        parts[f"{prefix}UpperLeg"] = u_leg

        l_leg = create_tapered_limb(
            f"{prefix}LowerLeg",
            col,
            Vector((lx, 0.0, -1.85)),
            top_z=0.08,
            bot_z=-0.95,
            rx_top=0.21,
            ry_top=0.21,
            rx_bot=0.16,
            ry_bot=0.16,
            mat=mats["Zone1_ObsidianCloth"],
            segments=8,
        )
        parent_keep_world(l_leg, u_leg)
        parts[f"{prefix}LowerLeg"] = l_leg

        foot = create_tapered_limb(
            f"{prefix}Foot",
            col,
            Vector((lx, -0.08, -2.80)),
            top_z=0.06,
            bot_z=-0.24,
            rx_top=0.18,
            ry_top=0.31,
            rx_bot=0.20,
            ry_bot=0.35,
            mat=mats["Zone1_ObsidianCloth"],
            segments=8,
        )
        parent_keep_world(foot, l_leg)
        parts[f"{prefix}Foot"] = foot

    return parts


# ---------------------------------------------------------------------------
# 5. SCULPTED 3D ANIME HAIR (BANGS, GOLD CROWN CUFF, VOLUMINOUS HIGH PONYTAIL)
# ---------------------------------------------------------------------------
def build_sculpted_hair(col, head_obj, mats: dict):
    hz = 1.62
    hair_base = mats["Zone4_CopperHair"]
    hair_hi = mats["Zone4_HairHighlight"]
    gold = mats["Zone3_RoyalGold"]

    # 1. Full Cranial Hair Cap (with sculpted upper forehead hairline)
    cap_mesh = bpy.data.meshes.new("Hair_CranialCap_Mesh")
    cap_obj = bpy.data.objects.new("Hair_CranialCap", cap_mesh)
    col.objects.link(cap_obj)
    set_world_pivot(cap_obj, Vector((0.0, 0.0, hz)))

    bm = bmesh.new()
    cap_rings = [
        (0.16, 0.63, 0.64, -0.02),
        (0.42, 0.68, 0.68, -0.12),
        (0.72, 0.70, 0.70, -0.25),
        (0.94, 0.68, 0.68, -0.58),
        (1.22, 0.58, 0.60, -0.64),
        (1.38, 0.36, 0.38, -0.64),
    ]
    segs = 14
    r_verts = []
    for rz, rx, ry, min_y in cap_rings:
        row = []
        for i in range(segs):
            ang = 2.0 * math.pi * i / segs
            cx, sy = math.cos(ang), math.sin(ang)
            y_val = sy * ry
            z_val = rz
            if y_val < min_y and rz < 0.90:
                z_val = max(rz, 0.86 + (min_y - y_val) * 0.25)
            row.append(bm.verts.new((cx * rx, y_val, z_val)))
        r_verts.append(row)

    for r in range(len(r_verts) - 1):
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((r_verts[r][i], r_verts[r][ni], r_verts[r + 1][ni], r_verts[r + 1][i]))

    v_crown = bm.verts.new((0.0, 0.05, 1.44))
    for i in range(segs):
        ni = (i + 1) % segs
        bm.faces.new((r_verts[-1][i], r_verts[-1][ni], v_crown))

    bm.to_mesh(cap_mesh)
    bm.free()
    finalize_mesh(cap_obj, hair_base, shade_smooth=True)
    parent_keep_world(cap_obj, head_obj)

    # 2. Lush Forehead-Framing Curtain Bangs + Center Lock + Cheek Locks
    #    Note: roll_deg ~ 85-95 orients the wide ribbon flat against the forehead (-Y)!
    bang_specs = [
        # Signature curved center strand dipping between the eyebrows
        (
            "Hair_CenterStrand",
            hair_hi,
            [
                (0.00, -0.44, 1.24, 0.14, 0.07, 88.0),
                (-0.03, -0.58, 1.04, 0.15, 0.07, 88.0),
                (-0.02, -0.60, 0.80, 0.10, 0.05, 88.0),
                (0.02, -0.57, 0.62, 0.03, 0.02, 88.0),
            ],
        ),
        # Viewer-left (-X) inner curtain bang (drapes across left forehead above eyebrow)
        (
            "Hair_Bang_RightInner",
            hair_hi,
            [
                (-0.04, -0.42, 1.26, 0.28, 0.10, 78.0),
                (-0.24, -0.58, 1.08, 0.32, 0.11, 68.0),
                (-0.46, -0.54, 0.82, 0.24, 0.09, 52.0),
                (-0.56, -0.42, 0.56, 0.06, 0.04, 42.0),
            ],
        ),
        # Viewer-left (-X) outer voluminous bang sweep
        (
            "Hair_Bang_RightOuter",
            hair_base,
            [
                (-0.12, -0.36, 1.30, 0.30, 0.12, 65.0),
                (-0.44, -0.50, 1.10, 0.34, 0.13, 45.0),
                (-0.64, -0.34, 0.76, 0.26, 0.10, 25.0),
                (-0.68, -0.18, 0.38, 0.07, 0.04, 15.0),
            ],
        ),
        # Viewer-right (+X) inner curtain bang (drapes across right forehead above eyebrow)
        (
            "Hair_Bang_LeftInner",
            hair_hi,
            [
                (0.04, -0.42, 1.26, 0.28, 0.10, -78.0),
                (0.24, -0.58, 1.08, 0.32, 0.11, -68.0),
                (0.46, -0.54, 0.82, 0.24, 0.09, -52.0),
                (0.56, -0.42, 0.56, 0.06, 0.04, -42.0),
            ],
        ),
        # Viewer-right (+X) outer voluminous bang sweep
        (
            "Hair_Bang_LeftOuter",
            hair_base,
            [
                (0.12, -0.36, 1.30, 0.30, 0.12, -65.0),
                (0.44, -0.50, 1.10, 0.34, 0.13, -45.0),
                (0.64, -0.34, 0.76, 0.26, 0.10, -25.0),
                (0.68, -0.18, 0.38, 0.07, 0.04, -15.0),
            ],
        ),
        # Cheek/sideburn framing locks (flat against temples)
        (
            "Hair_SideLock_Right",
            hair_base,
            [
                (-0.56, -0.18, 0.84, 0.20, 0.09, 12.0),
                (-0.62, -0.22, 0.44, 0.18, 0.08, 12.0),
                (-0.56, -0.24, 0.08, 0.11, 0.05, 15.0),
                (-0.48, -0.20, -0.20, 0.03, 0.02, 18.0),
            ],
        ),
        (
            "Hair_SideLock_Left",
            hair_base,
            [
                (0.56, -0.18, 0.84, 0.20, 0.09, -12.0),
                (0.62, -0.22, 0.44, 0.18, 0.08, -12.0),
                (0.56, -0.24, 0.08, 0.11, 0.05, -15.0),
                (0.48, -0.20, -0.20, 0.03, 0.02, -18.0),
            ],
        ),
    ]
    for b_name, b_mat, pts in bang_specs:
        create_lofted_ribbon(b_name, col, head_obj, pts, b_mat, res_u=4, sharp_tip=True)

    # 3. Ornate Gold Hair Cuff at Upper Crown (+X viewer-right, matching reference!)
    cuff_mesh = bpy.data.meshes.new("Hair_GoldCuff_Mesh")
    cuff_obj = bpy.data.objects.new("Hair_GoldCuff", cuff_mesh)
    col.objects.link(cuff_obj)
    set_world_pivot(cuff_obj, Vector((0.20, 0.46, hz + 1.24)))
    cuff_obj.rotation_euler = Euler((math.radians(42.0), math.radians(24.0), math.radians(-15.0)), "XYZ")

    bm = bmesh.new()
    segs_u, segs_v = 10, 6
    R, r_tube = 0.24, 0.065
    t_rings = []
    for i in range(segs_u):
        u_a = 2.0 * math.pi * i / segs_u
        cu, su = math.cos(u_a), math.sin(u_a)
        row = []
        for j in range(segs_v):
            v_a = 2.0 * math.pi * j / segs_v
            cv, sv = math.cos(v_a), math.sin(v_a)
            row.append(bm.verts.new(((R + r_tube * cv) * cu, (R + r_tube * cv) * su, r_tube * sv * 1.3)))
        t_rings.append(row)
    for i in range(segs_u):
        ni = (i + 1) % segs_u
        for j in range(segs_v):
            nj = (j + 1) % segs_v
            bm.faces.new((t_rings[i][j], t_rings[ni][j], t_rings[ni][nj], t_rings[i][nj]))
    bm.to_mesh(cuff_mesh)
    bm.free()
    finalize_mesh(cuff_obj, gold, shade_smooth=True)
    parent_keep_world(cuff_obj, head_obj)

    # 4. Voluminous High Sweeping Ponytail (+X viewer-right) + Wind Strands toward Fire Orb (-X viewer-left)
    ponytail_specs = [
        (
            "Ponytail_CrestMain",
            hair_hi,
            [
                (0.20, 0.46, 1.24, 0.28, 0.16, 15.0),
                (0.54, 0.66, 1.64, 0.40, 0.22, 25.0),
                (1.02, 0.74, 1.38, 0.42, 0.20, 32.0),
                (1.38, 0.66, 0.74, 0.32, 0.14, 28.0),
                (1.52, 0.52, 0.08, 0.16, 0.08, 20.0),
                (1.38, 0.38, -0.42, 0.03, 0.02, 15.0),
            ],
        ),
        (
            "Ponytail_UpperLock",
            hair_base,
            [
                (0.18, 0.50, 1.22, 0.24, 0.15, -10.0),
                (0.38, 0.82, 1.54, 0.36, 0.20, -15.0),
                (0.76, 0.96, 1.20, 0.38, 0.18, -22.0),
                (1.08, 0.88, 0.54, 0.28, 0.13, -18.0),
                (1.22, 0.72, -0.16, 0.13, 0.06, -12.0),
                (1.10, 0.58, -0.62, 0.03, 0.02, -8.0),
            ],
        ),
        (
            "Ponytail_CurlLock",
            hair_hi,
            [
                (0.24, 0.44, 1.18, 0.20, 0.12, 35.0),
                (0.68, 0.56, 1.14, 0.28, 0.14, 42.0),
                (1.04, 0.44, 0.64, 0.24, 0.12, 30.0),
                (0.84, 0.32, 0.18, 0.16, 0.08, 15.0),
                (0.42, 0.26, 0.04, 0.04, 0.02, 0.0),
            ],
        ),
        # Wind-swept hair ribbon streaming toward the Fire Orb on viewer's left (-X)!
        (
            "Hair_WindStrand_ToOrb",
            hair_hi,
            [
                (-0.12, 0.42, 1.08, 0.18, 0.09, -25.0),
                (-0.58, 0.18, 0.86, 0.20, 0.09, -32.0),
                (-1.08, -0.18, 0.68, 0.16, 0.07, -28.0),
                (-1.52, -0.58, 0.66, 0.09, 0.04, -18.0),
                (-1.82, -0.88, 0.82, 0.02, 0.02, -10.0),
            ],
        ),
        # Long flowing back hair cascade
        (
            "Hair_BackCascade_Center",
            hair_base,
            [
                (0.00, 0.56, 0.82, 0.40, 0.18, 0.0),
                (-0.16, 0.68, 0.22, 0.48, 0.20, -8.0),
                (-0.34, 0.72, -0.48, 0.50, 0.20, -12.0),
                (-0.46, 0.68, -1.18, 0.38, 0.15, -15.0),
                (-0.38, 0.58, -1.75, 0.06, 0.03, -10.0),
            ],
        ),
    ]
    for p_name, p_mat, pts in ponytail_specs:
        create_lofted_ribbon(p_name, col, head_obj, pts, p_mat, res_u=4, sharp_tip=True)


# ---------------------------------------------------------------------------
# 6. GOTHIC CRIMSON, OBSIDIAN & ROYAL GOLD ATTIRE
# ---------------------------------------------------------------------------
def build_gothic_attire(col, parts: dict, mats: dict):
    upper_torso = parts["UpperTorso"]
    lower_torso = parts["LowerTorso"]

    obsidian = mats["Zone1_ObsidianCloth"]
    crimson = mats["Zone2_CrimsonVelvet"]
    lining = mats["Zone2_DeepCrimsonLining"]
    gold = mats["Zone3_RoyalGold"]
    ruby = mats["Zone6_RubyEmissive"]

    # 1. High Gold Collar + Glowing Ruby Brooch at Throat Hollow
    collar_mesh = bpy.data.meshes.new("Attire_GoldCollar_Mesh")
    collar_obj = bpy.data.objects.new("Attire_GoldCollar", collar_mesh)
    col.objects.link(collar_obj)
    set_world_pivot(collar_obj, Vector((0.0, 0.0, 1.34)))

    bm = bmesh.new()
    segs = 12
    c_rings = [
        (0.00, 0.34, 0.32),
        (0.12, 0.31, 0.29),
        (0.24, 0.29, 0.27),
    ]
    rv = []
    for rz, rx, ry in c_rings:
        row = []
        for i in range(segs):
            ang = 2.0 * math.pi * i / segs
            v_dip = -0.06 if abs(math.cos(ang)) < 0.35 and math.sin(ang) < 0 else 0.0
            row.append(bm.verts.new((math.cos(ang) * rx, math.sin(ang) * ry, rz + v_dip)))
        rv.append(row)
    for r in range(len(rv) - 1):
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((rv[r][i], rv[r][ni], rv[r + 1][ni], rv[r + 1][i]))
    bm.to_mesh(collar_mesh)
    bm.free()
    finalize_mesh(collar_obj, gold, shade_smooth=True)
    parent_keep_world(collar_obj, upper_torso)

    # Gold Brooch Bezel + Glowing Oval Ruby Cabochon
    bezel_mesh = bpy.data.meshes.new("Attire_BroochBezel_Mesh")
    bezel_obj = bpy.data.objects.new("Attire_BroochBezel", bezel_mesh)
    col.objects.link(bezel_obj)
    set_world_pivot(bezel_obj, Vector((0.0, -0.36, 1.22)))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.14)
    bmesh.ops.scale(bm, vec=(0.95, 0.38, 1.25), verts=bm.verts)
    bm.to_mesh(bezel_mesh)
    bm.free()
    finalize_mesh(bezel_obj, gold, shade_smooth=True)
    parent_keep_world(bezel_obj, upper_torso)

    ruby_mesh = bpy.data.meshes.new("Attire_RubyBrooch_Mesh")
    ruby_obj = bpy.data.objects.new("Attire_RubyBrooch", ruby_mesh)
    col.objects.link(ruby_obj)
    set_world_pivot(ruby_obj, Vector((0.0, -0.39, 1.22)))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=0.11)
    bmesh.ops.scale(bm, vec=(0.88, 0.42, 1.18), verts=bm.verts)
    bm.to_mesh(ruby_mesh)
    bm.free()
    finalize_mesh(ruby_obj, ruby, shade_smooth=True)
    parent_keep_world(ruby_obj, bezel_obj)

    # 2. Fitted Sweetheart Crimson Velvet Corset & Gold V-Piping (origin at UpperTorso Z = -0.20)
    corset_mesh = bpy.data.meshes.new("Attire_CrimsonCorset_Mesh")
    corset_obj = bpy.data.objects.new("Attire_CrimsonCorset", corset_mesh)
    col.objects.link(corset_obj)
    set_world_pivot(corset_obj, Vector((0.0, 0.0, -0.20)))

    bm = bmesh.new()
    segs = 14
    cor_profiles = [
        (-0.18, 0.64, 0.41, -0.15),
        (0.15, 0.60, 0.39, -0.06),
        (0.52, 0.65, 0.42, 0.00),
        (0.88, 0.72, 0.47, 0.04),
        (1.06, 0.70, 0.45, -0.10),
    ]
    c_verts = []
    for rz, rx, ry, f_drop in cor_profiles:
        row = []
        for i in range(segs):
            ang = 2.0 * math.pi * i / segs
            cx, sy = math.cos(ang), math.sin(ang)
            front_weight = max(0.0, -sy) ** 2.0
            side_swell = 0.08 * (abs(cx) ** 1.5) * max(0.0, -sy) if rz > 0.70 else 0.0
            row.append(bm.verts.new((cx * rx, sy * ry, rz + f_drop * front_weight + side_swell)))
        c_verts.append(row)

    for r in range(len(c_verts) - 1):
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((c_verts[r][i], c_verts[r][ni], c_verts[r + 1][ni], c_verts[r + 1][i]))

    bm.to_mesh(corset_mesh)
    bm.free()
    corset_mesh.materials.append(crimson)
    corset_mesh.materials.append(obsidian)
    for poly in corset_mesh.polygons:
        c = poly.center
        v_width = 0.11 + max(0.0, (c.z + 0.15)) * 0.22
        if c.y < -0.15 and abs(c.x) < v_width:
            poly.material_index = 1
        else:
            poly.material_index = 0
    finalize_mesh(corset_obj, None, shade_smooth=True)
    parent_keep_world(corset_obj, upper_torso)

    # Raised 3D Metallic Gold V-Piping along Corset Seams & Waistline
    for side in (-1, 1):
        s_tag = "R" if side < 0 else "L"
        create_lofted_ribbon(
            f"Corset_GoldSeam_Inner_{s_tag}",
            col,
            upper_torso,
            [
                (0.0, -0.43, -0.28, 0.035, 0.025, 0.0),
                (side * 0.20, -0.45, 0.35, 0.035, 0.025, side * 12.0),
                (side * 0.35, -0.47, 0.92, 0.035, 0.025, side * 18.0),
                (side * 0.10, -0.38, 1.36, 0.028, 0.020, 0.0),
            ],
            gold,
            res_u=4,
            sharp_tip=False,
        )
        create_lofted_ribbon(
            f"Corset_GoldWaist_{s_tag}",
            col,
            upper_torso,
            [
                (0.0, -0.44, -0.34, 0.042, 0.030, 0.0),
                (side * 0.40, -0.40, -0.12, 0.042, 0.030, side * 35.0),
                (side * 0.65, -0.05, 0.04, 0.038, 0.025, side * 80.0),
                (0.0, 0.42, -0.08, 0.035, 0.025, 0.0),
            ],
            gold,
            res_u=4,
            sharp_tip=False,
        )

    # 3. Draped Asymmetric Shoulder Capelet / Mantle (world origin Z = 1.28)
    cape_mesh = bpy.data.meshes.new("Attire_ShoulderCapelet_Mesh")
    cape_obj = bpy.data.objects.new("Attire_ShoulderCapelet", cape_mesh)
    col.objects.link(cape_obj)
    set_world_pivot(cape_obj, Vector((0.0, 0.0, 1.28)))

    bm = bmesh.new()
    segs = 14
    cape_rows = [
        (0.06, 0.40, 0.34, 12.0),
        (-0.08, 0.94, 0.54, 32.0),
        (-0.38, 1.28, 0.70, 54.0),
        (-0.78, 1.50, 0.86, 70.0),
        (-1.25, 1.64, 1.00, 84.0),
    ]
    outer_rings = []
    inner_rings = []
    for r_idx, (rz, rx, ry, cut_deg) in enumerate(cape_rows):
        row_o = []
        row_i = []
        for i in range(segs):
            t = i / (segs - 1)
            ang_deg = (-90.0 + cut_deg) + t * (360.0 - 2.0 * cut_deg)
            ang = math.radians(ang_deg)
            cx, sy = math.cos(ang), math.sin(ang)
            # Lift over Right Arm (-X, viewer's left) so casting arm emerges heroically!
            right_arm_lift = 0.42 * max(0.0, -cx) * (r_idx / 4.0)
            wave = 0.05 * math.sin(ang * 5.0) * (r_idx / 4.0)
            px = cx * rx
            py = sy * ry
            pz = rz + right_arm_lift + wave
            row_o.append(bm.verts.new((px, py, pz)))
            row_i.append(bm.verts.new((px * 0.96, py * 0.96, pz - 0.025)))
        outer_rings.append(row_o)
        inner_rings.append(row_i)

    for r in range(len(outer_rings) - 1):
        for i in range(segs - 1):
            f_out = bm.faces.new((outer_rings[r][i], outer_rings[r][i + 1], outer_rings[r + 1][i + 1], outer_rings[r + 1][i]))
            f_out.material_index = 0
            f_in = bm.faces.new((inner_rings[r][i + 1], inner_rings[r][i], inner_rings[r + 1][i], inner_rings[r + 1][i + 1]))
            f_in.material_index = 1

    bm.to_mesh(cape_mesh)
    bm.free()
    cape_mesh.materials.append(obsidian)
    cape_mesh.materials.append(lining)
    finalize_mesh(cape_obj, None, shade_smooth=True)
    parent_keep_world(cape_obj, upper_torso)

    # Bold 3D Metallic Gold Baroque Scrollwork on Shoulder Caps & Front Capelet Trim
    for side in (-1, 1):
        s_tag = "R" if side < 0 else "L"
        create_lofted_ribbon(
            f"Capelet_GoldShoulderFiligree_{s_tag}",
            col,
            upper_torso,
            [
                (side * 0.28, -0.36, 1.48, 0.06, 0.035, 0.0),
                (side * 0.68, -0.38, 1.44, 0.16, 0.045, side * 22.0),
                (side * 1.00, -0.18, 1.32, 0.20, 0.045, side * 50.0),
                (side * 1.06, 0.12, 1.12, 0.12, 0.035, side * 70.0),
                (side * 0.82, -0.10, 1.00, 0.04, 0.025, side * 40.0),
            ],
            gold,
            res_u=4,
            sharp_tip=True,
        )
        create_lofted_ribbon(
            f"Capelet_GoldEdge_{s_tag}",
            col,
            upper_torso,
            [
                (side * 0.10, -0.38, 1.44, 0.038, 0.025, 0.0),
                (side * 0.54, -0.44, 1.18, 0.044, 0.028, side * 25.0),
                (side * 0.98, -0.40, 0.84, 0.040, 0.025, side * 40.0),
                (side * 1.24, -0.20, 0.42, 0.025, 0.020, side * 55.0),
            ],
            gold,
            res_u=4,
            sharp_tip=True,
        )

    # 4. Flowing Floor-Length Split Gothic Skirt (origin at LowerTorso Z = -0.55)
    skirt_mesh = bpy.data.meshes.new("Attire_FlowingSkirt_Mesh")
    skirt_obj = bpy.data.objects.new("Attire_FlowingSkirt", skirt_mesh)
    col.objects.link(skirt_obj)
    set_world_pivot(skirt_obj, Vector((0.0, 0.0, -0.55)))

    bm = bmesh.new()
    segs = 16
    skirt_levels = [
        (0.28, 0.64, 0.41),
        (-0.15, 0.80, 0.54),
        (-0.70, 0.98, 0.70),
        (-1.35, 1.20, 0.90),
        (-1.95, 1.44, 1.10),
        (-2.42, 1.64, 1.26),
    ]
    sk_rings = []
    for r_idx, (rz, rx, ry) in enumerate(skirt_levels):
        row = []
        t_v = r_idx / (len(skirt_levels) - 1)
        for i in range(segs):
            t = i / (segs - 1)
            slit_gap = 20.0 * max(0.0, t_v - 0.25)
            ang_deg = (-52.0 + slit_gap) + t * (360.0 - 2.0 * slit_gap)
            ang = math.radians(ang_deg)
            cx, sy = math.cos(ang), math.sin(ang)
            pleat = 1.0 + 0.045 * math.cos(ang * 6.0) * t_v
            wind_x = -0.14 * (t_v ** 1.5)
            row.append(bm.verts.new((cx * rx * pleat + wind_x, sy * ry * pleat, rz)))
        sk_rings.append(row)

    for r in range(len(sk_rings) - 1):
        for i in range(segs - 1):
            bm.faces.new((sk_rings[r][i], sk_rings[r][i + 1], sk_rings[r + 1][i + 1], sk_rings[r + 1][i]))

    bm.to_mesh(skirt_mesh)
    bm.free()
    finalize_mesh(skirt_obj, obsidian, shade_smooth=True)
    parent_keep_world(skirt_obj, lower_torso)

    # Prominent 3D Gold Baroque Scrollwork on Right Hip (-X, viewer's left) & Left Slit (+X)
    create_lofted_ribbon(
        "Skirt_GoldHipScroll_Main",
        col,
        lower_torso,
        [
            (-0.16, -0.45, -0.02, 0.06, 0.035, 0.0),
            (-0.58, -0.44, -0.16, 0.16, 0.045, -32.0),
            (-0.80, -0.26, -0.52, 0.18, 0.045, -52.0),
            (-0.68, -0.46, -0.92, 0.12, 0.035, -35.0),
            (-0.42, -0.54, -0.76, 0.04, 0.025, -15.0),
        ],
        gold,
        res_u=4,
        sharp_tip=True,
    )
    create_lofted_ribbon(
        "Skirt_GoldSlitScroll_Left",
        col,
        lower_torso,
        [
            (0.40, -0.40, -0.26, 0.05, 0.03, 25.0),
            (0.64, -0.50, -0.88, 0.10, 0.04, 35.0),
            (0.80, -0.66, -1.58, 0.12, 0.04, 38.0),
            (0.92, -0.80, -2.20, 0.05, 0.025, 40.0),
        ],
        gold,
        res_u=4,
        sharp_tip=True,
    )

    # 5. Wide Metallic Gold Wrist Bracers on Both Forearms
    for side, prefix in ((-1, "Right"), (1, "Left")):
        l_arm = parts[f"{prefix}LowerArm"]
        sx = side * 0.90
        bracer = create_tapered_limb(
            f"Attire_GoldBracer_{prefix}",
            col,
            Vector((sx, 0.0, 0.40)),
            top_z=-0.38,
            bot_z=-0.68,
            rx_top=0.21,
            ry_top=0.21,
            rx_bot=0.19,
            ry_bot=0.19,
            mat=gold,
            segments=8,
            mid_bulge=1.06,
        )
        parent_keep_world(bracer, l_arm)


# ---------------------------------------------------------------------------
# 7. SIGNATURE POSE + RIGHT-HAND SOLAR FIRE ORB & VFX SOCKETS
# ---------------------------------------------------------------------------
def pose_character_and_build_vfx(col, parts: dict, mats: dict):
    hrp = parts["HumanoidRootPart"]
    r_hand = parts["RightHand"]
    r_hand_world = WORLD_PIVOTS[r_hand.name]

    aura_socket = bpy.data.objects.new("AuraRootSocket", None)
    aura_socket.empty_display_type = "CIRCLE"
    aura_socket.empty_display_size = 0.85
    col.objects.link(aura_socket)
    set_world_pivot(aura_socket, Vector((0.0, 0.0, -2.95)))
    parent_keep_world(aura_socket, hrp)

    grip_socket = bpy.data.objects.new("RightHandSocket", None)
    grip_socket.empty_display_type = "ARROWS"
    grip_socket.empty_display_size = 0.25
    col.objects.link(grip_socket)
    set_world_pivot(grip_socket, r_hand_world + Vector((0.0, -0.06, -0.18)))
    parent_keep_world(grip_socket, r_hand)

    # When RightUpperArm + RightLowerArm swing FORWARD (-X rot = -95 deg total),
    # local -Y of RightHand points UPWARD (+Z in world space)!
    # Placing CastVFXSocket at local -Y (-0.54) and local -Z (-0.22) places the
    # Solar Fire Orb directly ABOVE her upturned right palm in front of her!
    cast_socket = bpy.data.objects.new("CastVFXSocket", None)
    cast_socket.empty_display_type = "SPHERE"
    cast_socket.empty_display_size = 0.20
    col.objects.link(cast_socket)
    c_pos = r_hand_world + Vector((-0.08, -0.54, -0.22))
    set_world_pivot(cast_socket, c_pos)
    parent_keep_world(cast_socket, r_hand)

    # Core glowing molten sphere
    core_mesh = bpy.data.meshes.new("FireOrb_PreviewMesh_Data")
    orb_core = bpy.data.objects.new("FireOrb_PreviewMesh", core_mesh)
    col.objects.link(orb_core)
    set_world_pivot(orb_core, c_pos)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.38)
    bm.to_mesh(core_mesh)
    bm.free()
    finalize_mesh(orb_core, mats["Zone6_FireOrbCore"], shade_smooth=True)
    parent_keep_world(orb_core, cast_socket)

    # Swirling 3D Flame Ribbon Shells orbiting the core
    ribbons_mesh = bpy.data.meshes.new("FireOrb_FlameRibbons_Data")
    orb_ribbons = bpy.data.objects.new("FireOrb_FlameRibbons", ribbons_mesh)
    col.objects.link(orb_ribbons)
    set_world_pivot(orb_ribbons, c_pos)

    bm = bmesh.new()
    for s_idx in range(4):
        base_ang = s_idx * (math.pi * 0.5)
        tilt = (s_idx % 2) * 0.35 - 0.18
        steps = 10
        r_verts = []
        for k in range(steps + 1):
            t = k / steps
            ang = base_ang + t * math.pi * 1.45
            rad = 0.42 + 0.16 * math.sin(t * math.pi)
            z_lift = -0.24 + t * 0.74 + 0.14 * (t ** 2)
            px = math.cos(ang) * rad
            py = math.sin(ang) * rad
            pz = z_lift + px * tilt
            half_w = 0.14 * math.sin(t * math.pi * 0.92) + 0.015 * (1.0 - t)
            v_a = bm.verts.new((px * 0.96, py * 0.96, pz - half_w))
            v_b = bm.verts.new((px * 1.04, py * 1.04, pz + half_w))
            r_verts.append((v_a, v_b))
        for k in range(steps):
            bm.faces.new((r_verts[k][0], r_verts[k + 1][0], r_verts[k + 1][1], r_verts[k][1]))

    bm.to_mesh(ribbons_mesh)
    bm.free()
    finalize_mesh(orb_ribbons, mats["Zone6_FireOrbRibbon"], shade_smooth=True)
    parent_keep_world(orb_ribbons, orb_core)

    # Apply Iconic Forward-Reaching Casting Pose on Right Arm (-X, viewer's left!)
    # Note: Negative X rotation swings a downward-hanging (-Z) arm FORWARD (-Y)!
    #       Positive Y rotation swings a downward-hanging (-Z) arm OUTWARD (-X)!
    parts["RightUpperArm"].rotation_euler = Euler(
        (math.radians(-48.0), math.radians(36.0), math.radians(-14.0)), "XYZ"
    )
    parts["RightLowerArm"].rotation_euler = Euler(
        (math.radians(-46.0), math.radians(10.0), math.radians(16.0)), "XYZ"
    )
    parts["RightHand"].rotation_euler = Euler(
        (math.radians(8.0), math.radians(-8.0), math.radians(10.0)), "XYZ"
    )

    # Left Arm (+X, viewer's right) posed gracefully along hip
    parts["LeftUpperArm"].rotation_euler = Euler(
        (math.radians(8.0), math.radians(-14.0), math.radians(-8.0)), "XYZ"
    )
    parts["LeftLowerArm"].rotation_euler = Euler(
        (math.radians(-18.0), math.radians(6.0), math.radians(10.0)), "XYZ"
    )

    # Confident head gaze toward viewer
    parts["Head"].rotation_euler = Euler(
        (math.radians(-2.0), math.radians(4.0), math.radians(6.0)), "XYZ"
    )

    # 60-Frame Looping Animation on the Fire Orb
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 60
    prev_interp = bpy.context.preferences.edit.keyframe_new_interpolation_type
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "LINEAR"

    for f in (1, 15, 30, 45, 60):
        scene.frame_set(f)
        s = 1.0 + 0.10 * math.sin((f - 1) / 60.0 * 2.0 * math.pi * 2.0)
        orb_core.scale = (s, s, s)
        orb_core.keyframe_insert(data_path="scale", frame=f)

    scene.frame_set(1)
    orb_ribbons.rotation_euler = (0.0, 0.0, 0.0)
    orb_ribbons.keyframe_insert(data_path="rotation_euler", frame=1)
    scene.frame_set(60)
    orb_ribbons.rotation_euler = (0.0, 0.0, math.radians(360.0))
    orb_ribbons.keyframe_insert(data_path="rotation_euler", frame=60)

    bpy.context.preferences.edit.keyframe_new_interpolation_type = prev_interp
    scene.frame_set(1)


# ---------------------------------------------------------------------------
# 8. STUDIO LIGHTING, CAMERA & VIEWPORT SHADING SETUP
# ---------------------------------------------------------------------------
def setup_lighting_and_viewport(col):
    lights = [
        ("KeyLight_Warm", "AREA", (-2.6, -3.4, 2.8), (math.radians(58), 0, math.radians(-35)), 190.0, (1.0, 0.94, 0.88), 2.5),
        ("FillLight_Cool", "AREA", (2.8, -2.6, 1.6), (math.radians(68), 0, math.radians(42)), 80.0, (0.85, 0.90, 1.0), 2.5),
        ("RimLight_Fiery", "AREA", (0.0, 3.2, 2.6), (math.radians(-55), 0, 0), 160.0, (1.0, 0.55, 0.25), 2.2),
        ("OrbGlow_Point", "POINT", (-1.55, -1.25, 1.15), (0, 0, 0), 55.0, (1.0, 0.55, 0.15), 0.25),
    ]
    for l_name, l_type, loc, rot, energy, color, sz in lights:
        l_data = bpy.data.lights.new(name=l_name, type=l_type)
        l_data.energy = energy
        l_data.color = color
        if l_type == "AREA":
            l_data.size = sz
        l_obj = bpy.data.objects.new(name=l_name, object_data=l_data)
        col.objects.link(l_obj)
        l_obj.location = Vector(loc)
        l_obj.rotation_euler = Euler(rot, "XYZ")

    cam_data = bpy.data.cameras.new(name="PreviewCamera")
    cam_data.lens = 55.0
    cam_obj = bpy.data.objects.new(name="PreviewCamera", object_data=cam_data)
    col.objects.link(cam_obj)
    cam_obj.location = Vector((-0.25, -6.6, 0.45))
    cam_obj.rotation_euler = Euler((math.radians(87.0), 0.0, math.radians(-2.2)), "XYZ")
    bpy.context.scene.camera = cam_obj

    for window in bpy.context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == "VIEW_3D":
                for space in area.spaces:
                    if space.type == "VIEW_3D":
                        space.shading.color_type = "MATERIAL"
                        space.shading.type = "MATERIAL"
                        space.overlay.show_extras = False
                        space.overlay.show_relationship_lines = False
                        rv3d = space.region_3d
                        if rv3d:
                            rv3d.view_perspective = "PERSP"
                            rv3d.view_location = Vector((-0.10, 0.0, 0.25))
                            rv3d.view_distance = 8.2
                            rv3d.view_rotation = Euler((math.radians(82.0), 0.0, math.radians(-14.0)), "XYZ").to_quaternion()


# ---------------------------------------------------------------------------
# 9. TRIANGLE BUDGET AUDIT & EXPORT
# ---------------------------------------------------------------------------
def audit_and_export(col):
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    total_tris = 0
    for obj in col.objects:
        if obj.type == "MESH" and obj.name != "HumanoidRootPart":
            eval_obj = obj.evaluated_get(depsgraph)
            mesh = eval_obj.to_mesh()
            mesh.calc_loop_triangles()
            total_tris += len(mesh.loop_triangles)
            eval_obj.to_mesh_clear()

    print(f"[CrimsonPyromancer_Rig] Total Evaluated Triangles: {total_tris} (Budget: 2,500 - 4,200)")
    assert 2500 <= total_tris <= 4200, f"Triangle count {total_tris} outside 2,500-4,200 budget!"

    out_dir = r"c:\WORK\infinite-tower\assets\models"
    os.makedirs(out_dir, exist_ok=True)
    blend_path = os.path.join(out_dir, "crimson_pyromancer.blend")
    fbx_path = os.path.join(out_dir, "crimson_pyromancer.fbx")

    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=False,
        apply_unit_scale=True,
        bake_space_transform=True,
        object_types={"MESH", "EMPTY"},
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        path_mode="COPY",
        embed_textures=True,
    )
    print(f"[SAVED] Blend: {blend_path}")
    print(f"[SAVED] FBX:   {fbx_path}")


def main():
    rig_col = setup_clean_collection("CrimsonPyromancer_Rig")
    mats = build_materials()
    parts = build_r15_body(rig_col, mats)
    build_sculpted_hair(rig_col, parts["Head"], mats)
    build_gothic_attire(rig_col, parts, mats)
    pose_character_and_build_vfx(rig_col, parts, mats)
    setup_lighting_and_viewport(rig_col)
    audit_and_export(rig_col)


if __name__ == "__main__":
    main()
