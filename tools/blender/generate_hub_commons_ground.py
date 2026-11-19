"""
=============================================================================
Infinite Tower: Become a Master! - Hub Commons Single-Asset Ground & Proximity Grass Clump
Generates:
  1. `assets/models/environment/HubCommonsGround.fbx` (`HubCommons_Ground`)
     - `HubCommons_MeadowFloor` (Opaque 480x640 rounded-rectangle Hub lawn with
       high-res 57 px/stud seamless meadow grass & soil fiber PBR maps)
     - `HubCommons_PathWeathering` (Island-wide non-repeating macro meadow variation,
       sunlit golden-olive swells, earth clearings & feathered path/Dais dirt-moss borders)
  2. `assets/models/environment/HubGrassClump.fbx` (`HubGrassClump`)
     - Lightweight 60-tri low-poly 3D grass clump mesh for GPU-instanced proximity grass
  3. Seamless PBR Texture Sets under `assets/models/environment/textures/hub_ground/`:
     - `Tex_HubMeadowGround_{Color,Normal,Roughness}.png` (1024x1024, 18-stud tile)
     - `Tex_HubPathWeathering_{Color,Normal,Roughness}.png` (1024x1024 island-wide RGBA overlay)
     - `Tex_HubGrassClump_{Color,Normal,Roughness}.png` (512x512 root-to-tip grass blade map)
  4. `assets/models/environment/hub_commons_ground_manifest.json`

Coordinate Convention (1 Blender meter = 1 Roblox stud):
  Hub-local origin is HubLayout.HubCentre (world 0, 12, -796), Y = 0 is walking surface.
  rbx_to_blender(rx, ry, rz) = (rx, -rz, ry)
  Exported with axis_forward="Z", axis_up="Y" matching CastleCourtyardGround.fbx.

Run:
  "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b -P tools/blender/generate_hub_commons_ground.py
=============================================================================
"""

from __future__ import annotations

import argparse
import json
import math
import random
import struct
import sys
import zlib
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

REPO_ROOT = Path(__file__).resolve().parents[2]
ENV_DIR = REPO_ROOT / "assets" / "models" / "environment"
TEX_DIR = ENV_DIR / "textures" / "hub_ground"
GROUND_FBX_PATH = ENV_DIR / "HubCommonsGround.fbx"
GRASS_FBX_PATH = ENV_DIR / "HubGrassClump.fbx"
MANIFEST_PATH = ENV_DIR / "hub_commons_ground_manifest.json"
DEFAULT_PREVIEW_PATH = (
    Path(r"C:\Users\enter\.gemini\antigravity\brain\088d2829-720b-4091-8f1e-64273de844b4\scratch")
    / "hub_commons_ground_bake_verify.png"
)

# HubLayout constants (exact parity with src/ReplicatedStorage/Shared/Config/HubLayout.luau)
HUB_HALF_X = 240.0
HUB_HALF_Z = 320.0
OUTER_CORNER_RADIUS = 60.0
EDGE_INSET = 0.30

FLOOR_Y = 0.025
OVERLAY_Y = 0.042
SKIRT_BOTTOM_Y = -0.350
TILE_STUDS = 18.0
TEX_SIZE = 1024
GRASS_TEX_SIZE = 512

# Pond basins (depressed slightly under Pond_Bed/Pond_Water so the ground never clips water)
POND_BASINS = [
    (0.0, -160.0, 34.0, 29.0),     # HeroBridgePond
    (117.5, -173.0, 14.0, 11.5),   # WaterfallBoulderPond
    (157.0, 43.4, 12.0, 8.5),      # SteppingStreamPond
    (-52.1, 233.1, 14.0, 10.5),    # RockeryKoiPond
]

# Runesmith's Anvil chasm hole at HubLayout.ReforgeStation (-126, -190)
REFORGE_HOLE_X = -126.0
REFORGE_HOLE_Z = -190.0
REFORGE_HOLE_RADIUS = 36.0

PLOT_BRIDGE_LENGTH = 40.0
PLOT_FRONT_DEPTH = 168.0
PLOT_SPACING = 208.0
DAIS_EDGE = 56.0


def rbx_to_blender(rx: float, ry: float, rz: float) -> Vector:
    return Vector((rx, -rz, ry))


def write_png_rgba(path: Path, rgba: np.ndarray) -> None:
    h, w, c = rgba.shape
    assert c == 4 and rgba.dtype == np.uint8
    raw_rows = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))
    compressed = zlib.compress(raw_rows, level=6)

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def _tileable_noise(res: int, cells: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    grid = rng.random((cells, cells), dtype=np.float32)
    coords = np.linspace(0.0, cells, res, endpoint=False, dtype=np.float32)
    i0 = np.floor(coords).astype(np.int32) % cells
    i1 = (i0 + 1) % cells
    f = coords - np.floor(coords)
    u = f * f * (3.0 - 2.0 * f)
    g00 = grid[np.ix_(i0, i0)]
    g10 = grid[np.ix_(i0, i1)]
    g01 = grid[np.ix_(i1, i0)]
    g11 = grid[np.ix_(i1, i1)]
    nx0 = g00 * (1.0 - u[None, :]) + g10 * u[None, :]
    nx1 = g01 * (1.0 - u[None, :]) + g11 * u[None, :]
    return nx0 * (1.0 - u[:, None]) + nx1 * u[:, None]


def _tileable_fbm(res: int, seed: int, octaves: tuple[int, ...]) -> np.ndarray:
    acc = np.zeros((res, res), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for idx, c in enumerate(octaves):
        acc += amp * _tileable_noise(res, c, seed + idx * 97)
        norm += amp
        amp *= 0.5
    return acc / max(norm, 1e-6)


def _hash_noise_2d(h: int, w: int, scale: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    gh = max(4, h // scale + 2)
    gw = max(4, w // scale + 2)
    grid = rng.random((gh, gw), dtype=np.float32)
    yy = np.linspace(0.0, gh - 1.001, h, dtype=np.float32)[:, None]
    xx = np.linspace(0.0, gw - 1.001, w, dtype=np.float32)[None, :]
    y0 = np.floor(yy).astype(np.int32)
    x0 = np.floor(xx).astype(np.int32)
    fy = yy - y0
    fx = xx - x0
    fy = fy * fy * (3.0 - 2.0 * fy)
    fx = fx * fx * (3.0 - 2.0 * fx)
    v00 = grid[y0, x0]
    v10 = grid[y0, x0 + 1]
    v01 = grid[y0 + 1, x0]
    v11 = grid[y0 + 1, x0 + 1]
    return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy


def _fbm_local(h: int, w: int, seed: int, octaves: tuple[int, ...]) -> np.ndarray:
    acc = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for idx, sc in enumerate(octaves):
        acc += amp * _hash_noise_2d(h, w, sc, seed + idx * 97)
        norm += amp
        amp *= 0.5
    return acc / max(norm, 1e-6)


def height_to_normal_rgb(height: np.ndarray, strength: float = 2.6) -> np.ndarray:
    gx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    gy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(height)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    return np.stack([
        np.clip((nx * inv * 0.5 + 0.5) * 255.0, 0, 255),
        np.clip((ny * inv * 0.5 + 0.5) * 255.0, 0, 255),
        np.clip((nz * inv * 0.5 + 0.5) * 255.0, 0, 255),
    ], axis=-1).astype(np.uint8)


def _hub_landing_points() -> list[tuple[float, float]]:
    reach = PLOT_BRIDGE_LENGTH + PLOT_FRONT_DEPTH
    side_x = HUB_HALF_X + reach
    north_z = -(HUB_HALF_Z + reach)
    back = PLOT_FRONT_DEPTH + PLOT_BRIDGE_LENGTH
    pts: list[tuple[float, float]] = []
    for z in (PLOT_SPACING, 0.0, -PLOT_SPACING):
        pts.append((-side_x + back, z))
    for x in (-PLOT_SPACING * 0.5, PLOT_SPACING * 0.5):
        pts.append((x, north_z + back))
    for z in (-PLOT_SPACING, 0.0, PLOT_SPACING):
        pts.append((side_x - back, z))
    return pts


# ---------------------------------------------------------------------------
# 1. Seamless Hub Ground, Island-Wide Weathering & Grass Clump PBR Texture Bakers
# ---------------------------------------------------------------------------
def generate_meadow_ground_textures() -> tuple[Path, Path, Path]:
    """Generate 1024x1024 high-frequency warm olive/golden-turf/loam detail (zero tile-grid blotches)."""
    R = TEX_SIZE
    n_patch = _tileable_fbm(R, 1217, (28, 56, 112))
    n_tuft = _tileable_fbm(R, 1319, (96, 192, 320))
    n_blade = _tileable_noise(R, 384, 1423)
    n_grit = _tileable_noise(R, 256, 1523)

    streak_a = np.roll(_tileable_noise(R, 224, 1601), 2, axis=0)
    streak_b = np.roll(_tileable_noise(R, 224, 1613), 2, axis=1)
    fiber = 0.44 * n_tuft + 0.24 * n_blade + 0.16 * streak_a + 0.16 * streak_b

    # Warm olive-moss, golden dry grass & earthy loam calibrated for Sanctuary lighting
    c_deep_olive = np.array([78.0, 82.0, 38.0], dtype=np.float32)
    c_mid_olive = np.array([102.0, 100.0, 46.0], dtype=np.float32)
    c_warm_ochre = np.array([128.0, 108.0, 50.0], dtype=np.float32)
    c_loam_fleck = np.array([102.0, 78.0, 48.0], dtype=np.float32)

    turf_mix = np.clip((n_patch - 0.28) * 2.2, 0.0, 1.0)[..., None]
    rgb = c_deep_olive * (1.0 - turf_mix) + c_mid_olive * turf_mix

    gold_mask = np.clip((n_patch * 0.5 + n_tuft * 0.5 - 0.46) * 2.4, 0.0, 1.0)[..., None]
    rgb = rgb * (1.0 - gold_mask * 0.48) + c_warm_ochre * (gold_mask * 0.48)

    earth_mask = np.clip(((1.0 - n_patch) * 0.55 + (1.0 - n_tuft) * 0.45 - 0.52) * 2.8, 0.0, 1.0)[..., None]
    rgb = rgb * (1.0 - earth_mask * 0.54) + c_loam_fleck * (earth_mask * 0.54)

    micro = (fiber - 0.5) * 32.0 + (n_grit - 0.5) * 12.0
    rgb = np.clip(rgb + micro[..., None], 22.0, 225.0).astype(np.uint8)

    height = 0.48 + 0.30 * fiber + 0.10 * n_patch - 0.10 * earth_mask[..., 0] + 0.06 * n_grit
    norm_rgb = height_to_normal_rgb(height, strength=2.6)
    rough = np.clip(0.84 - 0.10 * (fiber - 0.5) + 0.06 * earth_mask[..., 0], 0.74, 0.95)
    rough_u8 = (rough * 255.0).astype(np.uint8)

    a255 = np.full((R, R), 255, dtype=np.uint8)
    p_col = TEX_DIR / "Tex_HubMeadowGround_Color.png"
    p_nrm = TEX_DIR / "Tex_HubMeadowGround_Normal.png"
    p_rgh = TEX_DIR / "Tex_HubMeadowGround_Roughness.png"
    write_png_rgba(p_col, np.dstack([rgb, a255]))
    write_png_rgba(p_nrm, np.dstack([norm_rgb, a255]))
    write_png_rgba(p_rgh, np.dstack([rough_u8, rough_u8, rough_u8, a255]))
    print(f"[HubGround] Baked seamless meadow PBR detail maps -> {TEX_DIR}")
    return p_col, p_nrm, p_rgh


def generate_path_weathering_textures() -> tuple[Path, Path, Path]:
    """Generate 1024x1024 island-wide RGBA macro variation & soft path-border weathering map."""
    R = TEX_SIZE
    rx = np.linspace(-HUB_HALF_X, HUB_HALF_X, R, dtype=np.float32)[None, :]
    rz = np.linspace(-HUB_HALF_Z, HUB_HALF_Z, R, dtype=np.float32)[:, None]

    # Non-repeating multi-scale FBM across the whole 480x640 island
    n_macro = _fbm_local(R, R, 3119, (256, 128, 64, 32))
    n_med = _fbm_local(R, R, 3217, (64, 32, 16))
    n_fine = _fbm_local(R, R, 3319, (16, 8, 4))

    # 1. Soft organic meadow variation: warm earthy loam clearings, golden dry grass swells, deep moss
    c_earth = np.array([108.0, 82.0, 50.0], dtype=np.float32)
    c_gold = np.array([148.0, 126.0, 56.0], dtype=np.float32)
    c_moss = np.array([68.0, 80.0, 34.0], dtype=np.float32)

    earth_w = np.clip((n_macro * 0.72 + n_med * 0.28 - 0.53) * 2.6, 0.0, 1.0)
    gold_w = np.clip(((1.0 - n_macro) * 0.72 + n_med * 0.28 - 0.51) * 2.6, 0.0, 1.0)
    moss_w = np.clip((0.36 - np.abs(n_macro - 0.48)) * 1.9 * n_med, 0.0, 0.65)

    # 2. Gentle feathered dusty-earth & moss transition along paths and Wayfinder Dais
    wobble = (n_med - 0.5) * 6.0 + (n_fine - 0.5) * 2.2
    d_dais = np.hypot(rx, rz)
    dais_rim = np.clip(1.0 - np.abs(d_dais - 57.5 + wobble * 0.5) / 6.5, 0.0, 1.0) * np.clip((d_dais - 52.5) / 2.5, 0.0, 1.0)

    min_path_d = np.full((R, R), 999.0, dtype=np.float32)
    segments: list[tuple[float, float, float, float, float]] = []
    for lx, lz in _hub_landing_points():
        llen = math.hypot(lx, lz)
        ux, uz = lx / llen, lz / llen
        segments.append((lx, lz, ux * (DAIS_EDGE + 2.0), uz * (DAIS_EDGE + 2.0), 8.0))
    segments.append((10.0, 118.0, 86.0, 156.0, 8.0))
    segments.append((0.0, HUB_HALF_Z, 0.0, DAIS_EDGE + 2.0, 14.0))
    # Runesmith's Anvil bridge approach dirt-wear (from chasm rim at r=36 out to r=49 toward Dais (0,0))
    anvil_len = math.hypot(-REFORGE_HOLE_X, -REFORGE_HOLE_Z)
    aux, auz = -REFORGE_HOLE_X / anvil_len, -REFORGE_HOLE_Z / anvil_len
    segments.append((
        REFORGE_HOLE_X + aux * (REFORGE_HOLE_RADIUS + 1.0),
        REFORGE_HOLE_Z + auz * (REFORGE_HOLE_RADIUS + 1.0),
        REFORGE_HOLE_X + aux * (REFORGE_HOLE_RADIUS + 13.0),
        REFORGE_HOLE_Z + auz * (REFORGE_HOLE_RADIUS + 13.0),
        4.2,
    ))

    for ax, az, bx, bz, half_w in segments:
        dx, dz = bx - ax, bz - az
        denom = dx * dx + dz * dz
        t = np.clip(((rx - ax) * dx + (rz - az) * dz) / denom, 0.0, 1.0)
        d = np.hypot(ax + t * dx - rx, az + t * dz - rz) - half_w
        min_path_d = np.minimum(min_path_d, d)

    outside_dais = np.clip((d_dais - 54.0) / 3.0, 0.0, 1.0)
    d_anvil_hole = np.hypot(rx - REFORGE_HOLE_X, rz - REFORGE_HOLE_Z)
    anvil_rim = np.clip(1.0 - np.abs(d_anvil_hole - (REFORGE_HOLE_RADIUS + 2.2) + wobble * 0.45) / 5.5, 0.0, 1.0) * np.clip((d_anvil_hole - (REFORGE_HOLE_RADIUS - 0.5)) / 2.5, 0.0, 1.0)
    path_shoulder = np.clip(1.0 - np.abs(min_path_d - 1.8 + wobble * 0.55) / 6.2, 0.0, 1.0) * outside_dais
    shoulder_w = np.maximum(np.maximum(dais_rim, path_shoulder), anvil_rim * 0.85)

    # 3. Fade smoothly near outer rounded rectangle rim, pond margins & Runesmith chasm hole
    pond_mask = np.ones((R, R), dtype=np.float32)
    for px, pz, rx_r, rz_r in POND_BASINS:
        pd = np.hypot((rx - px) / rx_r, (rz - pz) / rz_r)
        pond_mask *= np.clip((pd - 0.85) / 0.30, 0.0, 1.0)
    pond_mask *= np.clip((d_anvil_hole - (REFORGE_HOLE_RADIUS - 0.5)) / 2.2, 0.0, 1.0)

    cx, cz = HUB_HALF_X - OUTER_CORNER_RADIUS, HUB_HALF_Z - OUTER_CORNER_RADIUS
    qx = np.maximum(np.abs(rx) - cx, 0.0)
    qz = np.maximum(np.abs(rz) - cz, 0.0)
    corner_d = np.hypot(qx, qz) - OUTER_CORNER_RADIUS
    side_d = np.maximum(np.abs(rx) - HUB_HALF_X, np.abs(rz) - HUB_HALF_Z)
    rim_dist = np.where((np.abs(rx) > cx) & (np.abs(rz) > cz), -corner_d, -side_d)
    rim_mask = np.clip((rim_dist - 1.5) / 4.0, 0.0, 1.0)

    macro_alpha = np.clip(np.maximum(earth_w * 0.58, np.maximum(gold_w * 0.52, moss_w * 0.44)), 0.0, 0.62)
    w_sum = earth_w + gold_w + moss_w + shoulder_w * 1.1 + 1e-5
    rgb = (
        c_earth * (earth_w + shoulder_w * 0.72)[..., None]
        + c_gold * gold_w[..., None]
        + c_moss * (moss_w + shoulder_w * 0.38)[..., None]
    ) / w_sum[..., None]
    rgb = np.clip(rgb + (n_fine[..., None] - 0.5) * 20.0, 20.0, 228.0).astype(np.uint8)

    alpha = np.maximum(macro_alpha, shoulder_w * 0.48) * pond_mask * rim_mask
    a_u8 = np.clip(alpha * 255.0, 0.0, 255.0).astype(np.uint8)

    height = 0.50 + 0.14 * (n_fine - 0.5) * alpha - 0.06 * shoulder_w
    norm_rgb = height_to_normal_rgb(height, strength=2.2)
    rough = np.clip(0.86 + 0.06 * earth_w - 0.04 * gold_w, 0.76, 0.96)
    r_u8 = (rough * 255.0).astype(np.uint8)
    a255 = np.full((R, R), 255, dtype=np.uint8)

    p_col = TEX_DIR / "Tex_HubPathWeathering_Color.png"
    p_nrm = TEX_DIR / "Tex_HubPathWeathering_Normal.png"
    p_rgh = TEX_DIR / "Tex_HubPathWeathering_Roughness.png"
    write_png_rgba(p_col, np.dstack([rgb, a_u8]))
    write_png_rgba(p_nrm, np.dstack([norm_rgb, a255]))
    write_png_rgba(p_rgh, np.dstack([r_u8, r_u8, r_u8, a255]))
    print(f"[HubGround] Baked island-wide RGBA macro & path weathering map -> {TEX_DIR}")
    return p_col, p_nrm, p_rgh


def generate_grass_clump_textures() -> tuple[Path, Path, Path]:
    """Generate 512x512 warm olive-to-golden grass blade PBR maps matching the meadow palette."""
    S = GRASS_TEX_SIZE
    v = np.linspace(0.0, 1.0, S, dtype=np.float32)[:, None]
    u = np.linspace(0.0, 1.0, S, dtype=np.float32)[None, :]
    t_tip = 1.0 - v
    veins = 0.5 + 0.5 * np.sin(u * math.tau * 10.0) * 0.6
    n_grain = _fbm_local(S, S, 2601, (32, 16, 8))

    c_root = np.array([76.0, 80.0, 36.0], dtype=np.float32)
    c_mid = np.array([122.0, 124.0, 52.0], dtype=np.float32)
    c_tip = np.array([172.0, 156.0, 68.0], dtype=np.float32)

    mid_mask = np.clip(t_tip / 0.52, 0.0, 1.0)[..., None]
    tip_mask = np.clip((t_tip - 0.48) / 0.52, 0.0, 1.0)[..., None]
    rgb = c_root * (1.0 - mid_mask) + c_mid * mid_mask
    rgb = rgb * (1.0 - tip_mask) + c_tip * tip_mask
    rgb = rgb + (veins[..., None] - 0.5) * 14.0 + (n_grain[..., None] - 0.5) * 14.0
    rgb = np.clip(rgb, 20.0, 236.0).astype(np.uint8)

    height = 0.45 + 0.30 * veins + 0.15 * n_grain
    norm_rgb = height_to_normal_rgb(height, strength=1.8)
    rough = np.clip(0.84 - 0.14 * t_tip + 0.06 * (n_grain - 0.5), 0.64, 0.90)
    r_u8 = (rough * 255.0).astype(np.uint8)
    a255 = np.full((S, S), 255, dtype=np.uint8)

    p_col = TEX_DIR / "Tex_HubGrassClump_Color.png"
    p_nrm = TEX_DIR / "Tex_HubGrassClump_Normal.png"
    p_rgh = TEX_DIR / "Tex_HubGrassClump_Roughness.png"
    write_png_rgba(p_col, np.dstack([rgb, a255]))
    write_png_rgba(p_nrm, np.dstack([norm_rgb, a255]))
    write_png_rgba(p_rgh, np.dstack([r_u8, r_u8, r_u8, a255]))
    return p_col, p_nrm, p_rgh


# ---------------------------------------------------------------------------
# 2. Blender Material & Mesh Construction
# ---------------------------------------------------------------------------
def create_pbr_material(name: str, p_col: Path, p_nrm: Path, p_rgh: Path, blend_alpha: bool = False) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Specular IOR Level"].default_value = 0.24
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def load_img(path: Path, colorspace: str):
        img = bpy.data.images.load(str(path), check_existing=True)
        img.colorspace_settings.name = colorspace
        return img

    tex_col = nt.nodes.new("ShaderNodeTexImage")
    tex_col.image = load_img(p_col, "sRGB")
    nt.links.new(tex_col.outputs["Color"], bsdf.inputs["Base Color"])
    if blend_alpha:
        nt.links.new(tex_col.outputs["Alpha"], bsdf.inputs["Alpha"])

    tex_rgh = nt.nodes.new("ShaderNodeTexImage")
    tex_rgh.image = load_img(p_rgh, "Non-Color")
    nt.links.new(tex_rgh.outputs["Color"], bsdf.inputs["Roughness"])

    tex_nrm = nt.nodes.new("ShaderNodeTexImage")
    tex_nrm.image = load_img(p_nrm, "Non-Color")
    nrm_node = nt.nodes.new("ShaderNodeNormalMap")
    nrm_node.inputs["Strength"].default_value = 0.90
    nt.links.new(tex_nrm.outputs["Color"], nrm_node.inputs["Color"])
    nt.links.new(nrm_node.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def _clamp_to_rounded_rect(rx: float, rz: float, hx: float, hz: float, r: float) -> tuple[float, float]:
    cx, cz = hx - r, hz - r
    ax = max(abs(rx) - cx, 0.0)
    az = max(abs(rz) - cz, 0.0)
    dist = math.hypot(ax, az)
    if dist > r:
        s = r / dist
        rx = math.copysign(cx + ax * s, rx)
        rz = math.copysign(cz + az * s, rz)
    return rx, rz


def _floor_height(rx: float, rz: float, base_y: float) -> float:
    return base_y


def _build_rounded_rect_sheet(
    name: str,
    mat: bpy.types.Material,
    col: bpy.types.Collection,
    base_y: float,
    inset: float,
    island_uv: bool,
    with_skirt: bool,
) -> tuple[bpy.types.Object, int]:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    hx = HUB_HALF_X - inset
    hz = HUB_HALF_Z - inset
    r = OUTER_CORNER_RADIUS - inset
    nx, nz = 48, 64

    # Window in the 10-stud grid enclosing the R=36 Runesmith's Anvil chasm hole at (-126, -190)
    hole_ix0, hole_ix1 = 7, 16
    hole_iz0, hole_iz1 = 8, 18

    def set_top_uv(loop: bmesh.types.BMLoop, co: Vector) -> None:
        if island_uv:
            loop[uv].uv = ((co.x + HUB_HALF_X) / (2.0 * HUB_HALF_X), (co.y + HUB_HALF_Z) / (2.0 * HUB_HALF_Z))
        else:
            loop[uv].uv = ((co.x + hx) / TILE_STUDS, (co.y + hz) / TILE_STUDS)

    grid: list[list[bmesh.types.BMVert]] = []
    for iz in range(nz + 1):
        rz_raw = -hz + (2.0 * hz) * (iz / nz)
        row = []
        for ix in range(nx + 1):
            rx_raw = -hx + (2.0 * hx) * (ix / nx)
            rx, rz = _clamp_to_rounded_rect(rx_raw, rz_raw, hx, hz, r)
            ry = _floor_height(rx, rz, base_y)
            row.append(bm.verts.new(rbx_to_blender(rx, ry, rz)))
        grid.append(row)

    for iz in range(nz):
        for ix in range(nx):
            if hole_ix0 <= ix < hole_ix1 and hole_iz0 <= iz < hole_iz1:
                continue
            v00, v10, v11, v01 = grid[iz][ix], grid[iz][ix + 1], grid[iz + 1][ix + 1], grid[iz + 1][ix]
            pts = {v.co.to_tuple(3) for v in (v00, v01, v11, v10)}
            if len(pts) < 3:
                continue
            f = bm.faces.new([v00, v01, v11, v10])
            f.smooth = True
            for loop in f.loops:
                set_top_uv(loop, loop.vert.co)

    # Stitch the 24 boundary grid vertices around the 60x60 window to a 24-gon circle of R = REFORGE_HOLE_RADIUS
    ring_grid_verts: list[bmesh.types.BMVert] = []
    for ix in range(hole_ix0, hole_ix1):
        ring_grid_verts.append(grid[hole_iz0][ix])
    for iz in range(hole_iz0, hole_iz1):
        ring_grid_verts.append(grid[iz][hole_ix1])
    for ix in range(hole_ix1, hole_ix0, -1):
        ring_grid_verts.append(grid[hole_iz1][ix])
    for iz in range(hole_iz1, hole_iz0, -1):
        ring_grid_verts.append(grid[iz][hole_ix0])

    hole_top_verts: list[bmesh.types.BMVert] = []
    hole_top_pts: list[tuple[float, float]] = []
    for gv in ring_grid_verts:
        gx, gz = gv.co.x, -gv.co.y
        dx, dz = gx - REFORGE_HOLE_X, gz - REFORGE_HOLE_Z
        dist = max(1e-4, math.hypot(dx, dz))
        cx_h = REFORGE_HOLE_X + (dx / dist) * REFORGE_HOLE_RADIUS
        cz_h = REFORGE_HOLE_Z + (dz / dist) * REFORGE_HOLE_RADIUS
        hole_top_pts.append((cx_h, cz_h))
        hole_top_verts.append(bm.verts.new(rbx_to_blender(cx_h, base_y, cz_h)))

    n_hole = len(ring_grid_verts)
    for k in range(n_hole):
        kn = (k + 1) % n_hole
        fh = bm.faces.new([ring_grid_verts[k], hole_top_verts[k], hole_top_verts[kn], ring_grid_verts[kn]])
        fh.smooth = True
        for loop in fh.loops:
            set_top_uv(loop, loop.vert.co)

    # Remove unused interior grid vertices inside the cutout window
    for v in list(bm.verts):
        if len(v.link_faces) == 0:
            bm.verts.remove(v)

    bm.faces.ensure_lookup_table()
    bm.normal_update()
    top_faces = list(bm.faces)
    for f in top_faces:
        if f.normal.z < 0.0:
            f.normal_flip()

    if with_skirt:
        cx, cz = hx - r, hz - r
        perim_pts: list[tuple[float, float]] = []
        arc_steps = 8
        quadrants = [
            (1.0, -1.0, 0.0, math.pi * 0.5),
            (1.0, 1.0, math.pi * 0.5, math.pi),
            (-1.0, 1.0, math.pi, math.pi * 1.5),
            (-1.0, -1.0, math.pi * 1.5, math.tau),
        ]
        for qx, qz, a0, a1 in quadrants:
            for k in range(arc_steps + 1):
                ang = a0 + (k / arc_steps) * (a1 - a0)
                px = qx * cx + math.sin(ang) * r
                pz = qz * cz - math.cos(ang) * r
                perim_pts.append((px, pz))

        top_verts = [bm.verts.new(rbx_to_blender(px, base_y, pz)) for px, pz in perim_pts]
        bot_verts = [bm.verts.new(rbx_to_blender(px, SKIRT_BOTTOM_Y, pz)) for px, pz in perim_pts]
        n_p = len(top_verts)
        skirt_faces = []
        for k in range(n_p):
            kn = (k + 1) % n_p
            fs = bm.faces.new([top_verts[k], top_verts[kn], bot_verts[kn], bot_verts[k]])
            fs.smooth = False
            for loop in fs.loops:
                co = loop.vert.co
                loop[uv].uv = ((co.x + co.y) / TILE_STUDS, co.z / TILE_STUDS)
            skirt_faces.append(fs)
        bm.normal_update()
        for fs in skirt_faces:
            c = fs.calc_center_median()
            if fs.normal.x * c.x + fs.normal.y * c.y < 0.0:
                fs.normal_flip()

        # Inner chasm hole rim skirt (normals face inward toward hole center)
        hole_bot_verts = [bm.verts.new(rbx_to_blender(px, SKIRT_BOTTOM_Y, pz)) for px, pz in hole_top_pts]
        hole_c_bl = rbx_to_blender(REFORGE_HOLE_X, 0.0, REFORGE_HOLE_Z)
        inner_skirt_faces = []
        for k in range(n_hole):
            kn = (k + 1) % n_hole
            fi = bm.faces.new([hole_top_verts[k], hole_bot_verts[k], hole_bot_verts[kn], hole_top_verts[kn]])
            fi.smooth = False
            for loop in fi.loops:
                co = loop.vert.co
                loop[uv].uv = ((co.x + co.y) / TILE_STUDS, co.z / TILE_STUDS)
            inner_skirt_faces.append(fi)
        bm.normal_update()
        for fi in inner_skirt_faces:
            c = fi.calc_center_median()
            to_center_x = hole_c_bl.x - c.x
            to_center_y = hole_c_bl.y - c.y
            if fi.normal.x * to_center_x + fi.normal.y * to_center_y < 0.0:
                fi.normal_flip()

    bm.normal_update()
    assert all(f.normal.z > 0.5 for f in top_faces), f"{name}: top face normal inverted"
    tris = sum(max(1, len(f.verts) - 2) for f in bm.faces)
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    return obj, tris


def build_grass_clump(mat_grass: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """Build lightweight ~70-tri HubGrassClump mesh pivoted at (0, 0, 0) base."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(2026)

    num_blades = 14
    for i in range(num_blades):
        ang = (i / num_blades) * math.tau + rng.uniform(-0.26, 0.26)
        dist = rng.uniform(0.08, 0.90)
        bx = math.cos(ang) * dist
        bz = math.sin(ang) * dist
        h = rng.uniform(0.95, 1.48) * (1.0 - 0.15 * (dist / 0.95))
        w = rng.uniform(0.12, 0.18)
        lean = rng.uniform(0.32, 0.84)
        yaw = ang + rng.uniform(-0.35, 0.35)

        dx, dz = math.cos(yaw), math.sin(yaw)
        sx, sz = -dz, dx
        u_mid = (i + 0.5) / num_blades

        v_b0 = bm.verts.new(rbx_to_blender(bx - sx * w * 0.5, -0.04, bz - sz * w * 0.5))
        v_b1 = bm.verts.new(rbx_to_blender(bx + sx * w * 0.5, -0.04, bz + sz * w * 0.5))

        m_out = lean * 0.32
        v_m0 = bm.verts.new(rbx_to_blender(bx + dx * m_out - sx * w * 0.36, h * 0.48, bz + dz * m_out - sz * w * 0.36))
        v_m1 = bm.verts.new(rbx_to_blender(bx + dx * m_out + sx * w * 0.36, h * 0.48, bz + dz * m_out + sz * w * 0.36))

        u_out = lean * 0.68
        v_u0 = bm.verts.new(rbx_to_blender(bx + dx * u_out - sx * w * 0.16, h * 0.80, bz + dz * u_out - sz * w * 0.16))
        v_u1 = bm.verts.new(rbx_to_blender(bx + dx * u_out + sx * w * 0.16, h * 0.80, bz + dz * u_out + sz * w * 0.16))

        t_out = lean * 1.05
        v_tip = bm.verts.new(rbx_to_blender(bx + dx * t_out, h, bz + dz * t_out))

        for verts_quad, v_lo, v_hi in (
            ([v_b0, v_b1, v_m1, v_m0], 0.0, 0.48),
            ([v_m0, v_m1, v_u1, v_u0], 0.48, 0.80),
        ):
            fq = bm.faces.new(verts_quad)
            fq.smooth = True
            for loop, v_y in zip(fq.loops, (v_lo, v_lo, v_hi, v_hi)):
                loop[uv].uv = (u_mid, v_y)

        ft = bm.faces.new([v_u0, v_u1, v_tip])
        ft.smooth = True
        for loop, v_y in zip(ft.loops, (0.80, 0.80, 1.0)):
            loop[uv].uv = (u_mid, v_y)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    tris = sum(max(1, len(f.verts) - 2) for f in bm.faces)
    mesh = bpy.data.meshes.new("HubGrassClump_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat_grass)
    obj = bpy.data.objects.new("HubGrassClump", mesh)
    col.objects.link(obj)
    return obj, tris


def export_fbx(objs: list[bpy.types.Object], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=str(out_path),
        use_selection=True,
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        axis_forward="Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=False,
        path_mode="COPY",
        embed_textures=True,
    )
    print(f"[HubGround] Exported FBX -> {out_path} ({out_path.stat().st_size} bytes)")


def render_verification(out_png: Path, col: bpy.types.Collection) -> None:
    scene = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(out_png)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = -0.10

    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    scene.world = world
    if world.node_tree is None:
        world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg:
        bg.inputs[0].default_value = (0.16, 0.19, 0.24, 1.0)
        bg.inputs[1].default_value = 0.90

    sun_d = bpy.data.lights.new("VerifySun", type="SUN")
    sun_d.energy = 2.6
    sun_d.color = (1.0, 0.95, 0.85)
    sun = bpy.data.objects.new("VerifySun", sun_d)
    sun.rotation_euler = (math.radians(40.0), math.radians(18.0), math.radians(-38.0))
    col.objects.link(sun)

    cam_d = bpy.data.cameras.new("VerifyCam")
    cam_d.lens = 28.0
    cam_d.clip_end = 5000.0
    cam = bpy.data.objects.new("VerifyCam", cam_d)
    col.objects.link(cam)
    scene.camera = cam
    cam_pos = rbx_to_blender(-140.0, 480.0, 390.0)
    tgt_pos = rbx_to_blender(0.0, 0.0, 0.0)
    cam.location = cam_pos
    cam.rotation_euler = (tgt_pos - cam_pos).normalized().to_track_quat("-Z", "Y").to_euler()

    out_png.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"[HubGround] Rendered verification -> {out_png}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Hub Commons Single-Asset Ground & Proximity Grass Clump")
    parser.add_argument("--no-render", action="store_true")
    parser.add_argument("--preview-out", type=Path, default=DEFAULT_PREVIEW_PATH)
    cli_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args, _ = parser.parse_known_args(cli_args)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    col = bpy.data.collections.new("HubCommonsGround_Prefab")
    scene.collection.children.link(col)

    m_col, m_nrm, m_rgh = generate_meadow_ground_textures()
    w_col, w_nrm, w_rgh = generate_path_weathering_textures()
    g_col, g_nrm, g_rgh = generate_grass_clump_textures()

    mat_meadow = create_pbr_material("Mat_HubMeadowGround", m_col, m_nrm, m_rgh, blend_alpha=False)
    mat_splat = create_pbr_material("Mat_HubPathWeathering", w_col, w_nrm, w_rgh, blend_alpha=True)
    mat_grass = create_pbr_material("Mat_HubGrassClump", g_col, g_nrm, g_rgh, blend_alpha=False)

    floor_obj, floor_tris = _build_rounded_rect_sheet(
        "HubCommons_MeadowFloor", mat_meadow, col, FLOOR_Y, EDGE_INSET, island_uv=False, with_skirt=True
    )
    weather_obj, weather_tris = _build_rounded_rect_sheet(
        "HubCommons_PathWeathering", mat_splat, col, OVERLAY_Y, EDGE_INSET + 0.4, island_uv=True, with_skirt=False
    )
    grass_obj, grass_tris = build_grass_clump(mat_grass, col)

    total_ground_tris = floor_tris + weather_tris
    print(f"[HubGround] Ground Tris: {total_ground_tris} (floor={floor_tris}, weathering={weather_tris}), GrassClump Tris: {grass_tris}")
    assert total_ground_tris < 15000, f"Ground triangle budget exceeded: {total_ground_tris}"

    export_fbx([floor_obj, weather_obj], GROUND_FBX_PATH)
    grass_obj.hide_render = True
    export_fbx([grass_obj], GRASS_FBX_PATH)

    def bbox_rbx(obj: bpy.types.Object) -> dict:
        pts = [Vector(c) for c in obj.bound_box]
        r_pts = [(p.x, p.z, -p.y) for p in pts]
        xs, ys, zs = [p[0] for p in r_pts], [p[1] for p in r_pts], [p[2] for p in r_pts]
        pos = [round((min(xs) + max(xs)) * 0.5, 4), round((min(ys) + max(ys)) * 0.5, 4), round((min(zs) + max(zs)) * 0.5, 4)]
        sz = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)]
        return {"pos": pos, "size": sz, "pivot_offset": [-pos[0], -pos[1], -pos[2]]}

    manifest = {
        "hub_width": HUB_HALF_X * 2.0,
        "hub_length": HUB_HALF_Z * 2.0,
        "outer_corner_radius": OUTER_CORNER_RADIUS,
        "floor_y": FLOOR_Y,
        "overlay_y": OVERLAY_Y,
        "tile_studs": TILE_STUDS,
        "ground_tris": total_ground_tris,
        "grass_clump_tris": grass_tris,
        "meshes": {
            o.name: bbox_rbx(o) for o in (floor_obj, weather_obj, grass_obj)
        },
        "textures": {
            "hub_meadow_ground": {
                "color": str(m_col.relative_to(REPO_ROOT).as_posix()),
                "normal": str(m_nrm.relative_to(REPO_ROOT).as_posix()),
                "roughness": str(m_rgh.relative_to(REPO_ROOT).as_posix()),
            },
            "hub_path_weathering": {
                "color": str(w_col.relative_to(REPO_ROOT).as_posix()),
                "normal": str(w_nrm.relative_to(REPO_ROOT).as_posix()),
                "roughness": str(w_rgh.relative_to(REPO_ROOT).as_posix()),
            },
            "hub_grass_clump": {
                "color": str(g_col.relative_to(REPO_ROOT).as_posix()),
                "normal": str(g_nrm.relative_to(REPO_ROOT).as_posix()),
                "roughness": str(g_rgh.relative_to(REPO_ROOT).as_posix()),
            },
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"[HubGround] Wrote manifest -> {MANIFEST_PATH}")

    if not args.no_render:
        render_verification(args.preview_out, col)


if __name__ == "__main__":
    main()
