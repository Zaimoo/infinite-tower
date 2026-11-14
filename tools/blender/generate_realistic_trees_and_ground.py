"""Generate hyper-realistic Blender trees, shrubs, grass clumps & Cycles-baked PBR terrain for Roblox Studio.

Outputs:
  assets/meshes/environment/
    HeroOakTree.fbx
    HighlandPineTree.fbx
    SakuraBlossomTree.fbx
    WildForestShrub.fbx
    GroundProp_MeadowTurfClump.fbx
    GroundMaterialsKit.fbx
    textures/
      Tex_<Name>_Color.png
      Tex_<Name>_Normal.png
      Tex_<Name>_Roughness.png

Visual renders (for inspection):
  scratch/env_preview_trees_lineup.png
  scratch/env_preview_closeup_oak_ground.png
  scratch/env_preview_textures_sheet.png

Run via:
  blender -b -P tools/blender/generate_realistic_trees_and_ground.py
"""

from __future__ import annotations

import math
import os
import random
from pathlib import Path
from typing import Callable

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

REPO_ROOT = Path(__file__).resolve().parents[2]
ENV_DIR = REPO_ROOT / "assets" / "meshes" / "environment"
TEX_DIR = ENV_DIR / "textures"
SCRATCH_DIR = Path(
    r"C:\Users\enter\.gemini\antigravity\brain\978d5919-910f-4f65-8b6b-86e51f6565cf\scratch"
)

MAX_TRIS_PER_MESHPART = 9600
TEX_SIZE = 1024
CELL_MARGIN_UV = 0.015  # ~15px guard inside each 256px 4x4 cell to prevent mip bleed


# ---------------------------------------------------------------------------
# Scene & Cycles GPU setup
# ---------------------------------------------------------------------------

def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.display_settings.display_device = "sRGB"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0

    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "OPTIX"
    prefs.get_devices()
    use_gpu = False
    for dev in prefs.devices:
        dev.use = dev.type == "OPTIX"
        if dev.use:
            use_gpu = True
    if not use_gpu:
        prefs.compute_device_type = "CUDA"
        prefs.get_devices()
        for dev in prefs.devices:
            dev.use = dev.type == "CUDA"
            if dev.use:
                use_gpu = True
    scene.cycles.device = "GPU" if use_gpu else "CPU"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.margin = 12
    scene.render.bake.margin_type = "EXTEND"
    print(f"[Cycles] Device={'GPU' if use_gpu else 'CPU'} ({prefs.compute_device_type})")


def ensure_dirs() -> None:
    ENV_DIR.mkdir(parents=True, exist_ok=True)
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    SCRATCH_DIR.mkdir(parents=True, exist_ok=True)


def clear_objects() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)


def link_obj(obj: bpy.types.Object) -> bpy.types.Object:
    bpy.context.collection.objects.link(obj)
    return obj


def set_active_only(objs: list[bpy.types.Object], active: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


# ---------------------------------------------------------------------------
# Shader node helpers (Blender 5.3 safe)
# ---------------------------------------------------------------------------

def get_node_tree(mat: bpy.types.Material) -> bpy.types.NodeTree:
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    return nt


def mix_rgba(
    nt: bpy.types.NodeTree,
    fac: bpy.types.NodeSocket | float,
    a: bpy.types.NodeSocket | tuple[float, float, float, float],
    b: bpy.types.NodeSocket | tuple[float, float, float, float],
    clamp_result: bool = True,
) -> bpy.types.NodeSocket:
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.clamp_factor = True
    mix.clamp_result = clamp_result
    fac_in = next(s for s in mix.inputs if s.enabled and s.name == "Factor")
    a_in = next(s for s in mix.inputs if s.enabled and s.name == "A")
    b_in = next(s for s in mix.inputs if s.enabled and s.name == "B")
    res_out = next(s for s in mix.outputs if s.enabled and s.name == "Result")
    if isinstance(fac, (int, float)):
        fac_in.default_value = float(fac)
    else:
        nt.links.new(fac, fac_in)
    if isinstance(a, tuple):
        a_in.default_value = a
    else:
        nt.links.new(a, a_in)
    if isinstance(b, tuple):
        b_in.default_value = b
    else:
        nt.links.new(b, b_in)
    return res_out


def mul_rgba(
    nt: bpy.types.NodeTree,
    a: bpy.types.NodeSocket | tuple[float, float, float, float],
    b: bpy.types.NodeSocket | tuple[float, float, float, float],
    fac: float = 1.0,
) -> bpy.types.NodeSocket:
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.clamp_factor = True
    mix.clamp_result = True
    fac_in = next(s for s in mix.inputs if s.enabled and s.name == "Factor")
    a_in = next(s for s in mix.inputs if s.enabled and s.name == "A")
    b_in = next(s for s in mix.inputs if s.enabled and s.name == "B")
    res_out = next(s for s in mix.outputs if s.enabled and s.name == "Result")
    fac_in.default_value = fac
    if isinstance(a, tuple):
        a_in.default_value = a
    else:
        nt.links.new(a, a_in)
    if isinstance(b, tuple):
        b_in.default_value = b
    else:
        nt.links.new(b, b_in)
    return res_out


def val_ramp(
    nt: bpy.types.NodeTree,
    fac_socket: bpy.types.NodeSocket,
    stops: list[tuple[float, tuple[float, float, float, float]]],
) -> bpy.types.NodeSocket:
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    while len(cr.elements) > len(stops):
        cr.elements.remove(cr.elements[-1])
    while len(cr.elements) < len(stops):
        cr.elements.new(0.5)
    for idx, (pos, col) in enumerate(stops):
        cr.elements[idx].position = pos
        cr.elements[idx].color = col
    nt.links.new(fac_socket, ramp.inputs["Fac"])
    return ramp.outputs["Color"]


def map_range(
    nt: bpy.types.NodeTree,
    val_socket: bpy.types.NodeSocket,
    fmin: float,
    fmax: float,
    tmin: float,
    tmax: float,
) -> bpy.types.NodeSocket:
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = fmin
    mr.inputs["From Max"].default_value = fmax
    mr.inputs["To Min"].default_value = tmin
    mr.inputs["To Max"].default_value = tmax
    nt.links.new(val_socket, mr.inputs["Value"])
    return mr.outputs["Result"]


def create_bake_image(name: str, size: int, is_srgb: bool, fill: tuple[float, float, float, float]) -> bpy.types.Image:
    img = bpy.data.images.new(name, width=size, height=size, alpha=False, float_buffer=not is_srgb)
    img.colorspace_settings.name = "sRGB" if is_srgb else "Non-Color"
    # Pre-fill flat color cleanly via generated color array when needed
    img.generated_color = fill
    return img


def save_image(img: bpy.types.Image, out_path: Path) -> Path:
    img.filepath_raw = str(out_path)
    img.file_format = "PNG"
    img.save()
    return out_path


def make_pbr_material(name: str, color_path: Path, normal_path: Path, rough_path: Path) -> bpy.types.Material:
    """Standard Principled BSDF wired directly to final PNG maps (Roblox FBX compatible)."""
    mat = bpy.data.materials.new(name)
    nt = get_node_tree(mat)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def load_tex(path: Path, colorspace: str, loc: tuple[float, float]) -> bpy.types.Node:
        tex = nt.nodes.new("ShaderNodeTexImage")
        img = bpy.data.images.load(str(path), check_existing=True)
        img.colorspace_settings.name = colorspace
        tex.image = img
        tex.location = loc
        return tex

    t_col = load_tex(color_path, "sRGB", (-400, 300))
    t_rough = load_tex(rough_path, "Non-Color", (-400, 0))
    t_norm = load_tex(normal_path, "Non-Color", (-600, -300))
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nmap.location = (-250, -300)
    nt.links.new(t_col.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(t_rough.outputs["Color"], bsdf.inputs["Roughness"])
    nt.links.new(t_norm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


# ---------------------------------------------------------------------------
# Baking harness: supports EMIT (for Albedo+AO & Roughness) and NORMAL passes
# ---------------------------------------------------------------------------

def _wire_bake_channel(mat: bpy.types.Material, mode: str, target_img: bpy.types.Image | None) -> None:
    """Rewires a bakeable procedural material whose BSDF carries Base Color / Roughness / Normal."""
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None)
    if bsdf is None or out is None:
        return

    # Ensure active bake image node if requested (on target object's material)
    for n in list(nt.nodes):
        if n.name == "__BAKE_TEX__":
            nt.nodes.remove(n)
    if target_img is not None:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.name = "__BAKE_TEX__"
        tex.image = target_img
        nt.nodes.active = tex

    # Stash original links once
    if "__ORIG_COL" not in mat:
        col_in = bsdf.inputs["Base Color"]
        rough_in = bsdf.inputs["Roughness"]
        mat["__ORIG_COL"] = col_in.links[0].from_node.name + ":" + col_in.links[0].from_socket.name if col_in.links else ""
        mat["__ORIG_ROUGH"] = rough_in.links[0].from_node.name + ":" + rough_in.links[0].from_socket.name if rough_in.links else ""

    em = next((n for n in nt.nodes if n.name == "__BAKE_EMIT__"), None)
    if em is None:
        em = nt.nodes.new("ShaderNodeEmission")
        em.name = "__BAKE_EMIT__"

    if mode == "COLOR":
        src_desc = mat.get("__ORIG_COL", "")
        if src_desc:
            n_name, s_name = src_desc.split(":", 1)
            nt.links.new(nt.nodes[n_name].outputs[s_name], em.inputs["Color"])
        else:
            em.inputs["Color"].default_value = bsdf.inputs["Base Color"].default_value
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    elif mode == "ROUGHNESS":
        src_desc = mat.get("__ORIG_ROUGH", "")
        if src_desc:
            n_name, s_name = src_desc.split(":", 1)
            nt.links.new(nt.nodes[n_name].outputs[s_name], em.inputs["Color"])
        else:
            r = bsdf.inputs["Roughness"].default_value
            em.inputs["Color"].default_value = (r, r, r, 1.0)
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    elif mode == "NORMAL":
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])


def bake_selected_to_active_pbr(
    prefix: str,
    high_objs: list[bpy.types.Object],
    low_obj: bpy.types.Object,
    size: int = TEX_SIZE,
    cage_extrusion: float = 1.6,
    ray_dist: float = 3.2,
    ao_samples: int = 16,
) -> tuple[Path, Path, Path]:
    """Bakes Color(+AO), Tangent Normal, and Roughness from high-poly rig onto low_obj UV plane."""
    scene = bpy.context.scene
    scene.cycles.samples = ao_samples

    # Target material for the receiver plane
    t_mat = bpy.data.materials.new(f"{prefix}_TargetBakeMat")
    nt = get_node_tree(t_mat)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.name = "__BAKE_TEX__"
    nt.nodes.active = tex
    low_obj.data.materials.clear()
    low_obj.data.materials.append(t_mat)

    col_img = create_bake_image(f"{prefix}_Color", size, True, (0.12, 0.14, 0.08, 1.0))
    nrm_img = create_bake_image(f"{prefix}_Normal", size, False, (0.5, 0.5, 1.0, 1.0))
    rgh_img = create_bake_image(f"{prefix}_Roughness", size, False, (0.65, 0.65, 0.65, 1.0))

    high_mats = {m for o in high_objs for m in o.data.materials if m is not None}

    set_active_only(high_objs + [low_obj], low_obj)
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = cage_extrusion
    scene.render.bake.max_ray_distance = ray_dist
    scene.render.bake.use_clear = True

    # 1. Color (+ Cycles AO) via EMIT
    for m in high_mats:
        _wire_bake_channel(m, "COLOR", None)
    tex.image = col_img
    bpy.ops.object.bake(type="EMIT")

    # 2. Roughness via EMIT
    for m in high_mats:
        _wire_bake_channel(m, "ROUGHNESS", None)
    tex.image = rgh_img
    bpy.ops.object.bake(type="EMIT")

    # 3. Tangent Normal via NORMAL (OpenGL tangent)
    for m in high_mats:
        _wire_bake_channel(m, "NORMAL", None)
    tex.image = nrm_img
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")

    c_path = save_image(col_img, TEX_DIR / f"{prefix}_Color.png")
    n_path = save_image(nrm_img, TEX_DIR / f"{prefix}_Normal.png")
    r_path = save_image(rgh_img, TEX_DIR / f"{prefix}_Roughness.png")
    print(f"[Baked] {prefix}: Color/Normal/Roughness ({size}x{size})")
    return c_path, n_path, r_path


def bake_self_pbr(
    prefix: str,
    obj: bpy.types.Object,
    size: int = TEX_SIZE,
    samples: int = 16,
) -> tuple[Path, Path, Path]:
    """Self-bakes a UV-unwrapped mesh (e.g. sculpted bark with local fork AO & moss) to PBR PNGs."""
    scene = bpy.context.scene
    scene.cycles.samples = samples

    col_img = create_bake_image(f"{prefix}_Color", size, True, (0.18, 0.14, 0.10, 1.0))
    nrm_img = create_bake_image(f"{prefix}_Normal", size, False, (0.5, 0.5, 1.0, 1.0))
    rgh_img = create_bake_image(f"{prefix}_Roughness", size, False, (0.85, 0.85, 0.85, 1.0))

    mats = [m for m in obj.data.materials if m is not None]
    set_active_only([obj], obj)
    scene.render.bake.use_selected_to_active = False
    scene.render.bake.use_clear = True
    prev_margin = scene.render.bake.margin
    scene.render.bake.margin = 48

    for mode, img in [("COLOR", col_img), ("ROUGHNESS", rgh_img), ("NORMAL", nrm_img)]:
        for m in mats:
            _wire_bake_channel(m, mode, img)
        bake_type = "NORMAL" if mode == "NORMAL" else "EMIT"
        if bake_type == "NORMAL":
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
        else:
            bpy.ops.object.bake(type="EMIT")

    scene.render.bake.margin = prev_margin

    c_path = save_image(col_img, TEX_DIR / f"{prefix}_Color.png")
    n_path = save_image(nrm_img, TEX_DIR / f"{prefix}_Normal.png")
    r_path = save_image(rgh_img, TEX_DIR / f"{prefix}_Roughness.png")
    print(f"[Self-Baked] {prefix}: Color/Normal/Roughness ({size}x{size})")
    return c_path, n_path, r_path


# ---------------------------------------------------------------------------
# Procedural Cycles PBR Shaders (used ONLY for baking crisp 1024px maps)
# ---------------------------------------------------------------------------

def make_bake_ao_shader(
    name: str,
    base_col_fn: Callable[[bpy.types.NodeTree, bpy.types.Node, bpy.types.Node], bpy.types.NodeSocket],
    rough_fn: Callable[[bpy.types.NodeTree, bpy.types.Node], bpy.types.NodeSocket | float],
    bump_fn: Callable[[bpy.types.NodeTree, bpy.types.Node], bpy.types.NodeSocket | None] | None,
    ao_dist: float = 0.55,
    ao_strength: float = 0.68,
    ao_only_local: bool = False,
    bump_dist: float = 0.04,
) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    nt = get_node_tree(mat)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    texcoord = nt.nodes.new("ShaderNodeTexCoord")
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 16
    ao.only_local = ao_only_local
    ao.inputs["Distance"].default_value = ao_dist

    col_sock = base_col_fn(nt, texcoord, ao)
    # Apply Cycles AO crevices into Base Color
    ao_tinted = val_ramp(
        nt,
        ao.outputs["AO"],
        [
            (0.0, (1.0 - ao_strength, 1.0 - ao_strength, 1.0 - ao_strength * 0.92, 1.0)),
            (0.85, (1.0, 1.0, 1.0, 1.0)),
        ],
    )
    final_col = mul_rgba(nt, col_sock, ao_tinted, 1.0)
    nt.links.new(final_col, bsdf.inputs["Base Color"])

    rough = rough_fn(nt, texcoord)
    if isinstance(rough, (int, float)):
        bsdf.inputs["Roughness"].default_value = float(rough)
    else:
        nt.links.new(rough, bsdf.inputs["Roughness"])

    if bump_fn is not None:
        height_sock = bump_fn(nt, texcoord)
        if height_sock is not None:
            bump = nt.nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = 0.85
            bump.inputs["Distance"].default_value = bump_dist
            nt.links.new(height_sock, bump.inputs["Height"])
            nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def make_soil_ground_mat(name: str, c_dark: tuple, c_mid: tuple, c_moss: tuple) -> bpy.types.Material:
    def col_fn(nt, tc, _ao):
        n1 = nt.nodes.new("ShaderNodeTexNoise")
        n1.inputs["Scale"].default_value = 6.5
        n1.inputs["Detail"].default_value = 10.0
        n1.inputs["Roughness"].default_value = 0.7
        nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
        soil = val_ramp(nt, n1.outputs["Fac"], [(0.2, c_dark), (0.8, c_mid)])

        n2 = nt.nodes.new("ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = 2.8
        n2.inputs["Detail"].default_value = 6.0
        nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
        moss_mask = val_ramp(nt, n2.outputs["Fac"], [(0.55, (0, 0, 0, 1)), (0.72, (1, 1, 1, 1))])
        return mix_rgba(nt, moss_mask, soil, c_moss)

    def rough_fn(_nt, _tc):
        return 0.90

    def bump_fn(nt, tc):
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 14.0
        n.inputs["Detail"].default_value = 8.0
        nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
        return n.outputs["Fac"]

    return make_bake_ao_shader(name, col_fn, rough_fn, bump_fn, ao_dist=0.5, ao_strength=0.72, bump_dist=0.05)


def make_blade_mat(name: str, c_base: tuple, c_mid: tuple, c_tip: tuple, roughness: float = 0.44) -> bpy.types.Material:
    """Blades use UV Y (0=stem/root, 1=sunlit tip) + vein X modulation for organic gradient."""
    def col_fn(nt, tc, _ao):
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["UV"], sep.inputs["Vector"])
        n_var = nt.nodes.new("ShaderNodeTexNoise")
        n_var.inputs["Scale"].default_value = 18.0
        nt.links.new(tc.outputs["Object"], n_var.inputs["Vector"])
        grad = val_ramp(nt, sep.outputs["Y"], [(0.0, c_base), (0.55, c_mid), (0.98, c_tip)])
        # Subtle micro-vein stripe modulation
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "X"
        wave.inputs["Scale"].default_value = 18.0
        wave.inputs["Distortion"].default_value = 1.2
        nt.links.new(tc.outputs["UV"], wave.inputs["Vector"])
        veined = val_ramp(nt, wave.outputs["Fac"], [(0.2, (0.86, 0.90, 0.85, 1)), (0.8, (1.06, 1.06, 1.02, 1))])
        tint = val_ramp(nt, n_var.outputs["Fac"], [(0.25, (0.84, 0.88, 0.84, 1)), (0.75, (1.10, 1.08, 0.96, 1))])
        return mul_rgba(nt, mul_rgba(nt, grad, veined), tint)

    def rough_fn(nt, tc):
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["UV"], sep.inputs["Vector"])
        return map_range(nt, sep.outputs["Y"], 0.0, 1.0, roughness + 0.18, roughness)

    def bump_fn(nt, tc):
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "X"
        wave.inputs["Scale"].default_value = 22.0
        nt.links.new(tc.outputs["UV"], wave.inputs["Vector"])
        return wave.outputs["Fac"]

    return make_bake_ao_shader(name, col_fn, rough_fn, bump_fn, ao_dist=0.35, ao_strength=0.65, bump_dist=0.018)


def make_bark_bake_material(
    name: str,
    bark_dark: tuple,
    bark_mid: tuple,
    bark_ridge: tuple,
    moss_col: tuple,
    ridge_scale_xy: float = 14.0,
    ridge_scale_z: float = 1.6,
    moss_height: float = 2.6,
    bump_dist: float = 0.14,
    lenticels: bool = False,
) -> bpy.types.Material:
    """World/Object-space elongated fibrous bark shader with deep crevices + Cycles local AO."""
    def col_fn(nt, tc, _ao):
        mp = nt.nodes.new("ShaderNodeMapping")
        if lenticels:
            mp.inputs["Scale"].default_value = (2.8, 2.8, 26.0)
        else:
            mp.inputs["Scale"].default_value = (ridge_scale_xy, ridge_scale_xy, ridge_scale_z)
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])

        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "Z" if lenticels else "X"
        wave.inputs["Scale"].default_value = 3.2 if lenticels else 1.8
        wave.inputs["Distortion"].default_value = 4.2 if lenticels else 7.5
        wave.inputs["Detail"].default_value = 8.0
        nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])

        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 2.4
        noise.inputs["Detail"].default_value = 12.0
        noise.inputs["Roughness"].default_value = 0.76
        noise.inputs["Distortion"].default_value = 1.6
        nt.links.new(mp.outputs["Vector"], noise.inputs["Vector"])

        fine = nt.nodes.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 22.0
        fine.inputs["Detail"].default_value = 8.0
        nt.links.new(tc.outputs["Object"], fine.inputs["Vector"])

        fissure = mix_rgba(nt, 0.55, wave.outputs["Fac"], noise.outputs["Fac"])
        base_bark = val_ramp(
            nt,
            fissure,
            [(0.18, bark_dark), (0.48, bark_mid), (0.82, bark_ridge)],
        )
        bark_grained = mul_rgba(nt, base_bark, val_ramp(nt, fine.outputs["Fac"], [(0.2, (0.78, 0.78, 0.78, 1)), (0.8, (1.16, 1.14, 1.10, 1))]))

        # Subtle pale forest lichen flecks
        lich = nt.nodes.new("ShaderNodeTexNoise")
        lich.inputs["Scale"].default_value = 6.5
        nt.links.new(tc.outputs["Object"], lich.inputs["Vector"])
        lich_mask = val_ramp(nt, lich.outputs["Fac"], [(0.70, (0, 0, 0, 1)), (0.80, (0.55, 0.55, 0.55, 1))])
        bark_w_lich = mix_rgba(nt, lich_mask, bark_grained, (0.19, 0.23, 0.14, 1.0))

        # World/Object Z moss gradient creeping up roots
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
        z_mask = map_range(nt, sep.outputs["Z"], -0.1, moss_height, 0.90, 0.0)
        moss_n = nt.nodes.new("ShaderNodeTexNoise")
        moss_n.inputs["Scale"].default_value = 4.2
        nt.links.new(tc.outputs["Object"], moss_n.inputs["Vector"])
        moss_factor = val_ramp(nt, mul_rgba(nt, z_mask, moss_n.outputs["Fac"]), [(0.28, (0, 0, 0, 1)), (0.64, (1, 1, 1, 1))])
        return mix_rgba(nt, moss_factor, bark_w_lich, moss_col)

    def rough_fn(nt, tc):
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (ridge_scale_xy, ridge_scale_xy, ridge_scale_z)
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 3.2
        nt.links.new(mp.outputs["Vector"], noise.inputs["Vector"])
        base_r = 0.54 if lenticels else 0.80
        return map_range(nt, noise.outputs["Fac"], 0.2, 0.8, base_r - 0.12, min(0.96, base_r + 0.14))

    def bump_fn(nt, tc):
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (2.8, 2.8, 26.0) if lenticels else (ridge_scale_xy, ridge_scale_xy, ridge_scale_z)
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.wave_type = "BANDS"
        wave.bands_direction = "Z" if lenticels else "X"
        wave.inputs["Scale"].default_value = 3.2 if lenticels else 1.8
        wave.inputs["Distortion"].default_value = 4.2 if lenticels else 7.5
        wave.inputs["Detail"].default_value = 8.0
        nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
        return wave.outputs["Fac"]

    return make_bake_ao_shader(
        name,
        col_fn,
        rough_fn,
        bump_fn,
        ao_dist=2.4,
        ao_strength=0.78,
        ao_only_local=True,
        bump_dist=bump_dist,
    )


def bake_seamless_bark_texture(prefix: str, species: str) -> tuple[Path, Path, Path]:
    """Bakes a 1024x1024 3x3-toroidal seamless sculpted 3D bark relief map (no UV/AO artifacts)."""
    clear_objects()
    S = 4.0
    if species == "OAK":
        c_dark = (0.022, 0.014, 0.009, 1.0)
        c_mid = (0.072, 0.048, 0.028, 1.0)
        c_ridge = (0.145, 0.102, 0.064, 1.0)
        moss_col = (0.032, 0.074, 0.020, 1.0)
        r_base = 0.84
    elif species == "PINE":
        c_dark = (0.024, 0.012, 0.008, 1.0)
        c_mid = (0.105, 0.052, 0.030, 1.0)
        c_ridge = (0.195, 0.108, 0.062, 1.0)
        moss_col = (0.028, 0.062, 0.018, 1.0)
        r_base = 0.80
    elif species == "SAKURA":
        c_dark = (0.026, 0.014, 0.016, 1.0)
        c_mid = (0.088, 0.048, 0.048, 1.0)
        c_ridge = (0.175, 0.108, 0.098, 1.0)
        moss_col = (0.038, 0.068, 0.026, 1.0)
        r_base = 0.56
    else:  # SHRUB
        c_dark = (0.045, 0.032, 0.020, 1.0)
        c_mid = (0.118, 0.086, 0.055, 1.0)
        c_ridge = (0.185, 0.140, 0.095, 1.0)
        moss_col = (0.045, 0.088, 0.028, 1.0)
        r_base = 0.82

    def bark_col(nt, tc, _ao):
        # Object-space multi-scale grain + periodic harmonic crease tinting
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
        h_mask = map_range(nt, sep.outputs["Z"], 0.02, 0.16, 0.0, 1.0)

        fine = nt.nodes.new("ShaderNodeTexNoise")
        fine.inputs["Scale"].default_value = 9.0
        fine.inputs["Detail"].default_value = 10.0
        fine.inputs["Roughness"].default_value = 0.72
        nt.links.new(tc.outputs["Object"], fine.inputs["Vector"])

        base = val_ramp(nt, h_mask, [(0.14, c_dark), (0.48, c_mid), (0.86, c_ridge)])
        grained = mul_rgba(nt, base, val_ramp(nt, fine.outputs["Fac"], [(0.2, (0.76, 0.76, 0.76, 1)), (0.8, (1.16, 1.13, 1.08, 1))]))

        # Subtle crevice moss + pale forest lichen accents
        moss_n = nt.nodes.new("ShaderNodeTexNoise")
        moss_n.inputs["Scale"].default_value = 3.2
        moss_n.inputs["Detail"].default_value = 6.0
        nt.links.new(tc.outputs["Object"], moss_n.inputs["Vector"])
        crevice = map_range(nt, sep.outputs["Z"], 0.01, 0.075, 1.0, 0.0)
        moss_f = val_ramp(nt, mul_rgba(nt, crevice, moss_n.outputs["Fac"]), [(0.42, (0, 0, 0, 1)), (0.72, (1, 1, 1, 1))])
        return mix_rgba(nt, moss_f, grained, moss_col)

    def bark_rough(nt, tc):
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
        return map_range(nt, sep.outputs["Z"], 0.01, 0.16, min(0.95, r_base + 0.14), max(0.38, r_base - 0.14))

    def bark_bump(nt, tc):
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 18.0
        n.inputs["Detail"].default_value = 8.0
        nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
        return n.outputs["Fac"]

    mat = make_bake_ao_shader(f"{prefix}_Mat", bark_col, bark_rough, bark_bump, ao_dist=0.35, ao_strength=0.76, bump_dist=0.04)

    # Periodic height function on [0, S) x [0, S) in integer harmonics of 2*pi/S -> exact zero-seam wrapping!
    grid = 96
    tau_s = math.tau / S

    def height_at(x: float, y: float) -> float:
        ax = x * tau_s
        ay = y * tau_s
        if species == "SAKURA":
            # Glossy dark cherry bark ringed by horizontal corky lenticel bands + natural gnarly ripple
            w1 = 0.25 * math.sin(ax * 2.0 + ay) + 0.14 * math.cos(ax * 3.0 - ay * 2.0)
            band = abs(math.sin(ay * 5.0 + w1)) ** 0.38
            sub = max(0.0, math.sin(ay * 11.0 + 0.6 * math.sin(ax * 4.0)))
            patch = 0.5 + 0.5 * math.sin(ax * 3.0 + ay * 2.0) * math.cos(ax * 2.0 - ay * 3.0)
            return 0.045 + 0.042 * band * (0.35 + 0.65 * patch) + 0.016 * sub
        elif species == "PINE":
            # Broken flaky jigsaw conifer bark plates (irregular multi-angle periodic cellular fissures)
            h_sum = 0.0
            for kx, ky, amp_k, ph in [
                (4, 2, 0.045, 0.4), (3, -4, 0.040, 1.7), (7, 1, 0.024, 2.5),
                (-6, 3, 0.022, 0.9), (9, -3, 0.014, 3.1),
            ]:
                v = math.sin(ax * kx + ay * ky + ph + 0.45 * math.sin(ay * 2.0 - ax * 2.0))
                h_sum += amp_k * (1.0 - (1.0 - abs(v)) ** 1.6)
            return 0.015 + max(0.0, h_sum)
        elif species == "SHRUB":
            n1 = math.sin(ax * 7.0 + 0.8 * math.sin(ay * 3.0 + ax))
            n2 = math.cos(ax * 11.0 - ay * 4.0 + 0.5 * math.sin(ay * 5.0))
            return 0.02 + 0.075 * (abs(0.65 * n1 + 0.35 * n2) ** 0.55)
        else:  # OAK
            # Rugged multi-frequency interlaced oak bark plates & broken vertical crevices (no regular stripes)
            warp_x = 0.45 * math.sin(ay * 2.0 + 0.5 * math.cos(ax * 2.0)) + 0.28 * math.cos(ay * 3.0 - ax * 2.0)
            warp_y = 0.32 * math.sin(ax * 3.0 + ay)
            r1 = abs(math.sin(ax * 5.0 + ay * 1.0 + warp_x * 2.2)) ** 0.38
            r2 = abs(math.sin(ax * 8.0 - ay * 2.0 - warp_x * 1.6 + warp_y)) ** 0.48
            r3 = 0.5 + 0.5 * math.sin(ax * 13.0 + ay * 5.0 + 1.1)
            notch = max(0.25, 0.65 + 0.45 * math.sin(ay * 4.0 + math.sin(ax * 4.0)) * math.cos(ax * 3.0 - ay * 2.0))
            return 0.012 + 0.135 * (0.52 * r1 + 0.34 * r2 + 0.14 * r3) * notch

    # Tile central tile + border aprons (-0.4..S+0.4) periodically for clean 3x3 edge normals & AO
    step = S / grid
    pad_n = 10
    min_i, max_i = -pad_n, grid + pad_n
    nx = max_i - min_i + 1
    bm = bmesh.new()
    verts = []
    for iy in range(min_i, max_i + 1):
        row = []
        y = iy * step
        for ix in range(min_i, max_i + 1):
            x = ix * step
            z = height_at(x, y)
            row.append(bm.verts.new((x, y, z)))
        verts.append(row)
    for iy in range(nx - 1):
        for ix in range(nx - 1):
            f = bm.faces.new((verts[iy][ix], verts[iy][ix + 1], verts[iy + 1][ix + 1], verts[iy + 1][ix]))
            f.smooth = True

    m = bpy.data.meshes.new(f"{prefix}_HighMesh")
    bm.to_mesh(m)
    bm.free()
    high_obj = link_obj(bpy.data.objects.new(f"{prefix}_High", m))
    high_obj.data.materials.append(mat)

    low_plane = _new_bake_plane(f"{prefix}_Plane", S, z=0.0, origin_zero=True)
    return bake_selected_to_active_pbr(prefix, [high_obj], low_plane, size=TEX_SIZE, cage_extrusion=0.45, ray_dist=0.9, ao_samples=16)


# ---------------------------------------------------------------------------
# Phase 1: Seamless 3x3 Toroidal High-Poly Terrain Textures
# ---------------------------------------------------------------------------

def _new_bake_plane(name: str, size: float, z: float = 0.0, origin_zero: bool = False) -> bpy.types.Object:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    x0, y0 = (0.0, 0.0) if origin_zero else (-size * 0.5, -size * 0.5)
    v0 = bm.verts.new((x0, y0, z))
    v1 = bm.verts.new((x0 + size, y0, z))
    v2 = bm.verts.new((x0 + size, y0 + size, z))
    v3 = bm.verts.new((x0, y0 + size, z))
    f = bm.faces.new((v0, v1, v2, v3))
    uvs = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    for loop, coord in zip(f.loops, uvs):
        loop[uv].uv = coord
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    return link_obj(bpy.data.objects.new(name, mesh))


def _add_tapered_blade_to_bmesh(
    bm: bmesh.types.BMesh,
    uv_layer,
    pos: Vector,
    yaw: float,
    tilt: float,
    bend: float,
    length: float,
    width: float,
    segs: int = 5,
    roll: float = 0.0,
) -> None:
    """Appends a realistic V-creased curved 3D blade with normalized [0..1] UVs."""
    rot_z = Matrix.Rotation(yaw, 3, "Z")
    rot_roll = Matrix.Rotation(roll, 3, "Y")
    rows = []
    for i in range(segs + 1):
        t = i / segs
        w = width * math.sin(min(1.0, (1.0 - t * 0.92)) * math.pi * 0.5) ** 0.72
        if i == segs:
            w = 0.004
        y_local = math.sin(tilt) * length * t + bend * (t ** 2) * length
        z_local = math.cos(tilt) * length * t - 0.35 * bend * (t ** 2.2) * length
        crease = w * 0.18
        pts_local = [
            Vector((-w * 0.5, y_local, z_local + crease)),
            Vector((0.0, y_local, z_local)),
            Vector((w * 0.5, y_local, z_local + crease)),
        ]
        row_v = []
        for p in pts_local:
            wp = pos + rot_z @ (rot_roll @ p)
            row_v.append(bm.verts.new(wp))
        rows.append((t, row_v))

    for i in range(segs):
        t0, r0 = rows[i]
        t1, r1 = rows[i + 1]
        for c in range(2):
            u0, u1 = c * 0.5, (c + 1) * 0.5
            f = bm.faces.new((r0[c], r0[c + 1], r1[c + 1], r1[c]))
            f.smooth = True
            for loop, uv_pt in zip(f.loops, [(u0, t0), (u1, t0), (u1, t1), (u0, t1)]):
                loop[uv_layer].uv = uv_pt


def _wrap_offsets(pos: Vector, tile: float, pad: float) -> list[Vector]:
    """Yields toroidal 3x3 copies only if pos is within pad of tile boundary (saves massive time)."""
    hx = tile * 0.5
    xs = [0.0]
    ys = [0.0]
    if pos.x < -hx + pad:
        xs.append(tile)
    elif pos.x > hx - pad:
        xs.append(-tile)
    if pos.y < -hx + pad:
        ys.append(tile)
    elif pos.y > hx - pad:
        ys.append(-tile)
    return [Vector((pos.x + dx, pos.y + dy, pos.z)) for dx in xs for dy in ys]


def bake_meadow_grass_texture() -> tuple[Path, Path, Path]:
    clear_objects()
    T = 4.0  # physical tile in meters for grass detail density
    rng = random.Random(101)

    soil_mat = make_soil_ground_mat(
        "BakeSoil_Meadow",
        (0.032, 0.025, 0.015, 1.0),
        (0.068, 0.052, 0.030, 1.0),
        (0.048, 0.088, 0.028, 1.0),
    )
    blade_fresh = make_blade_mat(
        "BakeBlade_Fresh",
        (0.025, 0.068, 0.014, 1.0),
        (0.075, 0.175, 0.032, 1.0),
        (0.155, 0.275, 0.052, 1.0),
        roughness=0.40,
    )
    blade_lush = make_blade_mat(
        "BakeBlade_Lush",
        (0.020, 0.055, 0.015, 1.0),
        (0.048, 0.140, 0.028, 1.0),
        (0.105, 0.220, 0.044, 1.0),
        roughness=0.46,
    )
    blade_dry = make_blade_mat(
        "BakeBlade_DryStraw",
        (0.055, 0.070, 0.020, 1.0),
        (0.165, 0.160, 0.045, 1.0),
        (0.285, 0.230, 0.070, 1.0),
        roughness=0.66,
    )
    clover_mat = make_blade_mat(
        "BakeClover",
        (0.022, 0.062, 0.018, 1.0),
        (0.055, 0.145, 0.038, 1.0),
        (0.095, 0.210, 0.058, 1.0),
        roughness=0.42,
    )

    # 1. Backing dark soil plane with subtle micro-bumps (covers 3x3 padded tile cleanly)
    bm_soil = bmesh.new()
    bmesh.ops.create_grid(bm_soil, x_segments=48, y_segments=48, size=T * 0.72)
    for v in bm_soil.verts:
        wx, wy = (v.co.x + T * 0.5) % T, (v.co.y + T * 0.5) % T
        v.co.z = 0.03 + 0.022 * math.sin(wx * math.tau * 2.0 / T) * math.cos(wy * math.tau * 2.0 / T)
    m_soil = bpy.data.meshes.new("MeadowSoilBed")
    bm_soil.to_mesh(m_soil)
    bm_soil.free()
    o_soil = link_obj(bpy.data.objects.new("MeadowSoilBed", m_soil))
    o_soil.data.materials.append(soil_mat)

    # 2. High-poly 3D Grass blades (~4,600 physical curved blades + toroidal border wrap)
    bm_b = bmesh.new()
    uv_b = bm_b.loops.layers.uv.new("UVMap")
    # Build 3 blade material variations via separate bmeshes
    bms = [bmesh.new(), bmesh.new(), bmesh.new()]
    uvs = [b.loops.layers.uv.new("UVMap") for b in bms]

    num_clumps = 460
    for c_idx in range(num_clumps):
        cx = rng.uniform(-T * 0.5, T * 0.5)
        cy = rng.uniform(-T * 0.5, T * 0.5)
        blades_in_clump = rng.randint(8, 12)
        style = 2 if rng.random() < 0.10 else (0 if rng.random() < 0.52 else 1)
        for _ in range(blades_in_clump):
            ang = rng.uniform(0, math.tau)
            rad = rng.uniform(0.0, 0.14)
            bx = cx + math.cos(ang) * rad
            by = cy + math.sin(ang) * rad
            # Wrap inside primary square
            bx = ((bx + T * 0.5) % T) - T * 0.5
            by = ((by + T * 0.5) % T) - T * 0.5
            length = rng.uniform(0.22, 0.52)
            width = rng.uniform(0.032, 0.055)
            yaw = ang + rng.uniform(-0.65, 0.65)
            tilt = rng.uniform(0.42, 1.05)
            bend = rng.uniform(0.18, 0.48)
            roll = rng.uniform(-0.3, 0.3)
            b_idx = 2 if (style == 2 or rng.random() < 0.07) else (0 if rng.random() < 0.55 else 1)
            for p in _wrap_offsets(Vector((bx, by, 0.015)), T, 0.58):
                _add_tapered_blade_to_bmesh(bms[b_idx], uvs[b_idx], p, yaw, tilt, bend, length, width, 4, roll)

    # 3. Real 3-leaf clovers tucked among the grass
    bm_clov = bmesh.new()
    uv_clov = bm_clov.loops.layers.uv.new("UVMap")
    for _ in range(70):
        cx = rng.uniform(-T * 0.5, T * 0.5)
        cy = rng.uniform(-T * 0.5, T * 0.5)
        base_yaw = rng.uniform(0, math.tau)
        for p in _wrap_offsets(Vector((cx, cy, rng.uniform(0.11, 0.22))), T, 0.25):
            for k in range(3):
                lyaw = base_yaw + k * (math.tau / 3.0) + rng.uniform(-0.15, 0.15)
                _add_tapered_blade_to_bmesh(
                    bm_clov,
                    uv_clov,
                    p,
                    lyaw,
                    1.28,
                    0.10,
                    rng.uniform(0.08, 0.13),
                    rng.uniform(0.07, 0.10),
                    2,
                    0.0,
                )

    highs = [o_soil]
    for idx, (bm, mat, nm) in enumerate(
        zip(bms + [bm_clov], [blade_fresh, blade_lush, blade_dry, clover_mat], ["BladesF", "BladesL", "BladesD", "Clovers"])
    ):
        m = bpy.data.meshes.new(nm)
        bm.to_mesh(m)
        bm.free()
        o = link_obj(bpy.data.objects.new(nm, m))
        o.data.materials.append(mat)
        highs.append(o)

    low_plane = _new_bake_plane("MeadowLow", T, z=0.0)
    return bake_selected_to_active_pbr("Tex_MeadowGrass", highs, low_plane, size=TEX_SIZE, cage_extrusion=0.9, ray_dist=1.8, ao_samples=16)


def make_stone_shader(
    name: str,
    tint_stops: list[tuple[float, tuple[float, float, float, float]]] | None = None,
) -> bpy.types.Material:
    stops = tint_stops or [
        (0.20, (0.145, 0.148, 0.155, 1.0)),  # cool slate grey
        (0.55, (0.205, 0.198, 0.188, 1.0)),  # weathered granite
        (0.85, (0.255, 0.232, 0.195, 1.0)),  # warm sandstone accent
    ]

    def col_fn(nt, tc, _ao):
        # Rich granite + limestone color variation per stone position + lichen flecks
        noise_grain = nt.nodes.new("ShaderNodeTexNoise")
        noise_grain.inputs["Scale"].default_value = 22.0
        noise_grain.inputs["Detail"].default_value = 10.0
        noise_grain.inputs["Roughness"].default_value = 0.72
        nt.links.new(tc.outputs["Object"], noise_grain.inputs["Vector"])

        noise_patch = nt.nodes.new("ShaderNodeTexNoise")
        noise_patch.inputs["Scale"].default_value = 2.4
        noise_patch.inputs["Detail"].default_value = 5.0
        nt.links.new(tc.outputs["Object"], noise_patch.inputs["Vector"])

        base = val_ramp(nt, noise_patch.outputs["Fac"], stops)
        speck = val_ramp(nt, noise_grain.outputs["Fac"], [(0.22, (0.72, 0.72, 0.75, 1)), (0.78, (1.18, 1.16, 1.13, 1))])
        stone = mul_rgba(nt, base, speck)

        # Pale sage lichen & moss colonies near fractures
        lich = nt.nodes.new("ShaderNodeTexNoise")
        lich.inputs["Scale"].default_value = 8.5
        nt.links.new(tc.outputs["Object"], lich.inputs["Vector"])
        lich_mask = val_ramp(nt, lich.outputs["Fac"], [(0.68, (0, 0, 0, 1)), (0.77, (0.65, 0.65, 0.65, 1))])
        return mix_rgba(nt, lich_mask, stone, (0.22, 0.26, 0.17, 1.0))

    def rough_fn(nt, tc):
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 14.0
        nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
        return map_range(nt, n.outputs["Fac"], 0.2, 0.8, 0.42, 0.76)

    def bump_fn(nt, tc):
        vor = nt.nodes.new("ShaderNodeTexVoronoi")
        vor.feature = "DISTANCE_TO_EDGE"
        vor.inputs["Scale"].default_value = 7.5
        nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 28.0
        n.inputs["Detail"].default_value = 9.0
        nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
        return mix_rgba(nt, 0.68, vor.outputs["Distance"], n.outputs["Fac"])

    return make_bake_ao_shader(name, col_fn, rough_fn, bump_fn, ao_dist=0.55, ao_strength=0.82, bump_dist=0.045)


def _clip_voronoi_poly(poly: list[tuple[float, float]], nx: float, ny: float, limit: float) -> list[tuple[float, float]]:
    if not poly:
        return []
    out: list[tuple[float, float]] = []
    n_len = len(poly)
    for i in range(n_len):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % n_len]
        da = ax * nx + ay * ny - limit
        db = bx * nx + by * ny - limit
        if da <= 0.0:
            out.append((ax, ay))
            if db > 0.0:
                t = da / (da - db)
                out.append((ax + t * (bx - ax), ay + t * (by - ay)))
        elif db <= 0.0:
            t = da / (da - db)
            out.append((ax + t * (bx - ax), ay + t * (by - ay)))
    return out


def bake_medieval_cobble_texture() -> tuple[Path, Path, Path]:
    clear_objects()
    T = 8.0
    rng = random.Random(202)

    mortar_mat = make_soil_ground_mat(
        "BakeCobbleMortar",
        (0.022, 0.020, 0.015, 1.0),
        (0.048, 0.044, 0.032, 1.0),
        (0.045, 0.105, 0.024, 1.0),
    )
    stone_mats = [
        make_stone_shader("CobbleGranite", [(0.2, (0.14, 0.145, 0.152, 1)), (0.6, (0.195, 0.195, 0.20, 1)), (0.9, (0.24, 0.235, 0.23, 1))]),
        make_stone_shader("CobbleLimestone", [(0.2, (0.175, 0.165, 0.145, 1)), (0.6, (0.245, 0.228, 0.195, 1)), (0.9, (0.295, 0.270, 0.225, 1))]),
        make_stone_shader("CobbleSlate", [(0.2, (0.115, 0.125, 0.142, 1)), (0.6, (0.165, 0.175, 0.192, 1)), (0.9, (0.215, 0.220, 0.235, 1))]),
        make_stone_shader("CobbleMossy", [(0.2, (0.140, 0.148, 0.125, 1)), (0.6, (0.200, 0.202, 0.170, 1)), (0.9, (0.250, 0.242, 0.198, 1))]),
    ]
    moss_mat = make_blade_mat(
        "BakeCobbleMoss",
        (0.020, 0.052, 0.014, 1.0),
        (0.048, 0.122, 0.026, 1.0),
        (0.092, 0.180, 0.040, 1.0),
        roughness=0.82,
    )

    # 1. Dark recessed mortar bed
    bm_m = bmesh.new()
    bmesh.ops.create_grid(bm_m, x_segments=32, y_segments=32, size=T * 0.75)
    for v in bm_m.verts:
        v.co.z = 0.03 + 0.015 * math.sin(v.co.x * 3.1) * math.cos(v.co.y * 3.1)
    m_m = bpy.data.meshes.new("CobbleMortar")
    bm_m.to_mesh(m_m)
    bm_m.free()
    o_m = link_obj(bpy.data.objects.new("CobbleMortar", m_m))
    o_m.data.materials.append(mortar_mat)

    # 2. Periodic 2D Voronoi interlocking medieval courtyard flagstones (4 geological palettes)
    cols, rows = 8, 8
    dx = T / cols
    sites: list[tuple[float, float]] = []
    for r in range(rows):
        row_shift = 0.35 * dx if (r % 2 == 1) else 0.0
        for c in range(cols):
            sx = -T * 0.5 + ((c * dx + row_shift + rng.uniform(-0.26 * dx, 0.26 * dx)) % T)
            sy = -T * 0.5 + ((r * dx + rng.uniform(-0.26 * dx, 0.26 * dx)) % T)
            sites.append((sx, sy))

    periodic_sites = [(sx + ox, sy + oy) for (sx, sy) in sites for ox in (-T, 0.0, T) for oy in (-T, 0.0, T)]
    stone_bms = [bmesh.new() for _ in range(len(stone_mats))]

    for idx, (px, py) in enumerate(sites):
        rel_nbrs = []
        for nx, ny in periodic_sites:
            rx, ry = nx - px, ny - py
            d2 = rx * rx + ry * ry
            if 1e-6 < d2 < (3.4 * dx) ** 2:
                rel_nbrs.append((d2, rx, ry))
        rel_nbrs.sort(key=lambda t: t[0])

        bound = 1.8 * dx
        poly = [(-bound, -bound), (bound, -bound), (bound, bound), (-bound, bound)]
        gap = rng.uniform(0.036, 0.056)
        for _d2, rx, ry in rel_nbrs[:14]:
            dist = math.hypot(rx, ry)
            nx, ny = rx / dist, ry / dist
            limit = 0.5 * dist - gap
            poly = _clip_voronoi_poly(poly, nx, ny, limit)
            if len(poly) < 3:
                break
        if len(poly) < 3:
            continue

        # Subdivide edges slightly with micro-chisel displacement for organic hewn look
        detailed: list[tuple[float, float]] = []
        for k in range(len(poly)):
            ax, ay = poly[k]
            bx, by = poly[(k + 1) % len(poly)]
            detailed.append((ax, ay))
            if math.hypot(bx - ax, by - ay) > 0.24:
                mx = 0.5 * (ax + bx) + rng.uniform(-0.022, 0.022)
                my = 0.5 * (ay + by) + rng.uniform(-0.022, 0.022)
                detailed.append((mx, my))

        bm_dst = stone_bms[(idx + rng.randint(0, 3)) % len(stone_bms)]
        h_stone = rng.uniform(0.18, 0.30)
        domed = rng.uniform(-0.015, 0.035)
        for center in _wrap_offsets(Vector((px, py, 0.02)), T, 1.35 * dx):
            base_r, mid_r, top_r = [], [], []
            top_c = bm_dst.verts.new((center.x, center.y, center.z + h_stone + domed))
            for vx, vy in detailed:
                jit_z = rng.uniform(-0.012, 0.014)
                base_r.append(bm_dst.verts.new((center.x + vx * 1.02, center.y + vy * 1.02, center.z - 0.02)))
                mid_r.append(bm_dst.verts.new((center.x + vx * 0.94, center.y + vy * 0.94, center.z + h_stone * 0.72)))
                top_r.append(bm_dst.verts.new((center.x + vx * 0.78, center.y + vy * 0.78, center.z + h_stone + jit_z)))
            ns = len(detailed)
            for k in range(ns):
                nk = (k + 1) % ns
                f1 = bm_dst.faces.new((base_r[k], base_r[nk], mid_r[nk], mid_r[k]))
                f2 = bm_dst.faces.new((mid_r[k], mid_r[nk], top_r[nk], top_r[k]))
                f3 = bm_dst.faces.new((top_r[k], top_r[nk], top_c))
                f1.smooth = f2.smooth = f3.smooth = True

    stone_objs = []
    for i, (bm_dst, mat) in enumerate(zip(stone_bms, stone_mats)):
        m = bpy.data.meshes.new(f"CobbleStones_{i}")
        bm_dst.to_mesh(m)
        bm_dst.free()
        o = link_obj(bpy.data.objects.new(f"CobbleStones_{i}", m))
        o.data.materials.append(mat)
        stone_objs.append(o)

    # 3. Moss tufts sprouting along Voronoi crevices
    bm_moss = bmesh.new()
    uv_moss = bm_moss.loops.layers.uv.new("UVMap")
    for px, py in sites:
        if rng.random() > 0.45:
            continue
        ang = rng.uniform(0, math.tau)
        gx = ((px + math.cos(ang) * dx * 0.48 + T * 0.5) % T) - T * 0.5
        gy = ((py + math.sin(ang) * dx * 0.48 + T * 0.5) % T) - T * 0.5
        for _ in range(9):
            bx = ((gx + rng.uniform(-0.14, 0.14) + T * 0.5) % T) - T * 0.5
            by = ((gy + rng.uniform(-0.14, 0.14) + T * 0.5) % T) - T * 0.5
            for p in _wrap_offsets(Vector((bx, by, 0.03)), T, 0.25):
                _add_tapered_blade_to_bmesh(
                    bm_moss,
                    uv_moss,
                    p,
                    rng.uniform(0, math.tau),
                    rng.uniform(0.95, 1.35),
                    0.12,
                    rng.uniform(0.06, 0.13),
                    rng.uniform(0.022, 0.042),
                    2,
                    0.0,
                )

    m_moss = bpy.data.meshes.new("CobbleMoss")
    bm_moss.to_mesh(m_moss)
    bm_moss.free()
    o_moss = link_obj(bpy.data.objects.new("CobbleMoss", m_moss))
    o_moss.data.materials.append(moss_mat)

    low_plane = _new_bake_plane("CobbleLow", T, z=0.0)
    return bake_selected_to_active_pbr("Tex_MedievalCobble", [o_m] + stone_objs + [o_moss], low_plane, size=TEX_SIZE, cage_extrusion=0.9, ray_dist=1.8, ao_samples=16)


def bake_forest_earth_texture() -> tuple[Path, Path, Path]:
    clear_objects()
    T = 5.0
    rng = random.Random(303)

    earth_mat = make_soil_ground_mat(
        "BakeForestSoil",
        (0.030, 0.020, 0.012, 1.0),
        (0.075, 0.048, 0.026, 1.0),
        (0.036, 0.078, 0.020, 1.0),
    )
    needle_mat = make_blade_mat(
        "BakeFallenNeedles",
        (0.078, 0.040, 0.016, 1.0),
        (0.140, 0.075, 0.028, 1.0),
        (0.195, 0.115, 0.042, 1.0),
        roughness=0.74,
    )
    # Dark earthy mossy river pebbles instead of bright white-grey balls
    pebble_mat = make_stone_shader(
        "BakeForestPebbles",
        [(0.2, (0.055, 0.050, 0.044, 1.0)), (0.6, (0.095, 0.082, 0.068, 1.0)), (0.9, (0.125, 0.105, 0.080, 1.0))],
    )

    bm_g = bmesh.new()
    bmesh.ops.create_grid(bm_g, x_segments=48, y_segments=48, size=T * 0.72)
    for v in bm_g.verts:
        wx, wy = (v.co.x + T * 0.5) % T, (v.co.y + T * 0.5) % T
        v.co.z = 0.04 + 0.035 * math.sin(wx * math.tau / T) * math.cos(wy * math.tau * 2.0 / T)
    m_g = bpy.data.meshes.new("ForestBed")
    bm_g.to_mesh(m_g)
    bm_g.free()
    o_g = link_obj(bpy.data.objects.new("ForestBed", m_g))
    o_g.data.materials.append(earth_mat)

    # Fallen pine needles + curved curled autumn leaf ovals
    bm_n = bmesh.new()
    uv_n = bm_n.loops.layers.uv.new("UVMap")
    for _ in range(1100):
        px = rng.uniform(-T * 0.5, T * 0.5)
        py = rng.uniform(-T * 0.5, T * 0.5)
        if rng.random() < 0.24:
            for p in _wrap_offsets(Vector((px, py, rng.uniform(0.045, 0.095))), T, 0.25):
                _add_leaf_element_to_bm(bm_n, uv_n, p, rng.uniform(0, math.tau), rng.uniform(0.06, 0.11), rng.uniform(0.11, 0.19), cup=0.024)
        else:
            for p in _wrap_offsets(Vector((px, py, rng.uniform(0.04, 0.085))), T, 0.30):
                _add_tapered_blade_to_bmesh(
                    bm_n, uv_n, p, rng.uniform(0, math.tau), rng.uniform(1.36, 1.54), 0.08, rng.uniform(0.13, 0.26), rng.uniform(0.011, 0.019), 2, rng.uniform(-0.3, 0.3)
                )
    m_n = bpy.data.meshes.new("ForestLitter")
    bm_n.to_mesh(m_n)
    bm_n.free()
    o_n = link_obj(bpy.data.objects.new("ForestLitter", m_n))
    o_n.data.materials.append(needle_mat)

    # Smaller half-buried dark forest pebbles
    bm_p = bmesh.new()
    for _ in range(75):
        px = rng.uniform(-T * 0.5, T * 0.5)
        py = rng.uniform(-T * 0.5, T * 0.5)
        rad = rng.uniform(0.028, 0.082)
        for p in _wrap_offsets(Vector((px, py, 0.032)), T, 0.16):
            res = bmesh.ops.create_icosphere(bm_p, subdivisions=2, radius=rad)
            for v in res["verts"]:
                v.co.x *= rng.uniform(0.85, 1.25)
                v.co.y *= rng.uniform(0.85, 1.25)
                v.co.z *= rng.uniform(0.40, 0.62)
                v.co += p
    m_p = bpy.data.meshes.new("ForestPebbles")
    bm_p.to_mesh(m_p)
    bm_p.free()
    o_p = link_obj(bpy.data.objects.new("ForestPebbles", m_p))
    o_p.data.materials.append(pebble_mat)

    low_plane = _new_bake_plane("ForestLow", T, z=0.0)
    return bake_selected_to_active_pbr("Tex_ForestEarth", [o_g, o_n, o_p], low_plane, size=TEX_SIZE, cage_extrusion=0.9, ray_dist=1.8, ao_samples=16)


# ---------------------------------------------------------------------------
# Phase 2: 4x4 Botanical Leaf / Needle / Blossom / Turf Atlases (Opaque!)
# ---------------------------------------------------------------------------

def _make_atlas_leaf_material(
    name: str,
    palette_row_tier: int,
    palette_col: int,
    kind: str,
) -> bpy.types.Material:
    """Renders crisp internal venation, midrib, petal veins, or needle striation per cell."""
    tier_mul = [0.56, 0.78, 0.98, 1.16][palette_row_tier]
    if kind == "SAKURA":
        # Rich cherry-blossom pinks: porcelain blush -> classic sakura pink -> deep rose heart
        col_shifts = [
            (1.04, 0.92, 0.96),
            (1.02, 0.82, 0.90),
            (0.98, 0.72, 0.84),
            (0.92, 0.60, 0.76),
        ][palette_col]
    else:
        col_shifts = [
            (0.88, 1.05, 0.88),  # deep cool forest emerald
            (0.98, 1.02, 0.94),  # balanced lush chlorophyll
            (1.08, 1.05, 0.84),  # sun-warmed meadow olive
            (1.14, 0.98, 0.80),  # sunlit tip accent
        ][palette_col]

    if kind == "OAK":
        base = (0.042, 0.118, 0.020)
        mid = (0.092, 0.215, 0.038)
        tip = (0.155, 0.305, 0.056)
        rough = 0.44
    elif kind == "PINE":
        base = (0.024, 0.072, 0.024)
        mid = (0.050, 0.138, 0.045)
        tip = (0.088, 0.195, 0.068)
        rough = 0.50
    elif kind == "SAKURA":
        # Unmistakable blooming spring sakura pinks with glowing cream petal rims
        base = (0.72, 0.24, 0.44)
        mid = (0.94, 0.54, 0.70)
        tip = (1.00, 0.84, 0.91)
        rough = 0.42
    elif kind == "SHRUB":
        if palette_col == 3 and palette_row_tier >= 2:
            # Wild cream-rose garden blossoms nestled in foliage
            base = (0.38, 0.36, 0.20)
            mid = (0.86, 0.82, 0.76)
            tip = (0.98, 0.95, 0.92)
        else:
            base = (0.032, 0.092, 0.022)
            mid = (0.072, 0.185, 0.040)
            tip = (0.135, 0.270, 0.065)
        rough = 0.46
    else:  # TURF
        base = (0.024, 0.064, 0.014)
        mid = (0.068, 0.165, 0.030)
        tip = (0.145, 0.265, 0.050) if palette_col < 3 else (0.260, 0.220, 0.065)
        rough = 0.42

    def scale_c(c):
        return (
            min(1.0, c[0] * tier_mul * col_shifts[0]),
            min(1.0, c[1] * tier_mul * col_shifts[1]),
            min(1.0, c[2] * tier_mul * col_shifts[2]),
            1.0,
        )

    return make_blade_mat(name, scale_c(base), scale_c(mid), scale_c(tip), roughness=rough)


def _add_leaf_element_to_bm(bm: bmesh.types.BMesh, uv_layer, center: Vector, yaw: float, size_x: float, size_y: float, cup: float) -> None:
    """Adds a curved 6-quad oval leaf with central vein crease for close-up Cycles atlas baking."""
    r = Matrix.Rotation(yaw, 3, "Z")
    pts = [
        (0.0, -0.50, 0.02, 0.5, 0.0),
        (-0.34, -0.25, cup, 0.15, 0.25),
        (0.0, -0.22, -cup * 0.3, 0.5, 0.25),
        (0.34, -0.25, cup, 0.85, 0.25),
        (-0.48, 0.12, cup * 1.1, 0.0, 0.58),
        (0.0, 0.14, 0.0, 0.5, 0.58),
        (0.48, 0.12, cup * 1.1, 1.0, 0.58),
        (0.0, 0.54, cup * 0.4, 0.5, 1.0),
    ]
    vs = []
    uvs = []
    for px, py, pz, u, v in pts:
        wp = center + r @ Vector((px * size_x, py * size_y, pz))
        vs.append(bm.verts.new(wp))
        uvs.append((u, v))
    tris = [
        (0, 2, 1), (0, 3, 2),
        (1, 2, 5), (1, 5, 4),
        (2, 3, 6), (2, 6, 5),
        (4, 5, 7), (5, 6, 7),
    ]
    for a, b, c in tris:
        f = bm.faces.new((vs[a], vs[b], vs[c]))
        f.smooth = True
        for loop, idx in zip(f.loops, (a, b, c)):
            loop[uv_layer].uv = uvs[idx]


def bake_botanical_4x4_atlas(prefix: str, kind: str) -> tuple[Path, Path, Path]:
    """Bakes a 4x4 opaque botanical cell atlas (Row=shadow->sunlit, Col=species/color variants)."""
    clear_objects()
    rng = random.Random(400 + sum(ord(ch) for ch in kind))
    S = 4.0  # 4 x 4 grid of 1.0m cells

    high_objs: list[bpy.types.Object] = []

    if kind == "TURF":
        # Continuous vertically-aligned densely packed blades inside each 1x1 cell
        for row in range(4):
            for col in range(4):
                mat = _make_atlas_leaf_material(f"{prefix}_m_{row}_{col}", row, col, kind)
                bm = bmesh.new()
                uv = bm.loops.layers.uv.new("UVMap")
                # Solid blade-mulch underlay inside cell
                cx0, cy0 = float(col), float(row)
                v0 = bm.verts.new((cx0 - 0.05, cy0 - 0.05, 0.03))
                v1 = bm.verts.new((cx0 + 1.05, cy0 - 0.05, 0.03))
                v2 = bm.verts.new((cx0 + 1.05, cy0 + 1.05, 0.03))
                v3 = bm.verts.new((cx0 - 0.05, cy0 + 1.05, 0.03))
                f_bg = bm.faces.new((v0, v1, v2, v3))
                for loop, coord in zip(f_bg.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
                    loop[uv].uv = coord
                for k in range(36):
                    bx = cx0 + (k / 35.0) * 1.02 - 0.01
                    by = cy0 - 0.04
                    _add_tapered_blade_to_bmesh(
                        bm,
                        uv,
                        Vector((bx, by, 0.06 + rng.uniform(0.0, 0.08))),
                        rng.uniform(-0.18, 0.18),
                        1.48,
                        0.03,
                        1.10,
                        rng.uniform(0.065, 0.115),
                        4,
                        rng.uniform(-0.2, 0.2),
                    )
                m = bpy.data.meshes.new(f"Cell_{row}_{col}")
                bm.to_mesh(m)
                bm.free()
                o = link_obj(bpy.data.objects.new(f"Cell_{row}_{col}", m))
                o.data.materials.append(mat)
                high_objs.append(o)
    else:
        for row in range(4):
            for col in range(4):
                mat = _make_atlas_leaf_material(f"{prefix}_m_{row}_{col}", row, col, kind)
                tier_mul = [0.46, 0.72, 0.96, 1.15][row]
                if kind == "SAKURA":
                    u_col = (0.42 * tier_mul, 0.14 * tier_mul, 0.26 * tier_mul, 1.0)
                elif kind == "PINE":
                    u_col = (0.015 * tier_mul, 0.048 * tier_mul, 0.015 * tier_mul, 1.0)
                else:
                    u_col = (0.020 * tier_mul, 0.064 * tier_mul, 0.013 * tier_mul, 1.0)
                under_mat = make_soil_ground_mat(f"{prefix}_u_{row}_{col}", u_col, u_col, u_col)

                bm_u = bmesh.new()
                cx0, cy0 = float(col), float(row)
                v0 = bm_u.verts.new((cx0 - 0.04, cy0 - 0.04, 0.02))
                v1 = bm_u.verts.new((cx0 + 1.04, cy0 - 0.04, 0.02))
                v2 = bm_u.verts.new((cx0 + 1.04, cy0 + 1.04, 0.02))
                v3 = bm_u.verts.new((cx0 - 0.04, cy0 + 1.04, 0.02))
                bm_u.faces.new((v0, v1, v2, v3))
                mu = bpy.data.meshes.new(f"CellU_{row}_{col}")
                bm_u.to_mesh(mu)
                bm_u.free()
                ou = link_obj(bpy.data.objects.new(f"CellU_{row}_{col}", mu))
                ou.data.materials.append(under_mat)
                high_objs.append(ou)

                bm = bmesh.new()
                uv = bm.loops.layers.uv.new("UVMap")

                # Miniature crisp leaves packed with periodic horizontal border wraps so row strips tile continuously!
                if kind == "PINE":
                    for n_i in range(420):
                        px = cx0 + rng.uniform(0.0, 1.0)
                        py = cy0 + rng.uniform(0.02, 0.98)
                        pz = rng.uniform(0.04, 0.24)
                        yaw = math.pi * 0.5 + rng.uniform(-1.10, 1.10)
                        _add_tapered_blade_to_bmesh(
                            bm,
                            uv,
                            Vector((px, py, pz)),
                            yaw,
                            rng.uniform(0.60, 0.88),
                            0.05,
                            rng.uniform(0.11, 0.22),
                            rng.uniform(0.015, 0.028),
                            2,
                            rng.uniform(-0.22, 0.22),
                        )
                elif kind == "SAKURA":
                    for f_i in range(110):
                        fx = cx0 + rng.uniform(0.0, 1.0)
                        fy = cy0 + rng.uniform(0.03, 0.97)
                        fz = rng.uniform(0.04, 0.24)
                        base_yaw = rng.uniform(0, math.tau)
                        rad = rng.uniform(0.075, 0.130)
                        for k in range(5):
                            pyaw = base_yaw + k * (math.tau / 5.0)
                            ctr = Vector((fx + math.cos(pyaw) * rad * 0.52, fy + math.sin(pyaw) * rad * 0.52, fz))
                            _add_leaf_element_to_bm(bm, uv, ctr, pyaw - math.pi * 0.5, rad * 1.0, rad * 1.18, cup=0.024)
                else:
                    for l_i in range(210):
                        lx = cx0 + rng.uniform(0.0, 1.0)
                        ly = cy0 + rng.uniform(0.03, 0.97)
                        lz = rng.uniform(0.04, 0.26)
                        sx = rng.uniform(0.085, 0.145)
                        sy = rng.uniform(0.125, 0.210)
                        _add_leaf_element_to_bm(bm, uv, Vector((lx, ly, lz)), rng.uniform(0, math.tau), sx, sy, cup=0.024)

                m = bpy.data.meshes.new(f"Cell_{row}_{col}")
                bm.to_mesh(m)
                bm.free()
                o = link_obj(bpy.data.objects.new(f"Cell_{row}_{col}", m))
                o.data.materials.append(mat)
                high_objs.append(o)

    low_plane = _new_bake_plane(f"{prefix}_Plane", S, z=0.0, origin_zero=True)
    return bake_selected_to_active_pbr(prefix, high_objs, low_plane, size=TEX_SIZE, cage_extrusion=0.8, ray_dist=1.6, ao_samples=16)


# ---------------------------------------------------------------------------
# Phase 3: Procedural Spline Tree Sculpting & Foliage Clusters (<9,600 tris!)
# ---------------------------------------------------------------------------

def _cell_uv_bounds(row: int, col: int) -> tuple[float, float, float, float]:
    u0 = col * 0.25 + CELL_MARGIN_UV
    u1 = (col + 1) * 0.25 - CELL_MARGIN_UV
    v0 = row * 0.25 + CELL_MARGIN_UV
    v1 = (row + 1) * 0.25 - CELL_MARGIN_UV
    return u0, u1, v0, v1


def _frame_from_dir(d: Vector) -> tuple[Vector, Vector, Vector]:
    z = d.normalized()
    up = Vector((0, 0, 1)) if abs(z.z) < 0.92 else Vector((1, 0, 0))
    x = up.cross(z).normalized()
    y = z.cross(x).normalized()
    return x, y, z


def _subdivide_smooth_chain(
    points: list[Vector],
    radii: list[float],
    subdivs: int = 2,
    wobble_amp: float = 0.0,
    rng: random.Random | None = None,
) -> tuple[list[Vector], list[float]]:
    """Chaikin-smooths control chains so trunks, roots & boughs flow organically instead of straight pipes."""
    pts = list(points)
    rads = list(radii)
    for _ in range(subdivs):
        if len(pts) < 2:
            break
        n_pts = [pts[0]]
        n_rads = [rads[0]]
        for i in range(len(pts) - 1):
            p0, p1 = pts[i], pts[i + 1]
            r0, r1 = rads[i], rads[i + 1]
            q0 = p0.lerp(p1, 0.25)
            q1 = p0.lerp(p1, 0.75)
            if wobble_amp > 0.0 and rng is not None and 0 < i < len(pts) - 1:
                w = wobble_amp * (0.4 + 0.6 * (r0 / max(0.05, rads[0])))
                q0 += Vector((rng.uniform(-w, w), rng.uniform(-w, w), rng.uniform(-w * 0.5, w * 0.5)))
                q1 += Vector((rng.uniform(-w, w), rng.uniform(-w, w), rng.uniform(-w * 0.5, w * 0.5)))
            n_pts.extend((q0, q1))
            n_rads.extend((r0 * 0.75 + r1 * 0.25, r0 * 0.25 + r1 * 0.75))
        n_pts.append(pts[-1])
        n_rads.append(rads[-1])
        pts, rads = n_pts, n_rads
    return pts, rads


def _sweep_branch_tube(
    bm: bmesh.types.BMesh,
    points: list[Vector],
    radii: list[float],
    sides: int = 8,
    flute_amp: float = 0.0,
    flute_count: int = 5,
    root_flare_amp: float = 0.0,
    uv_tile_v_scale: float = 4.2,
    cap_tip: bool = True,
) -> None:
    """Sweeps a seamless cylindrical-UV bark tube with fluted buttress roots along smooth 3D points."""
    uv_layer = bm.loops.layers.uv.verify()
    n = len(points)
    rings: list[list[bmesh.types.BMVert]] = []
    arc_lens: list[float] = [0.0]
    for i in range(1, n):
        arc_lens.append(arc_lens[-1] + (points[i] - points[i - 1]).length)

    t0 = (points[1] - points[0]).normalized()
    ref = Vector((1, 0, 0)) if abs(t0.x) < 0.9 else Vector((0, 1, 0))
    u_ax = ref.cross(t0).normalized()

    u_tiles = float(max(1, round((math.tau * radii[0]) / 2.6)))

    for i, (pt, rad) in enumerate(zip(points, radii)):
        t = i / max(1, n - 1)
        if i == 0:
            tan = (points[1] - points[0]).normalized()
        elif i == n - 1:
            tan = (points[-1] - points[-2]).normalized()
        else:
            tan = (points[i + 1] - points[i - 1]).normalized()

        u_ax = u_ax - tan * u_ax.dot(tan)
        if u_ax.length < 1e-4:
            ref2 = Vector((0, 1, 0)) if abs(tan.y) < 0.9 else Vector((1, 0, 0))
            u_ax = ref2.cross(tan)
        u_ax.normalize()
        v_ax = tan.cross(u_ax).normalized()

        ring = []
        base_factor = max(0.0, 1.0 - t * 2.4)
        for s in range(sides):
            ang = s * math.tau / sides
            flute = 1.0 + flute_amp * math.sin(ang * flute_count + t * 2.2) * (0.45 + 0.55 * base_factor)
            flare = 1.0 + root_flare_amp * (base_factor ** 1.55) * max(0.0, math.cos(ang * flute_count + 0.35 * math.sin(t * 4.0)))
            r_eff = rad * flute * flare
            pos = pt + (u_ax * math.cos(ang) + v_ax * math.sin(ang)) * r_eff
            ring.append(bm.verts.new(pos))
        rings.append(ring)

    for i in range(n - 1):
        r0, r1 = rings[i], rings[i + 1]
        v0_uv = arc_lens[i] / uv_tile_v_scale
        v1_uv = arc_lens[i + 1] / uv_tile_v_scale
        for s in range(sides):
            ns = (s + 1) % sides
            u0_uv = (s / sides) * u_tiles
            u1_uv = ((s + 1) / sides) * u_tiles
            f = bm.faces.new((r0[s], r0[ns], r1[ns], r1[s]))
            f.smooth = True
            for loop, coord in zip(f.loops, ((u0_uv, v0_uv), (u1_uv, v0_uv), (u1_uv, v1_uv), (u0_uv, v1_uv))):
                loop[uv_layer].uv = coord

    if cap_tip and radii[-1] > 0.02:
        tip_f = bm.faces.new(rings[-1])
        tip_f.smooth = True
        for s, loop in enumerate(tip_f.loops):
            ang = s * math.tau / sides
            loop[uv_layer].uv = (0.5 + 0.15 * math.cos(ang), 0.5 + 0.15 * math.sin(ang))


def _add_sculpted_leaf_mass(
    bm: bmesh.types.BMesh,
    uv_layer,
    center: Vector,
    rx: float,
    ry: float,
    rz: float,
    uv_bounds: tuple[float, float, float, float],
    phase: float,
    subdivisions: int = 2,
    flatten_bottom: float = 0.60,
    amp: float = 0.22,
    tile_u: float = 0.28,
) -> None:
    """Adds an organically rippled 3D botanical foliage cloud lobe (tight crisp micro-leaf UV projection)."""
    u0, u1, v0, v1 = uv_bounds
    dv = (v1 - v0) * 0.44
    uc = 0.50 + 0.18 * math.sin(phase * 1.17)
    vc = 0.5 * (v0 + v1)

    ret = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    verts = ret["verts"]
    local_dirs: dict[bmesh.types.BMVert, Vector] = {}
    rot_m = Matrix.Rotation(phase * 1.37, 3, "Z")

    for v in verts:
        lp = v.co.copy()
        d = lp.normalized()
        local_dirs[v] = d
        bump = (
            1.0
            + amp * math.sin(lp.x * 3.8 + lp.y * 2.6 + phase) * math.cos(lp.z * 3.3 - phase * 0.7)
            + (amp * 0.45) * math.cos(lp.y * 5.7 - lp.z * 4.2 + phase * 1.3)
        )
        pz = lp.z * rz * (flatten_bottom if lp.z < 0.0 else 1.0)
        scaled = Vector((lp.x * rx, lp.y * ry, pz)) * bump
        v.co = center + rot_m @ scaled

    new_faces: set[bmesh.types.BMFace] = set()
    for v in verts:
        for f in v.link_faces:
            new_faces.add(f)
    for f in new_faces:
        f.smooth = True
        for loop in f.loops:
            d = local_dirs[loop.vert]
            # Smooth unclipped U tiling across miniature horizontal foliage strip while locking V strictly inside row tier
            loop[uv_layer].uv = (
                uc + tile_u * (0.76 * d.x + 0.24 * d.y),
                vc + dv * (0.72 * d.z - 0.20 * d.y),
            )


def _add_pine_bough_plume(
    bm: bmesh.types.BMesh,
    uv_layer,
    origin: Vector,
    fwd: Vector,
    length: float,
    width: float,
    thickness: float,
    droop: float,
    uv_bounds: tuple[float, float, float, float],
    phase: float,
) -> None:
    """Adds a broad, sculpted multi-ribbed arched 3D conifer bough wing (18 tris, cascading evergreen layers)."""
    u0, u1, v0, v1 = uv_bounds
    uc = 0.5 * (u0 + u1)
    u_l, u_r = u0 + (u1 - u0) * 0.06, u1 - (u1 - u0) * 0.06
    v_a, v_b, v_c = v0 + (v1 - v0) * 0.06, v0 + (v1 - v0) * 0.50, v0 + (v1 - v0) * 0.94

    f_n = fwd.normalized()
    up_ref = Vector((0, 0, 1)) if abs(f_n.z) < 0.94 else Vector((1, 0, 0))
    side = f_n.cross(up_ref).normalized()
    up_n = side.cross(f_n).normalized()

    # Wide overlapped conifer bough plume anchored at origin & cascading smoothly outward
    c0 = origin - up_n * (thickness * 0.08)
    c1 = origin + f_n * (length * 0.34) + up_n * (thickness * 0.32 - droop * 0.14)
    c2 = origin + f_n * (length * 0.70) + up_n * (-droop * 0.52 + thickness * 0.14)
    tip = origin + f_n * length + up_n * (-droop * 0.80 + 0.05 * length * math.sin(phase))

    l0 = c0 - side * (width * 0.28)
    r0 = c0 + side * (width * 0.28)
    l1 = c1 - side * (width * 0.56) - up_n * (thickness * 0.20)
    r1 = c1 + side * (width * 0.56) - up_n * (thickness * 0.20)
    k1 = c1 - up_n * (thickness * 0.50)

    l2 = c2 - side * (width * 0.38) - up_n * (thickness * 0.14)
    r2 = c2 + side * (width * 0.38) - up_n * (thickness * 0.14)
    k2 = c2 - up_n * (thickness * 0.36)

    vc0, vl0, vr0 = bm.verts.new(c0), bm.verts.new(l0), bm.verts.new(r0)
    vc1, vl1, vr1, vk1 = bm.verts.new(c1), bm.verts.new(l1), bm.verts.new(r1), bm.verts.new(k1)
    vc2, vl2, vr2, vk2 = bm.verts.new(c2), bm.verts.new(l2), bm.verts.new(r2), bm.verts.new(k2)
    vtip = bm.verts.new(tip)

    tris = [
        # Upper sun-catching evergreen needle blanket
        ((vc0, vl0, vl1), ((uc, v_a), (u_l, v_a), (u_l, v_b))),
        ((vc0, vl1, vc1), ((uc, v_a), (u_l, v_b), (uc, v_b))),
        ((vc0, vc1, vr1), ((uc, v_a), (uc, v_b), (u_r, v_b))),
        ((vc0, vr1, vr0), ((uc, v_a), (u_r, v_b), (u_r, v_a))),
        ((vc1, vl1, vl2), ((uc, v_b), (u_l, v_b), (u_l, v_c))),
        ((vc1, vl2, vc2), ((uc, v_b), (u_l, v_c), (uc, v_c))),
        ((vc1, vc2, vr2), ((uc, v_b), (uc, v_c), (u_r, v_c))),
        ((vc1, vr2, vr1), ((uc, v_b), (u_r, v_c), (u_r, v_b))),
        ((vc2, vl2, vtip), ((uc, v_c), (u_l, v_c), (uc, v1))),
        ((vc2, vtip, vr2), ((uc, v_c), (uc, v1), (u_r, v_c))),
        # Shaded closed underside
        ((vc0, vk1, vl1), ((uc, v_a), (uc, v_b), (u_l, v_b))),
        ((vc0, vr1, vk1), ((uc, v_a), (u_r, v_b), (uc, v_b))),
        ((vk1, vk2, vl2), ((uc, v_b), (uc, v_c), (u_l, v_c))),
        ((vk1, vl2, vl1), ((uc, v_b), (u_l, v_c), (u_l, v_b))),
        ((vk1, vr1, vr2), ((uc, v_b), (u_r, v_b), (u_r, v_c))),
        ((vk1, vr2, vk2), ((uc, v_b), (u_r, v_c), (uc, v_c))),
        ((vk2, vtip, vl2), ((uc, v_c), (uc, v1), (u_l, v_c))),
        ((vk2, vr2, vtip), ((uc, v_c), (u_r, v_c), (uc, v1))),
    ]
    for verts, uvs in tris:
        f = bm.faces.new(verts)
        f.smooth = True
        for loop, coord in zip(f.loops, uvs):
            loop[uv_layer].uv = coord


def _finalize_bark_with_tile_tex(name: str, bm: bmesh.types.BMesh, tex_paths: tuple[Path, Path, Path]) -> bpy.types.Object:
    m = bpy.data.meshes.new(name)
    bm.to_mesh(m)
    bm.free()
    obj = link_obj(bpy.data.objects.new(name, m))
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"  [Mesh] {name}: {tris} tris")
    assert tris <= MAX_TRIS_PER_MESHPART, f"{name} bark tris {tris} exceeded {MAX_TRIS_PER_MESHPART}!"
    obj.data.materials.append(make_pbr_material(f"{name}_Mat", *tex_paths))
    return obj


def _finalize_foliage(
    name: str,
    bm: bmesh.types.BMesh,
    tex_paths: tuple[Path, Path, Path],
    crown_cores: list[Vector] | None = None,
    normal_blend: float = 0.88,
) -> bpy.types.Object:
    bm.normal_update()
    custom_norms: list[tuple[float, float, float]] = []
    if crown_cores and normal_blend > 0.0:
        for v in bm.verts:
            best_c = crown_cores[0]
            best_d2 = (v.co - best_c).length_squared
            for c in crown_cores[1:]:
                d2 = (v.co - c).length_squared
                if d2 < best_d2:
                    best_d2 = d2
                    best_c = c
            rad_n = v.co - best_c
            if rad_n.length > 1e-4:
                rad_n.normalize()
            else:
                rad_n = Vector((0.0, 0.0, 1.0))
            geo_n = v.normal if v.normal.length > 1e-4 else rad_n
            blended = (geo_n * (1.0 - normal_blend) + rad_n * normal_blend).normalized()
            custom_norms.append((blended.x, blended.y, blended.z))

    m = bpy.data.meshes.new(name)
    bm.to_mesh(m)
    bm.free()
    if custom_norms and hasattr(m, "normals_split_custom_set_from_vertices"):
        m.normals_split_custom_set_from_vertices(custom_norms)

    obj = link_obj(bpy.data.objects.new(name, m))
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"  [Mesh] {name}: {tris} tris")
    assert tris <= MAX_TRIS_PER_MESHPART, f"{name} foliage tris {tris} exceeded {MAX_TRIS_PER_MESHPART}!"
    obj.data.materials.append(make_pbr_material(f"{name}_Mat", *tex_paths))
    return obj


def _export_fbx(objs: list[bpy.types.Object], filename: str) -> Path:
    set_active_only(objs, objs[0])
    out_path = ENV_DIR / filename
    bpy.ops.export_scene.fbx(
        filepath=str(out_path),
        use_selection=True,
        object_types={"MESH"},
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=False,
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="FACE",
        use_mesh_modifiers=True,
    )
    print(f"[Export FBX] {out_path.name} ({out_path.stat().st_size // 1024} KB)")
    return out_path


# ---------------------------------------------------------------------------
# Hero Oak Tree
# ---------------------------------------------------------------------------

def build_hero_oak(oak_atlas: tuple[Path, Path, Path], oak_bark: tuple[Path, Path, Path]) -> tuple[Path, list[bpy.types.Object]]:
    clear_objects()
    rng = random.Random(701)
    bm_bark = bmesh.new()
    bm_fol = bmesh.new()
    uv_fol = bm_fol.loops.layers.uv.new("UVMap")

    # Winding ancient trunk with flared buttress base
    trunk_pts, trunk_r = _subdivide_smooth_chain(
        [
            Vector((0.0, 0.0, -0.45)),
            Vector((0.08, -0.05, 0.90)),
            Vector((0.18, 0.10, 2.35)),
            Vector((-0.06, 0.16, 4.10)),
            Vector((-0.14, 0.06, 5.65)),
            Vector((0.04, 0.02, 6.75)),
        ],
        [1.56, 1.06, 0.90, 0.80, 0.68, 0.50],
        subdivs=1,
        wobble_amp=0.06,
        rng=rng,
    )
    _sweep_branch_tube(bm_bark, trunk_pts, trunk_r, sides=12, flute_amp=0.10, flute_count=6, root_flare_amp=0.40)

    # 6 sinuous gnarly surface buttress roots gripping the earth
    for r_i in range(6):
        ang = r_i * (math.tau / 6.0) + rng.uniform(-0.22, 0.22)
        d = Vector((math.cos(ang), math.sin(ang), 0.0))
        side_d = Vector((-d.y, d.x, 0.0))
        rlen = rng.uniform(2.5, 3.3)
        r_pts, r_r = _subdivide_smooth_chain(
            [
                Vector((0.0, 0.0, 1.45)) + d * 0.52,
                d * (rlen * 0.38) + side_d * rng.uniform(-0.28, 0.28) + Vector((0, 0, 0.44)),
                d * (rlen * 0.72) + side_d * rng.uniform(-0.22, 0.22) + Vector((0, 0, 0.07)),
                d * rlen + Vector((0, 0, -0.30)),
            ],
            [0.48, 0.34, 0.20, 0.07],
            subdivs=1,
        )
        _sweep_branch_tube(bm_bark, r_pts, r_r, sides=7, cap_tip=False)

    # Sweeping curved oak limbs & forked sub-boughs
    crown_lobes: list[tuple[Vector, float, float, float]] = []
    leaf_clusters: list[tuple[Vector, Vector]] = []

    limb_specs = [
        (Vector((-0.04, 0.14, 4.10)), 0.35, 0.44, 6.1, 0.48),
        (Vector((-0.12, 0.06, 5.20)), 1.55, 0.36, 6.4, 0.46),
        (Vector((-0.10, 0.04, 5.55)), 2.82, 0.42, 6.2, 0.45),
        (Vector((0.02, 0.08, 4.45)), 4.10, 0.46, 5.8, 0.44),
        (Vector((-0.08, 0.05, 5.35)), 5.32, 0.35, 6.1, 0.44),
        (Vector((0.04, 0.02, 6.50)), 1.15, 0.88, 5.6, 0.42),
    ]
    for base_pt, az, elev, length, r0 in limb_specs:
        horiz = Vector((math.cos(az), math.sin(az), 0.0))
        side_v = Vector((-horiz.y, horiz.x, 0.0))
        dir1 = (horiz * math.cos(elev) + Vector((0, 0, math.sin(elev)))).normalized()
        p0 = base_pt
        p1 = p0 + dir1 * (length * 0.35) + side_v * rng.uniform(-0.45, 0.45) + Vector((0, 0, 0.42))
        p2 = p1 + (dir1 + Vector((0, 0, 0.10))).normalized() * (length * 0.34) + side_v * rng.uniform(-0.35, 0.35)
        p3 = p2 + (dir1 + Vector((0, 0, 0.22))).normalized() * (length * 0.32)
        b_pts, b_r = _subdivide_smooth_chain([p0, p1, p2, p3], [r0, r0 * 0.72, r0 * 0.46, r0 * 0.24], subdivs=1)
        _sweep_branch_tube(bm_bark, b_pts, b_r, sides=7)
        crown_lobes.append((p2, 2.55, 2.40, 1.85))
        crown_lobes.append((p3, 2.75, 2.60, 1.95))

        for fp, fr, d_az in [(p1, 0.30, 0.56), (p2, 0.24, -0.58), (p2, 0.25, 0.46), (p3, 0.20, 0.0)]:
            faz = az + d_az + rng.uniform(-0.24, 0.24)
            felev = elev + rng.uniform(-0.10, 0.36)
            fdir = Vector((math.cos(faz) * math.cos(felev), math.sin(faz) * math.cos(felev), math.sin(felev))).normalized()
            fl = rng.uniform(2.5, 3.6)
            fp1 = fp + fdir * (fl * 0.52) + Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0.28))
            fp2 = fp1 + (fdir + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0.18))).normalized() * (fl * 0.50)
            f_pts, f_r = _subdivide_smooth_chain([fp, fp1, fp2], [fr, fr * 0.56, fr * 0.20], subdivs=1)
            _sweep_branch_tube(bm_bark, f_pts, f_r, sides=5)
            crown_lobes.append((fp2, rng.uniform(2.05, 2.65), rng.uniform(1.95, 2.55), rng.uniform(1.55, 1.95)))
            leaf_clusters.append((fp1, (fp1 - Vector((0, 0, 9.2))).normalized()))
            leaf_clusters.append((fp2, (fp2 - Vector((0, 0, 9.2))).normalized()))

            for tw in range(2):
                t_az = faz + (tw - 0.5) * 0.72 + rng.uniform(-0.2, 0.2)
                t_dir = Vector((math.cos(t_az), math.sin(t_az), rng.uniform(0.12, 0.62))).normalized()
                tp = fp1.lerp(fp2, 0.45 + tw * 0.3) + t_dir * rng.uniform(1.1, 1.8)
                _sweep_branch_tube(bm_bark, [fp1.lerp(fp2, 0.5), tp], [fr * 0.22, 0.055], sides=4)
                leaf_clusters.append((tp, (tp - Vector((0, 0, 9.6))).normalized()))

    bark_obj = _finalize_bark_with_tile_tex("HeroOakTree_Bark", bm_bark, oak_bark)

    # 108 tight nested organic multi-scale foliage billows (~8,640 tris < 9,600, ZERO sharp cones!)
    sub_clouds: list[tuple[Vector, float, float, float, Vector]] = []
    macro_cores: list[Vector] = [c for c, _, _, _ in crown_lobes] + [
        Vector((0.0, 0.0, 12.6)), Vector((0.3, -0.3, 14.2))
    ]
    for cl_pos, _ in leaf_clusters:
        for _ in range(4):
            off = Vector((rng.uniform(-1.75, 1.75), rng.uniform(-1.75, 1.75), rng.uniform(-1.05, 1.45)))
            p = cl_pos + off
            if p.z < 6.4:
                p.z = 6.4 + rng.uniform(0.0, 1.0)
            rad_xy = rng.uniform(0.88, 1.48)
            rad_z = rad_xy * rng.uniform(0.68, 0.92)
            sub_clouds.append((p, rad_xy * rng.uniform(0.9, 1.15), rad_xy * rng.uniform(0.9, 1.15), rad_z, cl_pos))
    for lobe_pos, _, _, _ in crown_lobes:
        sub_clouds.append((lobe_pos, rng.uniform(1.35, 1.75), rng.uniform(1.35, 1.75), rng.uniform(1.05, 1.35), lobe_pos))
    sub_clouds.append((Vector((0.0, 0.0, 13.0)), 1.85, 1.85, 1.40, Vector((0.0, 0.0, 12.5))))
    sub_clouds.append((Vector((0.2, -0.3, 14.5)), 1.60, 1.60, 1.25, Vector((0.2, -0.3, 14.0))))

    rng.shuffle(sub_clouds)
    for idx_l, (pos, rx, ry, rz, _) in enumerate(sub_clouds[:106]):
        rel_h = max(0.0, min(1.0, (pos.z - 6.4) / 10.0))
        radial = min(1.0, Vector((pos.x, pos.y, 0.0)).length / 6.8)
        row = min(3, max(0, int((0.65 * rel_h + 0.35 * radial) * 3.7 + rng.uniform(-0.3, 0.3))))
        col = rng.randint(0, 3)
        _add_sculpted_leaf_mass(
            bm_fol, uv_fol, pos, rx, ry, rz, _cell_uv_bounds(row, col), phase=idx_l * 1.13, subdivisions=2, flatten_bottom=0.58, amp=0.22, tile_u=0.28
        )

    fol_obj = _finalize_foliage("HeroOakTree_Foliage", bm_fol, oak_atlas, crown_cores=macro_cores, normal_blend=0.88)
    fbx_path = _export_fbx([bark_obj, fol_obj], "HeroOakTree.fbx")
    return fbx_path, [bark_obj, fol_obj]


# ---------------------------------------------------------------------------
# Highland Pine Tree
# ---------------------------------------------------------------------------

def build_highland_pine(pine_atlas: tuple[Path, Path, Path], pine_bark: tuple[Path, Path, Path]) -> tuple[Path, list[bpy.types.Object]]:
    clear_objects()
    rng = random.Random(702)
    bm_bark = bmesh.new()
    bm_fol = bmesh.new()
    uv_fol = bm_fol.loops.layers.uv.new("UVMap")

    trunk_pts, trunk_r = _subdivide_smooth_chain(
        [
            Vector((0.0, 0.0, -0.45)),
            Vector((0.03, -0.02, 1.8)),
            Vector((0.09, 0.04, 5.4)),
            Vector((-0.02, 0.07, 9.8)),
            Vector((-0.09, 0.02, 14.4)),
            Vector((0.03, -0.02, 18.0)),
            Vector((0.05, 0.01, 20.3)),
        ],
        [1.18, 0.78, 0.64, 0.48, 0.32, 0.16, 0.045],
        subdivs=1,
    )
    _sweep_branch_tube(bm_bark, trunk_pts, trunk_r, sides=10, flute_amp=0.07, flute_count=5, root_flare_amp=0.35)

    for r_i in range(5):
        ang = r_i * (math.tau / 5.0) + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(ang), math.sin(ang), 0.0))
        r_pts, r_r = _subdivide_smooth_chain(
            [Vector((0, 0, 1.05)) + d * 0.42, d * 1.18 + Vector((0, 0, 0.30)), d * 2.15 + Vector((0, 0, -0.32))],
            [0.36, 0.24, 0.07],
            subdivs=1,
        )
        _sweep_branch_tube(bm_bark, r_pts, r_r, sides=6, cap_tip=False)

    # Weathered dead lower stubs (Z=2.4..3.8)
    for s_i in range(4):
        sz = 2.4 + s_i * 0.42
        az = s_i * 1.85 + rng.uniform(-0.3, 0.3)
        d = Vector((math.cos(az), math.sin(az), -0.18)).normalized()
        _sweep_branch_tube(bm_bark, [Vector((0, 0, sz)), Vector((0, 0, sz)) + d * 0.92], [0.10, 0.03], sides=4)

    plume_anchors: list[tuple[Vector, Vector, float, float, float, float]] = []
    num_tiers = 18
    for tier in range(num_tiers):
        h_norm = tier / (num_tiers - 1)
        z_base = 3.5 + h_norm * 15.2
        boughs_in_tier = max(4, int(round(7.6 - h_norm * 3.6)))
        bough_len = 5.6 * (1.0 - 0.84 * (h_norm ** 0.90))
        tier_rot = tier * 0.92
        for b_i in range(boughs_in_tier):
            az = tier_rot + b_i * (math.tau / boughs_in_tier) + rng.uniform(-0.20, 0.20)
            l_cur = bough_len * rng.uniform(0.86, 1.16)
            horiz = Vector((math.cos(az), math.sin(az), 0.0))
            sag = 0.78 * (1.0 - h_norm * 0.72)
            p0 = Vector((0.0, 0.0, z_base + rng.uniform(-0.20, 0.20)))
            p1 = p0 + horiz * (l_cur * 0.38) + Vector((0, 0, -sag * 0.70))
            p2 = p1 + horiz * (l_cur * 0.36) + Vector((0, 0, -sag * 0.32))
            p3 = p2 + horiz * (l_cur * 0.28) + Vector((0, 0, 0.26 + 0.16 * h_norm))
            r_b = max(0.035, 0.16 * (1.0 - 0.68 * h_norm))
            _sweep_branch_tube(bm_bark, [p0, p1, p2, p3], [r_b, r_b * 0.65, r_b * 0.36, 0.02], sides=5)

            # Broad overlapping evergreen bough shields fanning continuously from inner trunk out!
            for frac, sc_f in ((0.12, 1.15), (0.42, 1.12), (0.72, 0.98), (0.94, 0.82)):
                bp = p0.lerp(p3, min(1.0, frac))
                for side_s in (-0.48, 0.0, 0.48):
                    if h_norm > 0.84 and side_s != 0.0:
                        continue
                    laz = az + side_s * 0.68 + rng.uniform(-0.15, 0.15)
                    elev = -0.22 + 0.30 * h_norm + (0.08 if side_s == 0 else -0.06) + rng.uniform(-0.06, 0.08)
                    pdir = Vector((math.cos(laz) * math.cos(elev), math.sin(laz) * math.cos(elev), math.sin(elev))).normalized()
                    plume_anchors.append((
                        bp,
                        pdir,
                        rng.uniform(1.85, 2.75) * sc_f * (1.0 - 0.56 * h_norm),
                        rng.uniform(1.45, 2.25) * sc_f * (1.0 - 0.58 * h_norm),
                        rng.uniform(0.58, 0.88) * (1.0 - 0.42 * h_norm),
                        h_norm,
                    ))

    # Feathered spire apex crowns (Z=18.0 -> 20.6)
    for ap_z in (18.0, 18.5, 19.0, 19.4, 19.8, 20.2):
        for k in range(5):
            az = ap_z * 2.5 + k * (math.tau / 5.0)
            pdir = Vector((math.cos(az) * 0.60, math.sin(az) * 0.60, 0.78)).normalized()
            sc_ap = 1.0 - (ap_z - 18.0) / 3.4
            plume_anchors.append((Vector((0, 0, ap_z)), pdir, 1.25 * sc_ap, 0.88 * sc_ap, 0.36, 1.0))

    bark_obj = _finalize_bark_with_tile_tex("HighlandPineTree_Bark", bm_bark, pine_bark)

    # 385 cascading broad 18-tri evergreen conifer wings = 6,930 tris (NO central bumpy blobs!)
    rng.shuffle(plume_anchors)
    for idx_p, (pos, pdir, plen, pwid, pthick, hn) in enumerate(plume_anchors[:385]):
        rad_n = min(1.0, Vector((pos.x, pos.y, 0.0)).length / 4.8)
        sun_score = 0.65 * hn + 0.35 * rad_n
        row = min(3, max(0, int(sun_score * 3.8 + rng.uniform(-0.28, 0.35))))
        col = rng.randint(0, 3)
        _add_pine_bough_plume(
            bm_fol,
            uv_fol,
            pos,
            pdir,
            length=plen,
            width=pwid,
            thickness=pthick,
            droop=plen * 0.30,
            uv_bounds=_cell_uv_bounds(row, col),
            phase=idx_p * 0.91,
        )

    pine_cores = [Vector((0.0, 0.0, 10.5)), Vector((0.0, 0.0, 15.0)), Vector((0.0, 0.0, 19.0))]
    fol_obj = _finalize_foliage("HighlandPineTree_Foliage", bm_fol, pine_atlas, crown_cores=pine_cores, normal_blend=0.58)
    fbx_path = _export_fbx([bark_obj, fol_obj], "HighlandPineTree.fbx")
    return fbx_path, [bark_obj, fol_obj]


# ---------------------------------------------------------------------------
# Sakura Blossom Tree
# ---------------------------------------------------------------------------

def build_sakura_blossom(sakura_atlas: tuple[Path, Path, Path], sakura_bark: tuple[Path, Path, Path]) -> tuple[Path, list[bpy.types.Object]]:
    clear_objects()
    rng = random.Random(703)
    bm_bark = bmesh.new()
    bm_fol = bmesh.new()
    uv_fol = bm_fol.loops.layers.uv.new("UVMap")

    trunk_pts, trunk_r = _subdivide_smooth_chain(
        [
            Vector((0.0, 0.0, -0.42)),
            Vector((-0.20, 0.07, 0.88)),
            Vector((-0.38, 0.16, 2.25)),
            Vector((-0.14, 0.08, 3.55)),
            Vector((0.08, -0.06, 4.55)),
        ],
        [1.06, 0.76, 0.64, 0.54, 0.42],
        subdivs=1,
    )
    _sweep_branch_tube(bm_bark, trunk_pts, trunk_r, sides=10, flute_amp=0.06, flute_count=5, root_flare_amp=0.36)

    for r_i in range(5):
        ang = r_i * (math.tau / 5.0) + rng.uniform(-0.25, 0.25)
        d = Vector((math.cos(ang), math.sin(ang), 0.0))
        r_pts, r_r = _subdivide_smooth_chain(
            [Vector((-0.12, 0.06, 0.92)) + d * 0.34, d * 1.15 + Vector((0, 0, 0.28)), d * 2.0 + Vector((0, 0, -0.30))],
            [0.34, 0.22, 0.07],
            subdivs=1,
        )
        _sweep_branch_tube(bm_bark, r_pts, r_r, sides=6, cap_tip=False)

    blossom_clouds: list[tuple[Vector, float]] = []
    bough_specs = [
        (Vector((-0.14, 0.08, 3.55)), 0.4, 0.34, 5.3, 0.36),
        (Vector((0.08, -0.06, 4.45)), 1.8, 0.40, 5.7, 0.34),
        (Vector((-0.14, 0.08, 3.65)), 3.3, 0.30, 5.5, 0.36),
        (Vector((0.05, -0.03, 4.35)), 4.9, 0.38, 4.9, 0.32),
        (Vector((0.08, -0.06, 4.55)), 2.5, 0.72, 4.6, 0.30),
    ]
    for base_pt, az, elev, length, r0 in bough_specs:
        horiz = Vector((math.cos(az), math.sin(az), 0.0))
        d = (horiz * math.cos(elev) + Vector((0, 0, math.sin(elev)))).normalized()
        p1 = base_pt + d * (length * 0.42) + Vector((0, 0, 0.38))
        p2 = p1 + (d + Vector((0, 0, -0.06))).normalized() * (length * 0.34)
        p3 = p2 + (d + Vector((0, 0, 0.16))).normalized() * (length * 0.30)
        b_pts, b_r = _subdivide_smooth_chain([base_pt, p1, p2, p3], [r0, r0 * 0.66, r0 * 0.40, 0.08], subdivs=1)
        _sweep_branch_tube(bm_bark, b_pts, b_r, sides=6)
        blossom_clouds.append((p2, 1.85))
        blossom_clouds.append((p3, 2.05))

        for fork_pt, d_az in [(p1, 0.56), (p2, -0.52), (p2, 0.44), (p3, 0.0)]:
            faz = az + d_az + rng.uniform(-0.2, 0.2)
            felev = rng.uniform(0.08, 0.35)
            fdir = Vector((math.cos(faz) * math.cos(felev), math.sin(faz) * math.cos(felev), math.sin(felev))).normalized()
            fl = rng.uniform(2.0, 3.0)
            fp1 = fork_pt + fdir * (fl * 0.5)
            fp2 = fp1 + (fdir + Vector((0, 0, 0.16))).normalized() * (fl * 0.52)
            f_pts, f_r = _subdivide_smooth_chain([fork_pt, fp1, fp2], [0.16, 0.09, 0.03], subdivs=1)
            _sweep_branch_tube(bm_bark, f_pts, f_r, sides=5)
            blossom_clouds.append((fp1, 1.55))
            blossom_clouds.append((fp2, 1.70))
            for s in (-0.65, 0.65):
                sub_az = faz + s
                sp = fp1.lerp(fp2, 0.55) + Vector((math.cos(sub_az), math.sin(sub_az), 0.3)) * 1.05
                blossom_clouds.append((sp, 1.45))

    bark_obj = _finalize_bark_with_tile_tex("SakuraBlossomTree_Bark", bm_bark, sakura_bark)

    # 106 nested soft flattened pink cherry blossom clouds (~8,480 tris < 9,600, ZERO sharp triangles!)
    sakura_subclouds: list[tuple[Vector, float, float, float]] = []
    macro_cores = [c for c, _ in blossom_clouds]
    for cp, cr in blossom_clouds:
        sakura_subclouds.append((cp, cr * 0.82, cr * 0.82, cr * 0.46))
        for _ in range(3):
            p = cp + Vector((rng.uniform(-cr * 0.9, cr * 0.9), rng.uniform(-cr * 0.9, cr * 0.9), rng.uniform(-0.35, 0.65)))
            if p.z < 5.0:
                p.z = 5.0 + rng.uniform(0.0, 0.5)
            r_sub = cr * rng.uniform(0.45, 0.72)
            sakura_subclouds.append((p, r_sub * rng.uniform(0.9, 1.15), r_sub * rng.uniform(0.9, 1.15), r_sub * 0.56))

    rng.shuffle(sakura_subclouds)
    for idx_c, (cp, rx, ry, rz) in enumerate(sakura_subclouds[:106]):
        rel_h = max(0.0, min(1.0, (cp.z - 5.0) / 6.8))
        radial = min(1.0, Vector((cp.x, cp.y, 0.0)).length / 6.2)
        row = min(3, max(0, int((0.65 * rel_h + 0.35 * radial) * 3.7 + rng.uniform(-0.25, 0.3))))
        col = rng.randint(0, 3)
        _add_sculpted_leaf_mass(
            bm_fol, uv_fol, cp, rx, ry, rz, _cell_uv_bounds(row, col), phase=idx_c * 1.21, subdivisions=2, flatten_bottom=0.50, amp=0.20, tile_u=0.28
        )

    fol_obj = _finalize_foliage("SakuraBlossomTree_Foliage", bm_fol, sakura_atlas, crown_cores=macro_cores, normal_blend=0.88)
    fbx_path = _export_fbx([bark_obj, fol_obj], "SakuraBlossomTree.fbx")
    return fbx_path, [bark_obj, fol_obj]


# ---------------------------------------------------------------------------
# Wild Forest Shrub, Meadow Turf Clump & GroundMaterialsKit
# ---------------------------------------------------------------------------

def build_wild_shrub(shrub_atlas: tuple[Path, Path, Path], shrub_bark: tuple[Path, Path, Path]) -> tuple[Path, list[bpy.types.Object]]:
    clear_objects()
    rng = random.Random(704)
    bm_wood = bmesh.new()
    bm_fol = bmesh.new()
    uv_fol = bm_fol.loops.layers.uv.new("UVMap")

    tips: list[tuple[Vector, Vector]] = []
    for k in range(7):
        az = k * (math.tau / 7.0) + rng.uniform(-0.2, 0.2)
        elev = rng.uniform(0.45, 1.05)
        l = rng.uniform(1.5, 2.2)
        d = Vector((math.cos(az) * math.cos(elev), math.sin(az) * math.cos(elev), math.sin(elev))).normalized()
        p0 = Vector((0, 0, -0.15))
        p1 = p0 + d * (l * 0.55)
        p2 = p1 + (d + Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.2, 0.2), 0.15))).normalized() * (l * 0.48)
        _sweep_branch_tube(bm_wood, [p0, p1, p2], [0.16, 0.09, 0.03], sides=5)
        tips.append((p1, d))
        tips.append((p2, d))
        for side in (-0.55, 0.55):
            sp = p1 + Vector((math.cos(az + side), math.sin(az + side), 0.35)) * 0.65
            tips.append((sp, (sp - Vector((0, 0, 0.6))).normalized()))

    wood_obj = _finalize_bark_with_tile_tex("WildForestShrub_Wood", bm_wood, shrub_bark)

    # 44 nested low organic thicket leaf pillows (~3,520 tris < 9,600, ZERO sharp spike cones!)
    mound_centers = [Vector((0.0, 0.0, 1.10))] + [
        Vector((math.cos(k * math.tau / 6.0) * 1.05, math.sin(k * math.tau / 6.0) * 1.05, 0.85 + (k % 2) * 0.25))
        for k in range(6)
    ]
    shrub_clouds: list[tuple[Vector, float]] = [(m, 0.78) for m in mound_centers]
    for tp, _ in tips:
        for _ in range(2):
            p = tp + Vector((rng.uniform(-0.55, 0.55), rng.uniform(-0.55, 0.55), rng.uniform(-0.30, 0.45)))
            p.z = max(0.32, p.z)
            shrub_clouds.append((p, rng.uniform(0.38, 0.64)))

    rng.shuffle(shrub_clouds)
    for idx_m, (mp, mr) in enumerate(shrub_clouds[:44]):
        h_n = min(1.0, mp.z / 2.4)
        row = min(3, max(0, int(h_n * 3.6)))
        col = 3 if (h_n > 0.62 and rng.random() < 0.28) else rng.randint(0, 2)
        _add_sculpted_leaf_mass(
            bm_fol, uv_fol, mp, mr * rng.uniform(0.95, 1.25), mr * rng.uniform(0.95, 1.25), mr * 0.76, _cell_uv_bounds(row, col), phase=idx_m * 1.4, subdivisions=2, flatten_bottom=0.52, amp=0.22, tile_u=0.28
        )

    fol_obj = _finalize_foliage("WildForestShrub_Foliage", bm_fol, shrub_atlas, crown_cores=[Vector((0.0, 0.0, 0.75))], normal_blend=0.88)
    fbx_path = _export_fbx([wood_obj, fol_obj], "WildForestShrub.fbx")
    return fbx_path, [wood_obj, fol_obj]


def build_meadow_turf_clump(turf_atlas: tuple[Path, Path, Path]) -> tuple[Path, list[bpy.types.Object]]:
    clear_objects()
    rng = random.Random(705)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    # 175 arching parabolic 3D grass blades clustered organically (~4.2 x 1.35 x 4.2 studs)
    for _ in range(175):
        rad = (rng.random() ** 0.72) * 1.85
        ang = rng.uniform(0, math.tau)
        bx = math.cos(ang) * rad
        by = math.sin(ang) * rad
        yaw = ang + rng.uniform(-0.55, 0.55)
        length = rng.uniform(0.75, 1.65) * (1.15 - 0.35 * (rad / 1.85))
        width = rng.uniform(0.10, 0.16)
        tilt = rng.uniform(0.28, 0.92)
        bend = rng.uniform(0.18, 0.48)
        row = min(3, max(0, int((length / 1.65) * 3.2)))
        col = 3 if rng.random() < 0.14 else rng.randint(0, 2)
        u0, u1, v0, v1 = _cell_uv_bounds(row, col)

        # Build V-profile curved blade mapped inside [u0..u1]x[v0..v1]
        segs = 3
        rot_z = Matrix.Rotation(yaw, 3, "Z")
        rows_v = []
        for s in range(segs + 1):
            t = s / segs
            w = width * (1.0 - t * 0.88)
            yl = math.sin(tilt) * length * t + bend * (t ** 2) * length
            zl = -0.10 + math.cos(tilt) * length * t - 0.34 * bend * (t ** 2.2) * length
            p_l = Vector((bx, by, 0.0)) + rot_z @ Vector((-w * 0.5, yl, zl + w * 0.18))
            p_r = Vector((bx, by, 0.0)) + rot_z @ Vector((w * 0.5, yl, zl + w * 0.18))
            rows_v.append((t, bm.verts.new(p_l), bm.verts.new(p_r)))
        for s in range(segs):
            t0, l0, r0 = rows_v[s]
            t1, l1, r1 = rows_v[s + 1]
            vt0 = v0 + t0 * (v1 - v0)
            vt1 = v0 + t1 * (v1 - v0)
            f = bm.faces.new((l0, r0, r1, l1))
            f.smooth = True
            for loop, coord in zip(f.loops, [(u0, vt0), (u1, vt0), (u1, vt1), (u0, vt1)]):
                loop[uv].uv = coord

    turf_obj = _finalize_foliage("MeadowTurfClump", bm, turf_atlas)
    fbx_path = _export_fbx([turf_obj], "GroundProp_MeadowTurfClump.fbx")
    return fbx_path, [turf_obj]


def build_ground_materials_kit(
    grass_tex: tuple[Path, Path, Path],
    cobble_tex: tuple[Path, Path, Path],
    earth_tex: tuple[Path, Path, Path],
) -> tuple[Path, list[bpy.types.Object]]:
    clear_objects()
    rng = random.Random(706)
    objs: list[bpy.types.Object] = []

    def make_slab(name: str, tex: tuple[Path, Path, Path], x_off: float) -> bpy.types.Object:
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        # 16 x 16 x 0.4m slab, top at Z=0
        hx, hy, hz = 8.0, 8.0, 0.4
        v_top = [
            bm.verts.new((-hx, -hy, 0.0)),
            bm.verts.new((hx, -hy, 0.0)),
            bm.verts.new((hx, hy, 0.0)),
            bm.verts.new((-hx, hy, 0.0)),
        ]
        v_bot = [
            bm.verts.new((-hx, -hy, -hz)),
            bm.verts.new((hx, -hy, -hz)),
            bm.verts.new((hx, hy, -hz)),
            bm.verts.new((-hx, hy, -hz)),
        ]
        f_top = bm.faces.new(v_top)
        for loop, coord in zip(f_top.loops, [(0, 0), (1, 0), (1, 1), (0, 1)]):
            loop[uv].uv = coord
        bm.faces.new(list(reversed(v_bot)))
        for k in range(4):
            nk = (k + 1) % 4
            f_s = bm.faces.new((v_bot[k], v_bot[nk], v_top[nk], v_top[k]))
            for loop, coord in zip(f_s.loops, [(0, 0), (1, 0), (1, 0.05), (0, 0.05)]):
                loop[uv].uv = coord
        m = bpy.data.meshes.new(name)
        bm.to_mesh(m)
        bm.free()
        o = link_obj(bpy.data.objects.new(name, m))
        o.location = (x_off, 0.0, 0.0)
        o.data.materials.append(make_pbr_material(f"{name}_Mat", *tex))
        return o

    objs.append(make_slab("Ground_MeadowGrass", grass_tex, -27.0))
    objs.append(make_slab("Ground_MedievalCobble", cobble_tex, -9.0))
    objs.append(make_slab("Ground_ForestEarth", earth_tex, 9.0))

    # Ground_MossyRootCollar (~7.4 x 1.15 x 7.4 sculpted soil mound + 7 mossy stones around tree base)
    bm_c = bmesh.new()
    uv_c = bm_c.loops.layers.uv.new("UVMap")
    rings, segs = 6, 24
    ring_verts: list[list[bmesh.types.BMVert]] = []
    radii = [0.65, 1.35, 2.05, 2.75, 3.35, 3.85]
    heights = [0.58, 0.54, 0.42, 0.24, 0.06, -0.22]
    for r_idx, (rad, h0) in enumerate(zip(radii, heights)):
        rv = []
        for s in range(segs):
            ang = s * math.tau / segs
            r_j = rad * (1.0 + 0.08 * math.sin(ang * 5.0 + r_idx))
            h_j = h0 + 0.08 * math.cos(ang * 3.0 + r_idx * 1.4)
            rv.append(bm_c.verts.new((math.cos(ang) * r_j, math.sin(ang) * r_j, h_j)))
        ring_verts.append(rv)
    # Close inner soil well at Z=0.45
    ctr = bm_c.verts.new((0.0, 0.0, 0.48))
    for s in range(segs):
        ns = (s + 1) % segs
        f = bm_c.faces.new((ctr, ring_verts[0][s], ring_verts[0][ns]))
        f.smooth = True
    for r_idx in range(rings - 1):
        for s in range(segs):
            ns = (s + 1) % segs
            f = bm_c.faces.new((ring_verts[r_idx][s], ring_verts[r_idx + 1][s], ring_verts[r_idx + 1][ns], ring_verts[r_idx][ns]))
            f.smooth = True

    # Planar projection UVs centered at 0 scaled nicely to tile Earth detail across collar
    for f in bm_c.faces:
        for loop in f.loops:
            co = loop.vert.co
            loop[uv_c].uv = (co.x / 5.0 + 0.5, co.y / 5.0 + 0.5)

    m_c = bpy.data.meshes.new("Ground_MossyRootCollar")
    bm_c.to_mesh(m_c)
    bm_c.free()
    collar = link_obj(bpy.data.objects.new("Ground_MossyRootCollar", m_c))
    collar.location = (27.0, 0.0, 0.0)
    collar.data.materials.append(make_pbr_material("Ground_MossyRootCollar_Mat", *earth_tex))
    tris_c = sum(len(p.vertices) - 2 for p in collar.data.polygons)
    print(f"  [Mesh] Ground_MossyRootCollar: {tris_c} tris")
    objs.append(collar)

    fbx_path = _export_fbx(objs, "GroundMaterialsKit.fbx")
    return fbx_path, objs


# ---------------------------------------------------------------------------
# Phase 4: Visual Showcase Cycles Renders (Inspection Before Delivery!)
# ---------------------------------------------------------------------------

def render_visual_previews(
    grass_tex: tuple[Path, Path, Path],
    cobble_tex: tuple[Path, Path, Path],
    earth_tex: tuple[Path, Path, Path],
    oak_fbx: Path,
    pine_fbx: Path,
    sakura_fbx: Path,
    shrub_fbx: Path,
    turf_fbx: Path,
    kit_fbx: Path,
) -> None:
    clear_objects()
    scene = bpy.context.scene
    scene.cycles.samples = 48
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.exposure = -1.15

    # Physical sky lighting matching Roblox afternoon sunlight (ClockTime=14.8)
    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    if world.node_tree is None:
        world.use_nodes = True
    wnt = world.node_tree
    wnt.nodes.clear()
    w_out = wnt.nodes.new("ShaderNodeOutputWorld")
    bg = wnt.nodes.new("ShaderNodeBackground")
    sky = wnt.nodes.new("ShaderNodeTexSky")
    sky.sky_type = "MULTIPLE_SCATTERING"
    if hasattr(sky, "sun_elevation"):
        sky.sun_elevation = math.radians(42.0)
        sky.sun_rotation = math.radians(38.0)
    bg.inputs["Strength"].default_value = 0.34
    wnt.links.new(sky.outputs["Color"], bg.inputs["Color"])
    wnt.links.new(bg.outputs["Background"], w_out.inputs["Surface"])

    # Sun key light
    sun_d = bpy.data.lights.new("SunKey", type="SUN")
    sun_d.energy = 2.6
    sun_d.angle = math.radians(1.6)
    sun_d.color = (1.0, 0.96, 0.90)
    sun = link_obj(bpy.data.objects.new("SunKey", sun_d))
    sun.rotation_euler = (math.radians(46.0), math.radians(14.0), math.radians(-38.0))

    # Tiled meadow + cobble path showcase stage (XY plane Z=0)
    def make_stage_plane(name: str, w: float, d: float, tile_u: float, tile_v: float, z: float, mat: bpy.types.Material, loc=(0, 0, 0)):
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        v0 = bm.verts.new((-w * 0.5, -d * 0.5, z))
        v1 = bm.verts.new((w * 0.5, -d * 0.5, z))
        v2 = bm.verts.new((w * 0.5, d * 0.5, z))
        v3 = bm.verts.new((-w * 0.5, d * 0.5, z))
        f = bm.faces.new((v0, v1, v2, v3))
        for loop, coord in zip(f.loops, [(0, 0), (tile_u, 0), (tile_u, tile_v), (0, tile_v)]):
            loop[uv].uv = coord
        m = bpy.data.meshes.new(name)
        bm.to_mesh(m)
        bm.free()
        o = link_obj(bpy.data.objects.new(name, m))
        o.location = loc
        o.data.materials.append(mat)
        return o

    grass_mat = make_pbr_material("StageGrass", *grass_tex)
    cobble_mat = make_pbr_material("StageCobble", *cobble_tex)
    make_stage_plane("StageLawn", 96.0, 56.0, 12.0, 7.0, 0.0, grass_mat)
    make_stage_plane("StageCobblePath", 88.0, 8.0, 11.0, 1.0, 0.03, cobble_mat, loc=(0, -14.0, 0.0))

    # Import back our exact exported FBXs (verifies the actual exported FBXs!)
    def import_at(fbx: Path, loc: tuple[float, float, float], rot_z: float = 0.0) -> list[bpy.types.Object]:
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=str(fbx))
        added = [o for o in bpy.data.objects if o not in before]
        for o in added:
            o.location = (o.location.x + loc[0], o.location.y + loc[1], o.location.z + loc[2])
            o.rotation_euler.z += rot_z
        return added

    import_at(oak_fbx, (-15.0, 3.0, 0.0))
    import_at(pine_fbx, (0.0, 5.0, 0.0))
    import_at(sakura_fbx, (16.0, 3.0, 0.0))
    import_at(shrub_fbx, (-8.0, -5.0, 0.0))
    import_at(shrub_fbx, (8.5, -5.5, 0.0), rot_z=1.1)
    for cx, cy in [(-14.2, -1.0), (-16.8, 0.5), (-9.2, -7.2), (-1.8, -0.5), (1.8, -1.0), (14.5, -0.8), (18.2, -1.5), (6.8, -8.5)]:
        import_at(turf_fbx, (cx, cy, 0.0), rot_z=cx * 0.7)

    # Camera 1: Wide Lineup (Oak + Pine + Sakura + Shrub + Turf + Meadow/Cobble)
    cam_d = bpy.data.cameras.new("PreviewCam")
    cam_d.lens = 35.0
    cam = link_obj(bpy.data.objects.new("PreviewCam", cam_d))
    scene.camera = cam

    def aim(pos: Vector, target: Vector) -> None:
        cam.location = pos
        d = (target - pos).normalized()
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

    scene.render.resolution_x = 1440
    scene.render.resolution_y = 860

    aim(Vector((1.0, -34.0, 11.5)), Vector((0.5, 1.0, 7.5)))
    scene.render.filepath = str(SCRATCH_DIR / "env_preview_trees_lineup.png")
    bpy.ops.render.render(write_still=True)

    # Camera 2: Dramatic close-up of Oak roots, Mossy collar / Shrub, Turf Clump & Cobblestone ground
    aim(Vector((-8.5, -18.5, 4.2)), Vector((-12.5, -2.5, 3.2)))
    scene.render.filepath = str(SCRATCH_DIR / "env_preview_closeup_oak_ground.png")
    bpy.ops.render.render(write_still=True)

    # Camera 3: Ground Materials Trio Overhead Sheet (MeadowGrass, MedievalCobble, ForestEarth)
    clear_objects()
    sun_d2 = bpy.data.lights.new("SunSheet", type="SUN")
    sun_d2.energy = 2.0
    sun2 = link_obj(bpy.data.objects.new("SunSheet", sun_d2))
    sun2.rotation_euler = (math.radians(32.0), math.radians(18.0), math.radians(-28.0))
    grass_mat2 = make_pbr_material("StageGrassSheet", *grass_tex)
    cobble_mat2 = make_pbr_material("StageCobbleSheet", *cobble_tex)
    earth_mat2 = make_pbr_material("StageEarthSheet", *earth_tex)
    make_stage_plane("SampleGrass", 14.0, 14.0, 1.0, 1.0, 0.0, grass_mat2, loc=(-15.5, 0.0, 0.0))
    make_stage_plane("SampleCobble", 14.0, 14.0, 1.0, 1.0, 0.0, cobble_mat2, loc=(0.0, 0.0, 0.0))
    make_stage_plane("SampleEarth", 14.0, 14.0, 1.0, 1.0, 0.0, earth_mat2, loc=(15.5, 0.0, 0.0))
    cam_d2 = bpy.data.cameras.new("SheetCam")
    cam_d2.lens = 45.0
    cam = link_obj(bpy.data.objects.new("SheetCam", cam_d2))
    scene.camera = cam
    aim(Vector((0.0, -20.0, 26.0)), Vector((0.0, 0.0, 0.0)))
    scene.render.resolution_x = 1350
    scene.render.resolution_y = 560
    scene.render.filepath = str(SCRATCH_DIR / "env_preview_textures_sheet.png")
    bpy.ops.render.render(write_still=True)
    print(f"[Renders] Previews saved to {SCRATCH_DIR}")


# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

def _tex_triplet_exists(prefix: str) -> tuple[Path, Path, Path] | None:
    paths = (
        TEX_DIR / f"{prefix}_Color.png",
        TEX_DIR / f"{prefix}_Normal.png",
        TEX_DIR / f"{prefix}_Roughness.png",
    )
    return paths if all(p.exists() for p in paths) else None


def main() -> None:
    ensure_dirs()
    reset_scene()
    force_rebake = os.environ.get("REBAKE_ATLASES") == "1"

    print("=== Step 1: Ground textures (1024x1024 PBR) ===")
    grass_tex = (None if force_rebake else _tex_triplet_exists("Tex_MeadowGrass")) or bake_meadow_grass_texture()
    cobble_tex = (None if force_rebake else _tex_triplet_exists("Tex_MedievalCobble")) or bake_medieval_cobble_texture()
    earth_tex = (None if force_rebake else _tex_triplet_exists("Tex_ForestEarth")) or bake_forest_earth_texture()

    print("=== Step 2: 4x4 opaque botanical & seamless bark atlases (1024x1024 PBR) ===")
    oak_atlas = (None if force_rebake else _tex_triplet_exists("Tex_OakFoliage")) or bake_botanical_4x4_atlas("Tex_OakFoliage", "OAK")
    pine_atlas = (None if force_rebake else _tex_triplet_exists("Tex_PineFoliage")) or bake_botanical_4x4_atlas("Tex_PineFoliage", "PINE")
    sakura_atlas = (None if force_rebake else _tex_triplet_exists("Tex_SakuraBlossom")) or bake_botanical_4x4_atlas("Tex_SakuraBlossom", "SAKURA")
    shrub_atlas = (None if force_rebake else _tex_triplet_exists("Tex_ShrubFoliage")) or bake_botanical_4x4_atlas("Tex_ShrubFoliage", "SHRUB")
    turf_atlas = (None if force_rebake else _tex_triplet_exists("Tex_MeadowTurfClump")) or bake_botanical_4x4_atlas("Tex_MeadowTurfClump", "TURF")

    oak_bark = (None if force_rebake else _tex_triplet_exists("Tex_OakBark")) or bake_seamless_bark_texture("Tex_OakBark", "OAK")
    pine_bark = (None if force_rebake else _tex_triplet_exists("Tex_PineBark")) or bake_seamless_bark_texture("Tex_PineBark", "PINE")
    sakura_bark = (None if force_rebake else _tex_triplet_exists("Tex_SakuraBark")) or bake_seamless_bark_texture("Tex_SakuraBark", "SAKURA")
    shrub_bark = (None if force_rebake else _tex_triplet_exists("Tex_ShrubWood")) or bake_seamless_bark_texture("Tex_ShrubWood", "SHRUB")

    print("=== Step 3: Sculpting trees, shrubs, clumps & kits ===")
    oak_fbx, _ = build_hero_oak(oak_atlas, oak_bark)
    pine_fbx, _ = build_highland_pine(pine_atlas, pine_bark)
    sakura_fbx, _ = build_sakura_blossom(sakura_atlas, sakura_bark)
    shrub_fbx, _ = build_wild_shrub(shrub_atlas, shrub_bark)
    turf_fbx, _ = build_meadow_turf_clump(turf_atlas)
    kit_fbx, _ = build_ground_materials_kit(grass_tex, cobble_tex, earth_tex)

    print("=== Step 4: Rendering Cycles visual QA previews ===")
    render_visual_previews(
        grass_tex, cobble_tex, earth_tex,
        oak_fbx, pine_fbx, sakura_fbx, shrub_fbx, turf_fbx, kit_fbx,
    )
    print("ALL ENVIRONMENT ASSETS GENERATED CLEANLY.")


if __name__ == "__main__":
    main()
